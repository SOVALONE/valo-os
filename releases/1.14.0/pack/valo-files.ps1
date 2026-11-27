# valo.os: the Files app (FilesCommunity.Files) as the default file manager — folders, «Відкрити папку», Win+E.
# Same per-user registry keys that Files' own "Set as default" writes (HKCU only, no administrator rights);
# the launcher comes from the installed Files package (Assets\FilesOpenDialog).
#   -Status  -> {"installed":true|false,"default":true|false}
#   -Set     -> make Files the default            -Unset  -> back to Windows Explorer
param([switch]$Status, [switch]$Set, [switch]$Unset)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write((ConvertTo-Json -InputObject $o -Compress)) }
$data = Join-Path $env:LOCALAPPDATA 'Files'
$launcher = Join-Path $data 'Files.App.Launcher.exe'
$cmdOpen = '"%LOCALAPPDATA%\Files\Files.App.Launcher.exe" "%1"'
$cmdWinE = '"%LOCALAPPDATA%\Files\Files.App.Launcher.exe"'
$keys = @{
    'Software\Classes\Folder\shell\open\command'    = $cmdOpen
    'Software\Classes\Folder\shell\explore\command' = $cmdOpen
    'Software\Classes\CLSID\{52205fd8-5dfb-447d-801a-d0b52f2e83e1}\shell\opennewwindow\command' = $cmdWinE
}
function Pkg { Get-AppxPackage -Name 'Files' -EA SilentlyContinue | Where-Object { Test-Path (Join-Path $_.InstallLocation 'Assets\FilesOpenDialog\Files.App.Launcher.exe') } | Sort-Object Version -Descending | Select-Object -First 1 }
function IsDefault {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\Folder\shell\open\command')
    if (-not $k) { return $false }
    $v = $k.GetValue('', $null, 'DoNotExpandEnvironmentNames'); $k.Close()
    return ("$v" -like '*Files.App.Launcher.exe*') -and (Test-Path $launcher)
}
function Write-Key($path, $value) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($path)
    $k.SetValue('', $value, 'ExpandString'); $k.SetValue('DelegateExecute', '', 'String'); $k.Close()
}

try {
    if ($Status) { Out-Json ([ordered]@{ installed = [bool](Pkg); default = (IsDefault) }) }
    elseif ($Set) {
        $p = Pkg; if (-not $p) { throw 'Files не встановлено' }
        New-Item -ItemType Directory -Force $data | Out-Null
        Copy-Item (Join-Path $p.InstallLocation 'Assets\FilesOpenDialog\*') $data -Force   # launcher + Files' own undo .reg
        [IO.File]::WriteAllText((Join-Path $data 'Branch.txt'), 'files-stable', [Text.UTF8Encoding]::new($false))
        foreach ($k in $keys.Keys) { Write-Key $k $keys[$k] }
        Out-Json @{ ok = (IsDefault) }
    }
    elseif ($Unset) {
        # only the per-user keys go; Windows then falls back to its own Explorer entries
        foreach ($k in $keys.Keys) { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($k, $false) }
        foreach ($k in 'Software\Classes\Folder\shell\open', 'Software\Classes\Folder\shell\explore', 'Software\Classes\CLSID\{52205fd8-5dfb-447d-801a-d0b52f2e83e1}\shell\opennewwindow',
                    'Software\Classes\Folder\shell', 'Software\Classes\Folder', 'Software\Classes\CLSID\{52205fd8-5dfb-447d-801a-d0b52f2e83e1}\shell', 'Software\Classes\CLSID\{52205fd8-5dfb-447d-801a-d0b52f2e83e1}') {
            $s = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($k)
            if ($s) { $empty = $s.SubKeyCount -eq 0 -and $s.ValueCount -eq 0; $s.Close(); if ($empty) { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($k, $false) } }
        }
        Out-Json @{ ok = -not (IsDefault) }
    }
} catch { Out-Json @{ ok = $false; error = "$_" } }
