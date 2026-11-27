# valo.os: run by valo-update.ps1 after a new version is installed (before Zebar restarts).
# Makes sure every valo widget starts with Zebar (new widgets come with updates).
$ErrorActionPreference = 'SilentlyContinue'
$settings = "$env:USERPROFILE\.glzr\zebar\settings.json"
if (-not (Test-Path $settings)) { return }
$cfg = Get-Content $settings -Raw | ConvertFrom-Json
$list = [Collections.Generic.List[object]]::new(); foreach ($c in @($cfg.startupConfigs)) { if ($c) { $list.Add($c) } }
$bar = $list | Where-Object { $_.pack -eq 'quill' -and $_.widget -eq 'bar' } | Select-Object -First 1
$host_ = $bar -and $bar.preset -like 'host*'
$want = [ordered]@{ menu = 'default'; dock = $(if ($host_) { 'host' } else { 'default' }); control = 'default'; welcome = 'default'; emoji = 'default'; saver = 'default'; desk = 'default' }
$changed = $false
foreach ($w in $want.Keys) {
    if (-not ($list | Where-Object { $_.pack -eq 'quill' -and $_.widget -eq $w })) {
        $list.Add([pscustomobject]@{ pack = 'quill'; widget = $w; preset = $want[$w] }); $changed = $true
    }
}
if ($changed) {
    $cfg.startupConfigs = $list.ToArray()
    [IO.File]::WriteAllText($settings, ($cfg | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
}

# valo Link (phone companion, optional — the valo Store installs it): refresh it only where it is installed
$lb = Join-Path $PSScriptRoot 'valo-link-build.ps1'
if (Test-Path $lb) { & $lb -Refresh }

# Files as the default file manager (1.14.0): once per PC where Files is installed; the menu switch can turn it off later
$fd = Join-Path $env:LOCALAPPDATA 'valo\files-default-done'
$vf = Join-Path $PSScriptRoot 'valo-files.ps1'
if (-not (Test-Path $fd) -and (Test-Path $vf)) {
    $st = & powershell -NoProfile -ExecutionPolicy Bypass -File $vf -Status
    if ("$st" -match '"installed":true') { & powershell -NoProfile -ExecutionPolicy Bypass -File $vf -Set | Out-Null }
    if ("$st" -match '"installed":true') { New-Item -ItemType File -Force $fd | Out-Null }
}
