# Anti-AFK Script

A Windows automation tool that prevents being flagged as AFK by simulating key presses in specified applications at configurable intervals.

## Project Structure

.
├── Library
│ └── anti_afk.ps1
└── anti_afk.bat

## Overview

- Monitors running processes specified by name.
- Starts processes if not running.
- After a set idle time (minutes), simulates a double key press in each app window.
- Uses Windows API for window focus and positioning.
- Plays sound notifications on each action cycle.
- Console-based with an emergency quit (`Q`) key.

## Configuration (in `anti_afk.bat`)

- `AFK_TIME`: Idle time in minutes before triggering key press.
- `APPS`: Comma-separated list of process names (without `.exe`).
- `KEY_TO_PRESS`: The key to simulate pressing.

## Usage

1. Adjust parameters in `anti_afk.bat`.
2. Run `anti_afk.bat`.
3. The script will launch/attach to the apps and perform anti-AFK actions at intervals.
4. Press `Q` in the console window to exit.

## Requirements

- Windows with PowerShell enabled.
- Execution policy allowing script execution (`Bypass` used).
- Target apps must have visible main windows.

## Notes

- Key press simulation is done via `[System.Windows.Forms.SendKeys]`.
- Windows API calls enable window manipulation and focus control.
- Audible beeps indicate action cycles.
