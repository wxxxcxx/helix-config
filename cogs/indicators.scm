;; cogs/indicators.scm
;; Composable statusline indicator factories with color thunks

(require "helix/components.scm")
(require "helix/editor.scm")
(require "helix/misc.scm")
(require "helix/static.scm")
(require-builtin helix/core/text as text.)
(require "cogs/color.scm")
(require (only-in "helix/themes.scm" string->color))

;; ── Helpers ──────────────────────────────────────────────────────

(define (basename path)
  (let loop ([i (- (string-length path) 1)])
    (cond
      [(< i 0) path]
      [(char=? (string-ref path i) #\/)
       (substring path (+ i 1) (string-length path))]
      [else (loop (- i 1))])))

(define (parent-dir path)
  (let loop ([i (- (string-length path) 1)])
    (cond
      [(< i 0) "."]
      [(char=? (string-ref path i) #\/)
       (substring path 0 i)]
      [else (loop (- i 1))])))

(define *git-cache-dir* #f)
(define *git-cache-branch* #f)

(define (count-newlines s)
  (let loop ([i 0] [n 0])
    (if (>= i (string-length s))
        n
        (loop (+ i 1) (if (char=? (string-ref s i) #\newline) (+ n 1) n)))))

(define (buffer-text doc-id)
  (with-handler (lambda (err) "") (text.rope->string (editor->text doc-id))))

(define (git-branch doc-id)
  (define path (editor-document->path doc-id))
  (if path
      (let ([dir (parent-dir path)])
        (unless (and *git-cache-dir* (string=? dir *git-cache-dir*))
          (set! *git-cache-dir* dir)
          (set! *git-cache-branch*
            (with-handler
              (lambda (err) #f)
              (let* ([proc (~> (command "git" (list "-C" dir "rev-parse" "--abbrev-ref" "HEAD"))
                               with-stdout-piped
                               spawn-process)]
                     [ok? (Ok? proc)])
                (and ok?
                     (let ([raw (read-port-to-string (child-stdout (Ok->value proc)))])
                       (and (string? raw)
                            (let ([t (trim raw)])
                              (and (not (string=? t "")) t)))))))))
        *git-cache-branch*)
      #f))

;; ── Mode tracking ────────────────────────────────────────────────

(define *current-mode* "normal")

(define mode-labels
  (hash
    "normal" "❖ NORMAL "
    "insert" "❖ INSERT "
    "select" "❖ SELECT "))

(define insert-mode (string->editor-mode "insert"))
(define select-mode (string->editor-mode "select"))

(register-hook 'on-mode-switch
  (lambda (event)
    (define new-mode (mode-switch-new event))
    (cond
      [(equal? new-mode insert-mode) (set! *current-mode* "insert")]
      [(equal? new-mode select-mode) (set! *current-mode* "select")]
      [else (set! *current-mode* "normal")])))

;; ── Color thunks ─────────────────────────────────────────────────

(define (mode-style)
  (theme-scope-ref (string-append "ui.statusline." *current-mode*)))

(provide major-bg)

(define (major-bg)
  (or (style->bg (mode-style)) (style->fg (mode-style))))

(provide minor-bg)

(define (minor-bg)
  (darken (desaturate (major-bg) 0.3) 0.4))

(provide text-color)

(define (text-color) (string->color "#D8DEE9"))

(provide accent)

(define (accent) (string->color "#88C0D0"))

(provide dirty-color)

(define (dirty-color) (string->color "#BF616A"))

;; ── Internal helpers ─────────────────────────────────────────────

(define (named-style fg bg)
  (~> (style) (style-fg fg) (style-bg bg)))

(define (resolve-color arg)
  (if (procedure? arg) (arg) arg))

(provide auto-fg)
;;@doc
;; Wraps a bg thunk: returns a thunk that yields a light or dark
;; text color depending on the bg's luminance.
(define (auto-fg bg-fn)
  (lambda () (contrast-text (resolve-color bg-fn))))

;; ── Arc factories ────────────────────────────────────────────────

(provide make-left-arc)

(define (make-left-arc #:fg (fg-fn (lambda () Color/Reset))
                        #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (~> (style) (style-fg (resolve-color fg-fn)) (style-bg (resolve-color bg-fn))))))))

(provide make-right-arc)

(define (make-right-arc #:fg (fg-fn (lambda () Color/Reset))
                         #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (list (span "" (~> (style) (style-fg (resolve-color fg-fn)) (style-bg (resolve-color bg-fn))))))))

;; ── Mode indicator ───────────────────────────────────────────────

(provide make-mode-indicator)

(define (make-mode-indicator #:fg (fg-fn (lambda () Color/Reset))
                              #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (list
        (span (hash-ref mode-labels *current-mode*)
              (~> (style)
                  (style-fg (resolve-color fg-fn))
                  (style-bg (resolve-color bg-fn))
                  style-with-bold))))))

;; ── File name ────────────────────────────────────────────────────

(provide make-file-name)

(define (make-file-name #:fg (fg-fn (lambda () Color/Reset))
                         #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define name
        (let ([path (editor-document->path doc-id)])
          (and path (basename path))))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (list
        (span " " (named-style fg bg))
        (span (or name "[no name]") (named-style fg bg))
        (span " " (named-style fg bg))))))

;; ── File modification indicator ──────────────────────────────────

(provide make-modification-indicator)

(define (make-modification-indicator #:fg (fg-fn (lambda () Color/Reset))
                                      #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (if (editor-document-dirty? doc-id)
          (list
            (span "*" (named-style (dirty-color) bg))
            (span " " (named-style fg bg)))
          '()))))

;; ── Version control ──────────────────────────────────────────────

(provide make-version-control)

(define (make-version-control #:fg (fg-fn (lambda () Color/Reset))
                               #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define branch (git-branch doc-id))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (if branch
          (list
            (span "  " (named-style fg bg))
            (span branch (named-style fg bg))
            (span " " (named-style fg bg)))
          '()))))

;; ── Selections ───────────────────────────────────────────────────

(provide make-selections)

(define (make-selections #:fg (fg-fn (lambda () Color/Reset))
                          #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define sel (current-selection-object))
      (define count (length (selection->ranges sel)))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (list
        (span " " (named-style fg bg))
        (span (number->string count) (named-style fg bg))
        (span " " (named-style fg bg))))))

;; ── Position ─────────────────────────────────────────────────────

(provide make-position)

(define (make-position #:fg (fg-fn (lambda () Color/Reset))
                        #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define offset (cursor-position))
      (define text (buffer-text doc-id))
      (define total (max 1 (+ (count-newlines text) 1)))
      (define line (+ (count-newlines (substring text 0 offset)) 1))
      (define col
        (let ([ls
               (let loop ([i (- offset 1)])
                 (if (or (< i 0) (char=? (string-ref text i) #\newline))
                     (+ i 1)
                     (loop (- i 1))))])
          (- offset ls)))
      (define pct
        (if (> total 1)
            (clamp (inexact->exact (round (* 100.0 (/ (- line 1) (- total 1))))) 0 100)
            0))
      (define display (string-append " " (number->string line) ":" (number->string col)
                                     " " (number->string pct) "% "))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (list
        (span display
              (~> (style)
                  (style-fg fg)
                  (style-bg bg)))))))

;; ── File type ────────────────────────────────────────────────────

(provide make-file-type)

(define (make-file-type #:fg (fg-fn (lambda () Color/Reset))
                         #:bg (bg-fn (lambda () Color/Reset)))
  (status-element
    (lambda (view-id focused?)
      (define doc-id (editor->doc-id view-id))
      (define lang (or (editor-document->language doc-id) ""))
      (define bg (resolve-color bg-fn))
      (define fg (resolve-color fg-fn))
      (list
        (span " " (named-style fg bg))
        (span lang (named-style fg bg))
        (span " " (named-style fg bg))))))
