# Launchers

PowerShell-запускатели для SmartMoneyEA.

## Ручной режим (готовый demo-терминал)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/launchers/manual-smartmoneyea.ps1
```

## Автоматический прогон (служебный)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/launchers/autotest-smartmoneyea.ps1
```

Этот скрипт предназначен для автоматических прогонов и не выносится в `run` как основной пользовательский сценарий.

## Tester UI (ручной запуск теста пользователем)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/launchers/tester-ui-smartmoneyea.ps1
```

Что делает:
- собирает EA/индикатор,
- копирует `.set` в тестовый терминал,
- открывает `mt5-test`,
- дальше тест запускается вручную в Strategy Tester (Ctrl+R).

## Credentials

Все launcher-скрипты могут брать `MT5_LOGIN`, `MT5_PASSWORD`, `MT5_SERVER` из `.env`.
