# Aurora Terminal

> 一套「好看、好用、功能全」的 Windows 终端环境配置：**PowerShell 7 为主力，zsh 可选**，共用同一套 Aurora 深色配色。

[![License: MIT](https://img.shields.io/badge/License-MIT-2DD4BF.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-A78BFA.svg)](#兼容性与要求)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.4%2B-FB7185.svg)](#兼容性与要求)
[![Shell](https://img.shields.io/badge/Shell-oh--my--posh%20%7C%20powerlevel10k-34D399.svg)](#特性)

配置即代码：所有 dotfile 与一键还原脚本都在仓库里，换机器只需一条命令。

---

## 特性

| 能力 | PowerShell 7（主力） | zsh（可选） |
| --- | --- | --- |
| 提示符 | oh-my-posh · aurora 主题（Powerline、git 状态、耗时、右侧时间） | Powerlevel10k · 同色系 |
| 补全 | Tab → fzf 模糊补全（带 eza 预览）、posh-git | Tab → fzf-tab、zsh-completions |
| 历史 | Ctrl+R 模糊搜索、↑↓ 前缀搜索、F7 网格选择 | Ctrl+R（fzf）、OMZ 历史 |
| 文件列表 | `ll` `la` `lt`（eza 图标 + git 标记）、Terminal-Icons | 同名别名 + eza |
| 跳转 | `z` / `zi`（zoxide） | `z` / `zi`（zoxide） |
| Git | posh-git、`lg`（lazygit）、delta 分页器 | OMZ git 插件、`lg` |
| 监控 | `btop`、`ff`（fastfetch 启动横幅） | `btop`、`fastfetch` 启动横幅 |
| 搜索工具 | fzf / fd / ripgrep / bat | 同左 |
| 原生着色 | `$PSStyle` 目录与扩展名配色 | LS_COLORS 由 eza 处理 |

启动开销经实测优化：PowerShell 新标签页到首个提示符 **约 1.6 s**（含启动横幅）。

## 快速开始

### 方案 A：PowerShell 7（推荐）

```powershell
git clone https://github.com/WindSnowLi/aurora-terminal.git
cd aurora-terminal\pwsh-setup
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install-PwshEnv.ps1
```

脚本会：winget 安装 oh-my-posh / fzf / zoxide / eza / bat / fd / ripgrep / fastfetch / btop4win / delta / lazygit → PSGallery 安装 posh-git / Terminal-Icons / PSFzf / ConsoleGuiTools → 按需安装 Nerd Font → 备份并部署 profile、主题、fastfetch 配置 → 合并 Windows Terminal 设置 → 主题渲染与组件自检。

常用开关：`-SkipModules`、`-SkipFont`、`-SkipTerminalSettings`、`-SkipGitDelta`、`-Force`。详细说明见 [pwsh-setup/README.md](pwsh-setup/README.md)。

### 方案 B：zsh（可选，免管理员）

```powershell
cd aurora-terminal\zsh-setup
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install-ZshEnv.ps1
```

使用 MSYS2 便携版（装在用户目录，无需管理员、无需 WSL/重启），安装 Oh My Zsh + Powerlevel10k + 现代 CLI 工具，并在 Windows Terminal 增加 “MSYS2 zsh” 标签页。详细说明见 [zsh-setup/README.md](zsh-setup/README.md)。

## 目录结构

```text
.
├── LICENSE
├── README.md
├── CHANGELOG.md
├── pwsh-setup/                     # 方案 A：PowerShell 7
│   ├── Install-PwshEnv.ps1         # 一键安装 / 部署 / 自检（幂等）
│   ├── Microsoft.PowerShell_profile.ps1
│   ├── themes/aurora.omp.json      # oh-my-posh 主题
│   ├── fastfetch/aurora.jsonc      # 启动横幅
│   ├── windows-terminal/settings.json
│   ├── packages.txt
│   └── README.md
└── zsh-setup/                      # 方案 B：zsh（可选）
    ├── Install-ZshEnv.ps1
    ├── .zshrc
    ├── .p10k.zsh
    ├── fastfetch/aurora.jsonc
    ├── windows-terminal/zsh-profile.json
    ├── packages.txt
    └── README.md
```

## Aurora 配色

| 角色 | 色值 |
| --- | --- |
| 终端背景 | `#0B0E1A` |
| 段背景（主/次） | `#1B2036` / `#232845` |
| 强调青（目录/成功） | `#2DD4BF` |
| 强调紫（git 分支） | `#C4B5FD` / `#A78BFA` |
| 警告琥珀 | `#FBBF24` |
| 错误粉 | `#FB7185` |
| 正文 | `#E5E7EB` |
| 次要文字 | `#94A3B8` |

字体统一使用 **JetBrainsMono Nerd Font**（`oh-my-posh font install JetBrainsMono` 或手动安装）。

## 快捷键

| 键 | 功能 |
| --- | --- |
| `Tab` | fzf 模糊补全（首次按 Tab 时加载 posh-git） |
| `Ctrl+R` / `Ctrl+T` / `Alt+C` | 历史搜索 / 选文件插入 / 跳转目录 |
| `F2` | 内联预测 ⇄ 列表预测 |
| `F7` | 历史命令网格选择 |
| `↑` / `↓` | 按前缀搜索历史 |

## 自定义

- **主题**：编辑 `themes/aurora.omp.json`，保存后 `. $PROFILE`；`path.max_depth`、`executiontime.threshold`、`git.fetch_status` 是最常调的三项。
- **横幅**：编辑 `fastfetch/aurora.jsonc`；不想要就设 `PWSH_NO_FASTFETCH=1`。
- **别名/键位**：直接改 profile 或 `.zshrc`；组件缺失时配置会静默降级，不会报错打断启动。
- **健康检查**：PowerShell 里执行 `Test-PwshEnv`，一次列出所有依赖状态。

## 兼容性与要求

- Windows 10 1809+ / Windows 11，Windows Terminal 1.18+
- PowerShell 7.4+（方案 A）；zsh 方案不需要管理员权限
- git（`posh-git`、delta、lazygit 依赖）

## 故障排查

| 症状 | 原因与处理 |
| --- | --- |
| `Style: roundrocket is not available` | 早期版本主题拼写错误，已修复为 `roundrock`（oh-my-posh 的耗时样式只接受德州城市名） |
| 提示符出现方块 / 问号 | 字体未生效：终端字体设为 `JetBrainsMono Nerd Font` |
| `Test-PwshEnv` 显示 posh-git 未加载 | 正常，posh-git 改为首次按 `Tab` 时加载以加快启动 |
| `Import-Module CompletionPredictor` 卡死 | PowerShell 7.6 下该模块会死锁，本仓库已不使用 |
| zsh 下 `zoxide: not a directory: C:\builtin pwd -L` | zoxide 为 Cygwin/MSYS 生成的脚本缺陷，`.zshrc` 已覆盖修复 |
| 终端背景图不显示 | `settings.json` 中背景图是占位路径，请换成自己的图片 |

## 卸载

```powershell
# 方案 A
Remove-Item "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Force
# 再在 Windows Terminal 设置里删除对应 profile（如需）
winget uninstall JanDeDobbeleer.OhMyPosh

# 方案 B
Remove-Item "$env:LOCALAPPDATA\Programs\msys64" -Recurse -Force
```

## 许可证

[MIT](LICENSE) © 2026 WindSnowLi