// valo.os helper, part 3 (compiled with valo-shell.ps1 + valo-ui.cs + valo-ui2.cs). Every feature here can be switched off.
//   Feat         - on/off flags (command: feat2 lang=1 privacy=1 net=0 ocr=1 tr=1 rec=1 dlsort=0 dlclean=0 console=1)
//   Watch3       - keyboard layout of the active window, microphone / camera / location in use, network speed
//   Ocr          - Win+Shift+T: select an area -> text (Windows OCR, offline) -> clipboard
//   Translate    - Win+Shift+Y: translate the selected text (MyMemory) in a small window
//   Recorder     - Win+Shift+R: record an area / the screen with FFmpeg (mp4 or gif); without FFmpeg Windows' own tool opens
//   Downloads    - sorts Downloads into folders, optional: old installers to the recycle bin
//   Backup       - daily copy of chosen folders to a drive (robocopy, nothing is deleted at the target)

public static class Feat {
    public static volatile bool Lang = true, Privacy = true, Net = false, Ocr = true, Tr = true, Rec = true, DlSort = false, DlClean = false, ConsoleOn = true;
    public static volatile string TrTarget = "en", RecFormat = "mp4";
    public static void Set(string s) {
        Lang = !s.Contains("lang=0"); Privacy = !s.Contains("privacy=0"); Net = s.Contains("net=1"); Ocr = !s.Contains("ocr=0");
        Tr = !s.Contains("tr=0"); Rec = !s.Contains("rec=0"); DlSort = s.Contains("dlsort=1"); DlClean = s.Contains("dlclean=1"); ConsoleOn = !s.Contains("console=0");
        Downloads.Apply();
    }
    public static string Pack = "";
    public static string Ps { get { return Environment.ExpandEnvironmentVariables(@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"); } }
}

// ------------------------------------------------------------------ layout, privacy, network
public static class Watch3 {
    [DllImport("user32.dll")] static extern IntPtr GetKeyboardLayout(uint thread);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    static IntPtr lastApp = IntPtr.Zero;
    static string lastLang = "", lastPriv = "";
    static long rx0 = -1, tx0 = -1;

    public static void Start() { Thread t = new Thread(Loop); t.IsBackground = true; t.Start(); }
    static string Short(int langId) {
        try {
            string n = new System.Globalization.CultureInfo(langId & 0xFFFF).TwoLetterISOLanguageName.ToUpperInvariant();
            if (n == "UK") return "UA"; if (n == "EN") return "EN"; return n;
        } catch { return "??"; }
    }
    static IntPtr AppWindow() {
        IntPtr fg = ValoUi.GetForegroundWindow();
        StringBuilder c = new StringBuilder(64); GetClassName(fg, c, 64);
        string cn = c.ToString();
        if (fg != IntPtr.Zero && cn != "Tauri Window" && !cn.StartsWith("WindowsForms") && cn != "Shell_TrayWnd") lastApp = fg;
        return lastApp;
    }
    public static void NextLang() {
        IntPtr h = AppWindow(); if (h == IntPtr.Zero) return;
        PostMessage(h, 0x0050, new IntPtr(2), new IntPtr(1));     // WM_INPUTLANGCHANGEREQUEST, forward, HKL_NEXT
        ValoUi.SetForegroundWindow(h);
    }
    static void Loop() {
        int tick = 0;
        while (true) {
            Thread.Sleep(300); tick++;
            try {
                if (Feat.Lang) {
                    uint pid; IntPtr h = AppWindow();
                    uint th = h == IntPtr.Zero ? 0 : GetWindowThreadProcessId(h, out pid);
                    string l = Short(GetKeyboardLayout(th).ToInt32());
                    if (l != lastLang) { lastLang = l; Emit.Line("{\"type\":\"lang\",\"code\":" + Emit.Q(l) + "}"); }
                }
                if (tick % 7 == 0 && Feat.Privacy) {
                    string p = "{\"type\":\"privacy\",\"mic\":" + InUse("microphone") + ",\"cam\":" + InUse("webcam") + ",\"loc\":" + InUse("location") + "}";
                    if (p != lastPriv) { lastPriv = p; Emit.Line(p); }
                }
                if (tick % 3 == 0 && Feat.Net) {
                    long rx = 0, tx = 0;
                    foreach (System.Net.NetworkInformation.NetworkInterface n in System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces()) {
                        if (n.OperationalStatus != System.Net.NetworkInformation.OperationalStatus.Up) continue;
                        if (n.NetworkInterfaceType == System.Net.NetworkInformation.NetworkInterfaceType.Loopback || n.NetworkInterfaceType == System.Net.NetworkInformation.NetworkInterfaceType.Tunnel) continue;
                        System.Net.NetworkInformation.IPInterfaceStatistics s = n.GetIPStatistics(); rx += s.BytesReceived; tx += s.BytesSent;
                    }
                    if (rx0 >= 0) Emit.Line("{\"type\":\"net\",\"down\":" + Math.Max(0, (rx - rx0) * 10 / 9) + ",\"up\":" + Math.Max(0, (tx - tx0) * 10 / 9) + ",\"rx\":" + rx + ",\"tx\":" + tx + "}");
                    rx0 = rx; tx0 = tx;
                }
            } catch { }
        }
    }
    // CapabilityAccessManager: an app is using the device while LastUsedTimeStop == 0
    static string InUse(string cap) {
        List<string> apps = new List<string>();
        try {
            using (Microsoft.Win32.RegistryKey root = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\" + cap)) {
                if (root == null) return "[]";
                foreach (string sub in root.GetSubKeyNames()) {
                    if (sub == "NonPackaged") {
                        using (Microsoft.Win32.RegistryKey np = root.OpenSubKey(sub)) foreach (string a in np.GetSubKeyNames()) using (Microsoft.Win32.RegistryKey k = np.OpenSubKey(a)) if (Active(k)) apps.Add(System.IO.Path.GetFileNameWithoutExtension(a.Replace('#', '\\')));
                    } else using (Microsoft.Win32.RegistryKey k = root.OpenSubKey(sub)) if (Active(k)) apps.Add(sub.Split('_')[0].Split('.').Length > 1 ? sub.Split('_')[0].Split('.')[1] : sub);
                }
            }
        } catch { }
        StringBuilder b = new StringBuilder("[");
        for (int i = 0; i < apps.Count; i++) { if (i > 0) b.Append(','); b.Append(Emit.Q(apps[i])); }
        return b.Append(']').ToString();
    }
    static bool Active(Microsoft.Win32.RegistryKey k) {
        if (k == null) return false;
        object s = k.GetValue("LastUsedTimeStart"), e = k.GetValue("LastUsedTimeStop");
        return s is long && (long)s > 0 && e is long && (long)e == 0;
    }
}

// ------------------------------------------------------------------ small text popup (OCR result, translation, recording notices)
public class TextToast : WF.Form {
    static TextToast inst;
    string head = "", body = "", foot = "";
    WF.Timer timer = new WF.Timer();
    float s = 1f;
    SD.Font f1 = new SD.Font("Segoe UI", 9f), f2 = new SD.Font("Segoe UI", 11f);
    public Action ClickAction;
    public TextToast() {
        FormBorderStyle = WF.FormBorderStyle.None; ShowInTaskbar = false; StartPosition = WF.FormStartPosition.Manual;
        AutoScaleMode = WF.AutoScaleMode.None; DoubleBuffered = true; Cursor = WF.Cursors.Hand; Text = "";
        timer.Tick += delegate { timer.Stop(); Hide(); };
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override WF.CreateParams CreateParams { get { WF.CreateParams p = base.CreateParams; p.ExStyle |= 0x08000088; return p; } }
    int S(float v) { return (int)Math.Round(v * s); }
    public static void Show_(string head, string body, string foot, int ms, Action click) {
        if (inst == null) inst = new TextToast();
        inst.head = head; inst.body = body.Length > 600 ? body.Substring(0, 600) + "…" : body; inst.foot = foot; inst.ClickAction = click;
        inst.s = ValoUi.Scale(inst);
        WF.Screen scr = WF.Screen.PrimaryScreen;
        int W = inst.S(380);
        SD.Size bs = WF.TextRenderer.MeasureText(inst.body, inst.f2, new SD.Size(W - inst.S(28), 2000), WF.TextFormatFlags.WordBreak);
        int H = Math.Min(inst.S(420), bs.Height + inst.S(78));
        inst.Bounds = new SD.Rectangle(scr.WorkingArea.Right - W - inst.S(16), scr.WorkingArea.Bottom - H - inst.S(16), W, H);
        inst.BackColor = ValoUi.Bg; ValoUi.Style(inst);
        inst.Show(); ValoUi.SetWindowPos(inst.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x13);
        inst.Invalidate(); inst.timer.Stop(); inst.timer.Interval = ms; inst.timer.Start();
    }
    protected override void OnPaint(WF.PaintEventArgs e) {
        SD.Graphics g = e.Graphics; g.Clear(ValoUi.Bg);
        WF.TextRenderer.DrawText(g, head, f1, new SD.Rectangle(S(14), S(10), Width - S(28), S(18)), ValoUi.Accent, WF.TextFormatFlags.Left);
        WF.TextRenderer.DrawText(g, body, f2, new SD.Rectangle(S(14), S(32), Width - S(28), Height - S(62)), ValoUi.Fg, WF.TextFormatFlags.WordBreak | WF.TextFormatFlags.EndEllipsis | WF.TextFormatFlags.NoPrefix);
        WF.TextRenderer.DrawText(g, foot, f1, new SD.Rectangle(S(14), Height - S(26), Width - S(28), S(18)), ValoUi.Muted, WF.TextFormatFlags.Left);
    }
    protected override void OnMouseUp(WF.MouseEventArgs e) { timer.Stop(); Hide(); if (e.Button == WF.MouseButtons.Left && ClickAction != null) ClickAction(); }
}

// ------------------------------------------------------------------ OCR (uses ShotForm area selection)
public static class Ocr {
    public static void Run(SD.Bitmap crop) {
        string tmp = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "valo-ocr.png");
        try { crop.Save(tmp, SD.Imaging.ImageFormat.Png); } catch { return; }
        Thread t = new Thread(delegate () {
            string text = Shell(System.IO.Path.Combine(Feat.Pack, "valo-ocr.ps1"), "-Path \"" + tmp + "\"");
            ValoUi.Post(delegate {
                if (string.IsNullOrEmpty(text) || text.StartsWith("ERROR")) { TextToast.Show_("Текст з екрана", "Тексту не знайдено.", "для кирилиці додайте українську мову розпізнавання в налаштуваннях Windows", 5000, null); return; }
                try { WF.Clipboard.SetText(text); } catch { }
                TextToast.Show_("Текст з екрана · скопійовано", text, "клік — закрити", 6000, null);
            });
        });
        t.IsBackground = true; t.Start();
    }
    public static string Shell(string script, string args) {
        try {
            System.Diagnostics.ProcessStartInfo p = new System.Diagnostics.ProcessStartInfo(Feat.Ps, "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" " + args);
            p.UseShellExecute = false; p.CreateNoWindow = true; p.RedirectStandardOutput = true; p.StandardOutputEncoding = Encoding.UTF8;
            using (System.Diagnostics.Process pr = System.Diagnostics.Process.Start(p)) { string o = pr.StandardOutput.ReadToEnd(); pr.WaitForExit(30000); return o.Trim(); }
        } catch { return null; }
    }
}

// ------------------------------------------------------------------ translate the selection
public static class Translate {
    public static void Run() {
        IntPtr target = ValoUi.GetForegroundWindow();
        string before = null;
        ValoUi.Post(delegate { try { if (WF.Clipboard.ContainsText()) before = WF.Clipboard.GetText(); WF.Clipboard.Clear(); } catch { } });
        Thread.Sleep(80);
        ValoUi.keybd_event(0x10, 0, 2, UIntPtr.Zero); ValoUi.keybd_event(0x5B, 0, 2, UIntPtr.Zero);   // release Shift / Win first
        ValoUi.keybd_event(0x11, 0, 0, UIntPtr.Zero); ValoUi.keybd_event(0x43, 0, 0, UIntPtr.Zero); ValoUi.keybd_event(0x43, 0, 2, UIntPtr.Zero); ValoUi.keybd_event(0x11, 0, 2, UIntPtr.Zero);
        Thread.Sleep(250);
        string text = null;
        ValoUi.Post(delegate { try { if (WF.Clipboard.ContainsText()) text = WF.Clipboard.GetText(); if (before != null) WF.Clipboard.SetText(before); } catch { } });
        Thread.Sleep(150);
        if (string.IsNullOrEmpty(text) || text.Trim().Length == 0) { ValoUi.Post(delegate { TextToast.Show_("Переклад", "Спершу виділіть текст, потім Win+Shift+Y.", "", 3500, null); }); return; }
        text = text.Trim(); if (text.Length > 480) text = text.Substring(0, 480);
        string src = System.Text.RegularExpressions.Regex.IsMatch(text, "[А-Яа-яІіЇїЄєҐґ]") ? "uk" : System.Text.RegularExpressions.Regex.IsMatch(text, "[ăâîșțĂÂÎȘȚşţ]") ? "ro" : "en";
        string dst = src == "uk" ? Feat.TrTarget : "uk";
        if (dst == src) dst = src == "en" ? "uk" : "en";
        string result = null;
        try {
            System.Net.ServicePointManager.SecurityProtocol = System.Net.SecurityProtocolType.Tls12;
            using (System.Net.WebClient wc = new System.Net.WebClient()) {
                wc.Encoding = Encoding.UTF8; wc.Headers.Add("User-Agent", "valo-os");
                string json = wc.DownloadString("https://api.mymemory.translated.net/get?langpair=" + src + "|" + dst + "&q=" + Uri.EscapeDataString(text));
                System.Text.RegularExpressions.Match m = System.Text.RegularExpressions.Regex.Match(json, "\"translatedText\":\"((?:[^\"\\\\]|\\\\.)*)\"");
                if (m.Success) result = System.Text.RegularExpressions.Regex.Unescape(m.Groups[1].Value);
            }
        } catch { }
        string r = result;
        ValoUi.Post(delegate {
            if (r == null) { TextToast.Show_("Переклад", "Не вдалося перекласти (немає інтернету?)", "", 3500, null); return; }
            TextToast.Show_("Переклад " + src.ToUpper() + " → " + dst.ToUpper(), r, "клік — скопіювати переклад", 12000, delegate { try { WF.Clipboard.SetText(r); } catch { } });
        });
    }
}

// ------------------------------------------------------------------ screen recording (FFmpeg)
public static class Recorder {
    public static System.Diagnostics.Process P;
    static string file, mp4; static DateTime started;
    public static bool Busy { get { return P != null && !P.HasExited; } }
    public static string FFmpeg() {
        string[] c = { System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\WinGet\Links\ffmpeg.exe"), @"C:\ffmpeg\bin\ffmpeg.exe" };
        foreach (string x in c) if (System.IO.File.Exists(x)) return x;
        foreach (string d in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';')) { try { string x = System.IO.Path.Combine(d.Trim(), "ffmpeg.exe"); if (System.IO.File.Exists(x)) return x; } catch { } }
        return null;
    }
    public static void Start(SD.Rectangle r) {
        string ff = FFmpeg(); if (ff == null) return;
        string dir = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyVideos), "Записи екрана"); System.IO.Directory.CreateDirectory(dir);
        string stamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
        mp4 = System.IO.Path.Combine(dir, "valo-" + stamp + ".mp4");
        file = Feat.RecFormat == "gif" ? System.IO.Path.Combine(dir, "valo-" + stamp + ".gif") : mp4;
        int w = r.Width & ~1, h = r.Height & ~1;
        System.Diagnostics.ProcessStartInfo p = new System.Diagnostics.ProcessStartInfo(ff,
            "-hide_banner -loglevel error -f gdigrab -framerate 30 -offset_x " + r.X + " -offset_y " + r.Y + " -video_size " + w + "x" + h +
            " -draw_mouse 1 -i desktop -c:v libx264 -preset ultrafast -pix_fmt yuv420p -crf 23 \"" + mp4 + "\"");
        p.UseShellExecute = false; p.CreateNoWindow = true; p.RedirectStandardInput = true;
        try { P = System.Diagnostics.Process.Start(p); started = DateTime.Now; Emit.Line("{\"type\":\"rec\",\"on\":true}"); }
        catch (Exception e) { ValoUi.Post(delegate { TextToast.Show_("Запис екрана", "FFmpeg не запустився: " + e.Message, "", 5000, null); }); }
    }
    public static void Stop() {
        if (!Busy) return;
        try { P.StandardInput.Write("q"); P.StandardInput.Flush(); } catch { }
        System.Diagnostics.Process pr = P;
        Thread t = new Thread(delegate () {
            pr.WaitForExit(15000); P = null;
            Emit.Line("{\"type\":\"rec\",\"on\":false}");
            if (file != mp4) {
                string ff = FFmpeg();
                System.Diagnostics.ProcessStartInfo g = new System.Diagnostics.ProcessStartInfo(ff, "-hide_banner -loglevel error -y -i \"" + mp4 + "\" -vf \"fps=12,scale='min(960,iw)':-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse\" \"" + file + "\"");
                g.UseShellExecute = false; g.CreateNoWindow = true;
                try { using (System.Diagnostics.Process gp = System.Diagnostics.Process.Start(g)) gp.WaitForExit(120000); System.IO.File.Delete(mp4); } catch { }
            }
            string f = file; TimeSpan len = DateTime.Now - started;
            ValoUi.Post(delegate { TextToast.Show_("Запис збережено", System.IO.Path.GetFileName(f) + " · " + ((int)len.TotalMinutes) + ":" + len.Seconds.ToString("00"), "клік — показати в папці", 7000,
                delegate { try { System.Diagnostics.Process.Start("explorer.exe", "/select,\"" + f + "\""); } catch { } }); });
        });
        t.IsBackground = true; t.Start();
    }
}

// ------------------------------------------------------------------ Downloads: sort into folders
public static class Downloads {
    static System.IO.FileSystemWatcher fw;
    static readonly object lk = new object();
    static Dictionary<string, string[]> Cats = new Dictionary<string, string[]> {
        { "Фото", new string[] { ".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".bmp", ".svg", ".tif", ".tiff", ".raw" } },
        { "Документи", new string[] { ".pdf", ".doc", ".docx", ".odt", ".rtf", ".txt", ".md", ".xls", ".xlsx", ".ods", ".csv", ".ppt", ".pptx", ".odp", ".epub" } },
        { "Архіви", new string[] { ".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".iso" } },
        { "Інсталятори", new string[] { ".exe", ".msi", ".msix", ".msixbundle", ".appx", ".apk" } },
        { "Відео", new string[] { ".mp4", ".mkv", ".avi", ".mov", ".webm", ".wmv" } },
        { "Музика", new string[] { ".mp3", ".flac", ".wav", ".ogg", ".m4a", ".aac" } },
        { "Код", new string[] { ".js", ".ts", ".py", ".cs", ".json", ".html", ".css", ".ps1", ".kt", ".java", ".zipx" } } };
    static string skip = ".crdownload .part .tmp .download .partial .opdownload .!ut";
    static string Dir() {
        Guid g = new Guid("374DE290-123F-4565-9164-39C4925E467B"); IntPtr p;
        if (SHGetKnownFolderPath(ref g, 0, IntPtr.Zero, out p) == 0) { string s = Marshal.PtrToStringUni(p); Marshal.FreeCoTaskMem(p); return s; }
        return System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
    }
    [DllImport("shell32.dll")] static extern int SHGetKnownFolderPath(ref Guid id, uint flags, IntPtr token, out IntPtr path);
    public static void Apply() {
        lock (lk) {
            if (Feat.DlSort && fw == null) {
                try {
                    fw = new System.IO.FileSystemWatcher(Dir()); fw.IncludeSubdirectories = false;
                    fw.Created += delegate { Later(); }; fw.Renamed += delegate { Later(); }; fw.EnableRaisingEvents = true;
                    Later();
                } catch { fw = null; }
            } else if (!Feat.DlSort && fw != null) { fw.EnableRaisingEvents = false; fw.Dispose(); fw = null; }
        }
    }
    static System.Threading.Timer pending;
    static void Later() { lock (lk) { if (pending != null) pending.Dispose(); pending = new System.Threading.Timer(delegate { SortNow(); }, null, 8000, System.Threading.Timeout.Infinite); } }
    public static int SortNow() {
        int moved = 0; string d = Dir();
        try {
            foreach (string f in System.IO.Directory.GetFiles(d)) {
                string ext = System.IO.Path.GetExtension(f).ToLowerInvariant(), name = System.IO.Path.GetFileName(f);
                if (ext.Length == 0 || skip.Contains(ext) || name.StartsWith("~") || name.Equals("desktop.ini", StringComparison.OrdinalIgnoreCase)) continue;
                if ((DateTime.Now - System.IO.File.GetLastWriteTime(f)).TotalSeconds < 6) continue;
                string cat = "Інше"; foreach (KeyValuePair<string, string[]> c in Cats) if (Array.IndexOf(c.Value, ext) >= 0) { cat = c.Key; break; }
                string tdir = System.IO.Path.Combine(d, cat); System.IO.Directory.CreateDirectory(tdir);
                string dst = System.IO.Path.Combine(tdir, name);
                for (int i = 2; System.IO.File.Exists(dst); i++) dst = System.IO.Path.Combine(tdir, System.IO.Path.GetFileNameWithoutExtension(name) + " (" + i + ")" + ext);
                try { using (System.IO.FileStream x = System.IO.File.Open(f, System.IO.FileMode.Open, System.IO.FileAccess.Read, System.IO.FileShare.None)) { } System.IO.File.Move(f, dst); moved++; } catch { }
            }
            if (Feat.DlClean) {
                string inst = System.IO.Path.Combine(d, "Інсталятори");
                if (System.IO.Directory.Exists(inst)) foreach (string f in System.IO.Directory.GetFiles(inst))
                    if ((DateTime.Now - System.IO.File.GetLastWriteTime(f)).TotalDays > 30)
                        try { Microsoft.VisualBasic.FileIO.FileSystem.DeleteFile(f, Microsoft.VisualBasic.FileIO.UIOption.OnlyErrorDialogs, Microsoft.VisualBasic.FileIO.RecycleOption.SendToRecycleBin); } catch { }
            }
        } catch { }
        return moved;
    }
}

// ------------------------------------------------------------------ backups (robocopy, daily, never deletes at the target)
public static class Backup {
    public static volatile bool On = false;
    public static string Target = "", Folders = "Documents|Desktop|Pictures"; public static int Hour = 20;
    static volatile bool running = false;
    static string StampFile { get { return System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "valo\\backup-last.txt"); } }
    public static void Set(string args) {   // backup <on 0|1> <hour> <folders a|b|c> <target path...>
        string[] a = args.Split(new char[] { ' ' }, 4);
        if (a.Length < 4) return;
        On = a[0] == "1"; int.TryParse(a[1], out Hour); Folders = a[2]; Target = a[3].Trim();
    }
    public static void Tick() {
        if (!On || running || Target.Length == 0) return;
        DateTime last = DateTime.MinValue; try { last = DateTime.Parse(System.IO.File.ReadAllText(StampFile)); } catch { }
        if (last.Date == DateTime.Today || DateTime.Now.Hour < Hour) return;
        Run();
    }
    public static void Run() {
        if (running || Target.Length == 0) return;
        if (!System.IO.Directory.Exists(System.IO.Path.GetPathRoot(Target) ?? Target)) { Emit.Line("{\"type\":\"backup\",\"ok\":false,\"msg\":\"Диск для копій не підключено\"}"); return; }
        running = true;
        Thread t = new Thread(delegate () {
            int bad = 0; string dest = System.IO.Path.Combine(Target, "valo Backup", Environment.MachineName);
            foreach (string f in Folders.Split('|')) {
                string src = f == "Documents" ? Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments) : f == "Desktop" ? Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory)
                           : f == "Pictures" ? Environment.GetFolderPath(Environment.SpecialFolder.MyPictures) : f == "Videos" ? Environment.GetFolderPath(Environment.SpecialFolder.MyVideos)
                           : f == "Music" ? Environment.GetFolderPath(Environment.SpecialFolder.MyMusic) : null;
                if (src == null || !System.IO.Directory.Exists(src)) continue;
                System.Diagnostics.ProcessStartInfo p = new System.Diagnostics.ProcessStartInfo("robocopy.exe", "\"" + src + "\" \"" + System.IO.Path.Combine(dest, f) + "\" /E /XO /XJ /R:1 /W:1 /NP /NFL /NDL /MT:8");
                p.UseShellExecute = false; p.CreateNoWindow = true;
                try { using (System.Diagnostics.Process pr = System.Diagnostics.Process.Start(p)) { pr.WaitForExit(); if (pr.ExitCode >= 8) bad++; } } catch { bad++; }
            }
            try { System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(StampFile)); System.IO.File.WriteAllText(StampFile, DateTime.Now.ToString("s")); } catch { }
            running = false;
            Emit.Line("{\"type\":\"backup\",\"ok\":" + (bad == 0 ? "true" : "false") + ",\"at\":" + Emit.Q(DateTime.Now.ToString("s")) + ",\"dest\":" + Emit.Q(dest) + "}");
        });
        t.IsBackground = true; t.Start();
    }
}
