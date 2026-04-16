@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." || goto :fail_cd
set "ROOT=%CD%"
popd
cd /d "%ROOT%" || goto :fail_cd

echo [Template] testervisual__EA_NAME__VERSION__SYMBOL_TF_PERIOD
REM powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\launchers\tester-visual-EA_NAME.ps1" -Symbol EURUSD -Period H1 -From 2024.01.01 -To 2024.12.31 -SetFile EA_NAME.set
set "CODE=0"
goto :end

:fail_cd
echo [ERROR] Cannot switch to project root: %ROOT%
set "CODE=2"

:end
if not defined RUN_NO_PAUSE pause
exit /b %CODE%
