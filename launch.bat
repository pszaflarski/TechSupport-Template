@echo off
setlocal enableextensions
cd /d "%~dp0"
if not exist "logs" mkdir "logs"

:: 1. Pre-flight internet connectivity check (HTTPS preferred, ICMP fallback)
call :check_online
if errorlevel 1 (
    echo No internet detected. Refreshing network settings...
    ipconfig /flushdns >nul 2>&1
    timeout /t 4 /nobreak >nul
    call :check_online
    if errorlevel 1 (
        echo Still offline. Please check your Wi-Fi connection or restart your router.
        pause
        exit /b 1
    )
)

:: 2. Resolve model (defaults to free-tier Flash; override in git-ignored .env)
if not defined TECHSUPPORT_MODEL set "TECHSUPPORT_MODEL=gemini-3.8-flash-high"
if exist ".env" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
        if /i "%%~A"=="TECHSUPPORT_MODEL" set "TECHSUPPORT_MODEL=%%~B"
    )
)

:: 3. Launch agy cleanly in interactive auto mode
if exist "%LOCALAPPDATA%\agy\bin" set "PATH=%LOCALAPPDATA%\agy\bin;%PATH%"
where agy >nul 2>&1
if errorlevel 1 (
    echo Tech Support could not find the 'agy' assistant on this computer.
    echo Please ask your family helper to check the installation.
    pause
    exit /b 1
)

if "%TECHSUPPORT_MODEL%"=="" (
    call agy --mode auto --dangerously-skip-permissions -i "hi"
) else if /i "%TECHSUPPORT_MODEL%"=="default" (
    call agy --mode auto --dangerously-skip-permissions -i "hi"
) else (
    call agy --model "%TECHSUPPORT_MODEL%" --mode auto --dangerously-skip-permissions -i "hi"
)

echo.
pause
exit /b 0

:check_online
curl.exe -fsIm 4 https://clients3.google.com/generate_204 >nul 2>&1
if not errorlevel 1 exit /b 0
ping -n 1 -w 2000 1.1.1.1 >nul 2>&1
if not errorlevel 1 exit /b 0
ping -n 1 -w 2000 8.8.8.8 >nul 2>&1
exit /b %errorlevel%
