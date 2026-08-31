# Combo Points

A World of Warcraft addon that shows a customizable point tracker for:

- Feral Druids in Cat Form and all Rogues — Combo Points
- Paladins — Holy Power
- Windwalker Monks — Chi
- Warlocks — Soul Shards
- Arcane Mages — Arcane Charges

## Install

Grab a release zip from [CurseForge](https://www.curseforge.com/wow/addons/combo-points) or the [Releases](../../releases) page and drop the `ComboPoints` folder into `Interface/AddOns`.

## Use

- `/cop` or `/combopoints` — open/close the live configuration panel.
- `/cop unlock` / `/cop lock` — unlock/lock the tracker for dragging.
- `/cop resetpos` — reset only the tracker position and detach it from a frame.
- `/cop reset` — reset all defaults.
- `/cop toggle`, `/cop on`, `/cop off` — enable/disable the tracker (also a checkbox in the Layout tab, default on).

Settings are stored per character. Layout, colors, style, and frame attachment are all configurable through the in-game editor, with a live preview.

## Development

`Interface/AddOns/ComboPoints` is a symlink to this repo's `ComboPoints/` directory. Edit files here, then `/reload` in WoW (or restart the client) to pick up Lua/TOC changes.

Releases are packaged and pushed to CurseForge automatically via GitHub Actions whenever a `v*` tag is pushed.
