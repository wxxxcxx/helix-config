(require "steel/result")

(provide package
         package-git-dependency
         package-install!
         package-install-all!
         package-clean!
         package-clean-all!
         package-reference
         package-reference-kind
         package-status
         package-list!)

;; Pure Steel wrapper around Forge. Requiring this module never mutates the
;; filesystem; callers explicitly choose install, clean, or list operations.

(define package-path-separator (path-separator))

(define (package-path-join base child)
  (define portable-child
    (string-replace child "/" package-path-separator))
  (if (ends-with? base package-path-separator)
      (string-append base portable-child)
      (string-append base package-path-separator portable-child)))

(define (package-valid-name? name)
  (and (string? name)
       (not (string=? name ""))
       (not (string-contains? name "/"))
       (not (string-contains? name "\\"))
       (not (string-contains? name ":"))
       (not (string-contains? name ".."))))

(define (package-reference-value? value)
  (and (string? value) (not (string=? value ""))))

(define (package-valid-verification-path? path)
  (and (string? path)
       (not (string=? path ""))
       (not (string=? (substring path 0 1) "/"))
       (not (string-contains? path "\\"))
       (not (string-contains? path ":"))
       (not (member ".." (split-many path "/")))))

(define (package #:name name #:url url
                 #:commit [commit #f]
                 #:branch [branch #f]
                 #:tag [tag #f]
                 #:revision [revision #f]
                 #:verify [verify #f])
  (unless (package-valid-name? name)
    (error (string-append "invalid package name: " (to-string name))))
  (unless (and (string? url) (not (string=? url "")))
    (error (string-append "invalid package URL for " name)))
  (for-each
    (lambda (reference)
      (when (and (cdr reference)
                 (not (package-reference-value? (cdr reference))))
        (error (string-append "invalid package "
                              (symbol->string (car reference))
                              " for " name))))
    (list (cons 'commit commit)
          (cons 'branch branch)
          (cons 'tag tag)
          (cons 'revision revision)))
  (define references
    (filter (lambda (reference) (cdr reference))
            (list (cons 'commit commit)
                  (cons 'branch branch)
                  (cons 'tag tag)
                  (cons 'commit revision))))
  (when (> (length references) 1)
    (error (string-append
             "package " name
             " accepts only one of commit, branch, or tag")))
  (when (and verify (not (package-valid-verification-path? verify)))
    (error (string-append "invalid package verification path for " name)))
  (define reference (and (not (null? references)) (car references)))
  (hash 'name name
        'url url
        'reference-kind (and reference (car reference))
        'reference (and reference (cdr reference))
        'verify verify))

;; Compatibility for callers using the old revision-only constructor.
(define (package-git-dependency #:name name #:url url
                                #:revision [revision #f]
                                #:verify [verify #f])
  (package #:name name #:url url #:revision revision #:verify verify))

(define (package-name dependency) (hash-get dependency 'name))
(define (package-url dependency) (hash-get dependency 'url))
(define (package-reference dependency) (hash-get dependency 'reference))
(define (package-reference-kind dependency)
  (hash-get dependency 'reference-kind))
(define (package-verify dependency) (hash-get dependency 'verify))

(define (package-steel-path child)
  (package-path-join (steel-home-location) child))

(define (package-install-path dependency)
  (package-path-join (package-steel-path "cogs") (package-name dependency)))

(define (package-source-path dependency)
  (package-path-join (package-steel-path "cog-sources") (package-name dependency)))

(define (package-command-output program arguments)
  (~> (command program arguments)
      with-stdout-piped
      spawn-process
      unwrap-ok
      wait->stdout
      unwrap-ok
      trim))

(define (package-run! program arguments)
  (define child (unwrap-ok (spawn-process (command program arguments))))
  (define status (unwrap-ok (wait child)))
  (unless (= status 0)
    (error (string-append program " failed with status " (to-string status))))
  status)

(define (package-git-value dependency arguments)
  (define source (package-source-path dependency))
  (and (path-exists? (package-path-join source ".git"))
       (with-handler (lambda (_) #f)
         (package-command-output "git" (append (list "-C" source) arguments)))))

(define (package-git-revision dependency reference)
  (package-git-value
    dependency
    (list "rev-parse" "--verify" "--quiet"
          (string-append reference "^{commit}"))))

(define (package-current-revision dependency)
  ;; `@` always means the checked-out commit, even when an older Forge cache
  ;; contains the ambiguous synthetic ref refs/heads/HEAD.
  (package-git-value
    dependency (list "rev-parse" "--verify" "--quiet" "@^{commit}")))

(define (package-current-url dependency)
  (package-git-value dependency (list "remote" "get-url" "origin")))

(define (package-expected-revision dependency)
  (define reference (package-reference dependency))
  (define kind (package-reference-kind dependency))
  (cond [(not reference) #f]
        [(equal? kind 'branch)
         (or (package-git-revision
               dependency (string-append "refs/remotes/origin/" reference))
             (package-git-revision
               dependency (string-append "refs/heads/" reference)))]
        [(equal? kind 'tag)
         (package-git-revision
           dependency (string-append "refs/tags/" reference))]
        [else (package-git-revision dependency reference)]))

(define (package-verification-ready? dependency)
  (define verify (package-verify dependency))
  (or (not verify)
      (path-exists? (package-path-join (package-install-path dependency) verify))))

(define (package-status dependency)
  (define installed? (path-exists? (package-install-path dependency)))
  (if (not installed?)
      'missing
      (let ([source-url (package-current-url dependency)]
            [current-revision (package-current-revision dependency)]
            [reference (package-reference dependency)]
            [expected-revision (package-expected-revision dependency)])
        (if (or (not source-url)
                (not (string=? source-url (package-url dependency)))
                (and reference
                     (or (not current-revision)
                         (not expected-revision)
                         (not (string=? current-revision expected-revision))))
                (not (package-verification-ready? dependency)))
            'stale
            'ready))))

(define (package-clone-source! dependency)
  (define source-path (package-source-path dependency))
  (define source-root (package-steel-path "cog-sources"))
  (unless (path-exists? source-root)
    (create-directory! source-root))
  (displayln (string-append "Cloning " (package-name dependency) " source..."))
  (package-run! "git"
                (list "clone" "--" (package-url dependency) source-path)))

(define (package-fetch-branch! dependency branch)
  (define remote-reference
    (string-append "refs/remotes/origin/" branch))
  (package-run!
    "git"
    (list "-C" (package-source-path dependency)
          "fetch" "--force" "origin"
          (string-append "+refs/heads/" branch ":" remote-reference)))
  (package-run!
    "git"
    (list "-C" (package-source-path dependency)
          "checkout" "--force" "-B" branch remote-reference)))

(define (package-fetch-tag! dependency tag)
  (define reference (string-append "refs/tags/" tag))
  (package-run!
    "git"
    (list "-C" (package-source-path dependency)
          "fetch" "--force" "origin"
          (string-append "+" reference ":" reference)))
  (package-run!
    "git"
    (list "-C" (package-source-path dependency)
          "checkout" "--force" "--detach" reference)))

(define (package-fetch-commit! dependency commit)
  (package-run!
    "git"
    (list "-C" (package-source-path dependency)
          "fetch" "--force" "origin" commit))
  (package-run!
    "git"
    (list "-C" (package-source-path dependency)
          "checkout" "--force" "--detach" commit)))

(define (package-fetch-default! dependency)
  (define source-path (package-source-path dependency))
  (package-run! "git"
                (list "-C" source-path "fetch" "--force" "--prune" "origin"))
  (define remote-head
    (package-git-value
      dependency
      (list "symbolic-ref" "--quiet" "refs/remotes/origin/HEAD")))
  (unless remote-head
    (error (string-append "package " (package-name dependency)
                          " origin has no default branch")))
  (package-run! "git"
                (list "-C" source-path
                      "checkout" "--force" "--detach" remote-head)))

(define (package-fetch-reference! dependency)
  (define reference (package-reference dependency))
  (define kind (package-reference-kind dependency))
  (cond [(not reference) (package-fetch-default! dependency)]
        [(equal? kind 'branch) (package-fetch-branch! dependency reference)]
        [(equal? kind 'tag) (package-fetch-tag! dependency reference)]
        [else (package-fetch-commit! dependency reference)]))

(define (package-prepare-source! dependency)
  (define source-path (package-source-path dependency))
  (define git-path (package-path-join source-path ".git"))
  (when (and (path-exists? source-path) (not (path-exists? git-path)))
    (displayln (string-append "Removing invalid source cache: " source-path))
    (delete-directory! source-path))
  (unless (path-exists? source-path)
    (package-clone-source! dependency))
  (unless (string=? (or (package-current-url dependency) "")
                       (package-url dependency))
    (displayln (string-append "Updating " (package-name dependency) " origin"))
    (package-run! "git"
                  (list "-C" source-path "remote" "set-url" "origin"
                        (package-url dependency))))
  ;; Older Forge versions created this synthetic branch for pinned revisions.
  ;; It makes Git treat HEAD as ambiguous and is not used by this installer.
  (package-run! "git"
                (list "-C" source-path "update-ref" "-d" "refs/heads/HEAD"))
  (package-fetch-reference! dependency)
  source-path)

(define (package-install! dependency #:force [force #f])
  (define status (package-status dependency))
  (if (and (equal? status 'ready) (not force))
      (displayln (string-append (package-name dependency) " is already ready"))
      (begin
        (unless (which "forge")
          (error "forge is required; build the Steel-enabled Helix fork first"))
        (unless (which "git")
          (error "git is required to install Steel packages"))
        (let ([source-path (package-prepare-source! dependency)])
          (displayln (string-append "Installing " (package-name dependency) " with Forge..."))
          (package-run! "forge" (list "install" source-path "--force"))
          (unless (equal? (package-status dependency) 'ready)
            (error (string-append "package verification failed: "
                                  (package-name dependency))))))))

(define (package-install-all! dependencies #:force [force #f])
  (for-each (lambda (dependency)
              (package-install! dependency #:force force))
            dependencies))

(define (package-clean! dependency)
  (define install-path (package-install-path dependency))
  (define source-path (package-source-path dependency))
  (when (path-exists? install-path)
    (unless (which "forge")
      (error "forge is required to uninstall packages safely"))
    (displayln (string-append "Uninstalling " (package-name dependency) " with Forge..."))
    (package-run! "forge" (list "pkg" "uninstall" (package-name dependency))))
  (when (path-exists? source-path)
    (displayln (string-append "Removing source cache: " source-path))
    (delete-directory! source-path))
  (displayln (string-append (package-name dependency) " is clean")))

(define (package-clean-all! dependencies)
  (for-each package-clean! dependencies))

(define (package-list! dependencies)
  (for-each
    (lambda (dependency)
      (define current (package-current-revision dependency))
      (displayln
        (string-append (package-name dependency)
                       "  "
                       (symbol->string (package-status dependency))
                       (if current (string-append "  " current) ""))))
    dependencies))
