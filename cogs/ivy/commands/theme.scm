(require (only-in "helix/commands.scm" theme))
(require (only-in "helix/editor.scm" themes->list))
(require (only-in "helix/themes.scm" current-theme-name))
(require (only-in "cogs/ivy/core.scm"
                  IvyCandidate
                  IvyCandidate-value))
(require (only-in "cogs/ivy/ivy.scm" ivy-read))

(provide ivy-theme)

(define (ivy-theme-candidates current)
  (define names (themes->list))
  (map (lambda (name)
         (IvyCandidate name "theme" name name))
       (cons current
             (filter (lambda (name) (not (string=? name current))) names))))

(define (ivy-theme-apply candidate)
  (theme (IvyCandidate-value candidate)))

(define (ivy-theme)
  (define original (current-theme-name))
  (ivy-read "Theme  " (ivy-theme-candidates original)
            #:accept ivy-theme-apply
            #:preview ivy-theme-apply
            #:cancel (lambda (_) (theme original))
            #:history 'theme))
