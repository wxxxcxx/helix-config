(require "features/file-manager/core/session.scm")
(require "features/file-manager/file-explorer/preview.scm")

(provide fe-ref
         fe-set!
         fe-state-ref
         fe-state-set!
         fe-reset-open-state!)

(define (fe-initial-state)
  (hash 'active #f
        'path ""
        'workspace-root ""
        'parent-files '()
        'files '()
        'all-parent-files '()
        'all-files '()
        'cursor-row 0
        'col-scroll (vector 0 0)
        'show-hidden #f
        'content-h 0
        'parent-cursor 0
        'scrolls (hash)
        'parent-scrolls (hash)
        'session (fm-session-empty)
        'preview (fe-preview-empty)
        'filter-query ""
        'filter-before-input ""
        'find-query ""
        'sort-mode 'name
        'sort-reverse? #f
        'pending-action #f
        'key-prefix ""
        'help-visible? #f
        'bookmarks '()))

(define *fe-state* (fe-initial-state))

(define (fe-ref key)
  (hash-get *fe-state* key))

(define (fe-set! key value)
  (set! *fe-state* (hash-insert *fe-state* key value)))

;; The renderer only reads this snapshot and reports its usable height.
(define (fe-state-ref key)
  (cond [(equal? key 'path) (fe-ref 'path)]
        [(equal? key 'parent-files) (fe-ref 'parent-files)]
        [(equal? key 'files) (fe-ref 'files)]
        [(equal? key 'cursor-row) (fe-ref 'cursor-row)]
        [(equal? key 'col-scroll) (fe-ref 'col-scroll)]
        [(equal? key 'show-hidden) (fe-ref 'show-hidden)]
        [(equal? key 'parent-cursor) (fe-ref 'parent-cursor)]
        [(equal? key 'marked) (fm-session-marked (fe-ref 'session))]
        [(equal? key 'clipboard) (fm-session-clipboard (fe-ref 'session))]
        [(equal? key 'clipboard-mode) (fm-session-mode (fe-ref 'session))]
        [(equal? key 'filter-query) (fe-ref 'filter-query)]
        [(equal? key 'filtering?) (equal? (fe-ref 'pending-action) 'filter)]
        [(equal? key 'sort-mode) (fe-ref 'sort-mode)]
        [(equal? key 'sort-reverse?) (fe-ref 'sort-reverse?)]
        [(equal? key 'bookmarks) (fe-ref 'bookmarks)]
        [(equal? key 'preview) (fe-ref 'preview)]
        [else #f]))

(define (fe-state-set! key value)
  (when (equal? key 'content-h)
    (fe-set! 'content-h value)))

(define (fe-reset-open-state!)
  (fe-set! 'active #t)
  (fe-set! 'filter-query "")
  (fe-set! 'filter-before-input "")
  (fe-set! 'find-query "")
  (fe-set! 'pending-action #f)
  (fe-set! 'key-prefix "")
  (fe-set! 'help-visible? #f)
  (fe-set! 'session (fm-session-empty))
  (fe-set! 'preview (fe-preview-empty)))
