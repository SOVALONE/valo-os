// valo.os weather (Open-Meteo, no key). The bar refreshes it every 20 min and keeps it in localStorage 'valo.weather';
// the control center only reads it. Place: valo.prefs.weather = { mode: 'auto' | 'city', name, lat, lon }  (auto = by IP, follows trips).

// WMO weather code -> [Ukrainian text, day glyph, night glyph] (Material Design icons in the Nerd Font)
const W = {
  0: ['ясно', 0xF0599, 0xF0594], 1: ['переважно ясно', 0xF0595, 0xF0F31], 2: ['мінлива хмарність', 0xF0595, 0xF0F31], 3: ['хмарно', 0xF0590, 0xF0590],
  45: ['туман', 0xF0591, 0xF0591], 48: ['паморозь, туман', 0xF0591, 0xF0591],
  51: ['мряка', 0xF0597, 0xF0597], 53: ['мряка', 0xF0597, 0xF0597], 55: ['сильна мряка', 0xF0597, 0xF0597], 56: ['крижана мряка', 0xF067F, 0xF067F], 57: ['крижана мряка', 0xF067F, 0xF067F],
  61: ['невеликий дощ', 0xF0597, 0xF0597], 63: ['дощ', 0xF0597, 0xF0597], 65: ['злива', 0xF0596, 0xF0596], 66: ['крижаний дощ', 0xF067F, 0xF067F], 67: ['крижаний дощ', 0xF067F, 0xF067F],
  71: ['невеликий сніг', 0xF0598, 0xF0598], 73: ['сніг', 0xF0598, 0xF0598], 75: ['снігопад', 0xF0F36, 0xF0F36], 77: ['снігова крупа', 0xF0598, 0xF0598],
  80: ['короткочасний дощ', 0xF0597, 0xF0597], 81: ['зливи', 0xF0596, 0xF0596], 82: ['сильні зливи', 0xF0596, 0xF0596], 85: ['снігові заряди', 0xF0598, 0xF0598], 86: ['сильний сніг', 0xF0F36, 0xF0F36],
  95: ['гроза', 0xF0593, 0xF0593], 96: ['гроза з градом', 0xF0593, 0xF0593], 99: ['гроза з градом', 0xF0593, 0xF0593],
};
export function describe(code, isDay = true) {
  const w = W[code] || ['—', 0xF0590, 0xF0590];
  return { text: w[0], glyph: String.fromCodePoint(isDay ? w[1] : w[2]) };
}
function prefs() { try { return JSON.parse(localStorage.getItem('valo.prefs') || '{}') || {}; } catch { return {}; } }
export function cached() { try { return JSON.parse(localStorage.getItem('valo.weather') || 'null'); } catch { return null; } }

async function place() {
  const w = prefs().weather || { mode: 'auto' };
  if (w.mode === 'city' && w.lat != null) return { name: w.name, lat: w.lat, lon: w.lon };
  const r = await fetch('https://ipwho.is/?fields=city,latitude,longitude,success');
  const j = await r.json();
  if (!j.success) throw new Error('location');
  return { name: j.city, lat: j.latitude, lon: j.longitude };
}
export async function refresh(force = false) {
  const c = cached();
  if (!force && c && Date.now() - c.at < 20 * 60e3) return c;
  try {
    const p = await place();
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${p.lat}&longitude=${p.lon}` +
      '&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m' +
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&forecast_days=5';
    const j = await (await fetch(url)).json();
    if (!j.current) throw new Error('no data');
    const out = { at: Date.now(), place: p.name, cur: j.current, daily: j.daily };
    localStorage.setItem('valo.weather', JSON.stringify(out));
    return out;
  } catch { return c; }
}
// city search for the settings (Open-Meteo geocoding)
export async function findCity(q) {
  try {
    const j = await (await fetch('https://geocoding-api.open-meteo.com/v1/search?count=5&language=uk&name=' + encodeURIComponent(q))).json();
    return (j.results || []).map(r => ({ name: r.name, lat: r.latitude, lon: r.longitude, sub: [r.admin1, r.country].filter(Boolean).join(', ') }));
  } catch { return []; }
}
