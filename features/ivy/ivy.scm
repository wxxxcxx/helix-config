(require "helix/components.scm")
(require "helix/configuration.scm")
(require "helix/misc.scm")
(require (only-in "features/file-manager/core/files.scm"
                  fm-display-width
                  fm-fit-text))
(require "features/ivy/core.scm")

(provide ivy-read
         ivy-update!)

(struct IvyComponentState ())

(define *ivy-prompt* "")
(define *ivy-query* "")
(define *ivy-input-cursor* 0)
(define *ivy-candidates* '())
(define *ivy-matches* '())
(define *ivy-selected* 0)
(define *ivy-visible-rows* 8)
(define *ivy-accept* #f)
(define *ivy-confirm* #f)
(define *ivy-preview* #f)
(define *ivy-cancel* #f)
(define *ivy-raw-accept* #f)
(define *ivy-empty-backspace* #f)
(define *ivy-tab-accept?* #f)
(define *ivy-history-key* #f)
(define *ivy-update-candidates* #f)
(define *ivy-histories* (hash))
(define *ivy-history-index* -1)
(define *ivy-history-draft* "")
(define *ivy-bounds* #f)

(define (ivy-clamp value low high)
  (max low (min high value)))

(define (ivy-current-match)
  (and (pair? *ivy-matches*)
       (list-ref *ivy-matches*
                 (ivy-clamp *ivy-selected* 0 (- (length *ivy-matches*) 1)))))

(define (ivy-current-candidate)
  (define match (ivy-current-match))
  (and match (IvyMatch-candidate match)))

(define (ivy-preview-current!)
  (define candidate (ivy-current-candidate))
  (when (and candidate *ivy-preview*)
    (*ivy-preview* candidate)))

(define (ivy-refilter!)
  (when *ivy-update-candidates*
    (define updated (*ivy-update-candidates* *ivy-query*))
    (when (list? updated) (set! *ivy-candidates* updated)))
  (set! *ivy-matches* (ivy-filter *ivy-candidates* *ivy-query*))
  (set! *ivy-selected*
        (if (null? *ivy-matches*)
            0
            (ivy-clamp *ivy-selected* 0 (- (length *ivy-matches*) 1))))
  (ivy-preview-current!))

(define (ivy-move! amount)
  (unless (null? *ivy-matches*)
    (define total (length *ivy-matches*))
    (set! *ivy-selected*
          (modulo (+ *ivy-selected* amount) total))
    (ivy-preview-current!)))

(define (ivy-select! index)
  (when (and (>= index 0) (< index (length *ivy-matches*)))
    (set! *ivy-selected* index)
    (ivy-preview-current!)))

(define (ivy-insert! value)
  (set! *ivy-query*
        (string-append (substring *ivy-query* 0 *ivy-input-cursor*)
                       value
                       (substring *ivy-query* *ivy-input-cursor* (string-length *ivy-query*))))
  (set! *ivy-input-cursor* (+ *ivy-input-cursor* (string-length value)))
  (set! *ivy-selected* 0)
  (ivy-refilter!))

(define (ivy-backspace!)
  (when (> *ivy-input-cursor* 0)
    (set! *ivy-query*
          (string-append (substring *ivy-query* 0 (- *ivy-input-cursor* 1))
                         (substring *ivy-query* *ivy-input-cursor* (string-length *ivy-query*))))
    (set! *ivy-input-cursor* (- *ivy-input-cursor* 1))
    (set! *ivy-selected* 0)
    (ivy-refilter!)))

(define (ivy-delete!)
  (when (< *ivy-input-cursor* (string-length *ivy-query*))
    (set! *ivy-query*
          (string-append (substring *ivy-query* 0 *ivy-input-cursor*)
                         (substring *ivy-query* (+ *ivy-input-cursor* 1)
                                    (string-length *ivy-query*))))
    (set! *ivy-selected* 0)
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
  (if (and *ivy-history-key* (hash-contains? *ivy-histories* *ivy-history-key*))
      (hash-get *ivy-histories* *ivy-history-key*)
      '()))

(define (ivy-record-history!)
  (when (and *ivy-history-key* (not (string=? (trim *ivy-query*) "")))
    (define values (ivy-history-values))
    (set! *ivy-histories*
          (hash-insert *ivy-histories* *ivy-history-key*
                       (ivy-take
                         (cons *ivy-query*
                               (filter (lambda (value) (not (string=? value *ivy-query*)))
                                       values))
                         50)))))

(define (ivy-use-history! direction)
  (define values (ivy-history-values))
  (unless (null? values)
    (when (= *ivy-history-index* -1)
      (set! *ivy-history-draft* *ivy-query*))
    (set! *ivy-history-index*
          (ivy-clamp (+ *ivy-history-index* direction) -1 (- (length values) 1)))
    (set! *ivy-query*
          (if (= *ivy-history-index* -1)
              *ivy-history-draft*
              (list-ref values *ivy-history-index*)))
    (set! *ivy-input-cursor* (string-length *ivy-query*))
    (set! *ivy-selected* 0)
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
      (if (and *ivy-confirm* (*ivy-confirm* candidate))
          event-result/consume
          (ivy-finish! *ivy-accept* candidate))))

(define (ivy-handle-backspace!)
  (if (and (= *ivy-input-cursor* 0)
           (string=? *ivy-query* "")
           *ivy-empty-backspace*)
      (*ivy-empty-backspace*)
      (ivy-backspace!))
  event-result/consume)

(define (ivy-mouse-inside? event)
  (and *ivy-bounds*
       (let ([col (event-mouse-col event)]
             [row (event-mouse-row event)]
             [x (list-ref *ivy-bounds* 0)]
             [y (list-ref *ivy-bounds* 1)]
             [width (list-ref *ivy-bounds* 2)]
             [height (list-ref *ivy-bounds* 3)])
         (and col row
              (>= col x) (< col (+ x width))
              (>= row y) (< row (+ y height))))))

(define (ivy-mouse-candidate-index event)
  (and *ivy-bounds*
       (let* ([row (event-mouse-row event)]
              [candidates-y (list-ref *ivy-bounds* 5)]
              [visible-rows (list-ref *ivy-bounds* 6)]
              [start (list-ref *ivy-bounds* 7)]
              [row-offset (- row candidates-y)]
              [index (+ start row-offset)])
         (and (>= row-offset 0) (< row-offset visible-rows)
              (< index (length *ivy-matches*))
              index))))

(define (ivy-query-index-at-width target-width)
  (let loop ([index 0] [width 0])
    (if (>= index (string-length *ivy-query*))
        index
        (let ([next-width
                (+ width
                   (fm-display-width
                     (substring *ivy-query* index (+ index 1))))])
          (if (> next-width target-width)
              index
              (loop (+ index 1) next-width))))))

(define (ivy-position-input-cursor! event)
  (define prompt-y (list-ref *ivy-bounds* 4))
  (when (= (event-mouse-row event) prompt-y)
    (define query-x (+ (list-ref *ivy-bounds* 0) 2
                       (fm-display-width *ivy-prompt*)))
    (set! *ivy-input-cursor*
          (ivy-query-index-at-width
            (max 0 (- (event-mouse-col event) query-x))))))

(define (ivy-handle-mouse event)
  (define kind (event-mouse-kind event))
  (if (not (ivy-mouse-inside? event))
      (if (= kind 0)
          (ivy-finish! *ivy-cancel* #f)
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
  (set! *ivy-prompt* prompt)
  (set! *ivy-query* initial)
  (set! *ivy-input-cursor* (string-length initial))
  (set! *ivy-candidates* candidates)
  (set! *ivy-selected* 0)
  (ivy-refilter!))

(define (ivy-handle-event state event)
  (cond
    [(mouse-event? event) (ivy-handle-mouse event)]
    [(paste-event? event)
     (define value (paste-event-string event))
     (when value (ivy-insert! value))
     event-result/consume]
    [(key-event-escape? event) (ivy-finish! *ivy-cancel* #f)]
    [(ivy-alt-char? event #\p)
     (ivy-use-history! 1)
     event-result/consume]
    [(ivy-alt-char? event #\n)
     (ivy-use-history! -1)
     event-result/consume]
    [(and (key-event-enter? event) (ivy-ctrl? event) *ivy-raw-accept*)
     (ivy-finish! *ivy-raw-accept* *ivy-query*)]
    [(or (key-event-enter? event)
         (and *ivy-tab-accept?* (key-event-tab? event)))
     (ivy-accept-current!)]
    [(or (key-event-down? event) (ivy-ctrl-char? event #\n))
     (ivy-move! 1)
     event-result/consume]
    [(or (key-event-up? event) (ivy-ctrl-char? event #\p))
     (ivy-move! -1)
     event-result/consume]
    [(key-event-page-down? event)
     (ivy-move! *ivy-visible-rows*)
     event-result/consume]
    [(key-event-page-up? event)
     (ivy-move! (- *ivy-visible-rows*))
     event-result/consume]
    [(key-event-left? event)
     (set! *ivy-input-cursor* (max 0 (- *ivy-input-cursor* 1)))
     event-result/consume]
    [(key-event-right? event)
     (set! *ivy-input-cursor* (min (string-length *ivy-query*) (+ *ivy-input-cursor* 1)))
     event-result/consume]
    [(key-event-home? event)
     (set! *ivy-input-cursor* 0)
     event-result/consume]
    [(key-event-end? event)
     (set! *ivy-input-cursor* (string-length *ivy-query*))
     event-result/consume]
    [(or (key-event-backspace? event) (ivy-ctrl-char? event #\h))
     (ivy-handle-backspace!)]
    [(key-event-delete? event)
     (ivy-delete!)
     event-result/consume]
    [(ivy-ctrl-char? event #\u)
     (set! *ivy-query* (substring *ivy-query* *ivy-input-cursor* (string-length *ivy-query*)))
     (set! *ivy-input-cursor* 0)
     (set! *ivy-selected* 0)
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
    (if (or (>= index (string-length *ivy-prompt*))
            (char-whitespace? (string-ref *ivy-prompt* index)))
        index
        (loop (+ index 1)))))

(define (ivy-render-prompt frame x y width text-style info-style)
  (define title-length (ivy-prompt-title-length))
  (define title (substring *ivy-prompt* 0 title-length))
  (define context (substring *ivy-prompt* title-length (string-length *ivy-prompt*)))
  (define title-width (fm-display-width title))
  (define context-width (fm-display-width context))
  (define full-input (string-append *ivy-prompt* *ivy-query*))
  (if (<= (fm-display-width full-input) width)
      (begin
        (frame-set-string! frame x y title (style-with-bold info-style))
        (frame-set-string! frame (+ x title-width) y context text-style)
        (frame-set-string! frame (+ x title-width context-width) y
                           *ivy-query* (style-with-bold text-style)))
      (begin
        (frame-set-string! frame x y (fm-fit-text full-input width) text-style)
        (frame-set-string! frame x y (fm-fit-text title width)
                           (style-with-bold info-style)))))

(define (ivy-render-highlighted-label frame x y width match style match-style)
  (define label (IvyCandidate-label (IvyMatch-candidate match)))
  (define shown (fm-fit-text label width))
  (frame-set-string! frame x y shown style)
  (for-each
    (lambda (index)
      (when (< index (string-length shown))
        (frame-set-string! frame (+ x (fm-display-width (substring shown 0 index))) y
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
  (set! *ivy-visible-rows* list-rows)
  (buffer/clear-with frame (area x y width height) background)
  (block/render frame (area x y width height)
                (make-block background (theme-scope-ref "ui.window") "top" "plain"))
  (frame-set-string! frame (+ x 2) (+ y 2)
                     (make-string (max 0 (- width 4)) #\─)
                     (theme-scope-ref "ui.window"))
  (define total (length *ivy-matches*))
  (define start
    (if (<= total list-rows)
        0
        (max 0 (min (- total list-rows)
                    (- *ivy-selected* (quotient list-rows 2))))))
  (set! *ivy-bounds*
        (list x y width height prompt-y candidates-y list-rows start))
  (define visible (ivy-take (ivy-drop *ivy-matches* start) list-rows))
  (let loop ([matches visible] [row 0])
    (unless (or (null? matches) (>= row list-rows))
      (define match (car matches))
      (define candidate (IvyMatch-candidate match))
      (define selected? (= (+ start row) *ivy-selected*))
      (define annotation (IvyCandidate-annotation candidate))
      (define annotation-width (min (quotient width 2) (fm-display-width annotation)))
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
                           (fm-fit-text annotation annotation-width)
                           (style-with-dim (if selected? selected-style text-style))))
      (loop (cdr matches) (+ row 1))))
  (when (null? *ivy-matches*)
    (frame-set-string! frame (+ x 4) candidates-y "No matches" dim-style))
  (define counter (string-append (number->string total) "/"
                                 (number->string (length *ivy-candidates*))))
  (ivy-render-prompt frame (+ x 2) prompt-y (- width 4)
                     text-style info-style)
  (when (> width (+ (fm-display-width *ivy-prompt*) (fm-display-width *ivy-query*)
                    (string-length counter) 7))
    (frame-set-string! frame (- (+ x width) (string-length counter) 2) prompt-y counter dim-style)))

(define (ivy-cursor state rect)
  (define height (ivy-panel-height rect))
  (define panel-y (+ (area-y rect) (- (area-height rect) height)))
  (define y (+ panel-y 1))
  (define query-before-cursor (substring *ivy-query* 0 *ivy-input-cursor*))
  (position y (+ (area-x rect) 2 (fm-display-width *ivy-prompt*)
                 (fm-display-width query-before-cursor))))

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
  (set! *ivy-accept* accept)
  (set! *ivy-confirm* confirm)
  (set! *ivy-preview* preview)
  (set! *ivy-cancel* cancel)
  (set! *ivy-raw-accept* raw-accept)
  (set! *ivy-empty-backspace* empty-backspace)
  (set! *ivy-tab-accept?* tab-accept?)
  (set! *ivy-history-key* history-key)
  (set! *ivy-update-candidates* update-candidates)
  (set! *ivy-history-index* -1)
  (set! *ivy-history-draft* initial)
  (set! *ivy-bounds* #f)
  (ivy-update! prompt candidates initial)
  (push-component!
    (new-component! "ivy" (IvyComponentState) ivy-render
                    (hash "handle_event" ivy-handle-event
                          "cursor" ivy-cursor))))
