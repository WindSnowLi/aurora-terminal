<#
  PowerShell 7 交互式配置 —— 全功能 / 视觉统一（oh-my-posh + zoxide + eza + bat + fd + rg + fzf + lazygit + fastfetch）

  迁移方式
    - 本文件与 themes\、fastfetch\ 目录保持同级，整体复制到新机器的
      <我的文档>\PowerShell\ 下即可；
    - 依赖安装请运行同目录的 Install-PwshEnv.ps1；
    - 自查环境请运行 Test-PwshEnv；
    - 不想要启动横幅：设置环境变量 PWSH_NO_FASTFETCH=1；
    - 不想要系统代理同步：设置环境变量 PWSH_SYNC_SYSTEM_PROXY=0。
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
                    # 千万别在这里调 PSConsoleReadLine::RevertLine()：它的语义是"撤销当前行的全部编辑"，
                    # 会把命令行清空，随后 PSFzf 读到空行直接返回（Invoke-FzfTabCompletionInner 的
                    # IsNullOrWhiteSpace 分支），表现就是按 Tab 命令消失。替换范围 PSFzf 自己会算。
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

# ── 系统代理（启动时读取一次 → 环境变量）────────────────────────────────────
# 系统代理只对 WinINet / HTTP.SYS 生效，curl / git / npm / pip / gh 这类命令行工具只认环境变量。
# 每次启动读取注册表 Internet Settings 的 ProxyEnable / ProxyServer / ProxyOverride，
# 翻译成 HTTP_PROXY / HTTPS_PROXY / ALL_PROXY / NO_PROXY；系统代理改过之后，
# 在新开的标签页里自动生效，或者在当前会话手动执行 Sync-SystemProxy 刷新。
# 关闭同步：PWSH_SYNC_SYSTEM_PROXY=0。
$script:ProxyRegistryPath = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$script:ProxyVariableNames = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')
# 记录本次会话里自己写过的值，系统代理关掉后只清理这些（reload 时保留）
if (-not $script:ProxyAppliedValues) {
    $script:ProxyAppliedValues = @{}
}

function Get-SystemProxyState {
    # 直接读 .NET 注册表（约 0.2ms/次）；Get-ItemProperty 约 4ms，不适合定时轮询
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:ProxyRegistryPath)
    if (-not $key) { return $null }
    try {
        [pscustomobject]@{
            Enabled       = 1 -eq [int]($key.GetValue('ProxyEnable', 0))
            Server        = [string]$key.GetValue('ProxyServer', '')
            Override      = [string]$key.GetValue('ProxyOverride', '')
            AutoConfigUrl = [string]$key.GetValue('AutoConfigURL', '')
        }
    } finally {
        $key.Dispose()
    }
}

# 支持 "127.0.0.1:7897"、"http://127.0.0.1:7897"、"socks=127.0.0.1:7891" 三种写法。
# 注册表里不带 scheme 的 ProxyServer 是"HTTP 代理端点"：HTTP_PROXY 和 HTTPS_PROXY 都要写成
# http://host:port（变量名只表示"代理哪类请求"，不代表要用 TLS 连代理），
# 写成 https://host:port 会让 curl/git 用 TLS 去连一个明文代理，直接连不上。
function ConvertTo-ProxyUrl {
    param([string]$Value, [string]$Scheme = 'http')

    $text = if ($Value) { $Value.Trim() } else { '' }
    if (-not $text) { return $null }
    if ($text -match '^[a-z][a-z0-9+.\-]*://') { return $text }
    if ($Scheme -eq 'socks') { return "socks5://$text" }
    return "http://$text"
}

# ProxyOverride（';' 分隔的 Windows 例外）→ NO_PROXY（',' 分隔）：
#   <local> → localhost/127.0.0.1/::1；192.168.* → 192.168.0.0/16；*.corp.com → .corp.com
function ConvertTo-ProxyBypassList {
    param([string]$Override)

    $items = [System.Collections.Generic.List[string]]::new()
    foreach ($raw in ($Override -split ';')) {
        $entry = $raw.Trim()
        if (-not $entry) { continue }
        if ($entry -eq '<local>') {
            foreach ($local in 'localhost', '127.0.0.1', '::1') {
                if (-not $items.Contains($local)) { $items.Add($local) }
            }
            continue
        }
        if ($entry -match '^(?<octets>\d{1,3}(?:\.\d{1,3}){0,3})\.\*$') {
            $octets = $matches['octets'].Split('.')
            $network = (@($octets) + @('0', '0', '0'))[0..3] -join '.'
            $entry = "$network/$($octets.Count * 8)"
        } elseif ($entry -match '^\*\.(?<domain>.+)$') {
            $entry = ".$($matches['domain'])"
        }
        if (-not $items.Contains($entry)) { $items.Add($entry) }
    }
    if ($items.Count -eq 0) { return $null }
    return ($items -join ',')
}

function Get-SystemProxyEnvironment {
    param($State)

    $environment = [ordered]@{ HTTP_PROXY = $null; HTTPS_PROXY = $null; ALL_PROXY = $null; NO_PROXY = $null }
    if (-not $State -or -not $State.Enabled -or -not $State.Server) { return $environment }

    $servers = @{}
    if ($State.Server -match '=') {
        # 逐协议写法："http=127.0.0.1:7890;https=127.0.0.1:7890;socks=127.0.0.1:7891"
        foreach ($part in ($State.Server -split ';')) {
            $pair = $part -split '=', 2
            if ($pair.Count -eq 2 -and $pair[0].Trim()) {
                $servers[$pair[0].Trim().ToLowerInvariant()] = $pair[1].Trim()
            }
        }
        # 只配了 http 或 https 时互为兜底，避免"只代理了一半"
        if (-not $servers['http']) { $servers['http'] = $servers['https'] }
        if (-not $servers['https']) { $servers['https'] = $servers['http'] }
    } else {
        $servers['http'] = $State.Server.Trim()
        $servers['https'] = $State.Server.Trim()
    }

    $environment.HTTP_PROXY = ConvertTo-ProxyUrl -Value $servers['http']
    $environment.HTTPS_PROXY = ConvertTo-ProxyUrl -Value $servers['https']
    $environment.ALL_PROXY = ConvertTo-ProxyUrl -Value $servers['socks'] -Scheme 'socks'
    $environment.NO_PROXY = ConvertTo-ProxyBypassList -Override $State.Override
    return $environment
}

function Set-SystemProxyEnvironment {
    param([System.Collections.IDictionary]$Environment)

    foreach ($name in $script:ProxyVariableNames) {
        $value = $Environment[$name]
        if ($value) {
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
            $script:ProxyAppliedValues[$name] = $value
        } elseif ($script:ProxyAppliedValues[$name]) {
            # 系统代理关掉后，只清理本次会话里自己写过的值
            if ([Environment]::GetEnvironmentVariable($name, 'Process') -eq $script:ProxyAppliedValues[$name]) {
                [Environment]::SetEnvironmentVariable($name, $null, 'Process')
            }
            $script:ProxyAppliedValues.Remove($name)
        }
    }
}

function Sync-SystemProxy {
    param([switch]$Quiet)

    $state = Get-SystemProxyState
    if (-not $state) { return }

    $environment = Get-SystemProxyEnvironment -State $state
    Set-SystemProxyEnvironment -Environment $environment

    if ($Quiet) { return }
    $applied = @($script:ProxyVariableNames | Where-Object { $environment[$_] })
    if ($applied.Count -gt 0) {
        Write-ProfileNote ('系统代理: {0} → {1}' -f ($environment.HTTPS_PROXY ?? $environment.HTTP_PROXY), ($applied -join ' / '))
    } elseif ($state.Enabled) {
        Write-ProfileNote '系统代理已启用，但没能解析出代理服务器地址'
    } else {
        Write-ProfileNote '系统代理未启用，未设置代理环境变量'
    }
}

function Get-SystemProxy {
    $state = Get-SystemProxyState
    $environment = Get-SystemProxyEnvironment -State $state
    [pscustomobject]@{
        Enabled       = [bool]($state -and $state.Enabled)
        Server        = if ($state) { $state.Server } else { '' }
        AutoConfigUrl = if ($state) { $state.AutoConfigUrl } else { '' }
        HttpProxy     = $environment.HTTP_PROXY
        HttpsProxy    = $environment.HTTPS_PROXY
        AllProxy      = $environment.ALL_PROXY
        NoProxy       = $environment.NO_PROXY
    }
}

# 自助诊断：注册表原始值 → 应设置的值 → 当前进程里的实际值；-Probe 再用 curl 实测能否连通
function Test-SystemProxy {
    param([switch]$Probe)

    $state = Get-SystemProxyState
    if (-not $state) {
        Write-Host '  读不到 HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ForegroundColor Yellow
        return
    }

    Write-Host '系统代理（注册表）' -ForegroundColor Cyan
    Write-Host ("  ProxyEnable   : {0}" -f $state.Enabled)
    Write-Host ("  ProxyServer   : {0}" -f $state.Server)
    Write-Host ("  ProxyOverride : {0}" -f $state.Override)
    if ($state.AutoConfigUrl) { Write-Host ("  AutoConfigURL : {0}（PAC 无法静态解析）" -f $state.AutoConfigUrl) }

    $environment = Get-SystemProxyEnvironment -State $state
    Write-Host '环境变量（期望 / 当前进程实际）' -ForegroundColor Cyan
    foreach ($name in $script:ProxyVariableNames) {
        $expected = $environment[$name]
        $actual = [Environment]::GetEnvironmentVariable($name, 'Process')
        $color = if ($actual -eq $expected) { 'DarkGray' } else { 'Yellow' }
        Write-Host ("  {0,-11} 期望=[{1}] 实际=[{2}]" -f $name, $expected, $actual) -ForegroundColor $color
    }

    if (-not $Probe) { return }

    # WinHTTP 和 WinINet 是两套设置：winget / Windows Update 之类只认 WinHTTP，不读环境变量
    $winHttp = (& netsh winhttp show proxy 2>$null | Where-Object { $_.Trim() -and $_ -notmatch 'WinHTTP' } |
            Select-Object -First 1)
    Write-Host ("  WinHTTP      : {0}" -f ($winHttp -replace '^\s+|\s+$', '')) -ForegroundColor DarkGray

    if (-not (Test-Tool curl)) {
        Write-Host '  未找到 curl，跳过连通性探测' -ForegroundColor Yellow
        return
    }
    $code = & curl.exe -s -o NUL -w '%{http_code}' -m 8 https://www.example.com
    $color = if ($code -eq '200') { 'Green' } else { 'Yellow' }
    Write-Host ("  经当前环境变量访问 https://www.example.com → HTTP {0}" -f $code) -ForegroundColor $color
}

# 启动时读取一次（交互式会话会打印一行确认；脚本 / 管道会话静默生效）
# 用 OSVersion 判断而不是 $IsWindows：Windows PowerShell 5.1 里没有 $IsWindows，会让同步被整个跳过
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and
    $env:PWSH_SYNC_SYSTEM_PROXY -notin '0', 'false', 'off') {
    Sync-SystemProxy
}

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

    $proxy = Get-SystemProxy
    $proxyDetail = if (-not $proxy.Enabled) {
        if ($proxy.AutoConfigUrl) { "PAC 脚本，未同步（$($proxy.AutoConfigUrl)）" } else { '系统代理未启用' }
    } elseif (-not $proxy.HttpsProxy) {
        '已启用但未解析出代理地址'
    } else {
        '{0}（启动时同步）' -f $proxy.HttpsProxy
    }
    $items += @{ Name = 'system-proxy'; Ok = (-not $proxy.Enabled) -or [bool]$proxy.HttpsProxy; Detail = $proxyDetail }

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