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
};

export const DEFAULT = { id: 'sakura', sticky: false, size: 100, dockSticky: false, dockOverlap: false, dockHide: false, dockTrash: true, wallSync: true };
export const SIZES = [100, 75, 50];

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
  const th = THEMES[t.id] || THEMES.sakura;
  const s = document.documentElement.style;
  for (const [k, v] of Object.entries(th.vars)) s.setProperty('--' + k, v);
  const root = document.documentElement, isDock = root.dataset.widget === 'dock';
  root.classList.toggle('sticky', isDock ? !!t.dockSticky : !!t.sticky);
  root.classList.toggle('overlap', isDock && !!t.dockOverlap);
  root.classList.toggle('light', t.id === 'latte');
  for (const z of SIZES) root.classList.toggle('s' + z, !isDock && !!t.sticky && t.size === z);
}

// keep every widget in sync
window.addEventListener('storage', e => { if (e.key === 'valo.theme') applyTheme(); });
applyTheme();
