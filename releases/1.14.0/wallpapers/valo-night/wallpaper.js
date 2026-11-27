// valo.os live wallpaper for Lively Wallpaper: one animated scene per panel theme, palette shared with the Zebar themes.
// Lively properties (LivelyProperties.json): theme (dropdown index), speed, density, mark, clock, parallax, audio.
// With "--audio" in LivelyInfo Arguments the scene reacts to music: faster motion, the mark and a bottom glow pulse with the bass.
(() => {
  'use strict';

  // same order and colours as zebar\quill\themes.js
  const THEMES = [
    { id: 'sakura',   c: { solid: '#1e1a1f', chip: '#2a2329', hi: '#3a2f37', accent: '#f2a7bb', accent2: '#e07a96', text: '#f5e6ea', muted: '#9c8a93' } },
    { id: 'night',    c: { solid: '#1a1b26', chip: '#24283b', hi: '#2f3549', accent: '#7aa2f7', accent2: '#bb9af7', text: '#c0caf5', muted: '#737aa2' } },
    { id: 'matcha',   c: { solid: '#1e231e', chip: '#283028', hi: '#34402f', accent: '#a7c080', accent2: '#dbbc7f', text: '#e6e2cc', muted: '#859289' } },
    { id: 'latte',    c: { solid: '#efeae4', chip: '#e2d9cf', hi: '#d6cabd', accent: '#b4637a', accent2: '#d7827e', text: '#3b2f2f', muted: '#8a7a72' }, light: true },
    { id: 'graphite', c: { solid: '#121212', chip: '#222222', hi: '#2e2e2e', accent: '#e6e6e6', accent2: '#9a9a9a', text: '#f0f0f0', muted: '#8a8a8a' } },
    { id: 'sunset',   c: { solid: '#24161c', chip: '#3a2229', hi: '#4a2c34', accent: '#ff9e64', accent2: '#f7768e', text: '#ffe8d6', muted: '#b08a80' } },
  ];

  const startTheme = Math.max(0, THEMES.findIndex(t => t.id === (window.VALO_THEME || 'sakura')));
  const P = { theme: startTheme, speed: 100, density: 100, mark: true, clock: false, parallax: true, audio: true };
  const A = { bass: 0, level: 0, sb: 0, sl: 0 };   // raw and smoothed music levels

  const cv = document.getElementById('c');
  const ctx = cv.getContext('2d');
  let W = 0, H = 0, M = 0, S = 1;               // size, min side, scale vs 1080p
  let theme = THEMES[P.theme], scene = null;
  const mouse = { x: 0.5, y: 0.5 }, pm = { x: 0.5, y: 0.5 };

  // ---------- helpers
  const rnd = (a, b) => a + Math.random() * (b - a);
  const pick = a => a[Math.floor(Math.random() * a.length)];
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  function rgb(hex) { const n = parseInt(hex.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
  function rgba(hex, a) { const [r, g, b] = rgb(hex); return `rgba(${r},${g},${b},${a})`; }
  function mix(h1, h2, t) { const a = rgb(h1), b = rgb(h2); return '#' + a.map((v, i) => Math.round(v + (b[i] - v) * t).toString(16).padStart(2, '0')).join(''); }
  function canvas(w, h) { const c = document.createElement('canvas'); c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h)); return c; }
  const count = n => Math.round(n * (P.density / 100) * Math.max(0.35, (W * H) / (1920 * 1080)));
  const par = depth => P.parallax ? { x: (pm.x - 0.5) * -40 * depth * S, y: (pm.y - 0.5) * -24 * depth * S } : { x: 0, y: 0 };
  function ridge(seed, amp, base, freq) {        // smooth random horizon line: array of [x, y]
    const ph = [rnd(0, 6), rnd(0, 6), rnd(0, 6)], pts = [];
    for (let x = -60; x <= W + 60; x += 12) {
      const u = x / W * freq;
      pts.push([x, base - amp * (0.55 * Math.sin(u * 2.1 + ph[0] + seed) + 0.3 * Math.sin(u * 5.3 + ph[1]) + 0.15 * Math.sin(u * 11.7 + ph[2]))]);
    }
    return pts;
  }
  function fillRidge(g, pts, color, dx = 0, dy = 0) {
    g.beginPath(); g.moveTo(pts[0][0] + dx, H + 60);
    for (const [x, y] of pts) g.lineTo(x + dx, y + dy);
    g.lineTo(pts[pts.length - 1][0] + dx, H + 60); g.closePath(); g.fillStyle = color; g.fill();
  }
  function vgrad(stops) { const g = ctx.createLinearGradient(0, 0, 0, H); for (const [o, c] of stops) g.addColorStop(o, c); return g; }
  function glow(x, y, r, color, a) {
    const g = ctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, rgba(color, a)); g.addColorStop(1, rgba(color, 0));
    ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
  }

  // ---------- valo.os mark (three-blade shuriken + trefoil), cached per colour / size
  const BLADE = new Path2D('M0 -130 C 1 -62, 3 -38, 23 -23 C 17 -27, 12 -29, 9 -29 A 14 14 0 0 0 0 -23 A 14 14 0 0 0 -9 -29 C -12 -29, -17 -27, -23 -23 C -3 -38, -1 -62, 0 -130 Z');
  let markCache = null, markKey = '';
  function markImage(size, color) {
    const key = size + color;
    if (key === markKey) return markCache;
    const c = canvas(size, size), g = c.getContext('2d'), k = size / 280;
    g.translate(size / 2, size / 2 + 12 * k); g.scale(k, k); g.fillStyle = color;
    for (const r of [0, 120, 240]) { g.save(); g.rotate(r * Math.PI / 180); g.fill(BLADE); g.restore(); }
    for (const [x, y] of [[0, 12], [10.4, -6], [-10.4, -6]]) { g.beginPath(); g.arc(x, y, 12.5, 0, Math.PI * 2); g.fill(); }
    g.globalCompositeOperation = 'destination-out'; g.strokeStyle = '#000'; g.lineWidth = 3; g.lineCap = 'round';
    for (const [x, y] of [[0, -14], [12.1, 7], [-12.1, 7]]) { g.beginPath(); g.moveTo(0, 0); g.lineTo(x, y); g.stroke(); }
    markCache = c; markKey = key; return c;
  }
  function drawMark(x, y, size, color, alpha) {
    if (!P.mark) return;
    const img = markImage(Math.round(size), color);
    ctx.globalAlpha = Math.min(1, alpha * (1 + A.sb * 2.2)); ctx.drawImage(img, x - size / 2, y - size / 2); ctx.globalAlpha = 1;
  }

  // ======================================================================== scenes
  const SCENES = {};

  // ---------- Сакура: night sky, moon, hills, a blossoming branch, falling petals
  SCENES.sakura = c => {
    let hills, branch, petals;
    const petalColors = [c.accent, c.accent2, '#ffd9e3', mix(c.accent, '#ffffff', 0.35)];
    function makeBranch() {
      const img = canvas(W * 0.7, H * 0.75), g = img.getContext('2d');
      g.lineCap = 'round';
      const wood = mix('#4a3036', c.hi, 0.35), blossoms = [];
      (function grow(x, y, ang, len, w, d) {
        const x2 = x + Math.cos(ang) * len, y2 = y + Math.sin(ang) * len;
        g.strokeStyle = wood; g.lineWidth = w;
        g.beginPath(); g.moveTo(x, y);
        g.quadraticCurveTo((x + x2) / 2 + rnd(-8, 8) * S, (y + y2) / 2 + rnd(-8, 8) * S, x2, y2); g.stroke();
        if (d >= 4) for (let i = 0; i < 2 + d; i++) blossoms.push([x2 + rnd(-24, 24) * S, y2 + rnd(-18, 18) * S, rnd(3, 7) * S]);
        if (d >= 8 || len < 12 * S) return;
        grow(x2, y2, ang + rnd(-0.55, -0.15), len * rnd(0.68, 0.8), w * 0.7, d + 1);
        if (Math.random() < 0.85) grow(x2, y2, ang + rnd(0.15, 0.6), len * rnd(0.6, 0.78), w * 0.68, d + 1);
      })(-30 * S, H * 0.02, 0.32, M * 0.26, 26 * S, 0);
      for (const [x, y, r] of blossoms) {
        g.fillStyle = rgba(pick(petalColors), rnd(0.55, 0.95));
        for (let k = 0; k < 5; k++) { const a = k * 1.2566 + r; g.beginPath(); g.ellipse(x + Math.cos(a) * r * 0.9, y + Math.sin(a) * r * 0.9, r, r * 0.62, a, 0, Math.PI * 2); g.fill(); }
        g.fillStyle = rgba('#fff3c4', 0.8); g.beginPath(); g.arc(x, y, r * 0.35, 0, Math.PI * 2); g.fill();
      }
      return img;
    }
    function petal(spread) {
      const z = rnd(0.35, 1);
      return { x: rnd(-0.1, 1.1) * W, y: spread ? rnd(-0.1, 1) * H : rnd(-0.25, -0.02) * H, z, s: rnd(7, 13) * z * S,
        r: rnd(0, 6.28), vr: rnd(-1.6, 1.6), vy: rnd(28, 60) * z * S, vx: rnd(8, 30) * z * S, ph: rnd(0, 6.28), col: pick(petalColors) };
    }
    return {
      init() {
        hills = [ridge(1, H * 0.07, H * 0.74, 1.6), ridge(2, H * 0.06, H * 0.8, 2.3), ridge(3, H * 0.05, H * 0.88, 3.1)];
        branch = makeBranch();
        petals = Array.from({ length: count(120) }, () => petal(true));
      },
      draw(t, dt) {
        ctx.fillStyle = vgrad([[0, mix(c.solid, '#000000', 0.45)], [0.55, c.solid], [1, mix(c.solid, c.accent2, 0.22)]]); ctx.fillRect(0, 0, W, H);
        const p0 = par(0.2), mx = W * 0.76 + p0.x, my = H * 0.25 + p0.y, mr = M * 0.085;
        glow(mx, my, mr * 5, c.accent, 0.12);
        ctx.fillStyle = mix(c.text, c.accent, 0.15); ctx.beginPath(); ctx.arc(mx, my, mr, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = rgba(c.solid, 0.08); ctx.beginPath(); ctx.arc(mx - mr * 0.3, my - mr * 0.2, mr * 0.25, 0, Math.PI * 2); ctx.arc(mx + mr * 0.35, my + mr * 0.3, mr * 0.18, 0, Math.PI * 2); ctx.fill();
        drawMark(W / 2 + par(0.3).x, H * 0.47 + par(0.3).y, M * 0.34, c.accent, 0.06);
        const cols = [mix(c.solid, c.hi, 0.8), mix(c.solid, c.chip, 0.6), mix(c.solid, '#000000', 0.25)];
        hills.forEach((h, i) => { const p = par(0.3 + i * 0.3); fillRidge(ctx, h, cols[i], p.x, p.y); });
        const pb = par(0.9); ctx.drawImage(branch, pb.x - 10 * S, pb.y - 10 * S);
        for (const q of petals) {
          q.y += q.vy * dt; q.x += (q.vx + Math.sin(t * 1.3 + q.ph) * 26 * q.z * S) * dt; q.r += q.vr * dt;
          if (q.y > H + 20 || q.x > W + 40) Object.assign(q, petal(false));
          const p = par(q.z); ctx.save(); ctx.translate(q.x + p.x, q.y + p.y); ctx.rotate(q.r); ctx.scale(1, 0.55 + 0.45 * Math.abs(Math.sin(t * 2 + q.ph)));
          ctx.fillStyle = rgba(q.col, 0.45 + 0.45 * q.z);
          ctx.beginPath(); ctx.moveTo(0, -q.s); ctx.quadraticCurveTo(q.s * 0.95, -q.s * 0.2, 0, q.s); ctx.quadraticCurveTo(-q.s * 0.95, -q.s * 0.2, 0, -q.s); ctx.fill();
          ctx.restore();
        }
      },
    };
  };

  // ---------- Нічне місто: neon skyline, flickering windows, rain
  SCENES.night = c => {
    let layers, stars, drops, beacons;
    function skyline(depth) {
      const img = canvas(W + 120 * S, H), g = img.getContext('2d');
      const base = H * (0.62 + depth * 0.1), body = mix(c.solid, '#000000', 0.15 + depth * 0.3);
      const winCols = [c.accent, c.accent2, '#ffd59a', c.text], wins = [];
      let x = -20;
      while (x < img.width) {
        const bw = rnd(40, 120) * S * (0.7 + depth * 0.5), bh = rnd(0.12, 0.42) * H * (1.15 - depth * 0.35);
        g.fillStyle = body; g.fillRect(x, base - bh, bw, H - base + bh);
        if (Math.random() < 0.3) { g.fillRect(x + bw * 0.45, base - bh - 26 * S, 2 * S, 26 * S); beacons.push([x + bw * 0.45 + S, base - bh - 26 * S, depth, rnd(0, 6)]); }
        const ww = 3.5 * S * (0.8 + depth), wh = 5 * S * (0.8 + depth);
        for (let wy = base - bh + 10 * S; wy < base - 8 * S; wy += wh * 2.2)
          for (let wx = x + 6 * S; wx < x + bw - ww - 4 * S; wx += ww * 2.4)
            if (Math.random() < 0.28 + depth * 0.1) { const col = pick(winCols); g.fillStyle = rgba(col, rnd(0.35, 0.9)); g.fillRect(wx, wy, ww, wh); wins.push([wx, wy, ww, wh, col]); }
        g.fillStyle = rgba(depth > 0.5 ? c.accent2 : c.accent, 0.5); g.fillRect(x, base - bh, bw, 1.5 * S);
        x += bw + rnd(2, 14) * S;
      }
      return { img, g, wins, body, depth };
    }
    function drop() { return { x: rnd(-0.1, 1.1) * W, y: rnd(-1, 1) * H, l: rnd(10, 26) * S, v: rnd(700, 1100) * S, z: rnd(0.4, 1) }; }
    return {
      init() {
        beacons = [];
        layers = [skyline(0), skyline(0.5), skyline(1)];
        stars = Array.from({ length: count(140) }, () => [rnd(0, W), rnd(0, H * 0.55), rnd(0.4, 1.4) * S, rnd(0, 6)]);
        drops = Array.from({ length: count(160) }, drop);
      },
      draw(t, dt) {
        ctx.fillStyle = vgrad([[0, mix(c.solid, '#000000', 0.5)], [0.6, c.solid], [0.85, mix(c.solid, c.accent2, 0.3)], [1, c.solid]]); ctx.fillRect(0, 0, W, H);
        for (const [x, y, r, ph] of stars) { ctx.fillStyle = rgba(c.text, 0.25 + 0.35 * Math.abs(Math.sin(t * 0.8 + ph))); ctx.fillRect(x, y, r, r); }
        const pg = par(0.15); glow(W * 0.5 + pg.x, H * 0.72, M * 0.9, c.accent2, 0.16); glow(W * 0.2 + pg.x, H * 0.75, M * 0.5, c.accent, 0.1);
        drawMark(W / 2 + par(0.25).x, H * 0.36 + par(0.25).y, M * 0.3, c.accent, 0.07);
        for (const L of layers) {
          if (Math.random() < 0.08 && L.wins.length) {     // a window switches on/off now and then
            const w = pick(L.wins); const on = Math.random() < 0.6;
            L.g.fillStyle = L.body; L.g.fillRect(w[0], w[1], w[2], w[3]);
            if (on) { L.g.fillStyle = rgba(w[4], rnd(0.35, 0.9)); L.g.fillRect(w[0], w[1], w[2], w[3]); }
          }
          const p = par(0.3 + L.depth * 0.7); ctx.drawImage(L.img, p.x - 60 * S, p.y);
        }
        for (const [x, y, d, ph] of beacons) {
          const p = par(0.3 + d * 0.7), a = Math.max(0, Math.sin(t * 2 + ph));
          ctx.fillStyle = rgba('#ff5c7a', a); ctx.beginPath(); ctx.arc(x + p.x - 60 * S, y + p.y, 2.2 * S, 0, 6.3); ctx.fill();
        }
        ctx.strokeStyle = rgba(c.accent, 0.22); ctx.lineWidth = 1 * S; ctx.beginPath();
        for (const d of drops) {
          d.y += d.v * dt * d.z; d.x -= d.v * dt * d.z * 0.12;
          if (d.y > H) { Object.assign(d, drop()); d.y = rnd(-0.2, 0) * H; }
          ctx.moveTo(d.x, d.y); ctx.lineTo(d.x + d.l * 0.12, d.y - d.l);
        }
        ctx.stroke();
        ctx.fillStyle = vgrad([[0, 'rgba(0,0,0,0)'], [0.88, 'rgba(0,0,0,0)'], [1, rgba(c.accent2, 0.12)]]); ctx.fillRect(0, 0, W, H);
      },
    };
  };

  // ---------- Матча: misty hills, swaying bamboo, fireflies
  SCENES.matcha = c => {
    let hills, flies, stalks;
    function fly() { return { x: rnd(0, W), y: rnd(H * 0.35, H), z: rnd(0.4, 1), ph: rnd(0, 6), vx: rnd(-1, 1), vy: rnd(-1, 1), col: Math.random() < 0.6 ? c.accent2 : c.accent }; }
    return {
      init() {
        hills = Array.from({ length: 5 }, (_, i) => ridge(i, H * (0.09 - i * 0.008), H * (0.5 + i * 0.1), 1.2 + i * 0.7));
        flies = Array.from({ length: count(46) }, fly);
        stalks = [];
        for (const side of [0, 1]) for (let i = 0; i < 4; i++)
          stalks.push({ x: side ? W - rnd(20, 230) * S : rnd(20, 230) * S, w: rnd(9, 18) * S, ph: rnd(0, 6), seg: rnd(70, 120) * S, z: rnd(0.6, 1) });
      },
      draw(t, dt) {
        ctx.fillStyle = vgrad([[0, mix(c.solid, '#000000', 0.35)], [0.5, mix(c.solid, c.accent, 0.12)], [1, c.solid]]); ctx.fillRect(0, 0, W, H);
        const ps = par(0.1); glow(W * 0.62 + ps.x, H * 0.3 + ps.y, M * 0.5, c.accent2, 0.13);
        ctx.fillStyle = rgba(mix(c.accent2, c.text, 0.4), 0.55); ctx.beginPath(); ctx.arc(W * 0.62 + ps.x, H * 0.3 + ps.y, M * 0.07, 0, 6.3); ctx.fill();
        drawMark(W / 2 + par(0.2).x, H * 0.42 + par(0.2).y, M * 0.3, c.accent, 0.06);
        hills.forEach((h, i) => {
          const p = par(0.2 + i * 0.2);
          fillRidge(ctx, h, mix(mix(c.solid, c.accent, 0.32 - i * 0.06), '#000000', i * 0.12), p.x, p.y);
          ctx.fillStyle = vgrad([[0, 'rgba(0,0,0,0)'], [Math.min(0.99, 0.5 + i * 0.1), rgba(c.text, 0.035)], [1, 'rgba(0,0,0,0)']]); ctx.fillRect(0, 0, W, H);
        });
        for (const s of stalks) {       // bamboo
          const p = par(1.1 * s.z), sway = Math.sin(t * 0.6 + s.ph) * 0.012;
          ctx.save(); ctx.translate(s.x + p.x, H + 10); ctx.rotate(sway);
          const col = mix(c.solid, '#000000', 0.3 + (1 - s.z) * 0.2);
          for (let y = 0; y < H * 1.1; y += s.seg) {
            ctx.fillStyle = col; ctx.fillRect(-s.w / 2, -y - s.seg + 3 * S, s.w, s.seg - 3 * S);
            ctx.fillStyle = mix(col, c.accent, 0.12); ctx.fillRect(-s.w / 2 - 1.5 * S, -y - 3 * S, s.w + 3 * S, 4 * S);
            if (y > H * 0.35 && Math.round(y / s.seg) % 2 === 1) {
              ctx.fillStyle = col;
              const d = Math.round(y / s.seg) % 4 === 1 ? 1 : -1;
              for (let k = 0; k < 4; k++) {
                ctx.save(); ctx.translate(d * s.w * 0.4, -y - 2 * S);
                ctx.rotate(d * (0.35 + k * 0.28) + Math.sin(t * 0.9 + s.ph + k) * 0.06);
                ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(d * 22 * S, -5 * S, d * 52 * S, 0); ctx.quadraticCurveTo(d * 22 * S, 5 * S, 0, 0); ctx.fill();
                ctx.restore();
              }
            }
          }
          ctx.restore();
        }
        for (const f of flies) {
          f.vx += rnd(-1, 1) * dt * 2; f.vy += rnd(-1, 1) * dt * 2; f.vx *= 0.99; f.vy *= 0.99;
          f.x += f.vx * 22 * S * dt; f.y += f.vy * 16 * S * dt;
          if (f.x < -20 || f.x > W + 20 || f.y < H * 0.25 || f.y > H + 20) Object.assign(f, fly());
          const p = par(f.z), a = 0.25 + 0.6 * Math.max(0, Math.sin(t * 1.7 + f.ph));
          glow(f.x + p.x, f.y + p.y, 14 * S * f.z, f.col, a * 0.45);
          ctx.fillStyle = rgba(mix(f.col, '#ffffff', 0.4), a); ctx.beginPath(); ctx.arc(f.x + p.x, f.y + p.y, 1.8 * S * f.z, 0, 6.3); ctx.fill();
        }
      },
    };
  };

  // ---------- Латте: light, soft drifting colour blobs, rising steam, floating rings
  SCENES.latte = c => {
    let blobs, rings;
    function ring(spread) { return { x: rnd(0, W), y: spread ? rnd(0, H) : H + 30 * S, r: rnd(4, 16) * S, v: rnd(10, 30) * S, ph: rnd(0, 6), col: pick([c.accent, c.accent2, c.muted]) }; }
    return {
      init() {
        const cols = [c.accent, c.accent2, '#c9a27e', '#e8b79a', c.accent];
        blobs = cols.map((col, i) => ({ col, r: M * rnd(0.35, 0.6), ax: rnd(0.15, 0.85), ay: rnd(0.2, 0.8), fx: rnd(0.03, 0.07), fy: rnd(0.03, 0.07), ph: i * 1.7 }));
        rings = Array.from({ length: count(26) }, () => ring(true));
      },
      draw(t, dt) {
        ctx.fillStyle = vgrad([[0, mix(c.solid, '#ffffff', 0.4)], [0.6, c.solid], [1, c.chip]]); ctx.fillRect(0, 0, W, H);
        for (const b of blobs) {
          const p = par(0.4), x = W * (b.ax + 0.12 * Math.sin(t * b.fx * 6 + b.ph)) + p.x, y = H * (b.ay + 0.12 * Math.cos(t * b.fy * 6 + b.ph)) + p.y;
          glow(x, y, b.r, b.col, 0.26);
        }
        drawMark(W / 2 + par(0.2).x, H * 0.45 + par(0.2).y, M * 0.32, c.accent, 0.08);
        ctx.lineCap = 'round';
        for (let k = 0; k < 3; k++) {       // steam wisps
          const bx = W * (0.44 + k * 0.06) + par(0.6).x;
          ctx.beginPath();
          for (let i = 0; i <= 40; i++) {
            const u = i / 40, y = H * (1.02 - u * 0.75), x = bx + Math.sin(u * 7 + t * 0.7 + k * 2) * 40 * S * u + Math.sin(u * 3 - t * 0.4) * 25 * S;
            i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
          }
          for (const [lw, a] of [[46, 0.025], [30, 0.03], [16, 0.035]]) { ctx.strokeStyle = rgba('#ffffff', a * 2.2); ctx.lineWidth = lw * S; ctx.stroke(); }
        }
        for (const q of rings) {
          q.y -= q.v * dt; q.x += Math.sin(t * 0.8 + q.ph) * 10 * S * dt;
          if (q.y < -30 * S) Object.assign(q, ring(false));
          const p = par(0.7); ctx.strokeStyle = rgba(q.col, 0.35); ctx.lineWidth = 1.5 * S;
          ctx.beginPath(); ctx.arc(q.x + p.x, q.y + p.y, q.r, 0, 6.3); ctx.stroke();
        }
      },
    };
  };

  // ---------- Графіт: monochrome particle network that reaches for the cursor
  SCENES.graphite = c => {
    let pts, grid;
    return {
      init() {
        pts = Array.from({ length: count(140) }, () => ({ x: rnd(0, W), y: rnd(0, H), vx: rnd(-1, 1) * 14 * S, vy: rnd(-1, 1) * 14 * S }));
        grid = canvas(W, H); const g = grid.getContext('2d'); g.fillStyle = rgba(c.text, 0.05);
        const step = 34 * S; for (let x = step / 2; x < W; x += step) for (let y = step / 2; y < H; y += step) g.fillRect(x, y, 1.4 * S, 1.4 * S);
      },
      draw(t, dt) {
        const g = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, Math.hypot(W, H) / 2);
        g.addColorStop(0, mix(c.solid, '#ffffff', 0.05)); g.addColorStop(1, mix(c.solid, '#000000', 0.5)); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
        ctx.drawImage(grid, 0, 0);
        drawMark(W / 2, H / 2, M * 0.34, c.accent, 0.05);
        const link = 175 * S, mx = mouse.x * W, my = mouse.y * H;
        for (const p of pts) {
          p.x += p.vx * dt; p.y += p.vy * dt;
          if (p.x < 0 || p.x > W) p.vx *= -1;
          if (p.y < 0 || p.y > H) p.vy *= -1;
        }
        ctx.lineWidth = 1 * S;
        for (let i = 0; i < pts.length; i++) {
          const a = pts[i];
          for (let j = i + 1; j < pts.length; j++) {
            const b = pts[j], d = Math.hypot(a.x - b.x, a.y - b.y);
            if (d < link) { ctx.strokeStyle = rgba(c.text, (1 - d / link) * 0.38); ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke(); }
          }
          if (P.parallax) { const d = Math.hypot(a.x - mx, a.y - my); if (d < link * 1.4) { ctx.strokeStyle = rgba(c.accent, (1 - d / (link * 1.4)) * 0.35); ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(mx, my); ctx.stroke(); } }
          ctx.fillStyle = rgba(c.text, 0.85); ctx.beginPath(); ctx.arc(a.x, a.y, 2 * S, 0, 6.3); ctx.fill();
        }
      },
    };
  };

  // ---------- Захід: retro striped sun over the sea, mountains, birds
  SCENES.sunset = c => {
    let mtn, birds, stars, sunImg;
    function bird() { return { x: rnd(-0.3, -0.05) * W, y: rnd(0.12, 0.45) * H, v: rnd(30, 60) * S, s: rnd(5, 10) * S, ph: rnd(0, 6) }; }
    return {
      init() {
        const hz = H * 0.64;
        mtn = [ridge(4, H * 0.07, hz - H * 0.01, 1.5), ridge(5, H * 0.04, hz + 1, 2.6)];
        birds = Array.from({ length: Math.max(3, count(7)) }, () => { const b = bird(); b.x = rnd(0, W); return b; });
        stars = Array.from({ length: count(70) }, () => [rnd(0, W), rnd(0, H * 0.35), rnd(0.5, 1.3) * S, rnd(0, 6)]);
        sunImg = canvas(M * 0.4, M * 0.4);
      },
      draw(t, dt) {
        const hz = H * 0.64;
        ctx.fillStyle = vgrad([[0, mix(c.solid, '#000000', 0.4)], [0.3, c.solid], [0.5, mix(c.solid, c.accent2, 0.45)], [0.64, mix(c.accent2, c.accent, 0.6)], [0.64, mix(c.solid, '#000000', 0.2)], [1, mix(c.solid, '#000000', 0.45)]]);
        ctx.fillRect(0, 0, W, H);
        for (const [x, y, r, ph] of stars) { ctx.fillStyle = rgba(c.text, 0.15 + 0.3 * Math.abs(Math.sin(t * 0.6 + ph))); ctx.fillRect(x, y, r, r); }
        drawMark(W / 2 + par(0.15).x, H * 0.3 + par(0.15).y, M * 0.26, c.text, 0.05);
        // sun with moving stripes
        const R = M * 0.2, g = sunImg.getContext('2d'), sz = sunImg.width;
        g.clearRect(0, 0, sz, sz); g.globalCompositeOperation = 'source-over';
        const sg = g.createLinearGradient(0, 0, 0, sz); sg.addColorStop(0, '#ffe08a'); sg.addColorStop(0.5, c.accent); sg.addColorStop(1, c.accent2);
        g.fillStyle = sg; g.beginPath(); g.arc(sz / 2, sz / 2, R * 0.98, 0, 6.3); g.fill();
        g.globalCompositeOperation = 'destination-out';
        const off = (t * 10 * S) % (R * 0.16);
        for (let y = sz / 2 + off; y < sz; y += R * 0.16) { const k = (y - sz / 2) / (sz / 2); g.fillRect(0, y, sz, Math.max(1, k * R * 0.07)); }
        const sx = W / 2 + par(0.2).x, sy = hz - R * 0.35;
        glow(sx, sy, R * 3.2, c.accent, 0.22);
        ctx.save(); ctx.beginPath(); ctx.rect(0, 0, W, hz); ctx.clip(); ctx.drawImage(sunImg, sx - sz / 2, sy - sz / 2); ctx.restore();
        mtn.forEach((m, i) => {
          const p = par(0.4 + i * 0.3);
          ctx.save(); ctx.beginPath(); ctx.rect(0, 0, W, hz + 1); ctx.clip();
          fillRidge(ctx, m, mix(c.solid, '#000000', 0.25 + i * 0.2), p.x, 0); ctx.restore();
        });
        // sea: shimmering reflection under the sun
        for (let y = hz + 4 * S, i = 0; y < H; y += 7 * S, i++) {
          const k = (y - hz) / (H - hz), w = R * (1.6 - k * 0.6) * (0.7 + 0.3 * Math.sin(t * 2 + i * 1.3));
          ctx.fillStyle = rgba(i % 2 ? c.accent : c.accent2, 0.5 * (1 - k));
          ctx.fillRect(sx - w / 2 + Math.sin(t + i) * 8 * S, y, w, 2 * S);
        }
        ctx.strokeStyle = rgba(c.text, 0.06); ctx.lineWidth = 1 * S;
        for (let y = hz + 12 * S; y < H; y += 26 * S) { ctx.beginPath(); for (let x = 0; x <= W; x += 20) ctx.lineTo(x, y + Math.sin(x * 0.01 + t + y) * 2 * S); ctx.stroke(); }
        ctx.strokeStyle = rgba(mix(c.solid, '#000000', 0.4), 0.85); ctx.lineWidth = 1.6 * S; ctx.lineCap = 'round';
        for (const b of birds) {
          b.x += b.v * dt; if (b.x > W + 40) Object.assign(b, bird());
          const f = Math.sin(t * 6 + b.ph) * b.s * 0.6, p = par(0.6);
          ctx.beginPath(); ctx.moveTo(b.x - b.s + p.x, b.y + f + p.y); ctx.quadraticCurveTo(b.x - b.s * 0.4 + p.x, b.y - b.s * 0.2 + p.y, b.x + p.x, b.y + p.y);
          ctx.quadraticCurveTo(b.x + b.s * 0.4 + p.x, b.y - b.s * 0.2 + p.y, b.x + b.s + p.x, b.y + f + p.y); ctx.stroke();
        }
      },
    };
  };

  // ======================================================================== runtime
  function setTheme(i) {
    P.theme = clamp(i | 0, 0, THEMES.length - 1);
    theme = THEMES[P.theme];
    scene = SCENES[theme.id](theme.c);
    scene.init();
    const clk = document.getElementById('clock');
    clk.style.color = theme.c.text;
    document.body.style.background = theme.c.solid;
  }
  function resize() {
    W = cv.width = window.innerWidth; H = cv.height = window.innerHeight;
    M = Math.min(W, H); S = Math.max(0.5, M / 1080);
    markKey = '';
    if (scene) scene.init();
  }

  const days = ['неділя', 'понеділок', 'вівторок', 'середа', 'четвер', "п'ятниця", 'субота'];
  const months = ['січня', 'лютого', 'березня', 'квітня', 'травня', 'червня', 'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня'];
  function clock() {
    const d = new Date();
    document.getElementById('time').textContent = String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0');
    document.getElementById('date').textContent = `${days[d.getDay()]}, ${d.getDate()} ${months[d.getMonth()]}`;
    document.getElementById('clock').classList.toggle('off', !P.clock);
  }

  let last = performance.now(), simT = 0;
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000) * (P.speed / 100);
    last = now; simT += dt;
    pm.x += (mouse.x - pm.x) * 0.05; pm.y += (mouse.y - pm.y) * 0.05;
    A.bass *= 0.9; A.level *= 0.9;                      // decays when the music stops
    A.sb += (A.bass - A.sb) * 0.3; A.sl += (A.level - A.sl) * 0.15;
    const boost = 1 + A.sl * 1.6;
    simT += dt * (boost - 1);
    scene.draw(simT, dt * boost);
    if (A.sb > 0.02) {                                   // bass glow from the bottom edge
      const g = ctx.createRadialGradient(W / 2, H * 1.05, 0, W / 2, H * 1.05, M * 0.9);
      g.addColorStop(0, rgba(theme.c.accent, Math.min(0.35, A.sb * 0.3))); g.addColorStop(1, rgba(theme.c.accent, 0));
      ctx.fillStyle = g; ctx.fillRect(0, H * 0.3, W, H * 0.75);
    }
    requestAnimationFrame(frame);
  }

  window.addEventListener('mousemove', e => { mouse.x = e.clientX / W; mouse.y = e.clientY / H; });
  window.addEventListener('resize', resize);

  // Lively Wallpaper audio (needs "--audio" in LivelyInfo Arguments): 128 values, usually 0..1
  window.livelyAudioListener = arr => {
    if (!P.audio || !arr || !arr.length) return;
    let b = 0, l = 0; const n = arr.length, nb = Math.max(1, Math.round(n / 10));
    for (let i = 0; i < n; i++) { const v = Math.min(1.5, Math.max(0, +arr[i] || 0)); l += v; if (i < nb) b += v; }
    A.bass = Math.max(A.bass, Math.min(1.2, b / nb)); A.level = Math.max(A.level, Math.min(1.2, l / n * 2));
  };

  // Lively Wallpaper: called once per property at load, then on every change
  window.livelyPropertyListener = (name, val) => {
    if (name === 'theme') { if ((val | 0) !== P.theme) setTheme(val); }
    else if (name in P) {
      P[name] = val;
      if (name === 'density') scene.init();
      if (name === 'clock') clock();
    }
  };

  // ?theme=<id>&clock=1 for previews outside Lively
  const q = new URLSearchParams(location.search);
  if (q.get('theme')) { const i = THEMES.findIndex(t => t.id === q.get('theme')); if (i >= 0) P.theme = i; }
  if (q.get('clock')) P.clock = q.get('clock') === '1';

  resize();
  setTheme(P.theme);
  clock(); setInterval(clock, 5000);
  if (q.get('warm')) { for (let i = 0; i < +q.get('warm') * 30; i++) scene.draw(simT += 1 / 30, 1 / 30); }
  requestAnimationFrame(frame);
})();
