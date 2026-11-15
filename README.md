# HoverMarks Forever

Mark your target without giving up any keybinds. Built for the WoW Forever
client (interface 16001).

While your mouse is over your target frame, your chosen hotkeys apply
raid target markers to your target. Move the mouse away and those keys go
straight back to casting your spells. Your normal keybindings are never
changed.

## Using it

1. Target something.
2. Move your mouse over the target frame.
3. Press a marker hotkey.

To remove every marker at once, bind a "clear all" hotkey in the settings
window. It works anywhere, with or without a target, so pick a spare key:
whatever that key normally does is replaced.

Marking and clearing both work in combat.

## Default hotkeys

| Key | Marker   |
|-----|----------|
| 1   | Skull    |
| 2   | Cross    |
| 3   | Square   |
| 4   | Diamond  |
| 5   | Star     |
| 6   | Triangle |
| 7   | Moon     |
| 8   | Circle   |

## Settings

Type `/hmf` to open the settings window.

- Click a marker (its icon or its box), then press a key to bind it. Key
  combinations such as Shift-1 work too.
- Right click a marker to unbind it.
- The "clear all" hotkey is bound the same way, in its own section below the
  markers. It starts unbound.
- The Defaults button restores the original hotkeys and window position.

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
- The game's own rules about who can set markers in a group still apply.

## Installing by hand

Copy the `HoverMarksForever` folder into
`World of Warcraft/_forever_/Interface/AddOns`, then restart the game.

## Licence

MIT. See `LICENSE.txt`.
