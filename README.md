# SmartMoney MQL5 Workspace

Изолированная среда для разработки `MQL5`-советников и индикаторов в `VSCode + Codex` с отдельными инстансами `MT5` под `dev`, `test`, `demo`.

## Что уже подготовлено

- Структура проекта для `Experts`, `Indicators`, `Include`
- Черновик стратегии в `docs/strategy`
- PowerShell-скрипты для `build`, `backtest`, `demo-launch`, `collect-logs`, `parse-report`, `sync-data`
- Каркасы `EA`, индикатора и общих утилит
- Конфигурация `VSCode tasks`
- Локальный Git-репозиторий

## Что нужно для сборки и тестов

1. Положить брокерский инсталлятор в `downloads/mt5setup.exe` или передать путь в `scripts/install-finam-terminal.ps1 -InstallerPath ...`
2. Запустить `scripts/install-finam-terminal.ps1`
3. Убедиться, что в терминале есть каталог `MQL5`
4. При необходимости открыть `mt5-dev` и подключить demo/real сервер брокера для подкачки истории
5. Использовать VSCode tasks или PowerShell-скрипты напрямую

Для `backtest.ps1` в MT5 обычно нужно передавать аккаунт:
`-Login <id> -Server <server> -Password <password>`
или предварительно выполнить вход в слоте `mt5-test`.

## Рабочий цикл

1. Формализовать стратегию в `docs/strategy/current-strategy.md`
2. Дорабатывать `src/MQL5/...`
3. Запускать `build`
4. Запускать `backtest`
5. Анализировать `logs/` и `reports/`
6. После стабилизации запускать `mt5-demo`

## Важное замечание

Слоты терминалов в проекте используют формат `terminals/mt5-*`; текущий pipeline настроен на `MT5/MQL5`.
