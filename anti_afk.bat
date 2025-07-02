@echo off
setlocal

:: Check for admin rights
>nul 2>&1 (
    mkdir "%windir%\System32\AdminCheck" 2>nul
    rmdir "%windir%\System32\AdminCheck" 2>nul
)
if %errorlevel%==0 (
    goto :admin
)

:: Not Admin: so prompt user
echo Baya's Anti-AFK requires administrator privileges, mainly to block (keyboard & mouse) Inputs.
set "choice="
echo Run as administrator? (Y/N) - default is No after 5 seconds timeout.

:: Use choice command with timeout 5 seconds, default N (No)
choice /c YN /n /t 5 /d N >nul

if errorlevel 2 (
    echo No selected or timeout reached. Exiting.
    exit /b 1
)

if errorlevel 1 (
    echo Yes selected. Restarting as administrator...
    :: Relaunch the batch file as admin
    powershell -Command "Start-Process -FilePath '%~f0' -Verb runAs"
    exit /b
)

goto :eof

:admin
set "AFK_TIME=5" :: AFK_TIME in seconds (default is 600 seconds = 10 minutes)
set "APPS=RobloxPlayerBeta" :: APPS is a comma-separated list of application names to monitor , RobloxPlayerBeta,ApplicationFrameHost
set "KEY_TO_PRESS= " :: KEY_TO_PRESS is the key to simulate pressing when AFK
set "PLAY_PING=true" :: PLAY_PING is a boolean to enable/disable ping sound


powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "& { . '%~dp0Library\anti_afk.ps1' -AFK_TIME %AFK_TIME% -APPS '%APPS%' -KEY_TO_PRESS '%KEY_TO_PRESS%' -PLAY_PING ([bool]::Parse('%PLAY_PING%')) }"

pause
