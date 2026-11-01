# VS Code 的 PowerShell 集成控制台是独立宿主（VisualStudioCode），
# 加载的是 Microsoft.VSCode_profile.ps1 而不是 Microsoft.PowerShell_profile.ps1。
# 这里直接转交给主配置，保证 VS Code 里也有同样的提示符 / 别名 / 系统代理环境变量。
. (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1')
