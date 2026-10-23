# Nameplates

## Purpose
A name floating over every player's head, the local player's own included, that
disappears past a distance. Room is kept above the name for a title, for when
titles come in (user, 2026-10-23).

## Design intent
- Two lines over the head: a small gold italic title (only when the player has
  one) above the name in bold cream serif, with a dark outline so it reads
  against sky and ground. The fonts and colours are the character screen's
  (Merriweather, `Theme` Cream and GoldBright).
- The name is the one chosen on the character screen, surname first as in
  xianxia ("Li Wei"). Until a player has both, it falls back to their Roblox
  DisplayName (the main game has no character screen yet).
- Roblox's own humanoid name is turned off, so there's only ever one name.
- It's cut off by `BillboardGui.MaxDistance` (60 studs), not faded.

## Key files
- `src/client/Nameplates.luau`: clones the template per character, adorns it to
  the Head, keeps it in `PlayerGui.Nameplates` (local only) and repaints on the
  attributes below. `MAX_DISTANCE` and the default title colour are at its top.
  `Nameplates.nameOf(player)` gives the shown name to anything else that needs it.
- `assets/Nameplate.rbxmx` (`ReplicatedStorage.Nameplate`, mapped in both
  projects): the BillboardGui with a vertical list: `Title` (hidden by default),
  then `PlayerName`.

## The title contract
A future titles system only has to set player attributes; the nameplate already
shows them:
- `Title` (string): the text above the name. `""` or nil hides the line.
- `TitleColor` (Color3, optional): its colour, e.g. a rarity colour. Gold if unset.

## Known gaps
- Untested in play with several players (shown on others, cut at 60 studs).
- No titles exist yet, so the title line never shows until something sets `Title`.
- It isn't `AlwaysOnTop`, so walls and terrain between you and a player hide
  their nameplate.
