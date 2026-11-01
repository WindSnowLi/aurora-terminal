# Changelog

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Added

- PowerShell 配置新增**系统代理同步**：启动时读取注册表 `Internet Settings` 的 `ProxyEnable` / `ProxyServer` / `ProxyOverride`，
  翻译成 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY`（`<local>` 展开、`192.168.*` → `192.168.0.0/16` 等）
  - 只在启动时读取一次，不做后台监听；改完系统代理后新开标签页生效，当前会话可用 `Sync-SystemProxy` 手动刷新
  - `HTTPS_PROXY` 使用 `http://host:port`（变量名只表示代理哪类请求），显式带 scheme 的 `ProxyServer` 原样保留
  - 系统代理关闭时不设置任何变量，并清理本会话里由 profile 写入的值
  - 新增 `Sync-SystemProxy` / `Get-SystemProxy` / `Test-SystemProxy [-Probe]`（`-Probe` 会对比「期望/实际」环境变量、显示 WinHTTP 状态并用 curl 实测连通性），`Test-PwshEnv` 增加 `system-proxy` 状态行，`PWSH_SYNC_SYSTEM_PROXY=0` 可关闭
- 新增 `Microsoft.VSCode_profile.ps1`：VS Code 的 PowerShell 集成控制台是独立宿主（只加载该文件），
  安装脚本会把它部署到 profile 目录并转交主配置，避免 VS Code 里没有提示符/别名/代理环境变量

### Removed

- 移除 `zsh-setup`（MSYS2 + Oh My Zsh + Powerlevel10k 方案）：仓库只维护 PowerShell 7 一条主线，
  `.zshrc`、`.p10k.zsh`、`Install-ZshEnv.ps1`、`windows-terminal/zsh-profile.json`、`packages.txt` 及其 README 一并删除，
  根 README 的特性表、快速开始、目录结构、兼容性说明、故障排查与卸载中的 zsh 内容同步清理

### Fixed

- 连按 `Tab` 清空整条命令：Tab handler 里多余的 `PSConsoleReadLine::RevertLine()` 会撤销当前行的全部编辑，
  第一次 Tab 关掉列表预测、第二次 Tab 就把命令行清空，PSFzf 随后读到空行直接返回。已改为直接调用 `Invoke-FzfTabCompletion`
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