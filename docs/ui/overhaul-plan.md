# UI overhaul: the screens we need, and the art prompts

Written 2026-10-22 from the progression and roadmap discussion
([roadmap](../roadmap.md), [progression](../progression.md)). The UI is moving from
Pillow-drawn art to **generated reference art** (image generator, "Codex" in the
user's words). Pillow looks decent but not good enough. The reference:
[dialogue_prompt_reference.webp](../reference/ui/dialogue_prompt_reference.webp)
(dialogue panel, portrait frames, response buttons, interaction prompts), which is
the style anchor for everything below.

## Out of scope (already done, user, 2026-10-22)
The HUD vitals (health and qi bars), enemy health bars and boss bars were redone in a
recent commit and look fine as they are. **Don't redraw them.** New work only plugs into
them: for example, the foundation solidity meter is a small new element beside the
existing bar, drawn in the same style as it, never a replacement. The same goes for
the hotbar, the weapon badge and the windows that already exist: new screens match
them; they are not part of this overhaul unless the user says so.

## How the art pipeline works now (rules for the ui-designer)
1. **Prefer generated or supplied images to Pillow.** Pillow stays for icons, bars,
   fills and anything procedural. For frames, panels, buttons, banners and prompts,
   use generated art. If the brief has no reference, **ask the user for one** (or for
   a generated sheet) before drawing.
2. **Mobile first, and careful.** The phone is the smallest target (about 360 x 640
   logical, a thumb-sized touch target of at least 44-48 px high, body text at least
   14 px). Design the phone layout first, then widen it.
3. **Resolution and scaling: design once at a baseline, let a scaler fit it
   (user, 2026-10-22; the general industry practice).** Not every part of that
   advice applies in Roblox, so this is the adapted version:
   - **Roblox has no vector images** (no SVG on an ImageLabel) and caps textures at
     1024 px on the long side, so the "4K source" version is out. Raster only.
   - **Author each layout once at a baseline**, and scale the whole thing with a
     `UIScale` rather than redrawing per screen. Proposed baselines (verify in the
     device emulator): **desktop 1920 x 1080** and **phone landscape about 844 x 390**.
     A shared client module (`UiScale.luau`, to be written) picks the baseline by
     platform and sets scale = min(viewportWidth / baseWidth, viewportHeight /
     baseHeight), clamped, on one authored `UIScale` per ScreenGui. Per-frame
     `Motion` UIScales stay as they are and multiply on top.
   - **A phone is not a shrunken desktop.** Text at a small scale is unreadable, so
     the phone has its own baseline *and its own layout* (smaller portrait,
     stacked buttons), and a floor on text size. Never rely on shrinking alone.
   - **Art: author at about 2x the largest size it will show on its baseline, capped
     at 1024 px.** Shrinking a high-resolution raster stays crisp; scaling a small one
     up blurs. Pieces that would exceed 1024 px on their long side are **9-sliced**
     (ornate corners, plain repeatable edges, see the agent's 9-slice rules), or
     split into parts.
   - Never bake text into art. If a piece still blurs at some size, **generate
     another asset** (small, medium, large) instead of stretching one.
4. **Generation requests:** a flat single-colour background (pure white or chroma
   green, nothing painted behind it), one family per sheet, plenty of space
   between pieces so they cut apart cleanly, the same lighting everywhere (top-left
   soft light), no text, no watermarks, no drop shadows baked in.
5. **Check in Studio at real size** on the phone emulator before calling anything done.

> **Workflow (user, 2026-10-22): reference image first, extend the Figma kit's style (with
> a motif of its own where an element needs one), the ui-designer writes a Codex sheet
> request, the user runs it in Codex, Codex only generates and commits the sources, and
> the ui-designer cuts them with `tools/ui_assemble.py`, composes in the Figma kit, then
> builds in Studio.** Full steps: `.claude/agents/ui-designer.md`, "How UI art is made".
> Sheets: [codex-sheets](codex-sheets.md). The rules above and the prompts below are the
> older wording; where they disagree, the workflow wins (ornaments never stretch, plain
> middles do).

## UI kit in Figma (2026-10-22)
The source of truth for the overhaul's look is now a Figma kit: [Martial World UI Kit](https://www.figma.com/design/9u6RPHLelUJF6aABm6mY7y)
(user's account, Starter plan: 3 pages max). Parts, not screens:
- **Foundations:** colour variables (Primitives, aliased by Theme), type (Cormorant Garamond for
  labels and titles, Fredoka for numbers; Cinzel only for kit headers, since it renders 1 as I).
- **Kit:** ornaments cut from the two reference images (dialogue sheet, HUD vitals) and mirrored
  corner sets; frames built for 9-slicing (panel, inset, title plaque, name tab, toast, portrait,
  item slot, tooltip); buttons (response pill on the reference's own end caps, solid
  Primary/Secondary/Danger, round, close seal, tab, toggle); bars (fills, vitals mount, boss bar
  with Normal and Enrage); badges; 20 white glyphs.
- **Example:** one 1920 x 1080 screen built only from kit instances, including the proposed compact
  HUD (your name inside the realm plaque, one row instead of two).

Every piece of art still to generate, as Codex sheets: [codex-sheets](codex-sheets.md).

Known limits: the cut ornaments are 30-200 px, so they set the style but must be regenerated at
about 4x before shipping; the key plate has its E baked in. Pieces go to Roblox through the Studio
MCP's `upload_image`, which takes Figma asset URLs.

## Style anchor (paste into every prompt)
> Stylized xianxia UI art. Deep midnight-navy lacquer panels with a thin warm gold
> border and ornate gold corner flourishes, stylized cloud scrolls (xiangyun) in
> brushed gold at the corners and tabs, soft inner glow, subtle ink-wash cloud
> pattern inside the panel, cream serif text areas left empty. Elegant, restrained,
> readable at small sizes. Flat game-UI illustration with soft top-left light, crisp
> edges, no photoreal texture, no text, no logos. Isolated on a pure white
> background with generous spacing between pieces. Square pixels, high resolution.

## Phase 1: dialogue and interaction (do first)
Already have a sheet (the reference). What the sheet shows, and what to add.

| Piece | Status | Notes |
|---|---|---|
| Dialogue panel (named) | in reference | name tab on the top-left with a cloud flourish; portrait frame at the left; text area; continue chevron bottom-right |
| Dialogue panel (unknown "???") | in reference | same, with a silhouette portrait and "..." text |
| Portrait frame | in reference | square, gold ornate border, cloud flourish bottom-left. Needs a **small** variant (for the mobile HUD tracker) |
| Response button (default) | in reference | pill with cloud-scroll ends and an icon slot at the left |
| Response button (highlighted) | in reference (gold glow, an arrow) | the primary / recommended choice |
| Response button states | to generate | pressed, disabled (dim), a "locked" variant with a lock |
| Response icons | to generate | chat bubble, bag, exit, quest scroll, trade, bow, sword; same weight and size |
| Interaction prompt (E, Talk, Harvest, Rush Growth) | in reference | round gold key plate on the left, a dark banner on the right with cloud flourishes, icon slot at the right end |
| Interaction key plates | to generate | E, **tap** (a finger), A (gamepad), X, and a hold-ring variant for long press |
| Prompt banner sizes | to generate | short (one word), medium, long (two words plus icon) |
| Name tab variants | to generate | normal, "???" , and a **gold** (master or elder) and **crimson** (demon) variant |
| Continue chevron | in reference | plus a pulsing glow overlay |

**Prompt: dialogue sheet additions**
> Sheet of UI pieces, in the style: {style anchor}. A set of four response button
> states in one row: default (dark navy pill with gold edge and cloud-scroll ends),
> highlighted (the same with a bright gold glow and an arrow at the right end),
> pressed (slightly darker, inset), disabled (desaturated, dim gold). Each pill is
> 6:1, with an empty icon circle at the left. Below it, a row of eight matching
> round icons (a speech bubble, a cloth bag, a door with an arrow, a rolled quest
> scroll, a coin purse, a bowing figure, a sword, a heart), in cream on a navy disc
> with a thin gold rim.

**Prompt: interaction prompt kit**
> Sheet of interaction prompt pieces, in the style: {style anchor}. Five round
> gold key plates with a thick brass ring and four small diamond studs, each holding
> a cream key tile: the letter E, a touch finger (a tap icon), a gamepad A button,
> a gamepad X button, and an empty plate with a circular progress ring around it for
> hold-to-confirm. Then three dark banner shapes that tuck behind the plate and extend
> right with gold cloud flourishes at the top and bottom edges: short, medium and
> long. Empty text areas.

## Phase 2: the reward card family and quest UI
See [roadmap](../roadmap.md) section 3c (one card, three jobs).
- **Reward card frame** (the boss card, reused): ornate large frame, rays behind it,
  title ribbon, a row of reward tiles. Variants: **boss victory** (crimson and gold),
  **quest complete** (gold and jade, with a crest slot), **objective** (a smaller
  slim banner), **milestone** (the big breakthrough or bloodline card, full
  width, with a bloom).
- **Reward tile** (item, stone, qi, insight, contribution): square with rarity glow
  in four tints.
- **Quest log and sect board:** a window frame, a quest row (title, a reward strip,
  a progress bar), rank crests (Outer, Inner, Core Disciple), a contribution
  counter, a tracker line and a sticky "your wall" card.
- **Prompt:**
> Sheet of reward card pieces, in the style: {style anchor}. A large ornate card
> frame (3:2), a rotating-ray sunburst disc to sit behind it, a ribbon title banner,
> a slim notification banner (8:1), and a row of square reward tiles in four rarity
> glows (grey, jade, violet, gold). Empty centre and empty text areas.

## Phase 3: character, foundation and combat
- **Foundation solidity meter:** a small addition next to the existing vitals bar (match its style, don't redraw it), with crack states (none, hairline, split,
  shattered) as overlays, and a jade "deep foundation" glow.
- **Death-save prompt:** a large, centred tap button ("Break through to survive") with
  a heartbeat ring and a vignette overlay; one big thumb-sized target.
- **Seclusion screen:** a calm full-screen overlay with a lotus or a cave mouth, a
  timer, and a result card.
- **Self card:** a path crest, lineage line, bloodline badge (**Pure** and
  **Inherited**), a heaven-defying mark.
- **Arms window (per weapon):** a weapon frame, three skill slots with unlock levels,
  a Dao level ring, and technique tier frames T1 to T4.
- **Status icons:** bleed, burn, chill, break, stun, poison, pierce; one set.
- **Prompt:** *a set of seven matching 128 px status icons in cream on a coloured
  rounded tile (a blood drop, a flame, a snowflake, a cracked shield, a star, a
  skull-and-drop, a spear tip)*.

## Phase 4: garden, building and home
- **Herbarium:** a book frame (two-page spread), an entry card (herb art slot, name,
  tier, mutation tags), tier badges I to V, size and mutation tags, and an empty-entry
  silhouette.
- **Garden:** planting bar, seed picker tiles, harvest and rush prompts (phase 1).
- **Building:** a catalog tab strip, set icons (courtyard, jade pavilion, cloud
  palace, herb house, library, formations), the peak-score meter.
- **Prompt:** *a leather-and-lacquer open book, two pages, ornate gold corners, with
  an empty left page for art and an empty right page for text, in the style...*

## Phase 5: sect, Halls and masters
- **Hall:** a crest and banner builder (shield shapes, border, emblem slots), roster
  rows, a hall card, a group goal bar.
- **Master and disciple:** a lineage card (a portrait slot, epithet ribbon, seat
  number plate "Second Brother of the Turtle Saint"), a ceremony frame, a cohort
  roster of nine seats.
- **Prompt:** *nine-slot arrangement of seat plates in a fan, each a small gold plaque
  with a number, plus an epithet ribbon and a portrait medallion, in the style...*

## Phase 6: world and events
- **Event announcement banner** (a wide scroll with a title and a timer), event map
  pins, an off-screen direction chip, a countdown ring.
- **Tribulation overlay:** a warning ribbon, a safe-zone cue, and a "Heaven's decree"
  title card (a large black-and-gold card for the heavenly lines).
- **Secret realm rift:** an entry prompt, a modifiers list, a clear card.
- **Toasts and notices:** a small toast, a Hall or sect notice, a spirit-quest card.
- **Window pieces the existing windows lack:** only what a new screen needs (currency
  chips for contribution and solidity, a tooltip); reuse the current window frame and
  close seal.
- **Prompt:** *a wide scroll banner (6:1) unrolling with rod ends in gold, an empty
  centre; a heavenly-decree card, black and gold with lightning-thread corners*.

## Responsive rules (every screen)
- Design the phone first; the same art scales up by the baseline scaler, anchoring and
  slicing, not by redrawing.
- Touch targets at least 44-48 px; at most one dialogue panel and one prompt visible
  at a time; reserve the thumbstick and action cluster zones.
- Dialogue panel: on phones, portrait shrinks to a small frame at the left or a
  head-only medallion; choice buttons stack at the bottom and never overlap the text.
- Provide **small, medium and large** variants of any piece that must serve both
  phone and desktop, instead of stretching one.

## Order of work
1. Phase 1: slice the reference sheet, build the dialogue and prompt system with the
   `ui-designer`, one screen at a time with the user.
2. Phase 2: the reward card, then the quest log.
3. Phases 3 to 6 as their systems land (see the roadmap's order of work).
