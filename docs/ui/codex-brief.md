# Codex brief: what to generate so the UI scales

Written 2026-10-22. This replaces the whole-sheet prompts in
[overhaul-plan](overhaul-plan.md) for anything that has to scale (frames, panels,
buttons, banners, prompts). The screens and phases there still stand; this page is
**how to ask the generator for the art**.

## The idea: generate a kit of parts, not finished screens
A finished dialogue panel from an image generator is one fixed size. On a phone, a
desktop, or a longer line of text it must stretch, and the generator can't promise
plain edges. So ask for the **parts**, and the build step assembles them at any size:

- **Corners** (ornate), with a short straight border arm leaving each. We mirror one
  corner into all four, and extend the plain border between them, so a panel can be any
  size and the ornament never stretches.
- **Button ends** (left cap, right cap) and a plain middle. A button can then be any
  width.
- **Ornaments** as separate overlays (the cloud flourish on a name tab, a header
  crest), placed by code and scaled independently.
- **Icons as white glyphs**, tinted in code, so one drawing serves every colour.
- **Text is never in the art.** Fonts draw all text, including the key letter on a
  prompt plate, so it stays sharp at every scale.

## What you give Codex every time
1. **The style reference**: [dialogue_prompt_reference.webp](../reference/ui/dialogue_prompt_reference.webp).
2. **The master spec** (paste below the image).
3. **One kit brief** (below). One kit per conversation keeps the style consistent.

## Master spec (paste at the top of every request)
> You are making game UI art parts for a Roblox xianxia game. Match the attached
> reference's look exactly: deep midnight-navy lacquer, warm gold trim, ornate gold
> corner flourishes with stylized cloud scrolls, cream text areas.
>
> **Palette (from the reference):** navy panel #192129, lighter navy #333d50, gold
> #d3a458, dark gold #97763b, cream #faecc3. Stay inside this palette; glows only in
> gold or warm white.
>
> **Technical rules, all required:**
> 1. Output each piece **centred in its own square cell** of the stated size, on a
>    **fully transparent background** (PNG with alpha). If you cannot output alpha, use a
>    flat pure magenta #FF00FF background with nothing else behind the piece, no gradient,
>    no shadow on it.
> 2. **Flat, even, front-on lighting.** No perspective, no 3-D tilt, no rotation, no cast
>    shadow, no drop shadow, no glow spilling outside the piece. Lighting must be symmetrical
>    (we mirror pieces), so no light from one side.
> 3. **No text, letters, numbers, watermark or logo** anywhere.
> 4. Pieces keep **4 % empty margin** inside their cell; nothing touches the cell edge,
>    except a straight border arm that is asked to run to the edge.
> 5. **Crisp edges, no blur, no noise, no photographic texture.** Vector-clean game art.
> 6. Where I say "plain", it means a single uniform line or flat colour with no
>    ornament, identical along its length.
> 7. Give **every state of a piece the same silhouette and size** (default, pressed,
>    disabled differ only in colour and inner detail).
> 8. Produce the pieces as **separate images**, one file per piece, named as in the
>    brief. Do not combine pieces into a poster.

## Sizes (why they are what they are)
Layouts are designed at a baseline (desktop 1920 x 1080, phone about 844 x 390) and
fitted with a `UIScale`. Art is made at **about 2x its baseline display size and no
larger than 1024 px** (Roblox shrinks anything bigger), because shrinking sharp art
looks crisp and enlarging small art blurs. So:

| Piece | Shown at (baseline px) | Make it |
|---|---|---|
| Panel corner | about 110 x 110 | 384 x 384 cell |
| Response button | 520 x 64, ends about 80 wide | 1024 x 256 whole, or caps 256 x 256 |
| Prompt plate | 88 round | 256 x 256 |
| Prompt banner | 300 x 60 | 1024 x 256 |
| Portrait frame | 200 square (phone 110) | 512 x 512 |
| Icon | 40 square | 256 x 256 |
| Ornament (name tab flourish) | 120 x 60 | 512 x 256 |
If a piece looks soft when we shrink or enlarge it, we ask for another size, rather
than force it.

## Kit 1: the panel kit (dialogue, reward card, quest windows, notices)
Files (all 384 x 384 cells unless noted):
- `panel_corner_tl.png`: the top-left corner of a dark navy lacquer panel with a thin
  gold double border and an ornate gold corner flourish with cloud scrolls. **The two
  border arms leave the corner as straight plain lines and run to the cell edge**, so
  the border continues cleanly when we extend it. Only the top-left; we mirror it.
- `panel_corner_tl_plain.png`: same, with a **much smaller, simpler** flourish (for
  small notices and tooltips).
- `panel_inner_corner_tl.png`: the corner of the **inner** thin gold frame (the text area
  box), small and simple, with arms to the edge.
- `panel_fill_tile.png` (512 x 512): a **seamlessly tiling** dark-navy fill with a very
  low-contrast cloud-scroll pattern. It must tile with no visible seam.
- `tab_cap_left.png`, `tab_mid.png`, `tab_cap_right.png` (512 x 256): the name-tab
  (a raised tab on a panel's top-left) split into a left cap, a plain stretchable
  middle, and a right cap carrying the cloud flourish that sweeps out to the right.
- `ornament_flourish_left.png`, `ornament_flourish_right.png` (512 x 256): the cloud
  flourish alone, for placing on headers.
- `chevron_continue.png` (128 x 128): the gold "continue" chevron, white-to-gold.
- Variants of the tab (`tab_*_gold.png`, `tab_*_crimson.png`): the same shapes in a
  brighter gold (masters and elders) and in dark crimson (demons).

## Kit 2: the response-button kit
For each state, `default`, `highlight`, `pressed`, `disabled`, `locked`:
- `button_<state>_cap_left.png` and `button_<state>_cap_right.png` (256 x 256 cells):
  the **end caps** of a long pill, ornate cloud-scroll ends, with an empty circular
  slot at the left cap for an icon. The cap is cut where the straight middle begins.
- `button_<state>_mid.png` (64 x 256): the plain stretchable middle. Same height,
  top and bottom borders only, **identical along its width**.
- `button_icon_disc.png` (256 x 256): the round icon disc (navy with a thin gold rim).
- **Highlight** has a gold-lit border and an arrow at the right end (`button_highlight_arrow.png`).

## Kit 3: the prompt kit
- `plate_key_empty.png` (256 x 256): the round brass key plate: thick brass ring, four
  small diamond studs, an empty cream key tile in the middle. **No letter on it**; the
  game draws E, A, X or a finger on top.
- `plate_key_pressed.png`: same, pressed in.
- `plate_hold_ring_track.png` (256 x 256): a thin empty gold ring (the track for
  hold-to-confirm; the game draws the fill).
- `banner_cap_left.png` (256 x 256) that tucks under the plate, `banner_mid.png`
  (64 x 256), `banner_cap_right.png` (256 x 256) with the cloud flourish trailing out.
  Three weights: short, medium, long are made by stretching the middle.
- `glyph_tap.png`, `glyph_gamepad_a.png`, `glyph_gamepad_x.png` (256 x 256): **white
  glyphs only** (a touch finger, an A button, an X button), no background.

## Kit 4: the portrait kit
- `portrait_frame_corner_tl.png` (384 x 384): the portrait frame's corner, gold, with
  the cloud flourish. Same rules as the panel corner.
- `portrait_frame_medallion.png` (512 x 512): a round head-only medallion frame for the
  phone (empty centre).
- `portrait_bg.png` (512 x 512): the dark misty navy portrait backdrop.
- `portrait_silhouette.png` and `portrait_unknown.png` (512 x 512): a calm silhouette,
  and the "???" silhouette, white on transparent so the game can tint them.
- **Character portraits** are art, not kit. One per speaker, **same framing** (bust,
  facing slightly left, 512 x 512, shoulders-up, transparent background or the backdrop
  above): Elder Qingyun, the Herbalist, the rack keeper, the NPC masters (to be cast),
  and the other recurring speakers. Add each one as the speaker is written.

## Kit 5: icons (white glyphs)
One file each, 256 x 256, **solid white glyph on transparent, no disc, no colour**.
The game tints and backs them. Same stroke weight and corner style throughout.
- Dialogue: speech bubble, bag, door with arrow, quest scroll, coin purse, bowing
  figure, sword, heart, lock.
- Stats and currency: spirit stone, qi, insight, contribution, solidity (a firm
  foundation), crack.
- Status: bleed (drop), burn (flame), chill (snowflake), break (cracked shield), stun
  (star), poison (skull and drop), pierce (spear tip).
- Interaction: talk, harvest, rush growth (hourglass), plant, open, pray.

## Later kits (same method)
- **Reward card kit:** frame corners (reuse Kit 1), `ribbon_cap_left/mid/right`,
  `rays_burst.png` (a radial sunburst, 1024 x 1024, symmetric), `tile_frame.png` (one
  neutral square tile frame that we tint for rarity).
- **Quest and sect kit:** row caps, rank crests (Outer, Inner, Core; 256 x 256),
  contribution chip caps.
- **Herbarium kit:** a book spread (page-corner pieces, binding, ribbon), entry-card
  caps, tier badges I to V.
- **Hall and master kit:** crest shield shapes, border pieces and emblem set (a builder
  needs parts), seat plates 1 to 9 as a frame only (the number is text), epithet ribbon
  caps.
- **World kit:** scroll banner caps (rod ends), event pins, decree card corners.
- **Overlay art:** the death-save vignette, seclusion overlay and cracks (one image each,
  1024 wide, stretched to the screen; these are not sliced).

## What happens to what you generate
1. Put the files in `art/ui/generated/<kit>/` (raw, as delivered).
2. The **assembler** (`tools/ui_assemble.py`, **to be written**) removes the background
   if it is magenta, trims, caps each piece at 1024 px, mirrors the corner into a full
   9-slice atlas, extends the plain border arms, builds the button from its caps and
   middle, writes `SliceCenter` and `SliceScale`, and runs `tools/check_slices.py`.
3. The `ui-designer` uploads, builds in Studio, fits it with the baseline `UIScale`,
   and checks on the phone emulator at real size.
4. Anything that looks soft or off goes back to you as a **specific re-request** ("the
   left cap, 512 px, border arm 4 px thicker"), not a rework.

## Checklist before you send me files
- [ ] One file per piece, named exactly as in the brief.
- [ ] Transparent background (or flat magenta), nothing else around the piece.
- [ ] No text anywhere, no shadow outside the piece, no tilt.
- [ ] Border arms run **straight and plain to the cell edge** on corners.
- [ ] Middles are identical along their length; the fill tile has no visible seam.
- [ ] Each state has the same size and silhouette as the others.
- [ ] Same palette as the reference.

## Open items
- Confirm the generator can output transparent PNGs; if not, magenta keying works.
- Cast the NPC masters, so their portraits can be generated.
- Write `tools/ui_assemble.py` before the first batch arrives.
