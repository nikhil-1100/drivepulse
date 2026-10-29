# Changelog

All notable changes to DrivePulse. The format follows Keep a Changelog and the
project adheres to Semantic Versioning.

## [1.0.0] — 2026-10-29

### Added

- Offline-first Flutter application for Android and iOS with native Kotlin and
  Swift storage bridges (MethodChannel `drivepulse/storage`, EventChannel
  `drivepulse/volumes`).
- Drive dashboard with radial capacity gauges, live transfer banner, quick
  actions, health panel and activity preview.
- Volume discovery: internal storage, USB/OTG volumes, SD cards, remembered
  drives, Android SAF trees and iOS security-scoped folders.
- File browser with breadcrumbs, list/grid views, recursive search, category
  filters, sorting, hidden files, multi-select and favourites.
- File operations: copy, move, rename, delete, new folder, open, share and
  details, with destination-drive picker.
- Sequential transfer queue with byte progress, pause/resume at file
  boundaries, cancel, ETA and per-job history.
- Folder backup flow to a second connected drive.
- Storage analyzer: category breakdown, junk/temp detection, SHA-256 duplicate
  groups, large files, empty folders and 180-day stale files.
- Local read/write benchmark and capacity-aware health estimate, explicitly
  labelled as not being S.M.A.R.T.
- AES-256-GCM vault with PBKDF2-HMAC-SHA256 (120,000 rounds), self-describing
  `.dpv` container, passphrase never stored.
- Filterable, day-grouped local activity history capped at 400 events.
- Light/dark/system theming, auto-hide navigation, adjustable thresholds,
  haptics, in-app alerts, privacy explainer and licences.
- Deterministic demo storage backend for web/desktop preview and hermetic tests.
- 42 unit and widget tests plus an offline-guarantee manifest test.
- Generated app icon set for Android, iOS and the web from a single script.
- Documentation: architecture, native API contract, testing matrix, README.

### Security

- Android release manifest ships without the `INTERNET` permission.
- Android backups disabled, cleartext traffic disabled.
- No analytics or third-party networking dependencies.
