@echo off
setlocal

REM Configurable parameters
set "AFK_TIME=5"        REM Time in minutes before AFK
set "APPS=RobloxPlayerBeta, ApplicationFrameHost"  REM List of process names (no .exe)
set "KEY_TO_PRESS=h"    REM Key to press 

REM Run PowerShell script with parameters
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { . '%~dp0Library\anti_afk.ps1' -AFK_TIME %AFK_TIME% -APPS %APPS% -KEY_TO_PRESS '%KEY_TO_PRESS%' }"
