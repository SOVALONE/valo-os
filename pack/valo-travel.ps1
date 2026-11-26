# valo.os "В дорозі" (travel) mode: power-saving power mode, live wallpaper paused, dimmer screen. -On / -Off.
# The previous state is kept in %LOCALAPPDATA%\valo\travel.json and restored by -Off.
param([switch]$On, [switch]$Off)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$state = Join-Path $env:LOCALAPPDATA 'valo\travel.json'
$efficiency = '961cc777-2547-4f9d-8174-7d86181b8a7a'   # "best power efficiency" power mode overlay
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }
function Lively([string[]]$a) {
    foreach ($r in "$env:LOCALAPPDATA\Programs\Lively Wallpaper", "$env:ProgramFiles\Lively Wallpaper") {
        foreach ($n in 'Livelycu.exe', 'Lively.exe') { if (Test-Path "$r\$n") { & "$r\$n" @a | Out-Null; return $true } }
    }
    $false
}
function Bright { try { [int](Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1).CurrentBrightness } catch { $null } }
function SetBright([int]$v) { $m = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods | Select-Object -First 1; if ($m) { Invoke-CimMethod -InputObject $m -MethodName WmiSetBrightness -Arguments @{ Timeout = [uint32]1; Brightness = [byte]$v } | Out-Null } }

if ($On) {
    $prevOverlay = ((powercfg /getactiveoverlayscheme) -join ' ' | Select-String -Pattern '[0-9a-f]{8}-[0-9a-f-]{27}' -AllMatches).Matches.Value | Select-Object -First 1
    $prev = [ordered]@{ overlay = $prevOverlay; bright = (Bright) }
    New-Item -ItemType Directory -Force (Split-Path $state) | Out-Null
    [IO.File]::WriteAllText($state, ($prev | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    powercfg /overlaysetactive $efficiency | Out-Null
    $power = $LASTEXITCODE -eq 0
    if ($prev.bright -ne $null -and $prev.bright -gt 60) { SetBright 60 }
    $lively = Lively @('app', '--play', 'false')
    Out-Json @{ ok = $true; on = $true; power = $power; lively = $lively }
}
elseif ($Off) {
    $prev = $null; if (Test-Path $state) { $prev = Get-Content $state -Raw | ConvertFrom-Json }
    $overlay = if ($prev -and $prev.overlay) { $prev.overlay } else { '00000000-0000-0000-0000-000000000000' }   # balanced
    powercfg /overlaysetactive $overlay | Out-Null
    if ($prev -and $prev.bright -ne $null) { SetBright ([int]$prev.bright) }
    $null = Lively @('app', '--play', 'true')
    Remove-Item $state -EA SilentlyContinue
    Out-Json @{ ok = $true; on = $false }
}
