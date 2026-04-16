@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.." || goto :fail_cd
set "ROOT=%CD%"
popd
cd /d "%ROOT%" || goto :fail_cd

echo [RUN] install__mt5__dev_test_demo
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\install-finam-terminal.ps1"
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" goto :fail_ps

echo [OK] install__mt5__dev_test_demo finished
goto :done

:fail_cd
echo [ERROR] Cannot switch to project root: %ROOT%
set "CODE=2"
goto :end

:fail_ps
echo [ERROR] Installer failed with code %CODE%
goto :end

:done
set "CODE=0"

:end
if not defined RUN_NO_PAUSE pause
exit /b %CODE%
