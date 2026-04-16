# Run Folder

Основные `.bat`-запускатели для быстрого старта сценариев.

Схема имени файла:

`<mode>__<ea_name>__<version>__<usecase>.bat`

Запускать (рабочие сценарии):
- `manual__smartmoneyea__v1__demo.bat`
- `manual__smartmoneyea__v1__multitf.bat`
- `testerui__smartmoneyea__v1__eurusd_h1.bat`
- `testervisual__smartmoneyea__v1__eurusd_h1_2024.bat`

Не запускать (это шаблоны):
- папка `run/templates`

Особенности:
- Каждый `.bat` печатает ошибку и не закрывается мгновенно (`pause`).
- Для CI/автоматических вызовов можно отключить паузу: `set RUN_NO_PAUSE=1`.
- Внутри используются PowerShell launchers из `scripts/launchers`.

Важно:
- В папке `run` размещены только сценарии для ручного тестирования пользователем.
- Полностью автоматические прогоны и пост-обработка логов выполняются отдельными PowerShell-скриптами и не дублируются в `run`.

`testervisual__...`:
- автоматически выбирает Expert/Symbol/Period/Set/Date,
- автоматически стартует Visual tester,
- дальше управление (пауза/скорость/просмотр сделок) остается в UI терминала.
