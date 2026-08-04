(require "../../core/process.scm")

(define (assert-equal! expected actual message)
  (unless (equal? expected actual)
    (error! (string-append message
                           ": expected " (to-string expected)
                           ", got " (to-string actual)))))

(define output
  (if (equal? (current-os!) "windows")
      (core-process-trimmed-output
        "powershell.exe"
        (list "-NoProfile" "-Command" "Write-Output shared-core"))
      (core-process-trimmed-output
        "sh"
        (list "-c" "printf shared-core"))))

(assert-equal! "shared-core" output
               "captured process output is trimmed")
