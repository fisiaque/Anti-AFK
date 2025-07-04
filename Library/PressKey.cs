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