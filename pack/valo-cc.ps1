# valo.os control center backend: Wi-Fi / Bluetooth radios, Wi-Fi networks, screen brightness, now-playing cover art.
#   -Action state                      -> {"radios":[{kind,on}],"bright":n|null,"wifi":[{ssid,signal,known,connected}],"connected":ssid}
#   -Action radio -Kind WiFi|Bluetooth -On 1|0
#   -Action bright -Value 0..100
#   -Action connect -Ssid <name>       (only networks with a saved profile; others open the Windows flyout)
#   -Action art                        -> {"title":..,"art":base64|null}
param([string]$Action = 'state', [string]$Kind, [int]$On = 1, [int]$Value = 50, [string]$Ssid)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await($op, [Type]$type) {
    $t = $asTaskGeneric.MakeGenericMethod($type).Invoke($null, @($op))
    if (-not $t.Wait(4000)) { return $null }
    $t.Result
}

function Get-Radios {
    $null = [Windows.Devices.Radios.Radio, Windows.System.Devices, ContentType = WindowsRuntime]
    $null = Await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus])
    Await ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
}

function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 4)) }

switch ($Action) {
    'state' {
        $radios = @(Get-Radios | Where-Object { $_.Kind -in 'WiFi', 'Bluetooth' } | ForEach-Object { [pscustomobject]@{ kind = "$($_.Kind)"; on = ("$($_.State)" -eq 'On') } })
        $bright = $null
        try { $b = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1; if ($b) { $bright = [int]$b.CurrentBrightness } } catch { }

        # Wi-Fi: netsh labels are localized, so only the language-neutral bits are parsed (SSID lines, "NN%", profile names)
        $connected = ''
        foreach ($l in (netsh wlan show interfaces)) { if ($l -match '^\s+SSID\s+:\s(.+)$') { $connected = $Matches[1].Trim(); break } }
        $known = @{}
        $inList = $false
        foreach ($l in (netsh wlan show profiles)) {
            if ($l -match '^-{4,}') { $inList = $true; continue }
            if ($inList -and $l -match '^\s{4}\S.*?\s:\s(.+)$') { $known[$Matches[1].Trim()] = 1 }
        }
        $nets = [Collections.Generic.List[object]]::new()
        $cur = $null
        foreach ($l in (netsh wlan show networks mode=bssid)) {
            if ($l -match '^SSID \d+\s*:\s?(.*)$') { $cur = [pscustomobject]@{ ssid = $Matches[1].Trim(); signal = 0; known = $false; connected = $false }; if ($cur.ssid) { $nets.Add($cur) } ; continue }
            if ($cur -and $l -match ':\s*(\d{1,3})%\s*$') { $cur.signal = [Math]::Max($cur.signal, [int]$Matches[1]) }
        }
        foreach ($n in $nets) { $n.known = $known.ContainsKey($n.ssid); $n.connected = ($n.ssid -eq $connected) }
        $wifi = @($nets | Sort-Object @{ e = { -not $_.connected } }, @{ e = { -$_.signal } } | Select-Object -First 12)
        Out-Json ([pscustomobject]@{ radios = $radios; bright = $bright; wifi = $wifi; connected = $connected })
    }
    'radio' {
        $r = Get-Radios | Where-Object { "$($_.Kind)" -eq $Kind } | Select-Object -First 1
        if (-not $r) { Out-Json @{ ok = $false; error = 'no radio' }; break }
        $state = if ($On) { [Windows.Devices.Radios.RadioState]::On } else { [Windows.Devices.Radios.RadioState]::Off }
        $res = Await ($r.SetStateAsync($state)) ([Windows.Devices.Radios.RadioAccessStatus])
        Out-Json @{ ok = ("$res" -eq 'Allowed'); status = "$res" }
    }
    'bright' {
        $v = [Math]::Max(0, [Math]::Min(100, $Value))
        $m = Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods | Select-Object -First 1
        if ($m) { Invoke-CimMethod -InputObject $m -MethodName WmiSetBrightness -Arguments @{ Timeout = [uint32]1; Brightness = [byte]$v } | Out-Null; Out-Json @{ ok = $true } }
        else { Out-Json @{ ok = $false } }
    }
    'connect' {
        $out = netsh wlan connect name="$Ssid" 2>&1 | Out-String
        Out-Json @{ ok = ($LASTEXITCODE -eq 0); msg = $out.Trim() }
    }
    'art' {
        $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
        $mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
        $s = if ($mgr) { $mgr.GetCurrentSession() }
        if (-not $s) { Out-Json @{ title = ''; art = $null }; break }
        $p = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
        $art = $null
        if ($p -and $p.Thumbnail) {
            $null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]
            $st = Await ($p.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
            if ($st) {
                $ns = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($st)
                $ms = New-Object IO.MemoryStream; $ns.CopyTo($ms)
                if ($ms.Length -gt 0) { $art = [Convert]::ToBase64String($ms.ToArray()) }
            }
        }
        Out-Json @{ title = "$($p.Title)"; artist = "$($p.Artist)"; art = $art }
    }
}
