;; cogs/splash.scm

(require "helix/components.scm")
(require "helix/misc.scm")

(provide splash-show splash-smart-show)

(define splash-text
  "
 .
 ###x.        .|
 d#####x,   ,v||
  '+#####v||||||
     ,v|||||+'.      _     _           _
  ,v|||||^'>####    | |   | |   ___   | | (_) __  __
 |||||^'  .v####    | |___| |  /   \\  | |  _  \\ \\/ /
 ||||=..v#####P'    |  ___  | /  ^  | | | | |  \\  /
 ''v'>#####P'       | |   | | |  ---  | | | |  /  \\
 ,######/P||x.      |_|   |_|  \\___/  |_| |_| /_/\\_\\
 ####P' \"x|||||,
 |/'       'x|||    (A (post-modern (modal (text editor)))).
  '           '|")

(define splash-lines (split-many splash-text "\n"))
(define splash-width (apply max (map string-length splash-lines)))
(define splash-height (length splash-lines))

(struct Splash ())

(define (splash-render state rect frame)
  (define x (- (round (/ (area-width rect) 2)) (round (/ splash-width 2))))
  (define y (round (/ (area-height rect) 4)))
  (define bg-style (theme-scope "ui.background"))
  (define code-style (theme-scope "string"))
  (buffer/clear-with frame rect bg-style)
  (let loop ([lines splash-lines] [i 0])
    (when (not (null? lines))
      (frame-set-string! frame x (+ y i) (car lines) code-style)
      (loop (cdr lines) (+ i 1)))))

(define (splash-event-handler _ event)
  (if (key-event? event) event-result/ignore-and-close event-result/ignore))

(define (splash-show)
  (push-component! (new-component! "splash"
                                    (Splash)
                                    splash-render
                                    (hash "handle_event" splash-event-handler))))

(define (splash-smart-show)
  (define args (cdr (command-line)))
  (define (has-file? lst)
    (and (not (null? lst))
         (or (not (char=? (string-ref (car lst) 0) #\-))
             (has-file? (cdr lst)))))
  (unless (has-file? args)
    (splash-show)))
