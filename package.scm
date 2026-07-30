(require "steel/result")

(provide package-git-dependency
         package-install!
         package-install-all!
         package-clean!
         package-clean-all!
         package-status
         package-list!)

;; Pure Steel wrapper around Forge. Requiring this module never mutates the
;; filesystem; callers explicitly choose install, clean, or list operations.

(define package-path-separator (path-separator))

(define (package-path-join base child)
  (if (ends-with? base package-path-separator)
      (string-append base child)
      (string-append base package-path-separator child)))

(define (package-valid-name? name)
  (and (string? name)
       (not (string=? name ""))
       (not (string-contains? name "/"))
       (not (string-contains? name "\\"))
       (not (string-contains? name ":"))
       (not (string-contains? name ".."))))

(define (package-git-dependency #:name name #:url url
                                #:revision [revision #f]
                                #:verify [verify #f])
  (unless (package-valid-name? name)
    (error (string-append "invalid package name: " (to-string name))))
  (unless (and (string? url) (not (string=? url "")))
    (error (string-append "invalid package URL for " name)))
  (when (and revision (not (string? revision)))
    (error (string-append "invalid package revision for " name)))
  (when (and verify (not (string? verify)))
    (error (string-append "invalid package verification path for " name)))
  (hash 'name name 'url url 'revision revision 'verify verify))

(define (package-name dependency) (hash-get dependency 'name))
(define (package-url dependency) (hash-get dependency 'url))
(define (package-revision dependency) (hash-get dependency 'revision))
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

(define (package-current-revision dependency)
  ;; Forge creates a detached checkout plus refs/heads/HEAD for pinned git
  ;; dependencies. Query that exact ref first to avoid Git's ambiguous-HEAD
  ;; warning, then fall back to the regular repository HEAD.
  (define forge-head
    (package-git-value dependency
                       (list "show-ref" "--hash" "--verify" "refs/heads/HEAD")))
  (if (and forge-head (not (string=? forge-head "")))
      forge-head
      (package-git-value dependency (list "rev-parse" "--verify" "HEAD^{commit}"))))

(define (package-current-url dependency)
  (package-git-value dependency (list "remote" "get-url" "origin")))

(define (package-verification-ready? dependency)
  (define verify (package-verify dependency))
  (or (not verify)
      (path-exists? (package-path-join (package-install-path dependency) verify))))

(define (package-status dependency)
  (define installed? (path-exists? (package-install-path dependency)))
  (define source-url (package-current-url dependency))
  (define current-revision (package-current-revision dependency))
  (define expected-revision (package-revision dependency))
  (cond [(not installed?) 'missing]
        [(or (not source-url)
             (not (string=? source-url (package-url dependency)))
             (and expected-revision
                  (or (not current-revision)
                      (not (string=? current-revision expected-revision))))
             (not (package-verification-ready? dependency)))
         'stale]
        [else 'ready]))

(define (package-prepare-source! dependency)
  (define source-path (package-source-path dependency))
  (define source-url (package-current-url dependency))
  (cond [(not (path-exists? source-path)) void]
        [(not source-url)
         (displayln (string-append "Removing invalid source cache: " source-path))
         (delete-directory! source-path)]
        [(not (string=? source-url (package-url dependency)))
         (displayln (string-append "Updating " (package-name dependency) " origin"))
         (package-run! "git"
                       (list "-C" source-path "remote" "set-url" "origin"
                             (package-url dependency)))]))

(define (package-install! dependency #:force [force #f])
  (unless (which "forge")
    (error "forge is required; build the Steel-enabled Helix fork first"))
  (define status (package-status dependency))
  (if (and (equal? status 'ready) (not force))
      (displayln (string-append (package-name dependency) " is already ready"))
      (let ([arguments
             (append (list "pkg" "install" "--git" (package-url dependency))
                     (if (package-revision dependency)
                         (list "--rev" (package-revision dependency))
                         '())
                     (list "--force"))])
        (package-prepare-source! dependency)
        (displayln (string-append "Installing " (package-name dependency) " with Forge..."))
        (package-run! "forge" arguments)
        (unless (equal? (package-status dependency) 'ready)
          (error (string-append "package verification failed: "
                                (package-name dependency)))))))

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
