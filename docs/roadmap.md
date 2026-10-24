# Roadmap: what's next, deferred and open

The plan for taking the game to a full climb from QC1 to FE9. **Plans only:** what is
built lives in its system doc ([README](README.md) maps them); this page holds what's
open, deferred or next, in order, and the owner's decisions that constrain it.
[progression](progression.md) is the stage ladder; [core-loop](core-loop.md) is the
north star. Ideas far past the MVP (factions, the sect rebuild, peak kinds) are
parked in [dreams](roadmap/dreams.md). Nothing here has been playtested.

## Principles (owner)
1. **Nobody is barred by skill.** Bosses, tribulations and difficulty never gate
   progress. No difficulty modes with scaling. Mobile players always have a road. (Open
   against boss tiers and variants: [enemies](systems/enemies.md), Known gaps.)
2. **Two ways to climb, both complete:** the fighter (hunt, bosses, events) and the
   gardener (meditate, garden, seclusion, building, non-combat quests). Fighters are
   faster. Gardeners are never stuck.
3. **You can't skip the world.** Rushing a breakthrough hurts; experiencing the world
   heals and rewards. A soft cost, not a lock.
4. **Story over rules.** Every system reads as cultivation fiction (cracked foundation,
   heart demons, sect rank), not a menu.
5. Every system names its **arrow into the loop** (core-loop rules).
6. **Few mechanics at once (2026-10-23).** Fun for kids and mobile players first; depth
   for hardcore players without permadeath. Each mechanic is taught alone and fits in
   one sentence from the elder, or it's cut.
7. **PvP is off by default (2026-10-23).** No forced PvP: realm gaps would let a strong
   player delete a weak one, and the audience is kids and mobile (section 3f).
8. **How we work (2026-10-22):** one system at a time, designed and built with the
   owner in the main session and checked at each step. Subagents are for mass assets
   only (technique VFX batches, building sets, model batches). Each phase ends in a
   commit and a test-build playtest.

**Pacing rules for new content (2026-10-23):** no stretch over 2-3 h of active play
without something new (a zone, boss, rift or verb); each major brings a new verb, not
just numbers (QC the body and combat, QR the abode, FE weapon refinement and a first
sword glide; body refinement and others for later realms); the mid-QR slowdown is met
by the garden and the peak, not alchemy. Targets and the curve:
[progression](progression.md).

## Deferred (owner)
Real plans, **not in this pass**. Nothing before FE9 depends on them.
- **Alchemy:** the peak furnace, crafted pills (qi, heal, buffs, breakthrough aids,
  foundation repair), pill impurities and talismans.
- **Mining and ores**, and **full weapon refinement** (spend ore and stones to raise a
  weapon's grade; the candidate FE verb). Body refinement: a candidate later verb.
- **Bloodlines,** absorbed or injected; they will replace race rerolls. Granting by
  masters: [relationships](roadmap/relationships.md).
- **Halls, masters and lineage** (sections 3b, 3d).
- **Factions (everyone is orthodox for now), player-made sects and the sect rebuild**
  (2026-10-24): [dreams](roadmap/dreams.md).
- **Rifts and paths** (section 9, [replayability](roadmap/replayability.md)).
- **World events** (section 7; separate work).
- **Fortuitous encounters (owner, 2026-10-24):** the heavy player's long-term edge
  comes from encounters, not stone trickles or streaks. Now: seclusion's finds (band
  herbs and seeds told as encounters; [seclusion](systems/seclusion.md)). Later: world
  events (deferred, section 7) and secret realms (deferred) as the next encounter
  sources; each gets its odds from the [progression rules](systems/progression-rules.md)
  rarity table and a run of the pacing model.
- **PvP-adjacent competition** (section 3f).
- **The Grow now dev product** rework ([garden review](design-reviews/garden-and-herbarium.md) rec 1).
- **The junior disciple NPC escort** (section 3e).
- **Legendary herb pity**, and **herbs beyond FE (tier V)**: Tribulation Thunder Grass,
  Ninefold Heaven Lotus and Dao Origin Fruit are parked (`deferred = true`, `Herbs.Deferred`).
- **A physical heart-demon scene:** a mirror copy of the player with red eyes
  ([heart-demon](systems/heart-demon.md), "Later").
- **Acupuncture and doctors (user, 2026-10-24: "would be cool as hell"):** a healer's
  path. Players learn acupuncture and medicine to treat others: clear a qi deviation,
  soothe a heart demon's after-effects, speed recovery after a death or a strained
  surge, open a blocked meridian for a temporary cultivation boost. A non-combat road
  with a social arrow (players seek out a doctor; doctors earn contribution and
  titles), pairs naturally with herbs and, later, alchemy. Needs design: what a
  treatment is (a calm minigame on meridian points), what it costs, and safety limits
  so it isn't a paid-power shortcut. Feeds the heart demon (healer vs fighter).
- **Tempering VFX and animation (user, 2026-10-24):** a special seated look while a
  foundation is tempered in seclusion or by the heart demon: qi gathering into the body,
  the old stage's light reforging, a settling pulse when it lands. A `vfx` pass on the
  seclusion seat plus an `animator` pose (deeper breathing, hands forming a seal).
- **Deepening old foundations past 100% (user, 2026-10-24):** tempering mends stages
  only up to 100%; deepening lifts them to about 130% (150% stays earned live). Chosen:
  a fully calmed heart demon (in progress), heaven-and-earth treasures (rare spirit
  fruits, Earth Marrow, Spirit Milk, a Foundation Establishment Pill) and feats above
  your realm (a boss or apex a realm up). Later options: heavenly lightning baptism in a
  storm on your peak, sitting at rare spirit veins and springs, an epiphany after a
  great feat. Never for Robux.
- **What stands in now:** herbs are eaten directly; pills, cores and elixirs are loot
  and shop items; foundation repair uses meditation and the heart-demon trial; stones
  sink into the Herbalist, the Pavilion and building; weapon grades come from caches,
  bosses and the rack. Keep the hooks open (herb tier qi share, the item `use` system, a
  spare building slot for a furnace) so the update drops in.

## 1. Progression
- **Tuning:** the QR and FE curve from analytics; region seals wait for the map.
- **Heaven-defiers:** nothing sets `heavenDefying` yet. The flag must be an explicit,
  warned opt-in; open whether they get a real perk or a smaller tax
  ([pacing review](design-reviews/pacing-and-realms.md) rec 3).
- **The new verb per major** is not built (QR's abode is; FE's waits on refinement).
- **Foundation:** the second catch-up road is built (seclusion tempering with herbs and
  pills, to 100%; [seclusion](systems/seclusion.md#tempering)). Open: the next deepening
  sources (heaven-and-earth treasures, feats above your realm; `Foundation.deepen`), the
  Cultivate-window line, and QR/FE hunts once variants ship to the main map (section 8).
- **The haul:** a dedicated spirit-light for the spill (vfx), and materials joining the
  haul once they exist ([haul](systems/haul.md)).

## 2. Onboarding (each realm)
- **Start as a mortal taking the sect's entrance trial (user, 2026-10-24; in scope).**
  Everyone is orthodox for now. The trial frames the first session's existing beats
  (it is not a combat gauntlet up front, so no one is turned away by a fight):
  1. **The Testing Stone first:** you roll your root there (the hook; the front
     door's Fate reveal moved into the world), not an immediate breakthrough.
  2. **A sitting station:** the examiner asks you to sense qi; your first
     breakthrough.
  3. **Then the fight**, which can't be failed: low on health, an examiner steps in,
     and the elder says the trial judged your heart, not your fists.
  The climb up the trial path is the walk between them, replacing the lesson list
  rather than adding length; pass and you're an outer disciple. The onboarding funnel
  (`Analytics.beat`) shows if the fight still loses players. Needs the map (a trial
  path at the sect gate) and a re-slot of the first beats; the lesson system and its
  one-idea-per-chapter rule stay. Faction skins of the trial: [dreams](roadmap/dreams.md).
- **Tempering lesson (user, 2026-10-24):** teach tempering the first time it matters:
  when a player's foundation is first damaged or sealed low (a stage under 100%, or a
  heart-demon trial that tempers little) the elder points them to seclusion and a
  tempering herb or pill. Unlocked then, not before (one idea at a time).
- **Deepening lesson:** taught when it first matters too: the first time a player holds a
  heaven-and-earth treasure, lands a feat above their realm, or calms a heart demon, the
  elder names deepening once ("an old foundation can grow deeper still"). Not before.
The built schedule is [onboarding](systems/onboarding.md) "One idea per chapter".
- **Every major** repeats the pattern: one new idea, said once by the elder, with a
  rewarded objective and a guide. Next: one lesson per QR third (QR4: the garden aura
  and build items against the slowdown); FE lessons as their systems ship.
- **QC9:** the quiet ceremony and the heaven-defier's tribulation dialogue.
- **QC8** stays a breather until a wild garden exists to teach.
- The other circulation games (from QC4) and the Dao drill's game get a lesson each,
  one per breather.
- The wall card's verbs get icons once the tracker supports them.
- Build: reuse the lesson system in `Quests.luau`; add lessons, not beats. UI by the
  ui-designer.

## 3. The sect and quests
The MVP is built ([sect](systems/sect.md)). Next, sprinkled in from QR onward: weeklies,
bounties, sect tasks, spirit quests, sect-wide goals, Halls and masters.
- **Peaceful quests exist beside every combat quest** (herb errand, tend the sect
  garden, find a place, build a feature on your peak).
- Chains per region after the Borderlands one.

## 3b. Sect structure and Halls (proposed 2026-10-22; deferred)
- **One official sect, run by NPCs, that everyone starts in.** The demon path leaves it
  for the Blood Sect (also NPC-run); a rogue belongs to neither.
- **Player groups sit under it as Halls.** A Hall is 10-30 players with a shared name,
  banner, a hall they furnish together, a shared plot, and a small board of group
  goals. A Hall can belong to the sect, the Blood Sect or be independent, so every path
  can form one. **Hall is the name (owner, 2026-10-22).** Lineage is kept for the
  mentor tie below.
- **Lineage as a light mentor tie inside a Hall:** a senior takes a junior, both earn
  contribution when the junior advances.
- **Contribution is soft.** Nothing nags: at most one dismissible prompt per session,
  no penalty for ignoring it. Each playstyle contributes in its own currency (herbs,
  beast cores, pieces for the hall).
- **Spirit quests** (rare story asks from a spirit or the heavens, flavour and a cadence
  hook, never a chore) and **sect-wide goals** (server-wide shared tasks that reward
  everyone who helped).
- The Hall and lineage screens are built ahead and wait for this
  ([halls and masters](ui/halls-masters.md)).

## 3c. Reward banners
Built ([reward banners](ui/rewards.md), one card for three jobs; sect quests send it).
Still to send their specs: onboarding objectives and bloodlines.

## 3d. Relationships: masters, disciples and sect siblings (deferred)
NPC masters at QR1, cohorts of nine with numbered seats and epithets, player masters,
up to three masters, bloodline granting (trial chains, the Blood Rite) and the safety
rules: [relationships](roadmap/relationships.md).

## 3e. Reasons to meet other players
Parties, shared credit, realm pressure and the shelter bonus quests are built
([party](systems/party.md), [sect](systems/sect.md) "Bonus quests"). Next:
- **Group world events and roaming beast kings**, rewards scaled to each player's realm,
  so a senior helping still earns.
- **Co-op rifts** with better loot as a party; sect board tasks with shared credit.
- **Deferred (owner, 2026-10-24: "that'll have to be deferred onto a roadmap but that's
  a very good idea"): the NPC junior escort**, so a player alone still learns the
  shelter. A friendly junior sect disciple (a stock R6, runtime clone) follows the
  player into the wilds; beasts target it; the player shelters it to a destination (a
  region landmark, or a set distance in the testbed) while it lands a few weak hits so
  the shelter lifts the Suppressed status; minimal AI (follow, flee when hurt, a weak
  attack). Offered once per major from QR1 as a bonus quest, and once as the shelter's
  solo teaching moment (one elder line). Needs EnemyService to target a non-Player
  (today `target` and every hit path are Player-only).

## 3f. PvP-adjacent competition (owner, 2026-10-23; deferred)
- **Liked:** competition only between players of similar realm. Opt-in **spar** duels
  from the player card (nothing at stake), and **contested ground** for some high-realm
  world events (a marked PvP zone, same realm band only, bigger rewards, entered by
  choice).
- World-event competition by contribution: a base reward for all, extra for top
  contributors, a channelled treasure claim weighted by contribution, party
  contribution pooled.

## 4. Techniques and weapons
**Why they feel weak:** nothing rewards using them over M1, no enemy asks for a
technique, and nothing combines. Learning and comprehension gated on weapon Dao are
built ([combat](systems/combat.md)). **Deferred (2026-10-23): enough enemies; systems
first.** The plan (revised 2026-10-22: fewer techniques, deeper ones):
1. **Three skills per weapon class (21), found as manuals, unlocked by weapon Dao
   (owner, 2026-10-23)** at about Dao 2, 5 and 8. Pending: each class's **plain Dao 2
   first skill**, on the level of Palm Strike (none exists, so no class skill is
   learnable before Dao 5), and the rest of the 21. Open: do any-weapon arts check the
   highest class Dao, or their own threshold?
2. **Techniques deepen instead of multiplying:** each levels up through its visual
   tiers T1-T4 ([vfx style](vfx/style.md)).
3. **Statuses give them jobs:** poison, slow, stun and bleed plus a few new ones (burn,
   chill, break); each class owns one (sword bleed, spear pierce armour, staff stun,
   greatsword break guard).
4. **Enemies ask for them:** armoured beasts (the Stone Tortoise) need guard-break;
   fliers (the Flame Raven) need ranged or pull; packs reward area moves; bosses have
   weak points a technique exploits. Combo windows (a status plus a technique = a
   bonus) and root element resonance reward pairing.
- **Quantity target:** about 28: 21 class skills plus 7 any-weapon arts (the 5 existing
  and 2 elemental).
- **The Arms window:** one per weapon (Dao level, its three skill slots and their
  unlock levels) and a hotbar preset per weapon, so swapping weapons swaps the arts row.
  Scope with the ui-designer after the owner lists what is clunky now.
- **Build order:** statuses and combo rules, then the Arms window and presets, then
  re-pass the existing techniques, then a class at a time (a `vfx` agent per batch).

## 5. The spirit garden
Herb tiers, region seeds and the Herbarium are built ([garden](systems/garden.md)). Next:
- **Herb models** for the stand-ins (garden "Models to build").
- **Tending matters:** watering, pests or weather events, rare mutation chances, size
  records. Calm, no punishment for being away.
- **Wild gardens:** discoverable spots in each region (Discover experiences), harvest
  once a day; they need the map.
- **Gifting:** walk through a friend's peak and gift a herb.
- **Sect garden:** a shared plot the sect tasks tend (quests with no combat).
- More herbs as regions get their maps; tier V is deferred.

## 6. Building and assets
Peak tiers, room and the peak score are built ([build](systems/build.md)). Next:
- **Peak tier looks (the building pass):** the QC and QR looks, and `Ground` terraces
  that unlock the bigger radius on the real map, to the template contract in build.
- **Themed sets**, 10-15 pieces each, unlocked by realm, rank or quest:
  1. *Mortal courtyard* (QC): walls, gate, simple halls, bridges, stairs.
  2. *Jade pavilion* (QR): pavilions, a spirit pond with a bridge, lanterns.
  3. *Cloud palace* (FE): floating platforms, tiered halls, banners, sky gardens.
  4. *Herb house* (QR3): drying racks, herb shelves, a tea pavilion (the furnace comes
     with alchemy).
  5. *Library and training* (QR7): scroll shelves, weapon racks, training dummies.
  6. *Formations:* functional arrays (a meditation array, a garden-growth array), where
     most bonuses should live.
- **Sources:** sect contribution (Pavilion), quest rewards, event drops, the Herbalist
  and market for stones, and a few cosmetic Robux items (earnable first).
- **Pipeline:** a fresh `modeler` per set (Blender, FBX plus a placement script) for
  structures, Studio parts for small props, `ui-designer` for the catalog. Roughly
  60-80 pieces over the three majors.

## 7. World events and tribulation VFX (separate work)
Per [progression](progression.md) "World events" and the
[world events plan](vfx/world_events.md): resume `world-fx` (Heaven Split, Beast Surge,
new events) and rebuild the tribulation (clouds, bolts, eye, aftermath). Tribulations
stay rare, so the VFX can be big.

## 8. Enemies
- **Flag (owner, 2026-10-24): beast variety for QR and FE.** Every regular beast is
  native to QC2-QC8; the bosses are QC7, QC9, QR5 and QR9; nothing is native to FE. QR
  and FE are filled only by elite and apex variants of the same 8 beasts, and variants
  are off on the live map. **Plan:** about 3-4 new beasts for QR/FE plus one FE boss
  (the Ember-Scale Pangolin and Blood-Fed Hound designs are parked:
  [next beasts](enemies/next-beasts.md)), and turn variants on for the live map
  (`Config.Wilds.VARIANTS`, [variants](enemies/variants.md)).
- **Elite art follow-ups:** the elite/apex aura, the serpent's twin spit, the tortoise's
  stomp wave, the mane's third rend (animator + vfx per beast), a tier seal on the
  nameplate.
- **Cultivator enemies** wired as human opponents and sect-quest targets.
- Promote the second and third waves from the testbed after a playtest each.

## 9. Replayability: why come back after the ladder
**Baked in, not bolted on (owner, 2026-10-23):** no reincarnation at FE. What makes a
second run different is designed in now: races and bloodlines, the sect, rogue and
demon paths, random rifts, foundation percents to beat, and the haul's risk.
Rebirth with a legacy, paths as affiliations (sect, rogue, a secret demon path), mixed
secret realms and rifts, cadence, endless goals, social, new realms; then the
discoverable demon secret chain: [replayability](roadmap/replayability.md). Rule: build
1-3 only after the core loop and the ladder are proven in playtests.

## 9b. More cultivation elements (candidates, 2026-10-22; none decided)
Each must name its arrow into the loop.
1. **Fortuitous encounters:** rare, random, sharable moments while out (an old hermit
   in a ring, a dying cultivator's bequest, a hidden spring). Arrow: out.
2. **Pill impurities** (with alchemy): pills cloud the foundation; purify by meditating.
3. **Talismans** (crafting later): heals, wards, buffs, tribulation protection; found
   and bought ones can come sooner.
4. **Formations (arrays):** functional building, and a Formation Dao to comprehend.
5. **Spirit beast taming:** a tamed beast follows you (the cosmetic pet at FE6, earlier
   as an egg), later the soul companion. The strongest kid hook.
6. **Alignment and reputation:** righteous, neutral and demonic standing from deeds;
   ties to the demon secret.
- **Skip for now:** lifespan (stress), dual cultivation (audience), PvP-for-progress,
  an open player auction (scams).

## 10. Open from the design reviews
Recommendations the owner hasn't built or declined yet ([design reviews](design-reviews/README.md)).
- **Front door and HUD:** hide the paid Change buttons on a first creation and add a
  `PolicyService` check (retention rec 1); reveal HUD tiles and seated tiles as they're
  taught; Herbarium card names at 12 px; profile the HUD on a 2-3 GB Android; A/B a wolf
  pup before Circulate.
- **Cultivation:** one run refines a whole dantian from QC5, a higher efficiency floor,
  a seated "steady breathing" option from QR1, a new circulation game at QR1 and FE1,
  "spirit" for combat qi on screen (minigames review).
- **Qi surge** (the 90% gate stays): teach it once, scripted; its own PC key.
- **Seclusion and AFK:** logging out on your peak counts as seclusion; show AFK on the
  calm view; mutations roll offline too, and Wood's growth perk offline.
- **Heart demon:** curious, not accusing; "may add a question" and a pool cap of about
  8. (Visible tempering is built: the milestone payoff card; the owner keeps the judging
  lines and honesty scoring.)
- **Pacing:** a post-FE9 loop before FE ships; the QR5 aura objective line; a toast the
  first time a hit is suppressed.
- **Combat and techniques:** arts as seals in the touch cluster (and seal art for the
  words-only hotbar), M1 hit-stop and impact, `NEW_TELEGRAPHS` to main, one guard line
  at the first boar charge, combat events; the first boss drops an art for the class in
  hand, Dao out of comprehension, an unlock card, one job (the Tortoise and guard-break)
  before twenty arts.
- **Enemies:** a Bestiary page; boss tiers as rare "corrupted" world variants, not
  modes; phone-check variant names.
- **Haul:** the ring holding a share of raw qi or stones; one elder line on nodes as
  waystations.
- **World events and exploration:** finds that pay daily and a Wilds Journal, shared
  event rewards, events on a clock, early rumour lines, caches that refill stones daily.
- **Garden:** a shared Herbalist restock; an opt-in "herbs ready" notification.
- **Peak building:** the tier-up as a moment, score sets not counts, a Travel row to
  visit a friend and an "admire", the peak score on the Self card.
- **Party:** `PromptGameInvite` with a once-a-day friend reward, free private servers,
  a 4-ping quick wheel.
- **Sect:** a starter board at QC3-4, one sect-wide storehouse goal in the MVP, dailies
  that ask for range, an active home daily instead of seclusion, the reset time.
- **Retention:** one honest fixed-price cosmetic line, opt-in notifications, a like
  prompt, a session-end "tomorrow" line, a weekly beat (rotating seed, a weekend world
  boss).

## Order of work
| Phase | Work | Agents |
|---|---|---|
| H | Beast variety for QR/FE, variants on the live map, elite art, cultivators, curve tuning | `enemy-designer` per beast; analytics |
| F | Building: peak tier looks, sets, formations | `modeler` per set; `ui-designer` |
| D | Onboarding past QC: QR thirds, the QC9 ceremony | main; `ui-designer` |
| E | Statuses, combo rules, then techniques class by class (deferred) | main; one `vfx` per batch |
| G | World events and tribulation VFX (separate work) | `world-fx` |
| I | Replayability: paths, rifts, cadence, leaderboards, then rebirth | main; `world-fx`, `modeler` |

Before spawning, ask how many agents and sandbox Studios at once
([orchestration](agents/orchestration.md#how-many-at-once)).

## Open questions
- Foundation: which stats, and how big a gap between a bare 50% and 150%?
- Spill share (half), spirit-light lifetime (5 min), ring slot counts: right numbers?
- Surge (15 s, 25% raw qi, once per engagement): right numbers, and a cooldown beyond that?
- Essence blood: a resource of its own (for the surge, the Blood Rite, the demon path) or flavour?
- How much harder is a tribulation or heart-demon trial below 50% foundation?
- Does the Herbarium reward cosmetics only, or more than stones and a Home experience?
- Which building sets are Robux and which are earnable? (earnable first)
- Rebirth: a full reset (keeping the legacy) or a parallel second character?
- How harsh is the Blood Rite's cost (one stage plus days of ebb, as drafted)?
- Which NPC masters, and what does each teach? (draft the cast with the owner)
- Does a player master unlock at FE1 or a major above the disciple, whichever is later?
- How hinted is the demon secret: rumours only, or does the elder give a nudge?
- Does the demon path keep its own home peak look, or reuse the sect's with a demon skin?
