# HoverMarks Forever

<!-- This description must stay word-for-word identical to the CurseForge
     project description. Change both together. -->

With HoverMarks Forever you can quickly mark targets without interrupting your damage, tanking or healing rotation. A lightweight addon, HMF uses the very same hotkeys you normally press for your spells: when your mouse is over a target frame, they mark your target instead. Use it during a spell cast for zero downtime.

* Assists in marking mid-cast, so your rotation never stops
* Perfect for proactive tab-targetters looking to maximise throughput
* Lets you customise every target mark and set a dedicated keybind to clear all marks
* Keeps your standard keybindings intact without the need for macros

By default, hotkeys 1–8 apply raid marks while your mouse is over a target frame. Marking isn't a spell and doesn't trigger the global cooldown, so it never delays your next cast. Move your mouse away, and those hotkeys work normally again.

Use /hmf to open the settings window and rebind mark hotkeys. You can also bind an optional hotkey that clears all marks at once from anywhere; it takes over the hotkey you give it, so pick something that's not already in use.

Compatible with not only the Blizzard target frames but any other target frames aswell, third-party or otherwise.

Open source on GitHub: https://github.com/matmew/HoverMarksForever/releases/

<!-- End of the shared description. Everything below is extra reference. -->

Built for the WoW Forever client (interface 16001).

## Using it

1. Target something.
2. Move your mouse over the target frame.
3. Press a mark hotkey.

To remove every mark at once, bind a "clear all" hotkey in the settings
window. It works anywhere, with or without a target, so pick a spare key:
whatever that key normally does is replaced.

Marking and clearing both work in combat.

## Default hotkeys

| Key | Mark   |
|-----|----------|
| 1   | Skull    |
| 2   | Cross    |
| 3   | Square   |
| 4   | Diamond  |
| 5   | Star     |
| 6   | Triangle |
| 7   | Moon     |
| 8   | Circle   |

## Minimap button

- Left click turns the addon on or off. Chat confirms it, in green when
  enabled and red when disabled, and the button goes grey while it is off.
- Right click opens the settings window.
- Drag the button to move it round the minimap.

While the addon is off, no hotkeys are taken over at all, including the
"clear all" key.

## Settings

Type `/hmf`, or right click the minimap button, to open the settings window.

- Click a mark (its icon or its box), then press a key to bind it. Key
  combinations such as Shift-1 work too.
- Right click a mark to unbind it.
- Tick "Press again to clear" to make a second press of a mark's hotkey clear
  that mark. The game hides a target's mark from addons, so this clears marks
  applied with these hotkeys; a mark applied any other way takes two presses.
  Hold Shift with a mark's hotkey to clear just the target's mark, or Ctrl to
  clear every mark. All of these only work while your mouse is over a target
  frame.
- The "clear all" hotkey is bound the same way, in its own section below the
  marks. It starts unbound.
- The Defaults button restores the original hotkeys and window position, turns
  the addon back on, and returns the minimap button to its starting place.

Settings are saved account-wide. Changes made during combat apply when combat
ends.

## Custom unit frames

The addon attaches to the Blizzard target frame and, if you use a unit-frame
addon, to its target frame as well. These are recognised automatically:
PitBull 4, Shadowed Unit Frames, ElvUI, Luna Unit Frames, Z-Perl, Perl
Classic, Unhalted Unit Frames, GW2 UI, Tukui and standard oUF layouts.

If yours is not picked up:

- Hover your target frame and type `/hmf frame`, or
- type `/hmf frame <name>` with the frame's name.

`/hmf frames` lists the frames it is attached to, and `/hmf frame clear`
forgets a custom one.

## Limits

- Works over target frames only, not nameplates, party frames or the
  target-of-target frame.
- Enemy players cannot be marked. That is the game's rule, not the addon's:
  friendly players and NPCs (friendly or hostile) mark normally.
- Hotkeys are keyboard only; mouse buttons cannot be bound.
- The game's own rules about who can set marks in a group still apply.

## Download

Latest version, always at the same link:
https://github.com/matmew/HoverMarksForever/releases/latest/download/HoverMarksForever.zip

## Installing by hand

Unzip the download and copy the `HoverMarksForever` folder into
`World of Warcraft/_forever_/Interface/AddOns`, then restart the game.

## Licence

MIT. See `LICENSE.txt`.
