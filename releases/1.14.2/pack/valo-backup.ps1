# valo.os settings backup: theme, panel, dock, pins, tools... (the localStorage of the widgets) to / from a JSON file.
#   -Save <base64 of the JSON>  -> writes Documents\valo-налаштування-<date>.json, prints {"ok":true,"path":..}
#   -Load                       -> file dialog, prints the file content (JSON) or {"error":..}
param([string]$Save, [switch]$Load)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
Add-Type -AssemblyName System.Windows.Forms
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }

if ($Save) {
    $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Save))
    $path = Join-Path ([Environment]::GetFolderPath('MyDocuments')) ("valo-налаштування-" + (Get-Date -f 'yyyy-MM-dd-HHmm') + '.json')
    [IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))
    Out-Json @{ ok = $true; path = $path }
}
elseif ($Load) {
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Title = 'Відновити налаштування valo.os'; $dlg.Filter = 'Налаштування valo.os|valo-*.json|JSON|*.json'
    $dlg.InitialDirectory = [Environment]::GetFolderPath('MyDocuments')
    $owner = New-Object Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false; Opacity = 0 }
    $owner.Show(); $owner.Activate()
    $r = $dlg.ShowDialog($owner); $owner.Close()
    if ($r -ne 'OK') { Out-Json @{ error = 'cancel' }; return }
    [Console]::Out.Write([IO.File]::ReadAllText($dlg.FileName, [Text.Encoding]::UTF8))
}
