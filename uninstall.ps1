# valo.os uninstaller: returns Windows to how it was. In PowerShell:
#   irm https://raw.githubusercontent.com/SOVALONE/valo-os/main/uninstall.ps1 | iex
# Zebar and the font stay installed (remove them in Settings → Apps, or set $env:VALO_REMOVE_APPS = '1' first).
& {
$ErrorActionPreference = 'SilentlyContinue'
$pack = "$env:USERPROFILE\.glzr\zebar\quill"
$valo = Join-Path $env:LOCALAPPDATA 'valo'
function Say($m, $c = 'Magenta') { Write-Host "  valo.os  " -ForegroundColor $c -NoNewline; Write-Host $m }
Write-Host ''; Say 'видалення valo.os'; Write-Host ''

# stop the panel and its helper
Get-Process zebar | Stop-Process -Force
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*valo-shell.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

# put back what valo.os changed
if (Test-Path "$pack\valo-shell.ps1") { powershell -NoProfile -ExecutionPolicy Bypass -File "$pack\valo-shell.ps1" -RestoreTaskbar; Say 'панель задач Windows повернуто' }
if (Test-Path "$pack\valo-sounds.ps1") { powershell -NoProfile -ExecutionPolicy Bypass -File "$pack\valo-sounds.ps1" -Disable | Out-Null; Say 'звуки Windows повернуто' }
if ((Test-Path "$valo\game.json") -and (Test-Path "$pack\valo-game.ps1")) { powershell -NoProfile -ExecutionPolicy Bypass -File "$pack\valo-game.ps1" -Off }
if ((Test-Path "$valo\travel.json") -and (Test-Path "$pack\valo-travel.ps1")) { powershell -NoProfile -ExecutionPolicy Bypass -File "$pack\valo-travel.ps1" -Off | Out-Null }
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' -Name 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' -Value 1 -Type DWord
Add-Type 'using System; using System.Runtime.InteropServices; public static class ValoGammaReset { [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h); [DllImport("gdi32.dll")] static extern bool SetDeviceGammaRamp(IntPtr dc, ushort[] r); public static void Reset() { ushort[] r = new ushort[768]; for (int i = 0; i < 256; i++) { r[i] = r[256 + i] = r[512 + i] = (ushort)(i * 257); } SetDeviceGammaRamp(GetDC(IntPtr.Zero), r); } }'
[ValoGammaReset]::Reset()

# autostart
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Remove-ItemProperty $run -Name 'valo-bar', 'valo-taskbar'

# Zebar settings: the backup from the installer, or just without the valo widgets
$settings = "$env:USERPROFILE\.glzr\zebar\settings.json"
if (Test-Path "$settings.valo-backup") { Move-Item "$settings.valo-backup" $settings -Force }
elseif (Test-Path $settings) {
    $cfg = Get-Content $settings -Raw | ConvertFrom-Json
    $cfg.startupConfigs = @(@($cfg.startupConfigs) | Where-Object { $_ -and $_.pack -ne 'quill' })
    [IO.File]::WriteAllText($settings, ($cfg | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
}

# files
Remove-Item $pack -Recurse -Force
Remove-Item $valo -Recurse -Force
Say 'файли valo.os видалено'

if ($env:VALO_REMOVE_APPS -eq '1') {
    winget uninstall --id glzr-io.zebar -e --silent --disable-interactivity | Out-Null
    winget uninstall --id DEVCOM.JetBrainsMonoNerdFont -e --silent --disable-interactivity | Out-Null
    Say 'Zebar і шрифт видалено'
}
Write-Host ''; Say 'готово. Якщо щось лишилось на екрані — вийдіть із системи й увійдіть знову.' 'Green'; Write-Host ''
}
