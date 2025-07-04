param (
    [float]$AFK_TIME = 0,
    [string[]]$APPS = @(""),
    [bool]$PLAY_PING = $false,
    [bool]$SHOULD_MINIMIZE = $false,
    [string[]]$KEYS_TO_PRESS = @("")
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# NativeMethods class definition as a string
$NativeMethodsSnippet = @"
using System;
using System.Runtime.InteropServices;
using System.Threading;

public class NativeMethods {
    public struct Rect {
       public int Left { get; set; }
       public int Top { get; set; }
       public int Right { get; set; }
       public int Bottom { get; set; }
    }

    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, ref Rect rectangle);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

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

# PressKey class definition as a string
$PressKeySnippet = @"
using System;
using System.Reflection;
using System.Threading;
using System.Linq;
using System.IO;

public class PressKey
{
    private static Assembly inputAssembly = null;  
    private bool debug;

    // initialize the debug flag
    public PressKey(bool debug = false, string scriptDirectory = "")
    {
        this.debug = debug;

        if (inputAssembly == null)
        {
            DebugWriteLine(scriptDirectory);
            string dllPath = scriptDirectory + "\\WindowsInput.dll";

            DebugWriteLine("Loading DLL from: " + dllPath);

            try
            {
                inputAssembly = Assembly.LoadFrom(dllPath);  // load DLL only once
                DebugWriteLine("DLL loaded successfully.");
            }
            catch (Exception ex)
            {
                DebugWriteLine("Failed to load DLL: " + ex.Message);
            }
        }
        else
        {
            DebugWriteLine("DLL is already loaded.");
        }
    }

    public void SimulateKeyPress(string[] validKeysToPress)
    {
        if (inputAssembly == null)
        {
            DebugWriteLine("Assembly not loaded. Cannot simulate key press.");
            return; // exit the method early if the assembly is not loaded
        }

        Type inputSimulatorType = inputAssembly.GetType("WindowsInput.InputSimulator");
        if (inputSimulatorType == null)
        {
            DebugWriteLine("Failed to find InputSimulator type.");
            return;
        }

        var inputSimulator = Activator.CreateInstance(inputSimulatorType);
        if (inputSimulator == null)
        {
            DebugWriteLine("Failed to create an instance of InputSimulator.");
            return;
        }

        var keyboardProperty = inputSimulatorType.GetProperty("Keyboard");
        if (keyboardProperty == null)
        {
            DebugWriteLine("Failed to get Keyboard property.");
            return;
        }

        var keyboard = keyboardProperty.GetValue(inputSimulator);
        if (keyboard == null)
        {
            DebugWriteLine("Failed to get Keyboard instance.");
            return;
        }

        var keyDownMethod = keyboard.GetType().GetMethod("KeyDown");
        var keyUpMethod = keyboard.GetType().GetMethod("KeyUp");
        if (keyDownMethod == null || keyUpMethod == null)
        {
            DebugWriteLine("Failed to get KeyDown or KeyUp method.");
            return;
        }

        try
        {
            var virtualKeyCodeType = inputAssembly.GetType("WindowsInput.Native.VirtualKeyCode");

            // loop through each key in the validKeysToPress array
            foreach (var key in validKeysToPress)
            {
                // default to SPACE if key is invalid
                string keyName = Enum.GetNames(virtualKeyCodeType).Contains(key) ? key : "SPACE";

                // parse the key name to get the corresponding VirtualKeyCode
                var virtualKeyCode = Enum.Parse(virtualKeyCodeType, keyName);

                keyDownMethod.Invoke(keyboard, new object[] { virtualKeyCode });
                Thread.Sleep(50); // short delay to mimic real key press
                keyUpMethod.Invoke(keyboard, new object[] { virtualKeyCode });

                DebugWriteLine("Successfully simulated " + keyName + " key press.");
            }
        }
        catch (Exception ex)
        {
            DebugWriteLine("Error during key press simulation: " + ex.Message);
        }
    }

    private void DebugWriteLine(string message)
    {
        if (debug)
        {
            Console.WriteLine(message);
        }
    }
}
"@

Add-Type -TypeDefinition $NativeMethodsSnippet -Language CSharp
Add-Type -TypeDefinition $PressKeySnippet -Language CSharp
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
$APPS = ($APPS -replace "\s*,\s*", ",") -split "," | Where-Object { $_ -ne "" }
$KEYS_TO_PRESS = ($KEYS_TO_PRESS -replace "\s*,\s*", ",") -split "," | Where-Object { $_ -ne "" }

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
Write-Host "AFK Time: $afkTimeInMinutes minutes"
Write-Host "Keys to awaken: $($KEYS_TO_PRESS -join ", ")"
Write-Host "Sound Ping: $PLAY_PING"
Write-Host "Should Minimize: $SHOULD_MINIMIZE"

$timer = 0
$timeout = 2000
$interval = 200
$lastCachedProcsNames = "" 
$alreadyMessaged = $false

while ($true) {
    Start-Sleep -Milliseconds 100
    $timer += 0.1

    if (-not $APPS -or $APPS.Count -eq 0) {
        continue
    }

    $currentProcsNames = ""  
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
        $lastCachedProcsNames = "" 

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
            Write-Host "$(Get-ElaspsedTime): Newly Monitoring List: ($($currentProcsNames.TrimEnd(", ")))"
            $lastCachedProcsNames = $currentProcsNames  
        }
    }

    if ($timer -ge $AFK_TIME) {
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
                        
                        $elapsed = 0
                        while ($elapsed -lt $timeout) {
                            Start-Sleep -Milliseconds $interval
                            $elapsed += $interval

                            $foregroundHwnd = [NativeMethods]::GetForegroundWindow()
                            $hwnd = $proc.MainWindowHandle
                           
                            if ($hwnd -eq [IntPtr]::Zero) { continue }
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
                        $pressKeyInstance = New-Object PressKey -ArgumentList $false, $PSScriptRoot
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
            $timer = 0
        }
    }
}
