# valo menu: list Start menu apps as JSON [{n:name, id:AppID, ic:base64png|null}], cached in %LOCALAPPDATA%\valo\apps.json
param([switch]$Cached)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$cache = "$env:LOCALAPPDATA\valo\apps.json"
if ($Cached) { if (Test-Path $cache) { [IO.File]::ReadAllText($cache) } else { '[]' }; return }

Add-Type -AssemblyName System.Drawing

function To-Png([Drawing.Image]$img) {
    $bmp = New-Object Drawing.Bitmap 48, 48
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($img, 0, 0, 48, 48)
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    [Convert]::ToBase64String($ms.ToArray())
}
function Icon-FromFile([string]$path) {
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $null }
    $ico = [Drawing.Icon]::ExtractAssociatedIcon($path)
    if (-not $ico) { return $null }
    $b = $ico.ToBitmap(); try { To-Png $b } finally { $b.Dispose() }
}

$known = @{
    '{6D809377-6AF0-444B-8957-A3773F02200E}' = $env:ProgramFiles
    '{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}' = ${env:ProgramFiles(x86)}
    '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}' = "$env:windir\System32"
    '{F38BF404-1D43-42F2-9305-67DE0B28FC23}' = $env:windir
}

# shortcuts by display name
$shell = New-Object -ComObject WScript.Shell
$lnk = @{}
foreach ($d in "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs") {
    Get-ChildItem $d -Recurse -Filter *.lnk | ForEach-Object { if (-not $lnk.ContainsKey($_.BaseName)) { $lnk[$_.BaseName] = $_.FullName } }
}
# internet shortcuts (Steam games etc.) carry an IconFile
$urlIcon = @{}
foreach ($d in "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs", "$env:USERPROFILE\Desktop", "$env:PUBLIC\Desktop") {
    Get-ChildItem $d -Recurse -Filter *.url | ForEach-Object {
        $line = Select-String -LiteralPath $_.FullName -Pattern '^IconFile=(.+)$' | Select-Object -First 1
        if ($line) { $urlIcon[$_.BaseName] = $line.Matches[0].Groups[1].Value.Trim() }
    }
}
$special = @{ 'Microsoft.Windows.Explorer' = "$env:windir\explorer.exe"; 'Microsoft.Windows.ControlPanel' = "$env:windir\System32\control.exe";
              'Microsoft.Windows.Shell.RunDialog' = "$env:windir\System32\shell32.dll"; 'Microsoft.Windows.RemoteDesktop' = "$env:windir\System32\mstsc.exe" }

# packaged (UWP) apps: family name -> install folder
$pkg = @{}
Get-AppxPackage | ForEach-Object { $pkg[$_.PackageFamilyName] = $_.InstallLocation }

function Icon-Uwp([string]$aumid) {
    $fam, $app = $aumid -split '!', 2
    $dir = $pkg[$fam]; if (-not $dir) { return $null }
    [xml]$m = Get-Content -LiteralPath "$dir\AppxManifest.xml" -Raw
    $a = $m.Package.Applications.Application | Where-Object { $_.Id -eq $app } | Select-Object -First 1
    if (-not $a) { return $null }
    $ve = $a.ChildNodes | Where-Object { $_.LocalName -eq 'VisualElements' } | Select-Object -First 1
    $logo = $ve.Square44x44Logo; if (-not $logo) { $logo = $ve.Square150x150Logo }
    if (-not $logo) { return $null }
    $base = Join-Path $dir ([IO.Path]::GetDirectoryName($logo))
    $stem = [IO.Path]::GetFileNameWithoutExtension($logo)
    $files = Get-ChildItem -LiteralPath $base -Filter "$stem*.png"
    $pick = ($files | Where-Object Name -match 'targetsize-48(_altform-unplated)?\.png$' | Select-Object -First 1)
    if (-not $pick) { $pick = $files | Where-Object Name -match 'altform-unplated' | Sort-Object Length -Descending | Select-Object -First 1 }
    if (-not $pick) { $pick = $files | Where-Object Name -match 'scale-200|scale-100' | Select-Object -First 1 }
    if (-not $pick) { $pick = $files | Select-Object -First 1 }
    if (-not $pick) { return $null }
    $img = [Drawing.Image]::FromFile($pick.FullName); try { To-Png $img } finally { $img.Dispose() }
}

$skip = 'uninstall|деінстал|видалити|readme|release notes|documentation|довідка|website|веб-сайт'
$out = New-Object System.Collections.Generic.List[object]
foreach ($a in Get-StartApps | Sort-Object Name -Unique) {
    if ($a.Name -match $skip -or $a.AppID -match '^https?://') { continue }
    $ic = $null
    $target = $null
    if ($a.AppID -match '!') { $ic = Icon-Uwp $a.AppID }
    if (-not $ic) {
        $p = $a.AppID
        foreach ($k in $known.Keys) { if ($p.StartsWith($k)) { $p = $known[$k] + $p.Substring($k.Length) } }
        if ($p -match '^[A-Za-z]:\\' -and (Test-Path -LiteralPath $p)) { $ic = Icon-FromFile $p; $target = $p }
    }
    if (-not $target -and $special[$a.AppID]) { $target = $special[$a.AppID] }
    if (-not $target -and $lnk[$a.Name]) { $tp = $shell.CreateShortcut($lnk[$a.Name]).TargetPath; if ($tp -match '\.exe$') { $target = $tp } }
    if (-not $ic -and $special[$a.AppID]) { $ic = Icon-FromFile $special[$a.AppID] }
    if (-not $ic -and $urlIcon[$a.Name]) { $ic = Icon-FromFile $urlIcon[$a.Name] }
    if (-not $ic -and $lnk[$a.Name]) {
        $s = $shell.CreateShortcut($lnk[$a.Name])
        $src = if ($s.IconLocation -and $s.IconLocation -notmatch '^,') { ($s.IconLocation -split ',')[0] } else { $s.TargetPath }
        $src = [Environment]::ExpandEnvironmentVariables($src)
        $ic = Icon-FromFile $src
        if (-not $ic) { $ic = Icon-FromFile $lnk[$a.Name] }
    }
    $out.Add([pscustomobject]@{ n = $a.Name; id = $a.AppID; ic = $ic; t = $target })
}

$json = ConvertTo-Json -InputObject $out.ToArray() -Compress -Depth 3
New-Item -ItemType Directory -Force (Split-Path $cache) | Out-Null
[IO.File]::WriteAllText($cache, $json, [Text.UTF8Encoding]::new($false))
$json
