# valo.os installer for an existing Windows 11 (no reinstall). In PowerShell:
#   irm https://raw.githubusercontent.com/SOVALONE/valo-os/main/install.ps1 | iex
# Installs Zebar + JetBrainsMono Nerd Font (winget), the signed valo.os release (panel, menu, dock, control center,
# wallpapers, sounds), autostart, and hides the Windows taskbar. Remove everything again with uninstall.ps1.
# Options through environment variables (iex can't pass parameters):
#   $env:VALO_CHANNEL = 'beta'   beta releases      $env:VALO_DRYRUN = '1'   only download + verify into $env:VALO_TARGET
& {
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$PUBLIC_KEY = '<RSAKeyValue><Modulus>5LKH9Sfzt9YqpaF4I3wMJChoOMfjRZYQRmCr4E4ioVCzuqq6phwMk78RfoUVhG0yCeo27SOsvYq1iTR3sk7LplLWTiGucwvXRf3Y3Lk9B0INo21HVA4jvpqrk5EuLgN0ZUItnhpfQEmoWWPisltx0+suXJB5Vc8p+tcq5k4sYBIuemEiEmWmm8NDXxMMpa/V2N5C6RlK/mB1NPK8YoSb1UzoetmzBOH5Tr9eimFLA8MUPmC7aGfebOJ3cmDwOHLDOqO5kLeWSR9y+rhpV5aWOGR8VfzBY2v6ai7JrjaW4hp1O9Awgi9dNkaf0v6tUp8coHpdui/Fslk891+nao7Pj/2ZhirngLo/VWQuqZWP7BiXDunNyD8MqM+tN4SuaULsHp6C9fk4o3ltHLZnOsq4Pzifyka1A3A2qpI7uVN6Uagk39rYs0+pGiWvM4BOzXlF8sHnT4+1cDBt24XN37X0JtEUlgxKSq2VXgYoB6/KNgm6Jaxge6JrgdtrwNFQ5qEp</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
$ref = 'main'
if (-not $env:VALO_BASE) { try { $ref = [Text.Encoding]::ASCII.GetString((Invoke-WebRequest -Uri 'https://api.github.com/repos/SOVALONE/valo-os/commits/main' -Headers @{ Accept = 'application/vnd.github.sha'; 'User-Agent' = 'valo-os-installer' } -UseBasicParsing -TimeoutSec 15).RawContentStream.ToArray()).Trim() } catch { } }
if ($ref -notmatch '^[0-9a-f]{40}$') { $ref = 'main' }
$base = if ($env:VALO_BASE) { $env:VALO_BASE.TrimEnd('/') } else { "https://raw.githubusercontent.com/SOVALONE/valo-os/$ref" }
$channel = if ($env:VALO_CHANNEL -eq 'beta') { 'beta' } else { 'stable' }
$dry = $env:VALO_DRYRUN -eq '1'
$pack = if ($env:VALO_TARGET) { Join-Path $env:VALO_TARGET 'quill' } else { "$env:USERPROFILE\.glzr\zebar\quill" }
$valo = if ($env:VALO_TARGET) { Join-Path $env:VALO_TARGET 'valo' } else { Join-Path $env:LOCALAPPDATA 'valo' }
$zebarExe = 'C:\Program Files\glzr.io\Zebar\zebar.exe'
function Say($m, $c = 'Magenta') { Write-Host "  valo.os  " -ForegroundColor $c -NoNewline; Write-Host $m }

Write-Host ''; Say 'встановлення valo.os' 'Magenta'; Write-Host ''
if ([Environment]::OSVersion.Version.Build -lt 22000) { Say 'Це не Windows 11 — valo.os розрахована на Windows 11, але спробуємо.' 'Yellow' }

# ---- 1. apps: Zebar + font
if (-not $dry) {
    if (-not (Get-Command winget -EA SilentlyContinue)) { throw 'Немає winget. Встановіть «App Installer» з Microsoft Store і запустіть ще раз.' }
    foreach ($app in @(@('glzr-io.zebar', 'Zebar (панель)'), @('DEVCOM.JetBrainsMonoNerdFont', 'шрифт JetBrainsMono Nerd Font'))) {
        $have = (winget list --id $app[0] -e --accept-source-agreements --disable-interactivity 2>$null) -join ' '
        if ($have -match [regex]::Escape($app[0])) { Say "$($app[1]) — уже є"; continue }
        Say "встановлюю $($app[1])… (Windows може попросити дозвіл)"
        winget install --id $app[0] -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    }
}

# ---- 2. signed release
Say "завантажую valo.os ($channel)…"
$wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$bytes = $wc.DownloadData("$base/$channel.json?t=$t")
$sig = [Convert]::FromBase64String($wc.DownloadString("$base/$channel.json.sig?t=$t").Trim())
$rsa = New-Object Security.Cryptography.RSACryptoServiceProvider; $rsa.PersistKeyInCsp = $false; $rsa.FromXmlString($PUBLIC_KEY)
if (-not $rsa.VerifyData($bytes, 'SHA256', $sig)) { throw 'Підпис випуску не збігається — встановлення зупинено.' }
$m = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
$stage = Join-Path $env:TEMP "valo-install-$($m.version)"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
$prefix = "$($m.base)/"; $n = 0
foreach ($f in $m.files) {
    $p = [string]$f.path
    if ($p -match '\.\.' -or -not $p.StartsWith($prefix)) { throw "Підозрілий шлях: $p" }
    $rel = $p.Substring($prefix.Length)
    if ($rel -notmatch '^(pack|wallpapers)/[A-Za-z0-9._/-]+$') { throw "Підозрілий шлях: $p" }
    $dst = Join-Path $stage ($rel -replace '/', '\'); New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    $wc.DownloadFile("$base/$p", $dst)
    if ((Get-FileHash $dst -Algorithm SHA256).Hash -ne ([string]$f.sha256).ToUpper()) { throw "Файл $rel пошкоджений" }
    $n++; if ($n % 15 -eq 0) { Say "  $n / $($m.files.Count)" 'DarkGray' }
}
New-Item -ItemType Directory -Force $pack, (Join-Path $valo 'wallpapers') | Out-Null
Copy-Item "$stage\pack\*" $pack -Recurse -Force
Copy-Item "$stage\wallpapers\*" (Join-Path $valo 'wallpapers') -Recurse -Force
[IO.File]::WriteAllText((Join-Path $pack 'version.json'), ([ordered]@{ version = $m.version; date = $m.date; notes = @($m.notes); channel = $channel; installedAt = (Get-Date -f s) } | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
Remove-Item $stage -Recurse -Force
Say "valo.os $($m.version): $n файлів перевірено й встановлено" 'Green'
if ($dry) { Say "пробний запуск — далі нічого не змінюю ($pack)" 'Yellow'; return }

# ---- 3. Zebar settings: valo widgets start with Zebar (the old settings are kept as a backup)
$settings = "$env:USERPROFILE\.glzr\zebar\settings.json"
if ((Test-Path $settings) -and -not (Test-Path "$settings.valo-backup")) { Copy-Item $settings "$settings.valo-backup" }
$cfg = if (Test-Path $settings) { Get-Content $settings -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
$list = @(@($cfg.startupConfigs) | Where-Object { $_ -and $_.pack -ne 'quill' })
$list += [pscustomobject]@{ pack = 'quill'; widget = 'bar'; preset = 'host' }
$list += [pscustomobject]@{ pack = 'quill'; widget = 'dock'; preset = 'host' }
foreach ($w in 'menu', 'control', 'welcome', 'emoji', 'saver') { $list += [pscustomobject]@{ pack = 'quill'; widget = $w; preset = 'default' } }
$cfg | Add-Member -NotePropertyName startupConfigs -NotePropertyValue $list -Force
New-Item -ItemType Directory -Force (Split-Path $settings) | Out-Null
[IO.File]::WriteAllText($settings, ($cfg | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))

# ---- 4. autostart + taskbar hidden right at login
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Set-ItemProperty $run -Name 'valo-bar' -Value "`"$zebarExe`""
Set-ItemProperty $run -Name 'valo-taskbar' -Value ('conhost.exe --headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + "$pack\valo-shell.ps1" + '" -HideTaskbar')

# ---- 5. start
Get-Process zebar -EA SilentlyContinue | Stop-Process -Force
Start-Sleep 1
if (Test-Path $zebarExe) { Start-Process $zebarExe }
Write-Host ''
Say "готово! Зараз з'явиться панель valo.os і майстер першого запуску." 'Green'
Say 'Видалити: irm https://raw.githubusercontent.com/SOVALONE/valo-os/main/uninstall.ps1 | iex' 'DarkGray'
Write-Host ''
}
