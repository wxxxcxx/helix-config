;; features/splash/splash.scm

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

(struct Splash (load-time-ms))

(define (splash-load-time-label state)
  (define load-time-ms (Splash-load-time-ms state))
  (and load-time-ms
       (string-append "Features loaded in "
                      (number->string load-time-ms)
                      " ms")))

(define (splash-render state rect frame)
  (define x (- (round (/ (area-width rect) 2)) (round (/ splash-width 2))))
  (define y (round (/ (area-height rect) 4)))
  (define bg-style (theme-scope "ui.background"))
  (define code-style (theme-scope "string"))
  (define info-style (theme-scope "ui.text.inactive"))
  (buffer/clear-with frame rect bg-style)
  (let loop ([lines splash-lines] [i 0])
    (when (not (null? lines))
      (frame-set-string! frame x (+ y i) (car lines) code-style)
      (loop (cdr lines) (+ i 1))))
  (define load-time-label (splash-load-time-label state))
  (when load-time-label
    (define label-x
      (- (round (/ (area-width rect) 2))
         (round (/ (string-length load-time-label) 2))))
    (frame-set-string! frame label-x (+ y splash-height 1)
                       load-time-label info-style)))

(define (splash-event-handler _ event)
  (if (key-event? event) event-result/ignore-and-close event-result/ignore))

(define (splash-show [load-time-ms #f])
  (push-component! (new-component! "splash"
                                    (Splash load-time-ms)
                                    splash-render
                                    (hash "handle_event" splash-event-handler))))

(define (splash-smart-show [load-time-ms #f])
  (define args (cdr (command-line)))
  (define (has-file? lst)
    (and (not (null? lst))
         (or (not (char=? (string-ref (car lst) 0) #\-))
             (has-file? (cdr lst)))))
  (unless (has-file? args)
    (splash-show load-time-ms)))
