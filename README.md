WowSims Gear Helper
![Version](https://img.shields.io/badge/version-0.1.0-blue)
===================

<img src="WowSimsGearHelper_icon.png" alt="WowSims Gear Helper icon" width="128">

World of Warcraft addon for Classic clients that helps you apply WowSims
exports by showing what to change and guiding you through the steps ingame.

Features
--------
- Import WowSims exports and build a gear plan.
- Highlight sockets, enchants, upgrades, and shopping needs.
- Support for extra sockets and tinkers.
- Bag/character slot highlighting to guide actions.
- Live shopping list updates as items are bought / obtained from mailbox.

Supported Bag Addons
--------------------
- ElvUI Bags
- ArkInventory
- Baganator (single + category views)
- Bagnon
- BetterBags

If your bag addon is not listed, open a feature request.

Installation
------------
### For testers (recommended)
1) Install via CurseForge client.
2) Search for `WowSims Gear Helper` and install.

### Manual zip install
1) Download the latest release zip from GitHub Releases.
2) Extract so the folder layout is:
   `World of Warcraft/_classic_/Interface/AddOns/WowSimsGearHelper/`
3) Launch the game and enable the addon.

Usage
-----
1) Open the addon with `/wsgh`.
2) Click Import and paste your WowSims export JSON.
3) Follow the guided steps for sockets, enchants, and items.

Report Bugs / Request Features
------------------------------
Please use GitHub Issues and include as much context as possible.

- Bug reports: <https://github.com/martinhoite/WowSimsGearHelper/issues/new?template=bug_report.md>
- Feature requests: <https://github.com/martinhoite/WowSimsGearHelper/issues/new?template=feature_request.md>

Limitations
-----------
- Reforging is not handled. Use ReforgeLite: <https://www.curseforge.com/wow/addons/reforgelite>, an integration is planned to work with ReforgeLite from WSGH directly.

Attribution
-----------
WowSims Gear Helper is built to work with WowSims exports, huge thanks to the WowSims team and contributors.
See the WowSims projects: <https://github.com/wowsims>
This addon primarily focuses on the MoP version at this time, live here: <https://www.wowsims.com/mop>

Development Notes
-----------------
- The addon targets Classic clients.
- Integration points for bag addons live in `Integrations/BagAdapters.lua`.

License
-------
See [LICENSE](LICENSE).
