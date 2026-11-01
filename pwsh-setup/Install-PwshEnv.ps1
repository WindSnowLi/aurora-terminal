<#
.SYNOPSIS
    一键还原 PowerShell 7 终端环境（oh-my-posh + posh-git + Terminal-Icons + PSFzf）。

.DESCRIPTION
    幂等脚本：已安装的组件会跳过，可安全重复运行。建议在新机器上以普通用户权限运行：

        pwsh -NoProfile -ExecutionPolicy Bypass -File .\Install-PwshEnv.ps1

.PARAMETER SkipModules
    跳过 PowerShell 模块（posh-git / Terminal-Icons / PSFzf）的安装。

.PARAMETER SkipFont
    跳过 Nerd Font 安装。

.PARAMETER SkipTerminalSettings
    跳过 Windows Terminal settings.json 的还原。

.PARAMETER SkipGitDelta
    跳过把 delta 配置为 git 分页器。

.PARAMETER Force
    即使目标文件内容相同也强制覆盖（默认会跳过一致文件，仅备份有差异的文件）。
.NOTES
    版本: 1.0.0
    作者: WindSnowLi
    许可: MIT
    仓库: https://github.com/WindSnowLi/aurora-terminal
#>
[CmdletBinding()]
param(
    [switch]$SkipModules,
    [switch]$SkipFont,
    [switch]$SkipTerminalSettings,
    [switch]$SkipGitDelta,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$SourceRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ProfileSource = Join-Path $SourceRoot 'Microsoft.PowerShell_profile.ps1'
$VSCodeProfileSource = Join-Path $SourceRoot 'Microsoft.VSCode_profile.ps1'
$ThemeSource = Join-Path $SourceRoot 'themes\aurora.omp.json'
$FastfetchSource = Join-Path $SourceRoot 'fastfetch\aurora.jsonc'
$TerminalSettingsSource = Join-Path $SourceRoot 'windows-terminal\settings.json'
$Modules = 'posh-git', 'Terminal-Icons', 'PSFzf', 'Microsoft.PowerShell.ConsoleGuiTools'
$WingetPackages = @(
    @{ Id = 'JanDeDobbeleer.OhMyPosh'; Name = 'oh-my-posh'; Command = 'oh-my-posh' },
    @{ Id = 'junegunn.fzf'; Name = 'fzf'; Command = 'fzf' },
    @{ Id = 'ajeetdsouza.zoxide'; Name = 'zoxide'; Command = 'zoxide' },
    @{ Id = 'eza-community.eza'; Name = 'eza'; Command = 'eza' },
    @{ Id = 'sharkdp.bat'; Name = 'bat'; Command = 'bat' },
    @{ Id = 'sharkdp.fd'; Name = 'fd'; Command = 'fd' },
    @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep'; Command = 'rg' },
    @{ Id = 'Fastfetch-cli.Fastfetch'; Name = 'fastfetch'; Command = 'fastfetch' },
    @{ Id = 'aristocratos.btop4win'; Name = 'btop4win'; Command = 'btop4win' },
    @{ Id = 'dandavison.delta'; Name = 'delta'; Command = 'delta' },
    @{ Id = 'JesseDuffield.lazygit'; Name = 'lazygit'; Command = 'lazygit' }
)

function Write-Step { param([string]$Text) Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "    [OK]   $Text" -ForegroundColor Green }
function Write-Skip { param([string]$Text) Write-Host "    [SKIP] $Text" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

function Test-CommandExists {
    param([string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:PATH = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

function Resolve-OmpPath {
    $command = Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\oh-my-posh.exe'),
        (Join-Path $env:ProgramFiles 'oh-my-posh\oh-my-posh.exe')
    )
    return ($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1)
}

function Install-WingetPackage {
    param([string]$Id, [string]$Label)

    if (-not (Test-CommandExists winget)) {
        Write-Warn "winget 不可用，请手动安装 $Label（$Id）"
        return $false
    }

    Write-Host "    installing $Label ($Id) ..."
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & winget install --id $Id --exact --silent --disable-interactivity `
            --accept-source-agreements --accept-package-agreements 2>&1 | ForEach-Object { "      $_" }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    Update-SessionPath

    if ($exitCode -eq 0) {
        Write-Ok "$Label 安装完成"
        return $true
    }
    if ($exitCode -eq -1978335189) {
        Write-Skip "$Label 已是最新（winget: already installed）"
        return $true
    }
    Write-Warn "$Label 安装返回 $exitCode（可能正在被占用或需要管理员权限），请用 winget list --id $Id 确认"
    return $false
}

function Test-NerdFont {
    $fontDirs = @((Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'), (Join-Path $env:windir 'Fonts'))
    foreach ($dir in $fontDirs) {
        if (Test-Path -LiteralPath $dir) {
            if (Get-ChildItem -LiteralPath $dir -Filter '*NerdFont*' -ErrorAction SilentlyContinue | Select-Object -First 1) {
                return $true
            }
        }
    }
    return $false
}

# 用 "强制渲染所有段" 的方式校验主题，能捕获 Style: xxx is not available 这类配置错误
function Test-OmpTheme {
    param([string]$OmpExe, [string]$ThemePath)

    $config = Get-Content -LiteralPath $ThemePath -Raw | ConvertFrom-Json -AsHashtable
    foreach ($block in $config.blocks) {
        foreach ($segment in $block.segments) {
            if ($segment.properties) { $segment.properties['always_enabled'] = $true }
        }
    }

    $temp = Join-Path $env:TEMP ("omp-verify-{0}.json" -f [guid]::NewGuid())
    try {
        $config | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $temp -Encoding utf8
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = & $OmpExe print primary --shell pwsh --config $temp 2>&1 | Out-String
        } finally {
            $ErrorActionPreference = $previousPreference
        }
        return @{ Ok = ($output -notmatch 'is not available'); Output = $output.Trim() }
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

function Copy-ConfigFile {
    param([string]$Source, [string]$Destination)

    $targetDir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $exists = Test-Path -LiteralPath $Destination
    if ($exists -and -not $Force -and (Get-FileHash $Source).Hash -eq (Get-FileHash $Destination).Hash) {
        Write-Skip "已是最新: $Destination"
        return
    }
    if ($exists) {
        $backup = "$Destination.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $Destination -Destination $backup -Force
        Write-Host "    备份旧文件: $backup" -ForegroundColor DarkGray
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Ok "已写入: $Destination"
}

# Windows Terminal 设置是用户资产（含自定义 profile / 配色 / 键位），
# 因此只叠加 Aurora 的配色、主题与 profile 默认值，其余原样保留；新机器无配置时才整份写入。
function Merge-TerminalSettings {
    param([string]$Source, [string]$Destination)

    if (-not (Test-Path -LiteralPath $Destination)) {
        Copy-ConfigFile -Source $Source -Destination $Destination
        return
    }

    try {
        $existing = Get-Content -LiteralPath $Destination -Raw | ConvertFrom-Json -AsHashtable
        $reference = Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Warn "现有 settings.json 不是合法 JSON（$($_.Exception.Message)），改为整份覆盖"
        Copy-ConfigFile -Source $Source -Destination $Destination
        return
    }

    $existing['schemes'] = @($existing['schemes'] | Where-Object { $_ })
    foreach ($scheme in @($reference['schemes'])) {
        if (-not ($existing['schemes'] | Where-Object { $_.name -eq $scheme.name })) { $existing['schemes'] += $scheme }
    }

    $existing['themes'] = @($existing['themes'] | Where-Object { $_ })
    foreach ($theme in @($reference['themes'])) {
        if (-not ($existing['themes'] | Where-Object { $_.name -eq $theme.name })) { $existing['themes'] += $theme }
    }
    if ($reference.ContainsKey('theme')) { $existing['theme'] = $reference['theme'] }

    if (-not $existing['profiles']) { $existing['profiles'] = @{} }
    if (-not $existing['profiles']['list']) { $existing['profiles']['list'] = @($reference['profiles']['list']) }

    $defaults = if ($existing['profiles']['defaults']) { $existing['profiles']['defaults'] } else { @{} }
    $referenceDefaults = $reference['profiles']['defaults']
    $backgroundImage = $referenceDefaults['backgroundImage']
    $hasBackgroundImage = $backgroundImage -and (Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($backgroundImage)))
    foreach ($key in $referenceDefaults.Keys) {
        if ($key -like 'backgroundImage*' -and -not $hasBackgroundImage) { continue }
        $defaults[$key] = $referenceDefaults[$key]
    }
    $existing['profiles']['defaults'] = $defaults
    if (-not $hasBackgroundImage -and $backgroundImage) {
        Write-Skip "背景图不存在，跳过 backgroundImage（如需启用请放到: $([Environment]::ExpandEnvironmentVariables($backgroundImage))）"
    }

    # profile 级显式字体会覆盖 defaults：默认 profile 若写死了非 Nerd 字体（例如 Fira Code），
    # 提示符图标就会变成问号。这里只替换字体家族，字号等其余设置保留用户的。
    $nerdFace = $referenceDefaults['font']['face']
    foreach ($profile in @($existing['profiles']['list'])) {
        if ($profile['guid'] -ne $existing['defaultProfile'] -or -not $profile['font']) { continue }
        $face = $profile['font']['face']
        if ($face -and $face -ne $nerdFace -and $face -notmatch 'Nerd Font|NF') {
            $profile['font']['face'] = $nerdFace
            Write-Ok "默认 profile 字体 $face → $nerdFace（否则图标会显示为问号）"
        }
    }

    $backup = "$Destination.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $Destination -Destination $backup -Force
    Write-Host "    备份旧文件: $backup" -ForegroundColor DarkGray
    $existing | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Destination -Encoding utf8NoBOM
    Write-Ok "已合并 Aurora 配色/主题/默认值（保留原有 $($existing['profiles']['list'].Count) 个 profile）: $Destination"
}

# ── 0. 环境检查 ─────────────────────────────────────────────────────────────
Write-Step '检查当前环境'
# 先刷新 PATH：winget 安装的目录写进用户 PATH 后，新进程才可见
Update-SessionPath
Write-Host "    PowerShell $($PSVersionTable.PSVersion) / $([Environment]::OSVersion.VersionString)"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warn '当前不是 PowerShell 7，部分特性（PSReadLine 历史预测）将不可用；建议 winget install Microsoft.PowerShell'
}
if (-not (Test-Path -LiteralPath $ProfileSource)) { throw "找不到配置模板: $ProfileSource" }
if (-not (Test-Path -LiteralPath $ThemeSource)) { throw "找不到主题文件: $ThemeSource" }

# ── 1. 可执行程序 ───────────────────────────────────────────────────────────
Write-Step '安装命令行程序（oh-my-posh / 现代 CLI 工具）'
foreach ($package in $WingetPackages) {
    $existing = if ($package.Command -eq 'oh-my-posh') {
        Resolve-OmpPath
    } else {
        (Get-Command $package.Command -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1).Source
    }
    if ($existing) {
        Write-Skip "$($package.Name) 已安装"
    } else {
        Install-WingetPackage -Id $package.Id -Label $package.Name | Out-Null
    }
}
$ompExe = Resolve-OmpPath
if (-not $ompExe) { Write-Warn 'oh-my-posh 仍不可用，提示符将退回到默认样式' }

# ── 2. PowerShell 模块 ──────────────────────────────────────────────────────
if ($SkipModules) {
    Write-Step '跳过 PowerShell 模块安装（-SkipModules）'
} else {
    Write-Step '安装 PowerShell 模块（posh-git / Terminal-Icons / PSFzf）'
    if (-not (Get-PSRepository PSGallery -ErrorAction SilentlyContinue)) {
        Write-Warn '未找到 PSGallery，请先运行 Register-PSRepository -Default'
    } elseif ((Get-PSRepository PSGallery).InstallationPolicy -ne 'Trusted') {
        try { Set-PSRepository PSGallery -InstallationPolicy Trusted } catch { }
    }

    foreach ($module in $Modules) {
        if (Get-Module -ListAvailable -Name $module | Select-Object -First 1) {
            Write-Skip "$module 已安装"
            continue
        }
        Write-Host "    installing $module ..."
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Ok "$module 安装完成"
        } catch {
            Write-Warn "$module 安装失败: $($_.Exception.Message)"
        }
    }
}

# ── 3. Nerd Font ────────────────────────────────────────────────────────────
if ($SkipFont) {
    Write-Step '跳过字体安装（-SkipFont）'
} elseif (Test-NerdFont) {
    Write-Step '字体检查'
    Write-Skip '已存在 Nerd Font'
} else {
    Write-Step '安装 Nerd Font（JetBrainsMono）'
    if ($ompExe) {
        # oh-my-posh 在部分环境打印完 "Successfully installed" 后进程不退出（遗留子进程占住管道），
        # 直接调用会把脚本卡死，这里改为带超时的等待。
        $fontProcess = Start-Process -FilePath $ompExe -ArgumentList 'font', 'install', 'JetBrainsMono' -NoNewWindow -PassThru
        if (-not $fontProcess.WaitForExit(300000)) {
            Write-Warn 'oh-my-posh 未在 5 分钟内退出，已结束该进程（字体通常已写入，下面会重新检测）'
            Stop-Process -Id $fontProcess.Id -Force -ErrorAction SilentlyContinue
        }
        if (Test-NerdFont) { Write-Ok 'JetBrainsMono NF 安装完成' } else { Write-Warn '字体安装未生效，可在终端渲染异常时手动安装' }
    } else {
        Write-Warn '需要先安装 oh-my-posh 才能自动装字体'
    }
}

# ── 4. 部署配置 ─────────────────────────────────────────────────────────────
Write-Step '部署 profile 与主题'
$profileTarget = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path -Parent $profileTarget
Copy-ConfigFile -Source $ProfileSource -Destination $profileTarget
# VS Code 的 PowerShell 集成控制台是独立宿主，只加载 Microsoft.VSCode_profile.ps1
if (Test-Path -LiteralPath $VSCodeProfileSource) {
    Copy-ConfigFile -Source $VSCodeProfileSource -Destination (Join-Path $profileDir 'Microsoft.VSCode_profile.ps1')
}
Copy-ConfigFile -Source $ThemeSource -Destination (Join-Path $env:USERPROFILE '.config\oh-my-posh\aurora.omp.json')
if (Test-Path -LiteralPath $FastfetchSource) {
    Copy-ConfigFile -Source $FastfetchSource -Destination (Join-Path $profileDir 'fastfetch\aurora.jsonc')
}

Write-Step '检查执行策略'
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in 'Restricted', 'AllSigned', 'Undefined') {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Ok "执行策略已设为 RemoteSigned（原值: $policy）"
    } catch {
        Write-Warn "执行策略设置失败: $($_.Exception.Message)"
    }
} else {
    Write-Skip "当前执行策略: $policy"
}

# ── 4.5 git 使用 delta 分页器 ───────────────────────────────────────────────
if ($SkipGitDelta) {
    Write-Step '跳过 git delta 配置（-SkipGitDelta）'
} elseif (-not (Get-Command delta -ErrorAction SilentlyContinue)) {
    Write-Step 'git delta 配置'
    Write-Skip '未安装 delta'
} elseif (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Step 'git delta 配置'
    Write-Skip '未安装 git'
} else {
    Write-Step '配置 git 分页器（delta）'
    $currentPager = & git config --global --get core.pager 2>$null
    if ($currentPager) {
        Write-Skip "core.pager 已存在: $currentPager"
    } else {
        & git config --global core.pager delta
        & git config --global interactive.diffFilter 'delta --color-only'
        & git config --global delta.navigate true
        & git config --global delta.line-numbers true
        & git config --global diff.colorMoved default
        Write-Ok '已启用 delta（撤销：git config --global --unset core.pager）'
    }
}

# ── 5. Windows Terminal ─────────────────────────────────────────────────────
if ($SkipTerminalSettings) {
    Write-Step '跳过 Windows Terminal 配置（-SkipTerminalSettings）'
} else {
    Write-Step '合并 Windows Terminal 设置（保留现有 profile 与配色）'
    $terminalSettings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (-not (Test-Path -LiteralPath $TerminalSettingsSource)) {
        Write-Skip '迁移包中没有 windows-terminal\settings.json'
    } elseif (-not (Test-Path -LiteralPath (Split-Path -Parent $terminalSettings))) {
        Write-Skip '未检测到 Windows Terminal，跳过'
    } else {
        Merge-TerminalSettings -Source $TerminalSettingsSource -Destination $terminalSettings
        Write-Host '    注意：该配置引用了 "Aurora Night" 配色，字体需为 JetBrainsMono NF（Nerd Fonts 3.4+ 的家族名）' -ForegroundColor DarkGray
        Write-Host "    背景图路径（需自行拷贝）: $env:USERPROFILE\Pictures\TerminalBackgrounds\aurora-night.png" -ForegroundColor DarkGray
    }
}

# ── 6. 主题自检 ─────────────────────────────────────────────────────────────
Write-Step '校验 oh-my-posh 主题'
if (-not $ompExe) {
    Write-Warn 'oh-my-posh 不可用，跳过校验'
} else {
    $result = Test-OmpTheme -OmpExe $ompExe -ThemePath $ThemeSource
    if ($result.Ok) {
        Write-Ok '主题渲染正常，没有 "xxx is not available" 之类的报错'
    } else {
        Write-Warn '主题仍有配置错误，请检查上面的渲染输出：'
        Write-Host $result.Output -ForegroundColor DarkYellow
    }
}

# ── 7. 组件自检 ─────────────────────────────────────────────────────────────
Write-Step '组件自检（新会话）'
try {
    $envCheck = & pwsh -NoLogo -Command 'Test-PwshEnv | Out-String' 2>&1
    $envCheck | Where-Object { $_ -match 'MISSING|Status|----|OK' } | ForEach-Object { "      $_" }
} catch {
    Write-Warn "自检失败: $($_.Exception.Message)"
}

# ── 完成 ────────────────────────────────────────────────────────────────────
Write-Step '完成'
Write-Host @"
    后续步骤：
      1. 关闭并重新打开终端（或执行 . `$PROFILE）
      2. 运行 Test-PwshEnv 检查各组件状态
      3. 若提示符或图标出现方块/问号，说明字体未生效：Windows Terminal 中把字体设为 JetBrainsMono NF（profile 级字体设置优先级高于全局默认）
      4. 快捷键：Tab 模糊补全 / Ctrl+R 历史 / Ctrl+T 选文件 / F2 切换预测视图 / F7 历史网格
      5. 常用命令：ll / la / lt / lg(lazygit) / btop / ff(fastfetch) / z 目录名(zoxide) / ocgv
"@ -ForegroundColor Gray
