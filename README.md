# Combo Points

[![Release](https://github.com/MathiasEvensen/ComboPoints/actions/workflows/release.yml/badge.svg)](https://github.com/MathiasEvensen/ComboPoints/actions/workflows/release.yml)

A World of Warcraft addon that shows a customizable point tracker for:

- Feral Druids in Cat Form (optionally any druid spec in Cat Form) and all Rogues - Combo Points
- Paladins - Holy Power
- Windwalker Monks - Chi
- Warlocks - Soul Shards
- Arcane Mages - Arcane Charges

## Install

Grab a release zip from [CurseForge](https://www.curseforge.com/wow/addons/combo-points) or the [Releases](../../releases) page. The zip contains a `ComboPoints` folder - drop it into `Interface/AddOns`.

## Use

- `/cop` or `/combopoints` - open/close the live configuration panel.
- `/cop unlock` / `/cop lock` - unlock/lock the tracker for dragging.
- `/cop resetpos` - reset only the tracker position and detach it from a frame.
- `/cop resetconfigpos` - reset only the settings window's position and size.
- `/cop reset` - reset all defaults (asks for confirmation, then reloads the UI).
- `/cop toggle`, `/cop on`, `/cop off` - enable/disable the tracker (also a checkbox in the Layout tab, default on).

Settings are stored per character. Layout, colors, style, and frame attachment are all configurable through the in-game editor, with a live preview. The **Profiles** tab copies settings from another character, and exports or imports a profile as text.

