# Codex brief: finished art, at fixed sizes, cut not redrawn

Rewritten 2026-10-22 after the user's point: when an AI (or Pillow) *rebuilds* generated art
from parts, it never looks as good as the generator's own image. So the rule is:

> **The image generator draws every finished piece. We never repaint, rebuild or
> "recreate" generated art. Our job is to crop it, key out the background, slice it
> if it must stretch, tint it for states, and put real text on top.**

This replaces the earlier "kit of parts" plan (corners mirrored into panels, buttons built
from caps). That plan made the work fall back on us, which is the problem. The screens and
phases in [overhaul-plan](overhaul-plan.md) still stand.

## How scaling works without redrawing
1. **Scale the whole layout, not the art.** Each screen is laid out once at a baseline
   (desktop 1920 x 1080, phone about 844 x 390) and fitted with one `UIScale`
   ([overhaul-plan](overhaul-plan.md), "Resolution and scaling"). A finished panel just
   gets bigger or smaller with it. Sharp art shrinks crisply, so generate at the largest
   canvas the generator offers (1536 px on the long side).
2. **Most pieces are fixed size.** A dialogue panel is the same size on every line of
   dialogue. A key plate is round and fixed. These need **no stretching at all**: one
   finished image each.
3. **Things whose width varies come in sizes.** Buttons and banners get **short, medium
   and long** versions, each a finished image at its own proportions, and the game picks
   the one that fits the text. If one is ever too small or large, we ask for another
   width. More assets is the answer, as decided earlier.
4. **The phone gets its own art where its shape differs** (a shorter, wider dialogue
   panel; a smaller portrait), generated at the phone's proportions rather than shrunk
   from the desktop one.
5. **If a true stretch is unavoidable** (a long list window), we **slice the actual
   generated image** with `SliceCenter`, only if its middle and edges are plain enough
   (the assembler checks this). Otherwise we ask for more sizes. We never mirror or
   repaint corners.
6. **Too big for one image (over 1024 px)?** Roblox shrinks anything past 1024, so a
   wide hero panel is **cut into two or three side-by-side tiles** (each at most 1024
   px, joined seamlessly), which keeps every pixel the generator drew.
7. **States are tints, not new art.** Pressed, disabled and hover come from code
   (`ImageColor3`, `ImageTransparency`, a darker or brighter overlay) on the same
   image. Only the **highlighted** (gold) look is generated, once.
8. **Icons are white glyphs**, tinted in code.
9. **All text is drawn by the font**, never in the art (including the key letter on a
   prompt plate), so it stays sharp at every scale.

## What you give Codex every time
1. **The style reference**: [dialogue_prompt_reference.webp](../reference/ui/dialogue_prompt_reference.webp).
2. **The master spec** (below).
3. **One image from the generation list**, with its canvas and its line. Ask for a few
   variants, pick the best, and **edit the one you like** rather than regenerating. For a
   S / M / L set, generate S first, then attach S and ask for M and L "identical except
   longer".

## Master spec (paste with the reference)
> You are making finished game UI art for a Roblox xianxia game. Match the attached
> reference's look exactly: deep midnight-navy lacquer, warm gold trim, ornate gold corner
> flourishes with stylized cloud scrolls, subtle ink-wash cloud pattern inside panels,
> cream text areas.
>
> **Palette (from the reference):** navy #192129, lighter navy #333d50, gold #d3a458, dark
> gold #97763b, cream #faecc3.
>
> **Rules:**
> 1. **One piece per image**, centred, on a **fully transparent background** (PNG with
>    alpha). If you cannot output alpha, use a flat pure magenta #FF00FF background with
>    nothing else on it. Nothing from any other piece in the image.
> 2. The piece **fills the canvas width (or height) with a 4 % empty margin** on every side.
>    Every flourish and cloud stays inside the canvas; nothing touches the edge.
> 3. **No text, letters, numbers, watermark or logo.** Leave text areas and key tiles empty.
> 4. **Front-on, flat game-UI style.** No perspective, tilt or rotation, no cast or drop
>    shadow. A soft inner glow is fine; **nothing glows outside the outline**.
> 5. **Calm, empty middle** on panels, buttons and banners; ornate detail in the corners and
>    ends. The straight border between ornaments is **a plain, uniform line**.
> 6. **Crisp, clean edges.** No blur, noise or photographic texture.
> 7. In a S / M / L set, **ornament size, border thickness and end shapes are identical**;
>    only the plain middle gets longer.

## Generation list (phase 1: dialogue, responses, prompts)
Canvases are what the generator offers: **wide 1536 x 1024**, **square 1024 x 1024**,
**tall 1024 x 1536**. A thin piece on a wide canvas fills the width and leaves the rest
empty (the assembler trims it). Save each file as `art/ui/codex/<file>.png`, exactly this
name; the assembler matches on it. Display sizes are at the 1920 x 1080 baseline.

**Layout decisions this list relies on (2026-10-22):**
- The dialogue panel **includes** its portrait frame and its text box (both empty), but
  **not** the name tab and **not** the chevron. Those are separate images laid on top, so
  a name of any length and the gold or crimson tabs don't need extra panels.
- Panels are **never stretched**. Desktop and phone each get their own panel.
- Buttons and banners are picked by text length from S / M / L; never stretched.
- Icons are drawn **white** and tinted in the game.

### Dialogue
| # | File | Canvas | Display | Draw |
|---|---|---|---|---|
| 1 | `dialogue_panel_desktop` | wide | 1000 x 250 | The dialogue panel, **4 : 1**, without its name tab. A square portrait frame at the left (gold ornate border, cloud flourish bottom-left, misty navy backdrop, empty), and an empty inner text box filling the rest with a thin gold inner border and a faint ink-wash cloud pattern at its lower corners. Ornate gold corners on the outer frame. |
| 2 | `dialogue_panel_phone` | wide | 560 x 187 | The same panel at **3 : 1**: a smaller portrait frame, a shorter text box, the same ornaments at the same thickness. |
| 3 | `nametab_S` | wide | 160 wide | The raised name tab from the reference (dark navy plate, gold edge, angled ends, gold cloud scroll trailing off its right end), **4 : 1**, empty. Its bottom edge is straight so it sits on the panel's top border. |
| 4 | `nametab_M` | wide | 240 wide | The same tab at **6 : 1**. |
| 5 | `nametab_L` | wide | 320 wide | The same tab at **8 : 1**. |
| 6 | `nametab_gold_M` | wide | 240 wide | Tab 4 for masters and elders: the plate in rich gold lacquer with a darker gold edge, the cloud scroll brighter. |
| 7 | `nametab_gold_L` | wide | 320 wide | The same at **8 : 1**. |
| 8 | `nametab_crimson_M` | wide | 240 wide | Tab 4 for demons: deep crimson lacquer (#5a1414) with a dark gold edge. |
| 9 | `nametab_crimson_L` | wide | 320 wide | The same at **8 : 1**. |
| 10 | `chevron` | square | 28 | The gold downward "continue" chevron, alone. |
| 11 | `chevron_glow` | square | 28 | The same chevron, brighter, with a soft gold glow **inside the canvas** (for the pulse). |
| 12 | `portrait_frame_small` | square | 110 | The square portrait frame alone, empty misty navy backdrop (for the quest tracker). |
| 13 | `portrait_medallion` | square | 96 | A round head-only portrait frame: gold ring, small cloud flourish at the bottom-left, empty misty navy inside. |

### Response buttons
| # | File | Canvas | Display | Draw |
|---|---|---|---|---|
| 14 | `response_S` | wide | 360 x 60 | The response button from the reference (dark navy pill, gold edge, cloud-scroll end caps), **6 : 1**. An empty icon space at the left, no icon. |
| 15 | `response_M` | wide | 540 x 60 | The same at **9 : 1**. |
| 16 | `response_L` | wide | 780 x 60 | The same at **13 : 1**. |
| 17 | `response_hi_S` | wide | 360 x 60 | The highlighted button from the reference (gold-lit edge and inner glow, small gold arrow at the right end), **6 : 1**, no icon. |
| 18 | `response_hi_M` | wide | 540 x 60 | The same at **9 : 1**. |
| 19 | `response_hi_L` | wide | 780 x 60 | The same at **13 : 1**. |
Pressed, disabled and locked are tints of 14 to 16 (with the lock icon on top).

### Interaction prompts
| # | File | Canvas | Display | Draw |
|---|---|---|---|---|
| 20 | `keyplate` | square | 88 | The round gold key plate from the reference (thick brass ring, four small diamond studs) holding an **empty** cream key tile. |
| 21 | `keyplate_ring` | square | 88 | Only a thin circular track ring the size of the plate's outer edge, in dark gold, empty inside (the hold-to-confirm progress fills over it). |
| 22 | `prompt_banner_S` | wide | 220 x 60 | The dark banner that tucks behind the key plate and extends right, gold cloud flourishes at its top and bottom right, angled right end, **4 : 1**, empty. Its left end is plain (the plate covers it). |
| 23 | `prompt_banner_M` | wide | 330 x 60 | The same at **6 : 1**. |
| 24 | `prompt_banner_L` | wide | 480 x 60 | The same at **9 : 1**. |

### Icons (one sheet each, white glyphs)
Ask for a **4 x 3 grid** on a wide canvas: each glyph white on transparent (or magenta),
centred in its cell, same stroke weight and rounded corner style, **cells far apart and
never touching**. Order left to right, top to bottom.
| # | File | Glyphs |
|---|---|---|
| 25 | `icons_dialogue` | speech bubble with three dots, cloth bag, door with arrow (leave), rolled quest scroll, coin purse, bowing figure, sword, heart, lock, question mark, exclamation mark, hand (give) |
| 26 | `icons_interact` | talk (speech bubble), harvest (sickle and leaf), rush growth (hourglass), plant (seedling), open (opening chest), pray (joined hands), tap (finger touching), gamepad A, gamepad X, gamepad Y, hold (finger with a ring), search (eye) |
Gamepad glyphs are the round button outlines only; the letter is drawn by the font.

### Portraits (art, not UI chrome)
**Identical framing for all**: shoulders-up bust, facing slightly left, square canvas,
on the misty navy portrait backdrop of the reference (no frame; the panel frames it).
| # | File | Who |
|---|---|---|
| 27 | `portrait_elder_qingyun` | Elder Qingyun |
| 28 | `portrait_herbalist` | the Herbalist |
| 29 | `portrait_rack_keeper` | the rack keeper |
| 30 | `portrait_silhouette` | an unnamed figure as a dark silhouette on the backdrop |
| 31 | `portrait_unknown` | the "???" silhouette: a plain dark head-and-shoulders with a cream question mark |
Masters get their portraits once they are cast (see [roadmap](../roadmap.md)).
Shown in game as flat gray silhouettes, not painted ([dialogue-ornaments](dialogue-ornaments.md#sheet-a4-portraits-are-gray-silhouettes)).

**Phase 1 is 31 images.** Stats, currency and status icons are generated with their
phases (below).

## Later pieces (same method: finished, sized, no rebuilding)
- **Reward card family** (boss victory, quest complete, objective, milestone): each a
  finished card frame at its own proportions (3:2 large, 8:1 slim banner), plus a
  1024 x 1024 radial **ray burst**, a ribbon title banner S/M/L, and one neutral square
  **reward tile** we tint for rarity.
- **Icon sheets** (same 4 x 3 white-glyph format): stats and currency (spirit stone, qi,
  insight, contribution, solidity, crack) and status (bleed drop, burn flame, chill
  snowflake, break cracked shield, stun star, poison skull and drop, pierce spear tip).
- **Quest and sect:** quest row S/M/L, rank crests (Outer, Inner, Core), contribution chip.
- **Herbarium:** an open-book spread (wide, tiled if over 1024), entry card, tier badges I
  to V.
- **Halls and masters:** crest shield shapes (several), border sets and emblems, seat plates
  1 to 9 (the frame only), the epithet ribbon S/M/L.
- **World:** scroll banners (wide, tiled), event pins, the "Heaven's decree" card.
- **Overlays:** the death-save vignette, seclusion overlay and cracks, each one full-screen
  image (stretched, not sliced).

## What we do with it (the assembler never repaints)
`tools/ui_assemble.py` (on branch `ui-assemble`, off `test`; run with
`uv run --with pillow --with numpy`), per file:
1. Remove a magenta background and trim to the piece.
2. Reject a piece that touches the canvas edge or has stray islands from a neighbour,
   and finish with one contact sheet (each piece beside its source on a checker) for the
   user to approve before anything is uploaded.
3. Downscale (never upscale) to at most 1024 px on the long side; if the piece is wider,
   **cut it into side-by-side tiles**.
4. Where a piece must stretch, test its edges with `tools/check_slices.py` and write the
   `SliceCenter`/`SliceScale`; if it fails, report it so we ask for another size.
5. Write the file name, size and tile layout into a manifest the `ui-designer` reads.
The `ui-designer` then mounts the pieces in Studio under the baseline `UIScale`,
adds real text and glyphs, wires the tints, and checks at real size in the phone
emulator.

## Checklist before you send files
- [ ] One finished piece per file, at the stated proportions, saved under its list name in
      `art/ui/codex/`.
- [ ] Nothing touches the canvas edge (clouds and flourishes included).
- [ ] Transparent background (or flat magenta), nothing else around it.
- [ ] No text, no outside glow or shadow, no tilt.
- [ ] The middle is empty, and the border between the ornaments is a plain line.
- [ ] S / M / L sets share ornament size, border thickness and end shapes.
- [ ] Same palette as the reference.

## Open items
- Confirm whether the generator outputs transparent PNGs; magenta keying is the fallback.
- Cast the NPC masters for their portraits.
