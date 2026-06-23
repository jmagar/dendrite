# agent-os Recipes

Common Windows-MCP task patterns. In examples below, bare tool names (`App`,
`PowerShell`, ...) mean the matching namespaced MCP tool, e.g.
`mcp__plugin_agent-os_windows-mcp__App` or the legacy `mcp__windows-mcp__App`.

## Open an app and do something

```
App {"name": "Notepad"}
# wait until Notepad's title bar paints
Wait {"seconds": 1}
Type {"text": "hello from claude"}
Shortcut {"keys": "Ctrl+s"}
```

## Run PowerShell directly (preferred for headless work)

```
PowerShell {"command": "Get-Process | Where-Object {$_.CPU -gt 10} | Select-Object Name,CPU,Id -First 10 | ConvertTo-Json"}
```

You get stdout back as text. JSON-out makes the result trivial to parse. Use `PowerShell` for anything that's expressible as a command — it sidesteps every GUI hazard.

## Driving native / GPUI desktop apps

Custom desktop apps — especially ones built on **GPUI** (Zed's Rust GUI framework) and other non-standard toolkits — often don't expose a usable accessibility tree, so `Snapshot`/`Click`-by-coordinate and plain `Type` can be unreliable. Launch, focus, and input must run through Windows-MCP's **desktop-attached** PowerShell, not a plain SSH session: SSH can start the process but typically can't foreground it or deliver synthetic input to the interactive desktop.

Use a `WScript.Shell` harness for launch/focus/input:

```powershell
$ws = New-Object -ComObject WScript.Shell
$null = $ws.Run('"C:\path\to\app.exe"', 1, $false)
Start-Sleep -Seconds 2
$null = $ws.AppActivate('Window Title')
$ws.SendKeys('status{ENTER}')
```

Lessons for these apps:

- Prefer `WScript.Shell` `Run` + `AppActivate` over `Start-Process` — the latter launches but often leaves synthetic keyboard input unreliable for GPUI windows.
- Run it through Windows-MCP `PowerShell` (desktop-attached), not non-interactive SSH — the SSH path can't foreground the window.
- GPUI text inputs frequently ignore clipboard paste; literal `SendKeys('<command>{ENTER}')` is the reliable path.
- Kill and relaunch the app between captures when testing command output, so input/mode state doesn't leak from one operation into the next.

For launch-blocking and capture failures on these apps (SmartScreen/`Unblock-File`, firewall prompts, missing `cv2` screenshot fallback, the ~120s MCP-call timeout), see `references/troubleshooting.md`.

## Click by accessibility coordinates instead of vision-guessing

```
Snapshot {}                      # returns interactive elements with labels + their coordinates
Click {"x": 412, "y": 287}       # pass the coordinates Snapshot reported for the element you want
```

`Click` still takes `(x, y)` — you don't click by element name. The win is that `Snapshot` gives you each element's coordinates straight from the accessibility tree, so you copy those in instead of guessing pixels from a Screenshot. Use Snapshot whenever you need to *interact*; use Screenshot when you just need to *look*.

## Install software via winget

```
PowerShell {"command": "winget install --id Microsoft.PowerToys --silent --accept-package-agreements --accept-source-agreements"}
```

## Push and paste a long string (bypass typing)

```
Clipboard {"action": "set", "text": "<your long or symbol-heavy string>"}
Click {"x": ..., "y": ...}        # focus the field
Shortcut {"keys": "Ctrl+v"}
```

## Send a desktop notification when a long task ends

```
Notification {"title": "agent-os", "message": "winget install finished"}
```

## Persist a Windows setting

```
Registry {"action": "write", "path": "HKCU\\Software\\YourApp", "name": "Setting", "type": "REG_SZ", "value": "x"}
```
