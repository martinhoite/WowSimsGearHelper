# Changelog

All notable changes to this project are documented in this file.

## [1.4.0-beta.1] - 26 Jun, 2026

### Added
- Added a Colors settings section with focused previews, per-color help icons, swatches, preset dropdowns, per-color resets, and a confirmed reset-all action.
- Added customizable color roles for action button text presets, window backgrounds, row titles, shopping text, highlight glow/labels, and settings task-priority states.

### Changed
- Replaced the separate opaque-background setting with customizable window background colors.

## [1.3.2] - 21 Jun, 2026

### Added
- MoP perfect uncommon gems now compare as equivalent to matching rare gem cuts when checking socketed gems.

## [1.3.1] - 18 Jun, 2026

### Fixed
- Reforge removal tasks now appear when an imported item expects no reforge but the equipped item is currently reforged.

## [1.3.0] - 16 Jun, 2026

### Added
- Added a task priority ordering UI with drag-and-drop rows.
- Dragging task types in Settings saves a per-character priority order.
- Task priority controls which row action is offered first when a slot has multiple kinds of work. Equipping the expected item remains the first prerequisite before task ordering applies.
- Row badge task details follow the configured task order, including separate sections for enchants and tinkers.
- The flat diff task list also follows the configured task type order, with equipped slot order used as the secondary sort.
- Reforging defaults to the last priority with a tooltip reminder to upgrade first, since Blizzard can calculate reforges from stale item stats after upgrades.

## [1.2.0] - 15 Jun, 2026

### Added
- Added optional ReforgeLite Classic sync for successful manual WowSims imports.
- Added reforge diff tasks that confirm current reforges from equipped item links.
- Added Reforge row actions after sockets, enchants, and upgrades, handing reforges off to ReforgeLite instead of applying them directly.
- Added ReforgeLite-backed reforge labels such as `281 Mastery > Crit` when ReforgeLite method data is available.
- Added Reforge details to row badges and action tooltips, including ReforgeLite and manual fallback guidance.
- Added Reforge NPC window behavior settings, including default WSGH minimization and optional restore after the NPC closes.
- Added a compact header collapse/expand control for keeping WSGH out of the way during reforging.
- Added WowSims ReforgeLite export guidance while keeping `Export -> JSON` as a supported import path.
- Added manual reforge reminders as a fallback only when ReforgeLite Classic is not available.

### Changed
- Main window resizing now snaps to full row heights with consistent bottom padding.

### Fixed
- Row item tooltips now use the live equipped inventory item so item level and upgrade state match the character panel.
- Import warning tooltips now show existing gems as item-colored, socket-numbered lines.

## [1.1.0] - 13 Jun, 2026

### Added
- Added row status badges that summarize import warnings, purchases, sockets, gems, and upgrade tasks in a tooltip.
- Added Blacksmithing socket guidance that opens Blacksmithing and selects relevant socket recipe.
- Added Enchanting ring guidance that opens Enchanting and selects learned ring enchant recipes.

### Changed
- Simplified row subtitle text to a remaining-task count and moved detailed task lists into the badge tooltip.
- Character slot highlights for row actions now use the glow without the letter overlay.
- Profession recipe guidance now reports immediately when a loaded recipe list does not include the requested recipe.

### Fixed
- Starting a new row action now clears previous guidance highlights so socket and tinker targets do not overlap.
- First-pass bag and character highlight glows now wait for stable target sizing before starting.
- Shopping purchase tracking no longer treats mailbox loot as purchases and reconciles bought counts once auction wins are received.
- Shopping list sorting now handles currency entries alongside normal item entries.
- Closing the addon window now fully disables runtime listeners so entering combat later no longer prints the combat-close notice.

## [1.0.0] - 04 Jun, 2026

### Snapshot
- First full stable release of WowSims Gear Helper.
- Guided WowSims import flow with gear, socket, enchant, upgrade, and shopping guidance.
- Built-in help, bag addon highlights, and import/restoration quality-of-life options.

### Planned
- [Feature] Add profession-assisted apply flow for Enchanting and Blacksmithing sockets.
- [Feature?] ReforgeLite integration.

## [0.1.4] - 04 Jun, 2026

### Added
- Added help buttons to main and import-window that open an in-game guide of using the addon.
- Imports that include reforges can now show a compact reminder below the shopping list, with separate settings for fresh imports and restored saved imports (settings defaults to ON).
- Optional opaque backgrounds are now available for addon windows, with the help and import windows using the higher-contrast style by default to not "fight" with the other windows.

### Fixed
- Addon-owned secondary windows now close immediately on entering combat, and their runtime listeners stay disabled until the UI is shown again (previous Auction House fixes broke this behavior).
- Default Auction House shopping purchase tracking now handles plain auction-win chat messages more reliably, as much as it can with the disaster Blizzard provides at least...

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


