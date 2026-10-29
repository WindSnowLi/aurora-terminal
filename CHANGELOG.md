# Changelog

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Fixed

- `Install-PwshEnv.ps1` 不再整份覆盖 Windows Terminal `settings.json`，改为合并 Aurora 配色/主题/`profiles.defaults` 并保留用户已有的 profile、键位与配色（仍会先备份）
- Windows Terminal 配置字体名改为 `JetBrainsMono NF`（Nerd Fonts 3.4+ 家族名），修复提示符图标显示为方块的问题
- `oh-my-posh font install` 在部分环境不退出导致安装脚本挂起，改为带 5 分钟超时等待
- 提示符图标显示为 `?`：合并 WT 设置时把默认 profile 上写死的非 Nerd 字体家族换成 `JetBrainsMono NF`（保留字号），并把耗时段图标从 `\ufbab`（Nerd Fonts 3.x 无此字形）改为 `\uf2f2`

## [1.0.0] - 2026-10-28

### Added

- **PowerShell 7 环境（主力）**
  - oh-my-posh + aurora 主题（Powerline 段、git 状态、命令耗时、右侧时间、终端标题）
  - posh-git（首次 Tab 时按需加载）、Terminal-Icons、PSFzf、ConsoleGuiTools
  - PSReadLine 调优：`HistoryAndPlugin` 预测、列表视图、F2 切换、F7 历史网格、前缀历史搜索
  - `$PSStyle` 目录与扩展名配色、fastfetch 启动横幅（`PWSH_NO_FASTFETCH` 可关）
  - 现代 CLI 接线：zoxide（`z`/`zi`）、eza（`ll`/`la`/`lt`/`tree`）、bat（`catp`/`batp`）、fzf、fd、ripgrep、lazygit（`lg`）、btop、delta
  - `Test-PwshEnv` 健康检查、`Install-PwshEnv.ps1` 幂等安装脚本
- **zsh 环境（可选）**
  - MSYS2 UCRT64 便携安装（免管理员）、Oh My Zsh、Powerlevel10k（Aurora 配色）
  - 插件：zsh-autosuggestions、zsh-syntax-highlighting、zsh-completions、fzf-tab、sudo、extract、colored-man-pages、cp、web-search
  - 同款 fastfetch 横幅、Windows Terminal profile 合并、`Install-ZshEnv.ps1` 幂等安装脚本
- 仓库标准化：MIT 许可证、`.gitignore`、`.gitattributes`、`.editorconfig`、根 README 与 CHANGELOG

### Fixed

- `Style: roundrocket is not available`：`executiontime` 段 `properties.style` 拼写错误（`roundrocket` → `roundrock`）
- 终端标题模板引用不存在的 `{{ .Git.Branch }}`，导致每次刷新抛 `can't evaluate field Git`，改为 `{{ .Segments.Git.HEAD }}`
- zoxide 在 Cygwin/MSYS 下生成的 `__zoxide_pwd` 缺少命令替换，报 `not a directory: C:\builtin pwd -L`，改为覆盖实现
- Powerlevel10k 的 gitstatus 守护进程在 MSYS 无法初始化，改为内置回退实现
- `CompletionPredictor` 在 PowerShell 7.6 下导入死锁，已从配置移除

### Performance

- PowerShell 启动从 1.98 s 优化到约 1.6 s（posh-git 延迟到首次 Tab 加载）