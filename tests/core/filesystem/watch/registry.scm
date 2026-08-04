(require "../../../../core/filesystem/watch/registry.scm")

(define (assert-equal! expected actual message)
  (unless (equal? expected actual)
    (error! (string-append message
                           ": expected " (to-string expected)
                           ", got " (to-string actual)))))

(define active? #f)
(define snapshot-value 1)
(define changes '())

(filesystem-watch-register!
  'fixture
  (lambda () active?)
  (lambda () snapshot-value)
  (lambda (previous current)
    (set! changes (cons (list previous current) changes))))

(assert-equal! #f (filesystem-watch-refresh! 'fixture)
               "inactive watcher is skipped")
(assert-equal! '() changes
               "inactive watcher does not invoke its callback")

(set! active? #t)
(assert-equal! #t (filesystem-watch-refresh! 'fixture)
               "first active capture invokes its callback")
(assert-equal! (list (list #f 1)) changes
               "first callback receives no previous snapshot")
(assert-equal! #f (filesystem-watch-refresh! 'fixture)
               "equal snapshot is ignored")

(set! snapshot-value 2)
(assert-equal! #t (filesystem-watch-refresh! 'fixture)
               "changed snapshot invokes its callback")
(assert-equal! (list (list 1 2) (list #f 1)) changes
               "changed callback receives both snapshots")

(filesystem-watch-unregister! 'fixture)
(assert-equal! #f (filesystem-watch-refresh! 'fixture)
               "unregistered watcher is absent")
(filesystem-watch-clear!)
