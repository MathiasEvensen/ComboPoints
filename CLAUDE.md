# Combo Points

World of Warcraft **Midnight (12.0)** addon for:

- Feral Druids in Cat Form and all Rogues: Combo Points
- Paladins: Holy Power
- Windwalker Monks: Chi
- Warlocks: Soul Shards
- Arcane Mages: Arcane Charges

## Use

- `/cop` or `/combopoints` — open/close live configuration panel.
- `/cop unlock` — unlock tracker, then drag it.
- `/cop lock` — lock tracker position.
- `/cop resetpos` — reset only tracker position and detach it from a frame.
- `/cop reset` — reset all defaults.
- `/cop toggle`, `/cop on`, `/cop off` — enable/disable tracker (also a checkbox in Layout tab, default on).

Settings are stored per character. In the **Profiles** tab, select a saved character from the dropdown, then use **Copy selected profile** to duplicate its complete profile, including frame attachment and position. Selection is temporary and clears when editor closes without copying. New installs use Næpskrell's visual defaults. Settings use compact **Layout**, **Colors**, **Style**, and **Attach** tabs. A transparent live preview remains visible while editing Layout, Colors, and Style, showing full, 2/5, and empty five-point states with current shape, dimensions, spacing, colors, backgrounds, and borders. Drag the lower-right resize grip to resize the settings window. In Layout, **Only show in combat** is off by default, leaving tracker visible at all times; enable it to hide tracker outside combat. Choose **Color mode: One static color** to use one active color for all points, or **Color mode: Individual** to configure each of five active points. Default individual palette: points 1–2 red, 3 yellow, 4–5 green. Toggle per-point box backgrounds and borders independently, then choose their colors. In **Attach**, click **Pick frame**, hover any named UI frame, and press `Enter` to attach; `Esc` cancels. Choose one of nine attach points (for example `Top left` or `Center`) to align tracker and frame at that same point. A newly selected frame always starts with X/Y offsets reset to `0`; then use sliders or type exact offsets and press `Enter`. When detached to screen, normal unlock-and-drag positioning remains available. WoW **Settings → AddOns → Combo Points** also includes the `/cop` and `/combopoints` access reminder. All style changes update tracker live. Configuration is saved automatically by WoW in its account `WTF/.../SavedVariables/ComboPoints.lua` file.

## Development install

`Interface/AddOns/ComboPoints` is a symlink to this repository's root directory. Edit files here, then use `/reload` in WoW (or restart client) for Lua/TOC changes. WoW does not hot-reload changed Lua files while running; live panel settings do apply immediately.

## Project layout

```text
ComboPoints.toc     # Midnight interface metadata, saved variable declaration, and Lua load order
Core.lua            # namespace setup, defaults, addon frame, table utils
CharacterState.lua  # per-character profile persistence, class/spec/power detection
Tracker.lua         # point frames, layout, live power updates
Widgets.lua         # reusable slider/label/color-picker builders for the config UI
ConfigPanel.lua     # settings window: tabs (Layout/Colors/Style/Attach/Profiles) and live preview
SettingsCategory.lua # WoW Settings → AddOns panel entry
Bindings.lua        # slash commands and event wiring
.pkgmeta            # packager config (manual changelog, ignores CLAUDE.md)
CHANGELOG.md        # release notes, edit before tagging a release
```

The repo root is the addon root — `BigWigsMods/packager` (see `.github/workflows/release.yml`) and CurseForge's own auto-packaging both require the `.toc` at the git checkout root, which is the standard layout for single-addon WoW repos.

The Lua files share state through a single addon-scoped table: each file starts with `local ADDON_NAME, ns = ...`, since WoW's loader passes the same `(name, table)` pair to every file of an addon. Mutable state (`ns.db`, `ns.tracker`, `ns.configPanel`, `ns.pointFrames`) and cross-file functions (`ns.ApplyLayout`, `ns.UpdateTracker`, etc.) live on `ns`. Load order in `ComboPoints.toc` matters only for top-level execution (e.g. `Core.lua` must set `ns.DEFAULTS` before `CharacterState.lua` uses it); functions that read `ns.*` at call time work regardless of file order.

Uses current namespaced APIs where available: `C_SpecializationInfo`, `C_UI`, and `Enum.PowerType`. It avoids protected action-bar manipulation and creates only addon-owned UI frames.
