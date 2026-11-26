# valo.os power mode (Windows 11 "Power mode": best efficiency / balanced / best performance) through powrprof.dll.
#   -Get            -> prints the current overlay GUID
#   -Set <guid>     -> sets it (00000000-... = balanced, 961cc777-... = best efficiency, ded574b5-... = best performance)
param([switch]$Get, [string]$Set)
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class ValoPower {
    [DllImport("powrprof.dll")] static extern uint PowerGetEffectiveOverlayScheme(out Guid g);
    [DllImport("powrprof.dll")] static extern uint PowerSetActiveOverlayScheme(Guid g);
    public static string Get() { Guid g; return PowerGetEffectiveOverlayScheme(out g) == 0 ? g.ToString() : ""; }
    public static bool Set(string s) { return PowerSetActiveOverlayScheme(new Guid(s)) == 0; }
}
'@
if ($Get) { [Console]::Out.Write([ValoPower]::Get()) }
elseif ($Set) { if ($Set -match '^[0-9a-fA-F-]{36}$') { [Console]::Out.Write([ValoPower]::Set($Set)) } }
