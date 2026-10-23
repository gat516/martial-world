# Second bestiary wave: Venom Serpent, Stone Tortoise, Shadow Mane Wolf (testbed)

Venom Serpent, Stone Tortoise and Shadow Mane Wolf (testbed): fights, numbers, effects. Their mechanics (`guard`, `reach`, `flankPoint`) are in enemies.md "Attack mechanics". Shared systems (AI states, wire, cues, attack mechanics, template contract): [enemies.md](../systems/enemies.md).


Three regular beasts with their own bodies, behind `Config.Wilds.NEW_SERPENT`,
`NEW_TORTOISE` and `NEW_SHADOW_MANE` (all `= TESTBED`; they turn on attack slots and
dash-front hits like the other new fights). The Tortoise and the Shadow Mane have no old
def, so they exist only while their flag is on; with `NEW_SERPENT` off the old one-spit
serpent stays (the Jade Jiao's molt still summons whichever `VenomSerpent` is live). They
are in no ambient pack yet: the testbed zones `SerpentPair` (-90, 648.6, 80), `TortoiseSolo`
(100, 648.6, 80) and `ManePair` (0, 648.6, 140) keep them for the user to fight. Each is a
Studio-part body with its own pose module and effects (below). All numbers are first guesses
for the user's playtest, not balance; the user retunes them.

User decisions (2026-10-22): the serpent's strike and spit apply poison (the existing
`PlayerPoison`); Shell Guard is a real damage-reduction state; the Tortoise sits at mid tier
(QC6); the user retunes every number later. A Blood Centipede body is also being built (no
fight yet), and the Flame Raven (flies at melee height) is next.

**Venom Serpent** (QC3, 80 HP, weight 0.8, `body = "VenomSerpentB"`, the user's reference
cobra at 1.40x, root 5.1 x 4.8 x 15.9, muzzle 7.1 ahead of the root centre). A skirmisher: it circles
14 studs out (`pack.circle`, 5 studs/s), spits from 12 to 32 studs, strikes when you come inside 12, then slides back 9 studs (`pack.hop`, only
after a strike: `hits = 99`). It does not repeat the Jiao's lance, fang cone, spray, pools,
coil or dive.

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC3 140 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `venomSpit` (opener) | spit | 1.1 / - / 0.6 | 12-32 | circle r 5.5 on the target, lobbed gob lands at windup end | 15 (11%) + 1 poison stack 4 s | 2.6 s |
| `hoodStrike` | lunge | 0.6 / 0.25 (up to 8 studs at 32/s, stops 4 short of you) / 0.8 | 2-12 | box 3.5 wide, dash + 7 (`reach`: the muzzle leads the root) | 14 (10%) + 1 poison stack | 3.2 s, then the backslide (`hop`) |

Rushed inside 12 studs it strikes first (`closeOpener`). Poses: `EnemyPoses/VenomSerpent.luau` (a serpent family on `Serpent.luau`'s maths, QA'd on the
roster body rebuilt at 1.4x, not yet on `VenomSerpentB`), registered as `VenomSerpentB` with
`circleLoop` (its circle loop plays while it side-steps) and the moves `venomSpit`,
`hoodStrike`, `hoodStrikeSkid`, `hop`. Dash skids turn it round
(`hoodStrikeSkid`). The optional rear Tail Snap was cut: the pool picks by distance, not
bearing, so it would fire at the face.

**Stone Tortoise** (QC6, 450 HP, weight 6, walk 3.5 / run 6, `body = "StoneTortoiseB"`, the
user's reference at 1.76x, 13.3 x 13.9 x 22). Slow and heavy: it walks into you and picks from
a pool; Shell Guard first (after 5 s, every 14 s), then the stomp, then the snap. Reaches are
measured from the root centre: the root box is 13.3 x 8.5 x 22.0, the beak 10.8 ahead (11.5
stretched), the fore feet 3.3 ahead, so the stomp circle sits under the fore feet.

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC6 220 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `neckSnap` (opener) | cone | 0.7 / 0.12 / 0.9 | 13 | r 14, 60 deg | 24 (11%) | 2.5 s |
| `quakeStomp` | slam | 1.2 / 0.15 / 1.4 | 13 | r 10 at (0, 0, -3.3) | 40 (18%), stagger | 5 s |
| `shellGuard` | guard | 0.5 / hold 2.0 / 0.5 | 16, not before 5 s | none; takes 20% damage | 0 | 14 s |
| `shellSnap` (`arrive` of shellGuard, `chainOnly`) | cone | 0.35 / - / 1.0 | 14 | r 14, 70 deg | 24 (11%) | - |

**Shadow Mane Wolf** (QC6, 300 HP, weight 1.8, walk 9 / run 20, `body = "ShadowManeWolfB"`, the
user's reference at 1.63x on the wolf-family rig, root 6.5 x 8.4 x 21.3, muzzle 10.5 ahead of the
root centre). A flanker with no howl: it circles wide (`pack.circle` 18 studs, 7 studs/s), comes in on a flank, and fades back after a rend
(`pack.hop` 10 studs in 0.3 s, only after `maneRend`). Pool order: lash when hugged, rend, then
the step; rushed inside 11 it uses its pool (`closeOpener`).

| Attack (`name`) | Kind | Windup / active / recover | Range | Area | Damage (QC6 220 HP) | Cooldown |
|---|---|---|---|---|---|---|
| `shadowStep` (opener) | lunge, `flankPoint` 8 | 0.7 / 0.3-0.5 (up to 26 studs at 45/s) / 0.9 | 11-26 | 5-wide lane to a point 8 studs beside the target | 12 (5%) | 3.5 s |
| `shadowRake` (`arrive`, `chainOnly`) | cone | 0.4 / - / 0.9 | 14 | r 13, 100 deg | 22 (10%) | - |
| `maneRend` | cone + second cone at +0.35 s | 0.6 / 0.12 / 1.0 | 11 | r 12, 90 deg, twice | 16 (7%) a strike | 2.4 s, then the fade back |
| `maneLash` | slam | 0.8 / 0.15 / 1.1 | 8 | circle r 12 on the wolf | 20 (9%) | 6 s |

A step that ends with the target off its nose skids round (`shadowStepSkid`). Sounds
(`SFX.Enemies.StoneTortoise`, `ShadowManeWolf`, the serpent's additions) reuse existing ids
pitched, picked by description and unheard.


## Effects (second bestiary wave)
Handlers `EnemyFX/VenomSerpent.luau`, `StoneTortoise.luau`, `ShadowManeWolf.luau`
(shared helpers in `EnemyFX/BeastKit.luau`: template playback, attachment lookup
that tolerates a missing one, the dim-to-bright Tell strips, hit frame). Templates
`ReplicatedStorage.Effects.<Beast>`, builders `tools/vfx_specs/<Beast>.luau`. Each
handler only plays for the new bodies (`Template` = `VenomSerpentB`,
`StoneTortoiseB`, `ShadowManeWolfB`); the old defs play nothing. Every bright layer
sits on a dark copy so it reads in daylight; emitter counts are low (packs).
Shared with the old effects: `Impact.explode/ground/swipe/skid/shot` (venom, earth
and a violet-ink palette). Checked numerically against the real bodies in a sandbox (every attachment and Tell
resolves, the model faces -Z at an identity pivot, every cue fires without error, the
guard hold and the spit lob run); not played in a fight; feel and phone cost are the
user's to review.

| Beast / beat | Layers (templates) |
|---|---|
| Serpent windup (all) | EyeGlint star + held glow; Tell parts dim -> yellow |
| spit windup | SacSwell on both sacs (glow, haze, drips); MouthDrip (drips, mist); at windup - 0.4 s the gob lob (`Impact.shot`, venom) to `shape.center` |
| spit landing | `Impact.explode` venom + SpitSplash (splash, droplets, ring on slate, pool, glint) |
| hoodStrike | windup HoodGlint (star, glow on slate) per HoodSpot; strike/dash Streak (streak on slate, drops) at the Mouth; land HopDust |
| hit (strike, spit) | HitSplash (pop, splash, drops, poison bubbles) on the torso |
| hop | HopDust (dust, venom smear) |
| stagger / death | StaggerFlash + flash; Death (venom mist, motes, core glint) |
| Tortoise windup | EyeGlint on eyes and BrowMark; seams jade -> pale |
| neckSnap / shellSnap | windup Breath (neckSnap); strike SnapBurst (jade streak, chips, dust); hit HitChips |
| quakeStomp | windup ShellDust at the Core, FootPebbles at the four feet (hind feet twice: they dig); strike QuakeCrack (scar, jade crack glow, dust ring, chips, flash) + `Impact.ground` earth with rocks, shake 0.3 within 28 studs; hit HitJade |
| shellGuard | the `Guarding` attribute (wired on `ready`): seams cold white-blue, GuardSheen + a faint Highlight sheen for the hold; each Health drop while guarding throws GuardSpark on the shell; the end plays GuardRelease |
| stagger / death | StaggerChips + flash; Death (jade flash, crumble, chips, glint), seams go dark |
| Mane windup | EyeGlint violet; mane-edge/tail Tell parts dim -> flare |
| shadowStep | windup Gather; dash Takeoff, StepTrail on the Core host (smoke, streak, motes) and PawSmoke on 4 paws; land Arrive; skid `Impact.skid` |
| shadowRake / maneRend | windup ClawGlint on a front paw (+ small ManeFlare for maneRend); maneRend strike ClawSweep x2 (0.35 s apart, second rolled to mirror) + swipe dust; hit ClawRake |
| maneLash | windup ManeFlare (large) at ManeTop_FX; strike LashRing (ink, violet, flare rings, smoke, motes) + `Impact.ground` violet-ink; hit LashHit |
| hop | HopSmoke (smoke puff, ink smear, violet smear) thrown backward |
| stagger / death | StaggerFlash + flash; Death (ink smoke up, violet motes, glint) |

Needs from the body contract: attachments `Mouth`, `SacL/R_FX`
(serpent); `Mouth`, `Core`, `Foot{FL,FR,BL,BR}_FX`, `NeckBase_FX` (tortoise);
`Mouth`, `Core`, `Paw{FL,FR,BL,BR}_FX`, `ManeTop_FX` (mane); Neon `Tell` parts and
`EyeL/R`, tortoise `BrowMark` and `SeamTell*`. The server must send the `hit`
`enemyCue` once per player caught.

## Known gaps
- The second bestiary wave (Venom Serpent, Stone Tortoise, Shadow Mane Wolf) is untested in
  play and mostly unbuilt as of the server pass: reaches on the big Tortoise and the Mane's
  flank lane against the real bodies, whether Shell Guard's 20% reads (and its snap-out
  `arrive`), the serpent's poison at QC3, the poison-hop backslide, and every number. Rewards are
  placeholders; the Tortoise drops a Lesser core (and a small chance of a Greater).
