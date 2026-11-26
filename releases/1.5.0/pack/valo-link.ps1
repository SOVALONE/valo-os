# valo Link launcher: compiles valo-link.cs in memory and runs it (window + tray + phone server).
#   powershell -STA -WindowStyle Hidden -File valo-link.ps1 [--hidden]
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
try {
    Add-Type -ReferencedAssemblies System.Web.Extensions, System.Windows.Forms, System.Drawing -TypeDefinition ([IO.File]::ReadAllText((Join-Path $dir 'valo-link.cs')))
} catch {
    Add-Content -LiteralPath "$env:TEMP\valo-link.log" -Value ((Get-Date -f s) + " compile failed: $_")
    exit 1
}
[ValoLink.Program]::WebDir = $dir
[ValoLink.Program]::Main([string[]]$args)
