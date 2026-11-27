# valo.os search commands that need PowerShell.
#   -Close <name>  closes windows of apps whose process name / description contains <name> (politely, like the X button)
param([string]$Close)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
if ($Close) {
    $n = $Close.Trim().ToLower()
    $ps = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and ($_.ProcessName.ToLower().Contains($n) -or ("$($_.Description)").ToLower().Contains($n) -or ("$($_.MainWindowTitle)").ToLower().Contains($n)) }
    $count = 0
    foreach ($p in $ps) { if ($p.CloseMainWindow()) { $count++ } }
    [Console]::Out.Write((@{ ok = $true; closed = $count } | ConvertTo-Json -Compress))
}
