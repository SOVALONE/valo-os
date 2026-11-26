# valo.os

Оболонка для Windows 11 у стилі «Сакура»: верхня панель, меню з розумним пошуком, док, центр керування, живі шпалери, свій Alt+Tab, історія буфера, знімки, емодзі, теми — і оновлення з цього репозиторію.

Сайт: https://sovalone.github.io/valo-os/

## Встановити на свою Windows 11

У PowerShell (без прав адміністратора; Windows може попросити дозвіл на встановлення Zebar):

```powershell
irm https://raw.githubusercontent.com/SOVALONE/valo-os/main/install.ps1 | iex
```

Бета-версії: ` = 'beta'` перед командою.

## valo Link — телефон разом з ПК

Необов'язковий: на ПК встановлюється з меню → «Магазин valo» → valo Link (значок у треї). На телефоні — сторінка в браузері або застосунок для Android: https://sovalone.github.io/valo-os/valo-link.apk (фонові сповіщення на ПК, «Поділитися → valo Link», гучний пошук телефона).

## Видалити

```powershell
irm https://raw.githubusercontent.com/SOVALONE/valo-os/main/uninstall.ps1 | iex
```

## Оновлення

Меню valo.os → «Перевірити оновлення». Кожен випуск підписаний ключем valo.os (RSA-3072): `stable.json` / `beta.json` + `.sig`, файли випуску в `releases/<версія>/` з SHA-256. Історія змін — [Releases](https://github.com/SOVALONE/valo-os/releases).