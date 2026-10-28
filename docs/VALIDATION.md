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
