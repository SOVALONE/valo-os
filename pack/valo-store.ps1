# valo.os store (winget):
#   -List <id,id,...>  -> {"installed":["id",...]}
#   -Install <id>      -> {"ok":true|false,"code":N}   (some installers ask for administrator rights — Windows shows its own prompt)
#   -Remove <id>       -> {"ok":true|false}  (only valo's own components)
# valo.Link is valo's own component (the phone companion): its files come with valo.os, "install" sets it up.
param([string]$List, [string]$Install, [string]$Remove)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }
$log = Join-Path $env:TEMP 'valo-store.log'

if ($List) {
    $ids = $List -split ',' | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' }
    $out = (winget list --accept-source-agreements --disable-interactivity 2>$null) -join "`n"
    $have = @($ids | Where-Object { $_ -ne 'valo.Link' -and $out -match [regex]::Escape($_) })
    if ($ids -contains 'valo.Link' -and (Test-Path (Join-Path $env:LOCALAPPDATA 'valo\link\installed'))) { $have += 'valo.Link' }
    Out-Json @{ installed = $have }
}
elseif ($Install -eq 'valo.Link' -or $Remove -eq 'valo.Link') {
    $b = Join-Path $PSScriptRoot 'valo-link-build.ps1'
    if ($Remove) { & $b -Remove } else { & $b }
    Out-Json @{ ok = ((Test-Path (Join-Path $env:LOCALAPPDATA 'valo\link\installed')) -eq (-not $Remove)) }
}
elseif ($Install) {
    if ($Install -notmatch '^[A-Za-z0-9._-]+$') { Out-Json @{ ok = $false; error = 'bad id' }; return }
    Add-Content $log ((Get-Date -f s) + " install $Install")
    $p = Start-Process winget -ArgumentList 'install', '--id', $Install, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity' -WindowStyle Hidden -Wait -PassThru
    Add-Content $log ((Get-Date -f s) + " $Install exit $($p.ExitCode)")
    Out-Json @{ ok = ($p.ExitCode -eq 0); code = $p.ExitCode }
}
