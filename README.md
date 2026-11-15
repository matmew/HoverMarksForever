# HoverMarks Forever

<!-- This description must stay word-for-word identical to the CurseForge
     project description. Change both together. -->

With HoverMarks Forever you can mark targets quickly without interrupting your damage, tanking or healing rotation. It uses the very same keys you normally press for your spells: when your mouse is over a target frame, they mark your target instead. Use it during a spell cast for zero downtime.

* Supports all eight raid target markers
* Keeps your standard keybindings intact
* Lets you customise every marker hotkey and set a keybind to clear all markers
* Marks mid-cast, so your rotation never stops
* Perfect for proactive tab-targetters looking to maximise throughput

By default, keys 1–8 apply raid markers while your mouse is over a target frame. Marking isn't a spell and doesn't trigger the global cooldown, so it never delays your next cast. Move your mouse away, and those keys work normally again.

Use /hmf to open the settings window and rebind marker keys. You can also bind an optional hotkey that clears all markers at once from anywhere; it takes over the key you give it, so pick a spare one. Works in combat, with the Blizzard target frame and popular unit-frame addons.

<!-- End of the shared description. Everything below is extra reference. -->

Built for the WoW Forever client (interface 16001).

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

## Download

Latest version, always at the same link:
https://github.com/matmew/HoverMarksForever/releases/latest/download/HoverMarksForever.zip

## Installing by hand

Unzip the download and copy the `HoverMarksForever` folder into
`World of Warcraft/_forever_/Interface/AddOns`, then restart the game.

## Licence

MIT. See `LICENSE.txt`.
