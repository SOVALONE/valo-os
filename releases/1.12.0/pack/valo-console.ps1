# valo.os console (fullscreen game mode for the TV / a gamepad): the game library.
#   -List          -> {"games":[{key,name,src,cover,last}]}   Steam, Epic, GOG and installed «Ігри valo»; covers are small cached JPEGs (data URIs)
#   -Hero <key>    -> {"img":data-uri|null}                    the wide background picture of a game (Steam), cached
#   -Launch <key>  -> {"ok":true|false}
param([switch]$List, [string]$Hero, [string]$Launch)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write((ConvertTo-Json -InputObject $o -Compress -Depth 5)) }
Add-Type -AssemblyName System.Drawing
$cache = Join-Path $env:LOCALAPPDATA 'valo\console'
New-Item -ItemType Directory -Force $cache | Out-Null

function Steam-Root { $p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath; if ($p) { $p.Replace('/', '\') } }
function Steam-Libs($root) {
    $libs = @($root)
    $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value.Replace('\\', '\') } }
    $seen = @{}; foreach ($l in $libs) { $k = $l.TrimEnd('\').ToLower(); if (-not $seen[$k]) { $seen[$k] = 1; $l } }
}
# Steam keeps the art per game in appcache\librarycache\<appid>\ (sometimes in a hashed subfolder)
function Steam-Art($root, $id, [string[]]$names) {
    $d = Join-Path $root "appcache\librarycache\$id"
    foreach ($n in $names) {
        $f = Get-ChildItem $d -Recurse -File -Filter $n | Select-Object -First 1
        if ($f) { return $f.FullName }
        $old = Join-Path $root "appcache\librarycache\${id}_$n"; if (Test-Path $old) { return $old }
    }
}
# resized copy in the cache, returned as a data URI
function Thumb($src, $key, $w, $h, $q) {
    if (-not $src -or -not (Test-Path $src)) { return $null }
    $safe = $key -replace '[^A-Za-z0-9_-]', '_'
    $out = Join-Path $cache "$safe-$w.jpg"
    if (-not (Test-Path $out) -or (Get-Item $out).LastWriteTime -lt (Get-Item $src).LastWriteTime) {
        try {
            $img = [Drawing.Image]::FromFile($src)
            if (-not $h) { $h = [int]($img.Height * $w / $img.Width) }
            $bmp = New-Object Drawing.Bitmap $w, $h
            $g = [Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'
            # cover-fit (crop the overflow)
            $s = [Math]::Max($w / $img.Width, $h / $img.Height); $dw = $img.Width * $s; $dh = $img.Height * $s
            $g.DrawImage($img, ($w - $dw) / 2, ($h - $dh) / 2, $dw, $dh); $g.Dispose(); $img.Dispose()
            $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $ep = New-Object Drawing.Imaging.EncoderParameters 1; $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality, [long]$q)
            $bmp.Save($out, $enc, $ep); $bmp.Dispose()
        } catch { return $null }
    }
    'data:image/jpeg;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($out))
}

function Games([switch]$Covers) {
    $list = New-Object Collections.Generic.List[object]
    # ---- Steam
    $root = Steam-Root
    if ($root -and (Test-Path $root)) {
        foreach ($lib in Steam-Libs $root) {
            foreach ($f in Get-ChildItem (Join-Path $lib 'steamapps') -Filter 'appmanifest_*.acf') {
                $t = Get-Content $f.FullName -Raw
                $id = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
                $name = [regex]::Match($t, '"name"\s+"([^"]+)"').Groups[1].Value
                if (-not $id -or $id -in '228980', '1070560', '1391110', '1628350', '250820' -or $name -match 'Redistributable|Proton|Steam Linux Runtime|SteamVR') { continue }
                $state = [regex]::Match($t, '"StateFlags"\s+"(\d+)"').Groups[1].Value
                if ($state -and ([int]$state -band 4) -eq 0) { continue }      # not fully installed
                $last = [regex]::Match($t, '"LastPlayed"\s+"(\d+)"').Groups[1].Value
                $g = [ordered]@{ key = "steam:$id"; name = $name; src = 'Steam'; last = [long]("0$last") }
                if ($Covers) { $g.cover = Thumb (Steam-Art $root $id 'library_600x900.jpg', 'library_capsule.jpg', 'header.jpg', 'library_header.jpg') "steam-$id" 300 450 82 }
                $list.Add($g)
            }
        }
    }
    # ---- Epic
    foreach ($f in Get-ChildItem 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests' -Filter *.item) {
        $m = Get-Content $f.FullName -Raw | ConvertFrom-Json
        if (-not $m.AppName -or $m.bIsIncompleteInstall) { continue }
        $g = [ordered]@{ key = "epic:$($m.AppName)"; name = $m.DisplayName; src = 'Epic'; last = 0 }
        if ($Covers) { $g.cover = $null }
        $list.Add($g)
    }
    # ---- GOG
    foreach ($k in Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games') {
        $p = Get-ItemProperty $k.PSPath
        if (-not $p.exe -or -not (Test-Path $p.exe)) { continue }
        $g = [ordered]@{ key = "gog:$($k.PSChildName)"; name = $p.gameName; src = 'GOG'; last = 0 }
        if ($Covers) { $g.cover = $null }
        $list.Add($g)
    }
    # ---- «Ігри valo»
    $vs = Join-Path $env:LOCALAPPDATA 'valo\games\installed.json'
    if (Test-Path $vs) {
        $cat = @{}; $cf = Join-Path $env:LOCALAPPDATA 'valo\games\catalog.json'
        if (Test-Path $cf) { foreach ($c in (Get-Content $cf -Raw -Encoding UTF8 | ConvertFrom-Json).games) { $cat[$c.id] = $c } }
        foreach ($p in (Get-Content $vs -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties) {
            if (-not $p.Value.exe) { continue }
            $n = if ($cat[$p.Name]) { $cat[$p.Name].name } else { $p.Name }
            $g = [ordered]@{ key = "valo:$($p.Name)"; name = $n; src = 'valo'; last = 0 }
            if ($Covers) { $g.cover = $null }
            $list.Add($g)
        }
    }
    $list
}

if ($List) { Out-Json @{ games = @(Games -Covers) } }
elseif ($Hero) {
    $img = $null
    if ($Hero -match '^steam:(\d+)$') { $root = Steam-Root; $img = Thumb (Steam-Art $root $Matches[1] 'library_hero.jpg', 'header.jpg') "hero-$($Matches[1])" 1600 0 78 }
    Out-Json @{ img = $img }
}
elseif ($Launch) {
    $ok = $true
    switch -Regex ($Launch) {
        '^steam:(\d+)$' { Start-Process "steam://rungameid/$($Matches[1])" }
        '^epic:([A-Za-z0-9._-]+)$' {
            $a = $Matches[1]; $m = Get-ChildItem 'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests' -Filter *.item | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json } | Where-Object { $_.AppName -eq $a } | Select-Object -First 1
            if ($m) { Start-Process "com.epicgames.launcher://apps/$($m.CatalogNamespace)%3A$($m.CatalogItemId)%3A$($m.AppName)?action=launch&silent=true" } else { $ok = $false }
        }
        '^gog:(\d+)$' { $p = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\$($Matches[1])"; if ($p.exe -and (Test-Path $p.exe)) { Start-Process $p.exe -WorkingDirectory $p.path } else { $ok = $false } }
        '^valo:([a-z0-9-]+)$' { $r = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'valo-games.ps1') -Play $Matches[1]; $ok = "$r" -match '"ok":true' }
        default { $ok = $false }
    }
    Out-Json @{ ok = $ok }
}
