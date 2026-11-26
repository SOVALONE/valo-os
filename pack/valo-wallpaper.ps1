# valo.os: put the live wallpaper of a theme on the desktop through Lively Wallpaper (if it is installed).
#   -Theme sakura|night|matcha|latte|graphite|sunset      -> {"ok":true} / {"ok":false,"error":..}
param([string]$Theme = 'sakura')
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }

if ($Theme -notmatch '^[a-z]+$') { Out-Json @{ ok = $false; error = 'bad theme' }; return }
$wp = Join-Path $env:LOCALAPPDATA "valo\wallpapers\valo-$Theme"
if (-not (Test-Path "$wp\LivelyInfo.json")) { Out-Json @{ ok = $false; error = "Шпалери $Theme не знайдено" }; return }

# Lively command utility (Livelycu.exe) or the app itself, wherever the installer put it
$roots = @("$env:LOCALAPPDATA\Programs\Lively Wallpaper", "$env:ProgramFiles\Lively Wallpaper", "${env:ProgramFiles(x86)}\Lively Wallpaper")
$cli = $null
foreach ($r in $roots) { foreach ($n in 'Livelycu.exe', 'Lively.exe') { if (-not $cli -and (Test-Path "$r\$n")) { $cli = "$r\$n" } } }
if (-not $cli) { $cli = (Get-ChildItem $roots -Recurse -Filter 'Livelycu.exe' -EA SilentlyContinue | Select-Object -First 1).FullName }
if (-not $cli) { Out-Json @{ ok = $false; error = 'Lively Wallpaper не встановлено' }; return }

if (-not (Get-Process Lively -EA SilentlyContinue)) {
    $app = Join-Path (Split-Path $cli) 'Lively.exe'
    if (Test-Path $app) { Start-Process $app; Start-Sleep -Seconds 4 }
}
& $cli setwp --file "$wp" | Out-Null
Add-Content -LiteralPath "$env:TEMP\valo-wallpaper.log" -Value ((Get-Date -f s) + " setwp $Theme via $cli exit $LASTEXITCODE")
Out-Json @{ ok = $true; cli = $cli }
