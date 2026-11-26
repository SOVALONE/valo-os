# valo.os store (winget):
#   -List <id,id,...>  -> {"installed":["id",...]}
#   -Install <id>      -> {"ok":true|false,"code":N}   (some installers ask for administrator rights — Windows shows its own prompt)
param([string]$List, [string]$Install)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }
$log = Join-Path $env:TEMP 'valo-store.log'

if ($List) {
    $ids = $List -split ',' | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' }
    $out = (winget list --accept-source-agreements --disable-interactivity 2>$null) -join "`n"
    $have = @($ids | Where-Object { $out -match [regex]::Escape($_) })
    Out-Json @{ installed = $have }
}
elseif ($Install) {
    if ($Install -notmatch '^[A-Za-z0-9._-]+$') { Out-Json @{ ok = $false; error = 'bad id' }; return }
    Add-Content $log ((Get-Date -f s) + " install $Install")
    $p = Start-Process winget -ArgumentList 'install', '--id', $Install, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity' -WindowStyle Hidden -Wait -PassThru
    Add-Content $log ((Get-Date -f s) + " $Install exit $($p.ExitCode)")
    Out-Json @{ ok = ($p.ExitCode -eq 0); code = $p.ExitCode }
}
