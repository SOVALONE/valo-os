# valo.os: put the live wallpaper of a theme on the desktop through Lively Wallpaper (if it is installed).
#   -Theme sakura|night|matcha|latte|graphite|sunset      -> {"ok":true} / {"ok":false,"error":..}
#   -Library    -> copy every valo live wallpaper into Lively's library (they show up in Lively next to its own) -> {"ok":true,"added":N}
param([string]$Theme = 'sakura', [switch]$Lock, [switch]$Library)   # -Lock: only set the Windows lock screen picture of the theme
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }
$lib = Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\Library\wallpapers'
# valo-<theme> folders -> Lively library (refreshed when valo ships a newer version); returns how many are new there
function Sync-Library {
    if (-not (Test-Path $lib)) { return -1 }
    $added = 0
    foreach ($src in Get-ChildItem (Join-Path $env:LOCALAPPDATA 'valo\wallpapers') -Directory -Filter 'valo-*') {
        if (-not (Test-Path "$($src.FullName)\LivelyInfo.json")) { continue }
        $dst = Join-Path $lib $src.Name
        if (-not (Test-Path $dst)) { $added++ }
        elseif ((Get-Item "$dst\LivelyInfo.json").LastWriteTime -ge (Get-Item "$($src.FullName)\LivelyInfo.json").LastWriteTime -and
                (Get-ChildItem $dst -Recurse -File).Count -ge (Get-ChildItem $src.FullName -Recurse -File).Count) { continue }
        New-Item -ItemType Directory -Force $dst | Out-Null
        Copy-Item "$($src.FullName)\*" $dst -Recurse -Force
    }
    $added
}
if ($Library) {
    $n = Sync-Library
    if ($n -lt 0) { Out-Json @{ ok = $false; error = 'Lively Wallpaper не встановлено' }; return }
    # Lively reads its library when it starts: restart it so the new ones appear
    if ($n -gt 0 -and (Get-Process Lively -EA SilentlyContinue)) {
        $exe = (Get-Process Lively | Select-Object -First 1).Path
        Get-Process Lively, Lively.UI.WinUI -EA SilentlyContinue | Stop-Process -Force; Start-Sleep 2
        if ($exe) { Start-Process $exe }
    }
    Out-Json @{ ok = $true; added = $n }; return
}

if ($Theme -notmatch '^[a-z]+$') { Out-Json @{ ok = $false; error = 'bad theme' }; return }
$wp = Join-Path $env:LOCALAPPDATA "valo\wallpapers\valo-$Theme"
if (-not (Test-Path "$wp\LivelyInfo.json")) { Out-Json @{ ok = $false; error = "Шпалери $Theme не знайдено" }; return }
if ($Lock) {
    # lock screen picture (current user, WinRT LockScreen API)
    $img = "$wp\lock.png"
    if (-not (Test-Path $img)) { Out-Json @{ ok = $false; error = 'Немає картинки для екрана блокування' }; return }
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 }
    $opT = $asTask | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
    $actT = $asTask | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' } | Select-Object -First 1
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
    try {
        $t1 = $opT.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @([Windows.Storage.StorageFile]::GetFileFromPathAsync($img))); $t1.Wait(5000) | Out-Null
        $t2 = $actT.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($t1.Result))); $t2.Wait(8000) | Out-Null
        Out-Json @{ ok = $true; lock = $img }
    } catch { Out-Json @{ ok = $false; error = "$($_.Exception.InnerException.Message)" } }
    return
}

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
if ((Sync-Library) -ge 0 -and (Test-Path (Join-Path $lib "valo-$Theme\LivelyInfo.json"))) { $wp = Join-Path $lib "valo-$Theme" }   # the library copy: Lively then shows it as the current one
& $cli setwp --file "$wp" | Out-Null
Add-Content -LiteralPath "$env:TEMP\valo-wallpaper.log" -Value ((Get-Date -f s) + " setwp $Theme via $cli exit $LASTEXITCODE")
Out-Json @{ ok = $true; cli = $cli }
