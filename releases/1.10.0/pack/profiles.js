// valo.os modes (profiles): one click switches theme, dock, "do not disturb", power mode and opens apps.
// Stored in valo.prefs.profiles = { active, list: { work, games, rest, travel } }. Wi‑Fi auto: a mode with `wifi` turns on when that network connects.
import { getTheme, saveTheme } from './themes.js';

export const POWER = { eff: '961cc777-2547-4f9d-8174-7d86181b8a7a', balanced: '00000000-0000-0000-0000-000000000000', perf: 'ded574b5-45a0-4f42-8737-46345c09c238' };
export const DEFAULTS = {
  work:   { name: 'Робота',     glyph: 0xF00D6, theme: 'latte',    dnd: true,  power: 'balanced', dockHide: false, apps: [], wifi: '' },
  games:  { name: 'Ігри',       glyph: 0xF0297, theme: 'night',    dnd: true,  power: 'perf',     dockHide: true,  apps: [], wifi: '' },
  rest:   { name: 'Відпочинок', glyph: 0xF0F2E, theme: 'sakura',   dnd: false, power: 'balanced', dockHide: false, apps: [], wifi: '' },
  travel: { name: 'В дорозі',   glyph: 0xF001D, theme: 'graphite', dnd: false, power: 'eff',      dockHide: true,  apps: [], wifi: '' },
};
const prefs = () => { try { return JSON.parse(localStorage.getItem('valo.prefs') || '{}') || {}; } catch { return {}; } };
export function profiles() {
  const p = prefs().profiles || {};
  const list = {};
  for (const [id, d] of Object.entries(DEFAULTS)) list[id] = { ...d, ...((p.list || {})[id] || {}) };
  return { active: p.active || null, list };
}
export function saveProfiles(patch) {
  const cur = prefs(), p = cur.profiles || {};
  localStorage.setItem('valo.prefs', JSON.stringify({ ...cur, profiles: { ...p, ...patch } }));
}
export function setProfile(id, patch) {
  const p = prefs().profiles || {}, list = { ...(p.list || {}) };
  list[id] = { ...(list[id] || {}), ...patch };
  saveProfiles({ list });
}
// shell: (program, args) => Promise ; dir: pack folder
export async function applyProfile(id, shell, dir) {
  const PS = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden'];
  if (!id) { saveProfiles({ active: null }); return; }
  const m = profiles().list[id]; if (!m) return;
  const patch = {};
  if (m.theme) patch.id = m.theme;
  if (m.dockHide != null) { patch.dockOverlap = !!m.dockHide; patch.dockHide = !!m.dockHide; }   // hidden dock = overlap + auto-hide
  saveTheme(patch);
  const t = getTheme();
  if (m.theme && t.wallSync !== false && m.theme !== 'custom') shell('powershell', [...PS, '-File', dir + '\\valo-wallpaper.ps1', '-Theme', m.theme]).catch(() => {});
  shell('powershell', [...PS, '-File', dir + '\\valo-game.ps1', '-Dnd', m.dnd ? '1' : '0']).catch(() => {});
  if (m.power && POWER[m.power]) shell('powershell', [...PS, '-File', dir + '\\valo-power.ps1', '-Set', POWER[m.power]]).catch(() => {});
  for (const a of m.apps || []) shell('explorer', ['shell:AppsFolder\\' + a]).catch(() => {});
  saveProfiles({ active: id });
}
