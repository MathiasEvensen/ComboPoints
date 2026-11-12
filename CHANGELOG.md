# Changelog

## 2.0.1

- Fix the preview showing no counter numbers after logging in, until a setting was changed.
- Fix the counter font dropdown showing the font's file name instead of its name after logging in, until the font was picked again.

## 2.0.0

- Add a **Strata** control to the Layout tab: `-` and `+` move the tracker down or up through the UI layers (Background, Low, Medium, High, Dialog) when it ends up behind or in front of other frames. Default is Medium, as before.
- Every slider has `-` and `+` buttons that change the value 1 step at a time (in the Attach tab they move the tracker 1 unit), and the number boxes no longer sit on top of their sliders.
- **Border thickness** now counts screen pixels, so every step of the slider adds exactly one pixel instead of jumping unevenly.
- Fix borders getting thicker and thinner as the tracker is moved: point size, spacing, border thickness, and position are now rounded to whole screen pixels, and the tracker's edges are aligned to the pixel grid.
- Fix **Only show in combat** not showing the tracker until the first resource change after combat started.
- Fix the tracker staying in the wrong place when the frame it is attached to is created after login (for example by another addon); it now re-attaches once that frame exists, also when the frame only appears some time after login.
- Fix a thick border covering the whole point on the tracker while the preview looked fine; both now cap the border at a third of the point's smaller side.
- Fix the point count not updating when a talent changes the maximum (for example Deeper Stratagem) until the next resource change.
- Fix the Layout tab's unlock button showing the wrong state after `/cop unlock` or `/cop lock`.
- Profiles are now exported as JSON. Import reads JSON and still accepts strings exported by earlier versions.
- Importing a profile string now validates every setting, so a damaged or hand-edited string can no longer break the addon at login.
- The frame picker no longer accepts the tracker itself or the settings window's own controls, and an attachment WoW refuses falls back to the default position instead of raising an error.
- Every reset now asks for confirmation: Reset all defaults, both Reset position buttons, `/cop reset`, `/cop resetpos`, and `/cop resetconfigpos`. So do Copy selected profile and Import.
- Fix negative X/Y offsets in the Attach tab ending up 1 lower than the number typed.
- The Colors tab and the preview now follow the character's real point count as the game reports it: 4 for Arcane Mages, 6 or 7 for rogues with Deeper Stratagem / Secret Stratagem. Points 6 and 7 get their own colors in Individual mode, default green.
- The Attach tab's offset boxes accept any on-screen value and update after you drag the tracker.
- While unlocked, the tracker only catches the mouse over its visible points.
- `Esc` closes the settings window, and Combo Points is listed in the minimap addon menu. `Esc` first closes an open dropdown list. `Esc` keeps its normal job, and the window stays open, in combat, while the game's Settings window, the game menu, a popup, or the color picker is open, and while a spell is being cast or targeted.
- A tracker position that leaves no point on screen (for example from an imported profile, or while the frame it is attached to does not exist) is shown at the default position instead of being invisible.
- Fix an error when hovering a protected frame, such as some nameplates, while picking a frame in the Attach tab.
- Resetting the position now also updates the Attach tab's "Attached to" text and the unlock button, whichever way the reset was started.
- Lower CPU use: the tracker now updates only when its own resource changes, and fonts already found are cached.
- Replace the deprecated dropdown template with the addon's own dropdown button.

## 1.2.4

- Fix the settings window growing on the first click of its resize grip, before you drag.
- Resizing the settings window no longer redraws the preview on every frame of the drag.
- The settings window's controls now stretch with its width instead of leaving empty space when you resize it.
- The settings window's size is saved per character with its position, the window stays on screen, and `/cop resetconfigpos` resets both.

## 1.2.3

- Add **Show in Cat Form for all specs** to the Layout tab (druids only, off by default): shows the combo point tracker in Cat Form on every druid spec, not only Feral. It applies while **Only show usable specs** is on; with that off, the tracker already shows in every spec and form.

## 1.2.2

- Update for patch 12.1.5 (interface 120105).
- Fix Lua error when clicking the settings window's resize grip.
- Frame picking in the Attach tab can no longer be started in combat, and entering combat cancels it, avoiding blocked-action errors.
- Closing the settings window now cancels frame picking instead of leaving the highlight on screen.
- Fix keyboard input staying blocked after pressing Enter with no frame under the cursor while picking.

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
