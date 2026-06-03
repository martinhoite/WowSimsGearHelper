# Changelog

All notable changes to this project are documented in this file.

## [0.1.3] - 03 Jun, 2026

### Added
- New highlight style options now include Blizzard-style glow plus light and strong autocast shine variants.

### Fixed
- Settings now open correctly from the main addon window on the current client.
- Guidance no longer tries to reopen protected UIs from automatic inventory updates, avoiding post-patch blocked-action errors.
- ArkInventory bag highlights now resolve visible item frames more reliably after recent client changes.

### Changed
- Bag and character highlight glows now use a bundled standalone glow library so the addon no longer depends on another addon providing the effect.
- Blizzard-style glow coloring was adjusted to better match the familiar in-game yellow/gold alert look.

## [0.1.2-beta.3] - 07 May, 2026

### Changed
- Release notes publishing is now split by destination: GitHub release notes stay tag-specific, while CurseForge notes include the full `0.1.*` line for better in-client context.

## [0.1.2-beta.2] - 07 May, 2026

### Changed
- Tagged GitHub releases now include the matching changelog section in the release body, so release notes are always populated from project notes.

## [0.1.2-beta.1] - 07 May, 2026

### Added
- WowSims imports now support `apiVersion` 3 while keeping compatibility with `apiVersion` 2.
- Import warnings now include upgrade ambiguity checks for upgradeable items when upgrade data is missing or imported below max.

### Changed
- WowSims import compatibility handling is now consolidated under the shared importer entry point.
- Upgrade warning rows now show a clearer, low-priority "intentional?" message when applicable.

### Fixed
- Belt buckle detection now relies on tooltip `Prismatic Socket` data (with safe fallbacks), reducing false "buy buckle" prompts after applying a buckle.
- Tinker guidance no longer highlights the static Tinker's Kit bag item; slot/recipe guidance remains.
- Socket/import warning presentation around missing extra sockets was tightened for clearer row feedback.

## [0.1.2-alpha.2] - 25 Mar, 2026

### Fixed
- Equipped socket counting no longer double-counts filled sockets on some MoP Classic items, which previously caused false import-completeness warnings on otherwise-correct rows.
- Socket guidance now highlights the correct weapon when dual-wielding identical items, including off-hand socketing flows.

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


