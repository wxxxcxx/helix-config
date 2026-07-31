# AGENTS.md

Helix 编辑器配置，基于 [mattwparas/helix](https://github.com/mattwparas/helix) 分支，使用 Steel（Scheme 方言）配置。

## 参考

- `~/.local/share/steel/cogs/helix/*.scm` — 官方 Helix 内置函数 Steel 包装
- https://mattwparas.github.io/steel/book/introduction.html Steel 语言文档
- https://mattwparas.github.io/steel/book/reference/builtins.html Steel 函数速查
- https://mattwparas.github.io/steel/book/generated/logging.html Steel 日志函数
- [mattwparas/helix-config](https://github.com/mattwparas/helix-config) — 分支作者的示例
- `~/.cache/helix/helix.log` 默认日志文件位置，可以使用tail读取

## 架构

- `init.scm` 是唯一入口（启动时运行）。子模块在 require 时不得产生副作用 —— 用 `provide` 导出函数，在 `init.scm` 中调用它们。
- 配置即函数调用：`(line-number 'relative)`、`(soft-wrap (sw-enable #t))`。


## 风格与注意事项

- 线程宏：`(~> value fn1 fn2)`
- require 只需要个别函数时优先使用 `only-in`：`(require (only-in "helix/themes.scm" string->color))`，必要时用 `prefix-in` 为长名称创建别名：`(require (prefix-in theme. "helix/themes.scm"))`，；
- require 路径相对于项目根目录或 `~/.local/share/steel/cogs/`
- 哈希表：`(hash 'key value)`，用 `hash-union` 合并
- 主题作用域是字符串：`"ui.statusline.normal"`
- 错误/警告：`(error! ...)` / `(set-warning! ...)`
- 模式比较：`(string->editor-mode "insert")`，用 `equal?`（不是 `eq?`）
- 自定义状态栏元素：`(status-element (lambda (doc-id focused?) ...))`
- Shell 命令：`(spawn-process (command "name" '("arg1" "arg2")))`
- 钩子：`(register-hook 'on-mode-switch (lambda (event) ...))`
- `runtime/` 和 `steel/` 被 gitignore（外部生成/同步）
