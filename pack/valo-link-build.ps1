# valo Link setup: icon, Start menu shortcut, autostart (hidden in the tray), and (re)start.
# valo Link runs inside Windows PowerShell (valo-link.ps1) — a self-built .exe would be blocked by Smart App Control.
# Run by valo-postupdate.ps1 and by the installer.
$ErrorActionPreference = 'SilentlyContinue'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ico = Join-Path $dir 'valo-link.ico'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$psArgs = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$dir\valo-link.ps1`""

# icon: the valo mark as a PNG inside an .ico
if (-not (Test-Path $ico)) {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object Drawing.Bitmap 256, 256
    $g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
    $path = New-Object Drawing.Drawing2D.GraphicsPath; $r = 112
    $path.AddArc(0, 0, $r, $r, 180, 90); $path.AddArc(255 - $r, 0, $r, $r, 270, 90); $path.AddArc(255 - $r, 255 - $r, $r, $r, 0, 90); $path.AddArc(0, 255 - $r, $r, $r, 90, 90); $path.CloseFigure()
    $g.FillPath((New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml('#f2a7bb'))), $path)
    $g.TranslateTransform(128, 140); $g.ScaleTransform(0.85, 0.85)
    $ink = New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml('#1e1a1f'))
    for ($i = 0; $i -lt 3; $i++) {
        $b = New-Object Drawing.Drawing2D.GraphicsPath
        $b.AddBezier(0, -130, 1, -62, 3, -38, 23, -23); $b.AddBezier(23, -23, 12, -30, 4, -28, 0, -23); $b.AddBezier(0, -23, -4, -28, -12, -30, -23, -23); $b.AddBezier(-23, -23, -3, -38, -1, -62, 0, -130); $b.CloseFigure()
        $g.FillPath($ink, $b); $g.RotateTransform(120)
    }
    foreach ($c in @(@(0, 12), @(10.4, -6), @(-10.4, -6))) { $g.FillEllipse($ink, $c[0] - 12.5, $c[1] - 12.5, 25, 25) }
    $g.Dispose()
    $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $png = $ms.ToArray(); $bmp.Dispose()
    $w = New-Object IO.BinaryWriter ([IO.File]::Create($ico))
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)
    $w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$png.Length); $w.Write([uint32]22)
    $w.Write($png); $w.Close()
}

# old builds left an .exe that Smart App Control blocks — remove it
Remove-Item (Join-Path $dir 'valo-link.exe'), (Join-Path $dir 'valo-link.hash') -Force

$lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'valo Link.lnk'
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk); $s.TargetPath = $ps; $s.Arguments = $psArgs; $s.WorkingDirectory = $dir
$s.Description = 'valo Link — телефон і ПК разом'; $s.IconLocation = "$ico,0"; $s.WindowStyle = 7; $s.Save()
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'valo-link' -Value "`"$ps`" $psArgs --hidden"

# restart so a new version is used
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*valo-link.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Sleep -Milliseconds 400
Start-Process $ps -ArgumentList "$psArgs --hidden" -WindowStyle Hidden
