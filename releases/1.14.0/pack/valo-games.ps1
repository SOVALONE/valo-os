# valo.os "Ігри valo" (the valo Store): games from the catalog SOVALONE/valo-games (own games, friends' games, games that may be shared;
# paid games only as a link to their official site or store).
#   -List            -> {"games":[...catalog...],"installed":["id",...]}   (catalog cached for offline use)
#   -Install <id>    -> {"ok":true|false,"error":"..."}   zip: unpack to %LOCALAPPDATA%\valo\games\<id>; exe: copy there; installer: run it;
#                       link: open the site. Every file is checked against the catalog's SHA-256 before it is used.
#   -Play <id>       start an installed game        -Remove <id>   delete it (an installer game: Windows "Apps" settings)
#   -Torrent <id>    open the game's .torrent in the torrent program
#   -Site <id>       open the game's site
param([switch]$List, [string]$Install, [string]$Play, [string]$Remove, [string]$Torrent, [string]$Site)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Out-Json($o) { [Console]::Out.Write((ConvertTo-Json -InputObject $o -Compress -Depth 5)) }
$raw = 'https://raw.githubusercontent.com/SOVALONE/valo-games/main'
$home2 = Join-Path $env:LOCALAPPDATA 'valo\games'
$cache = Join-Path $home2 'catalog.json'
$state = Join-Path $home2 'installed.json'
$menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Ігри valo'
$log = Join-Path $env:TEMP 'valo-games.log'
New-Item -ItemType Directory -Force $home2 | Out-Null

function Catalog {
    try {
        # the API gives the latest version at once (raw.githubusercontent.com caches for ~5 min); raw is the fallback
        try { $t = (Invoke-WebRequest 'https://api.github.com/repos/SOVALONE/valo-games/contents/games.json' -Headers @{ Accept = 'application/vnd.github.raw'; 'User-Agent' = 'valo-os' } -UseBasicParsing -TimeoutSec 15).Content }
        catch { $t = (Invoke-WebRequest "$raw/games.json" -UseBasicParsing -TimeoutSec 15).Content }
        if ($t -is [byte[]]) { $t = [Text.Encoding]::UTF8.GetString($t) }
        $c = $t | ConvertFrom-Json
        [IO.File]::WriteAllText($cache, $t, [Text.UTF8Encoding]::new($false))
    } catch { if (Test-Path $cache) { $c = Get-Content $cache -Raw -Encoding UTF8 | ConvertFrom-Json } else { return @() } }
    @($c.games | Where-Object { $_.id -match '^[a-z0-9-]+$' })
}
function Installed { if (Test-Path $state) { $s = Get-Content $state -Raw -Encoding UTF8 | ConvertFrom-Json; $h = @{}; foreach ($p in $s.PSObject.Properties) { $h[$p.Name] = $p.Value }; $h } else { @{} } }
function Save-Installed($h) { [IO.File]::WriteAllText($state, (ConvertTo-Json -InputObject $h -Depth 4), [Text.UTF8Encoding]::new($false)) }
function Game($id) { $g = Catalog | Where-Object { $_.id -eq $id } | Select-Object -First 1; if (-not $g) { throw 'немає такої гри' }; $g }
# links only to the web; downloads only from this repository on GitHub
function Web($u) { if ($u -notmatch '^https://') { throw 'не https-посилання' }; Start-Process $u }
function Fetch($u, $sha) {
    if ($u -notmatch '^https://(github\.com/SOVALONE/valo-games/|raw\.githubusercontent\.com/SOVALONE/valo-games/)') { throw 'файл не з репозиторію valo-games' }
    $f = Join-Path $env:TEMP ('valo-game-' + [IO.Path]::GetRandomFileName() + [IO.Path]::GetExtension(([uri]$u).AbsolutePath))
    & curl.exe -sSL --fail --retry 6 --retry-all-errors --retry-delay 5 -o $f $u
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $f)) { throw "не вдалося завантажити ($LASTEXITCODE)" }
    if (-not $sha -or (Get-FileHash $f -Algorithm SHA256).Hash.ToLower() -ne $sha.ToLower()) { Remove-Item $f -Force; throw 'файл не збігається з каталогом (SHA-256)' }
    $f
}
function Shortcut($g, $target, $dir) {
    New-Item -ItemType Directory -Force $menu | Out-Null
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $menu (($g.name -replace '[\\/:*?"<>|]', '') + '.lnk')))
    $s.TargetPath = $target; $s.WorkingDirectory = $dir; $s.IconLocation = "$target,0"; $s.Description = $g.desc; $s.Save()
}

try {
    if ($List) {
        $h = Installed
        Out-Json ([ordered]@{ games = @(Catalog); installed = @($h.Keys) })
    }
    elseif ($Install) {
        $g = Game $Install
        Add-Content $log ((Get-Date -f s) + " install $($g.id) $($g.kind) $($g.version)")
        if ($g.kind -eq 'link') { Web $g.site; Out-Json @{ ok = $true; opened = $true }; return }
        $f = Fetch $g.url $g.sha256
        $dir = Join-Path $home2 $g.id
        $h = Installed
        if ($g.kind -eq 'installer') {
            $p = Start-Process $f -PassThru -Wait
            Remove-Item $f -Force -EA SilentlyContinue
            $h[$g.id] = [ordered]@{ version = $g.version; kind = 'installer' }; Save-Installed $h
            Out-Json @{ ok = $true; code = $p.ExitCode }; return
        }
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        New-Item -ItemType Directory -Force $dir | Out-Null
        if ($g.kind -eq 'zip') {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [IO.Compression.ZipFile]::ExtractToDirectory($f, $dir)      # .NET refuses entries that point outside $dir
            $exe = Join-Path $dir $g.exe
            if (-not (Test-Path $exe)) { $exe = (Get-ChildItem $dir -Recurse -Filter (Split-Path $g.exe -Leaf) | Select-Object -First 1).FullName }
        } else {
            $exe = Join-Path $dir ((Split-Path ([uri]$g.url).AbsolutePath -Leaf) -replace '[^A-Za-z0-9._-]', '_')
            Move-Item $f $exe
        }
        Remove-Item $f -Force -EA SilentlyContinue
        if (-not $exe -or -not (Test-Path $exe)) { throw 'у грі немає файлу для запуску' }
        Shortcut $g $exe (Split-Path $exe)
        $h[$g.id] = [ordered]@{ version = $g.version; kind = $g.kind; exe = $exe }; Save-Installed $h
        Out-Json @{ ok = $true }
    }
    elseif ($Play) {
        $i = (Installed)[$Play]; $exe = if ($i) { $i.exe }
        if (-not $exe -or -not (Test-Path $exe)) { throw 'гра не встановлена' }
        Start-Process $exe -WorkingDirectory (Split-Path $exe); Out-Json @{ ok = $true }
    }
    elseif ($Remove) {
        $h = Installed; $i = $h[$Remove]
        if (-not $i) { throw 'гра не встановлена' }
        if ($i.kind -eq 'installer') { Start-Process 'ms-settings:appsfeatures' }
        else {
            $dir = Join-Path $home2 $Remove
            if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
            Get-ChildItem $menu -Filter *.lnk -EA SilentlyContinue | Where-Object { (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).TargetPath -like "$dir\*" } | Remove-Item -Force
            if (-not (Get-ChildItem $menu -EA SilentlyContinue)) { Remove-Item $menu -Force -EA SilentlyContinue }
        }
        $h.Remove($Remove); Save-Installed $h; Out-Json @{ ok = $true }
    }
    elseif ($Torrent) {
        $g = Game $Torrent
        if (-not $g.torrent -or $g.torrent -notmatch '^torrents/[a-z0-9-]+\.torrent$') { throw 'для цієї гри немає торента' }
        $f = Join-Path $env:TEMP "$($g.id).torrent"
        & curl.exe -sSL --fail --retry 3 --retry-all-errors -o $f "$raw/$($g.torrent)"
        if ($LASTEXITCODE -ne 0) { throw 'не вдалося завантажити .torrent' }
        if (-not (Test-Path 'Registry::HKEY_CLASSES_ROOT\.torrent')) { Out-Json @{ ok = $false; error = 'notorrent' }; return }
        Start-Process $f; Out-Json @{ ok = $true }
    }
    elseif ($Site) { $g = Game $Site; Web $g.site; Out-Json @{ ok = $true } }
}
catch { Add-Content $log ((Get-Date -f s) + " error $_"); Out-Json @{ ok = $false; error = "$_" } }
