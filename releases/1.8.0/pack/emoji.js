// valo.os emoji picker data: [emoji, category, keywords (Ukrainian + English)]
export const CATS = [['smile', '😀', 'Емоції'], ['people', '👋', 'Люди й жести'], ['nature', '🐱', 'Природа'], ['food', '🍔', 'Їжа'],
  ['activity', '⚽', 'Дозвілля'], ['travel', '✈️', 'Подорожі'], ['objects', '💡', 'Речі'], ['symbols', '❤️', 'Символи'], ['flags', '🏳️', 'Прапори']];
const D = `
😀 smile усмішка радість smile happy grin|😃 smile усмішка радісний|😄 smile сміх радість laugh|😁 smile посмішка зуби grin|😆 smile регіт сміх laugh|😅 smile полегшення піт sweat|
🤣 smile регочу ржу rofl|😂 smile сльози сміху lol joy|🙂 smile усмішка легка|🙃 smile догори ногами upside|😉 smile підморгує wink|😊 smile сором'язливо blush|
😇 smile янгол angel halo|🥰 smile закоханий сердечка love|😍 smile закоханий очі серця love|🤩 smile зірки вау star|😘 smile поцілунок kiss|😗 smile поцілунок|
😋 smile смачно yum|😛 smile язик tongue|😜 smile язик підморг|🤪 smile божевільний crazy|😝 smile язик заплющені|🤑 smile гроші money|
🤗 smile обійми hug|🤭 smile ой хихи oops|🤫 smile тихо тсс shh|🤔 smile думаю хм think|🤐 smile мовчу zip|🤨 smile підозра брова|
😐 smile нейтрально neutral|😑 smile без виразу|😶 smile без рота|😏 smile самовдоволено smirk|😒 smile невдоволений unamused|🙄 smile закочує очі eyeroll|
😬 smile ніяково grimace|😌 smile спокій relieved|😔 smile сумно pensive|😪 smile сонний sleepy|😴 smile сплю sleep|😷 smile хворий маска mask|
🤒 smile температура хворий sick|🤕 smile травма|🤢 smile нудить nausea|🤮 smile блює vomit|🥵 smile жарко hot|🥶 smile холодно cold|
😵 smile запаморочення dizzy|🤯 smile вибух мозку mind blown|🤠 smile ковбой cowboy|🥳 smile свято вечірка party|😎 smile круто окуляри cool|🤓 smile ботан nerd|
😕 smile збентежений confused|😟 smile хвилююсь worried|🙁 smile сумний|😮 smile здивований wow|😲 smile шок astonished|😳 smile почервонів flushed|
🥺 smile благаю pleading|😦 smile жах|😨 smile страх fear|😰 smile тривога anxious|😢 smile плачу cry|😭 smile ридаю sob|
😱 smile крик жах scream|😖 smile розпач|😣 smile терплю|😞 smile розчарований disappointed|😓 smile втомився|😩 smile змучений weary|
😤 smile злюсь пара|😡 smile злий angry|🤬 smile лаюсь cursing|😈 smile чортик devil|💀 smile череп skull|💩 smile какашка poop|
🤡 smile клоун clown|👻 smile привид ghost|👽 smile прибулець alien|🤖 smile робот robot|😺 smile кіт усмішка cat|😻 smile кіт закоханий|
👋 people привіт махати wave hi|🤚 people долоня|✋ people стоп рука hand|👌 people окей ok|🤌 people італійський жест|✌️ people мир перемога peace|
🤞 people схрещені пальці luck|🤟 people люблю тебе|🤘 people рок rock|🤙 people подзвони call|👈 people ліворуч left|👉 people праворуч right|
👆 people вгору up|👇 people вниз down|👍 people клас лайк добре like yes thumbs|👎 people погано дизлайк no|✊ people кулак fist|👊 people удар|
👏 people оплески браво clap|🙌 people ура hooray|👐 people відкриті руки|🤲 people долоні|🤝 people рукостискання угода deal|🙏 people дякую будь ласка молитва pray thanks|
✍️ people пишу write|💪 people сила м'язи strong|🧠 people мозок brain|👀 people очі дивлюсь eyes|👁️ people око|👄 people губи|
👶 people дитина baby|🧒 people дитина|👦 people хлопчик boy|👧 people дівчинка girl|🧑 people людина|👨 people чоловік man|
👩 people жінка woman|🧓 people літня людина|👴 people дідусь|👵 people бабуся|🧑‍💻 people програміст розробник developer coder|👩‍🎨 people художниця artist|
🧑‍🍳 people кухар cook|🧑‍🚀 people космонавт|🦸 people супергерой hero|🧙 people чарівник wizard|💃 people танцюю dance|🕺 people танцюю|
🚶 people йду walk|🏃 people біжу run|🧘 people йога медитація yoga|🛌 people сплю ліжко|👪 people сім'я family|💑 people пара love|
🐶 nature собака пес dog|🐱 nature кіт кішка cat|🐭 nature миша mouse|🐹 nature хом'як|🐰 nature кролик rabbit|🦊 nature лис лисиця fox|
🐻 nature ведмідь bear|🐼 nature панда panda|🐨 nature коала|🐯 nature тигр tiger|🦁 nature лев lion|🐮 nature корова cow|
🐷 nature свиня pig|🐸 nature жаба frog|🐵 nature мавпа monkey|🐔 nature курка chicken|🐧 nature пінгвін penguin|🐦 nature пташка bird|
🦆 nature качка duck|🦉 nature сова owl|🦄 nature єдиноріг unicorn|🐝 nature бджола bee|🦋 nature метелик butterfly|🐌 nature равлик snail|
🐞 nature сонечко|🐢 nature черепаха turtle|🐍 nature змія snake|🐙 nature восьминіг octopus|🐬 nature дельфін dolphin|🐳 nature кит whale|
🐟 nature риба fish|🦈 nature акула shark|🌸 nature сакура квітка cherry blossom|🌹 nature троянда rose|🌻 nature соняшник sunflower|🌷 nature тюльпан tulip|
🌱 nature паросток росток sprout|🌿 nature трава зелень herb|🍀 nature конюшина удача clover luck|🍁 nature клен лист осінь maple|🍂 nature листя осінь fall|🌲 nature ялинка дерево tree|
🌴 nature пальма palm|🌵 nature кактус cactus|🌞 nature сонце sun|🌝 nature місяць moon|🌙 nature місяць ніч moon|⭐ nature зірка star|
🌟 nature зірка сяє|✨ nature блиск іскри sparkles|⚡ nature блискавка енергія lightning|🔥 nature вогонь круто fire hot|🌈 nature веселка rainbow|☁️ nature хмара cloud|
🌧️ nature дощ rain|⛈️ nature гроза storm|❄️ nature сніг сніжинка snow|☃️ nature сніговик snowman|🌊 nature хвиля море wave|💧 nature крапля water|
🍎 food яблуко apple|🍐 food груша pear|🍊 food апельсин orange|🍋 food лимон lemon|🍌 food банан banana|🍉 food кавун watermelon|
🍇 food виноград grapes|🍓 food полуниця strawberry|🍒 food вишня черешня cherry|🍑 food персик peach|🥭 food манго mango|🍍 food ананас pineapple|
🥥 food кокос|🥝 food ківі kiwi|🍅 food помідор томат tomato|🥑 food авокадо avocado|🥦 food броколі|🥕 food морква carrot|
🌽 food кукурудза corn|🌶️ food перець гострий pepper|🥔 food картопля potato|🍞 food хліб bread|🥐 food круасан croissant|🥖 food багет|
🧀 food сир cheese|🥚 food яйце egg|🍳 food яєчня сніданок breakfast|🥞 food млинці pancakes|🥓 food бекон bacon|🍗 food курка ніжка|
🍖 food м'ясо meat|🍔 food бургер burger|🍟 food картопля фрі fries|🍕 food піца pizza|🌭 food хот-дог hotdog|🥪 food сендвіч бутерброд sandwich|
🌮 food тако taco|🌯 food шаурма буріто burrito|🥗 food салат salad|🍝 food паста спагеті pasta|🍜 food локшина рамен ramen|🍲 food суп борщ soup|
🍣 food суші sushi|🍱 food бенто|🥟 food вареники пельмені dumpling|🍦 food морозиво icecream|🍰 food торт тістечко cake|🎂 food торт день народження birthday cake|
🍩 food пончик donut|🍪 food печиво cookie|🍫 food шоколад chocolate|🍬 food цукерка candy|🍯 food мед honey|☕ food кава чай coffee|
🍵 food чай tea|🧃 food сік juice|🥤 food напій drink|🍺 food пиво beer|🍻 food пиво будьмо cheers|🍷 food вино wine|
🥂 food шампанське тост cheers|🍸 food коктейль cocktail|🥃 food віскі|🍾 food шампанське свято|🧊 food лід ice|🥄 food ложка|
⚽ activity футбол м'яч football soccer|🏀 activity баскетбол basketball|🏈 activity американський футбол|⚾ activity бейсбол|🎾 activity теніс tennis|🏐 activity волейбол volleyball|
🏓 activity пінг-понг|🏸 activity бадмінтон|🥊 activity бокс boxing|🥋 activity карате|⛳ activity гольф golf|⛸️ activity ковзани|
🎿 activity лижі ski|🏂 activity сноуборд|🏋️ activity штанга спортзал gym|🚴 activity велосипед bike|🏊 activity плавання swim|🧗 activity скелелазіння|
🏆 activity кубок перемога trophy|🥇 activity золото перше місце gold|🥈 activity срібло|🥉 activity бронза|🏅 activity медаль medal|🎖️ activity орден|
🎮 activity гра ігри геймпад game|🕹️ activity джойстик|🎲 activity кубик|♟️ activity шахи chess|🎯 activity ціль target|🎳 activity боулінг|
🎨 activity малювання art paint|🎭 activity театр theatre|🎬 activity кіно movie|🎤 activity мікрофон караоке mic|🎧 activity навушники музика headphones|🎵 activity нота музика music|
🎶 activity музика ноти|🎸 activity гітара guitar|🎹 activity піаніно piano|🥁 activity барабан drum|🎻 activity скрипка violin|🎉 activity свято вечірка party|
🎊 activity конфеті|🎁 activity подарунок gift|🎈 activity кулька balloon|🎄 activity ялинка новий рік christmas|🎃 activity гарбуз хелловін|🧧 activity конверт|
✈️ travel літак політ plane flight|🛫 travel виліт|🛬 travel посадка|🚀 travel ракета rocket|🛸 travel нло ufo|🚁 travel гелікоптер|
🚂 travel потяг паровоз train|🚆 travel потяг train|🚇 travel метро metro|🚌 travel автобус bus|🚕 travel таксі taxi|🚗 travel авто машина car|
🚙 travel позашляховик|🚲 travel велосипед bicycle|🛴 travel самокат|🏍️ travel мотоцикл|⛵ travel вітрильник|🚢 travel корабель ship|
⚓ travel якір|⛽ travel заправка fuel|🚦 travel світлофор|🗺️ travel мапа карта map|🧭 travel компас compass|🏔️ travel гори mountain|
🏕️ travel кемпінг camping|🏖️ travel пляж beach|🏝️ travel острів island|🏜️ travel пустеля|🏙️ travel місто city|🌃 travel нічне місто night|
🏠 travel дім будинок home house|🏢 travel офіс office|🏰 travel замок castle|⛪ travel церква|🗼 travel вежа|🗽 travel статуя свободи|
🧳 travel валіза багаж luggage|🎒 travel рюкзак backpack|🎫 travel квиток ticket|🛂 travel паспортний контроль passport|🌍 travel земля світ europe world|🌐 travel інтернет глобус globe|
💡 objects ідея лампочка idea|📱 objects телефон phone|💻 objects ноутбук laptop|🖥️ objects комп'ютер монітор computer|⌨️ objects клавіатура keyboard|🖱️ objects миша mouse|
🖨️ objects принтер|📷 objects фото камера camera|🎥 objects відео|📺 objects телевізор tv|📻 objects радіо|⏰ objects будильник alarm|
⌛ objects пісочний годинник|⏳ objects час чекаю wait|📡 objects антена|🔋 objects батарея battery|🔌 objects розетка вилка plug|💸 objects гроші летять|
💵 objects долари гроші money|💶 objects євро гроші euro|💳 objects картка card|💎 objects діамант gem|🔧 objects ключ гайковий wrench|🔨 objects молоток hammer|
🛠️ objects інструменти tools|⚙️ objects налаштування шестерня gear settings|🔒 objects замок закрито lock|🔓 objects відкрито unlock|🔑 objects ключ key|🗝️ objects старий ключ|
📦 objects коробка посилка package|📫 objects пошта mail|✉️ objects лист email|📝 objects нотатка записати memo note|📅 objects календар calendar|📌 objects шпилька pin|
📎 objects скріпка clip|✂️ objects ножиці|🖊️ objects ручка pen|✏️ objects олівець pencil|📚 objects книги books|📖 objects книга book|
🔍 objects пошук лупа search|💊 objects таблетка pill|🩺 objects лікар|🧪 objects колба test|🧲 objects магніт|🪄 objects чарівна паличка magic|
🛒 objects кошик покупки cart shop|🛍️ objects покупки shopping|🕯️ objects свічка candle|🪴 objects рослина вазон plant|🛏️ objects ліжко bed|🚿 objects душ shower|
❤️ symbols серце любов love heart red|🧡 symbols помаранчеве серце|💛 symbols жовте серце|💚 symbols зелене серце|💙 symbols синє серце|💜 symbols фіолетове серце|
🖤 symbols чорне серце|🤍 symbols біле серце|🤎 symbols коричневе серце|💔 symbols розбите серце broken|❣️ symbols серце|💕 symbols два серця|
💞 symbols серця|💖 symbols серце сяє|💗 symbols серце росте|💘 symbols серце стріла|💝 symbols серце подарунок|💯 symbols сто відсотків 100|
✅ symbols готово так галочка done check yes|☑️ symbols галочка|✔️ symbols галочка|❌ symbols ні хрестик no cross|❎ symbols хрестик|➕ symbols плюс plus|
➖ symbols мінус|➗ symbols ділення|✖️ symbols множення|❓ symbols питання question|❗ symbols увага оклик|⚠️ symbols попередження warning|
🚫 symbols заборонено|⛔ symbols стоп|🔞 symbols 18+|♻️ symbols переробка recycle|✳️ symbols зірочка|❇️ symbols іскра|
🔴 symbols червоне коло|🟠 symbols помаранчеве коло|🟡 symbols жовте коло|🟢 symbols зелене коло|🔵 symbols синє коло|🟣 symbols фіолетове коло|
⚫ symbols чорне коло|⚪ symbols біле коло|🔺 symbols трикутник|🔻 symbols трикутник вниз|💠 symbols ромб|🔷 symbols синій ромб|
➡️ symbols стрілка праворуч arrow right|⬅️ symbols стрілка ліворуч left|⬆️ symbols стрілка вгору up|⬇️ symbols стрілка вниз down|↩️ symbols назад|🔄 symbols оновити refresh|
🆗 symbols ок|🆕 symbols нове new|🆓 symbols безкоштовно free|🔝 symbols топ|™️ symbols торгова марка|©️ symbols копірайт|
🇺🇦 flags україна ukraine|🇷🇴 flags румунія romania|🇨🇿 flags чехія czech|🇵🇱 flags польща poland|🇲🇩 flags молдова moldova|🇪🇺 flags євросоюз eu europe|
🇩🇪 flags німеччина germany|🇫🇷 flags франція france|🇮🇹 flags італія italy|🇪🇸 flags іспанія spain|🇬🇧 flags британія uk|🇺🇸 flags сша usa|
🇨🇦 flags канада|🇯🇵 flags японія japan|🇰🇷 flags корея|🇸🇰 flags словаччина|🇭🇺 flags угорщина|🇦🇹 flags австрія|
🇳🇱 flags нідерланди|🇵🇹 flags португалія|🇬🇪 flags грузія|🇱🇹 flags литва|🇱🇻 flags латвія|🇪🇪 flags естонія|
🏳️ flags білий прапор|🏴 flags чорний прапор|🏁 flags фініш|🚩 flags червоний прапорець|🏳️‍🌈 flags веселка прайд pride|🏴‍☠️ flags пірати pirate`;
export const EMOJI = D.split('|').map(x => x.trim()).filter(Boolean).map(x => {
  const i = x.indexOf(' '), rest = x.slice(i + 1), j = rest.indexOf(' ');
  return { e: x.slice(0, i), cat: rest.slice(0, j), k: rest.slice(j + 1).toLowerCase() };
});
