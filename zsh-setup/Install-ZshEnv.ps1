<#
.SYNOPSIS
    一键还原 zsh 环境：MSYS2(UCRT64) + zsh + Oh My Zsh + Powerlevel10k + 现代 CLI 工具。

.DESCRIPTION
    全程免管理员权限（MSYS2 便携版装在用户目录）。幂等，可重复执行。
    建议在新机器上运行：

        pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install-ZshEnv.ps1

.PARAMETER Msys2Path
    MSYS2 安装目录，默认 %LOCALAPPDATA%\Programs\msys64。

.PARAMETER SkipPackages
    跳过 pacman 软件包安装（仅部署配置）。

.PARAMETER SkipZshPlugins
    跳过 Oh My Zsh / p10k / 插件的克隆。

.PARAMETER SkipTerminalSettings
    跳过 Windows Terminal profile 的写入。

.PARAMETER Force
    目标文件内容相同也强制覆盖。
.NOTES
    版本: 1.0.0
    作者: WindSnowLi
    许可: MIT
    仓库: https://github.com/WindSnowLi/aurora-terminal
#>
[CmdletBinding()]
param(
    [string]$Msys2Path = (Join-Path $env:LOCALAPPDATA 'Programs\msys64'),
    [switch]$SkipPackages,
    [switch]$SkipZshPlugins,
    [switch]$SkipTerminalSettings,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$SourceRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$BashExe = Join-Path $Msys2Path 'usr\bin\bash.exe'
$TarballUrl = 'https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib/msys2-x86_64-latest.tar.xz'
$TarballFallback = 'https://repo.msys2.org/distrib/msys2-x86_64-latest.tar.xz'
$MirrorHost = 'https://mirrors.tuna.tsinghua.edu.cn/msys2'

$PacmanPackages = @(
    'zsh', 'git', 'curl', 'wget', 'unzip', 'less', 'man-db', 'tmux', 'nano', 'vim', 'util-linux',
    'mingw-w64-ucrt-x86_64-eza', 'mingw-w64-ucrt-x86_64-bat', 'mingw-w64-ucrt-x86_64-fd',
    'mingw-w64-ucrt-x86_64-ripgrep', 'mingw-w64-ucrt-x86_64-fzf', 'mingw-w64-ucrt-x86_64-zoxide',
    'mingw-w64-ucrt-x86_64-jq', 'mingw-w64-ucrt-x86_64-dust', 'mingw-w64-ucrt-x86_64-hyperfine',
    'mingw-w64-ucrt-x86_64-lazygit', 'mingw-w64-ucrt-x86_64-fastfetch'
)

$ZshAddons = @(
    @{ Dir = 'custom/themes/powerlevel10k'; Url = 'https://github.com/romkatv/powerlevel10k.git' },
    @{ Dir = 'custom/plugins/zsh-autosuggestions'; Url = 'https://github.com/zsh-users/zsh-autosuggestions.git' },
    @{ Dir = 'custom/plugins/zsh-syntax-highlighting'; Url = 'https://github.com/zsh-users/zsh-syntax-highlighting.git' },
    @{ Dir = 'custom/plugins/zsh-completions'; Url = 'https://github.com/zsh-users/zsh-completions.git' },
    @{ Dir = 'custom/plugins/fzf-tab'; Url = 'https://github.com/Aloxaf/fzf-tab.git' }
)

function Write-Step { param([string]$Text) Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "    [OK]   $Text" -ForegroundColor Green }
function Write-Skip { param([string]$Text) Write-Host "    [SKIP] $Text" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

function Invoke-Bash {
    param([Parameter(Mandatory)][string]$Script, [switch]$IgnoreExitCode)

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $env:MSYSTEM = 'UCRT64'
        $output = & $BashExe -lc $Script 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0 -and -not $IgnoreExitCode) {
        throw "bash 执行失败 ($code):`n$($output | Out-String)"
    }
    return $output
}

# dotfile 必须以 LF + UTF-8(无 BOM) 写入，否则 zsh 会报错
function Copy-DotFile {
    param([string]$Source, [string]$Destination)

    $targetDir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $exists = Test-Path -LiteralPath $Destination
    $text = [IO.File]::ReadAllText($Source).Replace("`r`n", "`n")
    if ($exists -and -not $Force -and [IO.File]::ReadAllText($Destination) -eq $text) {
        Write-Skip "已是最新: $Destination"
        return
    }
    if ($exists) {
        $backup = "$Destination.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $Destination -Destination $backup -Force
        Write-Host "    备份旧文件: $backup" -ForegroundColor DarkGray
    }
    [IO.File]::WriteAllText($Destination, $text, [Text.UTF8Encoding]::new($false))
    Write-Ok "已写入: $Destination"
}

function Install-Msys2 {
    if (Test-Path -LiteralPath $BashExe) {
        Write-Skip "MSYS2 已存在: $Msys2Path"
        return
    }

    Write-Host '    下载 MSYS2 便携版（约 41 MB）...'
    $tarball = Join-Path $env:TEMP 'msys2-base.tar.xz'
    if (Test-Path $tarball) { Remove-Item $tarball -Force }

    $downloaded = $false
    foreach ($url in @($TarballUrl, $TarballFallback)) {
        try {
            & curl.exe -L --fail --silent --show-error -o $tarball $url
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tarball)) { $downloaded = $true; break }
        } catch {
            Write-Warn "下载失败，尝试下一个镜像: $url"
        }
    }
    if (-not $downloaded) { throw 'MSYS2 下载失败，请手动下载 msys2-x86_64-latest.tar.xz 后重试' }

    Write-Host '    解压...'
    $parent = Split-Path -Parent $Msys2Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    & tar.exe -xf $tarball -C $parent
    Remove-Item $tarball -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path -LiteralPath $BashExe)) { throw "解压后找不到 $BashExe" }
    Write-Ok "MSYS2 已解压到 $Msys2Path"

    Write-Host '    首次初始化（生成 pacman 密钥环）...'
    Invoke-Bash -Script 'true' -IgnoreExitCode | Out-Null
    Write-Ok 'MSYS2 初始化完成'
}

# ── 0. 环境检查 ─────────────────────────────────────────────────────────────
Write-Step '检查当前环境'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$privText = if ($isAdmin) { '管理员' } else { '普通用户' }
Write-Host "    PowerShell $($PSVersionTable.PSVersion) / $privText / MSYS2 目标: $Msys2Path"
foreach ($file in '.zshrc', '.p10k.zsh', 'fastfetch\aurora.jsonc') {
    if (-not (Test-Path -LiteralPath (Join-Path $SourceRoot $file))) { throw "缺少模板文件: $file" }
}

# ── 1. MSYS2 ────────────────────────────────────────────────────────────────
Write-Step '准备 MSYS2（免管理员）'
Install-Msys2

# ── 2. 镜像加速 ─────────────────────────────────────────────────────────────
Write-Step '配置 pacman 镜像（清华 TUNA）'
Invoke-Bash -Script ("sed -i 's|https://repo.msys2.org|$MirrorHost|g; s|https://mirror.msys2.org|$MirrorHost|g' /etc/pacman.d/mirrorlist.* ; grep -h '^Server' /etc/pacman.d/mirrorlist.msys | head -2") |
    ForEach-Object { "      $_" }

# ── 3. 软件包 ───────────────────────────────────────────────────────────────
if ($SkipPackages) {
    Write-Step '跳过软件包安装（-SkipPackages）'
} else {
    Write-Step '安装 zsh 与现代 CLI 工具（首次约 66 MB 下载）'
    try {
        Invoke-Bash -Script 'pacman -Syu --noconfirm' | Select-Object -Last 3 | ForEach-Object { "      $_" }
    } catch {
        Write-Warn '系统升级未完成（可忽略，继续安装所需软件包）'
    }
    $packageList = $PacmanPackages -join ' '
    Invoke-Bash -Script "pacman -S --noconfirm --needed $packageList" | Select-Object -Last 3 | ForEach-Object { "      $_" }
    Write-Ok '软件包就绪'
}

# ── 4. Oh My Zsh + p10k + 插件 ──────────────────────────────────────────────
if ($SkipZshPlugins) {
    Write-Step '跳过 Oh My Zsh 安装（-SkipZshPlugins）'
} else {
    Write-Step '安装 Oh My Zsh / Powerlevel10k / 插件'
    $cloneScript = @'
set -e
cd "$HOME"
[ -d .oh-my-zsh ] || git clone --depth=1 -q https://github.com/ohmyzsh/ohmyzsh.git .oh-my-zsh
mkdir -p .oh-my-zsh/custom/themes .oh-my-zsh/custom/plugins
'@
    Invoke-Bash -Script $cloneScript | Out-Null

    foreach ($addon in $ZshAddons) {
        $target = ".oh-my-zsh/$($addon.Dir)"
        $result = Invoke-Bash -Script "cd `"`$HOME`" && if [ -d $target ]; then echo SKIP; else git clone --depth=1 -q $($addon.Url) $target && echo CLONED; fi" -IgnoreExitCode
        if ($result -match 'CLONED') { Write-Ok "已克隆 $(Split-Path $addon.Dir -Leaf)" }
        else { Write-Skip "$(Split-Path $addon.Dir -Leaf) 已存在" }
    }
}

# ── 5. 部署 dotfiles ────────────────────────────────────────────────────────
Write-Step '部署 zsh 配置'
$homeWin = (Invoke-Bash -Script 'cygpath -w "$HOME"' | Select-Object -First 1)
if (-not (Test-Path -LiteralPath $homeWin)) { throw "无法定位 MSYS2 HOME: $homeWin" }
Write-Host "    MSYS2 HOME: $homeWin" -ForegroundColor DarkGray

Copy-DotFile -Source (Join-Path $SourceRoot '.zshrc') -Destination (Join-Path $homeWin '.zshrc')
Copy-DotFile -Source (Join-Path $SourceRoot '.p10k.zsh') -Destination (Join-Path $homeWin '.p10k.zsh')
Copy-DotFile -Source (Join-Path $SourceRoot 'fastfetch\aurora.jsonc') -Destination (Join-Path $homeWin '.config\fastfetch\aurora.jsonc')

# ── 6. Windows Terminal profile ─────────────────────────────────────────────
if ($SkipTerminalSettings) {
    Write-Step '跳过 Windows Terminal 配置（-SkipTerminalSettings）'
} else {
    Write-Step '写入 Windows Terminal profile'
    $terminalSettings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    $profileTemplate = Join-Path $SourceRoot 'windows-terminal\zsh-profile.json'
    if (-not (Test-Path -LiteralPath $terminalSettings)) {
        Write-Skip '未检测到 Windows Terminal，跳过'
    } elseif (-not (Test-Path -LiteralPath $profileTemplate)) {
        Write-Skip '迁移包中没有 zsh-profile.json，跳过'
    } else {
        $profile = (Get-Content -LiteralPath $profileTemplate -Raw | ConvertFrom-Json -AsHashtable)
        $profile.Remove('_comment')
        $profile.commandline = $profile.commandline.Replace('%LOCALAPPDATA%\Programs\msys64', $Msys2Path)
        $profile.icon = $profile.icon.Replace('%LOCALAPPDATA%\Programs\msys64', $Msys2Path)

        Copy-Item -LiteralPath $terminalSettings -Destination "$terminalSettings.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
        $json = Get-Content -LiteralPath $terminalSettings -Raw | ConvertFrom-Json -AsHashtable
        $json.profiles.list = @(
            $json.profiles.list | Where-Object { $_.guid -ne $profile.guid -and $_.name -ne $profile.name }
        )
        $json.profiles.list = @($profile) + @($json.profiles.list)
        $json | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $terminalSettings -Encoding utf8
        Write-Ok '已添加 profile: MSYS2 zsh（原配置已备份）'
    }
}

# ── 7. 自检 ─────────────────────────────────────────────────────────────────
Write-Step '自检'
$check = Invoke-Bash -IgnoreExitCode -Script @'
printf 'zsh: %s\n' "$(zsh --version)"
zsh -i -l -c 'printf "theme=%s\np10k=%s\nplugins=%s\n" "$ZSH_THEME" "${P9K_VERSION:-未加载}" "$plugins"' 2>/dev/null
missing=""
for c in eza bat fd rg fzf zoxide lazygit fastfetch; do command -v $c >/dev/null || missing="$missing $c"; done
printf '缺失工具:%s\n' "${missing:- 无}"
'@
$check | ForEach-Object { "      $_" }

$syntax = Invoke-Bash -IgnoreExitCode -Script 'zsh -o no_aliases -n "$HOME/.zshrc" && echo SYNTAX_OK'
if ($syntax -match 'SYNTAX_OK') { Write-Ok '.zshrc 语法检查通过' } else { Write-Warn '.zshrc 语法检查未通过，请查看上面的输出' }

Write-Step '完成'
Write-Host @'
    后续步骤：
      1. 打开 Windows Terminal 新标签页，选择 "MSYS2 zsh"（默认仍是 PowerShell 7）
      2. 首次启动会显示 fastfetch 版本信息与 p10k 提示符
      3. 常用快捷键：Ctrl+R 历史搜索 / Ctrl+T 选文件 / Alt+C 跳目录 / Tab 补全(fzf-tab)
      4. 想设为默认：终端 设置 -> 启动 -> 默认配置文件 -> MSYS2 zsh
'@ -ForegroundColor Gray
