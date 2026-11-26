# valo.os updater 2: signed releases, stable / beta channels, rollback.
#   -Check     -> {"current":"1.4.0","latest":"1.5.0","available":true,"notes":[..],"channel":"stable"}
#   -Apply     -> installs the newest release of the channel (signature + SHA-256 of every file checked), backs up, restarts Zebar
#   -Rollback  -> puts back the newest backup (the version before the last update), restarts Zebar
#   -Current   -> installed version.json (no network)
#   -Channel stable|beta   (beta also gets stable releases when they are newer)
# Repository layout: <channel>.json (+ .sig) -> { version, date, notes, base: "releases/<v>", files: [{ path, sha256 }] }
#   releases/<v>/pack/*        -> %USERPROFILE%\.glzr\zebar\quill\       (this folder)
#   releases/<v>/wallpapers/*  -> %LOCALAPPDATA%\valo\wallpapers\
param([switch]$Check, [switch]$Apply, [switch]$Rollback, [switch]$Current, [string]$Channel = 'stable',
      [string]$Repo = 'SOVALONE/valo-os', [string]$Branch = 'main', [string]$BaseUrl, [switch]$NoRestart)   # BaseUrl / NoRestart: testing
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# public half of the release key (tools\valo-signing.ps1); only releases signed with its private half are installed
$PUBLIC_KEY = '<RSAKeyValue><Modulus>5LKH9Sfzt9YqpaF4I3wMJChoOMfjRZYQRmCr4E4ioVCzuqq6phwMk78RfoUVhG0yCeo27SOsvYq1iTR3sk7LplLWTiGucwvXRf3Y3Lk9B0INo21HVA4jvpqrk5EuLgN0ZUItnhpfQEmoWWPisltx0+suXJB5Vc8p+tcq5k4sYBIuemEiEmWmm8NDXxMMpa/V2N5C6RlK/mB1NPK8YoSb1UzoetmzBOH5Tr9eimFLA8MUPmC7aGfebOJ3cmDwOHLDOqO5kLeWSR9y+rhpV5aWOGR8VfzBY2v6ai7JrjaW4hp1O9Awgi9dNkaf0v6tUp8coHpdui/Fslk891+nao7Pj/2ZhirngLo/VWQuqZWP7BiXDunNyD8MqM+tN4SuaULsHp6C9fk4o3ltHLZnOsq4Pzifyka1A3A2qpI7uVN6Uagk39rYs0+pGiWvM4BOzXlF8sHnT4+1cDBt24XN37X0JtEUlgxKSq2VXgYoB6/KNgm6Jaxge6JrgdtrwNFQ5qEp</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'

$pack = Split-Path -Parent $MyInvocation.MyCommand.Path
$valo = Join-Path $env:LOCALAPPDATA 'valo'
$log = Join-Path $env:TEMP 'valo-update.log'
function Log($m) { Add-Content -LiteralPath $log -Value ((Get-Date -f 'yyyy-MM-dd HH:mm:ss') + ' ' + $m) }
function Out-Json($o) { [Console]::Out.Write(($o | ConvertTo-Json -Compress -Depth 4)) }
# "1.4.0" > "1.4.0-beta.2" > "1.4.0-beta.1" > "1.3.1"
function VerKey([string]$v) {
    $m = [regex]::Match("$v", '^(\d+)\.(\d+)\.(\d+)(?:-beta\.?(\d+))?')
    if (-not $m.Success) { return 0 }
    $b = if ($m.Groups[4].Success) { [int]$m.Groups[4].Value } else { 9999 }
    [long]$m.Groups[1].Value * 1e12 + [long]$m.Groups[2].Value * 1e8 + [long]$m.Groups[3].Value * 1e4 + $b
}
function Restart-Zebar {
    if ($NoRestart) { return }
    $zebar = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
    $cmd = "Start-Sleep -Milliseconds 800; Stop-Process -Name zebar -Force; Start-Sleep -Milliseconds 1800; Start-Process '$zebar'"
    Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile', '-Command', $cmd
}
$installedFile = Join-Path $pack 'version.json'
$installed = $null; try { $installed = Get-Content $installedFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
$current = if ($installed) { "$($installed.version)" } else { '0.0.0' }

if ($Current) { Out-Json @{ current = $current; notes = @($installed.notes); date = $installed.date; channel = $Channel }; return }

# ---- rollback to the newest backup
if ($Rollback) {
    $bk = Get-ChildItem (Join-Path $valo 'backup') -Directory -EA SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $bk) { Out-Json @{ ok = $false; error = 'Немає резервних копій для відкату' }; return }
    $ver = '?'; try { $ver = (Get-Content (Join-Path $bk.FullName 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch { }
    Copy-Item (Join-Path $bk.FullName '*') $pack -Recurse -Force
    Log "rollback $current -> $ver from $($bk.FullName)"
    Remove-Item $bk.FullName -Recurse -Force        # the next rollback goes one step further back
    Out-Json @{ ok = $true; version = $ver }
    Restart-Zebar
    return
}

# ---- signed channel manifests
$base = if ($BaseUrl) { $BaseUrl.TrimEnd('/') } else { "https://raw.githubusercontent.com/$Repo/$Branch" }
$bust = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
function Get-Bytes($url) { (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20).RawContentStream.ToArray() }
function Get-Manifest($name) {
    try {
        $bytes = Get-Bytes "$base/$name.json?t=$bust"
        $sig = [Convert]::FromBase64String([Text.Encoding]::ASCII.GetString((Get-Bytes "$base/$name.json.sig?t=$bust")).Trim())
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider; $rsa.PersistKeyInCsp = $false; $rsa.FromXmlString($PUBLIC_KEY)
        if (-not $rsa.VerifyData($bytes, 'SHA256', $sig)) { Log "$name.json: BAD SIGNATURE"; return @{ bad = $true } }
        return ([Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json)
    } catch { Log "$name.json: $_"; return $null }
}
$stable = Get-Manifest 'stable'
$beta = if ($Channel -eq 'beta') { Get-Manifest 'beta' } else { $null }
if (($stable -is [hashtable] -and $stable.bad) -or ($beta -is [hashtable] -and $beta.bad)) {
    Out-Json @{ current = $current; error = 'Підпис оновлення не збігається — оновлення відхилено.' }; return
}
$remote = $stable
if ($beta -and (-not $stable -or (VerKey $beta.version) -gt (VerKey $stable.version))) { $remote = $beta }
if (-not $remote) { Out-Json @{ current = $current; error = 'Не вдалося перевірити оновлення (немає інтернету або репозиторію).' }; return }
$available = (VerKey $remote.version) -gt (VerKey $current)

if (-not $Apply) {
    Out-Json @{ current = $current; latest = $remote.version; available = $available; notes = @($remote.notes); date = $remote.date; channel = $Channel; beta = ("$($remote.version)" -like '*beta*') }
    return
}
if (-not $available) { Out-Json @{ ok = $true; current = $current; msg = 'Уже остання версія.' }; return }

# ---- download + verify everything first, install only if all files are good
$stage = Join-Path $valo "update-$($remote.version)"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
Log "update $current -> $($remote.version) ($Channel)"
$prefix = "$($remote.base)/"
foreach ($f in $remote.files) {
    $p = [string]$f.path
    if ($p -match '\.\.' -or -not $p.StartsWith($prefix)) { Out-Json @{ ok = $false; error = "Підозрілий шлях у маніфесті: $p" }; return }
    $rel = $p.Substring($prefix.Length)
    if ($rel -notmatch '^(pack|wallpapers)/[A-Za-z0-9._/-]+$') { Out-Json @{ ok = $false; error = "Підозрілий шлях у маніфесті: $p" }; return }
    $dst = Join-Path $stage ($rel -replace '/', '\')
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    try { Invoke-WebRequest -Uri "$base/$p" -OutFile $dst -UseBasicParsing -TimeoutSec 60 }
    catch { Log "download failed $p : $_"; Out-Json @{ ok = $false; error = "Не вдалося завантажити $rel" }; return }
    if ((Get-FileHash $dst -Algorithm SHA256).Hash -ne ([string]$f.sha256).ToUpper()) { Log "hash mismatch $p"; Out-Json @{ ok = $false; error = "Файл $rel пошкоджений (не збігається SHA-256)" }; return }
}

$bk = Join-Path $valo "backup\$current-$(Get-Date -f yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Force $bk | Out-Null
Copy-Item (Join-Path $pack '*') $bk -Recurse -Force
# keep the 5 newest backups
Get-ChildItem (Join-Path $valo 'backup') -Directory | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 | Remove-Item -Recurse -Force -EA SilentlyContinue
if (Test-Path "$stage\pack") { Copy-Item "$stage\pack\*" $pack -Recurse -Force }
if (Test-Path "$stage\wallpapers") {
    $wp = Join-Path $valo 'wallpapers'; New-Item -ItemType Directory -Force $wp | Out-Null
    Copy-Item "$stage\wallpapers\*" $wp -Recurse -Force
}
$info = [ordered]@{ version = $remote.version; date = $remote.date; notes = @($remote.notes); installedAt = (Get-Date -f s); channel = $Channel }
[IO.File]::WriteAllText($installedFile, ($info | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
Remove-Item $stage -Recurse -Force
Log "installed $($remote.version), backup $bk"
$post = Join-Path $pack 'valo-postupdate.ps1'
if (Test-Path $post) { try { & $post } catch { Log "postupdate failed: $_" } }
Out-Json @{ ok = $true; version = $remote.version; backup = $bk }
Restart-Zebar
