# zsh-setup — Windows 上的 zsh 全功能环境（免管理员）

[![License: MIT](https://img.shields.io/badge/License-MIT-2DD4BF.svg)](../LICENSE)
[![Platform](https://img.shields.io/badge/Platform-MSYS2%20UCRT64-A78BFA.svg)](../README.md#兼容性与要求)

< [返回仓库首页](../README.md)

MSYS2(UCRT64) + zsh + Oh My Zsh + Powerlevel10k + 一整套现代 CLI 工具，视觉与 [pwsh-setup](../pwsh-setup/README.md) 的 aurora 配色保持一致。
全部安装在用户目录，**不需要管理员权限，也不需要 WSL/重启**。

> 该方案是可选项：偏好 PowerShell 的用户只装 [pwsh-setup](../pwsh-setup/README.md) 即可，两者互不干扰。

## 一键还原

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install-ZshEnv.ps1
```

脚本做的事（幂等，可重复执行）：

1. 下载并解压 MSYS2 便携版到 `%LOCALAPPDATA%\Programs\msys64`（清华 TUNA 镜像，失败回退官方源）
2. pacman 镜像切换到 TUNA，`pacman -Syu` + 安装 zsh 与工具链
3. 克隆 Oh My Zsh、Powerlevel10k、4 个插件
4. 部署 `.zshrc` / `.p10k.zsh` / fastfetch 配置（自动 LF 化，旧文件备份）
5. 向 Windows Terminal `settings.json` 合并 `MSYS2 zsh` profile（旧文件备份）
6. 自检：主题/插件/工具/语法

开关：`-Msys2Path`、`-SkipPackages`、`-SkipZshPlugins`、`-SkipTerminalSettings`、`-Force`。

## 目录结构

| 文件 | 用途 |
| --- | --- |
| `.zshrc` | 主配置：oh-my-zsh + 插件 + zoxide + fzf + 别名 + 启动横幅 |
| `.p10k.zsh` | Powerlevel10k 配置（Aurora 配色、异步 git、右侧时间） |
| `fastfetch/aurora.jsonc` | 启动横幅（系统、内存、磁盘、IP） |
| `windows-terminal/zsh-profile.json` | Windows Terminal profile 片段 |
| `Install-ZshEnv.ps1` | 一键安装/部署脚本 |

## 已装工具

| 命令 | 说明 | 别名 |
| --- | --- | --- |
| `eza` | 现代 `ls`（图标、git 状态） | `ls` `l` `ll` `la` `lt` `tree` |
| `bat` | 带高亮的 `cat` | `cat` |
| `fd` | 快速找文件（fzf 默认源） | |
| `rg` | ripgrep | |
| `fzf` | 模糊搜索 | `Ctrl+R` `Ctrl+T` `Alt+C` |
| `zoxide` | 智能 `cd` | `z 目录名` / `zi` |
| `lazygit` | 终端 Git UI | `lg` |
| `fastfetch` | 系统信息 | `ff` |
| `dust` / `hyperfine` / `jq` / `tmux` / `vim` | 杂项 | |

其它别名：`gs` `gd` `gco` `gl`（git 常用）、`..` `...` `....`、`reload`、`p10k-reload`、`myip`、`ports`、`lg`、`ff`。

补全与提示：`fzf-tab`（Tab 补全走 fzf，带 `eza` 预览）、`zsh-autosuggestions`（灰字建议，`→` 接受）、`zsh-syntax-highlighting`（命令实时着色）、`zsh-completions`。

## 定制

| 想改什么 | 改哪里 |
| --- | --- |
| 提示符样式/颜色 | `~/.p10k.zsh`（改完 `p10k reload`） |
| 启动横幅内容 | `~/.config/fastfetch/aurora.jsonc` |
| 不要启动横幅 | `.zshrc` 里 `export ZSH_NO_FASTFETCH=1`，或删掉文件末尾那段 |
| 别名 / 环境变量 | `.zshrc` 末尾追加 |
| 换镜像 | `~/.zshrc` 无关，改 `/etc/pacman.d/mirrorlist.*` |
| 加插件 | `plugins=(...)` 数组 + `git clone` 到 `~/.oh-my-zsh/custom/plugins/` |

## 实现要点（踩过的坑）

- **p10k 的 git 状态**：MSYS/Cygwin 下 `gitstatus` 守护进程无法初始化，已在 `.p10k.zsh` 里
  `POWERLEVEL9K_DISABLE_GITSTATUS=true`，改用 p10k 内置回退实现，提示符照常显示分支/改动标记且无报错。
- **zoxide 在 MSYS 下的 bug**：`zoxide init zsh` 生成的 `__zoxide_pwd` 写成 `cygpath -w "\builtin pwd -L"`
  （少了 `$( )`），会把字面量当路径，报 `zoxide: not a directory: C:\builtin pwd -L`。
  `.zshrc` 里已用 `function __zoxide_pwd() { \builtin pwd -L }` 覆盖修复。
- **instant prompt 与启动横幅互斥**：默认 `POWERLEVEL9K_INSTANT_PROMPT=off`；若不需要 fastfetch，
  可在 `.zshrc` 里设为 `quiet` 换取更快的冷启动。
- **登录 shell**：`msys2_shell.cmd -shell zsh` 会以 `-l` 启动 (经由 `/etc/zsh/zprofile` 加载 `/etc/profile` 设置 PATH)，
  实测提示符渲染正常；若在其它终端里遇到异常，可用 `exec zsh -i` 对照排查。
- **dotfile 换行**：`.zshrc`/`.p10k.zsh` 必须是 LF，脚本部署时会自动转换。

## 卸载

```powershell
# 1. 移除 Windows Terminal 里名为 "MSYS2 zsh" 的 profile（设置界面删除即可）
# 2. 删除 MSYS2 与数据
Remove-Item "$env:LOCALAPPDATA\Programs\msys64" -Recurse -Force
Remove-Item "$env:LOCALAPPDATA\zoxide" -Recurse -Force -ErrorAction SilentlyContinue
```

## 想要真正的 Linux 内核 / WSL？

WSL 需要管理员权限并重启；装好后可直接复用本目录的 `.zshrc` / `.p10k.zsh`（把 `MSYS2` 相关判断删掉即可），
`packages.txt` 里的 pacman 包换成对应的 `apt` 包名。
