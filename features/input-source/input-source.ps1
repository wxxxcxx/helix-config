param (
    [string]$Action,
    [string]$LayoutID
)

$code = @"
using System;
using System.Runtime.InteropServices;
public class WinInput {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")]
    public static extern IntPtr GetKeyboardLayout(uint idThread);
    [DllImport("user32.dll")]
    public static extern IntPtr PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern IntPtr LoadKeyboardLayout(string pwszKLID, uint Flags);
    public static string GetCurrentLayout() {
        IntPtr hwnd = GetForegroundWindow();
        uint processId;
        uint threadId = GetWindowThreadProcessId(hwnd, out processId);
        IntPtr hkl = GetKeyboardLayout(threadId);
        int layoutId = (int)hkl & 0xFFFF;
        return layoutId.ToString("X8");
    }
    public static void SetCurrentLayout(string layoutId) {
        IntPtr hwnd = GetForegroundWindow();
        IntPtr hkl = LoadKeyboardLayout(layoutId, 1);
        PostMessage(hwnd, 0x0050, IntPtr.Zero, hkl);
    }
}
"@

Add-Type -TypeDefinition $code -ErrorAction Stop

if ($Action -eq "get") {
    [WinInput]::GetCurrentLayout()
}
elseif ($Action -eq "set") {
    [WinInput]::SetCurrentLayout($LayoutID)
}
