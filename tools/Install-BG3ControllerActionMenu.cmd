@echo off
setlocal EnableExtensions

if /I "%~1"=="--self-test" (
    echo one-click cmd launcher syntax OK
    exit /b 0
)

set "BASEDIR=%~dp0"
set "BOOTSTRAP=%BASEDIR%install-latest.ps1"

if not exist "%BOOTSTRAP%" (
    echo.
    echo BG3 Controller Action Menu installer
    echo.
    echo ERROR: installer component is missing:
    echo "%BOOTSTRAP%"
    echo.
    echo Extract the entire ZIP to a normal folder before running this file.
    echo.
    pause
    exit /b 2
)

set "STATEDIR=%LOCALAPPDATA%\BG3ControllerActionMenu"
if not exist "%STATEDIR%" mkdir "%STATEDIR%" >nul 2>nul

set "LOG=%STATEDIR%\install-latest.log"
set "STATUS=%STATEDIR%\install-status.txt"
set "REPORT=%STATEDIR%\xbox-dev-environment.json"

if exist "%STATUS%" del /q "%STATUS%" >nul 2>nul

set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL%" set "POWERSHELL=powershell.exe"

echo.
echo BG3 Controller Action Menu
echo ==========================
echo.
echo Installing the newest published release.
echo This window shows real progress and will stay open if installation fails.
echo.

"%POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BOOTSTRAP%" -LogPath "%LOG%" -StatusPath "%STATUS%" -ReportPath "%REPORT%"
set "EXITCODE=%ERRORLEVEL%"

if "%EXITCODE%"=="0" (
    echo.
    echo Installation completed successfully.
    echo.
    timeout /t 3 /nobreak >nul
    exit /b 0
)

echo.
echo Installation failed safely.
echo.
echo Log:
echo   %LOG%
echo.
echo Diagnostic report:
echo   %REPORT%
echo.
pause
exit /b %EXITCODE%
