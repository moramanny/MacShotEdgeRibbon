# Validation checklist

Preparation checks: bash syntax, bundled plist parsing, archive integrity,
required files, license identifiers, and no bundled MacShot code/binaries.
AppKit compilation and UI checks require macOS and are not verified on Linux.

On a Mac before distributing a build:

- Build default and --no-launch; confirm icon, version and bundled notices.
- Hover expand/collapse, vertical drag, size changes and persistence after restart.
- Gear menu/About website, History, Quit, and Finder reopen recovery.
- Area capture followed by a second capture without waiting for the preview.
- Escape after immediate/delayed capture; tab returns.
- All delay choices and Cancel. Open a dropdown during countdown.
- Full-screen screenshot and scrolling start/stop/cancel; ribbon excluded.
- Area/screen recording start/pause/stop/cancel, including long takes; ribbon
  stays absent from every video frame and returns after stop.
- Recording save and editor actions, with MacShot's configured output folders.
- Login Items and replacement of an installed copy.
- Display scaling, resolution change and full-screen Spaces.

Record the tested macOS version, CPU architecture, MacShot version and result.
Window-layer heuristics may break after upstream changes. Do not claim universal
MacShot-version compatibility based on one successful personal test.


## 0.18 validation
- Shell syntax checked with bash -n; ZIP integrity checked locally.
- AppKit compilation and GUI behavior remain unverified until built on a Mac.
- Verify focus restoration does not interrupt the editor, history, scrolling, or video.
- Verify idle mode reset pauses during capture and restarts after completion/cancel.

## 0.19 validation
- **Owner-confirmed, 2026-10-31:** built and ran 0.19 on their Mac; focus
  restoration after screenshot capture works. This confirms the reported fix
  on that Mac, not every capture mode or macOS version.
- Owner reports 0.18 did not restore keyboard focus.
- Inspected upstream MacShot URL handling and prior-app activation implementation.
- Changed launch to avoid activation before MacShot snapshots its previous app.
- Shell syntax and diff whitespace checks passed; AppKit compilation unavailable here.
- On Mac: capture from browser, Finder, Terminal; immediately test Command–`/typing.
- Test Escape, delay and changing apps during countdown, clicking the preview to edit,
  History, scrolling, and video. Check that focus retries yield to user interaction.

## 0.20 validation
- Shell syntax and whitespace checks passed; ZIP integrity verified.
- New delay-reset behavior awaits native Mac testing; the 0.19 focus fix was
  owner-confirmed before this change.
- Set Delay: 5s and delay reset: 15s; wait without capturing and confirm both
  delay controls show Off. Repeat with 30s and 60s.
- Set reset: Off; confirm the chosen capture delay stays set after 60 seconds.
- Start a delayed capture before timeout; confirm countdown completes normally
  and the reset interval starts again only after capture/cancel.
- Verify long scrolling/recording sessions are not interrupted by the timer.
- Set different Area/delay timeouts and verify each resets independently.
- Restart and verify reset preferences persist; retest screenshot keyboard focus.
