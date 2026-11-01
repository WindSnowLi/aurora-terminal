# pwsh-setup — PowerShell 7 全功能终端环境

[![License: MIT](https://img.shields.io/badge/License-MIT-2DD4BF.svg)](../LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.4%2B-FB7185.svg)](../README.md#兼容性与要求)

< [返回仓库首页](../README.md)

一套可直接带走的 PowerShell 7 配置：**oh-my-posh（aurora 主题）+ zoxide + eza + bat + fd + rg + fzf + lazygit + btop + fastfetch + delta**，
外加 posh-git / Terminal-Icons / PSFzf / ConsoleGuiTools、系统代理自动同步与深度调优的 PSReadLine。附一键还原脚本。

## 目录结构

| 文件 | 用途 |
| --- | --- |
| `Microsoft.PowerShell_profile.ps1` | 主配置：可移植路径、按需降级、各个工具接线、PSReadLine 调优、系统代理同步、`Test-PwshEnv` 自检 |
| `Microsoft.VSCode_profile.ps1` | VS Code 集成控制台（独立宿主）的入口，转交主配置 |
| `themes/aurora.omp.json` | oh-my-posh 主题（深色 aurora） |
| `fastfetch/aurora.jsonc` | 启动横幅（系统/内存/磁盘/IP） |
| `Install-PwshEnv.ps1` | 一键安装 + 部署 + 自检（幂等） |
| `windows-terminal/settings.json` | Windows Terminal 参考配置（Aurora Night 配色、字体、背景） |
| `packages.txt` | winget / PSGallery 依赖清单 |

## 一键还原（新机器）

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install-PwshEnv.ps1
```

脚本做的事：

1. winget 安装 oh-my-posh、fzf、zoxide、eza、bat、fd、ripgrep、fastfetch、btop4win、delta、lazygit
2. PSGallery 安装 posh-git、Terminal-Icons、PSFzf、ConsoleGuiTools
3. 按需安装 JetBrainsMono Nerd Font（家族名 `JetBrainsMono NF`，已有 Nerd Font 则跳过）
4. 部署 profile / 主题 / fastfetch 配置（内容相同则跳过，有差异则备份为 `.bak-<时间戳>`）
5. 执行策略仅在过严时改为 `RemoteSigned`（CurrentUser）
6. 若 `core.pager` 未设置，把 delta 设为 git 分页器（可用 `-SkipGitDelta` 跳过）
7. 合并 Windows Terminal 设置（先备份）：只叠加 Aurora 配色、主题与 profile 默认值，已有的 profile / 键位 / 配色原样保留

开关：`-SkipModules`、`-SkipFont`、`-SkipTerminalSettings`、`-SkipGitDelta`、`-Force`。

## 命令与别名

| 命令 | 说明 |
| --- | --- |
| `ll` / `la` / `lt` / `tree` | eza：长列表（含 git 状态）/ 含隐藏项 / 两层树 / 树 |
| `catp` / `batp` | bat 高亮查看（不覆盖原生 `cat`，脚本里 `Get-Content` 语义不受影响） |
| `lg` | lazygit（终端 Git UI） |
| `btop` | btop4win（CPU/内存/进程实时监控） |
| `ff` | fastfetch（也可直接看启动横幅） |
| `z 关键词` / `zi` | zoxide 智能跳转 / 交互选择 |
| `ocgv` | Out-ConsoleGridView 网格化选择（`Get-Process \| ocgv`） |
| `Sync-SystemProxy` | 立即把系统代理重新同步成环境变量（改完系统代理不想新开标签页时用；`-Quiet` 不输出提示） |
| `Get-SystemProxy` | 查看系统代理与解析出的 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` |
| `Test-SystemProxy [-Probe]` | 排障：注册表原始值 → 应设置的值 → 当前进程实际值；`-Probe` 再用 curl 实测连通性 |
| `which` / `mkcd` / `reload` / `..` `...` `....` | PowerShell 友好替代 |

## 系统代理

Windows 的「系统代理」（设置 → 网络和 Internet → 代理，或 Internet 选项 → 局域网设置）只对 WinINet / HTTP.SYS 生效，
`curl`、`git`、`npm`、`pip`、`gh` 这类命令行工具只认环境变量。profile 在**启动时读取一次**注册表
`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` 的 `ProxyEnable` / `ProxyServer` / `ProxyOverride`，
翻译成环境变量；交互式会话会打印一行确认，形如 `系统代理: http://127.0.0.1:7897 → HTTP_PROXY / HTTPS_PROXY / NO_PROXY`。
不做后台监听：系统代理改过之后，新开的标签页自动生效；当前会话想立刻刷新就执行 `Sync-SystemProxy`。

| 系统代理设置 | 环境变量 |
| --- | --- |
| `ProxyServer` = `127.0.0.1:7897` | `HTTP_PROXY` = `http://127.0.0.1:7897`、`HTTPS_PROXY` = `http://127.0.0.1:7897` |
| `ProxyServer` = `http=…;https=…;socks=…`（逐协议） | 分别取 `http` / `https` / `socks`（只有其一时 http 与 https 互为兜底），`socks` → `ALL_PROXY=socks5://…` |
| `ProxyOverride` = `localhost;127.*;192.168.*;<local>` | `NO_PROXY`：`<local>` 展开为 `localhost,127.0.0.1,::1`，`192.168.*` 转成 `192.168.0.0/16`，`*.corp.com` → `.corp.com` |

> `HTTPS_PROXY` 也写成 `http://host:port`：变量名只表示「代理哪类请求」，不代表要用 TLS 连代理。
> 写成 `https://127.0.0.1:7897` 会让 curl / git 用 TLS 去连一个明文代理，直接连不上（`curl` 返回 `000`）。
> 如果 `ProxyServer` 本身写了 scheme（例如 `https://proxy:443`），则原样保留。

行为约定：

- 每个会话启动时重新读取，覆盖继承来的同名变量（系统代理是权威来源）
- 系统代理关闭（`ProxyEnable=0`）时不设置任何变量；本会话里之前由 profile 写入的值会被清掉
- `AutoConfigURL`（PAC 脚本）无法静态解析，会跳过并在 `Test-PwshEnv` 里标明
- 想确认状态：`Get-SystemProxy` 或 `Test-PwshEnv`（有 `system-proxy` 一行）；怀疑没生效就运行 `Test-SystemProxy -Probe`，
  它会一起列出注册表值、应设置的值、当前进程实际值，并用 curl 实测一次（`HTTP 200` 表示真的走通代理）
- VS Code 的「PowerShell 集成控制台」是独立宿主，安装脚本会额外部署 `Microsoft.VSCode_profile.ps1` 转交主配置

开关：`PWSH_SYNC_SYSTEM_PROXY=0` 完全关闭同步。

## 快捷键

| 键 | 功能 |
| --- | --- |
| `Tab` | fzf 模糊补全（带 eza 预览），无 PSFzf 时退回原生菜单补全 |
| `Ctrl+R` | 历史模糊搜索 |
| `Ctrl+T` | 选中文件插入命令行 |
| `F2` | 内联预测 ⇄ 列表预测 切换 |
| `F7` | 历史记录网格选择（ConsoleGuiTools） |
| `↑` / `↓` | 按前缀搜索历史 |
| `Ctrl+D` | 空行时退出 |

## 视觉与体验

- 提示符：oh-my-posh aurora 主题（Powerline 段、git 状态、耗时、右侧时间），终端标题自动跟随目录与分支
- 目录/扩展名配色：`$PSStyle` 定制（目录青色加粗、`.ps1` 紫色、`.json` 琥珀……）
- 文件图标：Terminal-Icons；eza 输出带 Nerd Font 图标与 git 标记
- 启动横幅：fastfetch（不想看就设环境变量 `PWSH_NO_FASTFETCH=1`）
- 预测：PSReadLine `HistoryAndPlugin` + ListView，预测文字用低调灰色
- git diff：delta（行号、导航、移动检测）

## 启动速度

实测（Windows Terminal 新标签页，含 fastfetch 横幅）：**约 1.6s 到首个提示符**。

优化手段：
- `posh-git`（约 0.45s）不随启动加载，改为**第一次按 Tab 补全时**才导入，git 补全功能不打折
- `Terminal-Icons`（约 0.3s）保留在启动阶段，保证 `ls` 一开始就有图标
- 主题与模块全部走轻量解析，缺件时静默降级，避免报错拖慢启动

## 已修复的问题

1. **`Style: roundrocket is not available`**：主题 `executiontime` 段的 `properties.style` 拼写错误，
   oh-my-posh 只接受 `roundrock`/`austin`/`dallas`/`galveston`/`houston`/`sanantonio`/`sugarland`。
2. **标题模板报错**：`console_title_template` 引用了标题上下文不存在的 `{{ .Git.Branch }}`，
   已改为 `{{ .Segments.Git }}` / `{{ .Segments.Git.HEAD }}`。
3. **CompletionPredictor 卡死**：PowerShell 7.6 下 `Import-Module CompletionPredictor` 会挂起，
   已从配置移除（`PredictionSource` 仍为 `HistoryAndPlugin`，不影响使用）。
4. **Windows Terminal 配置被整份覆盖**：旧版安装脚本会直接替换 `settings.json`，导致用户自己的
   WSL / SSH profile、自定义配色和键位丢失。现在改为合并：只写入 Aurora 配色、主题与 `profiles.defaults`，
   其余内容保留并先备份；`backgroundImage` 指向的图片不存在时自动跳过。
5. **字体家族名对不上**：Nerd Fonts 3.4+ 的家族名是 `JetBrainsMono NF`，旧配置写死 `JetBrainsMono Nerd Font`，
   终端找不到字体就回退默认字体，提示符出现方块。现已改为 `JetBrainsMono NF`。
6. **`oh-my-posh font install` 不退出**：部分环境下它打印 “Successfully installed” 后进程仍驻留并占住管道，
   会让安装脚本一直卡住；现在改为最多等待 5 分钟，超时后结束该进程并重新检测字体是否已写入。
7. **提示符图标显示为 `?`**：两个原因叠加 —— profile 里写死的字体（如 `Fira Code`）优先级高于
   `profiles.defaults`，以及耗时段的 `\ufbab` 在 Nerd Fonts 3.x 里没有字形。现在合并时会把默认 profile
   的非 Nerd 字体家族换成 `JetBrainsMono NF`（字号保留），耗时图标改用 `\uf2f2`。
8. **连按 `Tab` 会把整条命令清空**：Tab handler 里多了一句 `PSConsoleReadLine::RevertLine()`，
   而它在没有"已接受的预测"时会**撤销当前行的全部编辑**（PSReadLine 源码里就是循环 `_edits[i].Undo()`）。
   第一次 Tab 只是关掉列表预测，第二次 Tab 就把命令行清空；随后 PSFzf 的 `Invoke-FzfTabCompletionInner`
   读到空行直接 `return $false`，于是什么都没补全。已删除该调用，按 PSFzf 官方方式只调 `Invoke-FzfTabCompletion`
   （替换范围由 PSFzf 用 `ReplacementIndex` / `ReplacementLength` 自己算）。

## 手动恢复（不想跑脚本）

```powershell
winget install --id JanDeDobbeleer.OhMyPosh --exact
winget install --id junegunn.fzf,ajeetdsouza.zoxide,eza-community.eza,sharkdp.bat,sharkdp.fd --exact
winget install --id BurntSushi.ripgrep.MSVC,Fastfetch-cli.Fastfetch,aristocratos.btop4win,dandavison.delta,JesseDuffield.lazygit --exact
Install-Module posh-git, Terminal-Icons, PSFzf, Microsoft.PowerShell.ConsoleGuiTools -Scope CurrentUser -Force

$dir = "$env:USERPROFILE\Documents\PowerShell"
New-Item -ItemType Directory "$dir\themes","$dir\fastfetch","$env:USERPROFILE\.config\oh-my-posh" -Force | Out-Null
Copy-Item .\Microsoft.PowerShell_profile.ps1 $dir -Force
Copy-Item .\themes\aurora.omp.json "$dir\themes\aurora.omp.json" -Force
Copy-Item .\themes\aurora.omp.json "$env:USERPROFILE\.config\oh-my-posh\aurora.omp.json" -Force
Copy-Item .\fastfetch\aurora.jsonc "$dir\fastfetch\aurora.jsonc" -Force
```

## 定制要点

- 主题查找顺序：`<profile 目录>\themes\aurora.omp.json` → `~\.config\oh-my-posh\aurora.omp.json`，改完 `. $PROFILE` 生效
- 常用段可调项：`path.max_depth`（路径深度）、`executiontime.threshold`（毫秒）/`style`、`git.fetch_status`（实时查远端，关闭可提速）
- 想改别名/键位：直接编辑 profile 里对应小节；缺件时 profile 会静默降级，不会报错
- 系统代理同步：`Get-SystemProxy` 看当前解析结果，`Sync-SystemProxy` 手动刷新；不要同步就设 `PWSH_SYNC_SYSTEM_PROXY=0`