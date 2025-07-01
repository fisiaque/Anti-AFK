@echo off
setlocal

REM AFK_TIME in seconds (default is 600 seconds = 10 minutes)
REM APPS is a comma-separated list of application names to monitor
REM KEY_TO_PRESS is the key to simulate pressing when AFK
REM PLAY_PING is a boolean to enable/disable ping sound

set "AFK_TIME=600"
set "APPS=RobloxPlayerBeta,ApplicationFrameHost"
set "KEY_TO_PRESS=h"
set "PLAY_PING=true"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "& { . '%~dp0Library\anti_afk.ps1' -AFK_TIME %AFK_TIME% -APPS '%APPS%' -KEY_TO_PRESS '%KEY_TO_PRESS%' -PLAY_PING ([bool]::Parse('%PLAY_PING%')) }"

pause
