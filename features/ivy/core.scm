(require (only-in "../../core/list.scm"
                  list-drop
                  list-take))

(provide IvyCandidate
         IvyCandidate?
         IvyCandidate-label
         IvyCandidate-annotation
         IvyCandidate-value
         IvyCandidate-search
         IvyMatch?
         IvyMatch-candidate
         IvyMatch-score
         IvyMatch-positions
         ivy-filter
         ivy-take
         ivy-drop)

(struct IvyCandidate (label annotation value search))
(struct IvyMatch (candidate score positions))

(define (ivy-take values count)
  (list-take values count))

(define (ivy-drop values count)
  (list-drop values count))

(define (ivy-uppercase? ch)
  (and (char=? ch (char-upcase ch))
       (not (char=? ch (char-downcase ch)))))

(define (ivy-lowercase? ch)
  (and (char=? ch (char-downcase ch))
       (not (char=? ch (char-upcase ch)))))

(define (ivy-smart-case? query)
  (let loop ([index 0])
    (cond [(>= index (string-length query)) #f]
          [(ivy-uppercase? (string-ref query index)) #t]
          [else (loop (+ index 1))])))

(define (ivy-boundary? text index)
  (or (= index 0)
      (let ([previous (string-ref text (- index 1))]
            [current (string-ref text index)])
        (or (char-whitespace? previous)
            (char=? previous #\/)
            (char=? previous #\\)
            (char=? previous #\-)
            (char=? previous #\_)
            (char=? previous #\.)
            (and (ivy-lowercase? previous)
                 (ivy-uppercase? current))))))

(define (ivy-query-char? ch)
  (not (char-whitespace? ch)))

(define (ivy-match-text text query)
  (define case-sensitive? (ivy-smart-case? query))
  (define haystack (if case-sensitive? text (string-downcase text)))
  (define needle (if case-sensitive? query (string-downcase query)))
  (let loop ([query-index 0]
             [text-index 0]
             [previous-index -2]
             [score 0]
             [positions '()])
    (cond
      [(>= query-index (string-length needle))
       (list (- score (if (null? positions) 0 (car (reverse positions))))
             (reverse positions))]
      [(not (ivy-query-char? (string-ref needle query-index)))
       (loop (+ query-index 1) text-index previous-index score positions)]
      [else
       (define wanted (string-ref needle query-index))
       (let seek ([index text-index])
         (cond
           [(>= index (string-length haystack)) #f]
           [(char=? wanted (string-ref haystack index))
            (define consecutive? (= index (+ previous-index 1)))
            (define bonus (+ 10
                             (if (= index 0) 30 0)
                             (if (ivy-boundary? text index) 18 0)
                             (if consecutive? 22 0)))
            (loop (+ query-index 1)
                  (+ index 1)
                  index
                  (+ score bonus)
                  (cons index positions))]
           [else (seek (+ index 1))]))])))

(define (ivy-candidate-match candidate query)
  (define result (ivy-match-text (IvyCandidate-search candidate) query))
  (and result
       (IvyMatch candidate (car result) (list-ref result 1))))

(define (ivy-match<? left right)
  (if (= (IvyMatch-score left) (IvyMatch-score right))
      (string<? (string-downcase (IvyCandidate-label (IvyMatch-candidate left)))
                (string-downcase (IvyCandidate-label (IvyMatch-candidate right))))
      (> (IvyMatch-score left) (IvyMatch-score right))))

(define (ivy-filter candidates query)
  (if (string=? (trim query) "")
      (map (lambda (candidate) (IvyMatch candidate 0 '())) candidates)
      (sort (filter (lambda (value) value)
                    (map (lambda (candidate) (ivy-candidate-match candidate query))
                         candidates))
            ivy-match<?)))
