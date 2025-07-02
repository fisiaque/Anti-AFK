param (
    [float]$AFK_TIME = 0,                        
    [string[]]$APPS = @(''),                    
    [string]$KEY_TO_PRESS = '',   
    [bool]$PLAY_PING = $false              
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$NativeMethodsSnippet = @"
using System;
using System.Runtime.InteropServices;

public class NativeMethods {
    public struct Rect {
       public int Left { get; set; }
       public int Top { get; set; }
       public int Right { get; set; }
       public int Bottom { get; set; }
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, ref Rect rectangle);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
    public const UInt32 SWP_NOSIZE = 0x0001;
    public const UInt32 SWP_NOMOVE = 0x0002;
    public const UInt32 SWP_NOACTIVATE = 0x0010;

    const uint ENABLE_QUICK_EDIT = 0x0040;
    const int STD_INPUT_HANDLE = -10;

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll")]
    static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll")]
    static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    public static bool SetQuickEdit(bool SetEnabled)
    {
        IntPtr consoleHandle = GetStdHandle(STD_INPUT_HANDLE);
        uint consoleMode;
        if (!GetConsoleMode(consoleHandle, out consoleMode)) { return false; }
        if (SetEnabled) {
            consoleMode |= ENABLE_QUICK_EDIT;
        } else {
            consoleMode &= ~ENABLE_QUICK_EDIT;
        }
        if (!SetConsoleMode(consoleHandle, consoleMode)) { return false; }
        return true;
    }
}
"@
Add-Type -TypeDefinition $NativeMethodsSnippet -Language CSharp
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

$afkTimeInMinutes = [math]::Round($AFK_TIME / 60, 2)
$APPS = ($APPS -replace '\s*,\s*', ',') -split ',' | Where-Object { $_ -ne '' }

Write-Host "Monitoring Apps: $($APPS -join ', ')"
Write-Host "AFK Time: $afkTimeInMinutes minutes"
Write-Host "Key to Press: '$KEY_TO_PRESS'"
Write-Host "Sound Ping: $PLAY_PING"

$timer = 0
$timeout = 2000
$interval = 200
$elapsed = 0
$lastCachedProcsNames = '' 
$alreadyMessaged = $false

while ($true) {
    Start-Sleep -Milliseconds 100
    $timer += 0.1

    if (-not $APPS -or $APPS.Count -eq 0) {
        continue
    }

    $currentProcsNames = ''  
    $activeProcs = @{}
    foreach ($app in $APPS) {
        $currentProcs = [System.Diagnostics.Process]::GetProcessesByName($app)
    
        foreach ($proc in $currentProcs) {
            if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
                $activeProcs[$app] = $activeProcs[$app] + , $proc
                $currentProcsNames += $proc.ProcessName + ", "
            }
        }
    }

    if ($activeProcs.Count -eq 0) {
        $lastCachedProcsNames = '' 

        if (-not $alreadyMessaged) {
            Write-Host "$(Get-ElaspsedTime): No monitored apps running. Waiting..."
            $alreadyMessaged = $true
        }
       
        $timer = 0
        continue
    }
    else {
        $alreadyMessaged = $false

        if ($currentProcsNames -ne $lastCachedProcsNames) {
            Write-Host "$(Get-ElaspsedTime): Newly Monitoring List: ($($currentProcsNames.TrimEnd(', ')))"
            $lastCachedProcsNames = $currentProcsNames  
        }
    }

    if ($timer -ge $AFK_TIME) {
        $elapsed = 0

        $runningApps = $activeProcs.Keys
        Write-Host "$(Get-ElaspsedTime): 'Waking up': $($runningApps -join ', ')"

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

                        [NativeMethods]::SetForegroundWindow($hwnd) | Out-Null
                        $elapsed = 0

                        while ($elapsed -lt $timeout) {
                            Start-Sleep -Milliseconds $interval
                            $elapsed += $interval

                            $foregroundHwnd = [NativeMethods]::GetForegroundWindow()
                            if ($foregroundHwnd -eq $hwnd) { break }
                        }

                        if ($elapsed -ge $timeout) {
                            Write-Host "$(Get-ElaspsedTime): Could not focus $app. Skipping."
                            continue
                        }

                        [System.Windows.Forms.SendKeys]::SendWait($KEY_TO_PRESS)
                        Start-Sleep -Milliseconds 50
                        [System.Windows.Forms.SendKeys]::SendWait($KEY_TO_PRESS)

                        Write-Host "$(Get-ElaspsedTime): Pressed '$KEY_TO_PRESS' in $app."

                        [NativeMethods]::SetWindowPos(
                            $hwnd,
                            [NativeMethods]::HWND_BOTTOM,
                            0, 0, 0, 0,
                            [NativeMethods]::SWP_NOMOVE -bor [NativeMethods]::SWP_NOSIZE -bor [NativeMethods]::SWP_NOACTIVATE
                        ) | Out-Null
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
            $timer = 0
        }
    }
}
