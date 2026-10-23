# Roadmap: progression, onboarding, techniques, garden, building

The plan for taking the game from "QC1-9 plus a thin Foundation" to a full game
that lasts QC1 to FE9. [progression](progression.md) is the stage ladder and the
sect; [core-loop](core-loop.md) is the north star. This page is **what we build,
in what order, and why**. Written 2026-10-22 from conversation. Proposals unless
marked built; nothing here has been playtested.

## Principles (from the user)
1. **Nobody is barred by skill.** Bosses, tribulations and difficulty never gate
   progress. No difficulty modes with scaling. Mobile players always have a road.
2. **Two ways to climb, both complete:** the fighter (hunt, bosses, events) and the
   gardener (meditate, garden, pills, building, non-combat quests). Fighters are
   faster. Gardeners are never stuck.
3. **You can't skip the world.** Rushing a breakthrough hurts; experiencing the
   world heals and rewards. A soft cost, not a lock.
4. **Story over rules.** Every system reads as cultivation fiction (cracked
   foundation, heart demons, sect rank), not a menu.
5. Every system names its **arrow into the loop** (core-loop rules).

## 1. Progression

### Built (untuned)
27-stage ladder, `heavenDefying` tribulation gate, optional bosses on the quest
board ([progression](progression.md)).

### Foundation solidity (replaces the insight gate; proposed 2026-10-22)
- Each stage has a **solidity** meter beside the bar. It fills by:
  - **time and tempering:** slowly while idle, faster meditating on your peak;
  - **experiences** (one-time, by category): Hunt (first kills), Boss (worth 2, the
    fast road), Home (first harvest of a herb tier, first pill, a full-bloom
    garden), Dao (weapon Dao milestones), Discover (wild gardens, caches, secret
    places), World (witnessing events and phenomena).
- A full bar **always** allows a breakthrough. Low solidity leaves **cracks**:
  slower passive and refining until repaired, and a harder tribulation for a
  heaven-defier. Cracks are repaired by meditating, pills, or tending the garden.
- Full solidity gives a small **deep foundation** bonus, so the experiences stay
  worth doing even when time would cover them.
- **Insight stays** as the spendable currency for technique comprehension only
  (its gate role is removed; `Pacing.Curve.insight` goes to 0).
- Damage: a heavy hit or death can crack the foundation a little, never cost
  cultivation.
- **Force breakthrough becomes a death-save:** when a blow would kill you and your
  bar is at least 90%, time slows and a big tap prompt reads "Break through to
  survive?" (no shift-lock, mobile-friendly). It costs a badly cracked foundation.
  The seated forced breakthrough in `Cultivation.breakthrough` stays as the manual path.
- Build order: docs and Pacing numbers, then `data.solidity` and the experience
  set, then the cracks, then the death-save prompt (ui-designer).

### Pacing follow-ups
Tune the QR and FE curve from analytics; the two bosses tuned for the old FE1 get
re-tiered; region seals wait for the map.

## 2. Onboarding (QC1 to QC9, then each realm)
Today the hook ends at QC3 and the garden, sect and techniques arrive unannounced.
- **QC1-3 (keep):** circulate, break through, root, travel out, hunt, technique,
  refine. Minor fixes only.
- **QC3 end:** the elder names the loop once ("cultivate until you hit a wall,
  go out and break it, come home stronger").
- **QC4 "your home grows":** garden and peak building taught as one beat (plant a
  seed, place one item). Rewarded.
- **QC5 the sect board:** daily tasks and contribution; the first chapter quest.
- **QC6 herbs matter:** eat a herb for qi; the Herbalist.
- **QC7 weapon and Dao:** second weapon class, a Dao drill (exists as lessons).
- **QC8 rumours:** the elder points at a secret place and a wild garden.
- **QC9 the realm wall:** the quiet breakthrough ceremony; for a heaven-defier, the
  tribulation with its own dialogue.
- **Every major** repeats the pattern: one new idea, said once by the elder,
  with a rewarded objective and a guide.
- **The wall card:** a persistent "your wall is X, go to Y" line (the objective line
  already exists; make it read in loop terms). Shows the current wall and at most
  two other goals.
- Build: reuse the lesson system in `Quests.luau`; add lessons, not beats. UI by
  the ui-designer.

## 3. The sect and quests
Per [progression](progression.md): ranks, board, dailies, weeklies, chapter chains,
bounties, sect tasks, contribution and a Pavilion shop (never qi).
- **Data:** a contribution counter and rank in `PlayerData`; quest defs reuse
  `Quests.Quest`; dailies reset by day (like the daily login).
- **Peaceful quests exist beside every combat quest** (herb errand, tend the sect
  garden, find a place, build a feature on your peak).
- **Build order:** rank and contribution, then the board UI, then dailies, then
  chains per region. UI by the ui-designer.

## 3b. Sect structure and contribution (proposed 2026-10-22)
- **One official sect, run by NPCs, that everyone starts in.** It is the hub, the
  elder, the board and the Pavilion. The demon path leaves it for the Blood Sect
  (also NPC-run); a rogue belongs to neither.
- **Player groups sit under it as Halls.** A Hall is 10-30 players with a shared
  name, banner, a hall they furnish together, a shared plot, and a small board of
  group goals. A Hall can belong to the sect, the Blood Sect or be independent, so
  every path can form one. **Hall is the name (user, 2026-10-22).** Lineage is
  kept for the mentor tie below.
- **Lineage as a light mentor tie inside a Hall:** a senior takes a junior, both earn
  contribution when the junior advances. It helps new players, which helps retention.
- **Contribution is soft.** The sect board offers tasks; nothing nags. At most one
  dismissible prompt per session ("The elder summons disciples to the hall"), no
  penalty for ignoring it. Each playstyle contributes in its own currency: herbs from
  the gardener, beast cores from the fighter, pieces for the hall from the builder.
- **Spirit quests:** occasional special asks from a spirit or the heavens (find a
  lost spirit, tend a dying tree, carry a message), rare, a story beat each, with a
  small reward. They are flavour and a cadence hook, never a chore.
- **Sect-wide goals:** server-wide shared tasks (fill the storehouse, light the
  wards before a beast tide) that reward everyone who helped. Cadence and social in one.

## 3d. Relationships: masters, disciples and sect siblings (proposed 2026-10-22)
The genre's heart, and a strong retention and social hook.
- **An NPC master at QR1 (Inner Disciple).** The player picks one of several peak
  lords or elders, each with a specialty (a weapon class, alchemy, the garden, a
  signature art). The master gives teaching quests, a signature technique at the
  right Dao level, and a voice that reacts to the player's life.
- **Sect brothers and sisters = everyone under the same master.** Disciples of one
  NPC master form a cohort that the game knows about: shown on the Self card, a
  shared board, small perks when near each other, and co-op bounties. It solves
  matchmaking the way a house does, with no lobby. Cohort size is capped by
  instancing the roster.
- **Player masters (from about FE1, or a major above the disciple).** A higher-realm
  player can take up to a few disciples; a lower one can ask. A short **ceremony**
  (the tea or bow, a cinematic beat) binds them. In return:
  - *Master:* contribution and prestige when a disciple advances, a title, and a
    "guide" action (meditate together for a small shared boost).
  - *Disciple:* faster foundation repair, a master's gift (an art or a herb, created
    by the server), and quests the master sets from the board.
  - *A master can guard a disciple's tribulation* (heaven-defier): stand with them,
    share the spectacle.
- **Numbered seats and master epithets (user, 2026-10-22).** Masters have epithets, and
  disciples hold a numbered seat: "Second Brother of the Turtle Saint", "Third Sister
  of the Sword Immortal". Epithets draw on the beast saints and genre titles (Turtle
  Saint, Azure Dragon Elder, Sword Immortal, Crane Sage, Thunder Venerable, Herb
  Mother). Seats are **cohorts of nine** per master, filled in the order players pick
  that master, so seniority is earned by joining early. Friends can join the same
  cohort by invite. A full cohort opens another (a "Second Court" of the same saint).
  The wording (Brother, Sister, or a neutral "Sibling") is the player's own choice.
  Later seats can be given up and refilled, so early seats stay prestigious.
- **Granting bloodlines (user idea, 2026-10-22).** Both kinds of master can pass on blood,
  and it always costs.
  - *NPC master:* teaches its saint's bloodline (the Turtle Saint, the Black Tortoise
    line) at the end of a hard, solo **trial chain** (a quest series, a boss, a
    ritual) and an essence. The cost is the effort, and the chain is the content.
  - *Player master:* **transmits** a bloodline they hold, as a **Blood Rite**. The
    costs are real:
    - the master loses **one awakening stage** of that bloodline (stage 2 or more is
      needed, so a stage-1 holder can't), which they re-earn with essences;
    - the master's bloodline skill is dormant for a few days (**Blood Ebb**) and their
      foundation takes a crack;
    - it needs a rare catalyst (a beast essence from a boss or event);
    - a cooldown of days, and a cap on transmissions per master.
  - *The disciple receives* stage 1 of that bloodline, marked **Inherited**
    (a descendant's mark, visible on the card) as opposed to **Pure** (found).
    Inherited blood cannot be transmitted again, so it can't spread in chains.
  - *Not transmittable:* heaven-defying bloodlines (the tribulation ones), and
    bought bloodlines. The demon bloodline stays a discovery, though a demon master
    could corrupt a disciple as a second route (both are cast out), a storyline
    creators will film.
  - *Abuse limits:* no sale or trade of rites, disciple must be a real account past a
    minimum age and realm, one inheritance per account per life.
- **Several masters, up to a limit (user, 2026-10-22).** You take one **primary master**
  at QR1 (your cohort and seat), then learn from more as you grow: a second at FE1, a
  third at FE5, **three at most**. Each teaches its own specialty (a weapon class,
  alchemy, a signature art) and has its own trial chain and gifts. Rules:
  - the primary master is your cohort and seat ("Second Brother of the Turtle Saint");
    the others are teachers, shown as "also taught by...";
  - a master's gift (art, herb, rite) is given once per master per life, so hopping to
    farm gifts does nothing;
  - leaving a master has a cooldown, and an NPC master remembers (a line, a cold
    reception); a player master is notified;
  - the one-bloodline slot still holds, so masters cannot stack bloodlines;
  - a **player master** has its own cap on disciples, separate from how many masters a
    player can have.
- **Visible lineage.** The Self card and nameplate show "Disciple of X", "Senior
  Brother of Y". A Hall can be a master's household.
- **Drama hooks.** If a disciple takes the demon path, their master (NPC or player)
  gets a reaction: a confrontation, a disown, or a plea. Redemption can lead back.
- **Safety and abuse (the audience is young):** opt-in on both sides; no
  currency or item transfer between master and disciple, only server-granted
  rewards, capped per day; no new chat channels beyond what exists; leaving is
  always allowed with a short cooldown; master must be a realm above, so it can't
  be farmed with alts for rewards.
- **Build order:** NPC masters first (data and dialogue), then cohort display, then
  player masters and the ceremony, then tribulation guarding. Needs cutscene beats
  (`vfx`), a master pick UI (`ui-designer`), and writing.

## 3c. Reward banners: show cultivation gains
Today gains show as small toasts, floating numbers and a Rewards feed. Players should
feel the big ones.
- **Three tiers.** *Small:* a floating number or a line in the feed (qi, stones).
  *Medium:* a top banner for a notable gain (a technique tier, a cracked foundation
  repaired, a Herbarium entry, a quest done). *Big:* a full card with a short beat and
  sound for milestones (a breakthrough, a first of a category, a bloodline, a rank).
- **The card shows what changed:** the stat deltas, the new unlock, and one line on
  what to do next ("Your foundation is firm. The Outer Wastes are open.").
- **One card, three jobs (user, 2026-10-22).** The boss victory card
  (`Rewards.luau`, `StarterGui.Rewards.BossReward`: a title, a subtitle, reward tiles
  that land on it, rays, tap to close) is reused for **quest completion** and for
  **onboarding objectives**, which are two different things with different looks:
  - *Boss victory:* as today ("Victory", "<boss> defeated").
  - *Quest complete:* "Quest complete" with the quest's name; tiles for stones, qi,
    contribution and a manual; the sect or Hall crest. Rare and weighty.
  - *Onboarding objective:* "Objective complete", lighter and quicker (a smaller card
    or banner, short life), because the hook fires many in a few minutes. Same tiles.
  The server sends one Effect with a `kind`, a title and a subtitle (today it is
  `"boss"` with a name and qi); `openCard` takes those instead of hard-coding "Victory".
- **Never block play;** big cards are skippable and queue, one at a time.
- **Build:** a reward-banner component in the HUD, fed by one server event with a tier;
  existing "breakthrough" cards fold into it. `ui-designer`, designed with the user.

## 4. Techniques and weapons (why they feel lackluster, and the fix)
**What exists:** 12 techniques (5 any-weapon, one skill per weapon class; the table in [combat](systems/combat.md)). They
are mostly damage with a cooldown, plus a comprehension bottleneck. I haven't
playtested them; this diagnosis is from the numbers and docs.

**Why they feel weak:** there is one skill per class, so there's no choice; nothing
rewards using them over M1; no enemy asks for a technique; and nothing combines.

**The fix, in four layers (revised 2026-10-22: fewer techniques, deeper ones):**
1. **Three skills per weapon class (21), found as manuals, unlocked by weapon
   mastery.** A technique can be learned any time, but it can only be *equipped*
   once that class's Dao level reaches its threshold: about level 2, 5 and 8 for
   the three skills (Dao runs 0-10). So mastery of a weapon is what opens its arts.
2. **Techniques deepen instead of multiplying.** Each technique levels up
   (existing comprehension) through its visual tiers T1-T4 ([vfx style](vfx/style.md)),
   so one skill grows from a plain cast into a spectacle. No new content per level
   beyond the tiers.
3. **Give them jobs.** Statuses the game already has (poison, slow, stun,
   bleed) plus a few new ones (burn, chill, break): each class owns a status
   (sword: bleed; spear: pierce armor; staff: stun; greatsword: break guard).
4. **Make enemies ask for them.** Armoured beasts (the Stone Tortoise) need
   guard-break; fliers (the Flame Raven) need ranged or pull; packs reward area
   moves; bosses have weak points and openers that a technique exploits. Enemy
   designers bake this into each beast's card. Root element resonance (exists)
   and combo windows (a status plus a technique = a bonus) reward pairing.
- **Quantity target:** about 28: 21 class skills (3 per class, the 7 that exist
  are the first of each), plus 7 any-weapon arts (the 5 existing and 2 elemental).
  Cut from the earlier 50; more can come later as manuals.
- **Weapon and arts UI is a separate flow fix.** The Inventory holds the pouch,
  arts and weapons in tabs and the player juggles badges and "Requires a sword".
  Proposal: an **Arms window per weapon** (Dao level, its three skill slots and
  their unlock levels) and a **hotbar preset per weapon**, so swapping weapons
  swaps the arts row, and a quick-swap on the HUD badge. To scope with the
  ui-designer after the user lists what is clunky now.
- **Visuals:** `vfx` agent per technique batch.
- **Build order:** statuses and combo rules, then the Arms window and per-weapon
  presets, then re-pass the existing techniques, then a class at a time (fresh
  agent per class).

## 5. The spirit garden
**Today:** about 11 herbs in 3 soils (bed, pond, grove), 7 mutations, sizes,
weather effects, wild sprouts, the Herbalist, Grow Now, and an aura on cultivation.
Herb qi is flat per item, so the garden loses value around QC6.

**Plan:**
- **Herb tiers** I-V tied to regions, qi as a share of the dantian
  ([progression](progression.md)); 3-4 new herbs per tier (about 20 more).
- **Alchemy** (QR3): a furnace on your peak turns herbs into pills (qi, heal, buffs,
  breakthrough aids, **foundation repair**). The sink for herbs and stones.
- **Tending matters:** watering, pests or weather events, rare mutation chances,
  and size records. Keep it calm, no punishment for being away.
- **The Herbarium:** a collection index of every herb, size and mutation seen,
  with rewards. It's the "grow a garden" hook and feeds the Home experiences.
- **Wild gardens:** discoverable spots in each region (insight-free "Discover"
  experiences); harvest once a day; a reason to explore.
- **Visiting:** walk through a friend's peak and gift a herb. A cheap social hook,
  and a way to show building.
- **Gardener road:** garden aura, pills and tempering carry a pure gardener to every
  wall, just slower than a fighter ([progression](progression.md) "Difficulty").
- **Sect garden:** a shared plot the sect tasks tend (quests with no combat).
- **Build order:** herb tiers and qi scaling, then alchemy, then the Herbarium,
  then wild gardens (map), then visiting.

## 6. Building and assets
**Today:** about 40 items in 7 categories (cultivation, decor, furniture, garden,
lighting, nature, structures), realm-gated, with meditation and garden bonuses;
the peak swaps its look at Foundation only.
**Needed:** more assets, more reasons to build.
- **Peak tiers per major** (QC, QR, FE): the peak itself changes look at each
  major, not only Foundation.
- **Themed sets**, 10-15 pieces each, unlocked by realm, rank or quest:
  1. *Mortal courtyard* (QC): walls, gate, simple halls, bridges, stairs.
  2. *Jade pavilion* (QR): pavilions, a spirit pond with a bridge, lanterns.
  3. *Cloud palace* (FE): floating platforms, tiered halls, banners, sky gardens.
  4. *Alchemy* (QR3): the furnace and its shelves, herb racks, pill gourds.
  5. *Library and training* (QR7): scroll shelves, weapon racks, training dummies.
  6. *Formations:* functional arrays (a meditation array, a garden-growth array),
     which are where most bonuses should live.
- **Rewards for building:** bonuses stay small and capped (`AURA_CAP`), but more
  items count: a "peak score" that adds to meditation and garden up to a cap.
- **Sources:** sect contribution (Pavilion), quest rewards, event drops, the
  Herbalist and market for stones, and a few cosmetic robux items.
- **Peak size and rooms:** a larger buildable area per major (a plot unlock).
- **Pipeline:** the `modeler` agent in Blender (FBX plus a placement script) for
  structures, and Studio parts for small props; `ui-designer` for the catalog.
  A fresh modeler per set; see [build](systems/build.md). Roughly 60-80 pieces over
  the three majors.

## 7. World events and tribulation VFX
Per [progression](progression.md) "World events" and
[world events plan](vfx/world_events_plan.md): resume `world-fx` (Heaven Split,
Beast Surge, new events) and rebuild the tribulation (clouds, bolts, eye, aftermath).
Tribulations stay rare, so the VFX can be big.

## 8. Enemies
The roster is enough for now. Next: elite and apex tiers (tint, aura, one move),
wire the **cultivator enemies** as human opponents and sect-quest targets, and
tune the old FE1 bosses.

## 9. Replayability: why come back after the ladder
A 27-stage ladder is a story you finish. Replay has to come from **variety, cadence
and goals that don't end**, not from more linear stages. Proposed, in priority order:

1. **Reincarnation (rebirth).** At FE9, or anywhere past the point of no return,
   a player may start a new life: a fresh root, a chance at a bloodline, a new
   path, and the climb again, faster and with a **legacy** carried over: the
   Herbarium, the peak and its buildings, Dao seeds, titles, and a small
   permanent bonus per life (capped, so it never trivialises the ladder). Fits
   the novels, and every life can be a different build.
2. **Paths are an affiliation, not a map (proposed 2026-10-22).** One shared world.
   A path decides **who gives you quests, where your home is, and where your qi
   comes from**; it never locks you out of a system.
   - **Orthodox sect:** the sect board, library and Pavilion; the Jade Peak home.
   - **Blood / demon path:** expelled from the sect. Quests come from a **Blood Sect
     outpost** that already fits the Ruined Borderlands (the Deserters' Camp), not a
     new map. Home is a demon cave tier of your own peak. **No spirit garden is
     forbidden**: the demon path gets a *blood garden* (the same plots with a
     blood-herb set: Blood Ginseng and kin), and an extra qi source from **beast
     cores and blood essence** dropped by beasts. Progression never depends on
     killing other players (no PvP-for-progress: griefing, kids).
   - **Rogue / wanderer:** leaves the sect on their own. Quests come from a market
     town or guild board, picks up scavenged materials and finds secret places;
     gardening, alchemy and building are first-class. Same quest system, filtered
     by affiliation.
   - **How you reach each (revised 2026-10-22):**
     - *Sect* is the default. *Rogue* is open: leave the sect from the elder or board.
     - *Demon is a secret, never a menu.* No UI offers it. Players discover it, and
       it is the "how to become a demon in Martial World" video. See "The demon
       secret" below.
   - **Reincarnation** lets a new life start as a mortal in a village and choose from
     the start; the character-creation dev can add a visible pick on top later.
   - Each path has its own quests, a few exclusive arts and cosmetics, and building
     sets, so a second life isn't the same game.
3. **Secret realms, mixed (user, 2026-10-22).** Not all procedural:
   - **Handcrafted realms:** named places with a fixed route, a boss, lore and a
     quest chain; one per region, mostly one-time rewards.
   - **Rifts:** handcrafted room kits assembled with random modifiers (enemy mix,
     herbs, one manual), repeatable, a daily first-clear bonus.
   - **Fully random** only later, if rifts prove popular.
4. **Cadence.** Dailies and weeklies on the sect board; world events (the roaming
   beast king, Dao rain, tribulation spectacles) on a schedule; weather moods;
   seasonal sect festivals (a themed week with limited cosmetics and an event herb).
5. **Goals that don't end.** The Herbarium, titles, achievements, technique tiers
   and Dao mastery, and **leaderboards**: realm, Herbarium, tallest peak, best
   garden. A **peak showcase** (visit and rate peaks) gives builders a reason to
   come back.
6. **Social.** Co-op bosses and events, visiting peaks, gifting herbs, a friends'
   sect. Roblox retention lives here.
7. **New realms.** Core Formation (the flying sword) after FE9 is the long-term
   answer; the ladder is designed to extend.
- **Rule:** build 1-3 only after the core loop and the ladder are proven in
  playtests. Replayability systems amplify a loop that works; they don't fix one.
- Build order: the flags and paths first (they shape data), rebirth after the
  first full playthrough exists, rifts after the secret-place tooling, then
  leaderboards and festivals.

### The demon secret (a discoverable chain)
Made to be found, shared and filmed. Nothing says "demon" in the UI; the clues
live in the world, and each step is a place or a thing a creator can show.
1. **Rumours.** Odd lines from NPCs, a defaced notice on the board, a Blood Sect
   cultist's dying words, a torn page in a ruin. They point at the Ruined
   Borderlands and a hidden altar.
2. **The talisman.** Blood Sect cultists (the cultist enemies, once wired) rarely
   drop a *blood talisman*; collect a few.
3. **The forbidden manual.** A hidden ruin (a secret place with its own small
   route) holds a forbidden manual. A clue found elsewhere reveals where.
4. **The demon essence.** A demon-beast core from a boss (a Roaming Beast King or
   the Jade Jiao) or a rare drop. Needs the right moment: a **Blood Moon** weather
   (a rare world event) opens the altar.
5. **The ritual.** At the blood altar, on a Blood Moon night: the essence is
   consumed and the bloodline awakens (a short ritual cutscene). Horns, a tail or
   wings appear on your character, visible to everyone. A server-wide line:
   "A demon has risen."
6. **The expulsion.** The sect's elders confront you (a short cinematic) and you are
   cast out. Sect board and Pavilion close; the Blood Sect outpost opens. Optional
   redemption later (purify the bloodline) for story.
- **Guardrails:** optional (never required for the ladder), never PvP-for-progress,
  every step doable on mobile, no step needs a coin flip you can't retry (rare drops
  have pity), and a hint trail exists for players who ask the elder, so it's findable
  without a wiki.
- **Other hidden chains** can follow the same pattern for other bloodlines and
  heaven-defying roots (a dragon, a phoenix), each a discoverable secret.
- Needs: the cultist enemies wired, a hidden ruin, the Blood Moon weather and
  altar (world-fx), the awakening ritual and expulsion cutscene, and the blood garden.

## 10. Order of work and who does it

**How we work (user, 2026-10-22):** one system at a time, designed and built with the
user in the main session, checked at each step. Subagents are for mass asset
generation only (technique VFX batches, building sets, model batches). The Agents
column below is who builds the *assets*, not who designs the system.
Each phase ends in a commit and a test-build playtest.

| Phase | Work | Agents |
|---|---|---|
| A | Solidity docs and numbers; `data.solidity`, cracks | main session |
| B | Herb tiers, qi scaling, alchemy furnace | main session; `modeler` for the furnace |
| C | Sect: rank, contribution, board, dailies, Pavilion | main; `ui-designer` |
| D | Onboarding lessons QC4-QC9 and the wall card | main; `ui-designer` |
| E | Statuses, combo rules, then techniques class by class | main; one `vfx` per batch |
| F | Building: peak tiers, sets, formations | `modeler` per set; `ui-designer` |
| G | World events and tribulation VFX | `world-fx` |
| H | Elite tiers, cultivators, curve tuning | `enemy-designer` per beast; analytics |
| I | Replayability: paths, rifts, cadence, leaderboards, then rebirth | main; `world-fx`, `modeler` |

A, B and C can run together if we split files carefully; D waits for C; E and F can
run alongside them. Before spawning, ask how many agents and sandbox Studios at once
(AGENTS.md).

## Open questions
- How big is a "crack"? Proposal: -15% passive and refine per crack, up to three,
  repaired at a cost of time or a pill.
- Is a death-save usable once per hour or once per stage?
- Do heaven-defiers get extra cracks from rushing, or a harder tribulation only?
- Does the Herbarium reward cosmetics only, or small solidity?
- Which building sets are robux and which are earnable? (earnable first)
- Rebirth: is it a full reset (keeping the legacy) or a parallel second character?
- How harsh is the Blood Rite's cost (one stage plus days of ebb, as drafted)?
- Which NPC masters, and what does each teach? (draft the cast with the user)
- Does a player master unlock at FE1 or a major above the disciple, whichever is later?
- How hinted is the demon secret: rumours only, or does the elder give a nudge?
- Does the demon path keep its own home peak look, or reuse the sect's with a demon skin?
