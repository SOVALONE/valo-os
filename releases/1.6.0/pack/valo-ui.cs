// valo.os helper UI, compiled together with valo-shell.ps1 (same usings: System, Collections.Generic, Runtime.InteropServices,
// Text, Threading, WF = System.Windows.Forms, SD = System.Drawing). Everything here runs on the preview form's UI thread.
//   AltTab     - own Alt+Tab switcher with live thumbnails
//   Clip       - clipboard history (Win+V): in memory, pinned items saved; respects "don't record" clipboard formats
//   Shot       - PrintScreen: select an area, save to Pictures\Screenshots and copy, small preview toast

public static class ValoUi {
    public static SD.Color Bg = SD.Color.FromArgb(30, 26, 31), Fg = SD.Color.FromArgb(245, 230, 234),
        Accent = SD.Color.FromArgb(242, 167, 187), Muted = SD.Color.FromArgb(156, 138, 147);
    public static volatile bool AltTabOn = true, ClipOn = true, ShotOn = true, EmojiOn = true;

    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);

    public static void SetColors(string bg, string fg, string accent, string muted) {
        try { Bg = SD.ColorTranslator.FromHtml(bg); Fg = SD.ColorTranslator.FromHtml(fg); Accent = SD.ColorTranslator.FromHtml(accent); Muted = SD.ColorTranslator.FromHtml(muted); } catch { }
    }
    public static SD.Color Mix(SD.Color a, SD.Color b, float t) {
        return SD.Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));
    }
    public static void Style(WF.Form f) {
        int round = 2; DwmSetWindowAttribute(f.Handle, 33, ref round, 4);
        int bc = Accent.R | (Accent.G << 8) | (Accent.B << 16); DwmSetWindowAttribute(f.Handle, 34, ref bc, 4);
    }
    // bring one of our windows to the front from a background process (Alt tap unlocks SetForegroundWindow)
    public static void Focus(WF.Form f) {
        keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
        SetForegroundWindow(f.Handle); f.Activate();
    }
    public static void Post(Action a) { PreviewForm.Post(a); }
    public static float Scale(WF.Control c) { using (SD.Graphics g = c.CreateGraphics()) return g.DpiX / 96f; }

    static Dictionary<string, SD.Bitmap> icons = new Dictionary<string, SD.Bitmap>();
    public static SD.Bitmap Icon(string exe) {
        if (string.IsNullOrEmpty(exe)) return null;
        SD.Bitmap b;
        if (icons.TryGetValue(exe, out b)) return b;
        try { using (SD.Icon i = SD.Icon.ExtractAssociatedIcon(exe)) b = i.ToBitmap(); } catch { b = null; }
        icons[exe] = b; return b;
    }
}

// ------------------------------------------------------------------ Alt+Tab
public class AltTabForm : WF.Form {
    [DllImport("dwmapi.dll")] static extern int DwmRegisterThumbnail(IntPtr dest, IntPtr src, out IntPtr id);
    [DllImport("dwmapi.dll")] static extern int DwmUnregisterThumbnail(IntPtr id);
    [DllImport("dwmapi.dll")] static extern int DwmUpdateThumbnailProperties(IntPtr id, ref TP p);
    [DllImport("dwmapi.dll")] static extern int DwmQueryThumbnailSourceSize(IntPtr id, out SZ s);
    [StructLayout(LayoutKind.Sequential)] struct SZ { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct R4 { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct TP { public uint flags; public R4 dst; public R4 src; public byte opacity; public bool visible; public bool clientOnly; }
    class Cell { public ValoShell.Win w; public IntPtr thumb; public SD.Rectangle box, img; }

    public static AltTabForm Inst;
    public static volatile bool Active = false;
    List<Cell> cells = new List<Cell>();
    int sel = 0;
    float s = 1f;
    WF.Timer showTimer = new WF.Timer();
    SD.Font font = new SD.Font("Segoe UI", 9f);

    public AltTabForm() {
        FormBorderStyle = WF.FormBorderStyle.None; ShowInTaskbar = false; StartPosition = WF.FormStartPosition.Manual;
        AutoScaleMode = WF.AutoScaleMode.None; DoubleBuffered = true; Text = "";
        Bounds = new SD.Rectangle(-4000, -4000, 10, 10);
        showTimer.Interval = 110; showTimer.Tick += delegate { showTimer.Stop(); if (Active) Reveal(); };
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override WF.CreateParams CreateParams { get { WF.CreateParams p = base.CreateParams; p.ExStyle |= 0x08000088; return p; } }
    int S(float v) { return (int)Math.Round(v * s); }

    // called from the keyboard hook thread through ValoUi.Post
    public void Begin(bool back) {
        Clear();
        List<ValoShell.Win> ws = ValoShell.Windows();
        foreach (ValoShell.Win w in ws) { Cell c = new Cell(); c.w = w; cells.Add(c); }
        if (cells.Count == 0) { Active = false; return; }
        int fg = cells.FindIndex(delegate (Cell c) { return c.w.fg; });
        if (fg > 0) { Cell f = cells[fg]; cells.RemoveAt(fg); cells.Insert(0, f); }
        sel = cells.Count > 1 ? (back ? cells.Count - 1 : 1) : 0;
        Active = true;
        showTimer.Stop(); showTimer.Start();          // quick Alt+Tab taps switch without flashing the switcher
    }
    public void Step(bool back) {
        if (!Active || cells.Count == 0) return;
        sel = (sel + (back ? cells.Count - 1 : 1)) % cells.Count;
        if (Visible) Invalidate();
    }
    public void Commit() {
        if (!Active) return;
        Active = false; showTimer.Stop();
        Cell c = (sel >= 0 && sel < cells.Count) ? cells[sel] : null;
        Hide(); Clear();
        if (c != null) ValoShell.Activate(c.w.hwnd);
    }
    public void Cancel() { Active = false; showTimer.Stop(); Hide(); Clear(); }

    void Clear() { foreach (Cell c in cells) if (c.thumb != IntPtr.Zero) DwmUnregisterThumbnail(c.thumb); cells.Clear(); }

    void Reveal() {
        s = ValoUi.Scale(this);
        WF.Screen scr = WF.Screen.PrimaryScreen;
        int n = cells.Count, perRow = Math.Min(n, 6), rows = (n + perRow - 1) / perRow;
        int cw = S(210), ch = S(150), pad = S(14), gap = S(10), head = S(26);
        int maxW = scr.WorkingArea.Width - S(80);
        if (perRow * (cw + gap) + pad * 2 > maxW) cw = (maxW - pad * 2) / perRow - gap;
        int W = pad * 2 + perRow * cw + (perRow - 1) * gap, H = pad * 2 + rows * (ch + head) + (rows - 1) * gap;
        Bounds = new SD.Rectangle(scr.Bounds.Left + (scr.Bounds.Width - W) / 2, scr.Bounds.Top + (scr.Bounds.Height - H) / 2, W, H);
        BackColor = ValoUi.Bg;
        for (int i = 0; i < n; i++) {
            Cell c = cells[i];
            int x = pad + (i % perRow) * (cw + gap), y = pad + (i / perRow) * (ch + head + gap);
            c.box = new SD.Rectangle(x, y, cw, ch + head);
            SD.Rectangle area = new SD.Rectangle(x + S(6), y + head, cw - S(12), ch - S(6));
            c.img = area;
            if (!c.w.min && DwmRegisterThumbnail(Handle, new IntPtr(c.w.hwnd), out c.thumb) == 0) {
                SZ z;
                if (DwmQueryThumbnailSourceSize(c.thumb, out z) == 0 && z.x > 0 && z.y > 0) {
                    double k = Math.Min((double)area.Width / z.x, (double)area.Height / z.y);
                    int iw = (int)(z.x * k), ih = (int)(z.y * k);
                    c.img = new SD.Rectangle(area.Left + (area.Width - iw) / 2, area.Top + (area.Height - ih) / 2, iw, ih);
                }
                TP p = new TP(); p.flags = 0x1D; p.opacity = 255; p.visible = true;
                p.dst.l = c.img.Left; p.dst.t = c.img.Top; p.dst.r = c.img.Right; p.dst.b = c.img.Bottom;
                DwmUpdateThumbnailProperties(c.thumb, ref p);
            } else c.thumb = IntPtr.Zero;
        }
        ValoUi.Style(this);
        Show();
        ValoUi.SetWindowPos(Handle, new IntPtr(-1), 0, 0, 0, 0, 0x13);
        Invalidate();
    }

    protected override void OnPaint(WF.PaintEventArgs e) {
        SD.Graphics g = e.Graphics; g.Clear(ValoUi.Bg);
        for (int i = 0; i < cells.Count; i++) {
            Cell c = cells[i];
            if (i == sel) {
                using (SD.SolidBrush b = new SD.SolidBrush(ValoUi.Mix(ValoUi.Bg, ValoUi.Accent, .22f))) g.FillRectangle(b, c.box);
                using (SD.Pen p = new SD.Pen(ValoUi.Accent, S(2))) g.DrawRectangle(p, c.box.X + 1, c.box.Y + 1, c.box.Width - 2, c.box.Height - 2);
            }
            SD.Bitmap ic = ValoUi.Icon(c.w.exe);
            int tx = c.box.Left + S(8);
            if (ic != null) { g.DrawImage(ic, tx, c.box.Top + S(5), S(16), S(16)); tx += S(22); }
            WF.TextRenderer.DrawText(g, c.w.title, font, new SD.Rectangle(tx, c.box.Top + S(3), c.box.Right - tx - S(6), S(20)),
                i == sel ? ValoUi.Fg : ValoUi.Mix(ValoUi.Fg, ValoUi.Muted, .4f),
                WF.TextFormatFlags.Left | WF.TextFormatFlags.VerticalCenter | WF.TextFormatFlags.EndEllipsis | WF.TextFormatFlags.SingleLine | WF.TextFormatFlags.NoPrefix);
            if (c.thumb == IntPtr.Zero) {
                using (SD.SolidBrush b = new SD.SolidBrush(ValoUi.Mix(ValoUi.Bg, ValoUi.Fg, .06f))) g.FillRectangle(b, c.img);
                if (ic != null) g.DrawImage(ic, c.img.Left + c.img.Width / 2 - S(16), c.img.Top + c.img.Height / 2 - S(16), S(32), S(32));
            }
        }
    }
    protected override void OnMouseUp(WF.MouseEventArgs e) {
        for (int i = 0; i < cells.Count; i++) if (cells[i].box.Contains(e.Location)) { sel = i; Commit(); return; }
    }
}

// ------------------------------------------------------------------ clipboard history (Win+V)
public class ClipItem { public string text; public SD.Bitmap img; public bool pinned; public DateTime at; }

public class ClipForm : WF.Form {
    [DllImport("user32.dll")] static extern bool AddClipboardFormatListener(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint RegisterClipboardFormat(string f);
    [DllImport("user32.dll")] static extern bool IsClipboardFormatAvailable(uint f);

    public static ClipForm Inst;
    public List<ClipItem> items = new List<ClipItem>();
    WF.TextBox search = new WF.TextBox();
    WF.ListBox list = new WF.ListBox();
    WF.Label hint = new WF.Label();
    List<ClipItem> shown = new List<ClipItem>();
    IntPtr prevFg = IntPtr.Zero;
    bool ignoreNext = false;
    float s = 1f;
    uint fmtExclude, fmtHistory, fmtIgnore;
    string pinFile = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "valo\\clip-pinned.txt");
    SD.Font font = new SD.Font("Segoe UI", 9.5f), small = new SD.Font("Segoe UI", 8f);

    public ClipForm() {
        FormBorderStyle = WF.FormBorderStyle.None; ShowInTaskbar = false; StartPosition = WF.FormStartPosition.Manual; TopMost = true;
        AutoScaleMode = WF.AutoScaleMode.None; KeyPreview = true; Text = "valo clipboard";
        Bounds = new SD.Rectangle(-4000, -4000, 10, 10);
        search.BorderStyle = WF.BorderStyle.None; search.Font = new SD.Font("Segoe UI", 11f);
        list.BorderStyle = WF.BorderStyle.None; list.DrawMode = WF.DrawMode.OwnerDrawVariable; list.IntegralHeight = false;
        list.MeasureItem += OnMeasure; list.DrawItem += OnDraw;
        list.MouseClick += delegate (object o, WF.MouseEventArgs e) { if (list.SelectedIndex >= 0) Paste(shown[list.SelectedIndex]); };
        list.MouseDown += delegate (object o, WF.MouseEventArgs e) {
            int i = list.IndexFromPoint(e.Location); if (i < 0) return;
            list.SelectedIndex = i;
            if (e.Button == WF.MouseButtons.Right) TogglePin(shown[i]);
        };
        search.TextChanged += delegate { Fill(); };
        hint.Text = "Enter — вставити · ПКМ / Ctrl+P — закріпити · Del — видалити · Esc — закрити";
        Controls.Add(list); Controls.Add(search); Controls.Add(hint);
        Deactivate += delegate { if (Visible) Hide(); };
        fmtExclude = RegisterClipboardFormat("ExcludeClipboardContentFromMonitorProcessing");
        fmtHistory = RegisterClipboardFormat("CanIncludeInClipboardHistory");
        fmtIgnore = RegisterClipboardFormat("Clipboard Viewer Ignore");
        LoadPinned();
    }
    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); AddClipboardFormatListener(Handle); }
    int S(float v) { return (int)Math.Round(v * s); }

    protected override void WndProc(ref WF.Message m) {
        if (m.Msg == 0x031D) OnClipboard();   // WM_CLIPBOARDUPDATE
        base.WndProc(ref m);
    }
    void OnClipboard() {
        if (ignoreNext) { ignoreNext = false; return; }
        try {
            // password managers and similar mark secrets: never record those
            if (IsClipboardFormatAvailable(fmtExclude) || IsClipboardFormatAvailable(fmtIgnore)) return;
            if (IsClipboardFormatAvailable(fmtHistory)) {
                WF.IDataObject d = WF.Clipboard.GetDataObject();
                object v = d != null ? d.GetData("CanIncludeInClipboardHistory") : null;
                System.IO.MemoryStream ms = v as System.IO.MemoryStream;
                if (ms != null && ms.Length >= 4) { byte[] b = ms.ToArray(); if (BitConverter.ToInt32(b, 0) == 0) return; }
            }
            ClipItem it = null;
            if (WF.Clipboard.ContainsText()) {
                string t = WF.Clipboard.GetText();
                if (string.IsNullOrEmpty(t) || t.Length > 200000) return;
                items.RemoveAll(delegate (ClipItem x) { return !x.pinned && x.text == t; });
                if (items.Exists(delegate (ClipItem x) { return x.pinned && x.text == t; })) return;
                it = new ClipItem(); it.text = t;
            } else if (WF.Clipboard.ContainsImage()) {
                SD.Image im = WF.Clipboard.GetImage(); if (im == null) return;
                it = new ClipItem(); it.img = new SD.Bitmap(im); im.Dispose();
            }
            if (it == null) return;
            it.at = DateTime.Now;
            int firstFree = items.FindIndex(delegate (ClipItem x) { return !x.pinned; });
            items.Insert(firstFree < 0 ? items.Count : firstFree, it);
            int unpinned = 0, imgs = 0;
            for (int i = 0; i < items.Count; i++) {
                if (items[i].pinned) continue;
                unpinned++; if (items[i].img != null) imgs++;
                if (unpinned > 40 || (items[i].img != null && imgs > 8)) { if (items[i].img != null) items[i].img.Dispose(); items.RemoveAt(i); i--; }
            }
        } catch { }
    }

    void LoadPinned() {
        try {
            if (!System.IO.File.Exists(pinFile)) return;
            foreach (string t in System.IO.File.ReadAllText(pinFile, Encoding.UTF8).Split(new string[] { "\u001e" }, StringSplitOptions.RemoveEmptyEntries)) {
                ClipItem it = new ClipItem(); it.text = t; it.pinned = true; it.at = DateTime.Now; items.Add(it);
            }
        } catch { }
    }
    void SavePinned() {
        try {
            List<string> ts = new List<string>();
            foreach (ClipItem it in items) if (it.pinned && it.text != null) ts.Add(it.text);
            System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(pinFile));
            System.IO.File.WriteAllText(pinFile, string.Join("\u001e", ts.ToArray()), Encoding.UTF8);
        } catch { }
    }
    void TogglePin(ClipItem it) {
        if (it.img != null) return;          // only text can be pinned (pinned items are kept on disk)
        it.pinned = !it.pinned;
        items.Remove(it);
        if (it.pinned) items.Insert(0, it);
        else { int f = items.FindIndex(delegate (ClipItem x) { return !x.pinned; }); items.Insert(f < 0 ? items.Count : f, it); }
        SavePinned(); Fill();
    }

    public void Toggle() {
        if (Visible) { Hide(); return; }
        prevFg = ValoUi.GetForegroundWindow();
        s = ValoUi.Scale(this);
        WF.Screen scr = WF.Screen.PrimaryScreen;
        int W = S(440), H = S(500);
        Bounds = new SD.Rectangle(scr.Bounds.Left + (scr.Bounds.Width - W) / 2, scr.WorkingArea.Bottom - H - S(16), W, H);
        BackColor = ValoUi.Bg;
        search.BackColor = ValoUi.Mix(ValoUi.Bg, ValoUi.Fg, .07f); search.ForeColor = ValoUi.Fg;
        list.BackColor = ValoUi.Bg; list.ForeColor = ValoUi.Fg;
        hint.ForeColor = ValoUi.Muted; hint.BackColor = ValoUi.Bg; hint.Font = small;
        search.SetBounds(S(14), S(14), W - S(28), S(26));
        list.SetBounds(S(8), S(50), W - S(16), H - S(50) - S(30));
        hint.SetBounds(S(14), H - S(26), W - S(28), S(20));
        search.Text = "";
        Fill();
        ValoUi.Style(this);
        Show(); ValoUi.Focus(this); search.Focus();
    }
    void Fill() {
        string q = search.Text.Trim().ToLowerInvariant();
        shown = items.FindAll(delegate (ClipItem x) { return q.Length == 0 || (x.text != null && x.text.ToLowerInvariant().Contains(q)); });
        list.BeginUpdate(); list.Items.Clear();
        foreach (ClipItem x in shown) list.Items.Add(x);
        if (shown.Count == 0) list.Items.Add(items.Count == 0 ? "Історія порожня — скопіюйте щось" : "Нічого не знайдено");
        list.EndUpdate();
        if (shown.Count > 0) list.SelectedIndex = 0;
    }
    void OnMeasure(object o, WF.MeasureItemEventArgs e) {
        ClipItem x = (e.Index >= 0 && e.Index < shown.Count) ? shown[e.Index] : null;
        e.ItemHeight = x != null && x.img != null ? S(96) : S(50);
    }
    void OnDraw(object o, WF.DrawItemEventArgs e) {
        if (e.Index < 0) return;
        SD.Graphics g = e.Graphics;
        bool selected = (e.State & WF.DrawItemState.Selected) != 0;
        SD.Rectangle r = new SD.Rectangle(e.Bounds.X + S(4), e.Bounds.Y + S(3), e.Bounds.Width - S(8), e.Bounds.Height - S(6));
        using (SD.SolidBrush b = new SD.SolidBrush(ValoUi.Bg)) g.FillRectangle(b, e.Bounds);
        using (SD.SolidBrush b = new SD.SolidBrush(selected ? ValoUi.Mix(ValoUi.Bg, ValoUi.Accent, .25f) : ValoUi.Mix(ValoUi.Bg, ValoUi.Fg, .05f))) g.FillRectangle(b, r);
        if (e.Index >= shown.Count) { WF.TextRenderer.DrawText(g, list.Items[e.Index].ToString(), font, r, ValoUi.Muted, WF.TextFormatFlags.HorizontalCenter | WF.TextFormatFlags.VerticalCenter); return; }
        ClipItem x = shown[e.Index];
        if (x.pinned) WF.TextRenderer.DrawText(g, "★", font, new SD.Rectangle(r.Right - S(22), r.Top + S(2), S(20), S(18)), ValoUi.Accent, WF.TextFormatFlags.HorizontalCenter);
        if (x.img != null) {
            double k = Math.Min((double)(r.Width - S(16)) / x.img.Width, (double)(r.Height - S(12)) / x.img.Height);
            g.InterpolationMode = SD.Drawing2D.InterpolationMode.HighQualityBicubic;
            g.DrawImage(x.img, r.Left + S(8), r.Top + S(6), (int)(x.img.Width * k), (int)(x.img.Height * k));
        } else {
            string t = x.text.Replace("\r", "").Replace("\t", "  ");
            if (t.Length > 300) t = t.Substring(0, 300);
            WF.TextRenderer.DrawText(g, t, font, new SD.Rectangle(r.Left + S(8), r.Top + S(4), r.Width - S(34), r.Height - S(8)), ValoUi.Fg,
                WF.TextFormatFlags.Left | WF.TextFormatFlags.WordBreak | WF.TextFormatFlags.EndEllipsis | WF.TextFormatFlags.NoPrefix);
        }
    }
    protected override void OnPaint(WF.PaintEventArgs e) { e.Graphics.Clear(ValoUi.Bg); }
    protected override bool ProcessCmdKey(ref WF.Message msg, WF.Keys k) {
        int i = list.SelectedIndex;
        if (k == WF.Keys.Escape) { Hide(); return true; }
        if (k == WF.Keys.Down) { if (i < shown.Count - 1) list.SelectedIndex = i + 1; return true; }
        if (k == WF.Keys.Up) { if (i > 0) list.SelectedIndex = i - 1; return true; }
        if (k == WF.Keys.Enter) { if (i >= 0 && i < shown.Count) Paste(shown[i]); return true; }
        if (k == (WF.Keys.Control | WF.Keys.P)) { if (i >= 0 && i < shown.Count) TogglePin(shown[i]); return true; }
        if (k == WF.Keys.Delete && search.Text.Length == 0) { if (i >= 0 && i < shown.Count) { items.Remove(shown[i]); SavePinned(); Fill(); } return true; }
        return base.ProcessCmdKey(ref msg, k);
    }
    void Paste(ClipItem x) {
        try {
            ignoreNext = true;
            if (x.img != null) WF.Clipboard.SetImage(x.img); else WF.Clipboard.SetText(x.text);
            items.Remove(x);
            if (x.pinned) items.Insert(0, x);
            else { int f = items.FindIndex(delegate (ClipItem y) { return !y.pinned; }); items.Insert(f < 0 ? items.Count : f, x); }
        } catch { ignoreNext = false; }
        Hide();
        IntPtr target = prevFg;
        WF.Timer t = new WF.Timer(); t.Interval = 90;
        t.Tick += delegate {
            t.Stop(); t.Dispose();
            if (target != IntPtr.Zero) SetFg(target);
            ValoUi.keybd_event(0x11, 0, 0, UIntPtr.Zero); ValoUi.keybd_event(0x56, 0, 0, UIntPtr.Zero);
            ValoUi.keybd_event(0x56, 0, 2, UIntPtr.Zero); ValoUi.keybd_event(0x11, 0, 2, UIntPtr.Zero);
        };
        t.Start();
    }
    static void SetFg(IntPtr h) { ValoUi.keybd_event(0x12, 0, 0, UIntPtr.Zero); ValoUi.keybd_event(0x12, 0, 2, UIntPtr.Zero); ValoUi.SetForegroundWindow(h); }
}

// ------------------------------------------------------------------ screenshots (PrintScreen)
public class ShotForm : WF.Form {
    public static ShotForm Inst;
    SD.Bitmap shot, dim;
    SD.Rectangle virt;
    SD.Point start; bool dragging = false; SD.Rectangle sel = SD.Rectangle.Empty;
    float s = 1f;
    SD.Font font = new SD.Font("Segoe UI", 9f);

    public ShotForm() {
        FormBorderStyle = WF.FormBorderStyle.None; ShowInTaskbar = false; StartPosition = WF.FormStartPosition.Manual; TopMost = true;
        AutoScaleMode = WF.AutoScaleMode.None; DoubleBuffered = true; KeyPreview = true; Cursor = WF.Cursors.Cross; Text = "valo screenshot";
        Bounds = new SD.Rectangle(-4000, -4000, 10, 10);
    }
    int S(float v) { return (int)Math.Round(v * s); }

    public string Mode = "shot";
    public void Start() { Start("shot"); }
    public void Start(string mode) {
        if (Visible) return;
        Mode = mode;
        s = ValoUi.Scale(this);
        virt = WF.SystemInformation.VirtualScreen;
        if (shot != null) { shot.Dispose(); dim.Dispose(); }
        shot = new SD.Bitmap(virt.Width, virt.Height);
        using (SD.Graphics g = SD.Graphics.FromImage(shot)) g.CopyFromScreen(virt.Left, virt.Top, 0, 0, virt.Size);
        dim = new SD.Bitmap(shot);
        using (SD.Graphics g = SD.Graphics.FromImage(dim)) using (SD.SolidBrush b = new SD.SolidBrush(SD.Color.FromArgb(110, 0, 0, 0))) g.FillRectangle(b, 0, 0, dim.Width, dim.Height);
        sel = SD.Rectangle.Empty; dragging = false;
        Bounds = virt;
        Show(); ValoUi.Focus(this);
        ValoUi.SetWindowPos(Handle, new IntPtr(-1), 0, 0, 0, 0, 0x13);
        Invalidate();
    }
    protected override void OnPaint(WF.PaintEventArgs e) {
        if (dim == null) return;
        SD.Graphics g = e.Graphics;
        g.DrawImageUnscaled(dim, 0, 0);
        if (sel.Width > 0 && sel.Height > 0) {
            g.DrawImage(shot, sel, sel, SD.GraphicsUnit.Pixel);
            using (SD.Pen p = new SD.Pen(ValoUi.Accent, Math.Max(1, S(2)))) g.DrawRectangle(p, sel);
            string label = sel.Width + " × " + sel.Height;
            SD.Size ts = WF.TextRenderer.MeasureText(label, font);
            SD.Rectangle lr = new SD.Rectangle(sel.Left, Math.Max(0, sel.Top - ts.Height - S(8)), ts.Width + S(12), ts.Height + S(4));
            using (SD.SolidBrush b = new SD.SolidBrush(ValoUi.Bg)) g.FillRectangle(b, lr);
            WF.TextRenderer.DrawText(g, label, font, lr, ValoUi.Fg, WF.TextFormatFlags.HorizontalCenter | WF.TextFormatFlags.VerticalCenter);
        } else {
            string t = (Mode == "ocr" ? "Текст з екрана: виділіть область" : Mode == "rec" ? "Запис екрана: виділіть область" : "Виділіть область") + " · Enter — увесь екран · Esc — скасувати";
            SD.Size ts = WF.TextRenderer.MeasureText(t, font);
            WF.Screen scr = WF.Screen.PrimaryScreen;
            SD.Rectangle lr = new SD.Rectangle(scr.Bounds.Left - virt.Left + (scr.Bounds.Width - ts.Width) / 2 - S(12), scr.Bounds.Top - virt.Top + S(80), ts.Width + S(24), ts.Height + S(14));
            using (SD.SolidBrush b = new SD.SolidBrush(ValoUi.Bg)) g.FillRectangle(b, lr);
            WF.TextRenderer.DrawText(g, t, font, lr, ValoUi.Fg, WF.TextFormatFlags.HorizontalCenter | WF.TextFormatFlags.VerticalCenter);
        }
    }
    protected override void OnMouseDown(WF.MouseEventArgs e) {
        if (e.Button == WF.MouseButtons.Right) { Close_(); return; }
        dragging = true; start = e.Location; sel = new SD.Rectangle(e.Location, SD.Size.Empty);
    }
    protected override void OnMouseMove(WF.MouseEventArgs e) {
        if (!dragging) return;
        sel = SD.Rectangle.FromLTRB(Math.Min(start.X, e.X), Math.Min(start.Y, e.Y), Math.Max(start.X, e.X), Math.Max(start.Y, e.Y));
        Invalidate();
    }
    protected override void OnMouseUp(WF.MouseEventArgs e) {
        if (!dragging) return;
        dragging = false;
        if (sel.Width > 4 && sel.Height > 4) Save(sel);
    }
    protected override bool ProcessCmdKey(ref WF.Message msg, WF.Keys k) {
        if (k == WF.Keys.Escape) { Close_(); return true; }
        if (k == WF.Keys.Enter) {
            WF.Screen scr = WF.Screen.PrimaryScreen;
            Save(new SD.Rectangle(scr.Bounds.Left - virt.Left, scr.Bounds.Top - virt.Top, scr.Bounds.Width, scr.Bounds.Height));
            return true;
        }
        return base.ProcessCmdKey(ref msg, k);
    }
    void Close_() { Hide(); if (shot != null) { shot.Dispose(); dim.Dispose(); shot = null; dim = null; } }
    void Save(SD.Rectangle r) {
        if (Mode == "rec") { SD.Rectangle sr = new SD.Rectangle(r.X + virt.Left, r.Y + virt.Top, r.Width, r.Height); Close_(); Recorder.Start(sr); return; }
        if (Mode == "ocr") { SD.Bitmap c = null; try { c = shot.Clone(r, shot.PixelFormat); } catch { } Close_(); if (c != null) Ocr.Run(c); return; }
        string path = null;
        SD.Bitmap crop = null;
        try {
            crop = shot.Clone(r, shot.PixelFormat);
            string dir = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), "Screenshots");
            System.IO.Directory.CreateDirectory(dir);
            path = System.IO.Path.Combine(dir, "valo-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".png");
            crop.Save(path, SD.Imaging.ImageFormat.Png);
            WF.Clipboard.SetImage(crop);
        } catch { }
        Close_();
        if (crop != null) ShotToast.Show_(crop, path);
    }
}

public class ShotToast : WF.Form {
    static ShotToast inst;
    SD.Bitmap img; string path;
    WF.Timer timer = new WF.Timer();
    float s = 1f;
    SD.Font font = new SD.Font("Segoe UI", 9f);
    public ShotToast() {
        FormBorderStyle = WF.FormBorderStyle.None; ShowInTaskbar = false; StartPosition = WF.FormStartPosition.Manual;
        AutoScaleMode = WF.AutoScaleMode.None; DoubleBuffered = true; Cursor = WF.Cursors.Hand; Text = "";
        timer.Interval = 4500; timer.Tick += delegate { timer.Stop(); Hide(); };
    }
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override WF.CreateParams CreateParams { get { WF.CreateParams p = base.CreateParams; p.ExStyle |= 0x08000088; return p; } }
    int S(float v) { return (int)Math.Round(v * s); }
    public static void Show_(SD.Bitmap b, string p) {
        if (inst == null) inst = new ShotToast();
        if (inst.img != null) inst.img.Dispose();
        inst.img = b; inst.path = p; inst.s = ValoUi.Scale(inst);
        WF.Screen scr = WF.Screen.PrimaryScreen;
        int W = inst.S(280), H = inst.S(200);
        inst.Bounds = new SD.Rectangle(scr.WorkingArea.Right - W - inst.S(16), scr.WorkingArea.Bottom - H - inst.S(16), W, H);
        inst.BackColor = ValoUi.Bg;
        ValoUi.Style(inst);
        inst.Show(); ValoUi.SetWindowPos(inst.Handle, new IntPtr(-1), 0, 0, 0, 0, 0x13);
        inst.Invalidate(); inst.timer.Stop(); inst.timer.Start();
    }
    protected override void OnPaint(WF.PaintEventArgs e) {
        SD.Graphics g = e.Graphics; g.Clear(ValoUi.Bg);
        if (img == null) return;
        SD.Rectangle area = new SD.Rectangle(S(10), S(10), Width - S(20), Height - S(48));
        double k = Math.Min((double)area.Width / img.Width, (double)area.Height / img.Height);
        int w = (int)(img.Width * k), h = (int)(img.Height * k);
        g.InterpolationMode = SD.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.DrawImage(img, area.Left + (area.Width - w) / 2, area.Top + (area.Height - h) / 2, w, h);
        WF.TextRenderer.DrawText(g, "Знімок збережено й скопійовано", font, new SD.Rectangle(S(10), Height - S(36), Width - S(20), S(16)), ValoUi.Fg, WF.TextFormatFlags.Left);
        WF.TextRenderer.DrawText(g, "клік — відкрити, ПКМ — показати в папці", font, new SD.Rectangle(S(10), Height - S(20), Width - S(20), S(16)), ValoUi.Muted, WF.TextFormatFlags.Left);
    }
    protected override void OnMouseUp(WF.MouseEventArgs e) {
        timer.Stop(); Hide();
        if (string.IsNullOrEmpty(path)) return;
        try {
            if (e.Button == WF.MouseButtons.Right) System.Diagnostics.Process.Start("explorer.exe", "/select,\"" + path + "\"");
            else System.Diagnostics.Process.Start(path);
        } catch { }
    }
}
