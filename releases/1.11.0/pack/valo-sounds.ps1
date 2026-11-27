# valo.os system sounds on / off (current user only, nothing needs admin).
#   -Enable   copies valo-snd-*.wav to %LOCALAPPDATA%\valo\sounds and points the Windows sound events at them
#             (the previous sounds are remembered in %LOCALAPPDATA%\valo\sounds-backup.json)
#   -Disable  puts the remembered sounds back
param([switch]$Enable, [switch]$Disable)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dir = Join-Path $env:LOCALAPPDATA 'valo\sounds'
$backup = Join-Path $env:LOCALAPPDATA 'valo\sounds-backup.json'
$root = 'HKCU:\AppEvents\Schemes\Apps'
$map = [ordered]@{
    '.Default\.Default' = 'default'; '.Default\Notification.Default' = 'notify'; '.Default\SystemNotification' = 'notify'
    '.Default\WindowsLogon' = 'logon'; '.Default\SystemAsterisk' = 'default'; '.Default\SystemExclamation' = 'exclamation'
    '.Default\SystemHand' = 'error'; '.Default\DeviceConnect' = 'connect'; '.Default\DeviceDisconnect' = 'disconnect'
    'Explorer\EmptyRecycleBin' = 'trash'
}
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }

if ($Enable) {
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item (Join-Path $here 'valo-snd-*.wav') $dir -Force
    $old = @{}
    if (Test-Path $backup) { $old = @{}; (Get-Content $backup -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $old[$_.Name] = $_.Value } }
    foreach ($ev in $map.Keys) {
        $key = "$root\$ev\.Current"
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        $cur = (Get-ItemProperty $key).'(default)'
        if (-not $old.ContainsKey($ev) -and $cur -notlike '*\valo\sounds\*') { $old[$ev] = "$cur" }
        Set-ItemProperty -Path $key -Name '(default)' -Value (Join-Path $dir "valo-snd-$($map[$ev]).wav")
    }
    [IO.File]::WriteAllText($backup, ($old | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    Set-ItemProperty 'HKCU:\AppEvents\Schemes' -Name '(default)' -Value '.Current'
    Out-Json @{ ok = $true; on = $true }
}
elseif ($Disable) {
    if (-not (Test-Path $backup)) { Out-Json @{ ok = $true; on = $false }; return }
    (Get-Content $backup -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
        $key = "$root\$($_.Name)\.Current"
        if (Test-Path $key) { Set-ItemProperty -Path $key -Name '(default)' -Value "$($_.Value)" }
    }
    Remove-Item $backup -Force
    Out-Json @{ ok = $true; on = $false }
}
