# valo.os: apply panel height (floating / sticky 100-75-50) -> Zebar preset (+ GlazeWM top gap), then restart Zebar
param([int]$Size = 100, [switch]$Sticky)
$ErrorActionPreference = 'SilentlyContinue'

$h = if (-not $Sticky) { 44 } else { @{ 100 = 44; 75 = 33; 50 = 22 }[$Size] }
if (-not $h) { $h = 44 }
$suffix = if ($Sticky -and $Size -ne 100) { "$Size" } else { '' }

# Zebar: switch the bar preset (host* on a normal PC, default* with GlazeWM)
$settingsPath = "$env:USERPROFILE\.glzr\zebar\settings.json"
$cfg = Get-Content $settingsPath -Raw | ConvertFrom-Json
foreach ($c in $cfg.startupConfigs) {
    if ($c.pack -eq 'quill' -and $c.widget -eq 'bar') {
        $base = if ($c.preset -like 'host*') { 'host' } else { 'default' }
        $c.preset = $base + $suffix
    }
}
[IO.File]::WriteAllText($settingsPath, ($cfg | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))

# GlazeWM: keep tiled windows just below the bar
$glz = "$env:USERPROFILE\.glzr\glazewm\config.yaml"
if (Test-Path $glz) {
    $top = if ($Sticky) { $h + 10 } else { 52 }
    $y = [IO.File]::ReadAllText($glz)
    $y = [regex]::Replace($y, "(outer_gap:\s*\r?\n\s*top:\s*)'\d+px'", "`${1}'${top}px'")
    [IO.File]::WriteAllText($glz, $y, [Text.UTF8Encoding]::new($false))
    $cli = 'C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe'
    if (-not (Test-Path $cli)) { $cli = 'C:\Program Files\glzr.io\GlazeWM\glazewm.exe' }
    if (Get-Process glazewm) { & $cli command wm-reload-config | Out-Null }
}

# restart Zebar from a detached process (this script is a child of Zebar)
$zebar = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
$cmd = "Start-Sleep -Milliseconds 400; Stop-Process -Name zebar -Force; Start-Sleep -Milliseconds 1500; Start-Process '$zebar'"
Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', $cmd
