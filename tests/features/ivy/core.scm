(require "../../../features/ivy/core.scm")

(define (assert-equal! expected actual)
  (unless (equal? expected actual)
    (error! (string-append "expected " (to-string expected)
                           ", got " (to-string actual)))))

(define candidates
  (list (IvyCandidate "src/file-manager.scm" "" 'file "src/file-manager.scm")
        (IvyCandidate "README.md" "" 'readme "README.md")
        (IvyCandidate "file.scm" "" 'short "file.scm")))

(assert-equal! '("file.scm" "src/file-manager.scm")
  (map (lambda (match) (IvyCandidate-label (IvyMatch-candidate match)))
       (ivy-filter candidates "file")))

(assert-equal! '("src/file-manager.scm")
  (map (lambda (match) (IvyCandidate-label (IvyMatch-candidate match)))
       (ivy-filter candidates "sfm")))

(assert-equal! '() (ivy-filter candidates "File"))
(assert-equal! '("src/file-manager.scm" "README.md" "file.scm")
  (map (lambda (match) (IvyCandidate-label (IvyMatch-candidate match)))
       (ivy-filter candidates "")))
(assert-equal! '(1 2) (ivy-take '(1 2 3) 2))
(assert-equal! '(3) (ivy-drop '(1 2 3) 2))
