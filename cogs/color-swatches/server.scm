(require-builtin steel/json)

(define hex-lengths '(3 4 6 8))
(define rgb-prefix "(Color/rgb")
(define *documents* (hash))

(define (starts-at? text index prefix)
  (define end (+ index (string-length prefix)))
  (and (<= end (string-length text))
       (string=? (substring text index end) prefix)))

(define (hex-digit? char)
  (define code (char->integer char))
  (or (and (>= code (char->integer #\0)) (<= code (char->integer #\9)))
      (and (>= code (char->integer #\a)) (<= code (char->integer #\f)))
      (and (>= code (char->integer #\A)) (<= code (char->integer #\F)))))

(define (decimal-digit? char)
  (define code (char->integer char))
  (and (>= code (char->integer #\0)) (<= code (char->integer #\9))))

(define (hex-match-length text start)
  (define length (string-length text))
  (if (or (>= start length)
          (not (char=? (string-ref text start) #\#))
          (and (> start 0) (hex-digit? (string-ref text (- start 1)))))
      #f
      (let loop ([index (+ start 1)] [count 0])
        (if (and (< index length)
                 (< count 8)
                 (hex-digit? (string-ref text index)))
            (loop (+ index 1) (+ count 1))
            (and (member count hex-lengths)
                 (or (>= index length)
                     (not (hex-digit? (string-ref text index))))
                 count)))))

(define (hex-channel value start width)
  (if (= width 1)
      (string->number
        (string (string-ref value start) (string-ref value start))
        16)
      (string->number (substring value start (+ start 2)) 16)))

(define (hex->color value)
  (define digits (- (string-length value) 1))
  (define width (if (or (= digits 3) (= digits 4)) 1 2))
  (define red (hex-channel value 1 width))
  (define green (hex-channel value (+ 1 width) width))
  (define blue (hex-channel value (+ 1 (* 2 width)) width))
  (define alpha
    (if (or (= digits 4) (= digits 8))
        (hex-channel value (+ 1 (* 3 width)) width)
        255))
  (hash "red" (/ red 255.0)
        "green" (/ green 255.0)
        "blue" (/ blue 255.0)
        "alpha" (/ alpha 255.0)))

(define (utf16-column text end)
  (let loop ([index 0] [column 0])
    (if (>= index end)
        column
        (loop (+ index 1)
              (+ column (if (> (char->integer (string-ref text index)) #xffff) 2 1))))))

(define (lsp-range line-number line start end)
  (hash "start" (hash "line" line-number
                      "character" (utf16-column line start))
        "end" (hash "line" line-number
                    "character" (utf16-column line end))))

(define (color-entry line-number line start end color)
  (hash "range" (lsp-range line-number line start end)
        "color" color))

(define (scan-generic-line line line-number)
  (let loop ([index 0] [colors '()])
    (if (>= index (string-length line))
        (reverse colors)
        (let ([match-length (hex-match-length line index)])
          (if match-length
              (let ([end (+ index match-length 1)])
                (loop end
                      (cons
                        (color-entry
                          line-number line index end
                          (hex->color (substring line index end)))
                        colors)))
              (loop (+ index 1) colors))))))

(define (generic-color-information text)
  (let loop ([lines (split-many text "\n")] [line-number 0] [colors '()])
    (if (null? lines)
        (reverse colors)
        (let ([line-colors (scan-generic-line (car lines) line-number)])
          (loop (cdr lines)
                (+ line-number 1)
                (append (reverse line-colors) colors))))))

(define (skip-whitespace text index)
  (if (and (< index (string-length text))
           (char-whitespace? (string-ref text index)))
      (skip-whitespace text (+ index 1))
      index))

(define (read-uint text start)
  (let loop ([index start])
    (if (and (< index (string-length text))
             (decimal-digit? (string-ref text index)))
        (loop (+ index 1))
        (and (> index start)
             (cons index (string->number (substring text start index)))))))

(define (parse-rgb text start)
  (and (starts-at? text start rgb-prefix)
       (let* ([after-prefix (+ start (string-length rgb-prefix))]
              [first-start (skip-whitespace text after-prefix)])
         (and (> first-start after-prefix)
              (let ([first (read-uint text first-start)])
                (and first
                     (let* ([second-start (skip-whitespace text (car first))]
                            [second (and (> second-start (car first))
                                         (read-uint text second-start))])
                       (and second
                            (let* ([third-start (skip-whitespace text (car second))]
                                   [third (and (> third-start (car second))
                                               (read-uint text third-start))])
                              (and third
                                   (let ([end (skip-whitespace text (car third))]
                                         [red (cdr first)]
                                         [green (cdr second)]
                                         [blue (cdr third)])
                                     (and (< end (string-length text))
                                          (char=? (string-ref text end) #\))
                                          (<= red 255)
                                          (<= green 255)
                                          (<= blue 255)
                                          (list (+ end 1) red green blue)))))))))))))

;; Returns (block-comment-depth . colors-in-reverse-order).
(define (scan-scheme-line line line-number initial-depth)
  (let loop ([index 0]
             [block-depth initial-depth]
             [in-string? #f]
             [escaped? #f]
             [colors '()])
    (cond
      [(>= index (string-length line)) (cons block-depth colors)]
      [(> block-depth 0)
       (cond [(starts-at? line index "#|")
              (loop (+ index 2) (+ block-depth 1) #f #f colors)]
             [(starts-at? line index "|#")
              (loop (+ index 2) (- block-depth 1) #f #f colors)]
             [else (loop (+ index 1) block-depth #f #f colors)])]
      [in-string?
       (define match-length (hex-match-length line index))
       (cond [match-length
              (define end (+ index match-length 1))
              (loop end block-depth #t #f
                    (cons
                      (color-entry
                        line-number line index end
                        (hex->color (substring line index end)))
                      colors))]
             [escaped?
              (loop (+ index 1) block-depth #t #f colors)]
             [(char=? (string-ref line index) #\\)
              (loop (+ index 1) block-depth #t #t colors)]
             [(char=? (string-ref line index) #\")
              (loop (+ index 1) block-depth #f #f colors)]
             [else (loop (+ index 1) block-depth #t #f colors)])]
      [(starts-at? line index "#|")
       (loop (+ index 2) 1 #f #f colors)]
      [(char=? (string-ref line index) #\;) (cons block-depth colors)]
      [(char=? (string-ref line index) #\")
       (loop (+ index 1) block-depth #t #f colors)]
      [else
       (define rgb (parse-rgb line index))
       (if rgb
           (let ([end (list-ref rgb 0)]
                 [red (list-ref rgb 1)]
                 [green (list-ref rgb 2)]
                 [blue (list-ref rgb 3)])
             (loop end block-depth #f #f
                   (cons
                     (color-entry
                       line-number line index end
                       (hash "red" (/ red 255.0)
                             "green" (/ green 255.0)
                             "blue" (/ blue 255.0)
                             "alpha" 1.0))
                     colors)))
           (loop (+ index 1) block-depth #f #f colors))])))

(define (scheme-color-information text)
  (let loop ([lines (split-many text "\n")]
             [line-number 0]
             [block-depth 0]
             [colors '()])
    (if (null? lines)
        (reverse colors)
        (let ([result (scan-scheme-line (car lines) line-number block-depth)])
          (loop (cdr lines)
                (+ line-number 1)
                (car result)
                (append (cdr result) colors))))))

(define (document-color-information document)
  (define text (or (hash-try-get document 'text) ""))
  (if (string=? (or (hash-try-get document 'languageId) "") "scheme")
      (scheme-color-information text)
      (generic-color-information text)))

(define (read-content-length)
  (let loop ([content-length #f])
    (define line (read-line))
    (cond [(eof-object? line) #f]
          [(string=? (trim line) "") content-length]
          [else
           (define parts (split-many line ":"))
           (define next-length
             (if (and (>= (length parts) 2)
                      (string=? (string-downcase (trim (car parts))) "content-length"))
                 (string->number (trim (list-ref parts 1)))
                 content-length))
           (loop next-length)])))

(define (read-exact-bytes amount)
  (let loop ([remaining amount] [result (bytes)])
    (if (= remaining 0)
        result
        (let ([chunk (read-bytes remaining)])
          (if (eof-object? chunk)
              #f
              (loop (- remaining (bytes-length chunk))
                    (bytes-append result chunk)))))))

(define (read-message)
  (define content-length (read-content-length))
  (and content-length
       (let ([body (read-exact-bytes content-length)])
         (and body (string->jsexpr (bytes->string/utf8 body))))))

(define (send-message payload)
  (define body (string->bytes (value->jsexpr-string payload)))
  (write-string (string-append "Content-Length: "
                               (number->string (bytes-length body))
                               "\r\n\r\n"))
  (write-bytes body)
  (flush-output-port (current-output-port)))

;; Steel's JSON reader represents every JSON number as a float. LSP request IDs
;; are integers, so restore their exact representation before serializing them.
(define (normalize-request-id id)
  (if (number? id)
      (string->number (car (split-many (number->string id) ".")))
      id))

(define (handle-message message)
  (define method (hash-try-get message 'method))
  (define params (or (hash-try-get message 'params) (hash)))
  (cond
    [(string=? method "initialize")
     (hash "capabilities"
           (hash "colorProvider" #t
                 "textDocumentSync" (hash "openClose" #t "change" 1))
           "serverInfo" (hash "name" "color-swatches" "version" "3"))]
    [(string=? method "shutdown") void]
    [(string=? method "textDocument/didOpen")
     (define document (hash-try-get params 'textDocument))
     (define uri (hash-try-get document 'uri))
     (set! *documents*
           (hash-insert
             *documents* uri
             (hash 'languageId (or (hash-try-get document 'languageId) "")
                   'text (hash-try-get document 'text))))
     void]
    [(string=? method "textDocument/didChange")
     (define document-id (hash-try-get params 'textDocument))
     (define uri (hash-try-get document-id 'uri))
     (define changes (or (hash-try-get params 'contentChanges) '()))
     (unless (null? changes)
       (define current
         (or (hash-try-get *documents* uri)
             (hash 'languageId "" 'text "")))
       (set! *documents*
             (hash-insert
               *documents* uri
               (hash-insert current 'text (hash-try-get (last changes) 'text)))))
     void]
    [(string=? method "textDocument/didClose")
     (define uri (hash-try-get (hash-try-get params 'textDocument) 'uri))
     (set! *documents* (hash-remove *documents* uri))
     void]
    [(string=? method "textDocument/documentColor")
     (define uri (hash-try-get (hash-try-get params 'textDocument) 'uri))
     (document-color-information
       (or (hash-try-get *documents* uri)
           (hash 'languageId "" 'text "")))]
    [else void]))

(define (main)
  (let loop ()
    (define message (read-message))
    (when message
      (define method (hash-try-get message 'method))
      (unless (and method (string=? method "exit"))
        (if (hash-contains? message 'id)
            (let ([id (normalize-request-id (hash-try-get message 'id))])
              (with-handler
                (lambda (error)
                  (send-message
                    (hash "jsonrpc" "2.0"
                          "id" id
                          "error" (hash "code" -32603
                                        "message" (to-string error)))))
                (send-message
                  (hash "jsonrpc" "2.0"
                        "id" id
                        "result" (handle-message message)))))
            (handle-message message))
        (loop)))))

(main)
