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
:: CONFIGURABLE
set "AFK_TIME=900" :: AFK_TIME in seconds (default is 900 seconds = 15 minutes)
set "PLAY_PING=true" :: PLAY_PING is a boolean to enable/disable ping sound
set "APPS=RobloxPlayerBeta,ApplicationFrameHost" :: APPS is a comma-separated list of application names to monitor , RobloxPlayerBeta,ApplicationFrameHost
set "SHOULD_MINIMIZE=false" :: Window minizes after every AFK_TIME
set "KEYS_TO_PRESS=h" :: KEY TO PRESS IN CAPS! CAN MAKE MULTIPLE BUTTONS (h, space, w, 2, f) etc

:::::::::::::::::::::::::::::
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "& { . '%~dp0Library\anti_afk.ps1' -AFK_TIME %AFK_TIME% -APPS '%APPS%' -PLAY_PING ([bool]::Parse('%PLAY_PING%')) -SHOULD_MINIMIZE ([bool]::Parse('%SHOULD_MINIMIZE%')) -KEYS_TO_PRESS '%KEYS_TO_PRESS%' }"

pause
