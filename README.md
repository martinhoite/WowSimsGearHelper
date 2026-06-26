# WowSims Gear Helper

![Alpha](https://img.shields.io/github/v/release/martinhoite/WowSimsGearHelper?filter=*-alpha.*&include_prereleases&sort=semver&label=alpha&color=blue)
![Beta](https://img.shields.io/github/v/release/martinhoite/WowSimsGearHelper?filter=*-beta.*&include_prereleases&sort=semver&label=beta&color=orange)
![Release](https://img.shields.io/github/v/release/martinhoite/WowSimsGearHelper?sort=semver&label=release&color=success)
===================

<img src="WowSimsGearHelper_icon.png" alt="WowSims Gear Helper icon" width="128">

World of Warcraft addon for Classic clients that helps you apply WowSims
exports by showing what to change and guiding you through the steps ingame.

Features
--------
- Import WowSims exports and build a gear plan.
- Highlight sockets, enchants, upgrades, and shopping needs.
- Support for extra sockets and tinkers.
- Optional ReforgeLite Classic import sync for WowSims reforges.
- Bag/character slot highlighting to guide actions.
- Live shopping list updates as items are bought / obtained from mailbox.
- Built-in quick help plus a more detailed import walkthrough.

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
2) Click Import and paste your WowSims ReforgeLite export, or the `Export -> JSON` output.
3) Use the `?` or `Help` buttons if you need a quick walkthrough.
4) Follow the guided steps for sockets, enchants, items, upgrades, and ReforgeLite-backed reforging.

Report Bugs / Request Features
------------------------------
Please use GitHub Issues and include as much context as possible.

- Bug reports: <https://github.com/martinhoite/WowSimsGearHelper/issues/new?template=bug_report.md>
- Feature requests: <https://github.com/martinhoite/WowSimsGearHelper/issues/new?template=feature_request.md>

Limitations
-----------
- At this time I only support the English client and language. If Blizzard decides to continue into Warlords of Draenor, I'll likely extend with additional locale support.
- Reforging is handled by syncing to ReforgeLite Classic when it is installed and enabled; WSGH only guides and confirms from item links.
- The addon follows the data you import and attempts to flag issues, but you should still verify the result yourself.

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
