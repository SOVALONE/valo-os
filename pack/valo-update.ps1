# valo.os updater: panel / menu / dock / control center (Zebar pack) and wallpapers from GitHub.
#   -Check  -> {"current":"1.1.0","latest":"1.2.0","available":true,"notes":[..]}   (or {"error":..})
#   -Apply  -> downloads every file of the latest release, checks SHA-256, backs up the pack, installs, restarts Zebar
# Release manifest: https://raw.githubusercontent.com/<Repo>/<Branch>/version.json
#   { "version": "1.2.0", "date": "...", "notes": ["..."], "files": [ { "path": "pack/bar.html", "sha256": "..." }, ... ] }
#   pack/*        -> %USERPROFILE%\.glzr\zebar\quill\
#   wallpapers/*  -> %LOCALAPPDATA%\valo\wallpapers\
param([switch]$Check, [switch]$Apply, [string]$Repo = 'SOVALONE/valo-os', [string]$Branch = 'main')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$pack = Split-Path -Parent $MyInvocation.MyCommand.Path
$valo = Join-Path $env:LOCALAPPDATA 'valo'
$log = Join-Path $env:TEMP 'valo-update.log'
function Log($m) { Add-Content -LiteralPath $log -Value ((Get-Date -f 'yyyy-MM-dd HH:mm:ss') + ' ' + $m) }
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 4)) }
function Ver($s) { try { [version]$s } catch { [version]'0.0.0' } }

$base = "https://raw.githubusercontent.com/$Repo/$Branch"
$current = '0.0.0'
try { $current = (Get-Content (Join-Path $pack 'version.json') -Raw | ConvertFrom-Json).version } catch { }

try {
    $remote = Invoke-RestMethod -Uri "$base/version.json?t=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" -UseBasicParsing -TimeoutSec 15
} catch {
    Log "check failed: $_"
    Out-Json @{ current = $current; error = 'Не вдалося перевірити оновлення (немає інтернету або репозиторію).' }
    return
}
$available = (Ver $remote.version) -gt (Ver $current)

if (-not $Apply) {
    Out-Json @{ current = $current; latest = $remote.version; available = $available; notes = @($remote.notes); date = $remote.date }
    return
}
if (-not $available) { Out-Json @{ ok = $true; current = $current; msg = 'Уже остання версія.' }; return }

# ---- download + verify everything first, install only if all files are good
$stage = Join-Path $valo "update-$($remote.version)"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Log "update $current -> $($remote.version)"
foreach ($f in $remote.files) {
    $rel = [string]$f.path
    if ($rel -notmatch '^(pack|wallpapers)/[A-Za-z0-9._/-]+$' -or $rel -match '\.\.') { Out-Json @{ ok = $false; error = "Підозрілий шлях у маніфесті: $rel" }; return }
    $dst = Join-Path $stage ($rel -replace '/', '\')
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    try { Invoke-WebRequest -Uri "$base/$rel" -OutFile $dst -UseBasicParsing -TimeoutSec 60 }
    catch { Log "download failed $rel : $_"; Out-Json @{ ok = $false; error = "Не вдалося завантажити $rel" }; return }
    $h = (Get-FileHash $dst -Algorithm SHA256).Hash
    if ($h -ne ([string]$f.sha256).ToUpper()) { Log "hash mismatch $rel"; Out-Json @{ ok = $false; error = "Файл $rel пошкоджений (не збігається SHA-256)" }; return }
}

# ---- backup current pack, install
$bk = Join-Path $valo "backup\$current-$(Get-Date -f yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Force $bk | Out-Null
Copy-Item (Join-Path $pack '*') $bk -Recurse -Force
if (Test-Path "$stage\pack") { Copy-Item "$stage\pack\*" $pack -Recurse -Force }
if (Test-Path "$stage\wallpapers") {
    $wp = Join-Path $valo 'wallpapers'; New-Item -ItemType Directory -Force $wp | Out-Null
    Copy-Item "$stage\wallpapers\*" $wp -Recurse -Force
}
$installed = [ordered]@{ version = $remote.version; date = $remote.date; notes = @($remote.notes); installedAt = (Get-Date -f s) }
[IO.File]::WriteAllText((Join-Path $pack 'version.json'), ($installed | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
Remove-Item $stage -Recurse -Force
Log "installed $($remote.version), backup $bk"
Out-Json @{ ok = $true; version = $remote.version; backup = $bk }

# ---- restart Zebar from a detached process (this script is a child of Zebar)
$zebar = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
$cmd = "Start-Sleep -Milliseconds 800; Stop-Process -Name zebar -Force; Start-Sleep -Milliseconds 1800; Start-Process '$zebar'"
Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', $cmd
