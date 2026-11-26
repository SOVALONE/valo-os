# valo.os settings sync through a secret GitHub Gist (needs GitHub CLI "gh" signed in on this PC).
#   -Push <base64 JSON>  -> creates / updates the gist "valo.os settings", prints {"ok":true,"id":..}
#   -Pull                -> prints the stored JSON (or {"error":..})
param([string]$Push, [switch]$Pull)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress)) }
$gh = (Get-Command gh -EA SilentlyContinue).Source
if (-not $gh) { foreach ($c in "$env:ProgramFiles\GitHub CLI\gh.exe", "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe") { if (Test-Path $c) { $gh = $c } } }
if (-not $gh) { Out-Json @{ error = 'Потрібен GitHub CLI (gh) — встановіть його в «Магазині» і увійдіть: gh auth login' }; return }
& $gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Out-Json @{ error = 'GitHub CLI не авторизований: виконайте gh auth login' }; return }

$idFile = Join-Path $env:LOCALAPPDATA 'valo\gist-id.txt'
$id = if (Test-Path $idFile) { (Get-Content $idFile -Raw).Trim() } else { '' }
if (-not $id) {   # find an existing one (e.g. made on another PC)
    $list = & $gh api gists --paginate 2>$null | ConvertFrom-Json
    $g = @($list) | Where-Object { $_.description -eq 'valo.os settings' } | Select-Object -First 1
    if ($g) { $id = $g.id; New-Item -ItemType Directory -Force (Split-Path $idFile) | Out-Null; Set-Content $idFile $id }
}

if ($Push) {
    $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Push))
    $body = @{ description = 'valo.os settings'; public = $false; files = @{ 'valo-settings.json' = @{ content = $json } } } | ConvertTo-Json -Depth 5
    $tmp = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($tmp, $body, [Text.UTF8Encoding]::new($false))
    $res = if ($id) { & $gh api -X PATCH "gists/$id" --input $tmp 2>$null } else { & $gh api -X POST gists --input $tmp 2>$null }
    Remove-Item $tmp
    $o = $res | ConvertFrom-Json
    if ($o.id) { New-Item -ItemType Directory -Force (Split-Path $idFile) | Out-Null; Set-Content $idFile $o.id; Out-Json @{ ok = $true; id = $o.id } }
    else { Out-Json @{ error = 'Не вдалося зберегти в GitHub' } }
}
elseif ($Pull) {
    if (-not $id) { Out-Json @{ error = 'Ще немає збережених налаштувань у GitHub' }; return }
    $o = & $gh api "gists/$id" 2>$null | ConvertFrom-Json
    $c = $o.files.'valo-settings.json'.content
    if ($c) { [Console]::Out.Write($c) } else { Out-Json @{ error = 'Не вдалося отримати налаштування' } }
}
