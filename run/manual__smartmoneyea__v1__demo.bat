@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." || goto :fail_cd
set "ROOT=%CD%"
popd
cd /d "%ROOT%" || goto :fail_cd

echo [RUN] manual__smartmoneyea__v1__demo
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\launchers\manual-smartmoneyea.ps1" -Symbol EURUSD -Period H1 -SetFile SmartMoneyEA.set
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" goto :fail_ps

echo [OK] manual__smartmoneyea__v1__demo finished
goto :done

:fail_cd
echo [ERROR] Cannot switch to project root: %ROOT%
set "CODE=2"
goto :end

:fail_ps
echo [ERROR] Launcher failed with code %CODE%
goto :end

:done
set "CODE=0"

:end
if not defined RUN_NO_PAUSE pause
exit /b %CODE%
