param (
    [float]$AFK_TIME = 0,
    [string[]]$APPS = @(""),
    [bool]$PLAY_PING = $false,
    [bool]$SHOULD_MINIMIZE = $false,
    [string[]]$KEYS_TO_PRESS = @(""),
    [string]$DIRECTORY = ""
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$dllsPath = Join-Path $DIRECTORY "DLLs"
$libraryPath = Join-Path $DIRECTORY "Library"

$nativeMethodsCode = Get-Content -Path (Join-Path $libraryPath "NativeMethods.cs") -Raw
$pressKeyCode = Get-Content -Path (Join-Path $libraryPath "PressKey.cs") -Raw

Add-Type -TypeDefinition $nativeMethodsCode -Language CSharp
Add-Type -TypeDefinition $pressKeyCode -Language CSharp
Add-Type -AssemblyName System.Windows.Forms

function Get-ElaspsedTime {
    $elapsed = $stopwatch.Elapsed
    if ($elapsed.TotalHours -lt 24) {
        $timestamp = $elapsed.ToString("hh\:mm\:ss")
    }
    else {
        $days = [int]$elapsed.TotalDays
        $hours = $elapsed.Hours
        $minutes = $elapsed.Minutes
        $timestamp = "{0}d {1}h {2}m" -f $days, $hours, $minutes
    }
    return $timestamp
}

function Invoke-Ping {
    param (
        [int]$frequency,
        [int]$duration
    )
    if (-not $PLAY_PING) { return }
    [Console]::Beep($frequency, $duration)
}

function Set-QuickEdit {
    param([switch]$DisableQuickEdit = $false)
    if ($DisableQuickEdit) {
        if ([NativeMethods]::SetQuickEdit($false)) {
            Write-Host "$(Get-ElaspsedTime): QuickEdit disabled."
        }
        else {
            Write-Host "$(Get-ElaspsedTime): Failed to disable QuickEdit."
        }
    }
    else {
        if ([NativeMethods]::SetQuickEdit($true)) {
            Write-Host "$(Get-ElaspsedTime): QuickEdit enabled."
        }
        else {
            Write-Host "$(Get-ElaspsedTime): Failed to enable QuickEdit."
        }
    }
}

Set-QuickEdit -DisableQuickEdit

$AFK_TIME = [math]::Floor($AFK_TIME)
$APPS = ($APPS -replace "\s*,\s*", ",") -split "," | Where-Object { $_ -ne "" }
$KEYS_TO_PRESS = ($KEYS_TO_PRESS -replace "\s*,\s*", ",") -split "," | Where-Object { $_ -ne "" }

# makes sure the user input is never less than 1
if ($AFK_TIME -lt 1) {
    $AFK_TIME = 1
}

function Get-ValidatedKeys {
    param (
        [string[]]$keys
    )
    
    # list of all the available in WindowsInput.InputSimulator
    $validKeys = @(
        "LBUTTON", "RBUTTON", "CANCEL", "MBUTTON", "XBUTTON1", "XBUTTON2", "BACK", "TAB", "CLEAR", "RETURN", 
        "SHIFT", "CONTROL", "MENU", "PAUSE", "CAPITAL", "HANGUL", "JUNJA", "FINAL", "HANJA", "ESCAPE", "CONVERT", 
        "NONCONVERT", "ACCEPT", "MODECHANGE", "SPACE", "PRIOR", "NEXT", "END", "HOME", "LEFT", "UP", "RIGHT", 
        "DOWN", "SELECT", "PRINT", "EXECUTE", "SNAPSHOT", "INSERT", "DELETE", "HELP", "VK_0", "VK_1", "VK_2", 
        "VK_3", "VK_4", "VK_5", "VK_6", "VK_7", "VK_8", "VK_9", "VK_A", "VK_B", "VK_C", "VK_D", "VK_E", "VK_F", 
        "VK_G", "VK_H", "VK_I", "VK_J", "VK_K", "VK_L", "VK_M", "VK_N", "VK_O", "VK_P", "VK_Q", "VK_R", "VK_S", 
        "VK_T", "VK_U", "VK_V", "VK_W", "VK_X", "VK_Y", "VK_Z", "LWIN", "RWIN", "APPS", "SLEEP", "NUMPAD0", "NUMPAD1", 
        "NUMPAD2", "NUMPAD3", "NUMPAD4", "NUMPAD5", "NUMPAD6", "NUMPAD7", "NUMPAD8", "NUMPAD9", "MULTIPLY", "ADD", 
        "SEPARATOR", "SUBTRACT", "DECIMAL", "DIVIDE", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", 
        "F11", "F12", "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20", "F21", "F22", "F23", "F24", "NUMLOCK", 
        "SCROLL", "LSHIFT", "RSHIFT", "LCONTROL", "RCONTROL", "LMENU", "RMENU", "BROWSER_BACK", "BROWSER_FORWARD", 
        "BROWSER_REFRESH", "BROWSER_STOP", "BROWSER_SEARCH", "BROWSER_FAVORITES", "BROWSER_HOME", "VOLUME_MUTE", 
        "VOLUME_DOWN", "VOLUME_UP", "MEDIA_NEXT_TRACK", "MEDIA_PREV_TRACK", "MEDIA_STOP", "MEDIA_PLAY_PAUSE", 
        "LAUNCH_MAIL", "LAUNCH_MEDIA_SELECT", "LAUNCH_APP1", "LAUNCH_APP2", "OEM_1", "OEM_PLUS", "OEM_COMMA", "OEM_MINUS", 
        "OEM_PERIOD", "OEM_2", "OEM_3", "OEM_4", "OEM_5", "OEM_6", "OEM_7", "OEM_8", "OEM_102", "PROCESSKEY", "PACKET", 
        "ATTN", "CRSEL", "EXSEL", "EREOF", "PLAY", "ZOOM", "NONAME", "PA1", "OEM_CLEAR"
    )

    $validKeysToPress = @()

    foreach ($key in $keys) {
        $key = $key.ToUpper()

        if ($validKeys -contains $key) {
            $validKeysToPress += $key
        }
        elseif ($validKeys -contains "VK_" + $key) {
            $validKeysToPress += "VK_" + $key
        }
    }

    # if no valid keys: default to "SPACE"
    if ($validKeysToPress.Count -eq 0) {
        $validKeysToPress = @("SPACE")
    }

    return $validKeysToPress
}

$validKeysToPress = Get-ValidatedKeys -keys $KEYS_TO_PRESS

Write-Host "Monitoring Apps: $($APPS -join ", ")"
Write-Host "AFK Time: $AFK_TIME minutes"
Write-Host "Keys to awaken: $($KEYS_TO_PRESS -join ", ")"
Write-Host "Sound Ping: $PLAY_PING"
Write-Host "Should Minimize: $SHOULD_MINIMIZE"

$lastCachedProcsNames = "" 
$alreadyMessaged = $false
$cycles = 0

$pressKeyInstance = New-Object PressKey -ArgumentList $false, $dllsPath

while ($true) {
    Start-Sleep -Milliseconds 100

    if (-not $APPS -or $APPS.Count -eq 0) {
        continue
    }

    $currentProcsNames = ""  
    $activeProcs = @{}
    foreach ($app in $APPS) {
        $currentProcs = [System.Diagnostics.Process]::GetProcessesByName($app)
    
        foreach ($proc in $currentProcs) {
            try {
                if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
                    $activeProcs[$app] = $activeProcs[$app] + , $proc
                    $currentProcsNames += $proc.ProcessName + ", "
                }
            }
            catch {
                Write-Host "$(Get-ElaspsedTime): Error accessing $app process: $_"
            }
            finally {
                $proc.Dispose()
            }
        }
    }

    if ($activeProcs.Count -eq 0) {
        $lastCachedProcsNames = "" 

        if (-not $alreadyMessaged) {
            Write-Host "$(Get-ElaspsedTime): No monitored apps running. Waiting..."
            $alreadyMessaged = $true
        }

        Start-Sleep -Seconds 5
        
        continue
    }
    else {
        $alreadyMessaged = $false

        if ($currentProcsNames -ne $lastCachedProcsNames) {
            Write-Host "$(Get-ElaspsedTime): Newly Monitoring List: ($($currentProcsNames.TrimEnd(", ")))"
            $lastCachedProcsNames = $currentProcsNames  
        }
    }
    
    $elapsedMinutes = [math]::Floor($stopwatch.Elapsed.TotalMinutes)
    $currentCycle = [math]::Floor($elapsedMinutes / $AFK_TIME)

    if ($currentCycle -gt $cycles) {
        $runningApps = $activeProcs.Keys
        Write-Host "$(Get-ElaspsedTime):"Waking up": $($runningApps -join ", ")"

        Invoke-Ping 1000 200
        3..1 | ForEach-Object {
            Write-Host "$(Get-ElaspsedTime): Initializing in $_..."
            Start-Sleep -Seconds 1
        }

        try {
            [NativeMethods]::BlockInput($true) | Out-Null

            foreach ($app in $activeProcs.Keys) {
                foreach ($proc in $activeProcs[$app]) {
                    try {
                        if ($proc.HasExited) { continue }

                        $hwnd = $proc.MainWindowHandle
                        if ($hwnd -eq [IntPtr]::Zero) { continue }

                        $showWindow = [NativeMethods]::ShowWindow($hwnd, 9)  # SW_RESTORE
                        
                        if (-not $showWindow) {
                            Write-Host "$(Get-ElaspsedTime): Could not show $app. Skipping."
                            continue
                        }

                        [NativeMethods]::SetForegroundWindow($hwnd) | Out-Null                       
                        
                        $timeout = 2000
                        $interval = 200
                        $elapsed = 0
                        while ($elapsed -lt $timeout) {
                            Start-Sleep -Milliseconds $interval
                            $elapsed += $interval

                            $foregroundHwnd = [NativeMethods]::GetForegroundWindow()                           
                            if ($foregroundHwnd -eq $hwnd) { break }
                            
                            $showWindow = [NativeMethods]::ShowWindow($hwnd, 9)  # SW_RESTORE
                            if (showWindow) {
                                [NativeMethods]::SetForegroundWindow($hwnd) | Out-Null
                            }
                        }

                        if ($elapsed -ge $timeout) {
                            Write-Host "$(Get-ElaspsedTime): Could not focus $app. Skipping."
                            continue
                        }

                        $pressKeyInstance.SimulateKeyPress($validKeysToPress)

                        Write-Host "$(Get-ElaspsedTime): Pressed in $app."

                        if (-not $SHOULD_MINIMIZE) { 
                            [NativeMethods]::SetWindowPos(
                                $hwnd,
                                [NativeMethods]::HWND_BOTTOM,
                                0, 0, 0, 0,
                                [NativeMethods]::SWP_NOMOVE -bor [NativeMethods]::SWP_NOSIZE -bor [NativeMethods]::SWP_NOACTIVATE
                            ) | Out-Null
                        }
                        else {
                            [NativeMethods]::ShowWindow($hwnd, 6) #SW_MINIMIZE
                        }
                        
                    }
                    catch {
                        Write-Host "$(Get-ElaspsedTime): Exception with ${app}: $_"
                    }
                }
            }
        }
        finally {
            [NativeMethods]::BlockInput($false) | Out-Null
            Invoke-Ping 600 300
            $cycles = $currentCycle
        }
    }
}
