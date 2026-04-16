# USAGE.md

Краткая инструкция, как пользоваться системой разработки и тестов.

## 1) Первый запуск

1. Установить терминал в проект (если еще не установлен):
   - `powershell -ExecutionPolicy Bypass -File scripts/install-finam-terminal.ps1 -InstallerPath C:\work\MQL\SmartMoney\downloads\mt5setup.exe`
2. Проверить скрипты:
   - `powershell -ExecutionPolicy Bypass -File scripts/test-scripts.ps1`

## 2) Ежедневный цикл работы

1. Обновить правила стратегии в `docs/strategy/current-strategy.md`.
2. Внести изменения в:
   - `src/MQL5/Experts/...`
   - `src/MQL5/Indicators/...`
   - `src/MQL5/Include/...`
3. Выполнить сборку:
   - `powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Source src/MQL5/Experts/SmartMoneyEA.mq5 -Terminal test`
4. Выполнить бэктест:
   - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -Expert SmartMoneyEA -Symbol EURUSD -Period H1 -SetFile SmartMoneyEA.set -From 2024.01.01 -To 2024.12.31 -Login <LOGIN> -Server <SERVER> -Password <PASSWORD>`
5. Собрать логи:
   - `powershell -ExecutionPolicy Bypass -File scripts/collect-logs.ps1 -Terminal test`

## 3) Демо-прогон

Запуск в demo-слоте:

`powershell -ExecutionPolicy Bypass -File scripts/demo-launch.ps1 -Expert SmartMoneyEA -Symbol EURUSD -Period H1 -SetFile SmartMoneyEA.set -Login <LOGIN> -Server <SERVER> -Password <PASSWORD>`

## 4) Через VSCode Tasks

Используйте задачи из `.vscode/tasks.json`:

- `scripts:validate`
- `mql5:build-ea`
- `mql5:backtest-ea`
- `mt5:collect-logs`
- `mt5:launch-demo`

## 5) Как работать с ИИ

Рекомендуемый шаблон запроса:

1. "Прочитай `AGENTS.md`, `README.md`, `docs/strategy/current-strategy.md`."
2. "Сделай изменение X в `MQL5`."
3. "Запусти `test-scripts`, `build`, `backtest`, собери логи."
4. "Дай краткий отчет: изменения, команды, результат, остатки."

## 6) Частые проблемы

- `tester not started because the account is not specified`:
  - передайте `-Login/-Server/-Password` в `backtest.ps1`.
- `MQL5 include not found`:
  - убедитесь, что запуск был через `build.ps1`, он синхронизирует `src/MQL5` в терминал.
- Бэктест прошел, но нет отчета:
  - ориентируйтесь на `logs/tester/*.log`; не все сборки терминала стабильно создают файл отчета.
