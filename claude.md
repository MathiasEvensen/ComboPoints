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

`Interface/AddOns/ComboPoints` is a symlink to this project's `ComboPoints/` directory. Edit files here, then use `/reload` in WoW (or restart client) for Lua/TOC changes. WoW does not hot-reload changed Lua files while running; live panel settings do apply immediately.

## Project layout

```text
ComboPoints/
  ComboPoints.toc  # Midnight interface metadata and saved variable declaration
  ComboPoints.lua  # tracker, settings UI, slash commands
```

Uses current namespaced APIs where available: `C_SpecializationInfo`, `C_UI`, and `Enum.PowerType`. It avoids protected action-bar manipulation and creates only addon-owned UI frames.
