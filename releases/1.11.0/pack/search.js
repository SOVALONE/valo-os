// valo.os menu search helpers: calculator, currency converter, Windows settings pages.

// ---------- calculator: + - * / ^ ( ) %, "15% від 2400", "2400 + 15%", decimal comma
export function calc(input) {
  let s = input.toLowerCase().replace(/,/g, '.').replace(/×|х/g, '*').replace(/÷|:/g, '/').replace(/\s+/g, ' ').trim();
  if (!/[\d)]\s*[-+*/^%]|%|^\(|sqrt|√/.test(s) || /[a-zа-яіїєґ]{3,}/i.test(s.replace(/від|of|з|sqrt/g, ''))) return null;
  // "15% від 2400" -> (15/100)*(2400)
  s = s.replace(/(\d+(?:\.\d+)?)\s*%\s*(?:від|of|з)\s*(.+)$/, '($1/100)*($2)');
  // "a + n%" / "a - n%" -> a ± a*n/100
  s = s.replace(/(\d+(?:\.\d+)?)\s*([+-])\s*(\d+(?:\.\d+)?)\s*%/g, '($1$2$1*$3/100)');
  s = s.replace(/(\d+(?:\.\d+)?)\s*%/g, '($1/100)').replace(/√/g, 'sqrt');
  const toks = s.match(/\d+(?:\.\d+)?|sqrt|[-+*/^()]/g);
  if (!toks || toks.join('') !== s.replace(/ /g, '')) return null;
  let i = 0;
  const peek = () => toks[i], next = () => toks[i++];
  function expr() { let v = term(); while (peek() === '+' || peek() === '-') { const o = next(), r = term(); v = o === '+' ? v + r : v - r; } return v; }
  function term() { let v = power(); while (peek() === '*' || peek() === '/') { const o = next(), r = power(); v = o === '*' ? v * r : v / r; } return v; }
  function power() { const b = unary(); if (peek() === '^') { next(); return Math.pow(b, power()); } return b; }
  function unary() { if (peek() === '-') { next(); return -unary(); } if (peek() === '+') { next(); return unary(); } return atom(); }
  function atom() {
    const t = next();
    if (t === 'sqrt') { if (next() !== '(') throw 0; const v = expr(); if (next() !== ')') throw 0; return Math.sqrt(v); }
    if (t === '(') { const v = expr(); if (next() !== ')') throw 0; return v; }
    if (t !== undefined && /^\d/.test(t)) return parseFloat(t);
    throw 0;
  }
  try {
    const v = expr();
    if (i !== toks.length || !isFinite(v)) return null;
    return { value: v, text: fmt(v) };
  } catch { return null; }
}
export function fmt(v, digits = 10) {
  const r = Math.round(v * 10 ** digits) / 10 ** digits;
  return r.toLocaleString('uk-UA', { maximumFractionDigits: Math.abs(r) < 1 ? 6 : 4 });
}

// ---------- currency
const CUR = [
  ['UAH', /^(uah|грн|гривн\S*|гривень|₴)$/], ['EUR', /^(eur|євро|€|euro)$/], ['USD', /^(usd|\$|долар\S*|dollars?)$/],
  ['PLN', /^(pln|zł|zl|злот\S*)$/], ['RON', /^(ron|lei|леї|лей|леу)$/], ['CZK', /^(czk|kč|крон\S*)$/], ['GBP', /^(gbp|£|фунт\S*)$/],
  ['HUF', /^(huf|форинт\S*)$/], ['CHF', /^(chf|франк\S*)$/], ['MDL', /^(mdl|лей молд\S*)$/], ['TRY', /^(try|лір\S*)$/],
];
const code = w => { if (!w) return null; w = w.toLowerCase(); if (/^[a-z]{3}$/i.test(w) && CUR.some(c => c[0] === w.toUpperCase())) return w.toUpperCase(); const c = CUR.find(([, re]) => re.test(w)); return c ? c[0] : null; };
export function currencyQuery(q) {
  const m = q.trim().replace(',', '.').match(/^(\d+(?:\.\d+)?)\s*([^\d\s]+)(?:\s*(?:в|у|to|in|->|=|на)\s*|\s+)?([^\d\s]+)?$/i);
  if (!m) return null;
  const from = code(m[2]), to = m[3] ? code(m[3]) : null;
  if (!from || (m[3] && !to)) return null;
  return { amount: parseFloat(m[1]), from, to };
}
export async function rates() {
  try {
    const c = JSON.parse(localStorage.getItem('valo.rates') || 'null');
    if (c && Date.now() - c.at < 12 * 3600e3) return c.rates;
  } catch { }
  try {
    const r = await fetch('https://open.er-api.com/v6/latest/EUR');
    const j = await r.json();
    if (j && j.rates) { localStorage.setItem('valo.rates', JSON.stringify({ at: Date.now(), rates: j.rates })); return j.rates; }
  } catch { }
  return null;
}
export function convert(cq, rt) {
  const targets = cq.to ? [cq.to] : ['UAH', 'EUR', 'USD', 'PLN', 'RON'].filter(c => c !== cq.from).slice(0, 3);
  return targets.filter(t => rt[t] && rt[cq.from]).map(t => {
    const v = cq.amount / rt[cq.from] * rt[t];
    return { value: v, text: `${fmt(cq.amount)} ${cq.from} = ${fmt(v, 2)} ${t}` };
  });
}

// ---------- Windows settings pages (Ukrainian + English keywords)
export const SETTINGS = [
  ['Wi‑Fi', 'ms-settings:network-wifi', 'wifi wi-fi вайфай мережа інтернет бездротова'],
  ['Мережа та інтернет', 'ms-settings:network', 'мережа інтернет ethernet network'],
  ['VPN', 'ms-settings:network-vpn', 'vpn впн'],
  ['Режим польоту', 'ms-settings:network-airplanemode', 'польоту літак airplane'],
  ['Проксі', 'ms-settings:network-proxy', 'проксі proxy'],
  ['Bluetooth і пристрої', 'ms-settings:bluetooth', 'bluetooth блютуз пристрої навушники миша devices'],
  ['Принтери й сканери', 'ms-settings:printers', 'принтер сканер друк printer'],
  ['Миша', 'ms-settings:mousetouchpad', 'миша курсор mouse'],
  ['Сенсорна панель', 'ms-settings:devices-touchpad', 'тачпад сенсорна touchpad жести'],
  ['Звук', 'ms-settings:sound', 'звук гучність мікрофон динаміки sound audio'],
  ['Дисплей', 'ms-settings:display', 'дисплей екран яскравість роздільна масштаб монітор display'],
  ['Нічне світло', 'ms-settings:nightlight', 'нічне світло синє night light'],
  ['Тло робочого столу', 'ms-settings:personalization-background', 'шпалери тло фон wallpaper background'],
  ['Кольори', 'ms-settings:colors', 'колір кольори темна тема акцент colors dark'],
  ['Екран блокування', 'ms-settings:lockscreen', 'блокування lock screen заставка'],
  ['Шрифти', 'ms-settings:fonts', 'шрифт fonts'],
  ['Програми й компоненти', 'ms-settings:appsfeatures', 'програми видалити встановлені apps uninstall'],
  ['Програми за замовчуванням', 'ms-settings:defaultapps', 'замовчуванням браузер default apps'],
  ['Автозавантаження', 'ms-settings:startupapps', 'автозапуск автозавантаження startup'],
  ['Обліковий запис', 'ms-settings:yourinfo', 'обліковий запис акаунт профіль account'],
  ['Параметри входу', 'ms-settings:signinoptions', 'вхід пароль pin пін hello sign in'],
  ['Дата й час', 'ms-settings:dateandtime', 'дата час годинник часовий пояс time'],
  ['Мова й регіон', 'ms-settings:regionlanguage', 'мова розкладка регіон клавіатура language'],
  ['Живлення й батарея', 'ms-settings:powersleep', 'живлення батарея сон заряд power battery sleep'],
  ['Сховище', 'ms-settings:storagesense', 'сховище диск пам\'ять місце storage'],
  ['Сповіщення', 'ms-settings:notifications', 'сповіщення не турбувати notifications focus'],
  ['Оновлення Windows', 'ms-settings:windowsupdate', 'оновлення windows update'],
  ['Безпека Windows', 'windowsdefender:', 'безпека антивірус захисник defender security'],
  ['Конфіденційність', 'ms-settings:privacy', 'конфіденційність камера мікрофон доступ privacy'],
  ['Ігри', 'ms-settings:gaming-gamemode', 'ігри ігровий режим game'],
  ['Спеціальні можливості', 'ms-settings:easeofaccess', 'спеціальні можливості екранний диктор accessibility'],
  ['Про систему', 'ms-settings:about', 'про систему ім\'я пк характеристики about'],
  ['Відновлення', 'ms-settings:recovery', 'відновлення скинути recovery reset'],
  ['Активація', 'ms-settings:activation', 'активація ключ activation'],
  ['Панель керування', 'control', 'панель керування control panel'],
  ['Диспетчер завдань', 'taskmgr', 'диспетчер завдань процеси task manager'],
  ['Диспетчер пристроїв', 'devmgmt.msc', 'диспетчер пристроїв драйвери device manager'],
];
export function matchSettings(q) {
  q = q.toLowerCase();
  return SETTINGS.filter(([n, , k]) => n.toLowerCase().includes(q) || k.split(' ').some(w => w.startsWith(q))).slice(0, 5);
}

// ---------- unit conversion: "5 миль у км", "70 f в c", "2 gb в mb"
const UNITS = [
  // [group, factor to base, names]
  ['len', 0.001, 'мм mm міліметр міліметрів'], ['len', 0.01, 'см cm сантиметр сантиметрів'], ['len', 1, 'м m метр метрів метри'],
  ['len', 1000, 'км km кілометр кілометрів кілометри'], ['len', 0.0254, 'дюйм дюймів дюйми in inch inches "'], ['len', 0.3048, 'фут футів фути ft foot feet'],
  ['len', 0.9144, 'ярд ярдів yd yard yards'], ['len', 1609.344, 'миля миль милі mi mile miles'],
  ['mass', 0.001, 'г g грам грамів'], ['mass', 1, 'кг kg кілограм кілограмів'], ['mass', 1000, 'т t тонна тонн'],
  ['mass', 0.45359237, 'фунт фунтів lb lbs pound pounds'], ['mass', 0.028349523, 'унція унцій oz ounce ounces'],
  ['vol', 0.001, 'мл ml мілілітр'], ['vol', 1, 'л l літр літрів літри'], ['vol', 3.785411784, 'галон галонів gal gallon gallons'],
  ['speed', 1, 'км/год kmh km/h кмгод'], ['speed', 3.6, 'м/с m/s мс'], ['speed', 1.609344, 'миль/год mph'], ['speed', 1.852, 'вузол вузлів kn knot knots'],
  ['data', 1, 'б b байт байтів'], ['data', 1024, 'кб kb кілобайт'], ['data', 1048576, 'мб mb мегабайт мегабайтів'],
  ['data', 1073741824, 'гб gb гігабайт гігабайтів'], ['data', 1099511627776, 'тб tb терабайт'],
  ['area', 1, 'м2 m2 м² кв.м'], ['area', 10000, 'га ha гектар гектарів'], ['area', 4046.8564224, 'акр акрів acre acres'], ['area', 1e6, 'км2 km2 км²'],
  ['temp', 'c', '°c c цельсій цельсія градусів °'], ['temp', 'f', '°f f фаренгейт фаренгейта'], ['temp', 'k', 'k кельвін кельвіна'],
];
function unit(w) { w = w.trim().toLowerCase(); return UNITS.find(u => u[2].split(' ').includes(w)) || null; }
export function convertUnits(q) {
  const m = q.trim().toLowerCase().replace(',', '.').match(/^(-?\d+(?:\.\d+)?)\s*(.+?)\s+(?:в|у|to|in|->|=)\s+(.+)$/);
  if (!m) return null;
  const v = parseFloat(m[1]), a = unit(m[2]), b = unit(m[3]);
  if (!a || !b || a[0] !== b[0]) return null;
  let r;
  if (a[0] === 'temp') {
    const c = a[1] === 'c' ? v : a[1] === 'f' ? (v - 32) * 5 / 9 : v - 273.15;
    r = b[1] === 'c' ? c : b[1] === 'f' ? c * 9 / 5 + 32 : c + 273.15;
  } else r = v * a[1] / b[1];
  const nm = s => s[2].split(' ')[0];
  return { value: r, text: `${fmt(v)} ${nm(a)} = ${fmt(r)} ${nm(b)}` };
}

// ---------- commands: timer, scheduled shutdown, close an app, theme
export function command(q) {
  const s = q.trim().toLowerCase();
  let m = s.match(/^(?:таймер|timer|нагадай|нагадування)\s+(?:через\s+)?(\d+(?:[.,]\d+)?)\s*(с|сек|секунд|s|хв|хвилин|хвилини|min|m|год|годин|години|h)?\s*(.*)$/);
  if (m) {
    const n = parseFloat(m[1].replace(',', '.')), u = m[2] || 'хв';
    const ms = /^(с|сек|секунд|s)$/.test(u) ? n * 1e3 : /^(год|годин|години|h)$/.test(u) ? n * 3600e3 : n * 60e3;
    const label = /^(с|сек|секунд|s)$/.test(u) ? 'с' : /^(год|годин|години|h)$/.test(u) ? 'год' : 'хв';
    return { kind: 'timer', ms, text: m[3] ? q.trim().slice(q.trim().length - m[3].length) : 'Таймер', n: `Таймер на ${fmt(n)} ${label}`, glyph: 0xF13AB };
  }
  m = s.match(/^(?:вимкни|вимкнути|вимкнення|shutdown)\s+(?:о|об|в|at)\s+(\d{1,2})(?:[:.](\d{2}))?$/);
  if (m) {
    const d = new Date(); d.setHours(+m[1], +(m[2] || 0), 0, 0); if (d <= new Date()) d.setDate(d.getDate() + 1);
    const sec = Math.round((d - Date.now()) / 1000);
    return { kind: 'shutdown', sec, n: `Вимкнути комп'ютер о ${d.toLocaleTimeString('uk-UA', { hour: '2-digit', minute: '2-digit' })}`, glyph: 0xF0425 };
  }
  m = s.match(/^(?:вимкни|вимкнути|shutdown)\s+через\s+(\d+)\s*(хв|хвилин|min|год|годин|h)?$/);
  if (m) {
    const sec = +m[1] * (/^(год|годин|h)$/.test(m[2] || '') ? 3600 : 60);
    return { kind: 'shutdown', sec, n: `Вимкнути комп'ютер через ${m[1]} ${/^(год|годин|h)$/.test(m[2] || '') ? 'год' : 'хв'}`, glyph: 0xF0425 };
  }
  if (/^(скасуй|скасувати|відміни)\s+(вимкнення|shutdown)/.test(s) || s === 'shutdown -a') return { kind: 'abort', n: 'Скасувати заплановане вимкнення', glyph: 0xF0156 };
  m = s.match(/^(?:закрий|закрити|close|kill)\s+(.{2,})$/);
  if (m) return { kind: 'close', name: m[1].trim(), n: `Закрити «${m[1].trim()}»`, glyph: 0xF0156 };
  m = s.match(/^(?:тема|theme)\s+(.+)$/);
  if (m) return { kind: 'theme', name: m[1].trim(), n: `Тема «${m[1].trim()}»`, glyph: 0xF03D8 };
  return null;
}
