# valo.os

Оболонка для Windows 11 у стилі «Сакура»: верхня панель, меню з розумним пошуком, док, центр керування, живі шпалери, свій Alt+Tab, історія буфера, знімки, емодзі, теми — і оновлення з цього репозиторію.

## Встановити на свою Windows 11

У PowerShell (без прав адміністратора; Windows може попросити дозвіл на встановлення Zebar):

```powershell
irm https://raw.githubusercontent.com/SOVALONE/valo-os/main/install.ps1 | iex
```

Бета-версії: ` = 'beta'` перед командою.

## Видалити

```powershell
irm https://raw.githubusercontent.com/SOVALONE/valo-os/main/uninstall.ps1 | iex
```

## Оновлення

Меню valo.os → «Перевірити оновлення». Кожен випуск підписаний ключем valo.os (RSA-3072): `stable.json` / `beta.json` + `.sig`, файли випуску в `releases/<версія>/` з SHA-256. Історія змін — [Releases](https://github.com/SOVALONE/valo-os/releases).