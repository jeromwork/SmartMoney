# AGENTS.md

Обязательные правила для любого ИИ-агента (Codex, ChatGPT, внутренние агенты), работающего в этом репозитории.

## 1) Обязательный порядок работы

1. Перед любыми изменениями прочитать:
   - `README.md`
   - `docs/strategy/current-strategy.md`
   - этот файл `AGENTS.md`
2. Сначала синхронизировать понимание стратегии, потом писать код.
3. Любое изменение в `EA`/индикаторах сначала сверять с текущей стратегией в `docs/strategy/current-strategy.md`.
4. После изменений обязательно прогонять проверку скриптов:
   - `powershell -ExecutionPolicy Bypass -File scripts/test-scripts.ps1`
5. Для кода `EA` обязательно делать минимум:
   - `build.ps1`
   - `backtest.ps1` (если есть валидные данные входа в терминал)
6. Если команда/сценарий не может быть выполнен, агент обязан явно указать причину и следующий шаг.

## 2) Технические ограничения проекта

- Основная платформа: `MT5 / MQL5`.
- Исходники стратегии:
  - `src/MQL5/Experts`
  - `src/MQL5/Indicators`
  - `src/MQL5/Include`
- Скрипты автоматизации в `scripts/`.
- Терминальные слоты:
  - `terminals/mt5-dev`
  - `terminals/mt5-test`
  - `terminals/mt5-demo`

## 3) Что агенту запрещено

- Нарушать стратегию без обновления `docs/strategy/current-strategy.md`.
- Делать деструктивные git-операции (`reset --hard`, `checkout --`, переписывание истории) без явного запроса.
- Смешивать роли слотов:
  - `dev` для ручной работы/подкачки данных,
  - `test` для автотестов,
  - `demo` для форвард-прогонов.
- Писать секреты (пароли, токены) в репозиторий.

## 4) Обязательный формат результата от агента

После каждой завершенной задачи агент должен выдать:

1. Что изменено (кратко, по сути).
2. Какие команды запускались.
3. Результат проверок (`build/backtest/logs`).
4. Что осталось вручную (если осталось).

## 5) Стандартные команды

- Проверка скриптов:
  - `powershell -ExecutionPolicy Bypass -File scripts/test-scripts.ps1`
- Сборка EA:
  - `powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Source src/MQL5/Experts/SmartMoneyEA.mq5 -Terminal test`
- Бэктест:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -Expert SmartMoneyEA -Symbol EURUSD -Period H1 -SetFile SmartMoneyEA.set -From 2024.01.01 -To 2024.12.31 -Login <LOGIN> -Server <SERVER> -Password <PASSWORD>`
- Сбор логов:
  - `powershell -ExecutionPolicy Bypass -File scripts/collect-logs.ps1 -Terminal test`
- Запуск demo:
  - `powershell -ExecutionPolicy Bypass -File scripts/demo-launch.ps1 -Expert SmartMoneyEA -Symbol EURUSD -Period H1 -SetFile SmartMoneyEA.set -Login <LOGIN> -Server <SERVER> -Password <PASSWORD>`

## 6) Правило качества

Любое изменение считается незавершенным, пока не выполнены:

1. `scripts/test-scripts.ps1` без ошибок.
2. `build.ps1` для измененного `EA/indicator`.
3. Анализ логов после `backtest/demo` (если запускались).
