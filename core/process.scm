(provide core-process-output
         core-process-trimmed-output)

;; Captures a child process's complete stdout, returning #f when spawning fails.
(define (core-process-output program arguments)
  (let ([process (~> (command program arguments)
                     with-stdout-piped
                     spawn-process)])
    (and (Ok? process)
         (read-port-to-string (child-stdout (Ok->value process))))))

;; Captures stdout and removes surrounding whitespace while preserving #f failures.
(define (core-process-trimmed-output program arguments)
  (define output (core-process-output program arguments))
  (and output (trim output)))
