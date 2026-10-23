# Next beasts: Blood-Fed Hound and Ember-Scale Pangolin (approved concepts, 2026-10-22)

Approved design cards not yet built (Blood-Fed Hound, Ember-Scale Pangolin). Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).

Approved as concepts. Their design cards are written (below) but parked: the user left them
pending for the next monster pass. Then a fresh enemy-designer per beast takes its card and
the user's answers to its open questions, writes the briefs, and the pass runs as "Enemy work"
says (ask the user how many sandboxes first).
- **Blood-Fed Hound** (QC7, Ruined Borderlands: Deserters' Camp, Bone Gully). A war-hound the
  Blood Sect raises on cultivators' blood: hairless, scarred, ribs showing, a chain collar,
  blood talismans nailed into its back like the Blood Sect Cultist's. A pack of 2-3 that
  rushes straight in (the Shadow Mane flanks instead); its bite bleeds (the poison system,
  reskinned); it hunts the lowest-health or bleeding player; under half health its talismans
  burn and it speeds up. Wolf-family rig. It brings the blood cultivators into the wilds
  before humanoid enemies can animate; later a Cultist handler can lead the pack.
- **Ember-Scale Pangolin** (QC5-6, Ashen Hollow, the burned village). The "armour that
  pierces mountains", come out of the village fire with scales of cooled ember glowing at
  the seams. Roll charge (curls into a burning wheel, leaves an ember trail), curl guard (the
  Tortoise's `guard`), a tail flail at players behind it; its scales scatter as embers on
  death.
- The cut Frost Spider leaves no FE1 (Outer Wastes) beast; either of these could move up, or
  the slot waits for the Outer Wastes design.

Design cards (2026-10-22, pending the user's answers; nothing built):

**Blood-Fed Hound.** Look: a lean war-hound on the wolf-family rig, hairless grey-pink hide
with raised scar welts, ribs showing, a thin bare tail, a rusted iron collar with a broken
chain at the throat, three yellow talismans with red script nailed into its back (two
shoulders, one haunch), red eyes; the eyes and talisman script are the tells. Behaviour: packs
of 2-3 that come straight in (never circle or flank); targets the bleeding player, then the
lowest health; when one hound starts a bleed the others lift their noses and switch to that
player; while waiting for the attack slot it stalks head-on at 6-8 studs; no backing off, the
recover is the only gap. Attacks: **Blood Rush** (opener charge down a lane; ends in a short
**Rush Bite** cone if the target is in reach, else skids round), **Bleeding Fang** (wide-jawed
cone bite, the chain swings forward on the windup; a hit adds a bleed stack, the poison system
reskinned), **Blood Frenzy** (once at half health, no damage: rears and roars, talismans catch
fire for the rest of the fight; then faster and shorter cooldowns, windups unchanged; uses
`thresholdOnly`). Rig plan: the wolf-family joints incl. `JointJaw` and the tail, no crest or
mane; adds `JointChain` (from Neck) and `JointTalisman1..3`; tells `EyeL/R`, `TellTalisman1..3`;
attachments `Mouth`, `TalismanFire1..3`, `ChainTip`, `Core`, a torso `Hit`. Server work:
targeting by bleeding / lowest health, and a frenzy state at a health threshold.
Open questions, with the main session's suggestions: size (smaller than the Shadow Mane, so a
pack reads as hounds); does the frenzy add lifesteal (yes, the Bat's `leech`); does the frenzy
roar take the attack slot (yes, so no packmate hits during the window).

**Ember-Scale Pangolin.** Look: low and long (chest height at the shoulder, about 2.5 players
long, half of it tail; a ball stands about player height), charcoal and ash-grey roof-tile
scales with orange-red light in the seams, pale bone claws, ember eyes, a hot belly core seen
only when it uncurls. Behaviour: keeps moving and backs off to rolling distance (the Tortoise
walks in and stays); rushed or hit hard it curls, and a curl means a roll is coming; weakest just
after it uncurls (dizzy, slow to turn); behind its tail is the dangerous spot. Attacks:
**emberRoll** (tucks, rocks back, seams sweep bright head to tail, lane telegraph; rolls through
and past, leaving a short ember-trail patch; uncurls with its back to you and goes into
tailFlail if you're close behind, else skids round; it only turns while curled, before the
roll), **curlGuard** (the Tortoise's `guard`: seams go dark, eyes close, 20% damage taken, no
knockback; uncurls into emberRoll if you're in range, else recovers), **tailFlail** (forefeet
planted, tail coils over the back, cone behind it; picked only when the target is behind, and
as the roll's follow-up). Death: sags, seams flare, scales lift off as embers, a core glint in
the ash. Rig plan: `JointRoll` at the curled ball's centre (spin without hopping), spine
`JointChest`/`JointMid`/`JointHips` (90-100 deg each to close the circle), `JointNeck`,
`JointHead` (no jaw), `JointTail1..4`, four legs with `JointLeg*` + `JointShin*` that fold flat;
Neon seam strips per spine and tail segment (sweep), `EyeL/R`, `BellyCore`; attachments
`RollCore`, `TailTip`, `ClawFL/FR`, `Mouth`, `Core`. Server work: a bearing condition in the
attack pool (why the Venom Serpent's Tail Snap was cut), `patch` along a charge's lane, and a
`guard` follow-up into a charge (today `arrive` only goes into a cone).
Open questions, with the main session's suggestions: body (a new one by the modeler, unless the
testbed reference row `workspace.Folder.Model` has a pangolin); solo or a pair (solo, so the roll
lanes stay readable); ember trail burns or slows (burns: poison reskinned as fire); QC5 or QC6
(QC5, Ashen Hollow is the first stop past the border gate).
