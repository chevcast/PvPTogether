# PvPTogether

PvPTogether is a focused quality-of-life addon for Blizzard nameplates in player-heavy content.

It lets you keep Blizzard's native nameplate system, but apply style and border visual overrides separately for key player unit types.

## What It Does

- Adds per-unit-type Blizzard nameplate style overrides for:
- Party Members
- Friendly Players (non-group)
- Enemy Players
- Adds an `Inherit (Global)` option to each style dropdown so you can disable a specific override and fall back to Blizzard's global nameplate style.
- Keeps NPC nameplates on Blizzard global behavior (no NPC style override).
- Adds optional per-unit-type border visual overrides for the same three player categories.
- Border visuals include both:
- Tint
- Soft glow
- Uses per-unit-type default border colors:
- Party Members: bright green
- Friendly Players: cyan
- Enemy Players: bright red
- Includes reset buttons next to color swatches that appear only when the chosen color differs from default.

## Why Use It

- Keep Blizzard nameplates while still getting clearer PvP-oriented visual separation.
- Make group, friendly, and enemy player plates easier to distinguish at a glance.
- Tune visuals per category without replacing your whole nameplate system.

## Options

Path: `Options -> AddOns -> PvPTogether`

You can configure:

- Style per player unit type
- Per-category inherit-from-global behavior
- Border override enable/disable per player unit type
- Border color per player unit type
- One-click reset-to-default for each border color

## Slash Commands

- `/pt` - Open PvPTogether options
- `/pt on` - Enable PvPTogether runtime behavior
- `/pt off` - Disable PvPTogether runtime behavior
- `/pt toggle` - Toggle PvPTogether runtime behavior
- `/pvptogether` - Alias for `/pt`

## Saved Settings

All settings are saved per character in:

- `PvPTogetherDBChar`

## Compatibility Notes

- Retail WoW addon
- Built for Blizzard default nameplates
- Uses secure hook patterns and combat-aware deferred refreshes to reduce taint risk

## Feedback

If you report an issue, include:

- game version
- PvPTogether version
- exact steps to reproduce
- what unit type was affected (party/friendly/enemy)
- expected vs actual behavior
