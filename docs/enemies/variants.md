# Realm variants (2026-10-23)

Part of [enemies](../systems/enemies.md).

One def, many strengths: a spawn assigns a beast a realm, and it fights at that realm with a
tier that grows its body, speed, cadence and moveset in a few small steps. It fills the
stages with the existing roster ([progression](../progression.md) "Elite and apex tiers"; the
[roadmap](../roadmap.md) section 8 has what's next) using only moves, poses and effects that already exist. Behind
`Config.Wilds.VARIANTS` (testbed only until approved; off, every zone and pack spawns at its
def's own realm as before). Bosses never take variants.

- **Realm.** A zone (`Spawns.Zones[name].realm`, or the zone part's `Realm` attribute: `"QC4"`
  or `"QC3-QC5"`) or an ambient pack (`Spawns.Encounters` `realm = { lo, hi }`) gives the
  stage, or a range rolled per beast, so one lair spawns a mix. Ambient ranges lean toward
  their top the deeper the encounter is into its region (`Regions` `depth`, give or take
  `Pacing.Variants.AMBIENT_SPREAD`). Health follows the curve by player power and damage by
  player health, from `Pacing.BeastBaseline` at the def's realm to the spawn's, so a
  same-stage player needs as many hits and takes the same share of health as the def was
  designed for. Realm suppression, poison (a share of the variant stage's health),
  knockback (`Knockback.luau`) and the danger bar all use the variant's realm.
- **Tier.** The stage gap (spawn realm minus the def's) picks it, `Pacing.Variants.TIERS`:

  | Tier | Gap | Size | Speed | Cadence (cooldowns) | Health | Damage | Rewards | Look |
  |---|---|---|---|---|---|---|---|---|
  | young | below 0 | 0.85 | 0.9 | x1.25 | x0.8 | x0.85 | x1 (the onboarding's kill qi stays) | paler (20% toward bone) |
  | adult | 0 to 2 | 1 | 1 | 1 | 1 | 1 | 1 | the def as authored |
  | elite | 3 to 5 | 1.12 | 1.08 | x0.88 | x1.25 | 1 | x1.6 | darker (25% toward ink violet) |
  | apex | 6+, or a major realm up | 1.25 | 1.15 | x0.8 | x1.5 | x1.05 | x2.4 | darkest (35% toward blood ink) |

  Size scales the server's hit volume, root height and every reach, area and dash line
  (dash speeds too, so a dash takes as long and its poses stay in time). Windups and recovers
  never change: a higher tier gets more tells and combos, never shorter ones. `weight` scales
  with size, so a young boar (2.1) no longer staggers with its charge. `qiDrop` and stones
  scale with rewards; `drops` don't. Health and damage multiply the realm scaling.
- **Moves by tier.** An attack with `minTier` is gone below that tier (a pool beast whose
  opener is locked opens with its first pool move); `tiers = { elite = {...} }` replaces its
  fields at exactly that tier (`Enemies.NONE` clears one: a young howl's `summons`). A def's
  own `tiers` can override def fields (`pack` merges one level deep). Most unlocks are
  `followUp` chains of moves the beast already has, so each step keeps its own telegraph. A
  regular beast's follow-up now waits (until it lapses) while the target is inside its `minRange`, so "fade
  back, then step in" and "back off and it charges again" chains work.
- **The wire.** `Enemies.variant(id, stage?, tier?)` builds the variant def once per (id,
  stage, tier); the server stores it as the enemy's `def`, so every system reads its numbers.
  The model carries `Stage`, `Tier` and `Scale`, and clients rebuild the same def with
  `Enemies.forModel(model)` (EnemyBars: the name "Elite Spirit Wolf" and its realm tag;
  EnemyAnimator: timings). `EnemyMotion` scales the body about its root (`Model:ScaleTo`;
  the health bar's offset scales with it) and tints it (Neon, `Tell` and `Eye*` parts keep
  their colours); `EnemyAnimator` multiplies the family's pose scale by `Scale` (root
  translations, stride rates); `EnemySounds` pitches voices by 1 / sqrt(Scale).
  A howl's reinforcements of its own kind come at the howler's realm and tier.
- **First kills.** The first kill of each beast at each tier in each realm band is a Hunt
  experience (`hunt:<id>:<tier>@<band>`, the band from the variant's realm;
  [cultivation](../systems/cultivation.md#foundation-grade)), so the tiers refill the pools.
- **Testing.** The admin panel's "Beast tier" chips pick the tier the spawn chips use (at the
  tier's stage: young one below the def, elite +3, apex +6). The testbed zone `WolfTiers`
  (4 Spirit Wolves at QC1-QC8, (-200, 648.6, 60)) spawns a mix.

Per-beast unlocks are in each beast's doc. Zone realms (main map): GateWolves QC1 (young),
WolfPocket QC2-3, WolfDen QC3-5 (now and then an elite), BoarMeadow QC3-4, BoarField QC4-5,
SerpentMarsh QC5-7, SerpentFen QC5-6. Ambient: Inner QC1-4 (wolves QC1-3, young near the
gate), Borderlands QC5-8 (elite wolves, apex at QC8), Outer Wastes QR1-3 (all apex).
Ship: `VARIANTS = true` in `Config.Wilds`.

Known gaps: untested in play (sizes, tints, the bar's longer names on a phone, the new
follow-up chains, scaled poses on every family); the fliers' pose `scaled` ignores scale (their
root translations stay unscaled). Waiting on art: an elite/apex aura (vfx: a low qi haze
and motes on the body, darker for apex), the roadmap's "one extra move per tier" where a
chain of existing moves isn't enough (the serpent's twin spit, the tortoise's stomp wave
ring, a third mane rend: animator + vfx per beast), and a tier seal on the nameplate.
