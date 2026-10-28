<#
  PowerShell 7 交互式配置 —— 全功能 / 视觉统一（oh-my-posh + zoxide + eza + bat + fd + rg + fzf + lazygit + fastfetch）

  迁移方式
    - 本文件与 themes\、fastfetch\ 目录保持同级，整体复制到新机器的
      <我的文档>\PowerShell\ 下即可；
    - 依赖安装请运行同目录的 Install-PwshEnv.ps1；
    - 自查环境请运行 Test-PwshEnv；
    - 不想要启动横幅：设置环境变量 PWSH_NO_FASTFETCH=1。
#>

# ── 环境探测 ────────────────────────────────────────────────────────────────
$script:IsInteractive = -not [Console]::IsOutputRedirected -and $Host.Name -eq 'ConsoleHost'
$script:ProfileRoot = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $PROFILE.CurrentUserCurrentHost
}
$script:MissingDeps = [System.Collections.Generic.List[string]]::new()

function Write-ProfileNote {
    param([string]$Message)
    if ($script:IsInteractive) { Write-Host "  $Message" -ForegroundColor DarkGray }
}

function Test-Tool {
    param([string]$Name)
    [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Import-OptionalModule {
    param([string]$Name, [scriptblock]$Configure)

    try {
        Import-Module $Name -ErrorAction Stop
        if ($Configure) { & $Configure }
        return $true
    } catch {
        $script:MissingDeps.Add($Name)
        return $false
    }
}

function Set-ReadLineOptionSafe {
    param([hashtable]$Option)

    try { Set-PSReadLineOption @Option -ErrorAction Stop } catch { }
}

# ── oh-my-posh 路径解析 ─────────────────────────────────────────────────────
function Resolve-OmpExecutable {
    $command = Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) { return $command.Source }

    $bases = @(
        @{ Root = $env:LOCALAPPDATA; Relative = 'Programs\oh-my-posh\oh-my-posh.exe' },
        @{ Root = $env:ProgramFiles; Relative = 'oh-my-posh\oh-my-posh.exe' },
        @{ Root = $env:ProgramData; Relative = 'chocolatey\bin\oh-my-posh.exe' }
    ) | Where-Object { $_.Root -and (Test-Path -LiteralPath $_.Root) }

    foreach ($base in $bases) {
        $candidate = Join-Path $base.Root $base.Relative
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Resolve-OmpTheme {
    foreach ($candidate in @(
            (Join-Path $script:ProfileRoot 'themes\aurora.omp.json'),
            (Join-Path $env:USERPROFILE '.config\oh-my-posh\aurora.omp.json'),
            (Join-Path $env:USERPROFILE 'Documents\PowerShell\themes\aurora.omp.json')
        )) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

# ── 交互式环境准备 ──────────────────────────────────────────────────────────
# PSReadLine 先加载：PSFzf 需要它注册 Ctrl+R / Ctrl+T，CompletionPredictor 需要它提供内联预测
if ($script:IsInteractive) { Import-Module PSReadLine -ErrorAction SilentlyContinue }

# Terminal-Icons 立即加载（约 0.3s）：让 ls 一开始就有图标
Import-OptionalModule -Name Terminal-Icons | Out-Null
# posh-git 较慢（约 0.45s）且主要提供 git 补全，推迟到第一次按 Tab 时再加载
$global:PWSH_POSH_GIT_PENDING = $true
# Out-ConsoleGridView：网格化选择
Import-OptionalModule -Name Microsoft.PowerShell.ConsoleGuiTools | Out-Null

# ── fzf / PSFzf ─────────────────────────────────────────────────────────────
if (Test-Tool fzf) {
    $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git --exclude node_modules'
    $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
    $env:FZF_ALT_C_COMMAND = 'fd --type d --hidden --follow --exclude .git --exclude node_modules'
    $env:FZF_DEFAULT_OPTS = '--height 60% --layout=reverse --border rounded --info=inline ' +
    '--color=fg:#E5E7EB,bg:#0B0E1A,hl:#2DD4BF,fg+:#F8FAFC,bg+:#1B2036,hl+:#5EEAD4,' +
    'info:#94A3B8,prompt:#A78BFA,pointer:#FB7185,marker:#34D399,spinner:#A78BFA,header:#64748B'
    $env:FZF_CTRL_R_OPTS = '--preview "echo {}" --preview-window down:3:hidden:wrap --bind "?:toggle-preview"'
    $env:FZF_ALT_C_OPTS = '--preview "eza --tree --level=2 --icons --color=always {} 2>$null | Select-Object -First 40"'

    Import-OptionalModule -Name PSFzf -Configure {
        if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) {
            # Ctrl+T 模糊选文件，Ctrl+R 模糊搜索历史
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        }
    } | Out-Null
} else {
    $script:MissingDeps.Add('fzf')
}

# ── oh-my-posh 提示符 ───────────────────────────────────────────────────────
$script:OmpExe = Resolve-OmpExecutable
$script:OmpTheme = Resolve-OmpTheme

if ($script:OmpExe -and $script:OmpTheme) {
    try {
        $env:POSH_THEME = $script:OmpTheme
        & $script:OmpExe init pwsh --config $script:OmpTheme | Invoke-Expression
    } catch {
        $script:OmpExe = $null
        Write-ProfileNote "oh-my-posh 初始化失败: $($_.Exception.Message)"
    }
}

# ── zoxide（必须放在 oh-my-posh 之后：它包装当前 prompt 函数来记录目录）─────
if (Test-Tool zoxide) {
    try { Invoke-Expression (& { (zoxide init powershell --cmd z | Out-String) }) } catch { }
}

# ── PSReadLine ──────────────────────────────────────────────────────────────
if ($script:IsInteractive) {
    $readLine = Get-Module PSReadLine
    if ($readLine) {
        $readLineVersion = $readLine.Version

        Set-ReadLineOptionSafe @{ EditMode = 'Windows' }
        Set-ReadLineOptionSafe @{ HistorySearchCursorMovesToEnd = $true }
        Set-ReadLineOptionSafe @{ MaximumHistoryCount = 100000 }
        Set-ReadLineOptionSafe @{ HistorySaveStyle = 'SaveIncrementally' }
        # PSReadLine 2.3 起 BellStyle 已弃用，仅在旧版本设置
        if ($readLineVersion -lt [version]'2.3.0') {
            Set-ReadLineOptionSafe @{ BellStyle = 'None' }
        }
        if ($readLineVersion -ge [version]'2.2.0') {
            Set-ReadLineOptionSafe @{ PredictionSource = 'HistoryAndPlugin' }
            Set-ReadLineOptionSafe @{ PredictionViewStyle = 'ListView' }
            Set-ReadLineOptionSafe @{ Colors = @{
                    InlinePrediction       = "`e[38;5;242m"
                    ListPrediction         = "`e[38;5;109m"
                    ListPredictionSelected = "`e[48;5;236m`e[38;5;252m"
                    ContinuationPrompt     = "`e[38;5;109m"
                }
            }
        }

        # Tab：有 PSFzf 就走模糊补全，否则用原生菜单补全
        $loadPoshGit = {
            if ($global:PWSH_POSH_GIT_PENDING) {
                $global:PWSH_POSH_GIT_PENDING = $false
                Import-Module posh-git -ErrorAction SilentlyContinue
            }
        }
        try {
            if (Get-Command Invoke-FzfTabCompletion -ErrorAction SilentlyContinue) {
                Set-PSReadLineKeyHandler -Key Tab -BriefDescription 'FuzzyCompletion' -ScriptBlock {
                    if ($global:PWSH_POSH_GIT_PENDING) {
                        $global:PWSH_POSH_GIT_PENDING = $false
                        Import-Module posh-git -ErrorAction SilentlyContinue
                    }
                    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                    Invoke-FzfTabCompletion
                }
            } else {
                & $loadPoshGit
                Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
            }
        } catch { }

        foreach ($binding in @(
                @{ Key = 'UpArrow'; Function = 'HistorySearchBackward' },
                @{ Key = 'DownArrow'; Function = 'HistorySearchForward' },
                @{ Key = 'Ctrl+d'; Function = 'DeleteCharOrExit' },
                @{ Key = 'Ctrl+z'; Function = 'Undo' }
            )) {
            try { Set-PSReadLineKeyHandler -Key $binding.Key -Function $binding.Function -ErrorAction Stop } catch { }
        }

        # F2：内联预测 <-> 列表预测 切换
        try {
            Set-PSReadLineKeyHandler -Key F2 -BriefDescription 'TogglePredictionView' -ScriptBlock {
                $style = if ((Get-PSReadLineOption).PredictionViewStyle -eq 'ListView') { 'InlineView' } else { 'ListView' }
                Set-PSReadLineOption -PredictionViewStyle $style
                [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
            }
        } catch { }

        # F7：历史记录网格选择（需要 ConsoleGuiTools）
        if (Get-Command Out-ConsoleGridView -ErrorAction SilentlyContinue) {
            try {
                Set-PSReadLineKeyHandler -Key F7 -BriefDescription 'HistoryGridView' -ScriptBlock {
                    $picked = Get-History -Count 500 | Sort-Object Id -Descending |
                        Out-ConsoleGridView -Title '命令历史' -OutputMode Single
                    if ($picked) {
                        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($picked.CommandLine)
                    }
                }
            } catch { }
        }
    }
}

# ── 原生着色（$PSStyle）─────────────────────────────────────────────────────
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.FileInfo.Directory = "`e[1;38;5;44m"
    $PSStyle.FileInfo.SymbolicLink = "`e[38;5;183m"
    $PSStyle.FileInfo.Executable = "`e[1;38;5;114m"
    $PSStyle.FileInfo.Extension['.ps1'] = "`e[38;5;183m"
    $PSStyle.FileInfo.Extension['.psm1'] = "`e[38;5;183m"
    $PSStyle.FileInfo.Extension['.json'] = "`e[38;5;179m"
    $PSStyle.FileInfo.Extension['.jsonc'] = "`e[38;5;179m"
    $PSStyle.FileInfo.Extension['.md'] = "`e[38;5;109m"
    $PSStyle.FileInfo.Extension['.yml'] = "`e[38;5;204m"
    $PSStyle.FileInfo.Extension['.yaml'] = "`e[38;5;204m"
    $PSStyle.Formatting.Error = "`e[38;5;204m"
    $PSStyle.Formatting.Warning = "`e[38;5;179m"
}

# ── 现代化命令 ──────────────────────────────────────────────────────────────
if (Test-Tool eza) {
    function ll { eza -l --icons --group-directories-first --git --header @args }
    function la { eza -la --icons --group-directories-first --git --header @args }
    function lt { eza --tree --level=2 --icons --group-directories-first @args }
    function tree { eza --tree --icons --group-directories-first @args }
} else {
    function ll { Get-ChildItem @args }
    function la { Get-ChildItem -Force @args }
    $script:MissingDeps.Add('eza')
}

if (Test-Tool bat) {
    # 只追加新名字，不覆盖 cat（避免影响脚本里的 Get-Content 语义）
    function catp { bat --style=plain --paging=never @args }
    function batp { bat --style=full --paging=always @args }
}

if (Test-Tool lazygit) { Set-Alias -Name lg -Value lazygit -Scope Global }
if (Test-Tool btop4win) { Set-Alias -Name btop -Value btop4win -Scope Global }
elseif (Test-Tool btop) { Set-Alias -Name btop -Value btop -Scope Global }
if (Test-Tool fastfetch) { function ff { fastfetch --config (Join-Path $script:ProfileRoot 'fastfetch\aurora.jsonc') @args } }
if (Test-Tool delta) { $env:DELTA_FEATURES = 'line-numbers decorations navigate' }
if (Get-Command Out-ConsoleGridView -ErrorAction SilentlyContinue) { Set-Alias -Name ocgv -Value Out-ConsoleGridView -Scope Global }

Set-Alias -Name g -Value git -Scope Global -ErrorAction SilentlyContinue

function which {
    param([Parameter(Mandatory, Position = 0)][string]$Name)

    Get-Command $Name -All -ErrorAction SilentlyContinue |
        ForEach-Object { if ($_.Source) { $_.Source } else { $_.Definition } } |
        Select-Object -Unique
}

function mkcd {
    param([Parameter(Mandatory, Position = 0)][string]$Path)

    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    New-Item -ItemType Directory -Path $resolved -Force | Out-Null
    Set-Location -LiteralPath $resolved
}

function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }
function reload { . $PROFILE }

# ── 启动横幅（fastfetch）────────────────────────────────────────────────────
if ($script:IsInteractive -and -not $env:PWSH_NO_FASTFETCH -and (Test-Tool fastfetch)) {
    $ffConfig = Join-Path $script:ProfileRoot 'fastfetch\aurora.jsonc'
    try {
        if (Test-Path -LiteralPath $ffConfig) { fastfetch --config $ffConfig } else { fastfetch }
    } catch { }
}

# ── 自查 ────────────────────────────────────────────────────────────────────
function Test-PwshEnv {
    $poshGitModule = Get-Module posh-git
    if (-not $poshGitModule) {
        # posh-git 按需加载，这里只查是否已安装
        $poshGitModule = Get-Module -ListAvailable posh-git | Select-Object -First 1
    }
    $poshGitDetail = if ($poshGitModule) {
        if (Get-Module posh-git) { $poshGitModule.Version } else { "已安装 $($poshGitModule.Version)（首次按 Tab 时加载）" }
    } else { '未安装' }

    $items = @(
        @{ Name = 'PowerShell'; Ok = $PSVersionTable.PSVersion.Major -ge 7; Detail = $PSVersionTable.PSVersion.ToString() }
        @{ Name = 'oh-my-posh'; Ok = [bool]$script:OmpExe; Detail = if ($script:OmpExe) { "$(& $script:OmpExe --version) @ $script:OmpExe" } else { '未安装' } }
        @{ Name = 'theme'; Ok = [bool]$script:OmpTheme; Detail = if ($script:OmpTheme) { $script:OmpTheme } else { '未找到 aurora.omp.json' } }
        @{ Name = 'posh-git'; Ok = [bool]$poshGitModule; Detail = $poshGitDetail }
        @{ Name = 'Terminal-Icons'; Ok = [bool](Get-Module Terminal-Icons); Detail = (Get-Module Terminal-Icons).Version }
        @{ Name = 'ConsoleGuiTools'; Ok = [bool](Get-Module Microsoft.PowerShell.ConsoleGuiTools); Detail = (Get-Module Microsoft.PowerShell.ConsoleGuiTools).Version }
        @{ Name = 'PSFzf'; Ok = [bool](Get-Module PSFzf); Detail = (Get-Module PSFzf).Version }
        @{ Name = 'PSReadLine'; Ok = [bool](Get-Module PSReadLine); Detail = (Get-Module PSReadLine).Version }
    )
    foreach ($tool in 'oh-my-posh', 'fzf', 'fd', 'rg', 'eza', 'bat', 'zoxide', 'git', 'lazygit', 'btop4win', 'fastfetch', 'delta') {
        $command = Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $items += @{ Name = $tool; Ok = [bool]$command; Detail = if ($command) { $command.Source } else { '未安装' } }
    }

    $items | ForEach-Object {
        [pscustomobject]@{
            Component = $_.Name
            Status    = if ($_.Ok) { 'OK' } else { 'MISSING' }
            Detail    = $_.Detail
        }
    } | Format-Table -AutoSize
}

# ── 首次提示（仅在缺件且交互式时输出） ─────────────────────────────────────
if ($script:IsInteractive -and $script:MissingDeps.Count -gt 0) {
    Write-Host "  缺少组件: $($script:MissingDeps -join ', ') — 运行 Install-PwshEnv.ps1 或 Test-PwshEnv 查看详情" -ForegroundColor DarkYellow
}