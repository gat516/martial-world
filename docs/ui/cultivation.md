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
- `meditation_card.png` (1020x270, `art/ui/cultivation/draw_card.py`): the meditation
  panel's own shape. A lacquer-red crest raised 28 px above the top edge holds the title
  (set off from the body by a thin gold rule), concave cut corners (radius 12), and a
  shallow point 10 px below the bottom edge. The rail is the kit's: the cross-section of
  `window_corner_small`'s plain rail swept along the new outline, with upper-left light.
  Drawn at 3x; 9-slice `Rect(508, 159, 512, 165)`, `SliceScale` 1/3, so only the 4 centre
  columns (stretch ~1.0, the panel width is fixed) and the plain side rails stretch.
- `meter_disc.png`: a white disc, the foundation meter's fill (procedural, tinted in game).

Icons on the seated tiles: the kit's white glyphs where one fits (`glyph_qi` Circulate,
`glyph_insight` Technique, `glyph_quest` Method), tinted cream; the older drawn icons
(`meditation_art` in `art/ui/draw_ui.py`) for Break Through, Rise, Practice, Weapon Dao and
Back until Codex sheet B6 ([codex-sheets](codex-sheets.md)) replaces them.

## Restyled screens (`assets/Hud.rbxmx`)
| Piece | Path | Look |
|---|---|---|
| Seated tiles | `Stack.CultivatePrompt.*` | `tile_neutral` frame (Break Through: `tile_gold`, gold glyph and caption), glyph at 50 % centred on the tile (the frame art's hole is centred on the tile to 0.04 px), each icon cropped to its drawn area with `ImageRectOffset`/`ImageRectSize` (the Root icon's rect comes from `SelfCard.rootIconRect`) so its long side fills the box: 8.0/8.0/8.4/8.3 px to the hole (left/right/top/bottom; phone 7.4/7.5/7.8/7.7), caption under the tile (Builder Sans Bold 12, cream, ink stroke, no pill); the seal dot (`Badge`) is a `ruby_stud` on the top-right corner |
| Calm lotus | `Stack.CalmToggle` | the HUD's round seal (`figma/hud_round_seal.png`) with `emblem_lotus`, centred on the tiles' centre line (`placeLotus` sets it from the row's offset and the tile height) |
| Qi Surge pill (was Force Breakthrough; the label is set by code, see [HUD vitals](hud-vitals.md#qi-surge-pill)) | `Stack.BreakthroughButton` | `response_button_hi` sliced `Rect(200, 53, 860, 54)` at 0.374, the breakthrough glyph in its left ring, label centred between the ring and the chevron |
| Meditation panel | `MeditationPanel` | `meditation_card` backdrop (crest, cut corners, bottom point; `Backdrop` is the panel + 10 px wide and + 48 px tall, offset -9 so the crest rises above it); the gold title sits in the crest (136x23, centred on the crest's red field, `divider_cloud` hidden); `close_seal` with a live "×" over the top-right cut corner; rows: `crest_ring_plain` seal, `divider_diamond` rule under each row, actions on three-part `tag_jade` (suggested) and `tag_bronze` (the rest) ribbons fitted to their text (`Ribbon.fit`, styles `tag_jade`/`tag_bronze`). Content sits 15 px inside the rail's inner edge on all four sides (padding 12/18/18/18 plus the list's 6 px gap under the empty `Header`) |
| Circulation overlay | `Circulation` | gold title; the Leave pill is `tag_crimson`; the result card is `window_small` |
| Spirit-root reveal | `RootReveal` | `window_small` card, `rays_milestone` in the element's colour behind a `crest_ring_plain` seal, a gold `fx_shockwave` halo for rare roots (`Seal.Trim`) and a `tag_gold` "RARE!" tag |

Layout (PC 1616x784 Studio view, phone at 844x390): tiles are 54 px (phone: the 50 px
floor), 22 px apart, the row centred on the stack (row mid 808.0 = stack mid 808.0);
the row's bottom is 20 px above the stack top (the realm crest's top), so the captions sit
2 px under the tiles and their 14 px boxes end 4 px above the crest on every size (PC,
844x390, 750x369, 600x300). The lotus is `LOTUS_GAP` 22 px past the last tile, the row's own
gap, and level with the tiles' centre.

## Breakthrough card
Your own breakthrough shows the Rewards milestone card (`Rewards.show`, tier `card`, kind
`milestone`: stage name, the stats that changed, any travel array it opens; see
[reward banners](rewards.md)), not a card of its own: roadmap 3c's one card for three jobs.
The `Canvas.TitleCard` template built here (kit `title_crest`, turning `rays_milestone`,
`fx_glow`, a major-only glint) is unused and goes on the next Studio pass of this
ScreenGui. No full-screen flash and no darkening either way.

## The Cultivation ScreenGui
`assets/Cultivation.rbxmx` (mapped in both projects): `Canvas` (with the `UiScale`
UIScale, fitted by `CultivationGui` through `UiScale.fit`) holds `DeathSave` (and the unused `TitleCard`), laid out at the desktop baseline (1920x1080). On a phone every `Device`
UIScale under the canvas drops to 0.62, which keeps the smallest text at 11-12 px.
`Templates` holds the pieces other screens clone. `src/client/CultivationGui.luau`
returns the screen, a canvas piece, or a fresh template clone.

## Ready-to-wire components
Each has a `.preview()` callable from the client console in play, e.g.
`require(game.Players.LocalPlayer.PlayerScripts.Client.DeathSave).preview()`. Nothing in
the real flow calls them yet.

### Foundation line in the Self card (ready to wire)
Not built; a ui-designer adds it to the character window's Self card. The data is in
`State.current.foundation` (server `Foundation.state`, every PlayerState push):
`{ count, target, grade, grades = { [stageKey] = grade }, bonus, hints = { { category, text } } }`.
`grade` is what the current stage would get now (Cracked, Steady, Solid, Deep), `bonus`
the summed health/power share from graded stages (0.06 = +6%), and `hints` up to five
open experiences for this stage, e.g. `{ category = "Hunt", text = "Slay a Stone Boar for the first time" }`
or `{ category = "Boss", text = "The fast road: defeat the Elder Wolf King" }` (categories
Hunt, Boss, Home, Dao, Discover, World). Intended: one line "Foundation: Steady (3/5)"
and the hints as an optional list, so a player can solidify the stage if they want.

### Foundation solidity meter (`FoundationMeter.luau`, shelved)
Shelved by Phase A (2026-10-23): there's no meter; a foundation grade shows on the
breakthrough card instead ([roadmap](../roadmap.md) "Phase A"). Kept until that pass
decides whether to delete it.
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

### Death-save prompt (`DeathSave.luau`, shelved)
Shelved by Phase A: the qi surge fires from the realm plaque with no prompt or pause.
The vignette may be reused for the surge.
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
- Qi Surge pill (measured as Force Breakthrough): label centre 128.0 against the ring-to-chevron middle 127.7; glyph in
  the ring 21.0 against 21.5.
- Result card: grade and detail centred (0.0), 28.1 top and 28.2 bottom.
- Root reveal: seal, rays and every line centred (0.0).
- Death-save: pulse, track, button and sweep share one centre; title and hint centred.
