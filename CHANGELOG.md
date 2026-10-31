# Changelog

## 0.20 — 2026-10-31
- Add independent “Return delay to Off after idle” setting: Off, 15, 30 (default),
  or 60 seconds. Persist the choice; keep the popup and gear-menu delay in sync.
- Pause delay reset during countdown/capture/recording, then restart its interval
  when the session ends or is cancelled. Defer while the gear menu or drag is active.
- Retain the 0.19 focus fix confirmed by the owner on their Mac. The new delay
  reset requires Mac testing.

## 0.19 — 2026-10-31
- Launch capture URLs without activating MacShot first, preserving the prior app.
- Track the last external foreground app; refresh it after any capture countdown.
- Use cooperative activation on macOS 14+, with bounded focus retries that stop
  on user input or a deliberate switch to another app.
- Version 0.18 focus restoration failed in owner testing; the owner confirmed
  0.19 restores focus correctly on their Mac on 2026-10-31.

## 0.18 — 2026-10-31
- Add configurable return to Area after 15, 30 (default), or 60 idle seconds, or Off.
- Pause reset while capturing/recording; restart the interval after completion/cancel.
- Add optional previous-app focus restoration after screenshots (enabled by default).
- Keep editor/history and recording controls alone; focus behavior needs Mac testing.

## 0.17 — 2026-10-28
- Prepare a standalone repository with documentation, third-party notices,
  contribution guidance and a custom free-use/no-sale source-available license.
- Add BocaTechForce About dialog and bundle license notices in the application.
- Add --no-launch build option; retain saved preference identity.

## 0.16 — 2026-10-16
- Rename app to MacShotEdgeRibbon with a generated blue app icon.
- Includes history, screenshot modes, area/screen recording, capture delay,
  saved vertical positioning, auto-hide, and compact controls developed in
  the earlier 0.1–0.15 personal prototypes.
