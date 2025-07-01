param (
    [int]$AFK_TIME = 0,                        
    [string[]]$APPS = @(''),                    
    [string]$KEY_TO_PRESS = ''                  
)

# Convert comma-separated APPS into array
$APPS = $APPS -split ','

Write-Host "Apps: $($APPS -join ', ')"
Write-Host "AFK Time: $AFK_TIME minutes"
Write-Host "Key to Press: '$KEY_TO_PRESS'"

# Load necessary Win32 APIs
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class NativeMethods {
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
    [Console]::Beep($frequency, $duration)
}

# Launch apps if not running
$processes = @()
foreach ($app in $APPS) {
    $proc = Get-Process -Name $app -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Host "Starting process: $app"
        $proc = Start-Process $app -PassThru

        # Wait for main window to become available
        $maxWait = 5
        while ($maxWait -gt 0 -and $proc.MainWindowHandle -eq 0) {
            Start-Sleep -Milliseconds 200
            $proc = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
            $maxWait -= 0.2
        }
    }
    $processes += $proc
}

Add-Type -AssemblyName System.Windows.Forms

$idleSecondsThreshold = $AFK_TIME #* 60
$timer = 0

Write-Host "Press 'Q' in this console at any time to stop the script."

while ($true) {
    Start-Sleep -Milliseconds 100
    $timer += 0.1

    # Kill switch
    if ([console]::KeyAvailable) {
        $key = [console]::ReadKey($true)
        if ($key.Key -eq 'Q') {
            Write-Host "Exit key 'Q' pressed, stopping..."
            break
        }
    }

    if ($timer -ge $idleSecondsThreshold) {
        ## play ping sound
        Invoke-Ping 1000 200
        Start-Sleep -Milliseconds 100
        Invoke-Ping 1200 200

        $originalForeground = [NativeMethods]::GetForegroundWindow()

        foreach ($proc in $processes) {
            $hwnd = $proc.MainWindowHandle
            if ($hwnd -ne 0) {
                $rect = New-Object NativeMethods+RECT
                [NativeMethods]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

                Set-WindowToFront -hwnd $hwnd
                Start-Sleep -Milliseconds 150

                # Double key press
                [System.Windows.Forms.SendKeys]::SendWait($KEY_TO_PRESS)
                Start-Sleep -Milliseconds 150
                [System.Windows.Forms.SendKeys]::SendWait($KEY_TO_PRESS)

                Write-Host "Double-pressed '$KEY_TO_PRESS' in window of process $($proc.ProcessName)."

                [NativeMethods]::MoveWindow($hwnd, $rect.Left, $rect.Top, $rect.Right - $rect.Left, $rect.Bottom - $rect.Top, $true) | Out-Null
            }
        }

        if ($originalForeground -ne [IntPtr]::Zero) {
            [NativeMethods]::SetForegroundWindow($originalForeground) | Out-Null
        }

        $timer = 0

        ## end ping sound
        Invoke-Ping 600 300
        Start-Sleep -Milliseconds 100
        Invoke-Ping 500 400
    }
}
