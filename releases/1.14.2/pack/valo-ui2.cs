// valo.os helper, part 2 (compiled with valo-shell.ps1 + valo-ui.cs):
//   AudioMix   - per-app volume, output devices, default device switch (Core Audio)
//   SysMon     - CPU / RAM / temperature samples
//   ValoWatch  - hot corners, game mode (fullscreen app), idle (screensaver), virtual desktops
//   Zones      - Shift while dragging a window: snap it into a layout zone
//   Gamma      - warm screen (gamma ramp)
//   Typer      - types text (emoji) into the window that was active before
// Events go to stdout as JSON lines (Console.Out is synchronized).

// ------------------------------------------------------------------ "show in folder"
// In Files when it is the default file manager (valo-files.ps1 wrote the per-user Folder\shell\open key), otherwise in Explorer.
public static class ValoFiles {
    static string Alias() { return Environment.ExpandEnvironmentVariables(@"%LOCALAPPDATA%\Microsoft\WindowsApps\files-stable.exe"); }
    public static bool IsDefault() {
        try {
            using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Classes\Folder\shell\open\command")) {
                string cmd = k == null ? null : k.GetValue("", "", Microsoft.Win32.RegistryValueOptions.DoNotExpandEnvironmentNames) as string;
                return cmd != null && cmd.Contains("Files.App.Launcher.exe") && System.IO.File.Exists(Alias());
            }
        } catch { return false; }
    }
    // Win+E: Windows 11 26H2 no longer follows the per-user Win+E key, so the helper's hook opens Files itself
    public static void OpenNew() { try { System.Diagnostics.Process.Start(Alias()); } catch { } }
    public static void Reveal(string path) {
        try {
            string cmd = null;
            using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Classes\Folder\shell\open\command"))
                if (k != null) cmd = k.GetValue("", "", Microsoft.Win32.RegistryValueOptions.DoNotExpandEnvironmentNames) as string;
            string alias = Environment.ExpandEnvironmentVariables(@"%LOCALAPPDATA%\Microsoft\WindowsApps\files-stable.exe");
            if (cmd != null && cmd.Contains("Files.App.Launcher.exe") && System.IO.File.Exists(alias)) { System.Diagnostics.Process.Start(alias, "-select \"" + path + "\""); return; }
        } catch { }
        try { System.Diagnostics.Process.Start("explorer.exe", "/select,\"" + path + "\""); } catch { }
    }
}

// ------------------------------------------------------------------ Windows taskbar guard
// The Windows taskbar is hidden (and auto-hide); when the cursor touches the screen edge Explorer shows it again.
// A WinEvent hook hides it the moment it is shown, instead of waiting for the helper's slow loop.
public static class TrayGuard {
    delegate void WinEventProc(IntPtr hook, uint ev, IntPtr hwnd, int obj, int child, uint thread, uint time);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr mod, WinEventProc proc, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint a, uint b);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr h; public uint msg; public IntPtr w, l; public uint time; public int x, y; }
    public static volatile bool On = true;
    static WinEventProc proc;
    static bool IsTray(IntPtr h) {
        StringBuilder c = new StringBuilder(64); GetClassName(h, c, 64); string n = c.ToString();
        return n == "Shell_TrayWnd" || n == "Shell_SecondaryTrayWnd";
    }
    public static void Start() {
        Thread t = new Thread(delegate () {
            proc = delegate (IntPtr hook, uint ev, IntPtr hwnd, int obj, int child, uint thread, uint time) {
                if (On && obj == 0 && hwnd != IntPtr.Zero && IsTray(hwnd)) ShowWindow(hwnd, 0);
            };
            SetWinEventHook(0x8002, 0x8002, IntPtr.Zero, proc, 0, 0, 0);   // EVENT_OBJECT_SHOW, out of context
            MSG m; while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) { }
        });
        t.IsBackground = true; t.Start();
    }
}

public static class Emit {
    public static void Line(string json) { try { Console.Out.WriteLine(json); Console.Out.Flush(); } catch { } }
    public static string Q(string s) {
        if (s == null) return "null";
        StringBuilder b = new StringBuilder("\"");
        foreach (char c in s) {
            if (c == '"' || c == '\\') b.Append('\\').Append(c);
            else if (c < 32) b.Append("\\u").Append(((int)c).ToString("x4"));
            else b.Append(c);
        }
        return b.Append('"').ToString();
    }
}

// ------------------------------------------------------------------ Core Audio
public static class AudioMix {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCo { }
    [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")] class PolicyConfigCo { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device);
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IMMDevice device);
        int RegisterEndpointNotificationCallback(IntPtr client);
        int UnregisterEndpointNotificationCallback(IntPtr client);
    }
    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceCollection { int GetCount(out int n); int Item(int i, out IMMDevice d); }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice {
        int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o);
        int OpenPropertyStore(int access, out ValoShell.IPropertyStore store);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        int GetState(out int state);
    }
    [ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionManager2 {
        int GetAudioSessionControl(IntPtr g, int f, out IntPtr c);
        int GetSimpleAudioVolume(IntPtr g, int f, out IntPtr v);
        int GetSessionEnumerator(out IAudioSessionEnumerator e);
    }
    [ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionEnumerator { int GetCount(out int n); int GetSession(int i, out IAudioSessionControl2 s); }
    [ComImport, Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioSessionControl2 {
        int GetState(out int state);
        int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string name);
        int SetDisplayName(string n, IntPtr ctx);
        int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string p);
        int SetIconPath(string p, IntPtr ctx);
        int GetGroupingParam(out Guid g);
        int SetGroupingParam(ref Guid g, IntPtr ctx);
        int RegisterAudioSessionNotification(IntPtr n);
        int UnregisterAudioSessionNotification(IntPtr n);
        int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
        int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string id);
        int GetProcessId(out uint pid);
        int IsSystemSoundsSession();
        int SetDuckingPreference(bool opt);
    }
    [ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ISimpleAudioVolume {
        int SetMasterVolume(float v, ref Guid ctx); int GetMasterVolume(out float v);
        int SetMute(bool m, ref Guid ctx); int GetMute(out bool m);
    }
    [ComImport, Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPolicyConfig {
        int GetMixFormat(string id, IntPtr f); int GetDeviceFormat(string id, bool d, IntPtr f); int ResetDeviceFormat(string id);
        int SetDeviceFormat(string id, IntPtr a, IntPtr b); int GetProcessingPeriod(string id, bool d, IntPtr a, IntPtr b);
        int SetProcessingPeriod(string id, IntPtr p); int GetShareMode(string id, IntPtr m); int SetShareMode(string id, IntPtr m);
        int GetPropertyValue(string id, IntPtr k, IntPtr v); int SetPropertyValue(string id, IntPtr k, IntPtr v);
        int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
        int SetEndpointVisibility(string id, bool v);
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume {
        int RegisterControlChangeNotify(IntPtr n); int UnregisterControlChangeNotify(IntPtr n); int GetChannelCount(out uint c);
        int SetMasterVolumeLevel(float db, ref Guid ctx); int SetMasterVolumeLevelScalar(float v, ref Guid ctx);
        int GetMasterVolumeLevel(out float db); int GetMasterVolumeLevelScalar(out float v);
        int SetChannelVolumeLevel(uint ch, float db, ref Guid ctx); int SetChannelVolumeLevelScalar(uint ch, float v, ref Guid ctx);
        int GetChannelVolumeLevel(uint ch, out float db); int GetChannelVolumeLevelScalar(uint ch, out float v);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool m, ref Guid ctx); int GetMute([MarshalAs(UnmanagedType.Bool)] out bool m);
    }
    static Guid ctxGuid = Guid.Empty;
    static IMMDeviceEnumerator En() { return (IMMDeviceEnumerator)new MMDeviceEnumeratorCo(); }

    static string FriendlyName(IMMDevice d) {
        try {
            ValoShell.IPropertyStore st; d.OpenPropertyStore(0, out st);
            ValoShell.PROPERTYKEY k = new ValoShell.PROPERTYKEY(); k.fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"); k.pid = 14;
            ValoShell.PROPVARIANT v; string r = null;
            if (st.GetValue(ref k, out v) == 0 && v.vt == 31) r = Marshal.PtrToStringUni(v.p);
            Marshal.ReleaseComObject(st); return r;
        } catch { return null; }
    }
    static List<ISimpleAudioVolume> Sessions(out List<uint> pids, out List<string> names) {
        pids = new List<uint>(); names = new List<string>();
        List<ISimpleAudioVolume> vols = new List<ISimpleAudioVolume>();
        IMMDevice dev; En().GetDefaultAudioEndpoint(0, 1, out dev);
        Guid iid = typeof(IAudioSessionManager2).GUID; object o;
        dev.Activate(ref iid, 23, IntPtr.Zero, out o);
        IAudioSessionEnumerator e; ((IAudioSessionManager2)o).GetSessionEnumerator(out e);
        int n; e.GetCount(out n);
        for (int i = 0; i < n; i++) {
            IAudioSessionControl2 c; e.GetSession(i, out c);
            int state; c.GetState(out state);
            if (state == 2) continue;                     // expired
            uint pid; c.GetProcessId(out pid);
            bool sys = c.IsSystemSoundsSession() == 0;
            string name = sys ? "Системні звуки" : null;
            if (!sys) {
                try {
                    System.Diagnostics.Process p = System.Diagnostics.Process.GetProcessById((int)pid);
                    try { name = p.MainModule.FileVersionInfo.FileDescription; } catch { }
                    if (string.IsNullOrEmpty(name)) name = p.ProcessName;
                } catch { continue; }
            }
            pids.Add(sys ? 0 : pid); names.Add(name); vols.Add((ISimpleAudioVolume)c);
        }
        return vols;
    }
    public static string List() {
        StringBuilder b = new StringBuilder("{\"type\":\"audio\",\"apps\":[");
        try {
            List<uint> pids; List<string> names;
            List<ISimpleAudioVolume> vols = Sessions(out pids, out names);
            HashSet<string> seen = new HashSet<string>();
            bool first = true;
            for (int i = 0; i < vols.Count; i++) {
                string key = pids[i] + "|" + names[i];
                if (seen.Contains(key)) continue; seen.Add(key);
                float v; bool m; vols[i].GetMasterVolume(out v); vols[i].GetMute(out m);
                if (!first) b.Append(','); first = false;
                b.Append("{\"pid\":").Append(pids[i]).Append(",\"name\":").Append(Emit.Q(names[i]))
                 .Append(",\"vol\":").Append((int)Math.Round(v * 100)).Append(",\"mute\":").Append(m ? "true" : "false").Append('}');
            }
        } catch { }
        b.Append("],\"devices\":[");
        try {
            IMMDeviceEnumerator en = En();
            IMMDevice def; en.GetDefaultAudioEndpoint(0, 1, out def); string defId; def.GetId(out defId);
            IMMDeviceCollection col; en.EnumAudioEndpoints(0, 1, out col);
            int n; col.GetCount(out n);
            for (int i = 0; i < n; i++) {
                IMMDevice d; col.Item(i, out d); string id; d.GetId(out id);
                if (i > 0) b.Append(',');
                b.Append("{\"id\":").Append(Emit.Q(id)).Append(",\"name\":").Append(Emit.Q(FriendlyName(d) ?? id)).Append(",\"def\":").Append(id == defId ? "true" : "false").Append('}');
            }
        } catch { }
        return b.Append("]}").ToString();
    }
    public static void SetVol(uint pid, int vol) {
        try { List<uint> pids; List<string> names; List<ISimpleAudioVolume> v = Sessions(out pids, out names);
              for (int i = 0; i < v.Count; i++) if (pids[i] == pid) v[i].SetMasterVolume(Math.Max(0, Math.Min(100, vol)) / 100f, ref ctxGuid); } catch { }
    }
    public static void SetMute(uint pid, bool mute) {
        try { List<uint> pids; List<string> names; List<ISimpleAudioVolume> v = Sessions(out pids, out names);
              for (int i = 0; i < v.Count; i++) if (pids[i] == pid) v[i].SetMute(mute, ref ctxGuid); } catch { }
    }
    // ---- microphone: the default capture device (dataFlow 1 = eCapture)
    static IAudioEndpointVolume MicVolume() {
        IMMDevice d; if (En().GetDefaultAudioEndpoint(1, 1, out d) != 0 || d == null) return null;
        Guid iid = typeof(IAudioEndpointVolume).GUID; object o; d.Activate(ref iid, 23, IntPtr.Zero, out o);
        return (IAudioEndpointVolume)o;
    }
    public static int MicMuteState() {   // -1 = no microphone, 0 = on, 1 = muted
        try { IAudioEndpointVolume v = MicVolume(); if (v == null) return -1; bool m; v.GetMute(out m); return m ? 1 : 0; } catch { return -1; }
    }
    public static string MicList() {
        StringBuilder b = new StringBuilder("{\"type\":\"mic\"");
        try {
            IMMDeviceEnumerator en = En();
            IMMDevice def; string defId = null;
            if (en.GetDefaultAudioEndpoint(1, 1, out def) == 0 && def != null) {
                def.GetId(out defId);
                IAudioEndpointVolume v = MicVolume(); float f; bool m; v.GetMasterVolumeLevelScalar(out f); v.GetMute(out m);
                b.Append(",\"vol\":").Append((int)Math.Round(f * 100)).Append(",\"mute\":").Append(m ? "true" : "false").Append(",\"name\":").Append(Emit.Q(FriendlyName(def) ?? ""));
            }
            b.Append(",\"devices\":[");
            IMMDeviceCollection col; en.EnumAudioEndpoints(1, 1, out col);
            int n; col.GetCount(out n);
            for (int i = 0; i < n; i++) {
                IMMDevice d; col.Item(i, out d); string id; d.GetId(out id);
                if (i > 0) b.Append(',');
                b.Append("{\"id\":").Append(Emit.Q(id)).Append(",\"name\":").Append(Emit.Q(FriendlyName(d) ?? id)).Append(",\"def\":").Append(id == defId ? "true" : "false").Append('}');
            }
            b.Append(']');
        } catch { }
        return b.Append('}').ToString();
    }
    public static void MicSetVol(int vol) { try { MicVolume().SetMasterVolumeLevelScalar(Math.Max(0, Math.Min(100, vol)) / 100f, ref ctxGuid); } catch { } }
    public static void MicSetMute(bool mute) { try { MicVolume().SetMute(mute, ref ctxGuid); } catch { } }
    public static void MicToggle() { int s = MicMuteState(); if (s >= 0) MicSetMute(s == 0); }
    public static void SetDefault(string id) {
        try { IPolicyConfig pc = (IPolicyConfig)new PolicyConfigCo(); for (int r = 0; r < 3; r++) pc.SetDefaultEndpoint(id, r); } catch { }
    }
}

// ------------------------------------------------------------------ system monitor
public static class SysMon {
    [StructLayout(LayoutKind.Sequential)] struct FT { public uint lo, hi; }
    [StructLayout(LayoutKind.Sequential)] struct MEM { public uint len, load; public ulong total, avail, tp, ap, tv, av, ave; }
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out FT idle, out FT kernel, out FT user);
    [DllImport("kernel32.dll")] static extern bool GlobalMemoryStatusEx(ref MEM m);
    static ulong pIdle, pTotal;
    static ulong U(FT f) { return ((ulong)f.hi << 32) | f.lo; }
    static List<System.Diagnostics.PerformanceCounter> temps;
    public static volatile bool On = false;
    public static string Sample() {
        FT i, k, u; GetSystemTimes(out i, out k, out u);
        ulong idle = U(i), total = U(k) + U(u);
        double cpu = 0;
        if (pTotal > 0 && total > pTotal) cpu = 100.0 * (1 - (double)(idle - pIdle) / (total - pTotal));
        pIdle = idle; pTotal = total;
        MEM m = new MEM(); m.len = (uint)Marshal.SizeOf(typeof(MEM)); GlobalMemoryStatusEx(ref m);
        double temp = -1;
        try {
            if (temps == null) {
                temps = new List<System.Diagnostics.PerformanceCounter>();
                System.Diagnostics.PerformanceCounterCategory cat = new System.Diagnostics.PerformanceCounterCategory("Thermal Zone Information");
                foreach (string inst in cat.GetInstanceNames()) temps.Add(new System.Diagnostics.PerformanceCounter("Thermal Zone Information", "Temperature", inst));
            }
            foreach (System.Diagnostics.PerformanceCounter c in temps) { double kv = c.NextValue(); if (kv > 200) temp = Math.Max(temp, kv - 273.15); }
        } catch { temps = new List<System.Diagnostics.PerformanceCounter>(); }
        return "{\"type\":\"sys\",\"cpu\":" + Math.Round(Math.Max(0, Math.Min(100, cpu))) + ",\"ram\":" + m.load +
               ",\"ramUsed\":" + Math.Round((m.total - m.avail) / 1073741824.0, 1).ToString(System.Globalization.CultureInfo.InvariantCulture) +
               ",\"ramTotal\":" + Math.Round(m.total / 1073741824.0, 1).ToString(System.Globalization.CultureInfo.InvariantCulture) +
               ",\"temp\":" + (temp < 0 ? "null" : Math.Round(temp).ToString()) + "}";
    }
}

// ------------------------------------------------------------------ gamma (warm screen)
public static class Gamma {
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool SetDeviceGammaRamp(IntPtr dc, ushort[] ramp);
    public static volatile int Warm = 0;
    public static bool Apply(int warm) {
        Warm = Math.Max(0, Math.Min(100, warm));
        double t = Warm / 100.0, g = 1 - 0.18 * t, b = 1 - 0.42 * t;
        ushort[] ramp = new ushort[768];
        for (int i = 0; i < 256; i++) {
            ramp[i] = (ushort)Math.Min(65535, i * 256);
            ramp[256 + i] = (ushort)Math.Min(65535, i * 256 * g);
            ramp[512 + i] = (ushort)Math.Min(65535, i * 256 * b);
        }
        IntPtr dc = GetDC(IntPtr.Zero);
        bool ok = SetDeviceGammaRamp(dc, ramp);
        ReleaseDC(IntPtr.Zero, dc);
        return ok;
    }
}

// ------------------------------------------------------------------ typing text into the previous window (emoji picker)
public static class Typer {
    [StructLayout(LayoutKind.Sequential)] struct KI { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public KI ki; public long pad; }
    [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    public static IntPtr Target = IntPtr.Zero;
    public static void Remember() { Target = ValoUi.GetForegroundWindow(); }
    public static void Type(string text) {
        if (Target != IntPtr.Zero) { ValoUi.keybd_event(0x12, 0, 0, UIntPtr.Zero); ValoUi.keybd_event(0x12, 0, 2, UIntPtr.Zero); ValoUi.SetForegroundWindow(Target); }
        Thread.Sleep(60);
        List<INPUT> l = new List<INPUT>();
        foreach (char c in text) {
            INPUT d = new INPUT(); d.type = 1; d.ki.scan = c; d.ki.flags = 4; l.Add(d);           // KEYEVENTF_UNICODE
            INPUT u = new INPUT(); u.type = 1; u.ki.scan = c; u.ki.flags = 4 | 2; l.Add(u);
        }
        SendInput((uint)l.Count, l.ToArray(), Marshal.SizeOf(typeof(INPUT)));
    }
}

// ------------------------------------------------------------------ watcher: hot corners, game mode, idle, virtual desktops
public static class ValoWatch {
    [StructLayout(LayoutKind.Sequential)] struct PT { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct RC { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct MI { public int cb; public RC mon, work; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] struct LII { public uint cb, time; }
    [DllImport("user32.dll")] static extern bool GetCursorPos(out PT p);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr h, uint f);
    [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr m, ref MI i);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RC r);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LII i);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);

    public static string[] Corners = { "menu", "none", "none", "desktop" };   // top-left, top-right, bottom-left, bottom-right
    public static volatile bool GameAuto = true;
    public static volatile int SaverMin = 0;                              // 0 = screensaver off
    public static volatile bool Game = false, Idle = false;
    public static int MicLast = -2; static int micTick = 0;
    static int lastDeskN = -1, lastDeskCur = -1;

    public static void Start() {
        Thread t = new Thread(Loop); t.IsBackground = true; t.Start();
    }
    static void Key(byte vk, bool up) { ValoUi.keybd_event(vk, 0, up ? 2u : 0u, UIntPtr.Zero); }
    static void Fire(string a) {
        if (a == "menu") Emit.Line("{\"type\":\"win\"}");
        else if (a == "cc") Emit.Line("{\"type\":\"cc\"}");
        else if (a == "desktop") { Key(0x5B, false); Key(0x44, false); Key(0x44, true); Key(0x5B, true); }
        else if (a == "taskview") { Key(0x5B, false); Key(0x09, false); Key(0x09, true); Key(0x5B, true); }
    }
    static void Loop() {
        int corner = -2; long cornerSince = 0; bool fired = true; long slow = 0;   // a cursor already parked in a corner at start does not count
        while (true) {
            Thread.Sleep(60);
            try {
                long now = Environment.TickCount;
                // ---- hot corners
                PT p; GetCursorPos(out p);
                int cx = GetSystemMetrics(0), cy = GetSystemMetrics(1);
                int c = -1;
                if (p.x <= 1 && p.y <= 1) c = 0; else if (p.x >= cx - 2 && p.y <= 1) c = 1;
                else if (p.x <= 1 && p.y >= cy - 2) c = 2; else if (p.x >= cx - 2 && p.y >= cy - 2) c = 3;
                bool buttons = (GetAsyncKeyState(0x01) & 0x8000) != 0 || (GetAsyncKeyState(0x02) & 0x8000) != 0;
                if (corner == -2) { corner = c; }
                else if (c != corner) { corner = c; cornerSince = now; fired = false; }
                else if (c >= 0 && !fired && !buttons && !Game && now - cornerSince > 220) {
                    fired = true;
                    StringBuilder fc = new StringBuilder(64); GetClassName(ValoUi.GetForegroundWindow(), fc, 64);
                    string a = Corners[c];
                    if (a != "none" && fc.ToString() != "Windows.UI.Core.CoreWindow") Fire(a);   // not on the lock screen / Start
                }

                if (now - slow < 1000) continue;
                slow = now;
                // ---- game mode: a borderless window covering its whole monitor
                bool g = false;
                if (GameAuto) {
                    IntPtr fg = ValoUi.GetForegroundWindow();
                    StringBuilder cls = new StringBuilder(128); GetClassName(fg, cls, 128);
                    string cn = cls.ToString();
                    if (fg != IntPtr.Zero && cn != "Progman" && cn != "WorkerW" && cn != "Shell_TrayWnd" && cn != "Tauri Window" && cn != "Windows.UI.Core.CoreWindow" && cn != "LockScreenControllerProxyWindow" && !cn.StartsWith("WindowsForms")) {   // CoreWindow = lock screen, Start, search
                        RC r; MI mi = new MI(); mi.cb = Marshal.SizeOf(typeof(MI));
                        if (GetWindowRect(fg, out r) && GetMonitorInfo(MonitorFromWindow(fg, 2), ref mi)) {
                            bool covers = r.l <= mi.mon.l && r.t <= mi.mon.t && r.r >= mi.mon.r && r.b >= mi.mon.b;
                            bool caption = (GetWindowLong(fg, -16) & 0x00C00000) == 0x00C00000;
                            uint pid; GetWindowThreadProcessId(fg, out pid);
                            g = covers && !caption && pid != (uint)System.Diagnostics.Process.GetCurrentProcess().Id;
                        }
                    }
                }
                if (g != Game) { Game = g; Emit.Line("{\"type\":\"game\",\"on\":" + (g ? "true" : "false") + "}"); }
                // ---- microphone muted / unmuted elsewhere (Windows settings, a headset button) -> the bar's indicator
                if (++micTick % 3 == 0) { int ms = AudioMix.MicMuteState(); if (ms != MicLast) { MicLast = ms; Emit.Line(AudioMix.MicList()); } }
                // ---- idle -> screensaver
                LII li = new LII(); li.cb = (uint)Marshal.SizeOf(typeof(LII)); GetLastInputInfo(ref li);
                long idleMs = (uint)Environment.TickCount - li.time;
                bool idle = SaverMin > 0 && !Game && idleMs > SaverMin * 60000L;
                if (Idle && idleMs < 1500) idle = false;
                if (idle != Idle) { Idle = idle; Emit.Line("{\"type\":\"idle\",\"on\":" + (idle ? "true" : "false") + "}"); }
                // ---- virtual desktops (registry; Windows 11 layout, Windows 10 fallback)
                int n, cur; Desks(out n, out cur);
                if (n != lastDeskN || cur != lastDeskCur) { lastDeskN = n; lastDeskCur = cur; Emit.Line("{\"type\":\"desks\",\"n\":" + n + ",\"cur\":" + cur + "}"); }
            } catch { }
        }
    }
    public static void Desks(out int n, out int cur) {
        n = 1; cur = 0;
        try {
            using (Microsoft.Win32.RegistryKey k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops")) {
                if (k == null) return;
                byte[] ids = k.GetValue("VirtualDesktopIDs") as byte[];
                byte[] c = k.GetValue("CurrentVirtualDesktop") as byte[];
                if (ids == null || ids.Length < 16) return;
                n = ids.Length / 16;
                if (c != null && c.Length == 16)
                    for (int i = 0; i < n; i++) { bool eq = true; for (int j = 0; j < 16; j++) if (ids[i * 16 + j] != c[j]) { eq = false; break; } if (eq) { cur = i; break; } }
            }
        } catch { }
    }
    public static void GoDesk(int target) {
        int n, cur; Desks(out n, out cur);
        if (target < 0 || target >= n || target == cur) return;
        byte arrow = target > cur ? (byte)0x27 : (byte)0x25;
        for (int i = 0; i < Math.Abs(target - cur); i++) {
            Key(0x5B, false); Key(0x11, false); Key(arrow, false); Key(arrow, true); Key(0x11, true); Key(0x5B, true);
            Thread.Sleep(120);
        }
    }
    public static void NewDesk() { Key(0x5B, false); Key(0x11, false); Key(0x44, false); Key(0x44, true); Key(0x11, true); Key(0x5B, true); }
}

// ------------------------------------------------------------------ window zones (hold Shift while dragging a window)
public class ZoneForm : WF.Form {
    delegate void WinEventProc(IntPtr hook, uint ev, IntPtr h, int obj, int child, uint thread, uint time);
    [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr mod, WinEventProc fn, uint pid, uint tid, uint flags);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out R4 r);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll")] static extern bool IsZoomed(IntPtr h);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int a, out R4 r, int s);
    [StructLayout(LayoutKind.Sequential)] struct R4 { public int l, t, r, b; }

    public static ZoneForm Inst;
    public static volatile string ZoneLayout = "halves";       // halves | thirds | grid | main | off
    WinEventProc proc;
    IntPtr moving = IntPtr.Zero;
    List<SD.Rectangle> zones = new List<SD.Rectangle>();
    int hot = -1;
    WF.Timer timer = new WF.Timer();

    public ZoneForm() {
        FormBorderStyle = WF.FormBorderStyle.None; ShowInTaskbar = false; StartPosition = WF.FormStartPosition.Manual;
        AutoScaleMode = WF.AutoScaleMode.None; DoubleBuffered = true; Text = ""; Opacity = 0.9;
        BackColor = SD.Color.Magenta; TransparencyKey = SD.Color.Magenta;
        Bounds = new SD.Rectangle(-4000, -4000, 10, 10);
        timer.Interval = 30; timer.Tick += delegate { Track(); };
        proc = OnEvent;
        SetWinEventHook(0x000A, 0x000B, IntPtr.Zero, proc, 0, 0, 0);   // EVENT_SYSTEM_MOVESIZESTART / END, out of context
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override WF.CreateParams CreateParams { get { WF.CreateParams p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x80 | 0x8 | 0x20 | 0x80000; return p; } }

    void OnEvent(IntPtr hook, uint ev, IntPtr h, int obj, int child, uint thread, uint time) {
        if (obj != 0 || ZoneLayout == "off") return;
        if (ev == 0x000A) { moving = h; hot = -1; timer.Start(); }
        else if (ev == 0x000B) {
            timer.Stop();
            bool shift = (GetAsyncKeyState(0x10) & 0x8000) != 0;
            IntPtr w = moving; moving = IntPtr.Zero;
            int z = hot; Hide();
            if (shift && z >= 0 && z < zones.Count && w != IntPtr.Zero) Snap(w, zones[z]);
        }
    }
    void Build() {
        WF.Screen scr = WF.Screen.FromPoint(WF.Cursor.Position);
        SD.Rectangle a = scr.WorkingArea; int g = 8;
        zones.Clear();
        if (ZoneLayout == "thirds") for (int i = 0; i < 3; i++) zones.Add(new SD.Rectangle(a.Left + i * a.Width / 3, a.Top, a.Width / 3, a.Height));
        else if (ZoneLayout == "grid") for (int i = 0; i < 4; i++) zones.Add(new SD.Rectangle(a.Left + (i % 2) * a.Width / 2, a.Top + (i / 2) * a.Height / 2, a.Width / 2, a.Height / 2));
        else if (ZoneLayout == "main") { int w = a.Width * 3 / 5; zones.Add(new SD.Rectangle(a.Left, a.Top, w, a.Height)); zones.Add(new SD.Rectangle(a.Left + w, a.Top, a.Width - w, a.Height / 2)); zones.Add(new SD.Rectangle(a.Left + w, a.Top + a.Height / 2, a.Width - w, a.Height - a.Height / 2)); }
        else { zones.Add(new SD.Rectangle(a.Left, a.Top, a.Width / 2, a.Height)); zones.Add(new SD.Rectangle(a.Left + a.Width / 2, a.Top, a.Width - a.Width / 2, a.Height)); }
        for (int i = 0; i < zones.Count; i++) zones[i] = SD.Rectangle.Inflate(zones[i], -g / 2, -g / 2);
        Bounds = a;
    }
    void Track() {
        if (moving == IntPtr.Zero) { timer.Stop(); Hide(); return; }
        bool shift = (GetAsyncKeyState(0x10) & 0x8000) != 0;
        if (!shift) { if (Visible) Hide(); hot = -1; return; }
        if (!Visible) { Build(); Show(); ValoUi.SetWindowPos(Handle, new IntPtr(-1), 0, 0, 0, 0, 0x13); }
        SD.Point c = WF.Cursor.Position; int h = -1;
        for (int i = 0; i < zones.Count; i++) if (zones[i].Contains(c)) h = i;
        if (h != hot) { hot = h; Invalidate(); }
    }
    protected override void OnPaint(WF.PaintEventArgs e) {
        SD.Graphics gr = e.Graphics; gr.Clear(SD.Color.Magenta);
        for (int i = 0; i < zones.Count; i++) {
            SD.Rectangle r = zones[i]; r.Offset(-Left, -Top);
            using (SD.SolidBrush b = new SD.SolidBrush(i == hot ? ValoUi.Mix(ValoUi.Bg, ValoUi.Accent, .45f) : ValoUi.Mix(ValoUi.Bg, ValoUi.Fg, .06f))) gr.FillRectangle(b, r);
            using (SD.Pen p = new SD.Pen(i == hot ? ValoUi.Accent : ValoUi.Muted, 3)) gr.DrawRectangle(p, r.X + 1, r.Y + 1, r.Width - 3, r.Height - 3);
        }
    }
    static void Snap(IntPtr h, SD.Rectangle z) {
        if (IsZoomed(h)) ShowWindow(h, 9);
        R4 wr, fr; GetWindowRect(h, out wr);
        int bl = 0, bt = 0, br = 0, bb = 0;
        if (DwmGetWindowAttribute(h, 9, out fr, Marshal.SizeOf(typeof(R4))) == 0) { bl = fr.l - wr.l; bt = fr.t - wr.t; br = wr.r - fr.r; bb = wr.b - fr.b; }
        ValoUi.SetWindowPos(h, IntPtr.Zero, z.Left - bl, z.Top - bt, z.Width + bl + br, z.Height + bt + bb, 0x0014);
    }
}

// ------------------------------------------------------------------ Bluetooth device battery levels (SetupAPI, fast)
public static class BtBattery {
    [StructLayout(LayoutKind.Sequential)] struct DEVINFO { public int cbSize; public Guid cls; public uint inst; public IntPtr reserved; }
    [StructLayout(LayoutKind.Sequential)] struct DEVPROPKEY { public Guid fmtid; public uint pid; }
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode)] static extern IntPtr SetupDiGetClassDevs(IntPtr cls, string enumerator, IntPtr parent, uint flags);
    [DllImport("setupapi.dll")] static extern bool SetupDiEnumDeviceInfo(IntPtr set, uint i, ref DEVINFO d);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode)] static extern bool SetupDiGetDevicePropertyW(IntPtr set, ref DEVINFO d, ref DEVPROPKEY k, out uint type, byte[] buf, uint size, out uint req, uint flags);
    [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    static byte[] Prop(IntPtr set, ref DEVINFO d, Guid g, uint pid) {
        DEVPROPKEY k = new DEVPROPKEY(); k.fmtid = g; k.pid = pid; uint t, req;
        byte[] buf = new byte[512];
        return SetupDiGetDevicePropertyW(set, ref d, ref k, out t, buf, (uint)buf.Length, out req, 0) ? buf : null;
    }
    public static string List() {
        StringBuilder b = new StringBuilder("{\"type\":\"bt\",\"list\":[");
        Dictionary<string, int> seen = new Dictionary<string, int>();
        foreach (string en in new string[] { "BTHENUM", "BTHLE", "BTHLEDevice" }) {
            IntPtr set = SetupDiGetClassDevs(IntPtr.Zero, en, IntPtr.Zero, 0x2 | 0x4);   // PRESENT | ALLCLASSES
            if (set == new IntPtr(-1)) continue;
            DEVINFO d = new DEVINFO(); d.cbSize = Marshal.SizeOf(typeof(DEVINFO));
            for (uint i = 0; SetupDiEnumDeviceInfo(set, i, ref d); i++) {
                byte[] bat = Prop(set, ref d, new Guid("104EA319-6EE2-4701-BD47-8DDBF425BBE5"), 2);
                if (bat == null) continue;
                byte[] nm = Prop(set, ref d, new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"), 14);   // DEVPKEY_Device_FriendlyName
                string name = nm != null ? Encoding.Unicode.GetString(nm).Split('\0')[0] : "Bluetooth";
                if (!seen.ContainsKey(name)) seen[name] = bat[0];
            }
            SetupDiDestroyDeviceInfoList(set);
        }
        bool first = true;
        foreach (KeyValuePair<string, int> kv in seen) { if (!first) b.Append(','); first = false; b.Append("{\"name\":").Append(Emit.Q(kv.Key)).Append(",\"pct\":").Append(kv.Value).Append('}'); }
        return b.Append("]}").ToString();
    }
}

// ---- gamepad: the Xbox button, or View + Menu held together, opens / closes the valo console (Feat.ConsoleOn)
public static class PadWatch {
    [StructLayout(LayoutKind.Sequential)] struct XState { public uint packet; public ushort buttons; public byte lt, rt; public short lx, ly, rx, ry; }
    [DllImport("xinput1_4.dll", EntryPoint = "#100")] static extern uint GetStateEx(uint i, ref XState s);   // also reports the Xbox (guide) button
    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState")] static extern uint GetState(uint i, ref XState s);
    public static void Start() { Thread t = new Thread(Loop); t.IsBackground = true; t.Start(); }
    static void Loop() {
        bool[] connected = new bool[4]; long[] nextProbe = new long[4]; ushort[] last = new ushort[4]; long comboSince = 0; bool comboFired = false, ex = true;
        while (true) {
            Thread.Sleep(50);
            try {
                if (!Feat.ConsoleOn) { Thread.Sleep(1000); continue; }
                long now = Environment.TickCount; bool combo = false;
                for (uint i = 0; i < 4; i++) {
                    if (!connected[i] && now < nextProbe[i]) continue;      // probing an empty slot is slow: once every 2 s
                    XState s = new XState(); uint r;
                    if (ex) { try { r = GetStateEx(i, ref s); } catch (EntryPointNotFoundException) { ex = false; r = GetState(i, ref s); } } else r = GetState(i, ref s);
                    connected[i] = r == 0;
                    if (r != 0) { nextProbe[i] = now + 2000; last[i] = 0; continue; }
                    ushort b = s.buttons;
                    if ((b & 0x0400) != 0 && (last[i] & 0x0400) == 0 && !ValoWatch.Game) Emit.Line("{\"type\":\"console\"}");
                    if ((b & 0x0030) == 0x0030) combo = true;              // View (Back) + Menu (Start)
                    last[i] = b;
                }
                if (!combo) { comboSince = 0; comboFired = false; }
                else if (comboSince == 0) comboSince = now;
                else if (!comboFired && now - comboSince > 500 && !ValoWatch.Game) { comboFired = true; Emit.Line("{\"type\":\"console\"}"); }
            } catch { Thread.Sleep(2000); }
        }
    }
}
