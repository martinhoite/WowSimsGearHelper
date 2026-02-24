# Changelog

All notable changes to this project are documented in this file.

## [0.1.0] - 22 Feb, 2026

### Added
- Initial release preparation for distribution and tester onboarding.
- Tag-based GitHub Actions workflow that builds and publishes versioned zip artifacts.

### Changed
- Updated project version metadata to `0.1.0` for initial beta release.
- Expanded README with distribution instructions.

## [0.0.4] - 22 Feb, 2026

### Fixed
- Socket guidance now resolves the active socket target more reliably by using the socket UI item title when slot/link fields are unavailable.
- Socket highlights now retarget correctly when manually switching items in the socket UI (for items that still have pending socket tasks).
- Socket highlights now clear when the socket UI is closed, preventing stale bag/socket indicators.
- Socket indicator labels (`E`, `S`, and socket indices) now render consistently after recent highlight changes.
- JP commendation guidance highlight is now cleared when other task flows (socket/enchant/socket-hint actions) are started, reducing conflicting overlays.

### Changed
- Shopping list search icon sizing is now controlled separately from button sizing, so the icon no longer overflows the button.
- Added `SocketDiagnostics()` to the debug command list to simplify in-game socket-state troubleshooting.
