(require "helix/misc.scm")
(require (only-in "helix/commands.scm" open goto-line goto-column))
(require (only-in "helix/static.scm" get-helix-cwd))
(require (only-in "cogs/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value
                  ivy-drop))
(require (only-in "cogs/ivy/ivy.scm" ivy-read))

(provide ivy-project-search)

(struct IvyProjectMatch (path line column))

(define *ivy-project-search-query* #f)
(define *ivy-project-search-results* '())
(define *ivy-project-search-warned?* #f)

(define (ivy-project-relative-path root path)
  (define prefix (string-append (trim-end-matches root (path-separator))
                                (path-separator)))
  (if (starts-with? path prefix)
      (substring path (string-length prefix) (string-length path))
      path))

(define (ivy-project-run-rg root query)
  (with-handler
    (lambda (error-value)
      (unless *ivy-project-search-warned?*
        (set! *ivy-project-search-warned?* #t)
        (set-warning! (string-append "Project search failed: "
                                     (to-string error-value))))
      "")
    (let ([process
            (~> (command "rg"
                         (list "--line-number"
                               "--column"
                               "--no-heading"
                               "--color" "never"
                               "--smart-case"
                               "--fixed-strings"
                               "--hidden"
                               "--glob" "!.git/*"
                               "--max-columns" "500"
                               "--field-match-separator" "\t"
                               "--" query root))
                with-stdout-piped
                spawn-process)])
      (if (not (Ok? process))
          ""
          (let* ([child (Ok->value process)]
                 [output (read-port-to-string (child-stdout child))])
            (wait child)
            output)))))

(define (ivy-project-result-candidate root line)
  (define fields (split-many line "\t"))
  (and (>= (length fields) 4)
       (let* ([path (car fields)]
              [line-number (string->number (list-ref fields 1))]
              [column (string->number (list-ref fields 2))]
              [content (trim (string-join (ivy-drop fields 3) "\t"))]
              [relative (ivy-project-relative-path root path)])
         (and line-number column
              (IvyCandidate (if (string=? content "") relative content)
                            (string-append relative ":"
                                           (number->string line-number) ":"
                                           (number->string column))
                            (IvyProjectMatch path line-number column)
                            (string-append relative " " content))))))

(define (ivy-project-candidates root query)
  (if (< (string-length (trim query)) 2)
      '()
      (let loop ([lines (split-many (ivy-project-run-rg root query) "\n")]
                 [count 0]
                 [result '()])
        (if (or (null? lines) (>= count 400))
            (reverse result)
            (let ([candidate (ivy-project-result-candidate root (car lines))])
              (loop (cdr lines)
                    (if candidate (+ count 1) count)
                    (if candidate (cons candidate result) result)))))))

(define (ivy-project-update root query)
  (unless (and *ivy-project-search-query*
               (string=? query *ivy-project-search-query*))
    (set! *ivy-project-search-query* query)
    (set! *ivy-project-search-results* (ivy-project-candidates root query)))
  *ivy-project-search-results*)

(define (ivy-project-open candidate)
  (define match (IvyCandidate-value candidate))
  (open (IvyProjectMatch-path match))
  (goto-line (IvyProjectMatch-line match))
  (goto-column (max 0 (- (IvyProjectMatch-column match) 1))))

(define (ivy-project-search)
  (define root (get-helix-cwd))
  (set! *ivy-project-search-query* #f)
  (set! *ivy-project-search-results* '())
  (set! *ivy-project-search-warned?* #f)
  (ivy-read (string-append "Search project  " root "  ") '()
            #:accept ivy-project-open
            #:history 'project-search
            #:update (lambda (query) (ivy-project-update root query))))
