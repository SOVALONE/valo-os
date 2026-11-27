# valo.os menu search: files and folders from the Windows Search index (user profile), newest first.
#   -Q <text>  -> [{"n":"name","p":"full path","d":true|false}]
param([string]$Q = '', [int]$Top = 8)
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$q = $Q.Trim()
if ($q.Length -lt 2) { [Console]::Out.Write('[]'); return }
# escape for the SQL LIKE literal: quotes doubled, wildcards bracketed
$like = $q.Replace("'", "''").Replace('[', '[[]').Replace('%', '[%]').Replace('_', '[_]')
$scope = 'file:' + $env:USERPROFILE.Replace("'", "''")
$sql = "SELECT TOP $Top System.ItemUrl, System.ItemNameDisplay, System.ItemType FROM SYSTEMINDEX " +
       "WHERE SCOPE='$scope' AND System.ItemNameDisplay LIKE '%$like%' AND System.FileAttributes <> 2 " +
       "ORDER BY System.DateModified DESC"
$out = [Collections.Generic.List[object]]::new()
try {
    $con = New-Object -ComObject ADODB.Connection
    $con.Open("Provider=Search.CollatorDSO;Extended Properties='Application=Windows';")
    $rs = $con.Execute($sql)
    while (-not $rs.EOF) {
        $p = ([string]$rs.Fields.Item('System.ItemUrl').Value -replace '^file:', '').Replace('/', '\')   # real path (ItemPathDisplay is localized)
        if ($p -and $p -notmatch '\\AppData\\') {
            $out.Add([pscustomobject]@{ n = [string]$rs.Fields.Item('System.ItemNameDisplay').Value; p = $p; d = ([string]$rs.Fields.Item('System.ItemType').Value -eq 'Directory') })
        }
        $rs.MoveNext()
    }
    $rs.Close(); $con.Close()
} catch { }
[Console]::Out.Write((ConvertTo-Json -InputObject $out.ToArray() -Compress))
