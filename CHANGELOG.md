# Changelog

## 1.2.2

- New: hold Shift with a mark's hotkey to clear just your target's mark. It works
  on the first press every time, whatever applied the mark, including on yourself.
  Ctrl plus a mark's hotkey still clears every mark.
- "Press again to clear" now works reliably on marks you applied with the hotkeys,
  including in combat. The game hides a target's mark from addons, so a mark
  applied any other way takes two presses; the checkbox tooltip now says so.

## 1.2.1

- HoverMarks Forever now appears in the game's addon menu, the list opened from the
  minimap's addon button. Left click turns the addon on or off, and right click
  opens the settings window.
- New "Press again to clear" checkbox in the settings window. With it on,
  pressing a mark's hotkey again clears that mark. Hold Ctrl with a mark's
  hotkey to clear every mark.
- Clearing every mark no longer fills chat with "sets ... on ..." lines.
- "Marker" is now "mark" throughout.

## 1.2

- New minimap button. Left click turns the addon on or off, right click opens
  the settings window, and dragging moves it round the minimap.
- Turning the addon off releases every hotkey, including the clear-all key.
  Chat confirms the change in green (enabled) or red (disabled).
- New addon icon.

## 1.1

- New "clear all" hotkey: one press removes every mark, from anywhere, with
  no target or hovering needed. It starts unbound and takes over the key you
  give it. This replaces the hold-a-modifier clear from 1.0.
- Works with the target frames of common unit-frame addons as well as the
  Blizzard one. `/hmf frame` adds any other, and `/hmf frames` lists what it
  is attached to.
- Redesigned settings window: taller layout, section descriptions, rounded
  boxes, and a Defaults button.
- Clicking a mark's icon now starts binding it, the same as clicking its box.

## 1.0

Initial release.

- Hover the target frame and press a hotkey to mark your target.
- Hold a modifier to clear the mark.
- Settings window on `/hmf`: rebind or unbind each mark.
- Works in combat. Mark hotkeys never change your normal keybindings.
