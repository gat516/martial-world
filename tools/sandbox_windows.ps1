# Window layout for sandbox Studios (mw-sandbox-*.rbxl), driven by tools/sandbox.sh.
#
#   sandbox_windows.ps1 tile          tile every sandbox Studio in a grid on the second
#                                     monitor (the primary one if there's only one): at
#                                     most MAX_TILES tiles (1: the whole work area) so
#                                     agents keep a viewport big enough for a phone-size
#                                     preview; further sandboxes cascade 48 px apart;
#                                     minimised ones stay minimised and restore into
#                                     their tile
#   sandbox_windows.ps1 place <name>  wait for mw-sandbox-<name>.rbxl to open, then
#                                     tile; it opens minimised if every other sandbox
#                                     already is
#   sandbox_windows.ps1 watch         stay running: minimising or restoring one sandbox
#                                     Studio does the same to all of them. One instance
#                                     at a time; it exits once no sandbox is open.
#
# The user's own Studios (anything not named mw-sandbox-*) are never touched.
param([string]$Mode = 'tile', [string]$Name = '')

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class SandboxWindows {
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
	[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
	[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor, rcWork; public uint dwFlags; }
	[StructLayout(LayoutKind.Sequential)] public struct WINDOWPLACEMENT { public int length, flags, showCmd; public POINT ptMin, ptMax; public RECT rcNormal; }
	[StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public POINT pt; }

	delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
	delegate bool MonitorEnumProc(IntPtr m, IntPtr dc, ref RECT r, IntPtr l);
	delegate void WinEventProc(IntPtr hook, uint ev, IntPtr h, int obj, int child, uint thread, uint time);

	[DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
	[DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc f, IntPtr l);
	[DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorEnumProc f, IntPtr l);
	[DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO mi);
	[DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
	[DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
	[DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
	[DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
	[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
	[DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hgt, uint flags);
	[DllImport("user32.dll")] static extern bool SetWindowPlacement(IntPtr h, ref WINDOWPLACEMENT p);
	[DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr h, int cmd);
	[DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint min, uint max, IntPtr mod, WinEventProc f, uint pid, uint tid, uint flags);
	[DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr h, uint min, uint max);
	[DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG m);
	[DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref MSG m);
	[DllImport("user32.dll")] static extern IntPtr SetTimer(IntPtr h, IntPtr id, uint ms, IntPtr f);
	[DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);

	const int SW_SHOWNOACTIVATE = 4, SW_SHOWMINNOACTIVE = 7, SW_MINIMIZE = 6;
	const uint SWP_NOZORDER = 0x4, SWP_NOACTIVATE = 0x10;
	const uint EVENT_SYSTEM_MINIMIZESTART = 0x16, EVENT_SYSTEM_MINIMIZEEND = 0x17;
	const uint WM_TIMER = 0x113;
	// At most this many tiles. Studio's panels take about 340 px of a window's width and its
	// ribbon about 200 px of its height, so a phone-size preview (844x390 viewport) needs the
	// whole monitor: a 3x3 grid left agents 296x304, two full-width rows 1060x304
	// (2026-10-23). So each sandbox gets the full work area and they cascade.
	const int MAX_TILES = 1, CASCADE = 48;

	public class Win { public IntPtr Hwnd; public string Name; public DateTime Started; public bool Minimised; }

	public static void Init() {
		SetProcessDpiAwarenessContext(new IntPtr(-4)); // per-monitor v2: real pixels on every monitor
	}

	static string Title(IntPtr h) {
		var s = new StringBuilder(512);
		GetWindowText(h, s, s.Capacity);
		return s.ToString();
	}

	// Sandbox name from a main Studio window's title ("...mw-sandbox-<name>.rbxl - Roblox Studio"), or null.
	static string SandboxName(IntPtr h) {
		if (!IsWindowVisible(h) || GetWindow(h, 4) != IntPtr.Zero) return null; // owned windows are dock popouts
		var t = Title(h);
		if (!t.EndsWith("Roblox Studio")) return null;
		var m = System.Text.RegularExpressions.Regex.Match(t, @"mw-sandbox-([A-Za-z0-9_-]+)\.rbxl");
		return m.Success ? m.Groups[1].Value : null;
	}

	public static List<Win> Sandboxes() {
		var list = new List<Win>();
		EnumWindows((h, l) => {
			var n = SandboxName(h);
			if (n != null) {
				uint pid; GetWindowThreadProcessId(h, out pid);
				DateTime started = DateTime.MaxValue;
				try { started = Process.GetProcessById((int)pid).StartTime; } catch {}
				list.Add(new Win { Hwnd = h, Name = n, Started = started, Minimised = IsIconic(h) });
			}
			return true;
		}, IntPtr.Zero);
		return list.OrderBy(w => w.Started).ThenBy(w => w.Name).ToList();
	}

	// Work area of the first non-primary monitor, else the primary; plus the primary's (for workspace coords).
	static RECT TargetArea(out RECT primary) {
		var areas = new List<MONITORINFO>();
		EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr m, IntPtr dc, ref RECT r, IntPtr l) => {
			var mi = new MONITORINFO { cbSize = Marshal.SizeOf(typeof(MONITORINFO)) };
			if (GetMonitorInfo(m, ref mi)) areas.Add(mi);
			return true;
		}, IntPtr.Zero);
		var p = areas.FirstOrDefault(a => (a.dwFlags & 1) != 0);
		primary = p.rcWork;
		var second = areas.Where(a => (a.dwFlags & 1) == 0).ToList();
		return second.Count > 0 ? second[0].rcWork : p.rcWork;
	}

	// Gap between a window's rect and its visible frame (Windows 10/11 draw invisible resize borders).
	static RECT Border(List<Win> wins) {
		foreach (var w in wins) {
			if (w.Minimised) continue;
			RECT r, f;
			if (GetWindowRect(w.Hwnd, out r) && DwmGetWindowAttribute(w.Hwnd, 9, out f, Marshal.SizeOf(typeof(RECT))) == 0)
				return new RECT { L = f.L - r.L, T = f.T - r.T, R = r.R - f.R, B = r.B - f.B };
		}
		return new RECT { L = 7, T = 0, R = 7, B = 7 };
	}

	// minimiseNew: the named window opens minimised (its siblings all are).
	public static string Tile(string newName, bool minimiseNew) {
		var wins = Sandboxes();
		if (wins.Count == 0) return "no sandbox Studios open";
		RECT primary;
		var a = TargetArea(out primary);
		int tiles = Math.Min(wins.Count, MAX_TILES);
		int cols = 1, rows = tiles;
		int cw = (a.R - a.L) / cols, rh = (a.B - a.T) / rows;
		var b = Border(wins);
		var log = new List<string>();
		for (int i = 0; i < wins.Count; i++) {
			var w = wins[i];
			bool minimise = w.Minimised || (w.Name == newName && minimiseNew);
			int slot = i % tiles, layer = i / tiles; // past MAX_TILES, stack on the tiles in turn
			int x = a.L + (slot % cols) * cw - b.L + layer * CASCADE, y = a.T + (slot / cols) * rh - b.T + layer * CASCADE;
			int wd = cw + b.L + b.R, ht = rh + b.T + b.B;
			// Placement sets the restored rect even while minimised, so a restore lands in the tile.
			// Its coordinates are relative to the primary work area.
			var p = new WINDOWPLACEMENT { length = Marshal.SizeOf(typeof(WINDOWPLACEMENT)) };
			p.showCmd = minimise ? SW_SHOWMINNOACTIVE : SW_SHOWNOACTIVATE;
			p.rcNormal = new RECT { L = x - primary.L, T = y - primary.T, R = x + wd - primary.L, B = y + ht - primary.T };
			SetWindowPlacement(w.Hwnd, ref p);
			if (!minimise) SetWindowPos(w.Hwnd, IntPtr.Zero, x, y, wd, ht, SWP_NOZORDER | SWP_NOACTIVATE);
			log.Add(string.Format("{0}: {1}x{2} tile {3}{4}{5}", w.Name, cols, rows, slot + 1, layer > 0 ? " layer " + (layer + 1) : "", minimise ? " (minimised)" : ""));
		}
		return string.Join("\n", log);
	}

	public static string Place(string name, int timeoutSec) {
		var deadline = DateTime.Now.AddSeconds(timeoutSec);
		while (!Sandboxes().Any(w => w.Name == name)) {
			if (DateTime.Now > deadline) return "mw-sandbox-" + name + " never opened";
			Thread.Sleep(500);
		}
		var others = Sandboxes().Where(w => w.Name != name).ToList();
		bool minimise = others.Count > 0 && others.All(w => w.Minimised);
		Tile(name, minimise);
		// Studio restores its last saved geometry while it finishes loading; lay out again once it settles.
		Thread.Sleep(4000);
		others = Sandboxes().Where(w => w.Name != name).ToList();
		minimise = others.Count > 0 && others.All(w => w.Minimised);
		return Tile(name, minimise);
	}

	static WinEventProc hookProc; // kept referenced so the GC doesn't collect the callback
	static DateTime quietUntil = DateTime.MinValue;

	static void OnEvent(IntPtr hook, uint ev, IntPtr h, int obj, int child, uint thread, uint time) {
		if (obj != 0 || DateTime.Now < quietUntil || SandboxName(h) == null) return;
		bool minimise = ev == EVENT_SYSTEM_MINIMIZESTART;
		quietUntil = DateTime.Now.AddMilliseconds(800); // ignore the events our own changes fire
		foreach (var w in Sandboxes()) {
			if (w.Hwnd == h || w.Minimised == minimise) continue;
			ShowWindowAsync(w.Hwnd, minimise ? SW_MINIMIZE : SW_SHOWNOACTIVATE);
		}
	}

	public static void Watch() {
		bool created;
		using (var mutex = new Mutex(true, @"Local\mw-sandbox-window-watcher", out created)) {
			if (!created) return;
			hookProc = OnEvent;
			SetWinEventHook(EVENT_SYSTEM_MINIMIZESTART, EVENT_SYSTEM_MINIMIZEEND, IntPtr.Zero, hookProc, 0, 0, 0); // out of context
			SetTimer(IntPtr.Zero, IntPtr.Zero, 30000, IntPtr.Zero);
			int idle = 0;
			MSG m;
			while (GetMessage(out m, IntPtr.Zero, 0, 0) > 0) {
				if (m.message == WM_TIMER) {
					idle = Sandboxes().Count == 0 ? idle + 1 : 0;
					if (idle >= 2) return; // a minute with no sandbox open
					continue;
				}
				TranslateMessage(ref m);
				DispatchMessage(ref m);
			}
		}
	}
}
'@

[SandboxWindows]::Init()
switch ($Mode) {
	'tile' { [SandboxWindows]::Tile('', $false) }
	'place' { [SandboxWindows]::Place($Name, 180) }
	'watch' { [SandboxWindows]::Watch() }
	default { Write-Error "unknown mode $Mode"; exit 2 }
}
