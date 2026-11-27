# valo.os calendar: downloads an .ics link (Google Calendar "secret address in iCal format" etc.) and prints it.
# Widgets can't fetch it themselves (no CORS on calendar servers). Only https links are accepted.
param([string]$Url)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($Url -notmatch '^(https|webcal)://') { [Console]::Out.Write('ERROR: bad url'); return }
$Url = $Url -replace '^webcal://', 'https://'
try {
    $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20
    [Console]::Out.Write([Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()))
} catch { [Console]::Out.Write('ERROR: ' + $_.Exception.Message) }