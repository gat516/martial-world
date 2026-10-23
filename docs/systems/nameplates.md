# Nameplates

## Purpose
A namecard floating over every other player's head that disappears past a
distance. Your own name isn't over your head on your screen (others still see
it), and it isn't on the HUD either (user, 2026-10-22: a name row made the vitals
stack too tall on phones, and your own name tells you nothing). Room is kept above
the name for a title, for when titles come in (user, 2026-10-23).

## Design intent
- A small namecard, not bare text, but light enough that a crowd of players
  doesn't wall off the screen: the name in bold cream Merriweather on a
  translucent dark-jade ink band that thins out at both ends, ruled by a gold
  hairline above and below and closed by a small gold lozenge at each end (the
  same lozenge as the game's frames). The world shows through the band and its
  soft ends, so plates that overlap at a distance still read.
- The title, when a player has one, sits above the band in small gold italic
  Merriweather with a full dark outline, no backing of its own. Without a title
  the band alone shows and stays at the same height over the head (the list is
  bottom-aligned), so plates don't jump when a title appears.
- It shrinks with distance but never below legible. The BillboardGui's size is
  part studs and part pixels (`1.32, 108` x `0.36, 30`): close up it grows with
  the character, far away it bottoms out at the pixel part. Children are all
  scale, so the band keeps its aspect, and the text is `TextScaled` held to
  12-22px (name) and 12-16px (title) by `UITextSizeConstraint`. Previewed on PC
  at 1673x793: ~18px names at 10-15 studs, ~13px at 45 studs. On phones the
  pixel part dominates, so it's about the same size on screen as far plates on PC.
- The name is the one chosen on the character screen, surname first as in
  xianxia ("Li Wei"). Until a player has both, it falls back to their Roblox
  DisplayName (the main game has no character screen yet).
- Roblox's own humanoid name is turned off, so there's only ever one name.
- It's cut off by `BillboardGui.MaxDistance` (measured from the camera), not
  faded, at 60 studs.
- The testbed has a stand-in player beside the spawn pad ("Li Wei", title
  "Disciple of the Azure Peak") so a lone tester can see someone else's card
  (user, 2026-10-23). It's any model tagged `NameplateTarget` carrying the same
  attributes as a player.

## Key files
- `src/client/Nameplates.luau`: clones the template per character, adorns it to
  the Head, keeps it in `PlayerGui.Nameplates` (local only) and repaints on the
  attributes below; also plates models tagged `NameplateTarget`.
  `MAX_DISTANCE` and the default title colour are at its top. It skips the
  local player.
- `src/server/TestbedDummy.luau` (testbed only, started from `Main.server`): the
  stand-in player, an anchored R6 body in the ranger outfit.
  `Nameplates.nameOf(player)` gives the shown name to anything else that needs it.
- `assets/Nameplate.rbxmx` (`ReplicatedStorage.Nameplate`, mapped in both
  projects): the BillboardGui (StudsOffset 0, 2.1, 0; LightInfluence 0) with a
  bottom-aligned vertical list: `Title` (hidden by default), then `Band` (the
  ImageLabel) holding `PlayerName`. The script finds both labels with
  `FindFirstChild(name, true)`.
- `art/ui/draw_nameplate.ps1` draws `art/ui/nameplate_band.png`
  (`rbxassetid://77034028645753`, in `art/ui/assets.json`), shown with
  ScaleType Stretch (no 9-slice). It's PowerShell/System.Drawing, not
  `draw_ui.py`, because it was drawn on a Windows machine without Python.

## The title contract
A future titles system only has to set player attributes; the nameplate already
shows them:
- `Title` (string): the text above the name. `""` or nil hides the line.
- `TitleColor` (Color3, optional): its colour, e.g. a rarity colour. Gold if unset.

## Known gaps
- Untested in play with several players (shown on others, cut at 60 studs) and
  on a real phone; previewed only in Studio's Edit view on PC with stand-in rigs.
- No titles exist yet, so the title line only shows on the testbed stand-in.
  The HUD name plaque has no title line yet; a title could go on the plaque
  (under the name, smaller) or as a small line above it.
- Very long titles wrap or truncate at the minimum size rather than widening the
  card; keep titles to a few words.
- It isn't `AlwaysOnTop`, so walls and terrain between you and a player hide
  their nameplate.
- `StudsOffset` 2.1 assumes ordinary hair and hats; a tall hat may reach the band.
