param (
    [float]$AFK_TIME = 0,                        
    [string[]]$APPS = @(''),                    
    [string]$KEY_TO_PRESS = '',   
    [bool]$PLAY_PING = $false              
)

# Convert comma-separated APPS into array
$afkTimeInMinutes = [math]::Round($AFK_TIME / 60, 2)
$APPS = $APPS -split ','
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Attempting to monitor Apps: $($APPS -join ', ')."
Write-Host "AFK Time: $afkTimeInMinutes minutes."
Write-Host "Key to Press: '$KEY_TO_PRESS'."
Write-Host "Sound Ping: $PLAY_PING."

# Load necessary Win32 APIs
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class NativeMethods {
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@

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

function Set-WindowToFront {
    param ([IntPtr]$hwnd)
    [NativeMethods]::ShowWindow($hwnd, 9) | Out-Null  # SW_RESTORE
    [NativeMethods]::SetForegroundWindow($hwnd) | Out-Null
}
function Invoke-Ping {
    param (
        [int]$frequency,
        [int]$duration
    )
    if (-not $PLAY_PING) {
        return  # Exit if ping sound is disabled
    }
    
    [Console]::Beep($frequency, $duration)
}

# Check if the required parameters are provided
$processes = @()
foreach ($app in $APPS) {
    $proc = Get-Process -Name $app -ErrorAction SilentlyContinue
    if (-not $proc) {
        continue
    }
    $processes += $proc
}

if ($processes.Count -eq 0) {
    Write-Host "No matching apps from the list are currently running."
    Start-Sleep -Seconds 1
    Write-Host "Available running processes you can use in -APPS parameter:"
    Write-Host "--------------------------------------------------"
    Get-Process | Where-Object { $_.MainWindowTitle } |
    Select-Object -Property Id, ProcessName, MainWindowTitle |
    Sort-Object ProcessName |
    Format-Table -AutoSize
    Write-Host "--------------------------------------------------"
    Write-Host "Press Enter to exit..."
    [void][Console]::ReadLine()  # Wait for Enter key press
    exit  # Exit the script immediately
}

Add-Type -AssemblyName System.Windows.Forms

$timer = 0
$maxWait = 5  # seconds until we give up on bringing the window to the front

$monitoredApps = $processes.ProcessName | Sort-Object -Unique
Write-Host "$(Get-ElaspsedTime): Monitoring the following apps: $($monitoredApps -join ', ')"

while ($true) {
    Start-Sleep -Milliseconds 100
    $timer += 0.1

    if ($timer -ge $AFK_TIME) {
        ## play ping sound
        Invoke-Ping 1000 200

        # BLOCK INPUT
        [NativeMethods]::BlockInput($true) | Out-Null  

        $originalForeground = [NativeMethods]::GetForegroundWindow()

        foreach ($proc in $processes) {
            $hwnd = $proc.MainWindowHandle
            if ($hwnd -ne 0) {
                $rect = New-Object NativeMethods+RECT
                [NativeMethods]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

                Set-WindowToFront -hwnd $hwnd

                $elapsed = 0
                while ([NativeMethods]::GetForegroundWindow() -ne $hwnd -and $elapsed -lt $maxWait) {
                    Start-Sleep -Milliseconds 100
                    $elapsed += 0.1
                }

                # make sure window is actually at front
                if ([NativeMethods]::GetForegroundWindow() -eq $hwnd) {
                    [System.Windows.Forms.SendKeys]::SendWait($KEY_TO_PRESS)
                    Start-Sleep -Milliseconds 100  # Small delay to ensure key press is registered
                    [System.Windows.Forms.SendKeys]::SendWait($KEY_TO_PRESS)

                    Write-Host "$(Get-ElaspsedTime): Pressed '$KEY_TO_PRESS' in window of process $($proc.ProcessName)."
                }
                else {
                    Write-Warning "$(Get-ElaspsedTime): Timed out waiting for $($proc.ProcessName)'s window to come to front."
                }


                [NativeMethods]::MoveWindow($hwnd, $rect.Left, $rect.Top, $rect.Right - $rect.Left, $rect.Bottom - $rect.Top, $true) | Out-Null
            }
        }

        if ($originalForeground -ne [IntPtr]::Zero) {
            [NativeMethods]::SetForegroundWindow($originalForeground) | Out-Null
        }

        $timer = 0

        ## end ping sound
        Invoke-Ping 600 300

        # UNBLOCK INPUT
        [NativeMethods]::BlockInput($false) | Out-Null  
    }
}
