(require (only-in "cogs/file-manager/core/collections.scm" fm-member?))

(provide fm-session-empty
         fm-session-marked fm-session-clipboard fm-session-mode fm-session-register
         fm-session-toggle-mark fm-session-stage fm-session-clear-clipboard
         fm-session-clear-marks fm-session-prune-marks
         fm-session-complete-paths fm-session-replace-path
         fm-session-with-register fm-session-reset-register)

(struct FmSession (marked clipboard mode register))

(define (fm-session-empty)
  (FmSession '() '() #f #\+))

(define (fm-session-marked session) (FmSession-marked session))
(define (fm-session-clipboard session) (FmSession-clipboard session))
(define (fm-session-mode session) (FmSession-mode session))
(define (fm-session-register session) (FmSession-register session))

(define (fm-list-remove value values)
  (cond [(null? values) '()]
        [(equal? value (car values)) (fm-list-remove value (cdr values))]
        [else (cons (car values) (fm-list-remove value (cdr values)))]))

(define (fm-list-replace value replacement values)
  (cond [(null? values) '()]
        [(equal? value (car values))
         (cons replacement (fm-list-replace value replacement (cdr values)))]
        [else (cons (car values) (fm-list-replace value replacement (cdr values)))]))

(define (fm-remove-paths values paths)
  (filter (lambda (value) (not (fm-member? value paths))) values))

(define (fm-session-toggle-mark session path)
  (define marked (FmSession-marked session))
  (FmSession (if (fm-member? path marked)
                 (fm-list-remove path marked)
                 (cons path marked))
             (FmSession-clipboard session)
             (FmSession-mode session)
             (FmSession-register session)))

(define (fm-session-stage session mode paths)
  (FmSession '() paths mode (FmSession-register session)))

(define (fm-session-clear-clipboard session)
  (FmSession (FmSession-marked session) '() #f (FmSession-register session)))

(define (fm-session-clear-marks session)
  (FmSession '()
             (FmSession-clipboard session)
             (FmSession-mode session)
             (FmSession-register session)))

(define (fm-session-prune-marks session predicate)
  (FmSession (filter predicate (FmSession-marked session))
             (FmSession-clipboard session)
             (FmSession-mode session)
             (FmSession-register session)))

;; A completed destructive operation clears marks and removes only affected
;; paths from the staged operation, preserving unrelated staged entries.
(define (fm-session-complete-paths session paths)
  (let ([remaining (fm-remove-paths (FmSession-clipboard session) paths)])
    (FmSession '()
               remaining
               (if (null? remaining) #f (FmSession-mode session))
               (FmSession-register session))))

(define (fm-session-replace-path session old-path new-path)
  (FmSession (fm-list-replace old-path new-path (FmSession-marked session))
             (fm-list-replace old-path new-path (FmSession-clipboard session))
             (FmSession-mode session)
             (FmSession-register session)))

(define (fm-session-with-register session register)
  (FmSession (FmSession-marked session)
             (FmSession-clipboard session)
             (FmSession-mode session)
             register))

(define (fm-session-reset-register session)
  (fm-session-with-register session #\+))
