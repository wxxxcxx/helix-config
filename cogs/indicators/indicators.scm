;; cogs/indicators.scm
;; Aggregator — requires and re-provides all indicator modules

(require "cogs/indicators/mode.scm")
(require "cogs/indicators/file-name.scm")
(require "cogs/indicators/version-control.scm")
(require "cogs/indicators/selections.scm")
(require "cogs/indicators/position.scm")
(require "cogs/indicators/file-type.scm")
(require "cogs/indicators/register.scm")
(require "cogs/indicators/buffers.scm")

(provide mode-indicator
         file-name-indicator version-control-indicator
         selections-indicator position-indicator file-type-indicator
         register-indicator buffers-indicator)
