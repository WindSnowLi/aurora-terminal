# pwsh-setup — PowerShell 7 全功能终端环境

[![License: MIT](https://img.shields.io/badge/License-MIT-2DD4BF.svg)](../LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.4%2B-FB7185.svg)](../README.md#兼容性与要求)

< [返回仓库首页](../README.md)

一套可直接带走的 PowerShell 7 配置：**oh-my-posh（aurora 主题）+ zoxide + eza + bat + fd + rg + fzf + lazygit + btop + fastfetch + delta**，
外加 posh-git / Terminal-Icons / PSFzf / ConsoleGuiTools 与深度调优的 PSReadLine。附一键还原脚本。

> 也想要 zsh？同仓库的 [zsh-setup](../zsh-setup/README.md) 是配套的 MSYS2 + Oh My Zsh + Powerlevel10k 方案（与本包视觉统一）。

## 目录结构

| 文件 | 用途 |
| --- | --- |
| `Microsoft.PowerShell_profile.ps1` | 主配置：可移植路径、按需降级、各个工具接线、PSReadLine 调优、`Test-PwshEnv` 自检 |
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
3. 按需安装 JetBrainsMono Nerd Font（已有 Nerd Font 则跳过）
4. 部署 profile / 主题 / fastfetch 配置（内容相同则跳过，有差异则备份为 `.bak-<时间戳>`）
5. 执行策略仅在过严时改为 `RemoteSigned`（CurrentUser）
6. 若 `core.pager` 未设置，把 delta 设为 git 分页器（可用 `-SkipGitDelta` 跳过）
7. 合并 Windows Terminal 设置（先备份）并做主题渲染 + 组件自检

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
| `which` / `mkcd` / `reload` / `..` `...` `....` | PowerShell 友好替代 |

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