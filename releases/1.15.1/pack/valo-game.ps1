# valo.os game mode (a fullscreen app is in front): -On -> best performance power mode, notifications muted, live wallpaper paused; -Off restores.
# Also used for focus time: -Dnd 1|0 only mutes / unmutes notifications.
param([switch]$On, [switch]$Off, [string]$Dnd)
$ErrorActionPreference = 'SilentlyContinue'
$state = Join-Path $env:LOCALAPPDATA 'valo\game.json'
$toastKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
$perf = 'ded574b5-45a0-4f42-8737-46345c09c238'      # "best performance" power mode overlay
function Lively([string[]]$a) {
    foreach ($r in "$env:LOCALAPPDATA\Programs\Lively Wallpaper", "$env:ProgramFiles\Lively Wallpaper") {
        foreach ($n in 'Livelycu.exe', 'Lively.exe') { if (Test-Path "$r\$n") { & "$r\$n" @a | Out-Null; return } }
    }
}
function SetToasts([bool]$enabled) {
    if (-not (Test-Path $toastKey)) { New-Item $toastKey -Force | Out-Null }
    Set-ItemProperty $toastKey -Name 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' -Value ([int]$enabled) -Type DWord
}
if ($Dnd) { SetToasts ($Dnd -ne '1'); return }
if ($On) {
    $prevOverlay = & (Join-Path $PSScriptRoot 'valo-power.ps1') -Get
    $toasts = (Get-ItemProperty $toastKey -Name 'NOC_GLOBAL_SETTING_TOASTS_ENABLED').NOC_GLOBAL_SETTING_TOASTS_ENABLED
    New-Item -ItemType Directory -Force (Split-Path $state) | Out-Null
    [IO.File]::WriteAllText($state, (@{ overlay = $prevOverlay; toasts = $toasts } | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    $null = & (Join-Path $PSScriptRoot 'valo-power.ps1') -Set $perf
    SetToasts $false
    Lively @('app', '--play', 'false')
}
elseif ($Off) {
    $prev = $null; if (Test-Path $state) { $prev = Get-Content $state -Raw | ConvertFrom-Json }
    $ov = if ($prev -and $prev.overlay) { $prev.overlay } else { '00000000-0000-0000-0000-000000000000' }
    $null = & (Join-Path $PSScriptRoot 'valo-power.ps1') -Set $ov
    if ($prev -and $prev.toasts -eq 0) { SetToasts $false } else { SetToasts $true }
    Lively @('app', '--play', 'true')
    Remove-Item $state -EA SilentlyContinue
}
