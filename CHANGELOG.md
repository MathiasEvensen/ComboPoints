# Changelog

## 1.2.1

- Fix lua error on setfont check

## 1.2.0

- Add an optional point counter in the Style tab: a number over the bar showing how many points are active, capped at the spec's maximum.
  - Counter format switches between the current count alone and current/max (`2 / 5`).
  - Counter has its own color, font size, and font: the font dropdown scrolls, previews each row in its own font, and covers the fonts this client ships plus any font another addon registered.
  - Optional **Hide counter at 0** (off by default) hides the counter while no points are active.
  - Counter is centred on the bar and follows it; X/Y offsets adjust it relative to that centre.
- The Profiles tab's source-character dropdown now uses the same scrolling list, and its copy button lines up with it.
- Settings window is taller to fit the counter options.

## 1.1.1

- Add profile export/import as pasteable text in the Profiles tab.
- Fixed settings window keyboard input blocking key inputs while open.
- Layout/Style sliders now also take a typed number, not just drag.
- Fixed round shape border: was invisible, then various follow-up shape/darkening fixes; now a true circular outline.
- Settings window position is now remembered per character; `/cop resetconfigpos` resets it if stuck off-screen.

## 1.1.0

- Split `ComboPoints.lua` (1071 lines) into 7 files by responsibility (Core, CharacterState, Tracker, Widgets, ConfigPanel, SettingsCategory, Bindings). No functional changes.
- Fixed round shape: background and border stayed square behind the round dot when both were enabled.

## 1.0.3

- Add option/toggle to disable combo points under Layout.
- Initial CurseForge release from Github.
