;; Public statusline indicator exports.
;; Aggregator — requires and re-provides all indicator modules

(require "features/statusline/indicators/mode.scm")
(require "features/statusline/indicators/file-name.scm")
(require "features/statusline/indicators/version-control.scm")
(require "features/statusline/indicators/selections.scm")
(require "features/statusline/indicators/position.scm")
(require "features/statusline/indicators/file-type.scm")
(require "features/statusline/indicators/register.scm")
(require "features/statusline/indicators/buffers.scm")

(provide mode-indicator
         file-name-indicator version-control-indicator version-control-init
         selections-indicator position-indicator file-type-indicator
         register-indicator buffers-indicator)
