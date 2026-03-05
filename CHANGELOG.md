# Changelog

All notable changes to this project are documented in this file.

## [0.1.2-alpha.1] - 05 Mar, 2026

### Added
- Import completeness warnings for omitted enchant/gem data, including row-level `?` indicators and a header summary chip with affected-slot context.
- Tooltip messaging for omission warnings now includes current equipped gem/enchant context when available.

### Changed
- Missing-import warning logic now treats the import as authoritative and flags omissions even when the currently equipped item already has gems/enchants.
- Socket-count detection now handles mixed empty/filled socket states more reliably.
- Profession helper logic now uses shared profession metadata/constants, including an Enchanting helper for profession-aware checks.

### Fixed
- MoP enchantability handling now avoids false "missing enchant" warnings on slots that are not enchantable in that expansion.

## [0.1.1] - 04 Mar, 2026

### Added
- Main window title and settings panel now display the current addon version for easier in-game verification.

### Fixed
- Extra-socket workflows now defer blocked gem socket tasks until the missing socket is added, instead of treating them as immediately actionable.
- Socket rows now render deferred gems as blocked/not-ready with tooltip guidance to add the socket first.
- Shopping list item resolution and need counts now include deferred gem tasks so required gems remain visible while waiting on socket creation.
- Socket-hint subtitle fallback now avoids raw `item <id>` text when item data is uncached by requesting item data and using existing hint text until names resolve.

### Changed
- Diff task output now emits explicit `ADD_SOCKET` tasks for rows missing planned sockets, improving task flow and diagnostics.

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
