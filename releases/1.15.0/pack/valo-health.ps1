# valo.os PC health: disks, big folders, battery wear, startup apps (on/off for the current user), temp files, Windows updates.
#   -Summary                     -> {"disks":[..],"folders":[..],"battery":{..},"startup":[..],"temp":bytes}
#   -Startup <name> -On 0|1      -> enable / disable a startup entry of this user (same switch as Task Manager)
#   -CleanTemp                   -> deletes files older than a day from %TEMP% (in-use files are skipped)
#   -Updates                     -> pending Windows updates (slow: up to a minute)
param([switch]$Summary, [string]$Startup, [int]$On = 1, [switch]$CleanTemp, [switch]$Updates)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 4)) }
$approvedHKCU = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'

function Get-StartupItems {
    $items = @()
    $runs = @(@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'user', $approvedHKCU), @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'machine', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'))
    foreach ($r in $runs) {
        $k = Get-Item $r[0]; if (-not $k) { continue }
        foreach ($n in $k.GetValueNames()) {
            if (-not $n) { continue }
            $bin = (Get-ItemProperty $r[2] -Name $n).$n
            $enabled = -not ($bin -and ($bin[0] -band 1))
            $items += [pscustomobject]@{ name = $n; cmd = [string]$k.GetValue($n); scope = $r[1]; enabled = $enabled; valo = ($n -like 'valo-*') }
        }
    }
    foreach ($dir in @([Environment]::GetFolderPath('Startup'))) {
        foreach ($f in Get-ChildItem $dir -File) {
            $bin = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' -Name $f.Name).($f.Name)
            $items += [pscustomobject]@{ name = $f.Name; cmd = $f.FullName; scope = 'folder'; enabled = -not ($bin -and ($bin[0] -band 1)); valo = $false }
        }
    }
    $items
}

if ($Summary) {
    $disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { [pscustomobject]@{ name = $_.DeviceID; label = $_.VolumeName; size = [int64]$_.Size; free = [int64]$_.FreeSpace } })
    $fso = New-Object -ComObject Scripting.FileSystemObject
    $folders = @()
    foreach ($f in @(@('Завантаження', (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path), @('Відео', [Environment]::GetFolderPath('MyVideos')),
                      @('Зображення', [Environment]::GetFolderPath('MyPictures')), @('Документи', [Environment]::GetFolderPath('MyDocuments')),
                      @('Робочий стіл', [Environment]::GetFolderPath('DesktopDirectory')), @('Тимчасові файли', $env:TEMP))) {
        $sz = 0; try { $sz = [int64]$fso.GetFolder($f[1]).Size } catch { }
        if (-not $sz) { $sz = [int64](Get-ChildItem -LiteralPath $f[1] -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum }   # FSO gives up on folders it can't fully read
        if ($f[1]) { $folders += [pscustomobject]@{ name = $f[0]; path = $f[1]; size = $sz } }
    }
    $bat = $null
    try {
        $d = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        $c = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        $cyc = (Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction SilentlyContinue | Select-Object -First 1).CycleCount
        if ($d -gt 0 -and $c -gt 0) { $bat = [pscustomobject]@{ design = [int]$d; full = [int]$c; health = [math]::Round(100 * $c / $d); cycles = $cyc } }
    } catch { }
    if (-not $bat) {   # without admin rights root\wmi is closed: the battery report has the same numbers
        $x = Join-Path $env:TEMP 'valo-battery.xml'; powercfg /batteryreport /xml /output "$x" 2>$null | Out-Null
        try { [xml]$br = Get-Content $x -Raw; $b0 = @($br.BatteryReport.Batteries.Battery)[0]; if ($b0 -and [int]$b0.DesignCapacity -gt 0) { $bat = [pscustomobject]@{ design = [int]$b0.DesignCapacity; full = [int]$b0.FullChargeCapacity; health = [math]::Round(100 * [int]$b0.FullChargeCapacity / [int]$b0.DesignCapacity); cycles = $b0.CycleCount } } } catch { }
        Remove-Item $x -EA SilentlyContinue
    }
    $temp = ($folders | Where-Object { $_.path -eq $env:TEMP }).size
    $up = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    Out-Json @{ disks = $disks; folders = $folders; battery = $bat; startup = @(Get-StartupItems); temp = $temp; bootAt = $up.ToString('s') }
}
elseif ($Startup) {
    $it = Get-StartupItems | Where-Object { $_.name -eq $Startup } | Select-Object -First 1
    if (-not $it) { Out-Json @{ ok = $false; error = 'not found' }; return }
    if ($it.scope -eq 'machine') { Out-Json @{ ok = $false; error = 'Цей запис для всіх користувачів — потрібні права адміністратора (Диспетчер завдань → Автозавантаження)' }; return }
    $key = if ($it.scope -eq 'folder') { 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' } else { $approvedHKCU }
    if (-not (Test-Path $key)) { New-Item $key -Force | Out-Null }
    [byte[]]$val = 0x02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    if (-not $On) { $val[0] = 0x03; [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()).CopyTo($val, 4) }
    Set-ItemProperty $key -Name $Startup -Value $val -Type Binary
    Out-Json @{ ok = $true }
}
elseif ($CleanTemp) {
    $n = 0; $bytes = 0
    Get-ChildItem $env:TEMP -Recurse -File -Force -EA SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) -and $_.FullName -notlike '*\claude\*' } | ForEach-Object {
        $len = $_.Length; try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop; $n++; $bytes += $len } catch { } }
    Out-Json @{ ok = $true; files = $n; bytes = $bytes }
}
elseif ($Updates) {
    try {
        $s = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
        $r = $s.Search('IsInstalled=0 and IsHidden=0 and Type=''Software''')
        Out-Json @{ ok = $true; list = @($r.Updates | ForEach-Object { $_.Title }) }
    } catch { Out-Json @{ ok = $false; error = "$($_.Exception.Message)" } }
}
