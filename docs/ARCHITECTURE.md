# Architecture

[MacShot](https://github.com/sw33tLie/macshot) must be installed separately. The companion launches its URL actions and does not implement capture or editing.

main.swift is a small AppKit accessory app: no Dock or menu-bar item.
HoverView handles pointer entry/exit and vertical dragging. SymbolButton
draws centered symbols. AppDelegate owns the panel, preferences, menus,
countdown and MacShot handoff. make-icon.swift renders the icon; build.command
compiles, generates resources and signs the local app.

## MacShot URL actions

| Ribbon mode | Command |
|---|---|
| Area | macshot://capture |
| Full screen | macshot://capture-fullscreen |
| Scrolling | macshot://scroll-capture |
| Record area | macshot://record |
| Record screen | macshot://record-fullscreen |
| History | macshot://history |

The panel is removed 350 ms before the action. No synthetic keystrokes are used.
A temporary mouse monitor restores it after screenshot area selection.
A 100 ms window metadata poll handles Escape and scrolling/recording completion.
It tracks MacShot-owned windows: selection layer 257, scrolling HUD 258,
recording HUD NSWindow.Level.statusBar + 2. These are implementation details,
not a stable upstream contract. Grace periods avoid restoring between stages.
Future MacShot updates can require changes; do not treat this as guaranteed
recording-state detection. Reopening the app restores a stranded hidden panel.

Preferences use the retained bundle ID com.bocatechforce.edgecapture.prototype
for compatibility with the personal prototype. Position is normalized along
the main screen's visible height. Multiple-monitor selection, robust versioned
upstream state reporting, and signed/notarized distribution remain future work.

## Mode reset and focus restoration (0.18)

A one-shot timer uses the persisted areaResetSeconds preference (0, 15, 30, 60).
It is invalidated when capture begins and rearmed after panel restoration.
Reset changes only captureMode; activeMode remains the current session's mode.

The restoreFocus preference enables bounded activation attempts at 0, 150,
400, and 800 ms after panel restoration. User input, a new capture/History
action, or switching to another external app cancels remaining attempts.
The target is the last non-MacShot, non-ribbon foreground application, refreshed
immediately before capture so countdown users can switch apps.

Capture URLs use NSWorkspace.OpenConfiguration.activates = false. This avoids
activating MacShot before its own URL handler remembers the prior application.
The fallback handoff uses yieldActivation/activate on macOS 14+, and
activateIgnoringOtherApps on earlier systems. Window metadata heuristics still
skip capture overlays and large normal editor/history windows. No Accessibility
permission or explicit browser-window activation is used. Version 0.18 failed
the owner's focus test; version 0.19 requires native testing.
