(provide filesystem-watch-register!
         filesystem-watch-unregister!
         filesystem-watch-refresh!
         filesystem-watch-refresh-all!
         filesystem-watch-clear!)

(struct FilesystemWatch (active? snapshot on-change captured? value))

(define *filesystem-watches* (hash))

;; Registers or replaces one named watcher without capturing its initial state.
(define (filesystem-watch-register! name active? snapshot on-change)
  (set! *filesystem-watches*
        (hash-insert *filesystem-watches*
                     name
                     (FilesystemWatch active? snapshot on-change #f #f))))

;; Removes a watcher so its lifecycle callbacks can no longer run.
(define (filesystem-watch-unregister! name)
  (set! *filesystem-watches* (hash-remove *filesystem-watches* name)))

(define (filesystem-watch-log-error name error-value)
  (displayln
    (string-append "filesystem watcher "
                   (symbol->string name)
                   " failed: "
                   (error-object-message error-value))))

;; Captures one active watcher and invokes its callback only after a change.
(define (filesystem-watch-refresh! name)
  (define watcher (hash-try-get *filesystem-watches* name))
  (if (and watcher ((FilesystemWatch-active? watcher)))
      (with-handler
        (lambda (error-value)
          (filesystem-watch-log-error name error-value)
          #f)
        (let* ([current ((FilesystemWatch-snapshot watcher))]
               [changed? (or (not (FilesystemWatch-captured? watcher))
                             (not (equal? (FilesystemWatch-value watcher) current)))])
          (if (not changed?)
              #f
              (begin
                ((FilesystemWatch-on-change watcher)
                 (and (FilesystemWatch-captured? watcher)
                      (FilesystemWatch-value watcher))
                 current)
                (set! *filesystem-watches*
                      (hash-insert
                        *filesystem-watches*
                        name
                        (FilesystemWatch (FilesystemWatch-active? watcher)
                                         (FilesystemWatch-snapshot watcher)
                                         (FilesystemWatch-on-change watcher)
                                         #t
                                         current)))
                #t))))
      #f))

;; Refreshes every registered watcher; individual failures remain isolated.
(define (filesystem-watch-refresh-all!)
  (for-each filesystem-watch-refresh!
            (hash-keys->list *filesystem-watches*)))

;; Clears registry state for deterministic reinitialization and focused tests.
(define (filesystem-watch-clear!)
  (set! *filesystem-watches* (hash)))
