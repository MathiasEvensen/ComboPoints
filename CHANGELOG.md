# Changelog

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
