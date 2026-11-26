# valo.os: run by valo-update.ps1 after a new version is installed (before Zebar restarts).
# Makes sure every valo widget starts with Zebar (new widgets come with updates).
$ErrorActionPreference = 'SilentlyContinue'
$settings = "$env:USERPROFILE\.glzr\zebar\settings.json"
if (-not (Test-Path $settings)) { return }
$cfg = Get-Content $settings -Raw | ConvertFrom-Json
$list = [Collections.Generic.List[object]]::new(); foreach ($c in @($cfg.startupConfigs)) { if ($c) { $list.Add($c) } }
$bar = $list | Where-Object { $_.pack -eq 'quill' -and $_.widget -eq 'bar' } | Select-Object -First 1
$host_ = $bar -and $bar.preset -like 'host*'
$want = [ordered]@{ menu = 'default'; dock = $(if ($host_) { 'host' } else { 'default' }); control = 'default'; welcome = 'default'; emoji = 'default'; saver = 'default' }
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
