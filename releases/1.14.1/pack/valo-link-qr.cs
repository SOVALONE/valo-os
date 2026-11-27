// valo Link — QR codes (own small encoder: byte mode, error correction M, versions 1–10) and quick share without pairing.
// Quick share: the PC shows a QR with a one-time link (random 128-bit id, 15 minutes, local network only).
//   send    — the phone opens the link and downloads the chosen files
//   receive — the phone opens the link and uploads files / photos to Downloads\valo Link
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Windows.Forms;

namespace ValoLink {

public static class Qr {
    static readonly int[] Ecc = { -1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26 };
    static readonly int[] Blocks = { -1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5 };

    static int RawModules(int v) { int r = (16 * v + 128) * v + 64; if (v >= 2) { int n = v / 7 + 2; r -= (25 * n - 10) * n - 55; if (v >= 7) r -= 36; } return r; }
    static int DataCodewords(int v) { return RawModules(v) / 8 - Ecc[v] * Blocks[v]; }
    static int Mul(int x, int y) { int z = 0; for (int i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >> 7) * 0x11D); z ^= ((y >> i) & 1) * x; } return z & 0xFF; }
    static byte[] Divisor(int deg) {
        byte[] r = new byte[deg]; r[deg - 1] = 1; int root = 1;
        for (int i = 0; i < deg; i++) { for (int j = 0; j < deg; j++) { r[j] = (byte)Mul(r[j], root); if (j + 1 < deg) r[j] ^= r[j + 1]; } root = Mul(root, 2); }
        return r;
    }
    static byte[] Remainder(List<byte> data, byte[] div) {
        byte[] r = new byte[div.Length];
        foreach (byte b in data) {
            int f = b ^ r[0]; Array.Copy(r, 1, r, 0, r.Length - 1); r[r.Length - 1] = 0;
            for (int i = 0; i < r.Length; i++) r[i] ^= (byte)Mul(div[i], f);
        }
        return r;
    }

    public static bool[,] Encode(string text) {
        byte[] bytes = Encoding.UTF8.GetBytes(text);
        int ver = 1;
        for (; ver <= 10; ver++) { int cap = DataCodewords(ver) * 8; if (4 + (ver < 10 ? 8 : 16) + bytes.Length * 8 <= cap) break; }
        if (ver > 10) throw new ArgumentException("too long for QR");
        // ---- data bits
        List<bool> bits = new List<bool>();
        Action<int, int> put = delegate (int val, int n) { for (int i = n - 1; i >= 0; i--) bits.Add(((val >> i) & 1) != 0); };
        put(4, 4); put(bytes.Length, ver < 10 ? 8 : 16);
        foreach (byte b in bytes) put(b, 8);
        int capBits = DataCodewords(ver) * 8;
        put(0, Math.Min(4, capBits - bits.Count));
        while (bits.Count % 8 != 0) bits.Add(false);
        List<byte> data = new List<byte>();
        for (int i = 0; i < bits.Count; i += 8) { int b = 0; for (int j = 0; j < 8; j++) b = (b << 1) | (bits[i + j] ? 1 : 0); data.Add((byte)b); }
        for (bool alt = true; data.Count < DataCodewords(ver); alt = !alt) data.Add(alt ? (byte)0xEC : (byte)0x11);
        // ---- blocks + error correction, interleaved
        int nb = Blocks[ver], el = Ecc[ver], raw = RawModules(ver) / 8, nShort = nb - raw % nb, shortLen = raw / nb;
        byte[] div = Divisor(el);
        List<List<byte>> blocks = new List<List<byte>>(); int k = 0;
        for (int i = 0; i < nb; i++) {
            int len = shortLen - el + (i < nShort ? 0 : 1);
            List<byte> d = data.GetRange(k, len); k += len;
            byte[] ecc = Remainder(d, div);
            if (i < nShort) d.Add(0);
            d.AddRange(ecc); blocks.Add(d);
        }
        List<byte> all = new List<byte>();
        for (int i = 0; i < blocks[0].Count; i++) for (int j = 0; j < nb; j++) if (i != shortLen - el || j >= nShort) all.Add(blocks[j][i]);

        int size = ver * 4 + 17;
        bool[,] m = new bool[size, size], fn = new bool[size, size];
        Action<int, int, bool> set = delegate (int x, int y, bool dark) { m[y, x] = dark; fn[y, x] = true; };
        for (int i = 0; i < size; i++) { set(6, i, i % 2 == 0); set(i, 6, i % 2 == 0); }
        foreach (int[] c in new int[][] { new[] { 3, 3 }, new[] { size - 4, 3 }, new[] { 3, size - 4 } })
            for (int dy = -4; dy <= 4; dy++) for (int dx = -4; dx <= 4; dx++) {
                int d = Math.Max(Math.Abs(dx), Math.Abs(dy)), xx = c[0] + dx, yy = c[1] + dy;
                if (xx >= 0 && xx < size && yy >= 0 && yy < size) set(xx, yy, d != 2 && d != 4);
            }
        if (ver > 1) {
            int na = ver / 7 + 2, step = (ver * 8 + na * 3 + 5) / (na * 4 - 4) * 2;
            int[] pos = new int[na]; pos[0] = 6; for (int i = na - 1, p = size - 7; i >= 1; i--, p -= step) pos[i] = p;
            for (int i = 0; i < na; i++) for (int j = 0; j < na; j++) {
                if ((i == 0 && j == 0) || (i == 0 && j == na - 1) || (i == na - 1 && j == 0)) continue;
                for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++) set(pos[i] + dx, pos[j] + dy, Math.Max(Math.Abs(dx), Math.Abs(dy)) != 1);
            }
        }
        Format(m, fn, size, 0, set);
        if (ver >= 7) {
            int rem = ver; for (int i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
            int vb = (ver << 12) | (rem & 0xFFF);
            for (int i = 0; i < 18; i++) { bool b = ((vb >> i) & 1) != 0; int a = size - 11 + i % 3, bb = i / 3; set(a, bb, b); set(bb, a, b); }
        }
        // ---- codewords in zig-zag
        int bi = 0;
        for (int right = size - 1; right >= 1; right -= 2) {
            if (right == 6) right = 5;
            for (int vert = 0; vert < size; vert++) for (int j = 0; j < 2; j++) {
                int x = right - j; bool up = ((right + 1) & 2) == 0; int y = up ? size - 1 - vert : vert;
                if (!fn[y, x] && bi < all.Count * 8) { m[y, x] = ((all[bi >> 3] >> (7 - (bi & 7))) & 1) != 0; bi++; }
            }
        }
        // ---- best mask by a simple penalty
        int best = 0, bestScore = int.MaxValue;
        for (int mask = 0; mask < 8; mask++) {
            Mask(m, fn, size, mask); Format(m, fn, size, mask, set);
            int sc = Penalty(m, size); if (sc < bestScore) { bestScore = sc; best = mask; }
            Mask(m, fn, size, mask);
        }
        Mask(m, fn, size, best); Format(m, fn, size, best, set);
        return m;
    }
    static void Format(bool[,] m, bool[,] fn, int size, int mask, Action<int, int, bool> set) {
        int data = (0 << 3) | mask, rem = data;                   // ECC level M = 0b00
        for (int i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >> 9) * 0x537);
        int bits = ((data << 10) | rem) ^ 0x5412;
        Func<int, bool> b = i => ((bits >> i) & 1) != 0;
        for (int i = 0; i <= 5; i++) set(8, i, b(i));
        set(8, 7, b(6)); set(8, 8, b(7)); set(7, 8, b(8));
        for (int i = 9; i < 15; i++) set(14 - i, 8, b(i));
        for (int i = 0; i < 8; i++) set(size - 1 - i, 8, b(i));
        for (int i = 8; i < 15; i++) set(8, size - 15 + i, b(i));
        set(8, size - 8, true);
    }
    static void Mask(bool[,] m, bool[,] fn, int size, int mask) {
        for (int y = 0; y < size; y++) for (int x = 0; x < size; x++) {
            bool inv;
            switch (mask) {
                case 0: inv = (x + y) % 2 == 0; break;
                case 1: inv = y % 2 == 0; break;
                case 2: inv = x % 3 == 0; break;
                case 3: inv = (x + y) % 3 == 0; break;
                case 4: inv = (x / 3 + y / 2) % 2 == 0; break;
                case 5: inv = x * y % 2 + x * y % 3 == 0; break;
                case 6: inv = (x * y % 2 + x * y % 3) % 2 == 0; break;
                default: inv = ((x + y) % 2 + x * y % 3) % 2 == 0; break;
            }
            if (inv && !fn[y, x]) m[y, x] = !m[y, x];
        }
    }
    static int Penalty(bool[,] m, int size) {
        int p = 0, dark = 0;
        for (int y = 0; y < size; y++) {
            int runX = 1, runY = 1;
            for (int x = 0; x < size; x++) {
                if (m[y, x]) dark++;
                if (x > 0) {
                    if (m[y, x] == m[y, x - 1]) { runX++; if (runX == 5) p += 3; else if (runX > 5) p++; } else runX = 1;
                    if (m[x, y] == m[x - 1, y]) { runY++; if (runY == 5) p += 3; else if (runY > 5) p++; } else runY = 1;
                }
                if (x > 0 && y > 0 && m[y, x] == m[y - 1, x] && m[y, x] == m[y, x - 1] && m[y, x] == m[y - 1, x - 1]) p += 3;
            }
        }
        int total = size * size; p += (Math.Abs(dark * 20 - total * 10) + total - 1) / total * 10;
        return p;
    }
    public static Bitmap Draw(string text, int px, Color fg, Color bg) {
        bool[,] m = Encode(text); int n = m.GetLength(0), quiet = 3, cell = Math.Max(1, px / (n + quiet * 2)), full = cell * (n + quiet * 2);
        Bitmap b = new Bitmap(full, full);
        using (Graphics g = Graphics.FromImage(b)) {
            g.Clear(bg);
            using (SolidBrush br = new SolidBrush(fg)) for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) if (m[y, x]) g.FillRectangle(br, (x + quiet) * cell, (y + quiet) * cell, cell, cell);
        }
        return b;
    }
}

class QuickShare {
    public string id; public bool receive; public long until; public int got;
    public List<Offer> files = new List<Offer>();
    public bool Alive { get { return DateTime.UtcNow.Ticks / 10000 < until; } }
}

static class Net {
    // the address a phone on the same Wi‑Fi should use (prefers the interface with a default gateway)
    public static List<string> Addresses() {
        List<string> good = new List<string>(), other = new List<string>();
        try {
            foreach (System.Net.NetworkInformation.NetworkInterface ni in System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces()) {
                if (ni.OperationalStatus != System.Net.NetworkInformation.OperationalStatus.Up) continue;
                if (ni.NetworkInterfaceType == System.Net.NetworkInformation.NetworkInterfaceType.Loopback) continue;
                System.Net.NetworkInformation.IPInterfaceProperties p = ni.GetIPProperties();
                bool gw = false; foreach (System.Net.NetworkInformation.GatewayIPAddressInformation g in p.GatewayAddresses) if (g.Address.AddressFamily == AddressFamily.InterNetwork && !g.Address.Equals(IPAddress.Any)) gw = true;
                string desc = (ni.Description + " " + ni.Name).ToLowerInvariant();
                bool virt = desc.Contains("virtual") || desc.Contains("hyper-v") || desc.Contains("vmware") || desc.Contains("radmin") || desc.Contains("tailscale") || desc.Contains("vpn") || desc.Contains("wsl");
                foreach (System.Net.NetworkInformation.UnicastIPAddressInformation a in p.UnicastAddresses) {
                    if (a.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                    (gw && !virt ? good : other).Add(a.Address.ToString());
                }
            }
        } catch { }
        good.AddRange(other); return good;
    }
    public static string Base() { List<string> a = Addresses(); return "http://" + (a.Count > 0 ? a[0] : "127.0.0.1") + ":" + Server.Port; }
}

// ------------------------------------------------------------------ "find the PC": answers a UDP broadcast from the Android app
static class Discovery {
    public static void Start() {
        System.Threading.Thread t = new System.Threading.Thread(delegate () {
            UdpClient u = null;
            try { u = new UdpClient(new IPEndPoint(IPAddress.Any, Server.Port)); u.EnableBroadcast = true; } catch { return; }
            while (true) {
                try {
                    IPEndPoint from = new IPEndPoint(IPAddress.Any, 0);
                    byte[] d = u.Receive(ref from);
                    if (!Server.Enabled || !Server.IsLocalAddr(from.Address)) continue;
                    if (Encoding.UTF8.GetString(d).Trim() != "valo-link?") continue;
                    byte[] r = Encoding.UTF8.GetBytes("{\"valo\":\"link\",\"name\":\"" + Environment.MachineName.Replace("\"", "") + "\",\"port\":" + Server.Port + "}");
                    u.Send(r, r.Length, from);
                } catch { System.Threading.Thread.Sleep(300); }
            }
        });
        t.IsBackground = true; t.Start();
    }
}

// ------------------------------------------------------------------ small settings file
static class Settings {
    static string FilePath { get { return Path.Combine(Store.Dir, "settings.json"); } }
    public static bool Notify = true, Discover = true;
    public static void Load() {
        try {
            if (!File.Exists(FilePath)) return;
            Dictionary<string, object> j = new System.Web.Script.Serialization.JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(FilePath, Encoding.UTF8));
            if (j.ContainsKey("notify")) Notify = Convert.ToBoolean(j["notify"]);
            if (j.ContainsKey("discover")) Discover = Convert.ToBoolean(j["discover"]);
        } catch { }
    }
    public static void Save() {
        try { Directory.CreateDirectory(Store.Dir); File.WriteAllText(FilePath, new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(new Dictionary<string, object> { { "notify", Notify }, { "discover", Discover } }), Encoding.UTF8); } catch { }
    }
}

// ------------------------------------------------------------------ the QR window
class QrForm : Form {
    QuickShare share; PictureBox pic = new PictureBox(); Label head = new Label(), info = new Label(), url = new Label(), left = new Label();
    Timer t = new Timer(); Button stop = new Button();
    public QrForm(QuickShare s) {
        share = s;
        Text = "valo Link · QR"; Icon = Icons.Ico(64); StartPosition = FormStartPosition.CenterScreen; FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false; MinimizeBox = false;
        AutoScaleMode = AutoScaleMode.Dpi; ClientSize = new Size(380, 560); Font = new Font("Segoe UI", 10f); TopMost = true;
        BackColor = Theme.Bg; ForeColor = Theme.Fg;
        head.Font = new Font("Segoe UI Semibold", 13f); head.SetBounds(20, 14, 340, 28);
        head.Text = s.receive ? "Прийняти з телефона" : "Передати на телефон";
        info.SetBounds(20, 44, 340, 40); info.ForeColor = Theme.Muted;
        info.Text = s.receive ? "Наведіть камеру телефона на код — відкриється сторінка для надсилання файлів і фото." :
                                 "Наведіть камеру телефона на код — відкриється сторінка з файлами: " + s.files.Count + " шт.";
        string link = Net.Base() + "/q/" + s.id;
        pic.SetBounds(30, 92, 320, 320); pic.SizeMode = PictureBoxSizeMode.Zoom;
        pic.Image = Qr.Draw(link, 640, Color.FromArgb(20, 18, 20), Color.White);
        url.SetBounds(20, 420, 340, 40); url.ForeColor = Theme.Accent; url.Text = link; url.Cursor = Cursors.Hand; url.TextAlign = ContentAlignment.MiddleCenter;
        url.Click += delegate { try { Clipboard.SetText(link); url.Text = "Посилання скопійовано"; } catch { } };
        left.SetBounds(20, 462, 340, 22); left.ForeColor = Theme.Muted; left.TextAlign = ContentAlignment.MiddleCenter;
        stop.Text = "Зупинити"; stop.FlatStyle = FlatStyle.Flat; stop.FlatAppearance.BorderSize = 0; stop.SetBounds(130, 500, 120, 36);
        stop.BackColor = Theme.Mix(Theme.Bg, Theme.Fg, .1f); stop.ForeColor = Theme.Fg; stop.Click += delegate { Close(); };
        Controls.AddRange(new Control[] { head, info, pic, url, left, stop });
        t.Interval = 1000; t.Tick += delegate { Tick(); }; t.Start(); Tick();
    }
    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); int dark = 1; Native.DwmSetWindowAttribute(Handle, 20, ref dark, 4); }
    void Tick() {
        long ms = share.until - DateTime.UtcNow.Ticks / 10000;
        if (ms <= 0) { Close(); return; }
        left.Text = "Діє ще " + (ms / 60000) + ":" + ((ms / 1000) % 60).ToString("00") + (share.got > 0 ? (share.receive ? " · отримано: " : " · завантажено: ") + share.got : "");
    }
    protected override void OnFormClosed(FormClosedEventArgs e) { t.Stop(); lock (Server.Shares) Server.Shares.Remove(share.id); base.OnFormClosed(e); }
}
}
