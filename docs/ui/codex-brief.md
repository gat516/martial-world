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
   gets bigger or smaller with it. Sharp art shrinks crisply, so generate **large**.
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
3. **One piece family** from the list below, per conversation, so the style holds.
   Ask for several variants and pick the best; **iterate on the image you like**
   (edit it) rather than regenerating from scratch.

## Master spec (paste with the reference)
> You are making finished game UI art for a Roblox xianxia game. Match the attached
> reference's look exactly: deep midnight-navy lacquer, warm gold trim, ornate gold corner
> flourishes with stylized cloud scrolls, cream text areas.
>
> **Palette (from the reference):** navy #192129, lighter navy #333d50, gold #d3a458, dark
> gold #97763b, cream #faecc3.
>
> **Rules:**
> 1. One finished piece per image, **at the stated proportions and size**, on a **fully
>    transparent background** (PNG with alpha). If you cannot output alpha, use a flat pure
>    magenta #FF00FF background with nothing else on it.
> 2. **No text, letters, numbers, watermark or logo.** Leave text areas empty. Leave the
>    key tile on a prompt plate empty.
> 3. **Front-on, flat game-UI style.** No perspective, tilt or rotation, no cast or drop
>    shadow. A soft inner glow is fine, but **nothing glows outside the piece's outline**
>    (it is cropped there).
> 4. **Keep a calm, empty middle** on panels, buttons and banners (the text goes there), and
>    keep the ornate detail in the corners and ends. The straight stretches of border
>    between the ornaments should be **a plain, uniform line**, so the piece can be sliced
>    if we ever have to.
> 5. **Crisp, clean edges.** No blur, noise or photographic texture.
> 6. Leave **4 % empty margin** around the piece.
> 7. For a set of sizes (short, medium, long), **keep the same ornament size, border
>    thickness and end shapes**; only the plain middle gets longer.
> 8. Output at the largest size you can (**at least 2048 px on the long side**) and
>    keep proportions exact. We downscale; we never upscale.

## The pieces, with proportions and sizes
Display size is at the desktop baseline; generate at 2x or more (we downscale to
at most 1024 px per image, splitting wide pieces into tiles).

### Dialogue (generate first; the reference has most of it)
| Piece | Proportion | Display (px) | Generate | Notes |
|---|---|---|---|---|
| Dialogue panel, desktop | 4 : 1 | 1000 x 250 | 2048 x 512 | name tab sits on top-left; portrait frame at the left; empty text box; chevron at the bottom-right |
| Dialogue panel, phone | 3 : 1 | 560 x 187 | 1536 x 512 | designed at the phone's proportions, smaller portrait frame |
| Name tab, S / M / L | 4:1, 6:1, 8:1 | 160, 240, 320 wide | 1024 wide | raised tab with the cloud flourish; normal, **gold** (masters and elders), **crimson** (demon) |
| Portrait frame, large / small | 1 : 1 | 200 / 110 | 1024 / 512 | square, gold border, cloud flourish bottom-left |
| Portrait medallion (phone) | 1 : 1 | 96 | 512 | round head-only frame |
| Continue chevron | 1 : 1 | 28 | 256 | gold, with a separate brighter copy for the pulse |

### Response buttons
| Piece | Proportion | Display (px) | Generate |
|---|---|---|---|
| Response button, short / medium / long | 6:1, 9:1, 13:1 | 360, 540, 780 x 60 | 2048 wide |
| Response button, **highlighted** (gold lit, arrow at the right) | the same three | the same | 2048 wide |
| Icon disc | 1 : 1 | 44 | 256 |
Pressed, disabled and locked come from tinting the default (we add a lock glyph over it).

### Prompts
| Piece | Proportion | Display (px) | Generate |
|---|---|---|---|
| Key plate, empty (brass ring, four studs, an empty cream key tile) | 1 : 1 | 88 | 512 |
| Prompt banner, short / medium / long | 4:1, 6:1, 9:1 | 220, 330, 480 x 60 | 2048 wide |
| Hold-to-confirm ring track | 1 : 1 | 88 | 512 |
The key letter, the finger and the gamepad glyph are drawn on top (text and white glyphs).

### Icons (white glyphs on transparent, 256 x 256, no disc)
- Dialogue: speech bubble, bag, door with arrow, quest scroll, coin purse, bowing figure,
  sword, heart, lock.
- Stats and currency: spirit stone, qi, insight, contribution, solidity, crack.
- Status: bleed (drop), burn (flame), chill (snowflake), break (cracked shield), stun
  (star), poison (skull and drop), pierce (spear tip).
- Interaction: talk, harvest, rush growth (hourglass), plant, open, pray, tap, gamepad A,
  gamepad X.
Same stroke weight and corner style throughout. Generate them as a set so they match.

### Character portraits (art, not UI chrome)
One per speaker, **identical framing**: shoulders-up bust, facing slightly left, 1 : 1,
1024 x 1024, on the misty navy portrait backdrop or transparent. Elder Qingyun, the
Herbalist, the rack keeper, the NPC masters (to be cast, see
[roadmap](../roadmap.md)), a silhouette and the "???" silhouette (white on transparent).

## Later pieces (same method: finished, sized, no rebuilding)
- **Reward card family** (boss victory, quest complete, objective, milestone): each a
  finished card frame at its own proportions (3:2 large, 8:1 slim banner), plus a
  1024 x 1024 radial **ray burst**, a ribbon title banner S/M/L, and one neutral square
  **reward tile** we tint for rarity.
- **Quest and sect:** quest row S/M/L, rank crests (Outer, Inner, Core), contribution chip.
- **Herbarium:** an open-book spread (wide, tiled if over 1024), entry card, tier badges I
  to V.
- **Halls and masters:** crest shield shapes (several), border sets and emblems, seat plates
  1 to 9 (the frame only), the epithet ribbon S/M/L.
- **World:** scroll banners (wide, tiled), event pins, the "Heaven's decree" card.
- **Overlays:** the death-save vignette, seclusion overlay and cracks, each one full-screen
  image (stretched, not sliced).

## What we do with it (the assembler never repaints)
`tools/ui_assemble.py` (**to be written**), per file:
1. Remove a magenta background and trim to the piece.
2. Downscale (never upscale) to at most 1024 px on the long side; if the piece is wider,
   **cut it into side-by-side tiles**.
3. Where a piece must stretch, test its edges with `tools/check_slices.py` and write the
   `SliceCenter`/`SliceScale`; if it fails, report it so we ask for another size.
4. Write the file name, size and tile layout into a manifest the `ui-designer` reads.
The `ui-designer` then mounts the pieces in Studio under the baseline `UIScale`,
adds real text and glyphs, wires the tints, and checks at real size in the phone
emulator.

## Checklist before you send files
- [ ] One finished piece per file, at the stated proportions, at least 2048 px on the long
      side.
- [ ] Transparent background (or flat magenta), nothing else around it.
- [ ] No text, no outside glow or shadow, no tilt.
- [ ] The middle is empty, and the border between the ornaments is a plain line.
- [ ] S / M / L sets share ornament size, border thickness and end shapes.
- [ ] Same palette as the reference.

## Open items
- Confirm whether the generator outputs transparent PNGs; magenta keying is the fallback.
- Cast the NPC masters for their portraits.
- Write `tools/ui_assemble.py` before the first batch.
