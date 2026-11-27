// valo.os panel themes: colour palette + style per preset, shared by the bar and the menu.
// Saved in localStorage 'valo.theme' as { id, sticky, size, dockSticky, dockOverlap, dockHide } (size 100/75/50 applies to the sticky bar;
// the dock has its own sticky / floating switch and can overlap windows instead of reserving space); every widget re-applies on change.

export const THEMES = {
  sakura: {
    name: 'Сакура', desc: 'рожевий на темному, м’які кути',
    vars: { bg: 'rgba(30,26,31,.92)', solid: '#1e1a1f', chip: '#2a2329', hi: '#3a2f37', accent: '#f2a7bb', accent2: '#e07a96',
            text: '#f5e6ea', muted: '#9c8a93', ink: '#1e1a1f', border: 'rgba(242,167,187,.25)', radius: '12px', chipRadius: '8px', shadow: '0 6px 18px rgba(0,0,0,.25)' },
  },
  night: {
    name: 'Нічне місто', desc: 'синьо-фіолетовий неон',
    vars: { bg: 'rgba(26,27,38,.92)', solid: '#1a1b26', chip: '#24283b', hi: '#2f3549', accent: '#7aa2f7', accent2: '#bb9af7',
            text: '#c0caf5', muted: '#737aa2', ink: '#1a1b26', border: 'rgba(122,162,247,.28)', radius: '12px', chipRadius: '8px', shadow: '0 6px 22px rgba(122,162,247,.12)' },
  },
  matcha: {
    name: 'Матча', desc: 'зелений чай, строгі кути',
    vars: { bg: 'rgba(30,35,30,.93)', solid: '#1e231e', chip: '#283028', hi: '#34402f', accent: '#a7c080', accent2: '#dbbc7f',
            text: '#e6e2cc', muted: '#859289', ink: '#1e231e', border: 'rgba(167,192,128,.25)', radius: '6px', chipRadius: '4px', shadow: '0 4px 14px rgba(0,0,0,.3)' },
  },
  latte: {
    name: 'Латте', desc: 'світла, кавова, дуже округла',
    vars: { bg: 'rgba(239,234,228,.94)', solid: '#efeae4', chip: '#e2d9cf', hi: '#d6cabd', accent: '#b4637a', accent2: '#d7827e',
            text: '#3b2f2f', muted: '#8a7a72', ink: '#fffaf3', border: 'rgba(180,99,122,.3)', radius: '16px', chipRadius: '12px', shadow: '0 6px 18px rgba(80,50,40,.18)' },
  },
  graphite: {
    name: 'Графіт', desc: 'монохром, мінімалізм',
    vars: { bg: 'rgba(18,18,18,.94)', solid: '#121212', chip: '#222222', hi: '#2e2e2e', accent: '#e6e6e6', accent2: '#9a9a9a',
            text: '#f0f0f0', muted: '#8a8a8a', ink: '#121212', border: 'rgba(255,255,255,.12)', radius: '4px', chipRadius: '3px', shadow: 'none' },
  },
  sunset: {
    name: 'Захід', desc: 'помаранчевий, «таблетки»',
    vars: { bg: 'rgba(36,22,28,.92)', solid: '#24161c', chip: '#3a2229', hi: '#4a2c34', accent: '#ff9e64', accent2: '#f7768e',
            text: '#ffe8d6', muted: '#b08a80', ink: '#24161c', border: 'rgba(255,158,100,.3)', radius: '20px', chipRadius: '13px', shadow: '0 6px 20px rgba(255,120,80,.15)' },
  },
  // light and dark "aluminium" in a clean Mac-like style; glass = glassmorphism (frosted translucent panels)
  // wall: which live wallpaper / screensaver scene the theme uses
  aluminium: {
    name: 'Алюміній', desc: 'світла, чиста, як у Mac', wall: 'latte',
    vars: { bg: 'rgba(246,246,248,.86)', solid: '#f5f5f7', chip: '#e8e8ed', hi: '#dcdce2', accent: '#0a84ff', accent2: '#5e5ce6',
            text: '#1d1d1f', muted: '#86868b', ink: '#ffffff', border: 'rgba(0,0,0,.08)', radius: '14px', chipRadius: '9px', shadow: '0 8px 30px rgba(0,0,0,.12)' },
  },
  space: {
    name: 'Космос', desc: 'темний алюміній, синій акцент', wall: 'graphite',
    vars: { bg: 'rgba(28,28,30,.88)', solid: '#1c1c1e', chip: '#2c2c2e', hi: '#3a3a3c', accent: '#0a84ff', accent2: '#bf5af2',
            text: '#f5f5f7', muted: '#98989d', ink: '#ffffff', border: 'rgba(255,255,255,.1)', radius: '14px', chipRadius: '9px', shadow: '0 10px 32px rgba(0,0,0,.4)' },
  },
  glass: {
    name: 'Скло', desc: 'матове скло, світлі краї', wall: 'night', glass: true,
    vars: { bg: 'rgba(30,34,52,.42)', solid: '#1f2336', chip: 'rgba(255,255,255,.10)', hi: 'rgba(255,255,255,.2)', accent: '#a5b4fc', accent2: '#f0abfc',
            text: '#ffffff', muted: 'rgba(255,255,255,.66)', ink: '#1b1d33', border: 'rgba(255,255,255,.32)', radius: '18px', chipRadius: '12px', shadow: '0 8px 32px rgba(10,14,40,.35)' },
  },
};
// live wallpaper / screensaver scene of a theme (the new themes reuse one of the six scenes)
export const wallOf = id => THEMES[id]?.wall || id;

// glassmorphism: the panels of every widget get a frosted gradient, a light edge and an inner highlight
const GLASS_CSS = `
html.glass .bar, html.glass .dock { background: linear-gradient(135deg, rgba(255,255,255,.20), rgba(255,255,255,.06)), var(--bg) !important;
  border-color: var(--border) !important; box-shadow: inset 0 1px 0 rgba(255,255,255,.35), var(--shadow) !important; backdrop-filter: blur(20px) saturate(160%); }
html.glass .menu, html.glass .cc, html.glass .em { background: linear-gradient(150deg, rgba(255,255,255,.16), rgba(255,255,255,.04) 45%), rgba(28,32,50,.78) !important;
  border-color: var(--border) !important; box-shadow: inset 0 1px 0 rgba(255,255,255,.3), 0 18px 50px rgba(10,14,40,.45) !important; backdrop-filter: blur(24px) saturate(160%); }
html.glass .chip, html.glass .btn { border: 1px solid rgba(255,255,255,.14); }
`;

export const DEFAULT = { id: 'sakura', sticky: false, size: 100, dockSticky: false, dockOverlap: false, dockHide: false, dockTrash: true, wallSync: true };
export const SIZES = [100, 75, 50];

// ---------- custom theme ("Своя"): built from 4 colours + rounding + opacity
export const CUSTOM_DEFAULT = { solid: '#1e1a1f', accent: '#f2a7bb', accent2: '#e07a96', text: '#f5e6ea', radius: 12, alpha: 92 };
const rgbOf = h => { const n = parseInt(String(h).replace('#', ''), 16) || 0; return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
const hex = a => '#' + a.map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('');
export const mixHex = (a, b, t) => { const x = rgbOf(a), y = rgbOf(b); return hex(x.map((v, i) => v + (y[i] - v) * t)); };
export const lum = h => { const [r, g, b] = rgbOf(h).map(v => v / 255); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
export function customVars(c) {
  c = { ...CUSTOM_DEFAULT, ...(c || {}) };
  const [r, g, b] = rgbOf(c.solid), [ar, ag, ab] = rgbOf(c.accent), rad = Math.max(0, Math.min(24, +c.radius || 0));
  const light = lum(c.solid) > 0.5;
  return {
    bg: `rgba(${r},${g},${b},${(+c.alpha || 92) / 100})`, solid: c.solid,
    chip: mixHex(c.solid, c.text, light ? 0.1 : 0.07), hi: mixHex(c.solid, c.text, light ? 0.17 : 0.14),
    accent: c.accent, accent2: c.accent2, text: c.text, muted: mixHex(c.text, c.solid, 0.42),
    ink: lum(c.accent) > 0.5 ? mixHex(c.solid, '#000000', light ? 0.7 : 0) : '#ffffff',
    border: `rgba(${ar},${ag},${ab},.28)`, radius: rad + 'px', chipRadius: Math.max(2, Math.round(rad * 0.66)) + 'px',
    shadow: rad > 0 ? '0 6px 18px rgba(0,0,0,.25)' : 'none',
  };
}
export function themeVars(t) {
  if (t.id === 'custom') return customVars(t.custom);
  return (THEMES[t.id] || THEMES.sakura).vars;
}

export function getTheme() {
  try { return { ...DEFAULT, ...JSON.parse(localStorage.getItem('valo.theme') || '{}') }; } catch { return { ...DEFAULT }; }
}

export function saveTheme(patch) {
  const t = { ...getTheme(), ...patch };
  localStorage.setItem('valo.theme', JSON.stringify(t));
  applyTheme();
  return t;
}

export function applyTheme() {
  const t = getTheme();
  const vars = themeVars(t);
  const s = document.documentElement.style;
  for (const [k, v] of Object.entries(vars)) s.setProperty('--' + k, v);
  const root = document.documentElement, isDock = root.dataset.widget === 'dock';
  root.classList.toggle('sticky', isDock ? !!t.dockSticky : !!t.sticky);
  root.classList.toggle('overlap', isDock && !!t.dockOverlap);
  root.classList.toggle('light', lum(vars.solid) > 0.5);
  const glass = !!(THEMES[t.id] || {}).glass;
  root.classList.toggle('glass', glass);
  if (glass && !document.getElementById('valo-glass')) { const st = document.createElement('style'); st.id = 'valo-glass'; st.textContent = GLASS_CSS; document.head.append(st); }
  for (const z of SIZES) root.classList.toggle('s' + z, !isDock && !!t.sticky && t.size === z);
}

// keep every widget in sync
window.addEventListener('storage', e => { if (e.key === 'valo.theme') applyTheme(); });
applyTheme();
