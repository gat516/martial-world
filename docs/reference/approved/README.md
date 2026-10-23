# Approved and rejected: the bar

What the user has accepted and what they've sent back, with their words. The
`visual-critic` judges new work against this, and briefs name an entry here as
the exemplar to match. When the user approves something, the maker saves its
final sheet in `docs/reference/approved/<discipline>/` and adds a line. Keep the
lines short; the image is the record.

Seeded from the conversation history (2026-10-20 to 2026-10-23). Entries marked
"(no capture yet)" need their sheet saved the next time the thing is in a
sandbox.

## Approved

| Discipline | Item | Where | The user's words | Sheet |
|---|---|---|---|---|
| animation + vfx | Spirit Wolf pass: windup, lunge, howl call, pack | `src/client/EnemyPoses/Wolf*`, `docs/enemies/spirit-wolf.md` | "that was amazing" | (no capture yet) |
| vfx | Elder Wolf King boss effects, first pass | `tools/vfx_specs/ElderWolfKing*`, `docs/enemies/elder-wolf-king.md` | "that's really good" (before the ghost-copy cut) | (no capture yet) |
| vfx | Perfect dodge after-image, dodge and parry pass | `docs/combat/` dodge and parry visuals | "i like the after image effect", "looks good, push it to test" | (no capture yet) |
| ui | HUD kit reskin: pointed health bar with ruby tips, rounded qi bar, guard trough | `assets/Hud.rbxmx`, `art/ui/figma/README.md` | "looks great!" (then: give the bars more shape) | (no capture yet) |
| ui | Enemy health bar, segmented with the end gem | `assets/Nameplate.rbxmx`, `docs/ui/boss-bars.md` | "the healthbar we have for enemies is great" | (no capture yet) |
| ui | Boss bar with the 45-degree trough under a ruby socket | `docs/ui/boss-bars.md` | "boss bar is looking great", "45 looks fine" | (no capture yet) |
| bodies | Spirit Wolf B, Studio parts | `art/enemies/spirit_wolf_b/` | chosen over the Blender wolf: "we're gonna use studio from now on" | `art/enemies/spirit_wolf/preview/` |
| bodies | Part-built armour on humanoid enemies | `art/enemies/bandits/`, `cultivators/` | "the current humanoid work is really cool", "keep the armor work" | (no capture yet) |
| bodies | The user's reference row in the testbed (`workspace.Folder.Model`) | Studio only | the sizes and looks every boss body must match | (no capture yet) |
| modeling | Spirit peak pillar with the wide-to-narrow rock skirt into the lawn | `art/build_peak_pillar.py`, `art/spiritpeak/`, `art/main_peak/` | "that looks really good. can we add that same design to the main peak" | (no capture yet) |
| modeling | Spirit Fox cute ears (`FoxEarsBroad`): short, chunky, round dome peak, soft round cream tufts, seated on the head | `art/player/cosmetics/fox/` | "YES, the cute set for foxes is perfect. that is the exact direction i want to go in" | `docs/reference/approved/modeling/fox_ears_cute.png` |
| map | The sect-gate approach area detail (smooth terrain plus library rocks and trees) | `docs/map/` | "i want this level of detail" | `docs/reference/map_enclosed_valley.webp` (the look) |

## Rejected

| Discipline | What | The user's words | Rule it became |
|---|---|---|---|
| bodies | Jade Jiao rebuilt with a cobra hood and 18 segments; fox and ape redesigned | "BRO WHYAAAAGH", "the fox looks like shit, ape kinda overdoes it, jiao looks stupid" | match the reference row exactly; no redesign without asking |
| vfx | Cloned-body ghost afterimages on bosses; the flat howl disc | "really don't look too good", "couldn't give that a vfx effect? lol" | no body copies, no flat discs |
| vfx | A yellow circle for the perfect dodge | "why are we spawning a yellow circle... doesn't make sense" | every layer caused by the action |
| vfx | Camera-facing effects: the Rampaging Tiger claws that faced the player instead of the swing | "facing the player and not the direction the player is clawing in... we want the visual effects to feel physical" | no BillboardGuis or camera-facing planes; orient by the action in world space |
| vfx | Crown or halo motifs | "that'd look stupid lol" | none; the exception the user asked for (2026-10-23) is Great Sage Awakening's sigil: a flat glyph disc fixed to the back of the head in its own frame, never a billboard or a ring |
| vfx | Technique effects by the first Sonnet pass | "very misaligned and make no sense, like I'm just throwing vfx all over the place" | origin check; effects from the hand or mouth |
| vfx | Neon ground crack under Dragon Piercing / Heaven Splitting | "kinda eh" | cracks only from impacts |
| vfx | Boss health-bar effects | "went really overboard, i can't really see much" | the bar reads first; effects stay off the fill |
| map | Blue circular lighting on Foundation Establishment peaks | "ugly af, just get rid of it" | none |
| animation | Elder Wolf King first clips; the stun loop | "the anims are just so stiff", "leaning forward and it just reads like we're twitching" | chain lag, anticipation, one hero motion |
| animation | Thunder Ape landing then rotating; charges on every boss | "looks really tacky when the ape jumps around and THEN rotates", "all of the bosses have a stupid charge" | turn in the air; a charge ends in its blow |
| ui | Painted NPC busts | "so bad" | gray silhouettes only |
| ui | Heavy kit ornament on item tiles, slots, cards | "very very tacky" | repeated things are plain |
| ui | The realm plaque as a rectangle with cloud caps | "literally just a cube with ornaments smacked on top" | shape with depth, not ornament stuck on |
| ui | Menus docked at the bottom | corrected repeatedly | centre of the screen |
| ui | The phone HUD footprint | "i can see zero of the screen" | shrink, never enlarge |
| ui | Cropped studs, gems and buttons | "there's definitely cropping going on still" | `ui_lint` to zero FAIL before export |
| modeling | The tiered valley wall kit and the boulder kit; noise-blob rock; smooth-terrain water | "looks bad, give up on it", "melted", "that looks really janky" | library cliff rocks; crisp columns; no terrain water |
