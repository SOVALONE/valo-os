# valo.os: colour palette from an image for the custom theme.
#   (no args)  -> current desktop wallpaper      -Pick -> choose a picture      -Path <file>
#   -> {"solid":"#..","accent":"#..","accent2":"#..","text":"#..","source":"path"} or {"error":..}
param([string]$Path, [switch]$Pick)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }

if ($Pick) {
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Title = 'Картинка для теми valo.os'; $dlg.Filter = 'Зображення|*.jpg;*.jpeg;*.png;*.bmp;*.webp;*.gif'
    $dlg.InitialDirectory = [Environment]::GetFolderPath('MyPictures')
    $owner = New-Object Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false; Opacity = 0 }
    $owner.Show(); $owner.Activate()
    if ($dlg.ShowDialog($owner) -ne 'OK') { $owner.Close(); Out-Json @{ error = 'cancel' }; return }
    $owner.Close(); $Path = $dlg.FileName
}
if (-not $Path) {
    $Path = (Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallPaper
    if (-not $Path -or -not (Test-Path $Path)) { $Path = "$env:APPDATA\Microsoft\Windows\Themes\TranscodedWallpaper" }
}
if (-not (Test-Path $Path)) { Out-Json @{ error = 'Не знайдено зображення шпалер' }; return }

try { $src = [Drawing.Image]::FromFile($Path) } catch { Out-Json @{ error = 'Не вдалося відкрити зображення' }; return }
$bmp = New-Object Drawing.Bitmap 64, 64
$g = [Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBilinear'; $g.DrawImage($src, 0, 0, 64, 64); $g.Dispose(); $src.Dispose()

# buckets of similar colours: count + average
$buckets = @{}
for ($y = 0; $y -lt 64; $y++) { for ($x = 0; $x -lt 64; $x++) {
    $c = $bmp.GetPixel($x, $y)
    $k = (($c.R -shr 4) -shl 8) -bor (($c.G -shr 4) -shl 4) -bor ($c.B -shr 4)
    if (-not $buckets.ContainsKey($k)) { $buckets[$k] = @(0, 0, 0, 0) }
    $b = $buckets[$k]; $b[0]++; $b[1] += $c.R; $b[2] += $c.G; $b[3] += $c.B
} }
$bmp.Dispose()
$cols = foreach ($b in $buckets.Values) {
    $c = [Drawing.Color]::FromArgb([int]($b[1] / $b[0]), [int]($b[2] / $b[0]), [int]($b[3] / $b[0]))
    [pscustomobject]@{ c = $c; n = $b[0]; h = $c.GetHue(); s = $c.GetSaturation(); l = $c.GetBrightness() }
}
function HslHex([double]$h, [double]$s, [double]$l) {
    $q = if ($l -lt 0.5) { $l * (1 + $s) } else { $l + $s - $l * $s }; $p = 2 * $l - $q
    $f = { param($t) if ($t -lt 0) { $t += 1 }; if ($t -gt 1) { $t -= 1 }
        if ($t -lt 1 / 6) { return $p + ($q - $p) * 6 * $t }; if ($t -lt 0.5) { return $q }; if ($t -lt 2 / 3) { return $p + ($q - $p) * (2 / 3 - $t) * 6 }; return $p }
    $hh = $h / 360
    '#{0:x2}{1:x2}{2:x2}' -f [int](255 * (& $f ($hh + 1 / 3))), [int](255 * (& $f $hh)), [int](255 * (& $f ($hh - 1 / 3)))
}
# background: the most common colour, pushed dark; accent: most vivid frequent colour; accent2: next vivid with a different hue
$dom = $cols | Sort-Object n -Descending | Select-Object -First 1
$vivid = $cols | Where-Object { $_.s -gt 0.25 -and $_.l -gt 0.2 -and $_.l -lt 0.85 } | Sort-Object { $_.n * $_.s * $_.s } -Descending
$acc = $vivid | Select-Object -First 1
if (-not $acc) { $acc = [pscustomobject]@{ h = $dom.h; s = 0.5 } }
$acc2 = $vivid | Where-Object { [Math]::Min([Math]::Abs($_.h - $acc.h), 360 - [Math]::Abs($_.h - $acc.h)) -gt 25 } | Select-Object -First 1
if (-not $acc2) { $acc2 = [pscustomobject]@{ h = ($acc.h + 25) % 360; s = $acc.s } }
$solid = HslHex $dom.h ([Math]::Min(0.35, $dom.s)) 0.11
$accent = HslHex $acc.h ([Math]::Max(0.55, [Math]::Min(0.85, $acc.s))) 0.72
$accent2 = HslHex $acc2.h ([Math]::Max(0.5, [Math]::Min(0.8, $acc2.s))) 0.62
$text = HslHex $acc.h 0.35 0.93
Out-Json @{ solid = $solid; accent = $accent; accent2 = $accent2; text = $text; source = $Path }
