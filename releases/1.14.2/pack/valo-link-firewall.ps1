# valo Link: let phones on the local network reach this PC (run elevated; the valo Link window asks first).
# Windows created "Windows PowerShell — Block" inbound rules when its firewall prompt was dismissed; block rules beat allow rules,
# so those two are disabled (not deleted) and one narrow allow rule is added: powershell.exe, port 47800 TCP+UDP, local subnet only.
# Undo:  powershell -File valo-link-firewall.ps1 -Remove
param([switch]$Remove)
$ErrorActionPreference = 'SilentlyContinue'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$log = "$env:LOCALAPPDATA\valo\link\firewall.log"
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
Remove-NetFirewallRule -DisplayName 'valo Link (TCP 47800)', 'valo Link (UDP 47800)'
$blocks = Get-NetFirewallRule -Direction Inbound -Action Block | Where-Object { ($_ | Get-NetFirewallApplicationFilter).Program -ieq $ps -or ($_ | Get-NetFirewallApplicationFilter).Program -ieq '%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe' }
if ($Remove) {
    "$(Get-Date -f s) removed valo Link rules" | Add-Content $log
    exit 0
}
foreach ($b in $blocks) { Disable-NetFirewallRule -Name $b.Name; "$(Get-Date -f s) disabled block rule $($b.DisplayName) [$($b.Name)]" | Add-Content $log }
foreach ($p in 'TCP', 'UDP') {
    New-NetFirewallRule -DisplayName "valo Link ($p 47800)" -Direction Inbound -Action Allow -Protocol $p -LocalPort 47800 -RemoteAddress LocalSubnet -Program $ps -Profile Any -Description 'valo.os: phone companion (valo Link) on the local network only' | Out-Null
}
"$(Get-Date -f s) added valo Link allow rules" | Add-Content $log
