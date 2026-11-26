// valo Link — phone <-> PC companion for valo.os (own take on KDE Connect, no phone app needed: the phone uses a web page).
// Runs inside Windows PowerShell (valo-link.ps1 compiles it with Add-Type): no .exe is shipped or built, so Smart App Control has nothing to block.
//   - small HTTP + WebSocket server on the local network (port 47800), phone page = valo-link-phone.html next to the exe
//   - pairing with a 6-digit code shown in the window; every request needs the device token
//   - files both ways, clipboard both ways, media keys, touchpad + keyboard, lock / sleep, "find my phone", phone battery
// Data: %LOCALAPPDATA%\valo\link\devices.json, received files: Downloads\valo Link
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Web.Script.Serialization;

[assembly: System.Reflection.AssemblyTitle("valo Link")]
[assembly: System.Reflection.AssemblyProduct("valo.os")]

namespace ValoLink {

static class Native {
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint data, flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct INPUT { [FieldOffset(0)] public uint type; [FieldOffset(8)] public MOUSEINPUT mi; [FieldOffset(8)] public KEYBDINPUT ki; }
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] i, int size);
    [DllImport("user32.dll")] public static extern bool LockWorkStation();
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("shell32.dll")] public static extern int SHGetKnownFolderPath(ref Guid id, uint flags, IntPtr token, out IntPtr path);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);

    static int Size { get { return Marshal.SizeOf(typeof(INPUT)); } }
    public static void Mouse(uint flags, int dx, int dy, int data) {
        INPUT[] i = new INPUT[1]; i[0].type = 0; i[0].mi.dx = dx; i[0].mi.dy = dy; i[0].mi.flags = flags; i[0].mi.data = (uint)data;
        SendInput(1, i, Size);
    }
    public static void Key(ushort vk, bool up) {
        INPUT[] i = new INPUT[1]; i[0].type = 1; i[0].ki.vk = vk; i[0].ki.flags = up ? 2u : 0u; SendInput(1, i, Size);
    }
    public static void Tap(params ushort[] keys) { foreach (ushort k in keys) Key(k, false); for (int j = keys.Length - 1; j >= 0; j--) Key(keys[j], true); }
    public static void Text(string s) {
        List<INPUT> l = new List<INPUT>();
        foreach (char c in s) {
            if (c == '\n') { Tap(0x0D); continue; }
            INPUT d = new INPUT(); d.type = 1; d.ki.scan = c; d.ki.flags = 4; l.Add(d);
            INPUT u = new INPUT(); u.type = 1; u.ki.scan = c; u.ki.flags = 6; l.Add(u);
        }
        if (l.Count > 0) SendInput((uint)l.Count, l.ToArray(), Size);
    }
    public static string Downloads() {
        Guid g = new Guid("374DE290-123F-4565-9164-39C4925E467B"); IntPtr p;
        if (SHGetKnownFolderPath(ref g, 0, IntPtr.Zero, out p) == 0) { string s = Marshal.PtrToStringUni(p); Marshal.FreeCoTaskMem(p); return s; }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
    }
}

class Device { public string id, name, token; public long lastSeen; public int battery = -1; public bool charging; }
class Offer { public string id, path, name; public long size; }

static class Store {
    public static string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "valo\\link");
    static string FilePath { get { return Path.Combine(Dir, "devices.json"); } }
    public static List<Device> Devices = new List<Device>();
    public static readonly object Lock = new object();
    static JavaScriptSerializer js = new JavaScriptSerializer();
    public static void Load() {
        try { if (File.Exists(FilePath)) Devices = js.Deserialize<List<Device>>(File.ReadAllText(FilePath, Encoding.UTF8)) ?? new List<Device>(); } catch { Devices = new List<Device>(); }
    }
    public static void Save() {
        lock (Lock) { try { Directory.CreateDirectory(Dir); File.WriteAllText(FilePath, js.Serialize(Devices), Encoding.UTF8); } catch { } }
    }
    public static Device ByToken(string t) {
        if (string.IsNullOrEmpty(t)) return null;
        lock (Lock) { foreach (Device d in Devices) if (FixedEq(d.token, t)) return d; }
        return null;
    }
    static bool FixedEq(string a, string b) { if (a == null || b == null || a.Length != b.Length) return false; int r = 0; for (int i = 0; i < a.Length; i++) r |= a[i] ^ b[i]; return r == 0; }
    public static string Random(int bytes) { byte[] b = new byte[bytes]; using (RandomNumberGenerator g = RandomNumberGenerator.Create()) g.GetBytes(b); return BitConverter.ToString(b).Replace("-", "").ToLowerInvariant(); }
}

// ------------------------------------------------------------------ server
class Server {
    public const int Port = 47800;
    public static string Code = "";
    public static long CodeUntil = 0;
    static int failures = 0;
    public static volatile bool Enabled = true;
    public static List<Offer> Offers = new List<Offer>();
    public static List<WsClient> Clients = new List<WsClient>();
    public static string WebDir;
    public static MainForm Ui;
    static JavaScriptSerializer js = new JavaScriptSerializer();
    TcpListener listener;

    public static void NewCode() { Code = (new Random(Guid.NewGuid().GetHashCode()).Next(0, 1000000)).ToString("000000"); CodeUntil = Environment.TickCount + 10 * 60 * 1000; failures = 0; }

    public void Start() {
        listener = new TcpListener(IPAddress.Any, Port);
        listener.Start();
        Thread t = new Thread(delegate () {
            while (true) {
                try { TcpClient c = listener.AcceptTcpClient(); Thread h = new Thread(Handle); h.IsBackground = true; h.Start(c); } catch { Thread.Sleep(200); }
            }
        });
        t.IsBackground = true; t.Start();
    }

    static string ReadHeaders(NetworkStream s) {
        MemoryStream ms = new MemoryStream(); int n = 0, b;
        while ((b = s.ReadByte()) != -1) {
            ms.WriteByte((byte)b);
            n = (b == '\r' || b == '\n') ? n + 1 : 0;
            if (n == 4 || ms.Length > 32768) break;
        }
        return Encoding.UTF8.GetString(ms.ToArray());
    }
    static void Send(NetworkStream s, int code, string type, byte[] body, string extra) {
        string status = code == 200 ? "OK" : code == 401 ? "Unauthorized" : code == 404 ? "Not Found" : code == 403 ? "Forbidden" : "Error";
        string h = "HTTP/1.1 " + code + " " + status + "\r\nContent-Type: " + type + "\r\nContent-Length: " + body.Length +
                   "\r\nCache-Control: no-store\r\nConnection: close\r\n" + (extra ?? "") + "\r\n";
        byte[] hb = Encoding.UTF8.GetBytes(h);
        s.Write(hb, 0, hb.Length); s.Write(body, 0, body.Length); s.Flush();
    }
    static void Json(NetworkStream s, object o) { Send(s, 200, "application/json; charset=utf-8", Encoding.UTF8.GetBytes(js.Serialize(o)), null); }
    static void Err(NetworkStream s, int code, string msg) { Send(s, code, "application/json; charset=utf-8", Encoding.UTF8.GetBytes(js.Serialize(new Dictionary<string, object> { { "error", msg } })), null); }
    static byte[] ReadBody(NetworkStream s, long len) {
        if (len <= 0) return new byte[0];
        if (len > 4 * 1024 * 1024) throw new Exception("too big");
        byte[] buf = new byte[len]; int got = 0;
        while (got < len) { int r = s.Read(buf, got, (int)(len - got)); if (r <= 0) break; got += r; }
        return buf;
    }
    static string Query(string path, string key) {
        Match m = Regex.Match(path, "[?&]" + key + "=([^&]*)");
        return m.Success ? Uri.UnescapeDataString(m.Groups[1].Value.Replace('+', ' ')) : null;
    }

    void Handle(object o) {
        TcpClient c = (TcpClient)o;
        try {
            c.ReceiveTimeout = 30000;
            NetworkStream s = c.GetStream();
            string head = ReadHeaders(s);
            string[] lines = head.Split(new string[] { "\r\n" }, StringSplitOptions.None);
            string[] rl = lines[0].Split(' ');
            if (rl.Length < 2) { c.Close(); return; }
            string method = rl[0], path = rl[1];
            Dictionary<string, string> h = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            for (int i = 1; i < lines.Length; i++) { int k = lines[i].IndexOf(':'); if (k > 0) h[lines[i].Substring(0, k).Trim()] = lines[i].Substring(k + 1).Trim(); }
            long len = 0; string cl; if (h.TryGetValue("Content-Length", out cl)) long.TryParse(cl, out len);
            string route = path.Split('?')[0];
            IPEndPoint ep = (IPEndPoint)c.Client.RemoteEndPoint;
            if (!Enabled || !IsLocal(ep.Address)) { Err(s, 403, "off"); c.Close(); return; }

            // ---- public: the phone page and pairing
            if (method == "GET" && (route == "/" || route == "/index.html")) { File_(s, "valo-link-phone.html", "text/html; charset=utf-8"); c.Close(); return; }
            if (method == "GET" && route == "/manifest.webmanifest") {
                Send(s, 200, "application/manifest+json", Encoding.UTF8.GetBytes("{\"name\":\"valo Link\",\"short_name\":\"valo Link\",\"start_url\":\"/\",\"display\":\"standalone\",\"background_color\":\"#1e1a1f\",\"theme_color\":\"#1e1a1f\",\"icons\":[{\"src\":\"/icon.png\",\"sizes\":\"192x192\",\"type\":\"image/png\"}]}"), null);
                c.Close(); return;
            }
            if (method == "GET" && route == "/icon.png") { Send(s, 200, "image/png", Icons.Png(192), null); c.Close(); return; }
            if (method == "POST" && route == "/api/pair") {
                Dictionary<string, object> b = js.Deserialize<Dictionary<string, object>>(Encoding.UTF8.GetString(ReadBody(s, len)));
                string code = b.ContainsKey("code") ? Convert.ToString(b["code"]) : "";
                string name = b.ContainsKey("name") ? Convert.ToString(b["name"]) : "Телефон";
                if (failures >= 5 || Environment.TickCount > CodeUntil || code != Code) {
                    failures++; if (failures >= 5) Ui.Note("Забагато невдалих спроб — створіть новий код");
                    Err(s, 401, failures >= 5 ? "Забагато спроб. Створіть новий код на ПК." : "Невірний або застарілий код"); c.Close(); return;
                }
                Device d = new Device(); d.id = Store.Random(6); d.token = Store.Random(32); d.name = name.Length > 40 ? name.Substring(0, 40) : name; d.lastSeen = Now();
                lock (Store.Lock) Store.Devices.Add(d);
                Store.Save(); NewCode(); Ui.Refresh(); Ui.Note("Підключено: " + d.name);
                Json(s, new Dictionary<string, object> { { "token", d.token }, { "pc", Environment.MachineName } });
                c.Close(); return;
            }

            // ---- everything else needs a paired device
            string token; if (!h.TryGetValue("X-Valo-Token", out token)) token = Query(path, "token");
            Device dev = Store.ByToken(token);
            if (dev == null) { Err(s, 401, "Не підключено"); c.Close(); return; }
            dev.lastSeen = Now();

            if (route == "/ws") { WsClient w = new WsClient(c, s, h, dev); lock (Clients) Clients.Add(w); Ui.Refresh(); w.Run(); lock (Clients) Clients.Remove(w); Ui.Refresh(); return; }
            if (method == "GET" && route == "/api/state") {
                List<object> offers = new List<object>();
                lock (Offers) foreach (Offer f in Offers) offers.Add(new Dictionary<string, object> { { "id", f.id }, { "name", f.name }, { "size", f.size } });
                Json(s, new Dictionary<string, object> { { "pc", Environment.MachineName }, { "device", dev.name }, { "offers", offers }, { "theme", Theme.Json() } });
            }
            else if (method == "POST" && route == "/api/clip") {
                string text = Encoding.UTF8.GetString(ReadBody(s, len));
                Ui.Run(delegate { try { Clipboard.SetText(text); } catch { } });
                Ui.Note("Буфер з телефона: " + (text.Length > 40 ? text.Substring(0, 40) + "…" : text));
                Json(s, new Dictionary<string, object> { { "ok", true } });
            }
            else if (method == "GET" && route == "/api/clip") {
                string text = "";
                Ui.RunWait(delegate { try { if (Clipboard.ContainsText()) text = Clipboard.GetText(); } catch { } });
                Json(s, new Dictionary<string, object> { { "text", text } });
            }
            else if (method == "POST" && route == "/api/upload") {
                string name = Path.GetFileName(Query(path, "name") ?? "file");
                name = Regex.Replace(name, "[\\\\/:*?\"<>|]", "_"); if (name.Length == 0) name = "file";
                string dir = Path.Combine(Native.Downloads(), "valo Link"); Directory.CreateDirectory(dir);
                string dst = Path.Combine(dir, name);
                for (int i = 2; File.Exists(dst); i++) dst = Path.Combine(dir, Path.GetFileNameWithoutExtension(name) + " (" + i + ")" + Path.GetExtension(name));
                using (FileStream fs = File.Create(dst)) {
                    byte[] buf = new byte[81920]; long left = len;
                    while (left > 0) { int r = s.Read(buf, 0, (int)Math.Min(buf.Length, left)); if (r <= 0) break; fs.Write(buf, 0, r); left -= r; }
                }
                Ui.Received(dst, dev.name);
                Json(s, new Dictionary<string, object> { { "ok", true }, { "name", Path.GetFileName(dst) } });
            }
            else if (method == "GET" && route.StartsWith("/api/files/")) {
                string id = route.Substring(11); Offer f = null;
                lock (Offers) foreach (Offer x in Offers) if (x.id == id) f = x;
                if (f == null || !File.Exists(f.path)) { Err(s, 404, "Файл недоступний"); }
                else {
                    FileInfo fi = new FileInfo(f.path);
                    string hd = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: " + fi.Length +
                                "\r\nContent-Disposition: attachment; filename*=UTF-8''" + Uri.EscapeDataString(f.name) + "\r\nConnection: close\r\n\r\n";
                    byte[] hb = Encoding.UTF8.GetBytes(hd); s.Write(hb, 0, hb.Length);
                    using (FileStream fs = File.OpenRead(f.path)) fs.CopyTo(s);
                }
            }
            else if (method == "POST" && route == "/api/media") {
                string a = Query(path, "a") ?? "";
                byte vk = a == "play" ? (byte)0xB3 : a == "next" ? (byte)0xB0 : a == "prev" ? (byte)0xB1 : a == "up" ? (byte)0xAF : a == "down" ? (byte)0xAE : a == "mute" ? (byte)0xAD : (byte)0;
                if (vk != 0) { Native.keybd_event(vk, 0, 1, UIntPtr.Zero); Native.keybd_event(vk, 0, 3, UIntPtr.Zero); }
                Json(s, new Dictionary<string, object> { { "ok", vk != 0 } });
            }
            else if (method == "POST" && route == "/api/cmd") {
                string a = Query(path, "a") ?? "";
                Json(s, new Dictionary<string, object> { { "ok", true } });
                if (a == "lock") Native.LockWorkStation();
                else if (a == "sleep") Ui.Run(delegate { Application.SetSuspendState(PowerState.Suspend, false, false); });
                else if (a == "desktop") Native.Tap(0x5B, 0x44);
            }
            else if (method == "POST" && route == "/api/battery") {
                int lv; if (int.TryParse(Query(path, "level"), out lv)) dev.battery = lv;
                dev.charging = Query(path, "charging") == "1";
                Ui.Refresh();
                Json(s, new Dictionary<string, object> { { "ok", true } });
            }
            else Err(s, 404, "?");
        } catch { }
        try { c.Close(); } catch { }
    }
    static long Now() { return DateTime.UtcNow.Ticks / 10000; }
    static bool IsLocal(IPAddress a) {
        if (IPAddress.IsLoopback(a)) return true;
        byte[] b = a.GetAddressBytes();
        if (b.Length == 4) return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168) || (b[0] == 169 && b[1] == 254) || (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
        return a.IsIPv6LinkLocal || a.IsIPv6SiteLocal || (b.Length == 16 && (b[0] & 0xFE) == 0xFC);
    }
    static void File_(NetworkStream s, string name, string type) {
        string p = Path.Combine(WebDir, name);
        if (!File.Exists(p)) { Err(s, 404, "no page"); return; }
        Send(s, 200, type, File.ReadAllBytes(p), null);
    }
    public static void Broadcast(string json) { lock (Clients) foreach (WsClient w in Clients.ToArray()) w.SendText(json); }
}

// ------------------------------------------------------------------ WebSocket (touchpad, keyboard, pushes)
class WsClient {
    TcpClient c; NetworkStream s; public Device Dev;
    static JavaScriptSerializer js = new JavaScriptSerializer();
    readonly object wl = new object();
    public WsClient(TcpClient c, NetworkStream s, Dictionary<string, string> h, Device d) {
        this.c = c; this.s = s; Dev = d;
        string key; h.TryGetValue("Sec-WebSocket-Key", out key);
        string accept;
        using (SHA1 sha = SHA1.Create()) accept = Convert.ToBase64String(sha.ComputeHash(Encoding.ASCII.GetBytes((key ?? "") + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")));
        byte[] r = Encoding.ASCII.GetBytes("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + "\r\n\r\n");
        s.Write(r, 0, r.Length);
        c.ReceiveTimeout = 0;
    }
    byte[] Read(int n) { byte[] b = new byte[n]; int g = 0; while (g < n) { int r = s.Read(b, g, n - g); if (r <= 0) throw new IOException(); g += r; } return b; }
    public void Run() {
        try {
            while (true) {
                byte[] h2 = Read(2);
                int op = h2[0] & 0x0F; bool masked = (h2[1] & 0x80) != 0; long len = h2[1] & 0x7F;
                if (len == 126) { byte[] e = Read(2); len = (e[0] << 8) | e[1]; }
                else if (len == 127) { byte[] e = Read(8); len = 0; for (int i = 0; i < 8; i++) len = (len << 8) | e[i]; }
                if (len > 65536) break;
                byte[] mask = masked ? Read(4) : null;
                byte[] p = Read((int)len);
                if (masked) for (int i = 0; i < p.Length; i++) p[i] ^= mask[i % 4];
                if (op == 8) { Frame(8, new byte[0]); break; }
                if (op == 9) { Frame(10, p); continue; }
                if (op == 1) OnMessage(Encoding.UTF8.GetString(p));
            }
        } catch { }
        try { c.Close(); } catch { }
    }
    void Frame(int op, byte[] p) {
        lock (wl) {
            MemoryStream m = new MemoryStream();
            m.WriteByte((byte)(0x80 | op));
            if (p.Length < 126) m.WriteByte((byte)p.Length);
            else if (p.Length < 65536) { m.WriteByte(126); m.WriteByte((byte)(p.Length >> 8)); m.WriteByte((byte)p.Length); }
            else { m.WriteByte(127); for (int i = 7; i >= 0; i--) m.WriteByte((byte)((long)p.Length >> (8 * i))); }
            m.Write(p, 0, p.Length);
            byte[] a = m.ToArray();
            try { s.Write(a, 0, a.Length); } catch { }
        }
    }
    public void SendText(string t) { Frame(1, Encoding.UTF8.GetBytes(t)); }
    static readonly Dictionary<string, ushort> Keys = new Dictionary<string, ushort> {
        { "Enter", 0x0D }, { "Backspace", 0x08 }, { "Tab", 0x09 }, { "Escape", 0x1B }, { "Space", 0x20 }, { "Delete", 0x2E },
        { "ArrowLeft", 0x25 }, { "ArrowUp", 0x26 }, { "ArrowRight", 0x27 }, { "ArrowDown", 0x28 }, { "Home", 0x24 }, { "End", 0x23 },
        { "PageUp", 0x21 }, { "PageDown", 0x22 }, { "F5", 0x74 }, { "Win", 0x5B }, { "AltTab", 0 }, { "Copy", 0 }, { "Paste", 0 }, { "Undo", 0 } };
    void OnMessage(string t) {
        Dictionary<string, object> m;
        try { m = js.Deserialize<Dictionary<string, object>>(t); } catch { return; }
        string k = m.ContainsKey("t") ? Convert.ToString(m["t"]) : "";
        if (k == "m") Native.Mouse(0x0001, Convert.ToInt32(m["x"]), Convert.ToInt32(m["y"]), 0);
        else if (k == "c") {
            string b = Convert.ToString(m["b"]);
            if (b == "r") { Native.Mouse(0x0008, 0, 0, 0); Native.Mouse(0x0010, 0, 0, 0); }
            else if (b == "d") { Native.Mouse(0x0002, 0, 0, 0); }        // drag start
            else if (b == "u") { Native.Mouse(0x0004, 0, 0, 0); }        // drag end
            else { Native.Mouse(0x0002, 0, 0, 0); Native.Mouse(0x0004, 0, 0, 0); }
        }
        else if (k == "s") Native.Mouse(0x0800, 0, 0, -Convert.ToInt32(m["y"]));
        else if (k == "txt") Native.Text(Convert.ToString(m["v"]));
        else if (k == "k") {
            string n = Convert.ToString(m["v"]);
            if (n == "AltTab") Native.Tap(0x12, 0x09);
            else if (n == "Copy") Native.Tap(0x11, 0x43);
            else if (n == "Paste") Native.Tap(0x11, 0x56);
            else if (n == "Undo") Native.Tap(0x11, 0x5A);
            else { ushort vk; if (Keys.TryGetValue(n, out vk) && vk != 0) Native.Tap(vk); }
        }
        else if (k == "hello") { Dev.lastSeen = DateTime.UtcNow.Ticks / 10000; Server.Ui.Refresh(); }
    }
}

// ------------------------------------------------------------------ theme from valo.os (written by the dock helper)
static class Theme {
    public static Color Bg = Color.FromArgb(30, 26, 31), Fg = Color.FromArgb(245, 230, 234), Accent = Color.FromArgb(242, 167, 187), Muted = Color.FromArgb(156, 138, 147);
    static DateTime stamp;
    public static bool Load() {
        try {
            string p = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "valo\\theme.json");
            if (!File.Exists(p)) return false;
            DateTime w = File.GetLastWriteTimeUtc(p); if (w == stamp) return false; stamp = w;
            Dictionary<string, object> j = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(File.ReadAllText(p));
            Bg = ColorTranslator.FromHtml(Convert.ToString(j["bg"])); Fg = ColorTranslator.FromHtml(Convert.ToString(j["fg"]));
            Accent = ColorTranslator.FromHtml(Convert.ToString(j["accent"])); Muted = ColorTranslator.FromHtml(Convert.ToString(j["muted"]));
            return true;
        } catch { return false; }
    }
    public static Color Mix(Color a, Color b, float t) { return Color.FromArgb((int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t)); }
    static string Hex(Color c) { return "#" + c.R.ToString("x2") + c.G.ToString("x2") + c.B.ToString("x2"); }
    public static Dictionary<string, object> Json() { return new Dictionary<string, object> { { "bg", Hex(Bg) }, { "fg", Hex(Fg) }, { "accent", Hex(Accent) }, { "muted", Hex(Muted) } }; }
}

// ------------------------------------------------------------------ icons: the valo.os mark with a link badge
static class Icons {
    static GraphicsPath Blade() {
        GraphicsPath p = new GraphicsPath();
        p.AddBezier(0f, -130f, 1f, -62f, 3f, -38f, 23f, -23f);
        p.AddBezier(23f, -23f, 12f, -30f, 4f, -28f, 0f, -23f);
        p.AddBezier(0f, -23f, -4f, -28f, -12f, -30f, -23f, -23f);
        p.AddBezier(-23f, -23f, -3f, -38f, -1f, -62f, 0f, -130f);
        p.CloseFigure(); return p;
    }
    public static Bitmap Draw(int size) {
        Bitmap b = new Bitmap(size, size);
        using (Graphics g = Graphics.FromImage(b)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (GraphicsPath r = Round(new RectangleF(0, 0, size - 1, size - 1), size * 0.22f)) using (SolidBrush bb = new SolidBrush(Theme.Accent)) g.FillPath(bb, r);
            float k = size / 300f;
            g.TranslateTransform(size / 2f, size / 2f + 14 * k); g.ScaleTransform(k, k);
            using (SolidBrush ink = new SolidBrush(Theme.Bg)) {
                for (int i = 0; i < 3; i++) { using (GraphicsPath bl = Blade()) g.FillPath(ink, bl); g.RotateTransform(120); }
                foreach (PointF c in new PointF[] { new PointF(0, 12), new PointF(10.4f, -6), new PointF(-10.4f, -6) }) g.FillEllipse(ink, c.X - 12.5f, c.Y - 12.5f, 25, 25);
            }
        }
        return b;
    }
    static GraphicsPath Round(RectangleF r, float rad) {
        GraphicsPath p = new GraphicsPath(); float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90); p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure(); return p;
    }
    public static byte[] Png(int size) { using (Bitmap b = Draw(size)) using (MemoryStream m = new MemoryStream()) { b.Save(m, System.Drawing.Imaging.ImageFormat.Png); return m.ToArray(); } }
    public static Icon Ico(int size) { using (Bitmap b = Draw(size)) return Icon.FromHandle(b.GetHicon()); }
}

// ------------------------------------------------------------------ window + tray
class MainForm : Form {
    NotifyIcon tray = new NotifyIcon();
    Label title = new Label(), status = new Label(), codeL = new Label(), codeHint = new Label(), addr = new Label(), devHead = new Label();
    ListBox devs = new ListBox();
    FlowLayoutPanel buttons = new FlowLayoutPanel();
    CheckBox enabled = new CheckBox();
    System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
    bool quitting = false;

    public MainForm() {
        Text = "valo Link"; Icon = Icons.Ico(64); StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false; AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(440, 600); Font = new Font("Segoe UI", 10f);
        title.Text = "valo Link"; title.Font = new Font("Gabriola", 30f); title.AutoSize = true; title.Location = new Point(24, 8);
        status.AutoSize = false; status.SetBounds(28, 70, 390, 22);
        codeHint.Text = "Код для підключення телефона:"; codeHint.SetBounds(28, 104, 390, 22);
        codeL.Font = new Font("Segoe UI Semibold", 30f); codeL.SetBounds(24, 126, 300, 56); codeL.Cursor = Cursors.Hand;
        addr.SetBounds(28, 186, 390, 66);
        devHead.Text = "ПІДКЛЮЧЕНІ ПРИСТРОЇ"; devHead.Font = new Font("Segoe UI Semibold", 8.5f); devHead.SetBounds(28, 262, 390, 20);
        devs.SetBounds(24, 284, 392, 150); devs.BorderStyle = BorderStyle.None; devs.DrawMode = DrawMode.OwnerDrawFixed; devs.ItemHeight = 44; devs.DrawItem += DrawDev;
        enabled.Text = "Доступ з телефона увімкнено"; enabled.Checked = true; enabled.SetBounds(28, 442, 390, 24);
        enabled.CheckedChanged += delegate { Server.Enabled = enabled.Checked; Refresh(); };
        buttons.SetBounds(20, 474, 400, 120); buttons.FlowDirection = FlowDirection.LeftToRight;
        AddBtn("Надіслати файл", delegate { SendFiles(null); });
        AddBtn("Надіслати буфер", delegate { try { if (Clipboard.ContainsText()) { Server.Broadcast(new JavaScriptSerializer().Serialize(new Dictionary<string, object> { { "t", "clip" }, { "v", Clipboard.GetText() } })); Note("Буфер надіслано на телефон"); } } catch { } });
        AddBtn("Знайти телефон", delegate { Server.Broadcast("{\"t\":\"ring\"}"); Note("Телефон дзвонить (якщо сторінка valo Link відкрита)"); });
        AddBtn("Отримані файли", delegate { string d = Path.Combine(Native.Downloads(), "valo Link"); Directory.CreateDirectory(d); Process.Start("explorer.exe", "\"" + d + "\""); });
        AddBtn("Новий код", delegate { Server.NewCode(); Refresh(); });
        AddBtn("Відключити", delegate { RemoveSelected(); });
        codeL.Click += delegate { Server.NewCode(); Refresh(); };
        Controls.AddRange(new Control[] { title, status, codeHint, codeL, addr, devHead, devs, enabled, buttons });
        AllowDrop = true;
        DragEnter += delegate (object o, DragEventArgs e) { if (e.Data.GetDataPresent(DataFormats.FileDrop)) e.Effect = DragDropEffects.Copy; };
        DragDrop += delegate (object o, DragEventArgs e) { SendFiles((string[])e.Data.GetData(DataFormats.FileDrop)); };

        tray.Icon = Icons.Ico(32); tray.Text = "valo Link"; tray.Visible = true;
        ContextMenuStrip menu = new ContextMenuStrip();
        menu.Items.Add("Відкрити valo Link", null, delegate { ShowUi(); });
        menu.Items.Add("Надіслати файл на телефон…", null, delegate { SendFiles(null); });
        menu.Items.Add("Отримані файли", null, delegate { string d = Path.Combine(Native.Downloads(), "valo Link"); Directory.CreateDirectory(d); Process.Start("explorer.exe", "\"" + d + "\""); });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Вийти", null, delegate { quitting = true; tray.Visible = false; Application.Exit(); });
        tray.ContextMenuStrip = menu;
        tray.DoubleClick += delegate { ShowUi(); };

        timer.Interval = 4000; timer.Tick += delegate { if (Theme.Load()) ApplyTheme(); Refresh(); }; timer.Start();
        ApplyTheme(); Refresh();
    }
    void AddBtn(string text, EventHandler h) {
        Button b = new Button(); b.Text = text; b.FlatStyle = FlatStyle.Flat; b.FlatAppearance.BorderSize = 0; b.SetBounds(0, 0, 126, 34);
        b.Margin = new Padding(4); b.Cursor = Cursors.Hand; b.Click += h; buttons.Controls.Add(b);
    }
    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); int dark = 1; Native.DwmSetWindowAttribute(Handle, 20, ref dark, 4); }
    void ApplyTheme() {
        BackColor = Theme.Bg; ForeColor = Theme.Fg;
        title.ForeColor = Theme.Accent; codeL.ForeColor = Theme.Accent;
        foreach (Label l in new Label[] { status, codeHint, addr, devHead }) l.ForeColor = Theme.Muted;
        devs.BackColor = Theme.Mix(Theme.Bg, Theme.Fg, .05f); devs.ForeColor = Theme.Fg; enabled.ForeColor = Theme.Fg;
        foreach (Control c in buttons.Controls) { c.BackColor = Theme.Mix(Theme.Bg, Theme.Fg, .1f); c.ForeColor = Theme.Fg; }
        int bc = Theme.Accent.R | (Theme.Accent.G << 8) | (Theme.Accent.B << 16); Native.DwmSetWindowAttribute(Handle, 34, ref bc, 4);
        tray.Icon = Icons.Ico(32); Icon = Icons.Ico(64);
        Invalidate(true);
    }
    public new void Refresh() {
        if (InvokeRequired) { try { BeginInvoke(new Action(Refresh)); } catch { } return; }
        int clients; lock (Server.Clients) clients = Server.Clients.Count;
        status.Text = Server.Enabled ? "Працює · порт " + Server.Port + " · на зв'язку зараз: " + clients : "Вимкнено — телефони не можуть під'єднатися";
        if (Environment.TickCount > Server.CodeUntil) Server.NewCode();
        codeL.Text = Server.Code.Substring(0, 3) + " " + Server.Code.Substring(3);
        List<string> ips = new List<string>();
        try { foreach (IPAddress a in Dns.GetHostAddresses(Dns.GetHostName())) if (a.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(a)) ips.Add("http://" + a + ":" + Server.Port); } catch { }
        addr.Text = "На телефоні в тій самій Wi‑Fi мережі відкрийте:\n" + (ips.Count > 0 ? string.Join("\n", ips.ToArray()) : "(немає мережі)");
        int sel = devs.SelectedIndex;
        devs.BeginUpdate(); devs.Items.Clear();
        lock (Store.Lock) foreach (Device d in Store.Devices) devs.Items.Add(d);
        if (devs.Items.Count == 0) devs.Items.Add("Ще немає підключених телефонів");
        devs.EndUpdate();
        if (sel >= 0 && sel < devs.Items.Count) devs.SelectedIndex = sel;
    }
    void DrawDev(object o, DrawItemEventArgs e) {
        if (e.Index < 0) return;
        bool selected = (e.State & DrawItemState.Selected) != 0;
        using (SolidBrush b = new SolidBrush(selected ? Theme.Mix(Theme.Bg, Theme.Accent, .25f) : devs.BackColor)) e.Graphics.FillRectangle(b, e.Bounds);
        object it = devs.Items[e.Index];
        Device d = it as Device;
        if (d == null) { TextRenderer.DrawText(e.Graphics, it.ToString(), Font, e.Bounds, Theme.Muted, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter); return; }
        bool online = false; lock (Server.Clients) foreach (WsClient w in Server.Clients) if (w.Dev == d) online = true;
        long ago = (DateTime.UtcNow.Ticks / 10000 - d.lastSeen) / 60000;
        string sub = (online ? "на зв'язку" : ago < 1 ? "щойно" : ago < 60 ? ago + " хв тому" : ago < 1440 ? (ago / 60) + " год тому" : (ago / 1440) + " дн тому") +
                     (d.battery >= 0 ? " · батарея " + d.battery + "%" + (d.charging ? " ⚡" : "") : "");
        TextRenderer.DrawText(e.Graphics, "📱  " + d.name, Font, new Rectangle(e.Bounds.X + 10, e.Bounds.Y + 4, e.Bounds.Width - 20, 20), Theme.Fg, TextFormatFlags.Left);
        TextRenderer.DrawText(e.Graphics, sub, new Font("Segoe UI", 8.5f), new Rectangle(e.Bounds.X + 34, e.Bounds.Y + 23, e.Bounds.Width - 40, 18), online ? Theme.Accent : Theme.Muted, TextFormatFlags.Left);
    }
    void RemoveSelected() {
        Device d = devs.SelectedItem as Device; if (d == null) return;
        if (MessageBox.Show(this, "Відключити «" + d.name + "»? Телефону доведеться підключитися знову з новим кодом.", "valo Link", MessageBoxButtons.YesNo) != DialogResult.Yes) return;
        lock (Store.Lock) Store.Devices.Remove(d);
        Store.Save(); Refresh();
    }
    void SendFiles(string[] files) {
        if (files == null) {
            using (OpenFileDialog dlg = new OpenFileDialog()) { dlg.Multiselect = true; dlg.Title = "Файли для телефона"; if (dlg.ShowDialog(this) != DialogResult.OK) return; files = dlg.FileNames; }
        }
        lock (Server.Offers) foreach (string f in files) {
            if (!File.Exists(f)) continue;
            Offer o = new Offer(); o.id = Store.Random(8); o.path = f; o.name = Path.GetFileName(f); o.size = new FileInfo(f).Length;
            Server.Offers.Insert(0, o);
            if (Server.Offers.Count > 30) Server.Offers.RemoveAt(Server.Offers.Count - 1);
        }
        Server.Broadcast("{\"t\":\"files\"}");
        Note("Файли чекають на телефоні у вкладці «Файли»");
    }
    public void Received(string path, string from) {
        Run(delegate {
            tray.BalloonTipTitle = "valo Link · " + from; tray.BalloonTipText = "Отримано: " + Path.GetFileName(path) + "\nклік — відкрити папку";
            tray.Tag = path; tray.ShowBalloonTip(4000);
        });
    }
    public void Note(string text) { Run(delegate { tray.BalloonTipTitle = "valo Link"; tray.BalloonTipText = text; tray.Tag = null; tray.ShowBalloonTip(3000); }); }
    public void Run(Action a) { try { if (IsHandleCreated) BeginInvoke(a); } catch { } }
    public void RunWait(Action a) { try { if (IsHandleCreated) Invoke(a); } catch { } }
    public void ShowFromOutside() { ShowUi(); }
    void ShowUi() { Show(); WindowState = FormWindowState.Normal; Activate(); Native.SetForegroundWindow(Handle); }
    protected override void OnFormClosing(FormClosingEventArgs e) { if (!quitting && e.CloseReason == CloseReason.UserClosing) { e.Cancel = true; Hide(); } else base.OnFormClosing(e); }
    protected override void SetVisibleCore(bool v) { if (!IsHandleCreated) { CreateHandle(); v = !Program.Hidden; } base.SetVisibleCore(v); }
    public void Wire() {
        tray.BalloonTipClicked += delegate { string p = tray.Tag as string; if (p != null && File.Exists(p)) Process.Start("explorer.exe", "/select,\"" + p + "\""); };
    }
}

public static class Program {
    public static bool Hidden = false;
    public static string WebDir;
    [STAThread]
    public static void Main(string[] args) {
        bool created; Mutex m = new Mutex(true, "valo-link-single", out created);
        if (!created) { try { EventWaitHandle.OpenExisting("valo-link-show").Set(); } catch { } return; }   // already running: bring its window up
        Hidden = Array.IndexOf(args, "--hidden") >= 0;
        Application.EnableVisualStyles();
        Theme.Load(); Store.Load(); Server.NewCode();
        Server.WebDir = WebDir ?? Path.GetDirectoryName(Application.ExecutablePath);
        MainForm f = new MainForm(); Server.Ui = f; f.Wire();
        EventWaitHandle showEv = new EventWaitHandle(false, EventResetMode.AutoReset, "valo-link-show");
        Thread sw = new Thread(delegate () { while (true) { showEv.WaitOne(); f.Run(delegate { f.ShowFromOutside(); }); } }); sw.IsBackground = true; sw.Start();
        try { new Server().Start(); }
        catch (Exception e) { MessageBox.Show("Не вдалося запустити сервер на порту " + Server.Port + ":\n" + e.Message, "valo Link"); }
        Application.Run(f);
        GC.KeepAlive(m);
    }
}
}
