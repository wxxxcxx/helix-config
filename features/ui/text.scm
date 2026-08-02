(provide ui-char-width
         ui-display-width
         ui-fit-text)

(define (ui-char-width ch)
  (define code (char->integer ch))
  (cond
    ;; Combining marks, variation selectors, and joiners do not occupy a cell.
    [(or (and (>= code #x0300) (<= code #x036f))
         (and (>= code #x1ab0) (<= code #x1aff))
         (and (>= code #x1dc0) (<= code #x1dff))
         (and (>= code #x200b) (<= code #x200d))
         (and (>= code #x20d0) (<= code #x20ff))
         (and (>= code #xfe00) (<= code #xfe0f))
         (and (>= code #x1f3fb) (<= code #x1f3ff))
         (and (>= code #xfe20) (<= code #xfe2f)))
     0]
    ;; East Asian wide/full-width characters and common terminal emoji ranges.
    [(or (and (>= code #x1100) (<= code #x115f))
         (= code #x2329)
         (= code #x232a)
         (and (>= code #x2e80) (<= code #xa4cf))
         (and (>= code #xac00) (<= code #xd7a3))
         (and (>= code #xf900) (<= code #xfaff))
         (and (>= code #xfe10) (<= code #xfe19))
         (and (>= code #xfe30) (<= code #xfe6f))
         (and (>= code #xff00) (<= code #xff60))
         (and (>= code #xffe0) (<= code #xffe6))
         (and (>= code #x1f300) (<= code #x1faff))
         (and (>= code #x20000) (<= code #x3fffd)))
     2]
    [else 1]))

(define (ui-display-width text)
  (let loop ([index 0] [width 0])
    (if (>= index (string-length text))
        width
        (loop (+ index 1) (+ width (ui-char-width (string-ref text index)))))))

(define (ui-fit-text text width)
  (cond [(<= width 0) ""]
        [(<= (ui-display-width text) width) text]
        [(= width 1) "…"]
        [else
         (let loop ([index 0] [used 0])
           (if (or (>= index (string-length text))
                   (> (+ used (ui-char-width (string-ref text index))) (- width 1)))
               (string-append (substring text 0 index) "…")
               (loop (+ index 1)
                     (+ used (ui-char-width (string-ref text index))))))]))
