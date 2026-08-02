(require "helix/components.scm")
(require "helix/configuration.scm")
(require "helix/misc.scm")
(require (only-in "features/ui/text.scm"
                  ui-display-width
                  ui-fit-text))
(require "features/ivy/core.scm")
(require "features/ivy/state.scm")

(provide ivy-read
         ivy-update!)

(define *ivy-state* (ivy-state-empty))

(define (ivy-ref key)
  (ivy-state-ref *ivy-state* key))

(define (ivy-set! key value)
  (set! *ivy-state* (ivy-state-set *ivy-state* key value)))

(define (ivy-clamp value low high)
  (max low (min high value)))

(define (ivy-current-match)
  (and (pair? (ivy-ref 'matches))
       (list-ref (ivy-ref 'matches)
                 (ivy-clamp (ivy-ref 'selected) 0 (- (length (ivy-ref 'matches)) 1)))))

(define (ivy-current-candidate)
  (define match (ivy-current-match))
  (and match (IvyMatch-candidate match)))

(define (ivy-preview-current!)
  (define candidate (ivy-current-candidate))
  (when (and candidate (ivy-ref 'preview))
    ((ivy-ref 'preview) candidate)))

(define (ivy-refilter!)
  (when (ivy-ref 'update-candidates)
    (define updated ((ivy-ref 'update-candidates) (ivy-ref 'query)))
    (when (list? updated) (ivy-set! 'candidates updated)))
  (ivy-set! 'matches (ivy-filter (ivy-ref 'candidates) (ivy-ref 'query)))
  (ivy-set! 'selected
        (if (null? (ivy-ref 'matches))
            0
            (ivy-clamp (ivy-ref 'selected) 0 (- (length (ivy-ref 'matches)) 1))))
  (ivy-preview-current!))

(define (ivy-move! amount)
  (unless (null? (ivy-ref 'matches))
    (define total (length (ivy-ref 'matches)))
    (ivy-set! 'selected
              (modulo (+ (ivy-ref 'selected) amount) total))
    (ivy-preview-current!)))

(define (ivy-select! index)
  (when (and (>= index 0) (< index (length (ivy-ref 'matches))))
    (ivy-set! 'selected index)
    (ivy-preview-current!)))

(define (ivy-insert! value)
  (define query (ivy-ref 'query))
  (define cursor (ivy-ref 'input-cursor))
  (ivy-set! 'query
            (string-append (substring query 0 cursor)
                           value
                           (substring query cursor (string-length query))))
  (ivy-set! 'input-cursor (+ cursor (string-length value)))
  (ivy-set! 'selected 0)
  (ivy-refilter!))

(define (ivy-backspace!)
  (when (> (ivy-ref 'input-cursor) 0)
    (define query (ivy-ref 'query))
    (define cursor (ivy-ref 'input-cursor))
    (ivy-set! 'query
              (string-append (substring query 0 (- cursor 1))
                             (substring query cursor (string-length query))))
    (ivy-set! 'input-cursor (- cursor 1))
    (ivy-set! 'selected 0)
    (ivy-refilter!)))

(define (ivy-delete!)
  (when (< (ivy-ref 'input-cursor) (string-length (ivy-ref 'query)))
    (define query (ivy-ref 'query))
    (define cursor (ivy-ref 'input-cursor))
    (ivy-set! 'query
              (string-append (substring query 0 cursor)
                             (substring query (+ cursor 1) (string-length query))))
    (ivy-set! 'selected 0)
    (ivy-refilter!)))

(define (ivy-ctrl? event)
  (not (= 0 (bitwise-and (or (key-event-modifier event) 0) key-modifier-ctrl))))

(define (ivy-alt? event)
  (not (= 0 (bitwise-and (or (key-event-modifier event) 0) key-modifier-alt))))

(define (ivy-ctrl-char? event expected)
  (and (ivy-ctrl? event)
       (let ([ch (key-event-char event)])
         (and (char? ch) (char=? (char-downcase ch) expected)))))

(define (ivy-alt-char? event expected)
  (and (ivy-alt? event)
       (let ([ch (key-event-char event)])
         (and (char? ch) (char=? (char-downcase ch) expected)))))

(define (ivy-history-values)
  (if (and (ivy-ref 'history-key)
           (hash-contains? (ivy-ref 'histories) (ivy-ref 'history-key)))
      (hash-get (ivy-ref 'histories) (ivy-ref 'history-key))
      '()))

(define (ivy-record-history!)
  (when (and (ivy-ref 'history-key) (not (string=? (trim (ivy-ref 'query)) "")))
    (define values (ivy-history-values))
    (ivy-set! 'histories
              (hash-insert (ivy-ref 'histories) (ivy-ref 'history-key)
                           (ivy-take
                             (cons (ivy-ref 'query)
                                   (filter (lambda (value)
                                             (not (string=? value (ivy-ref 'query))))
                                           values))
                             50)))))

(define (ivy-use-history! direction)
  (define values (ivy-history-values))
  (unless (null? values)
    (when (= (ivy-ref 'history-index) -1)
      (ivy-set! 'history-draft (ivy-ref 'query)))
    (ivy-set! 'history-index
              (ivy-clamp (+ (ivy-ref 'history-index) direction) -1 (- (length values) 1)))
    (ivy-set! 'query
              (if (= (ivy-ref 'history-index) -1)
                  (ivy-ref 'history-draft)
                  (list-ref values (ivy-ref 'history-index))))
    (ivy-set! 'input-cursor (string-length (ivy-ref 'query)))
    (ivy-set! 'selected 0)
    (ivy-refilter!)))

(define (ivy-finish! callback value)
  (ivy-record-history!)
  (when callback
    (enqueue-thread-local-callback (lambda () (callback value))))
  event-result/close)

(define (ivy-accept-current!)
  (define candidate (ivy-current-candidate))
  (if (not candidate)
      event-result/consume
      (if (and (ivy-ref 'confirm) ((ivy-ref 'confirm) candidate))
          event-result/consume
          (ivy-finish! (ivy-ref 'accept) candidate))))

(define (ivy-handle-backspace!)
  (if (and (= (ivy-ref 'input-cursor) 0)
           (string=? (ivy-ref 'query) "")
           (ivy-ref 'empty-backspace))
      ((ivy-ref 'empty-backspace))
      (ivy-backspace!))
  event-result/consume)

(define (ivy-mouse-inside? event)
  (and (ivy-ref 'bounds)
       (let ([col (event-mouse-col event)]
             [row (event-mouse-row event)]
             [x (list-ref (ivy-ref 'bounds) 0)]
             [y (list-ref (ivy-ref 'bounds) 1)]
             [width (list-ref (ivy-ref 'bounds) 2)]
             [height (list-ref (ivy-ref 'bounds) 3)])
         (and col row
              (>= col x) (< col (+ x width))
              (>= row y) (< row (+ y height))))))

(define (ivy-mouse-candidate-index event)
  (and (ivy-ref 'bounds)
       (let* ([row (event-mouse-row event)]
              [candidates-y (list-ref (ivy-ref 'bounds) 5)]
              [visible-rows (list-ref (ivy-ref 'bounds) 6)]
              [start (list-ref (ivy-ref 'bounds) 7)]
              [row-offset (- row candidates-y)]
              [index (+ start row-offset)])
         (and (>= row-offset 0) (< row-offset visible-rows)
              (< index (length (ivy-ref 'matches)))
              index))))

(define (ivy-query-index-at-width target-width)
  (let loop ([index 0] [width 0])
    (if (>= index (string-length (ivy-ref 'query)))
        index
        (let ([next-width
                (+ width
                   (ui-display-width
                     (substring (ivy-ref 'query) index (+ index 1))))])
          (if (> next-width target-width)
              index
              (loop (+ index 1) next-width))))))

(define (ivy-position-input-cursor! event)
  (define prompt-y (list-ref (ivy-ref 'bounds) 4))
  (when (= (event-mouse-row event) prompt-y)
    (define query-x (+ (list-ref (ivy-ref 'bounds) 0) 2
                       (ui-display-width (ivy-ref 'prompt))))
    (ivy-set! 'input-cursor
              (ivy-query-index-at-width
                (max 0 (- (event-mouse-col event) query-x))))))

(define (ivy-handle-mouse event)
  (define kind (event-mouse-kind event))
  (if (not (ivy-mouse-inside? event))
      (if (= kind 0)
          (ivy-finish! (ivy-ref 'cancel) #f)
          event-result/ignore)
      (let ([index (ivy-mouse-candidate-index event)])
        (cond [(= kind 0)
               (if index
                   (begin
                     (ivy-select! index)
                     (ivy-accept-current!))
                   (begin
                     (ivy-position-input-cursor! event)
                     event-result/consume))]
              [(= kind 1)
               (when index (ivy-select! index))
               event-result/consume]
              [(= kind 10)
               (ivy-move! 1)
               event-result/consume]
              [(= kind 11)
               (ivy-move! -1)
               event-result/consume]
              [else event-result/consume]))))

(define (ivy-update! prompt candidates [initial ""])
  (ivy-set! 'prompt prompt)
  (ivy-set! 'query initial)
  (ivy-set! 'input-cursor (string-length initial))
  (ivy-set! 'candidates candidates)
  (ivy-set! 'selected 0)
  (ivy-refilter!))

(define (ivy-handle-event state event)
  (cond
    [(mouse-event? event) (ivy-handle-mouse event)]
    [(paste-event? event)
     (define value (paste-event-string event))
     (when value (ivy-insert! value))
     event-result/consume]
    [(key-event-escape? event) (ivy-finish! (ivy-ref 'cancel) #f)]
    [(ivy-alt-char? event #\p)
     (ivy-use-history! 1)
     event-result/consume]
    [(ivy-alt-char? event #\n)
     (ivy-use-history! -1)
     event-result/consume]
    [(and (key-event-enter? event) (ivy-ctrl? event) (ivy-ref 'raw-accept))
     (ivy-finish! (ivy-ref 'raw-accept) (ivy-ref 'query))]
    [(or (key-event-enter? event)
         (and (ivy-ref 'tab-accept?) (key-event-tab? event)))
     (ivy-accept-current!)]
    [(or (key-event-down? event) (ivy-ctrl-char? event #\n))
     (ivy-move! 1)
     event-result/consume]
    [(or (key-event-up? event) (ivy-ctrl-char? event #\p))
     (ivy-move! -1)
     event-result/consume]
    [(key-event-page-down? event)
     (ivy-move! (ivy-ref 'visible-rows))
     event-result/consume]
    [(key-event-page-up? event)
     (ivy-move! (- (ivy-ref 'visible-rows)))
     event-result/consume]
    [(key-event-left? event)
     (ivy-set! 'input-cursor (max 0 (- (ivy-ref 'input-cursor) 1)))
     event-result/consume]
    [(key-event-right? event)
     (ivy-set! 'input-cursor
               (min (string-length (ivy-ref 'query)) (+ (ivy-ref 'input-cursor) 1)))
     event-result/consume]
    [(key-event-home? event)
     (ivy-set! 'input-cursor 0)
     event-result/consume]
    [(key-event-end? event)
     (ivy-set! 'input-cursor (string-length (ivy-ref 'query)))
     event-result/consume]
    [(or (key-event-backspace? event) (ivy-ctrl-char? event #\h))
     (ivy-handle-backspace!)]
    [(key-event-delete? event)
     (ivy-delete!)
     event-result/consume]
    [(ivy-ctrl-char? event #\u)
     (ivy-set! 'query
               (substring (ivy-ref 'query)
                          (ivy-ref 'input-cursor)
                          (string-length (ivy-ref 'query))))
     (ivy-set! 'input-cursor 0)
     (ivy-set! 'selected 0)
     (ivy-refilter!)
     event-result/consume]
    [else
     (define ch (key-event-char event))
     (if (and (char? ch) (not (ivy-ctrl? event)))
         (begin (ivy-insert! (string ch)) event-result/consume)
         event-result/consume)]))

(define (ivy-panel-height rect)
  (min (area-height rect) (max 6 (min 12 (quotient (area-height rect) 2)))))

(define (ivy-prompt-title-length)
  (let loop ([index 0])
    (if (or (>= index (string-length (ivy-ref 'prompt)))
            (char-whitespace? (string-ref (ivy-ref 'prompt) index)))
        index
        (loop (+ index 1)))))

(define (ivy-render-prompt frame x y width text-style info-style)
  (define title-length (ivy-prompt-title-length))
  (define title (substring (ivy-ref 'prompt) 0 title-length))
  (define context (substring (ivy-ref 'prompt) title-length (string-length (ivy-ref 'prompt))))
  (define title-width (ui-display-width title))
  (define context-width (ui-display-width context))
  (define full-input (string-append (ivy-ref 'prompt) (ivy-ref 'query)))
  (if (<= (ui-display-width full-input) width)
      (begin
        (frame-set-string! frame x y title (style-with-bold info-style))
        (frame-set-string! frame (+ x title-width) y context text-style)
        (frame-set-string! frame (+ x title-width context-width) y
                           (ivy-ref 'query) (style-with-bold text-style)))
      (begin
        (frame-set-string! frame x y (ui-fit-text full-input width) text-style)
        (frame-set-string! frame x y (ui-fit-text title width)
                           (style-with-bold info-style)))))

(define (ivy-render-highlighted-label frame x y width match style match-style)
  (define label (IvyCandidate-label (IvyMatch-candidate match)))
  (define shown (ui-fit-text label width))
  (frame-set-string! frame x y shown style)
  (for-each
    (lambda (index)
      (when (< index (string-length shown))
        (frame-set-string! frame (+ x (ui-display-width (substring shown 0 index))) y
                           (substring shown index (+ index 1)) match-style)))
    (IvyMatch-positions match)))

(define (ivy-render state rect frame)
  (define height (ivy-panel-height rect))
  (define width (area-width rect))
  (define x (area-x rect))
  (define y (+ (area-y rect) (- (area-height rect) height)))
  (define background (theme-scope-ref "ui.background"))
  (define text-style (theme-scope-ref "ui.text"))
  (define info-style (theme-scope-ref "ui.text.info"))
  (define dim-style (theme-scope-ref "ui.text.inactive"))
  (define selected-style (style-with-bold info-style))
  (define match-style (style-with-bold info-style))
  (define list-rows (max 1 (- height 3)))
  (define prompt-y (+ y 1))
  (define candidates-y (+ y 3))
  (ivy-set! 'visible-rows list-rows)
  (buffer/clear-with frame (area x y width height) background)
  (block/render frame (area x y width height)
                (make-block background (theme-scope-ref "ui.window") "top" "plain"))
  (frame-set-string! frame (+ x 2) (+ y 2)
                     (make-string (max 0 (- width 4)) #\─)
                     (theme-scope-ref "ui.window"))
  (define total (length (ivy-ref 'matches)))
  (define start
    (if (<= total list-rows)
        0
        (max 0 (min (- total list-rows)
                    (- (ivy-ref 'selected) (quotient list-rows 2))))))
  (ivy-set! 'bounds
            (list x y width height prompt-y candidates-y list-rows start))
  (define visible (ivy-take (ivy-drop (ivy-ref 'matches) start) list-rows))
  (let loop ([matches visible] [row 0])
    (unless (or (null? matches) (>= row list-rows))
      (define match (car matches))
      (define candidate (IvyMatch-candidate match))
      (define selected? (= (+ start row) (ivy-ref 'selected)))
      (define annotation (IvyCandidate-annotation candidate))
      (define annotation-width (min (quotient width 2) (ui-display-width annotation)))
      (define label-width (max 1 (- width annotation-width 7)))
      (define candidate-style
        (if selected?
            selected-style
            (if (string=? annotation "dir") info-style text-style)))
      (when selected?
        (frame-set-string! frame (+ x 2) (+ candidates-y row) ">" selected-style))
      (ivy-render-highlighted-label frame (+ x 4) (+ candidates-y row) label-width match candidate-style
                                    (if selected? (style-with-bold selected-style) match-style))
      (when (and (> annotation-width 0) (> width (+ annotation-width 4)))
        (frame-set-string! frame (- (+ x width) annotation-width 3) (+ candidates-y row)
                           (ui-fit-text annotation annotation-width)
                           (style-with-dim (if selected? selected-style text-style))))
      (loop (cdr matches) (+ row 1))))
  (when (null? (ivy-ref 'matches))
    (frame-set-string! frame (+ x 4) candidates-y "No matches" dim-style))
  (define counter (string-append (number->string total) "/"
                                 (number->string (length (ivy-ref 'candidates)))))
  (ivy-render-prompt frame (+ x 2) prompt-y (- width 4)
                     text-style info-style)
  (when (> width (+ (ui-display-width (ivy-ref 'prompt))
                    (ui-display-width (ivy-ref 'query))
                    (string-length counter) 7))
    (frame-set-string! frame (- (+ x width) (string-length counter) 2) prompt-y counter dim-style)))

(define (ivy-cursor state rect)
  (define height (ivy-panel-height rect))
  (define panel-y (+ (area-y rect) (- (area-height rect) height)))
  (define y (+ panel-y 1))
  (define query-before-cursor (substring (ivy-ref 'query) 0 (ivy-ref 'input-cursor)))
  (position y (+ (area-x rect) 2 (ui-display-width (ivy-ref 'prompt))
                 (ui-display-width query-before-cursor))))

(define (ivy-read prompt candidates
                  #:initial [initial ""]
                  #:accept accept
                  #:confirm [confirm #f]
                  #:preview [preview #f]
                  #:cancel [cancel #f]
                  #:raw-accept [raw-accept #f]
                  #:empty-backspace [empty-backspace #f]
                  #:tab-accept [tab-accept? #f]
                  #:history [history-key #f]
                  #:update [update-candidates #f])
  (ivy-set! 'accept accept)
  (ivy-set! 'confirm confirm)
  (ivy-set! 'preview preview)
  (ivy-set! 'cancel cancel)
  (ivy-set! 'raw-accept raw-accept)
  (ivy-set! 'empty-backspace empty-backspace)
  (ivy-set! 'tab-accept? tab-accept?)
  (ivy-set! 'history-key history-key)
  (ivy-set! 'update-candidates update-candidates)
  (ivy-set! 'history-index -1)
  (ivy-set! 'history-draft initial)
  (ivy-set! 'bounds #f)
  (ivy-update! prompt candidates initial)
  (push-component!
    (new-component! "ivy" *ivy-state* ivy-render
                    (hash "handle_event" ivy-handle-event
                          "cursor" ivy-cursor))))
