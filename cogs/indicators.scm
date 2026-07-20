;; cogs/indicators.scm
;; Aggregator — requires and re-provides all indicator modules

(require "cogs/indicators/core.scm")
(require "cogs/indicators/left-arc.scm")
(require "cogs/indicators/right-arc.scm")
(require "cogs/indicators/mode.scm")
(require "cogs/indicators/file-name.scm")
(require "cogs/indicators/version-control.scm")
(require "cogs/indicators/selections.scm")
(require "cogs/indicators/position.scm")
(require "cogs/indicators/file-type.scm")
(require "cogs/indicators/register.scm")

(provide named-style resolve-color auto-fg
         mode-style
         left-arc-indicator right-arc-indicator
         mode-indicator
         file-name-indicator modification-indicator version-control-indicator
         selections-indicator position-indicator file-type-indicator
         register-indicator)
