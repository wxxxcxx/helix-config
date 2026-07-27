;; cogs/indicators/mode.scm
;; — mode indicator

(require "helix/components.scm")
(require "helix/editor.scm")
(require "cogs/indicators/style.scm")

(provide mode-style mode-indicator)

(define mode-labels
  (hash
    "normal" "❖ NORMAL "
    "insert" "❖ INSERT "
    "select" "❖ SELECT "))

(define (mode-name)
  (define mode (editor-mode))
  (cond
    [(equal? mode (string->editor-mode "insert")) "insert"]
    [(equal? mode (string->editor-mode "select")) "select"]
    [else "normal"]))

(define (mode-style)
  (theme-scope-ref (string-append "ui.statusline." (mode-name))))

(define (mode-indicator #:fg (fg #f) #:bg (bg #f)
                        #:placeholder (placeholder "❖ INACTIVE ")
                        #:left-arc? (left-arc? #f) #:left-arc-fg (left-arc-fg #f) #:left-arc-bg (left-arc-bg #f)
                        #:left-arc-char (left-arc-char "")
                        #:right-arc? (right-arc? #f) #:right-arc-fg (right-arc-fg #f) #:right-arc-bg (right-arc-bg #f)
                        #:right-arc-char (right-arc-char ""))
  (status-element
    (lambda (view-id focused?)
      (define s (~> (make-style fg bg focused?) style-with-bold))
      (if focused?
          (with-arcs
            (list (span (hash-ref mode-labels (mode-name))
                        s))
            #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
            #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char #:focused? focused?)
          (with-arcs '() #:placeholder placeholder #:placeholder-style s
                     #:left? left-arc? #:left-fg left-arc-fg #:left-bg left-arc-bg #:left-char left-arc-char
                     #:right? right-arc? #:right-fg right-arc-fg #:right-bg right-arc-bg #:right-char right-arc-char #:focused? focused?)))))
