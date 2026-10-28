# Troubleshooting

## No captures launch
Launch MacShot from Applications. Enable its macshot:// URL scheme in settings.
Grant screen recording permissions to MacShot if requested. The ribbon itself
does not need Accessibility permission for its current integration.

## Tab stays hidden
Finish/stop recording first, then reopen MacShotEdgeRibbon.app in Finder.
Reopen handling restores the tab. As a fallback, run killall MacShotEdgeRibbon
and launch the app again. This does not stop a recording owned by MacShot.

## Video not in the screenshots folder
Recording has separate MacShot settings. Choose a Recording Save folder and
When done action. Show in Finder saves/reveals output; Open editor uses
MacShot's editing workflow and may require a separate Save/Export. History
contents and ability to reopen videos depend on MacShot's installed version.
The ribbon does not index or move capture files.

## Duplicate ribbon / old name
Quit all older EdgeCapture and MacShotEdgeRibbon processes. Keep one app in
Applications and remove older Login Items entries.

## Startup or build issue
Run bash build.command from the project folder; keep LICENSE and
THIRD_PARTY_NOTICES.md beside it. Install Command Line Tools if required.
Build matches the current Mac's architecture. App is ad-hoc signed, not
notarized. Review source and your Mac's security guidance for downloaded apps.

## Report a bug
Supply macOS and MacShot versions and exact steps. Redact private information.
