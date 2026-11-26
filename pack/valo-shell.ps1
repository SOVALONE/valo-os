# valo.os shell helper (spawned by the dock widget, talks over stdin/stdout as JSON lines)
#  out: {"type":"windows","list":[...]}  {"type":"icon","path":..,"png":..}  {"type":"win"}
#  in : activate <hwnd> | min <hwnd> | close <hwnd> | activatetitle <title> | taskbar hide|show | quit
#       dock <overlap 0|1> <fitWidthPx>  (overlap: drop the app bar and shrink the dock window to the dock itself)
#       preview <x> <top> <bg> <text> <accent> <muted> <hwnd,hwnd..> | preview off | preview hide  (hover thumbnails)
param([switch]$RestoreTaskbar, [switch]$HideTaskbar)   # -HideTaskbar: one-shot at login, before Zebar is up
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)

Add-Type -ReferencedAssemblies System.Drawing, System.Windows.Forms -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using WF = System.Windows.Forms;
using SD = System.Drawing;

public static class ValoShell {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    delegate IntPtr HookProc(int code, IntPtr w, IntPtr l);

    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string c, string t);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string c, string t);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int val, int size);
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool QueryFullProcessImageName(IntPtr p, int flags, StringBuilder s, ref int n);
    [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc fn, IntPtr mod, uint thread);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int code, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint a, uint b);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string n);
    [DllImport("shell32.dll")] static extern IntPtr SHAppBarMessage(uint msg, ref APPBARDATA d);
    [DllImport("shell32.dll")] static extern int SHGetPropertyStoreForWindow(IntPtr h, ref Guid iid, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr h; public uint msg; public IntPtr w; public IntPtr l; public uint time; public int x; public int y; }
    [StructLayout(LayoutKind.Sequential)] struct KBD { public uint vk; public uint scan; public uint flags; public uint time; public UIntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct APPBARDATA { public int cbSize; public IntPtr hWnd; public uint cb; public uint edge; public RECT rc; public IntPtr lParam; }
    [StructLayout(LayoutKind.Sequential, Pack = 4)] public struct PROPERTYKEY { public Guid fmtid; public uint pid; }
    [StructLayout(LayoutKind.Explicit)] public struct PROPVARIANT { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p; [FieldOffset(16)] public IntPtr p2; }
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore {
        int GetCount(out uint c); int GetAt(uint i, out PROPERTYKEY k);
        int GetValue(ref PROPERTYKEY k, out PROPVARIANT v); int SetValue(ref PROPERTYKEY k, ref PROPVARIANT v); int Commit();
    }

    public class Win { public long hwnd; public string title; public uint pid; public string exe; public string aumid; public string desc; public bool min; public bool fg; }

    static string Aumid(IntPtr h) {
        try {
            Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
            IPropertyStore st;
            if (SHGetPropertyStoreForWindow(h, ref iid, out st) != 0 || st == null) return null;
            PROPERTYKEY k = new PROPERTYKEY(); k.fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"); k.pid = 5;
            PROPVARIANT v;
            string r = null;
            if (st.GetValue(ref k, out v) == 0 && v.vt == 31 && v.p != IntPtr.Zero) r = Marshal.PtrToStringUni(v.p);
            Marshal.ReleaseComObject(st);
            return r;
        } catch { return null; }
    }

    static Dictionary<uint, string> exeCache = new Dictionary<uint, string>();
    static string ExePath(uint pid) {
        string s;
        if (exeCache.TryGetValue(pid, out s)) return s;
        IntPtr p = OpenProcess(0x1000, false, pid);
        s = "";
        if (p != IntPtr.Zero) {
            StringBuilder sb = new StringBuilder(1024); int n = sb.Capacity;
            if (QueryFullProcessImageName(p, 0, sb, ref n)) s = sb.ToString();
            CloseHandle(p);
        }
        exeCache[pid] = s;
        return s;
    }
    static Dictionary<string, string> descCache = new Dictionary<string, string>();
    static string Desc(string exe) {
        string d;
        if (descCache.TryGetValue(exe, out d)) return d;
        d = "";
        try { if (exe.Length > 0) d = FileVersionInfo.GetVersionInfo(exe).FileDescription ?? ""; } catch { }
        if (d.Length == 0 && exe.Length > 0) d = System.IO.Path.GetFileNameWithoutExtension(exe);
        descCache[exe] = d;
        return d;
    }

    static readonly string[] skipClass = { "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Progman", "WorkerW", "Tauri Window", "Windows.UI.Core.CoreWindow" };

    public static List<Win> Windows() {
        List<Win> list = new List<Win>();
        IntPtr fg = GetForegroundWindow();
        EnumWindows(delegate (IntPtr h, IntPtr l) {
            if (!IsWindowVisible(h)) return true;
            if (GetWindow(h, 4) != IntPtr.Zero) return true;              // owned (dialogs, popups)
            int ex = GetWindowLong(h, -20);
            if ((ex & 0x80) != 0 && (ex & 0x40000) == 0) return true;      // tool window, not app window
            int cloaked; if (DwmGetWindowAttribute(h, 14, out cloaked, 4) == 0 && cloaked != 0) return true;
            StringBuilder t = new StringBuilder(512); GetWindowText(h, t, 512);
            if (t.Length == 0) return true;
            StringBuilder c = new StringBuilder(256); GetClassName(h, c, 256);
            if (Array.IndexOf(skipClass, c.ToString()) >= 0) return true;
            uint pid; GetWindowThreadProcessId(h, out pid);
            Win w = new Win();
            w.hwnd = h.ToInt64(); w.title = t.ToString(); w.pid = pid; w.exe = ExePath(pid);
            w.aumid = Aumid(h); w.desc = Desc(w.exe); w.min = IsIconic(h); w.fg = h == fg;
            list.Add(w);
            return true;
        }, IntPtr.Zero);
        return list;
    }

    // Alt tap unlocks SetForegroundWindow for a background process
    public static void Activate(long hwnd) {
        IntPtr h = new IntPtr(hwnd);
        if (IsIconic(h)) ShowWindow(h, 9);
        keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
        SetForegroundWindow(h);
    }
    public static void ActivateTitle(string title) {
        IntPtr h = FindWindow(null, title);
        if (h != IntPtr.Zero) Activate(h.ToInt64());
    }
    public static void Minimize(long hwnd) { ShowWindow(new IntPtr(hwnd), 6); }
    public static void Close(long hwnd) { PostMessage(new IntPtr(hwnd), 0x10, IntPtr.Zero, IntPtr.Zero); }

    // ---- Windows taskbar
    static List<IntPtr> Bars() {
        List<IntPtr> r = new List<IntPtr>();
        IntPtr p = FindWindow("Shell_TrayWnd", null); if (p != IntPtr.Zero) r.Add(p);
        IntPtr s = IntPtr.Zero;
        while ((s = FindWindowEx(IntPtr.Zero, s, "Shell_SecondaryTrayWnd", null)) != IntPtr.Zero) r.Add(s);
        return r;
    }
    static void AutoHide(bool on) {
        APPBARDATA d = new APPBARDATA(); d.cbSize = Marshal.SizeOf(typeof(APPBARDATA));
        d.hWnd = FindWindow("Shell_TrayWnd", null);
        d.lParam = new IntPtr(on ? 1 : 2);   // ABS_AUTOHIDE / ABS_ALWAYSONTOP
        SHAppBarMessage(10, ref d);          // ABM_SETSTATE
    }
    public static bool EnsureAutoHide() {
        APPBARDATA d = new APPBARDATA(); d.cbSize = Marshal.SizeOf(typeof(APPBARDATA)); d.hWnd = FindWindow("Shell_TrayWnd", null);
        if ((SHAppBarMessage(4, ref d).ToInt32() & 1) != 0) return false;
        AutoHide(true); return true;
    }
    public static void HideTaskbar() { AutoHide(true); foreach (IntPtr h in Bars()) ShowWindow(h, 0); }
    public static void ShowTaskbar() { foreach (IntPtr h in Bars()) ShowWindow(h, 5); AutoHide(false); }
    public static bool TaskbarVisible() { foreach (IntPtr h in Bars()) if (IsWindowVisible(h)) return true; return false; }

    // ---- lone Win key -> valo menu (a masked key stops the Start menu, like AutoHotkey does)
    public static ConcurrentQueue<string> Events = new ConcurrentQueue<string>();
    public static volatile bool CaptureWin = true;
    static HookProc hookProc;
    static bool winDown, otherKey;
    static IntPtr Hook(int code, IntPtr w, IntPtr l) {
        if (code >= 0 && CaptureWin) {
            KBD k = (KBD)Marshal.PtrToStructure(l, typeof(KBD));
            bool injected = (k.flags & 0x10) != 0;
            bool down = w.ToInt32() == 0x100 || w.ToInt32() == 0x104;
            bool isWin = k.vk == 0x5B || k.vk == 0x5C;
            if (isWin && !injected) {
                if (down && !winDown) { winDown = true; otherKey = false; keybd_event(0xE8, 0, 0, UIntPtr.Zero); keybd_event(0xE8, 0, 2, UIntPtr.Zero); }
                else if (!down) { if (winDown && !otherKey) Events.Enqueue("win"); winDown = false; }
            } else if (down && winDown && !injected) {
                otherKey = true;
            }
        }
        return CallNextHookEx(IntPtr.Zero, code, w, l);
    }
    public static void StartKeyHook() {
        Thread t = new Thread(delegate () {
            hookProc = Hook;
            SetWindowsHookEx(13, hookProc, GetModuleHandle(null), 0);
            MSG m; while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) { }
        });
        t.IsBackground = true; t.Start();
    }

    // ---- work area = between the valo bar and the valo dock (the hidden taskbar would otherwise reclaim it)
    [DllImport("user32.dll")] static extern bool SystemParametersInfo(uint a, uint b, ref RECT r, uint f);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    public static string EnsureWorkArea() {
        int cx = GetSystemMetrics(0), cy = GetSystemMetrics(1);
        RECT want = new RECT(); want.l = 0; want.t = 0; want.r = cx; want.b = cy;
        RECT r;
        IntPtr bar = FindWindow("Tauri Window", "Zebar - quill / bar");
        if (bar != IntPtr.Zero && IsWindowVisible(bar) && GetWindowRect(bar, out r) && r.t <= 0 && r.b < cy / 3) want.t = r.b;
        IntPtr dock = FindWindow("Tauri Window", "Zebar - quill / dock");
        if (dock != IntPtr.Zero && IsWindowVisible(dock) && GetWindowRect(dock, out r) && r.b >= cy && r.t > cy * 2 / 3) want.b = r.t;
        RECT cur = new RECT();
        SystemParametersInfo(0x30, 0, ref cur, 0);
        if (cur.l == want.l && cur.t == want.t && cur.r == want.r && cur.b == want.b) return null;
        SystemParametersInfo(0x2F, 0, ref want, 2);
        return want.t + "-" + want.b;
    }

    // ---- dock window: bottom app bar (maximized windows stop above it) or overlap mode (no app bar, window = the dock itself)
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    public static void DpiAware() { try { SetProcessDPIAware(); } catch { } }
    public static volatile bool Overlap = false;
    public static volatile int FitW = 0;
    public static volatile bool DockHide = false;
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int x, y; }
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
    static bool dockShown = true;
    static void SendVis(bool show) {
        dockShown = show;
        Console.Out.WriteLine(show ? "{\"type\":\"dockvis\",\"show\":true}" : "{\"type\":\"dockvis\",\"show\":false}");
        Console.Out.Flush();
    }
    // overlap + hide: show the dock when the cursor touches the bottom edge, hide it after the cursor leaves the dock (and its preview)
    public static void StartDockWatch() {
        Thread t = new Thread(delegate () {
            long outSince = 0, edgeSince = 0;
            while (true) {
                Thread.Sleep(60);
                try {
                    long now = Environment.TickCount;
                    if (!(DockHide && Overlap)) { if (!dockShown) SendVis(true); outSince = 0; edgeSince = 0; continue; }
                    POINT p; if (!GetCursorPos(out p)) continue;
                    RECT r; IntPtr d = DockWindow(); if (d == IntPtr.Zero || !GetWindowRect(d, out r)) continue;
                    int cy = GetSystemMetrics(1);
                    if (!dockShown) {
                        if (p.y >= cy - 2) { if (edgeSince == 0) edgeSince = now; if (now - edgeSince >= 100) { SendVis(true); outSince = 0; } }
                        else edgeSince = 0;
                        continue;
                    }
                    edgeSince = 0;
                    bool over = (p.x >= r.l && p.x < r.r && p.y >= r.t - 4 && p.y < r.b) || PreviewForm.IsOver(p.x, p.y) || p.y >= cy - 2;
                    if (over) { outSince = 0; continue; }
                    if (outSince == 0) outSince = now;
                    if (now - outSince >= 700) SendVis(false);
                } catch { }
            }
        });
        t.IsBackground = true; t.Start();
    }
    static IntPtr dockBar = IntPtr.Zero, dockWin = IntPtr.Zero;
    static int dockH = 0;
    static readonly object dockLock = new object();
    public static IntPtr DockWindow() { return FindWindow("Tauri Window", "Zebar - quill / dock"); }
    public static bool DockOrigin(out int x, out int y) {
        x = 0; y = 0; RECT r;
        IntPtr d = DockWindow();
        if (d == IntPtr.Zero || !GetWindowRect(d, out r)) return false;
        x = r.l; y = r.t; return true;
    }
    public static string EnsureDock() {
        lock (dockLock) {
            IntPtr dock = DockWindow();
            if (dock == IntPtr.Zero || !IsWindowVisible(dock)) return null;
            RECT r; if (!GetWindowRect(dock, out r)) return null;
            int cx = GetSystemMetrics(0), cy = GetSystemMetrics(1);
            if (dock != dockWin || dockH <= 0) { dockWin = dock; dockH = r.b - r.t; dockBar = IntPtr.Zero; }
            string res = "";
            int w = cx, x = 0, y = cy - dockH;
            if (Overlap && FitW > 0) { w = Math.Min(FitW, cx); x = (cx - w) / 2; }
            if (r.l != x || r.t != y || r.r - r.l != w || r.b - r.t != dockH) {
                SetWindowPos(dock, IntPtr.Zero, x, y, w, dockH, 0x0014);     // SWP_NOZORDER | SWP_NOACTIVATE
                res += " window " + x + "," + y + " " + w + "x" + dockH;
            }
            APPBARDATA d = new APPBARDATA(); d.cbSize = Marshal.SizeOf(typeof(APPBARDATA)); d.hWnd = dock; d.cb = 0x8000 + 77;
            if (Overlap) {
                if (dockBar != IntPtr.Zero) { SHAppBarMessage(1, ref d); dockBar = IntPtr.Zero; res += " appbar removed"; }   // ABM_REMOVE
            } else if (dockBar != dock) {
                SHAppBarMessage(0, ref d);                 // ABM_NEW
                d.edge = 3;                                 // ABE_BOTTOM
                d.rc.l = 0; d.rc.r = cx; d.rc.b = cy; d.rc.t = cy - dockH;
                SHAppBarMessage(2, ref d);                 // ABM_QUERYPOS
                d.rc.t = d.rc.b - dockH;
                SHAppBarMessage(3, ref d);                 // ABM_SETPOS
                dockBar = dock;
                res += " appbar " + d.rc.t + "-" + d.rc.b;
            }
            return res.Length > 0 ? res.Trim() : null;
        }
    }

    // ---- pop-ups (menu, control center) always sit right under the bar, whatever its height / style
    public static volatile bool BarSticky = false;
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr h);
    public static string EnsurePopups() {
        IntPtr bar = FindWindow("Tauri Window", "Zebar - quill / bar");
        RECT b; if (bar == IntPtr.Zero || !GetWindowRect(bar, out b)) return null;
        float s = 1f; try { uint dpi = GetDpiForWindow(bar); if (dpi > 0) s = dpi / 96f; } catch { }
        string res = "";
        foreach (string name in new string[] { "menu", "control" }) {
            IntPtr h = FindWindow("Tauri Window", "Zebar - quill / " + name);
            RECT r; if (h == IntPtr.Zero || !GetWindowRect(h, out r)) continue;
            int w = r.r - r.l;
            // floating: the pop-up has a 6px transparent margin -> 8px visible gap, 18px from the screen edge like the bar
            // sticky: flush with the bar and the screen edge
            int y = b.b + (BarSticky ? 0 : (int)Math.Round(2 * s));
            int side = BarSticky ? 0 : (int)Math.Round(12 * s);
            int x = name == "menu" ? b.l + side : b.r - w - side;
            if (r.l != x || r.t != y) {
                SetWindowPos(h, IntPtr.Zero, x, y, 0, 0, 0x0015);   // NOSIZE | NOZORDER | NOACTIVATE
                res += " " + name + " " + x + "," + y;
            }
        }
        return res.Length > 0 ? res.Trim() : null;
    }

    // ---- recycle bin
    [StructLayout(LayoutKind.Sequential)] struct RBINFO { public int cbSize; public long size; public long items; }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern int SHQueryRecycleBin(string root, ref RBINFO q);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern int SHEmptyRecycleBin(IntPtr h, string root, uint flags);
    public static long TrashCount() { RBINFO q = new RBINFO(); q.cbSize = Marshal.SizeOf(typeof(RBINFO)); return SHQueryRecycleBin(null, ref q) == 0 ? q.items : -1; }
    public static void EmptyTrash() { Thread t = new Thread(delegate () { SHEmptyRecycleBin(IntPtr.Zero, null, 1); }); t.IsBackground = true; t.Start(); }   // SHERB_NOCONFIRMATION (the dock asks twice)

    // ---- stdin commands on their own thread (Console.In.ReadLineAsync blocks in Windows PowerShell)
    public static ConcurrentQueue<string> Commands = new ConcurrentQueue<string>();
    public static void StartStdinReader() {
        Thread t = new Thread(delegate () {
            try {
                string line;
                while ((line = Console.In.ReadLine()) != null) {
                    string c = line.Trim().TrimStart('\uFEFF');
                    if (!c.StartsWith("preview")) try { System.IO.File.AppendAllText(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "valo-shell.log"), DateTime.Now.ToString("HH:mm:ss") + " cmd " + c + "\r\n"); } catch { }
                    // latency-sensitive commands run right here, the rest goes to the script loop
                    try {
                        if (c.StartsWith("preview")) { PreviewForm.Cmd(c); continue; }
                        if (c.StartsWith("activate ")) { PreviewForm.Cmd("preview hide"); Activate(long.Parse(c.Substring(9))); continue; }
                        if (c.StartsWith("min ")) { Minimize(long.Parse(c.Substring(4))); continue; }
                        if (c == "emptytrash") { EmptyTrash(); continue; }
                        if (c.StartsWith("barstyle ")) { BarSticky = c.EndsWith("1"); Commands.Enqueue("popups"); continue; }
                        if (c.StartsWith("dock ")) {
                            string[] a = c.Split(' ');
                            Overlap = a.Length > 1 && a[1] == "1";
                            int fw = 0; if (a.Length > 2) int.TryParse(a[2], out fw); FitW = fw;
                            DockHide = a.Length > 3 && a[3] == "1";
                            Commands.Enqueue("dockchanged");
                            continue;
                        }
                    } catch { }
                    Commands.Enqueue(line);
                }
            } catch { }
            Commands.Enqueue("parent-gone");
        });
        t.IsBackground = true; t.Start();
    }

    // ---- icons
    public static string IconPng(string path) {
        try {
            using (System.Drawing.Icon ico = System.Drawing.Icon.ExtractAssociatedIcon(path))
            using (System.Drawing.Bitmap src = ico.ToBitmap())
            using (System.Drawing.Bitmap bmp = new System.Drawing.Bitmap(48, 48))
            using (System.Drawing.Graphics g = System.Drawing.Graphics.FromImage(bmp))
            using (System.IO.MemoryStream ms = new System.IO.MemoryStream()) {
                g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                g.DrawImage(src, 0, 0, 48, 48);
                bmp.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
                return Convert.ToBase64String(ms.ToArray());
            }
        } catch { return null; }
    }
}

// ---- hover preview: small top-most window with live DWM thumbnails of an app's windows
public class PreviewForm : WF.Form {
    [DllImport("dwmapi.dll")] static extern int DwmRegisterThumbnail(IntPtr dest, IntPtr src, out IntPtr id);
    [DllImport("dwmapi.dll")] static extern int DwmUnregisterThumbnail(IntPtr id);
    [DllImport("dwmapi.dll")] static extern int DwmUpdateThumbnailProperties(IntPtr id, ref TP p);
    [DllImport("dwmapi.dll")] static extern int DwmQueryThumbnailSourceSize(IntPtr id, out SZ s);
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    [StructLayout(LayoutKind.Sequential)] struct SZ { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct R4 { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct TP { public uint flags; public R4 dst; public R4 src; public byte opacity; public bool visible; public bool clientOnly; }

    class Cell { public IntPtr h, thumb; public string title; public bool min; public SD.Rectangle box, img, x; }

    static PreviewForm inst;
    static volatile bool pvShown = false;
    static SD.Rectangle pvBounds;
    public static bool IsOver(int x, int y) { return pvShown && pvBounds.Contains(x, y); }
    public static void Start() {
        ManualResetEvent ready = new ManualResetEvent(false);
        Thread t = new Thread(delegate () {
            inst = new PreviewForm();
            IntPtr force = inst.Handle;
            ready.Set();
            WF.Application.Run();
        });
        t.SetApartmentState(ApartmentState.STA); t.IsBackground = true; t.Start();
        ready.WaitOne(5000);
    }
    public static void Cmd(string line) {
        PreviewForm f = inst;
        if (f == null) return;
        try { f.BeginInvoke(new Action<string>(f.OnCmd), line); } catch { }
    }

    List<Cell> cells = new List<Cell>();
    string key = "";
    int hover = -1;
    long hideAt = 0;
    bool entered = false;
    float s = 1f;
    SD.Color bg = SD.Color.FromArgb(30, 26, 31), fg = SD.Color.FromArgb(245, 230, 234), accent = SD.Color.FromArgb(242, 167, 187), muted = SD.Color.FromArgb(156, 138, 147);
    SD.Font font = new SD.Font("Segoe UI", 9f);
    WF.Timer timer = new WF.Timer();

    public PreviewForm() {
        FormBorderStyle = WF.FormBorderStyle.None; ShowInTaskbar = false; StartPosition = WF.FormStartPosition.Manual;
        AutoScaleMode = WF.AutoScaleMode.None; DoubleBuffered = true; Text = ""; BackColor = bg;
        Bounds = new SD.Rectangle(-3000, -3000, 10, 10);
        timer.Interval = 100; timer.Tick += delegate { TickHide(); }; timer.Start();
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override WF.CreateParams CreateParams {
        get { WF.CreateParams p = base.CreateParams; p.ExStyle |= 0x08000088; return p; }   // NOACTIVATE | TOOLWINDOW | TOPMOST
    }
    protected override void OnHandleCreated(EventArgs e) {
        base.OnHandleCreated(e);
        int round = 2; DwmSetWindowAttribute(Handle, 33, ref round, 4);   // Windows 11 rounded corners
        using (SD.Graphics g = CreateGraphics()) s = g.DpiX / 96f;
    }

    static SD.Color Col(string v, SD.Color d) { try { return SD.ColorTranslator.FromHtml(v); } catch { return d; } }
    int S(float v) { return (int)Math.Round(v * s); }

    void OnCmd(string line) {
        string[] a = line.Split(' ');
        if (a.Length >= 2 && a[1] == "hide") { HidePv(); return; }
        if (a.Length >= 2 && a[1] == "off") {
            if (Visible && !Bounds.Contains(WF.Cursor.Position) && hideAt == 0) hideAt = Environment.TickCount + 300;
            return;
        }
        if (a.Length < 8) return;
        int x, top, ox, oy;
        if (!int.TryParse(a[1], out x) || !int.TryParse(a[2], out top)) return;
        if (!ValoShell.DockOrigin(out ox, out oy)) return;
        bg = Col(a[3], bg); fg = Col(a[4], fg); accent = Col(a[5], accent); muted = Col(a[6], muted);
        hideAt = 0;
        string k = a[7] + "@" + x;
        if (Visible && k == key) return;
        key = k; entered = false;
        Build(a[7].Split(','), ox + x, oy + top);
    }

    void Clear() {
        foreach (Cell c in cells) if (c.thumb != IntPtr.Zero) DwmUnregisterThumbnail(c.thumb);
        cells.Clear(); hover = -1;
    }
    void HidePv() { pvShown = false; hideAt = 0; entered = false; key = ""; if (Visible) Hide(); Clear(); }

    void Build(string[] hwnds, int anchorX, int anchorTop) {
        Clear();
        int sw = GetSystemMetrics(0);
        int pad = S(8), gap = S(8), head = S(26);
        int n = 0; foreach (string hs in hwnds) if (hs.Length > 0) n++;
        if (n == 0) { HidePv(); return; }
        int maxW = Math.Min(S(230), (sw - S(40) - gap * (n - 1) - pad * 2) / n), maxH = S(140);
        int imgH = 0;
        foreach (string hs in hwnds) {
            long hv; if (!long.TryParse(hs, out hv)) continue;
            IntPtr h = new IntPtr(hv); if (!IsWindow(h)) continue;
            Cell c = new Cell(); c.h = h;
            StringBuilder t = new StringBuilder(512); GetWindowText(h, t, 512); c.title = t.ToString();
            c.min = IsIconic(h);
            int w = Math.Min(S(160), maxW), ih = S(90);
            if (!c.min && DwmRegisterThumbnail(Handle, h, out c.thumb) == 0) {
                SZ z;
                if (DwmQueryThumbnailSourceSize(c.thumb, out z) == 0 && z.x > 0 && z.y > 0) {
                    double k = Math.Min((double)maxW / z.x, (double)maxH / z.y);
                    w = (int)(z.x * k); ih = (int)(z.y * k);
                }
            } else c.thumb = IntPtr.Zero;
            c.box = new SD.Rectangle(0, 0, w, ih);
            imgH = Math.Max(imgH, ih);
            cells.Add(c);
        }
        if (cells.Count == 0) { HidePv(); return; }
        int cx = pad;
        foreach (Cell c in cells) {
            int iw = c.box.Width, ih = c.box.Height, w = Math.Max(iw, Math.Min(S(140), maxW));
            c.box = new SD.Rectangle(cx, pad, w, head + imgH);
            c.img = new SD.Rectangle(cx + (w - iw) / 2, pad + head + (imgH - ih) / 2, iw, ih);
            c.x = new SD.Rectangle(cx + w - S(22), pad + S(2), S(20), S(20));
            cx += w + gap;
        }
        int W = cx - gap + pad, H = pad * 2 + head + imgH;
        int L = Math.Max(S(6), Math.Min(sw - W - S(6), anchorX - W / 2)), T = anchorTop - H - S(8);
        Bounds = new SD.Rectangle(L, T, W, H);
        pvBounds = Bounds; pvShown = true;
        BackColor = bg;
        int bc = accent.R | (accent.G << 8) | (accent.B << 16); DwmSetWindowAttribute(Handle, 34, ref bc, 4);   // border colour
        foreach (Cell c in cells) {
            if (c.thumb == IntPtr.Zero) continue;
            TP p = new TP(); p.flags = 0x1D; p.opacity = 255; p.visible = true; p.clientOnly = false;
            p.dst.l = c.img.Left; p.dst.t = c.img.Top; p.dst.r = c.img.Right; p.dst.b = c.img.Bottom;
            DwmUpdateThumbnailProperties(c.thumb, ref p);
        }
        if (!Visible) Show();
        SetWindowPos(Handle, new IntPtr(-1), 0, 0, 0, 0, 0x13);   // HWND_TOPMOST, NOSIZE | NOMOVE | NOACTIVATE
        Invalidate();
    }

    void TickHide() {
        if (!Visible) return;
        long now = Environment.TickCount;
        if (Bounds.Contains(WF.Cursor.Position)) { entered = true; hideAt = 0; return; }
        if (entered && hideAt == 0) hideAt = now + 250;
        if (hover != -1) { hover = -1; Invalidate(); }
        if (hideAt != 0 && now >= hideAt) HidePv();
    }

    static SD.Color Mix(SD.Color a, SD.Color b, float t) {
        return SD.Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));
    }
    protected override void OnPaint(WF.PaintEventArgs e) {
        SD.Graphics g = e.Graphics;
        g.Clear(bg);
        for (int i = 0; i < cells.Count; i++) {
            Cell c = cells[i];
            if (i == hover) using (SD.SolidBrush hb = new SD.SolidBrush(Mix(bg, fg, .09f))) g.FillRectangle(hb, SD.Rectangle.Inflate(c.box, S(4), S(4)));
            SD.Rectangle tr = new SD.Rectangle(c.box.Left + S(2), c.box.Top, c.box.Width - S(26), S(22));
            WF.TextRenderer.DrawText(g, c.title, font, tr, i == hover ? fg : Mix(fg, muted, .35f),
                WF.TextFormatFlags.Left | WF.TextFormatFlags.VerticalCenter | WF.TextFormatFlags.EndEllipsis | WF.TextFormatFlags.SingleLine | WF.TextFormatFlags.NoPrefix);
            if (i == hover) WF.TextRenderer.DrawText(g, "✕", font, c.x, accent, WF.TextFormatFlags.HorizontalCenter | WF.TextFormatFlags.VerticalCenter);
            if (c.thumb == IntPtr.Zero) {
                using (SD.SolidBrush pb = new SD.SolidBrush(Mix(bg, fg, .06f))) g.FillRectangle(pb, c.img);
                WF.TextRenderer.DrawText(g, c.min ? "згорнуто" : "", font, c.img, muted, WF.TextFormatFlags.HorizontalCenter | WF.TextFormatFlags.VerticalCenter);
            }
        }
    }
    int Hit(SD.Point p) { for (int i = 0; i < cells.Count; i++) if (SD.Rectangle.Inflate(cells[i].box, S(4), S(4)).Contains(p)) return i; return -1; }
    protected override void OnMouseMove(WF.MouseEventArgs e) { int h = Hit(e.Location); if (h != hover) { hover = h; Invalidate(); } }
    protected override void OnMouseLeave(EventArgs e) { hover = -1; Invalidate(); }
    protected override void OnMouseUp(WF.MouseEventArgs e) {
        int i = Hit(e.Location); if (i < 0) return;
        Cell c = cells[i];
        if (e.Button == WF.MouseButtons.Middle || (e.Button == WF.MouseButtons.Left && c.x.Contains(e.Location))) {
            ValoShell.Close(c.h.ToInt64());
            if (cells.Count <= 1) { HidePv(); return; }
            List<string> rest = new List<string>();
            foreach (Cell o in cells) if (o != c) rest.Add(o.h.ToInt64().ToString());
            SD.Rectangle b = Bounds; key = "";
            Build(rest.ToArray(), b.Left + b.Width / 2, b.Bottom + S(8));
            return;
        }
        if (e.Button == WF.MouseButtons.Left) { HidePv(); ValoShell.Activate(c.h.ToInt64()); }
    }
}

'@

if ($RestoreTaskbar) { [ValoShell]::ShowTaskbar(); return }
if ($HideTaskbar) { for ($i = 0; $i -lt 20; $i++) { if ([ValoShell]::TaskbarVisible()) { [ValoShell]::HideTaskbar() }; Start-Sleep -Milliseconds 500 }; return }
[ValoShell]::DpiAware()

# single instance: stop an older helper (e.g. after a Zebar restart)
$pidFile = "$env:TEMP\valo-shell.pid"
if (Test-Path $pidFile) {
    $old = Get-Content $pidFile -EA SilentlyContinue
    if ($old -and $old -ne "$PID") { Stop-Process -Id ([int]$old) -Force -EA SilentlyContinue }
}
Set-Content $pidFile $PID

function Log($m) { Add-Content -LiteralPath "$env:TEMP\valo-shell.log" -Value ((Get-Date -f 'HH:mm:ss') + ' ' + $m) }
trap { Log ("error: " + $_ + ' @' + $_.InvocationInfo.ScriptLineNumber); continue }
function Send($obj) { [Console]::Out.WriteLine(($obj | ConvertTo-Json -Compress -Depth 4)); [Console]::Out.Flush() }

$hideTaskbar = $true
Log 'helper started'
Log 'hook...'; [ValoShell]::StartKeyHook(); Log 'hook ok'
[PreviewForm]::Start(); Log 'preview ok'
[ValoShell]::StartStdinReader()
[ValoShell]::StartDockWatch()
$last = ''
$iconsSent = @{}
$tick = 0
$lastTrash = -2
$gone = $false

while ($true) {
    # commands from the dock
    $line = $null
    while ([ValoShell]::Commands.TryDequeue([ref]$line)) {
        $parts = $line.Trim() -split ' ', 2
        switch ($parts[0]) {
            'activate'      { [ValoShell]::Activate([long]$parts[1]) }
            'min'           { [ValoShell]::Minimize([long]$parts[1]) }
            'close'         { [ValoShell]::Close([long]$parts[1]) }
            'activatetitle' { [ValoShell]::ActivateTitle($parts[1]) }
            'taskbar'       { $hideTaskbar = $parts[1] -eq 'hide'; if ($hideTaskbar) { [ValoShell]::HideTaskbar() } else { [ValoShell]::ShowTaskbar() } }
            'wincapture'    { [ValoShell]::CaptureWin = $parts[1] -eq 'on' }
            'quit'          { [ValoShell]::ShowTaskbar(); exit }
            'parent-gone'   { $gone = $true }
            'popups'        { $r = [ValoShell]::EnsurePopups(); Log ("bar sticky=$([ValoShell]::BarSticky) $r") }
            'dockchanged'   { $r = [ValoShell]::EnsureDock(); Log ("dock mode overlap=$([ValoShell]::Overlap) hide=$([ValoShell]::DockHide) fit=$([ValoShell]::FitW) $r") }
        }
    }

    # dock is gone (Zebar closed): give a restarted Zebar a moment, otherwise bring the Windows taskbar back
    if ($gone -or ($tick % 10 -eq 0 -and -not (Get-Process zebar -EA SilentlyContinue))) {
        # exit right away (a lingering child breaks the next Zebar start); a detached watcher restores the taskbar later
        $self = $MyInvocation.MyCommand.Path
        if (-not $self) { $self = $PSCommandPath }
        $watch = "Start-Sleep 8; if ((Get-Content '$pidFile' -EA SilentlyContinue) -eq '$PID') { & '$PSCommandPath' -RestoreTaskbar; Remove-Item '$pidFile' -EA SilentlyContinue }"
        Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $watch
        Log 'dock gone, exiting'
        exit
    }
    $ev = $null
    while ([ValoShell]::Events.TryDequeue([ref]$ev)) { Send @{ type = 'win' } }

    if ($hideTaskbar -and ($tick % 5 -eq 0) -and [ValoShell]::TaskbarVisible()) { [ValoShell]::HideTaskbar(); Log 'taskbar hidden' }
    if ($hideTaskbar -and ($tick % 10 -eq 0) -and [ValoShell]::EnsureAutoHide()) { Log 'auto-hide re-enabled' }
    if ($tick % 3 -eq 0) { $ab = [ValoShell]::EnsureDock(); if ($ab) { Log ('dock ' + $ab) } }
    if ($tick % 3 -eq 1) { $pp = [ValoShell]::EnsurePopups(); if ($pp) { Log ('popups ' + $pp) } }
    if ($false -and $hideTaskbar -and ($tick % 4 -eq 0)) { $wa = [ValoShell]::EnsureWorkArea(); if ($wa) { Log ('work area ' + $wa) } }

    if ($tick % 6 -eq 0) { $tn = [ValoShell]::TrashCount(); if ($tn -ne $lastTrash) { $lastTrash = $tn; Send @{ type = 'trash'; n = $tn } } }

    $wins = [ValoShell]::Windows()
    foreach ($w in $wins) {
        if ($w.exe -and -not $iconsSent.ContainsKey($w.exe)) {
            $iconsSent[$w.exe] = 1
            $png = [ValoShell]::IconPng($w.exe)
            if ($png) { Send @{ type = 'icon'; path = $w.exe; png = $png } }
        }
    }
    $json = ConvertTo-Json -InputObject @($wins | ForEach-Object { [ordered]@{ h = $_.hwnd; t = $_.title; exe = $_.exe; a = $_.aumid; d = $_.desc; min = $_.min; fg = $_.fg } }) -Compress -Depth 3
    if ($json -ne $last) { $last = $json; [Console]::Out.WriteLine('{"type":"windows","list":' + $json + '}'); [Console]::Out.Flush() }

    if ($tick % 30 -eq 0) { Log ("tick $tick wins $($wins.Count) tbVisible $([ValoShell]::TaskbarVisible())") }
    $tick++
    Start-Sleep -Milliseconds 350
}
