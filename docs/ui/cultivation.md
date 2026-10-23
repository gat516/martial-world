# Cultivation UI: meditation, breakthrough and the roadmap marks

The seated screen, the breakthrough moments and the small cultivation marks, in the
Figma kit's style (gold rails, navy lacquer, ruby blocks, cloud scrolls). Behaviour is in
[meditation](../systems/meditation.md) and [cultivation](../systems/cultivation.md); this
part covers the look, the layout and the contracts of the ready-to-wire pieces.

**No Figma mock** for any screen here (2026-10-23): the kit's Figma calls were rationed
during this pass, so everything was composed from the cut PNGs in Studio and checked there.

## Art
Kit cuts are copied from `ui-assemble` into `art/ui/codex/cut/` (`ornament_*.png`); ids are
in `art/ui/assets.json`. Two derived pieces, made only by cropping, mirroring and
stretching kit art (`art/ui/cultivation/derive.py`):
- `window_small.png` (904x624): the small window corner, cropped before its fret knots,
  mirrored to all four corners and joined by strips of its own plain rail, over the panel
  navy (17, 24, 32). 9-slice `Rect(420, 280, 484, 344)`, `SliceScale` 0.13-0.14. Used by
  the meditation panel, the circulation result card and the root reveal card.
- `meter_disc.png`: a white disc, the foundation meter's fill (procedural, tinted in game).

Icons on the seated tiles: the kit's white glyphs where one fits (`glyph_qi` Circulate,
`glyph_insight` Technique, `glyph_quest` Method), tinted cream; the older drawn icons
(`meditation_art` in `art/ui/draw_ui.py`) for Break Through, Rise, Practice, Weapon Dao and
Back until Codex sheet B6 ([codex-sheets](codex-sheets.md)) replaces them.

## Restyled screens (`assets/Hud.rbxmx`)
| Piece | Path | Look |
|---|---|---|
| Seated tiles | `Stack.CultivatePrompt.*` | `tile_neutral` frame (Break Through: `tile_gold`, gold glyph and caption), glyph at 50 %, caption under the tile (Builder Sans Bold 12, cream, ink stroke, no pill); the seal dot (`Badge`) is a `ruby_stud` on the top-right corner |
| Calm lotus | `Stack.CalmToggle` | the HUD's round seal (`figma/hud_round_seal.png`) with `emblem_lotus`, centred on the tiles' centre line |
| Force Breakthrough | `Stack.BreakthroughButton` | `response_button_hi` sliced `Rect(200, 53, 860, 54)` at 0.374, the breakthrough glyph in its left ring, label centred between the ring and the chevron |
| Meditation panel | `MeditationPanel` | `window_small` backdrop; `close_seal` with a live "×" over the top-right ruby block; centred gold title over `divider_cloud`; rows: `crest_ring_plain` seal, `divider_diamond` rule under each row, actions on `tag_jade` (suggested) and `tag_bronze` (the rest) sliced `Rect(96, 50, 283, 51)` |
| Circulation overlay | `Circulation` | gold title; the Leave pill is `tag_crimson`; the result card is `window_small` |
| Spirit-root reveal | `RootReveal` | `window_small` card, `rays_milestone` in the element's colour behind a `crest_ring_plain` seal, a gold `fx_shockwave` halo for rare roots (`Seal.Trim`) and a `tag_gold` "RARE!" tag |

Layout (PC 1616x784 Studio view, phone at 844x390): tiles are 54 px (phone: the 50 px
floor), 22 px apart, the row centred on the stack (row mid 808.0 = stack mid 808.0);
captions sit 2 px under the tiles and end 4 px (phone 3 px) above the realm crest. The lotus
is `LOTUS_GAP` 22 px past the last tile, the row's own gap. Seated, the row now reaches
8 px higher on a phone than the old overhanging frames did, because the captions no longer
overlap the crest.

## Breakthrough title card
`StarterGui.Cultivation.Canvas.TitleCard` (`BreakthroughView`, local player only): the
kicker ("BREAKTHROUGH" or "MAJOR BREAKTHROUGH") over the kit's five-part `title_crest`
(caps, two stretching plain strips, the cloud centre) with the new realm's name live on the
plaque, `rays_milestone` slowly turning behind it and an `fx_glow` that swells and settles,
both tinted jade (minor) or gold (major). A major one holds longer (3.4 s against 2.4 s)
and adds one `fx_sparkle` glint on the crest. No full-screen flash and no darkening (the
user rejected both on the boss bar); `Hud.Flash` and `Hud.Banner` are no longer used by it.
Preview: `BreakthroughView.previewCard(major)`.

The Rewards milestone card (branch `ui-rewards`, `Rewards.show`) wasn't built when this
landed. If it ships a milestone tier, the title card can hand over to it: BreakthroughView
calls `Rewards.show({ tier = "milestone", title = stageName, ... })` instead of `titleCard`,
and this card's template goes.

## The Cultivation ScreenGui
`assets/Cultivation.rbxmx` (mapped in both projects): `Canvas` (with the `UiScale`
UIScale, fitted by `CultivationGui` through `UiScale.fit`) holds `TitleCard` and
`DeathSave`, laid out at the desktop baseline (1920x1080). On a phone every `Device`
UIScale under the canvas drops to 0.62, which keeps the smallest text at 11-12 px.
`Templates` holds the pieces other screens clone. `src/client/CultivationGui.luau`
returns the screen, a canvas piece, or a fresh template clone.

## Ready-to-wire components
Each has a `.preview()` callable from the client console in play, e.g.
`require(game.Players.LocalPlayer.PlayerScripts.Client.DeathSave).preview()`. Nothing in
the real flow calls them yet.

### Foundation solidity meter (`FoundationMeter.luau`, roadmap 1)
- `FoundationMeter.set({ solidity = 0..1, cracks = 0..3, deep = bool })`.
- A 28 px round meter on the HUD plate's bottom-right corner, the mirror of the Dash and
  Strike chips (`Stack` x 0.9006, y 0.5436), so the HUD doesn't grow. It is cloned from
  `Templates.FoundationMeter` into `Hud.Stack` on first use.
- Look: `hold_ring` frame; a gold `meter_disc` fill rising from the bottom (eased); the
  crack overlay over it (`crack_hairline`, `crack_split`, `crack_shattered`); a deep
  foundation turns the fill jade and shows the `foundation_ring_jade` glow (1.55x).
- Shown while seated (the cultivation bars are up) and, standing, only while cracked. A tap
  toasts "Foundation 60% solid, with hairline cracks. Meditate to mend it."
- The system must provide: the stage's solidity share, a crack level, and the deep flag,
  whenever any changes (a State field is the natural route).

### Death-save prompt (`DeathSave.luau`, roadmap 1)
- `DeathSave.prompt({ seconds = 4, hold = 0.6, title?, hint? }, function(accepted) end)`,
  `DeathSave.cancel()`, `DeathSave.isOpen()`.
- `Canvas.DeathSave`: `death_vignette` over the whole screen at 0.45 transparency (subtle),
  "Break through to survive?", a 128 px seal button (phone 79 px) with the breakthrough
  glyph, `heartbeat_ring` beating behind it (two quick beats, a rest), and a gold ring that
  sweeps round the seal while held (two clipped halves of `hold_ring`, each swept by a
  UIGradient). Letting go drains it. `hold = 0` makes it a tap. Mouse, touch, Space, E and
  gamepad A all hold. It answers false when `seconds` run out.
- Placed at 38 % of the screen height, so on a phone its hint ends above the realm crest.
- The system must provide: the trigger (a would-be killing blow with the bar at 90 %+),
  the time slow, and what accepting costs (a badly cracked foundation); the server decides.

### Dao level ring, technique tier frames, bloodline badges, heaven mark (`CultivationMarks.luau`)
- `daoRing(parent, level)` / `setDao(ring, level)`: `dao_ring` filling its (square)
  parent; its nine notches (every 40° from the top) show a `gem_jade` once `level >= k`;
  the centre reads the level, "Max" at 10 (`Weapons.MAX_LEVEL`). For the Arms window.
- `tierFrame(icon, tier)`: `tier_t1`..`tier_t4` as the icon's child, sized so the art's hole
  (72-77 % of it) sits just inside the icon box; `nil` removes it. The inventory and hotbar
  (branch `ui-inventory`) own the skill icons: call it from `SlotArt` where a technique icon
  is painted, with the technique's tier (the comprehension tiers: levels 1-3 T1, 4-6 T2, 7-9 T3,
  mastery T4; roadmap 4).
- `bloodline(parent, "Pure" | "Inherited")`, `heavenMark(parent)`: badges filling their
  parent's height at the art's aspect. For the character window (Self card) and the
  lineage card.
- `CultivationMarks.preview()` lays every mark out in the middle of the screen for 8 s.

## Alignment (measured in Studio)
- Tiles: icon, frame and caption centres on the tile centre (0.0 px); gaps 22.0 each;
  lotus centre y = tile centre y (0.00), lotus gap 22.2.
- Panel: title and divider on the panel centre (0.0); row seal 8 px from the row's left,
  action 8 px from its right; header 14 px from the top, last line about 16 px from the
  bottom; the close seal centred on the corner's ruby block (5, 5 in from the corner).
- Force Breakthrough: label centre 128.0 against the ring-to-chevron middle 127.7; glyph in
  the ring 21.0 against 21.5.
- Result card: grade and detail centred (0.0), 28.1 top and 28.2 bottom.
- Root reveal: seal, rays and every line centred (0.0).
- Title card: title 1.0 px above the plaque band's centre, both strips 130 px.
- Death-save: pulse, track, button and sweep share one centre; title and hint centred.
