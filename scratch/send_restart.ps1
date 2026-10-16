Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class ConsoleSender {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeConsole();

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AttachConsole(uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteConsoleInput(IntPtr hConsoleInput, INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsWritten);

    const int STD_INPUT_HANDLE = -10;

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUT_RECORD {
        [FieldOffset(0)]
        public ushort EventType;
        [FieldOffset(4)]
        public KEY_EVENT_RECORD KeyEvent;
    }

    [StructLayout(LayoutKind.Explicit, CharSet = CharSet.Unicode)]
    public struct KEY_EVENT_RECORD {
        [FieldOffset(0)]
        public bool bKeyDown;
        [FieldOffset(4)]
        public ushort wRepeatCount;
        [FieldOffset(6)]
        public ushort wVirtualKeyCode;
        [FieldOffset(8)]
        public ushort wVirtualScanCode;
        [FieldOffset(10)]
        public char UnicodeChar;
        [FieldOffset(12)]
        public uint dwControlKeyState;
    }

    public static bool SendChar(uint pid, char c) {
        FreeConsole();
        if (!AttachConsole(pid)) {
            Console.WriteLine("AttachConsole failed: " + Marshal.GetLastWin32Error());
            return false;
        }

        IntPtr handle = GetStdHandle(STD_INPUT_HANDLE);
        if (handle == IntPtr.Zero || handle == (IntPtr)(-1)) {
            Console.WriteLine("GetStdHandle failed");
            FreeConsole();
            return false;
        }

        INPUT_RECORD[] records = new INPUT_RECORD[2];
        
        // Key down
        records[0].EventType = 1; // KEY_EVENT
        records[0].KeyEvent.bKeyDown = true;
        records[0].KeyEvent.wRepeatCount = 1;
        records[0].KeyEvent.wVirtualKeyCode = (ushort)c;
        records[0].KeyEvent.UnicodeChar = c;
        records[0].KeyEvent.dwControlKeyState = 0;

        // Key up
        records[1].EventType = 1; // KEY_EVENT
        records[1].KeyEvent.bKeyDown = false;
        records[1].KeyEvent.wRepeatCount = 1;
        records[1].KeyEvent.wVirtualKeyCode = (ushort)c;
        records[1].KeyEvent.UnicodeChar = c;
        records[1].KeyEvent.dwControlKeyState = 0;

        uint written = 0;
        bool ok = WriteConsoleInput(handle, records, (uint)records.Length, out written);
        Console.WriteLine("WriteConsoleInput result: " + ok + ", written: " + written);
        FreeConsole();
        return ok;
    }
}
"@

[ConsoleSender]::SendChar(27124, 'R')
