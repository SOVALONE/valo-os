// valo.os interface language: Ukrainian (source), English, Romanian. localStorage 'valo.lang' = uk | en | ro.
// Every widget imports this module: it translates text nodes and title / placeholder / data-tip attributes in place
// (the Ukrainian original is remembered, so switching back works) and keeps translating whatever the widget adds later.
const T = `
Усі програми|All apps|Toate aplicațiile
Закріплені|Pinned|Fixate
Результати|Results|Rezultate
Програми|Apps|Aplicații
Налаштування|Settings|Setări
Файли|Files|Fișiere
Інтернет|Web|Web
Калькулятор|Calculator|Calculator
Валюта|Currency|Valută
Одиниці|Units|Unități
Команда|Command|Comandă
Enter — скопіювати|Enter — copy|Enter — copiază
Шукаю файли…|Searching files…|Caut fișiere…
Завантажую курси…|Loading rates…|Se încarcă cursurile…
Нічого не знайдено|Nothing found|Nimic găsit
Завантаження…|Loading…|Se încarcă…
налаштування Windows|Windows settings|setări Windows
Клік — запустити, правий клік — закріпити|Click — open, right click — pin|Clic — deschide, clic dreapta — fixează
Клік — відкрити, правий клік — показати в папці|Click — open, right click — show in folder|Clic — deschide, clic dreapta — arată în folder
Налаштування панелі|Panel settings|Setările panoului
Вигляд|Look|Aspect
Система|System|Sistem
Дані|Data|Date
Тема|Theme|Temă
Сакура|Sakura|Sakura
Нічне місто|Night city|Oraș noaptea
Матча|Matcha|Matcha
Латте|Latte|Latte
Графіт|Graphite|Grafit
Захід|Sunset|Apus
Своя|Custom|Personalizată
рожевий на темному, м’які кути|pink on dark, soft corners|roz pe închis, colțuri moi
синьо-фіолетовий неон|blue-violet neon|neon albastru-violet
зелений чай, строгі кути|green tea, sharp corners|ceai verde, colțuri drepte
світла, кавова, дуже округла|light, coffee, very round|deschisă, cafea, foarte rotundă
монохром, мінімалізм|monochrome, minimal|monocrom, minimalist
помаранчевий, «таблетки»|orange, pills|portocaliu, pastile
власні кольори, з шпалер чи картинки|your colours, from wallpaper or a picture|culorile tale, din fundal sau imagine
Фон|Background|Fundal
Акцент|Accent|Accent
Другий|Second|Al doilea
Текст|Text|Text
Заокруглення|Rounding|Rotunjire
Непрозорість|Opacity|Opacitate
Кольори з шпалер|Colours from wallpaper|Culori din fundal
З картинки…|From a picture…|Din imagine…
Тема за часом доби|Theme by time of day|Temă după ora zilei
Вимкнено|Off|Oprit
Увімкнено|On|Pornit
Вдень|Daytime|Ziua
Увечері|Evening|Seara
Стиль панелі|Panel style|Stilul panoului
Плаваюча|Floating|Plutitor
Липка|Sticky|Lipit
Розмір липкої панелі|Sticky panel size|Mărimea panoului lipit
Док|Dock|Dock
Плаваючий|Floating|Plutitor
Липкий|Sticky|Lipit
Не перекривати|Don't overlap|Nu suprapune
Перекривати|Overlap|Suprapune
Перекривати й ховати|Overlap and hide|Suprapune și ascunde
Кошик у доці|Bin in the dock|Coș în dock
Без кошика|No bin|Fără coș
Панель задач Windows|Windows taskbar|Bara de activități Windows
Сховати (док valo.os)|Hide (valo.os dock)|Ascunde (dock valo.os)
Показати|Show|Arată
Інструменти|Tools|Instrumente
Буфер Win+V|Clipboard Win+V|Clipboard Win+V
Знімки PrtSc|Screenshots PrtSc|Capturi PrtSc
Емодзі Win+.|Emoji Win+.|Emoji Win+.
Гарячі кути|Hot corners|Colțuri active
Лівий верхній|Top left|Stânga sus
Правий верхній|Top right|Dreapta sus
Лівий нижній|Bottom left|Stânga jos
Правий нижній|Bottom right|Dreapta jos
Нічого|Nothing|Nimic
Меню valo.os|valo.os menu|Meniul valo.os
Центр керування|Control center|Centru de control
Робочий стіл|Desktop|Desktop
Усі вікна|All windows|Toate ferestrele
Зони вікон|Window zones|Zone pentru ferestre
Вимк.|Off|Oprit
Головне|Main|Principal
Тримайте Shift, коли перетягуєте вікно, і відпустіть над зоною.|Hold Shift while dragging a window and drop it on a zone.|Țineți Shift când trageți o fereastră și lăsați-o pe o zonă.
Ігровий режим|Game mode|Mod joc
Автоматично|Automatic|Automat
Заставка|Screensaver|Protector de ecran
Через скільки хвилин бездіяльності|After how many idle minutes|După câte minute de inactivitate
Теплий екран|Warm screen|Ecran cald
За розкладом|On schedule|După program
З|From|De la
До|To|Până la
Теплота|Warmth|Căldură
Робочі столи в доці|Desktops in the dock|Desktopuri în dock
Показувати|Show|Arată
Сховати|Hide|Ascunde
Звуки системи|System sounds|Sunete de sistem
Звуки valo.os|valo.os sounds|Sunete valo.os
Звуки Windows|Windows sounds|Sunete Windows
Живі шпалери|Live wallpapers|Fundaluri animate
Змінювати з темою|Change with theme|Schimbă cu tema
Не чіпати|Leave as is|Lasă așa
Екран блокування під тему|Lock screen to match|Ecran de blocare asortat
Погода|Weather|Vreme
Де я зараз (за IP)|Where I am (by IP)|Unde sunt (după IP)
Обране місто|Chosen city|Oraș ales
Календар|Calendar|Calendar
Зберегти календар|Save calendar|Salvează calendarul
Мова|Language|Limbă
Синхронізація через GitHub|Sync via GitHub|Sincronizare prin GitHub
Надіслати на GitHub|Send to GitHub|Trimite pe GitHub
Отримати з GitHub|Get from GitHub|Ia de pe GitHub
Резервна копія налаштувань|Settings backup|Copie de siguranță a setărilor
Зберегти у файл|Save to file|Salvează în fișier
Відновити з файлу|Restore from file|Restaurează din fișier
Майстер першого запуску|First-run wizard|Asistent la prima pornire
Оновлення valo.os|valo.os updates|Actualizări valo.os
Перевірити|Check|Verifică
Оновити|Update|Actualizează
Ще не перевірено|Not checked yet|Încă neverificat
Встановлено останню версію|Latest version installed|Ultima versiune instalată
Перевіряю…|Checking…|Verific…
Магазин valo|valo store|Magazin valo
Магазин програм|App store|Magazin de aplicații
Панель і теми|Panel and themes|Panou și teme
Налаштування Windows|Windows settings|Setări Windows
Заблокувати|Lock|Blochează
Вийти|Sign out|Deconectare
Сон|Sleep|Repaus
Перезавантажити|Restart|Repornește
Вимкнути|Shut down|Oprește
Встановити|Install|Instalează
Встановлено|Installed|Instalat
Встановлюю…|Installing…|Instalez…
Браузери|Browsers|Browsere
Спілкування|Chat|Comunicare
Медіа й творчість|Media & creative|Media și creație
Робота|Work|Lucru
Розробка|Development|Dezvoltare
Утиліти|Utilities|Utilitare
Ігри|Games|Jocuri
Wi‑Fi|Wi‑Fi|Wi‑Fi
Bluetooth|Bluetooth|Bluetooth
Звук|Sound|Sunet
В дорозі|On the go|În călătorie
Фокус|Focus|Focus
вимкнено|off|oprit
увімкнено|on|pornit
немає|none|niciunul
не підключено|not connected|neconectat
підключено|connected|conectat
збережена|saved|salvată
Інші мережі Windows…|Other Windows networks…|Alte rețele Windows…
Мережа|Network|Rețea
Пристрої|Devices|Dispozitive
Усі|All|Toate
Вихід звуку|Sound output|Ieșire audio
Зараз нічого не відтворює звук|Nothing is playing sound|Nimic nu redă sunet
Системні звуки|System sounds|Sunete de sistem
Процесор|CPU|Procesor
Пам'ять|Memory|Memorie
Температура|Temperature|Temperatură
Нагадування|Reminders|Mementouri
Про що нагадати?|Remind me about…|Ce să-ți amintesc?
через 10 хв|in 10 min|peste 10 min
30 хв|30 min|30 min
1 год|1 h|1 h
3 год|3 h|3 h
Нотатки|Notes|Notițe
Швидкі нотатки — зберігаються самі|Quick notes — saved automatically|Notițe rapide — se salvează singure
Світовий час|World clock|Ora în lume
Київ|Kyiv|Kiev
Бухарест|Bucharest|București
Прага|Prague|Praga
Варшава|Warsaw|Varșovia
як тут|same|la fel
сьогодні|today|azi
Живлення від мережі|On mains power|Alimentat de la rețea
батареї немає|no battery|fără baterie
від батареї|on battery|pe baterie
заряджається|charging|se încarcă
Попередній|Previous|Anterior
Наступний|Next|Următor
Пауза / відтворення|Pause / play|Pauză / redare
Мікшер і пристрої|Mixer and devices|Mixer și dispozitive
Мережі|Networks|Rețele
Приховані піктограми|Hidden icons|Pictograme ascunse
Почнімо|Let's start|Să începem
Далі|Next|Înainte
Назад|Back|Înapoi
Пропустити|Skip|Omite
Почати роботу|Get started|Începe
Оберіть тему|Choose a theme|Alege o temă
Панель і док|Panel and dock|Panou și dock
Верхня панель|Top panel|Panoul de sus
Липка до краю|Sticky to the edge|Lipit de margine
Док з програмами|App dock|Dock cu aplicații
Займає місце|Takes space|Ocupă spațiu
Поверх вікон|Over windows|Peste ferestre
Ховається сам|Auto-hide|Se ascunde singur
Дрібниці|Extras|Extra
Готово!|All set!|Gata!
Кілька підказок, щоб почати:|A few tips to start:|Câteva sfaturi pentru început:
Свій Alt+Tab|valo Alt+Tab|Alt+Tab valo
Історія буфера Win+V|Clipboard history Win+V|Istoric clipboard Win+V
Пошук емодзі: серце, кава, україна…|Search emoji: heart, coffee, ukraine…|Caută emoji: inimă, cafea, ucraina…
Нещодавні|Recent|Recente
Емоції|Smileys|Emoticoane
Люди й жести|People & gestures|Oameni și gesturi
Природа|Nature|Natură
Їжа|Food|Mâncare
Дозвілля|Activities|Activități
Подорожі|Travel|Călătorii
Речі|Objects|Obiecte
Символи|Symbols|Simboluri
Прапори|Flags|Steaguri
Клік — вставити · Shift+клік — вставити й не закривати · Esc — закрити|Click — insert · Shift+click — insert and keep open · Esc — close|Clic — inserează · Shift+clic — inserează și păstrează · Esc — închide
Кошик порожній|Bin is empty|Coșul e gol
ПКМ ще раз — очистити кошик назавжди|Right click again — empty the bin for good|Clic dreapta din nou — golește coșul definitiv
Новий робочий стіл|New desktop|Desktop nou
Свій перемикач вікон, історія буфера обміну й знімок області екрана. Натисніть, щоб увімкнути або вимкнути.|Own window switcher, clipboard history and area screenshots. Click to turn on or off.|Comutator de ferestre propriu, istoric clipboard și capturi de zonă. Clic pentru a porni sau opri.
Коли гра чи відео на весь екран: панель і док ховаються, сповіщення вимкнені, живлення на максимум.|When a game or video is fullscreen: panel and dock hide, notifications off, maximum power.|Când un joc sau video e pe tot ecranul: panoul și dock-ul se ascund, notificările se opresc, putere maximă.
Док резервує місце: розгорнуті вікна зупиняються над ним.|The dock reserves space: maximized windows stop above it.|Dock-ul rezervă spațiu: ferestrele maximizate se opresc deasupra lui.
Док лежить поверх вікон: розгорнуті програми займають увесь екран до низу.|The dock lies over windows: maximized apps use the whole screen.|Dock-ul stă peste ferestre: aplicațiile maximizate folosesc tot ecranul.
Док ховається, коли на ньому немає курсора. Щоб показати — доведіть курсор до нижнього краю екрана.|The dock hides when the cursor is away. Move the cursor to the bottom edge to show it.|Dock-ul se ascunde când cursorul nu e pe el. Duceți cursorul la marginea de jos ca să apară.
Плаваюча: панель з відступами від країв і заокругленими кутами.|Floating: the panel keeps a gap from the edges and has rounded corners.|Plutitor: panoul păstrează o distanță de margini și are colțuri rotunjite.
Потрібен Lively Wallpaper. Кожна тема має свої анімовані шпалери, що реагують на музику.|Needs Lively Wallpaper. Every theme has its own animated wallpaper that reacts to music.|Necesită Lively Wallpaper. Fiecare temă are fundalul ei animat, care reacționează la muzică.
Тема, панель, док, закріплені програми та інструменти — одним файлом у «Документах».|Theme, panel, dock, pinned apps and tools — one file in Documents.|Tema, panoul, dock-ul, aplicațiile fixate și instrumentele — un fișier în Documente.
Налаштування в секретному Gist вашого акаунта — однакові на всіх ПК. Потрібен GitHub CLI.|Settings in a secret Gist of your account — the same on every PC. Needs GitHub CLI.|Setările într-un Gist secret al contului tău — la fel pe toate PC-urile. Necesită GitHub CLI.
Добірка перевірених програм. Встановлення через winget; деякі програми попросять дозвіл Windows.|Hand-picked apps. Installed with winget; some will ask for Windows permission.|Aplicații alese. Instalare cu winget; unele vor cere permisiunea Windows.
Події з Google Calendar: додайте посилання .ics у «Налаштуваннях панелі» → «Календар».|Google Calendar events: add the .ics link in Panel settings → Calendar.|Evenimente Google Calendar: adăugați linkul .ics în Setările panoului → Calendar.
Місто, напр. Бухарест|City, e.g. Bucharest|Oraș, ex. București
`;
const DICT = new Map(); T.trim().split('\n').forEach(l => { const [uk, en, ro] = l.split('|'); if (uk) DICT.set(uk.trim(), { en: en?.trim(), ro: ro?.trim() }); });
const PATTERNS = [
  [/^Доступна версія (.+)$/, { en: 'Version $1 available', ro: 'Versiunea $1 disponibilă' }],
  [/^Шукати «(.+)» в інтернеті$/, { en: 'Search the web for “$1”', ro: 'Caută pe web „$1”' }],
  [/^Таймер на (.+) хв$/, { en: 'Timer for $1 min', ro: 'Cronometru $1 min' }],
  [/^Батарея (\d+)%$/, { en: 'Battery $1%', ro: 'Baterie $1%' }],
  [/^залишилось ~(.+)$/, { en: '~$1 left', ro: '~$1 rămas' }],
  [/^відчувається (.+)$/, { en: 'feels like $1', ro: 'se simte ca $1' }],
  [/^Робочий стіл (\d+)$/, { en: 'Desktop $1', ro: 'Desktop $1' }],
];
export const lang = () => localStorage.getItem('valo.lang') || 'uk';
export const locale = () => ({ en: 'en-GB', ro: 'ro-RO' }[lang()] || 'uk-UA');
export function t(uk) {
  const l = lang(); if (l === 'uk' || !uk) return uk;
  const k = uk.trim(), d = DICT.get(k);
  if (d && d[l]) return uk.replace(k, d[l]);
  for (const [re, tr] of PATTERNS) if (re.test(k)) return uk.replace(k, k.replace(re, tr[l]));
  return uk;
}
const ATTRS = ['title', 'placeholder', 'data-tip'];
// Ukrainian source text of an element (before translation)
export function source(el) { const n = el && el.firstChild; return ((n && orig.get(n)) || (el ? el.textContent : '')).trim(); }
const orig = new WeakMap();
function trNode(n) {
  if (n.nodeType === 3) {
    if (!n.nodeValue.trim()) return;
    let o = orig.get(n);
    if (o === undefined || (n.nodeValue !== o && n.nodeValue !== t(o))) { o = n.nodeValue; orig.set(n, o); }
    const v = t(o); if (n.nodeValue !== v) n.nodeValue = v;
  } else if (n.nodeType === 1) {
    if (n.tagName === 'SCRIPT' || n.tagName === 'STYLE' || n.tagName === 'TEXTAREA') return;
    for (const a of ATTRS) if (n.hasAttribute(a)) {
      const key = 'i18n' + a.replace(/-/g, '');
      const cur = n.getAttribute(a);
      if (n.dataset[key] === undefined || (cur !== n.dataset[key] && cur !== t(n.dataset[key]))) n.dataset[key] = cur;
      const v = t(n.dataset[key]); if (cur !== v) n.setAttribute(a, v);
    }
    for (const c of n.childNodes) trNode(c);
  }
}
let busy = false;
export function translate(root = document.body) { if (!root) return; busy = true; trNode(root); busy = false; }
const mo = new MutationObserver(list => {
  if (busy) return;
  busy = true;
  for (const m of list) {
    if (m.type === 'characterData') trNode(m.target);
    else if (m.type === 'attributes') trNode(m.target);
    else m.addedNodes.forEach(trNode);
  }
  busy = false;
});
function start() {
  document.documentElement.lang = lang();
  translate();
  mo.observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS });
}
if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
window.addEventListener('storage', e => { if (e.key === 'valo.lang') { document.documentElement.lang = lang(); translate(); } });
