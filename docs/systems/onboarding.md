# Onboarding, quests and travel

## Purpose
Teach one system at a time in the first ten minutes, then hand players a quest
board of next goals. Teleport formations move players between their peak, the
main peak, the sect gate and the wilds arrays (see [map](map.md), "World structure").

## Design intent
- Never blocking: beats advance on conditions checked every second, and players
  already past one skip straight through.
- The elder speaks one line per beat (beside the guide, auto-shown); an objective
  line and a pulse on the right button show what to do. Talking to him opens the
  dialogue screen with a short conversation for that beat (see "Talking to the elder").
- Beats: see the beat table under "The first session" below.
- A beat can show progress after its objective (`progress`, e.g. Technique's
  kills "(1/3)").
- Travel can't be used to flee a fight (blocked while in combat or mid-action).
- In the sect, travel works from anywhere: the contextual tile shows Travel on the sect's
  safe ground (`Gates.inSect`) and rides to My Peak, Main Peak or the Sect Gate,
  so a player tending their garden can hop between peaks without walking to an
  array. Out in the wilds the button is gone; every array has a Travel prompt
  that opens the menu, and that's the only way to travel there.
- You still leave through the gate: the wilds arrays answer only from the Sect
  Gate's array or another wilds array (`Gates.leadsOut`); elsewhere their menu
  buttons grey out with "From the Sect Gate". They also open by realm
  (`Gates.required`, from the region's `realm`). Arrivals and respawns land on arrays.

## Hook fast: the onboarding direction (decided 2026-10-21)
Goal: the player feels the core loop (cultivate -> hit a wall -> go out ->
come home stronger) in the first few minutes, with as little friction as
possible. Day 1 retention is the measure; the onboarding funnel
(`Analytics.beat`, one step per beat after the front-door steps; [data](data.md) "What we track") shows where players leave.

What Roblox's own guidance and common practice say (sources at the end):
- **Teach the essentials, get to the fun quickly, leave them wanting more.**
  Roblox's FTUE guide judges onboarding by D1 retention and a per-step funnel,
  and suggests A/B testing single steps (e.g. a shorter dialogue against a
  guided arrow).
- **Show, don't tell.** One short line at a time, never a text wall; point at
  the thing (a spotlit button, a path on the ground) instead of describing it.
- **Early wins.** Low first thresholds so progress is felt at once (QC1's bar
  is 40), starter items and currency so systems get used early, a celebrated
  milestone to end on a high.
- **Goals in view.** Short, mid and long goals always visible (objective line,
  quest board), and a reason to come back (offline cultivation, daily login).

How we apply it:
1. **Start set vs encounterables.** Onboarding beats teach only what every
   player needs in the first session: circulate/meditate, break through, spirit
   root, travel, fight (M1, dodge), a technique, refine. Everything met later
   teaches itself through a **lesson** the first time it matters (see below),
   so the beat list stays short.
2. **Guided UI** (built, `Guide.luau`): each beat and lesson carries a `guide`.
   - `button` + `dim`: grey the whole HUD except that control (a spotlight with a
     soft pulse) until it's pressed. Only for the first-session beats, never
     mid-fight, never for lessons.
   - `button` "Travel" + `to`: spotlight Travel, then the destination in the menu.
   - `button` + `point` (+ `say`): no veil and nothing blocked, but a bobbing
     gold pointer beside the control (`Hud.Guide.Pointer`, tip toward it, from
     its outer side) and a short step line in the callout. For lessons that
     need more than a pulse (RootPill). Lifts once the control is pressed.
   - In-window controls (`INSIDE` in `Guide.luau`, e.g. `RootPill`): the
     window's script marks the control with a `GuideKey` attribute (and may
     give it its own callout line, `GuideSay`); until that window is open the
     guide points at the control that opens it. A target inside a scrolling
     list is scrolled into view.
   - `place`: a path to walk to the target: a stream of jade qi along the
     ground with spirit motes drifting ahead, a slow gold formation circle and
     a faint light column at the target, a short flourish on arrival, plus an
     edge-of-screen arrow when it's off screen (see "Guide visuals").
   - The elder's line sits beside the spotlight; one line, auto-hides.
3. **Fewer steps to the first fight.** Measure time-to-first-kill in the funnel;
   cut anything between the root reveal and the wilds that isn't fun.
4. **Celebrate the highs:** the root reveal, the first breakthrough and the
   first technique are the moments to ask players to favourite the game.

**The first session (the hook, 2026-10-23):** from Roblox metrics (median session
5-9 min): combat right after the first breakthrough, three breakthroughs in about
ten minutes, one mechanic per beat. Before the third breakthrough the player meets
sit/circulate, breakthrough, combat, a technique, storing the haul and refining;
the spirit root and the travel formations' wider use wait until QC3.

| # | Beat | Teaches | Done when | Guide | ~min |
|---|---|---|---|---|---|
| 1 | Circulate | sit, the circulation minigame | a run finished | Cultivate, then Circulate (dim) | 0:30-1:00 |
| 2 | Breakthrough | the realm bar | first breakthrough | Break Through (dim) | ~1:15 (QC2) |
| 3 | FirstKill | combat, dodge; one spotlit ride (`travel = true`) | a kill | Travel -> Sect Gate (dim), then the nearest wolf | ~2:00 |
| 4 | Technique | kills earn manuals | the 3-kill milestone (Fire Seal) | the nearest wolf, "(n/3)" | ~3:00 |
| 5 | Cast | casting an art | any technique cast once (technique XP) | the art's hotbar slot (pointer, "Cast it at a wolf") and the wolf | ~3:15 |
| 6 | Store | the haul: bank it or lose half on a fall | `Haul.onBanked` fired (skipped without it) | the nearest array (testbed: the pad) | ~3:30 |
| 7 | Refine | raw qi -> cultivation at a node | a run since the beat began, or a full bar | circulate here, else the qi node by the gate wolves | ~4:00 |
| 8 | QC3 | the climb, again | QC3 | climb guide | ~4:30-5:00 |
| 9 | Root | spirit root, the formations | root tested | Travel -> Main Peak, then the Testing Stone | ~5:30-6:30 |
| 10 | QC4 | the loop alone (home to refine, out to hunt) | QC4 | climb guide, never silent | ~9-10 |
| | FreePlay | names the loop in its one-liner | | lessons, then the quest board's top goal | |

Minute marks assume `pacing-v2`'s curve (QC1->2 in ~1.5 min, QC2->3 by ~4-5,
QC3->4 by ~9-10); not yet timed in play.
- **The first breakthrough is guaranteed:** the very first run (one easy Maze level)
  fills the bar whatever the score, with no deviation (`Config.Circulation.FIRST_RUN_FILLS_BAR`).
  `STARTING_RAW_QI` is 48, exactly that run, so the dantian really is spent and the
  wolves are why you go out.
- **No starting technique:** new profiles start with an empty hotbar; Fire Seal (the
  3-kill manual) is the first art, taught by the Cast beat. Older profiles keep
  Lightning Talisman.
- **Gate wolves:** `Spawns.Zones` overrides a zone's own count and respawn by
  name: GateWolves 3 wolves, 8 s respawn (was 2 and 20 s), so a solo player or a
  pair (both are credited on a shared kill) gets 3 kills without waiting; the
  testbed's WolfPair keeps 2 but respawns in 8 s. With realm variants on (`VARIANTS`) they
  are young QC1 wolves ([spirit wolf](../enemies/spirit-wolf.md) "Realm variants"): no leap,
  a howl that only rallies the lair (no reinforcements), 7-11% hits, full kill qi.
- **Refine near the fight:** the qi node at (60, 8, 545) is about 100 studs from
  the GateWolves lair; Cast adds a fifth of a dantian of raw qi so that run
  reaches QC3.
- **The root reveal** (the favourite prompt, `RootReveal`, 1.5 s after the card
  closes) is now the QC3 high point instead of the first.
- **Skipped beats:** a beat's `skip` (Store: no `Haul.onBanked`) passes it over
  unmarked and unpaid, so it's met once that system is in the build.
- **In the testbed** the ready "Tester" (slot 1) skips onboarding and has the test
  kit; a character made in the creator (slot 2) gets no kit and plays every beat.
  There are no arrays, so ride steps become walks (`travelTo`'s `walk`: the wolves,
  the Testing Stone, `MyPeak` to refine and bank on the spawn pad's TestPeak; first
  player only).

**One idea per chapter after the hook** (user, 2026-10-24, from
[onboarding-lessons](../design-reviews/onboarding-lessons.md) and
[first-session](../design-reviews/first-session.md)). Each lesson is one live system:

| When | Lesson | Elder line (the why) | Objective (the what) |
|---|---|---|---|
| QC4 | Home | Your peak grows with you. Plant a seed in your garden. | Plant a seed |
| 2nd session | Seclusion | Rest now. Your peak works for you while you're away. | Enter seclusion at home |
| QC5 | Rumours | The Borderlands are open. Old manuals hide off their paths. | Find a hidden cache |
| QC6 | Herbs | Herbs are qi you can carry. Eat one when you run dry. | Eat a herb |
| QC7 | DaoPractice | Practice your weapon's forms as you sit. Its Dao will deepen. | Practice your weapon's Dao |
| QC8 | none | a breather | |
| QC9 | HeartDemon | Your heart demon stirs. Sit, and face it honestly. | Face your heart demon |
| QR1 | WeaponRack | One blade is not enough. Borrow another from the sect's rack. | Take a new weapon |
| QR2 | Build | Build up your peak. A finer home makes meditation stronger. | Place one build piece |
| state | Bottleneck | Your art is stuck. Sit and spend stones to break it. | Break your art's bottleneck |
| state | RootPill, Method | (rare finds, from QC5) | Absorb the root pill; Gain a cultivation method |

- **Seclusion waits for the second session:** offered on the first sit after a join
  that began at QC4 or later (Home claimed first), or at QC5 for a player who never
  rejoins. The first one ends by itself after 45 s (`Pacing.Seclusion.FIRST_SECONDS`,
  30-60 s) with a generous card; [seclusion](seclusion.md).
- **QC5 is one idea:** the Ruined Borderlands open (their array's line is on the
  breakthrough card) and their hidden caches (no guide: finding it is the point). The
  sect board is no longer a lesson; the elder's Talk for Rumours points at it, and its
  Read prompt opens the [sect](sect.md) board from QC5.
- **The foundation** gets one line on the QC4 -> QC5 breakthrough card, the first card
  that carries it ("New beasts and herbs deepen your foundation.",
  `BreakthroughView.FOUNDATION_LINE`).
- **The hook plays only the Maze** (`Circulation.pickGame`: below QC4 it's always
  `FIRST_RUN_GAME`); the other games are met from QC4 on.
- A lesson's line waits 20 s into free play (`LESSON_DELAY`), so Home doesn't land on
  FreePlay's own line.

**The party shelter has no lesson:** the sect board's bonus quests (Escort a Junior,
Seek a Senior, [sect](sect.md)) teach it by doing it, only when a partner of the right
major is on the server; taking one opens People. The solo teaching moment (one elder
line and an NPC junior to escort) is deferred with the NPC escort ([roadmap](../roadmap.md) 3e).

**Lines (user, 2026-10-24):** the elder line is the why, at most 12 words; the
objective is the what, at most 5 words (verb + noun; the reward rides after it); the
detail goes in Talk. Reading age 8-10, the elder's warm voice. Beats follow the same
rule.

**The wall card** (`wallCard`): in free play, when no lesson shown this session and no
tracked sect quest has the line, the objective line says what to do now, one verb per
state, from the guides' own checks: **Break through** (bar full; a heaven-defier at a
major: Face the tribulation), **Store your haul** (an unbanked haul out in the wilds
below half health, `STORE_HEALTH`), **Hunt beasts (raw qi / a run's worth)** (too
little raw qi for a run, `Circulation.enoughQi` and `qiForRun`), else **Refine your
qi (cultivation / bar)**. At the last stage or a method's limit it falls back on the
quest board's top goal. It is text only, with no guide.

### Beats and lessons (built)
- Beats are kept **by id** in `data.beats` (schema v8; v7's position count is
  migrated), so beats can be inserted or reordered. `travel = true` marks the
  beat from which the formation is taught (FirstKill).
- **Lessons** (`Quests.Lessons`, `data.lessons`), in priority order: RootPill
  (first, so no standing lesson can hide it), Home
  (QC4, nothing planted: walk to your garden), Seclusion (the second session, see
  above: home, sit, the Method tile reading Seclusion, Enter Seclusion), Rumours (QC5,
  no guide), Herbs (QC6), DaoPractice (QC7, until a drill is done), HeartDemon (QC9,
  the Qi Condensation trial unfaced: sit, and the seat offers it; nothing while a
  "Not now" snoozes it), Bottleneck, WeaponRack (QR1, a single weapon class: the Main
  Peak rack), Build (QR2, nothing placed: home, then the Build tile), Method. In free
  play, the first lesson whose condition holds says
  its elder line once ever (`QuestState.lesson`), and its guide shows for the
  rest of that session while the condition still holds (`persist`: every
  session until done). A lesson's `objective` replaces the objective line
  while its guide shows and it's unclaimed, and an open, unclaimed lesson shown this
  session holds it after; in a later session it leaves the line to the wall card and
  waits in the elder's Talk (see "Rewarded objectives").
- **Root pill (decided 2026-10-21):** a tested root plus a pill that can act
  (a Root Rebirth Pill, or a Marrow Washing Pill below the purest grade, and no
  reforming root waiting) brings the elder's line and a step-by-step guide:
  Cultivate ("Sit in meditation") -> the Spirit Root tile ("Open your Spirit
  Root") -> the pill's Absorb button on that page ("Absorb it to purify/reform
  your root"), each with the pointer and callout, the objective reading
  "Absorb the root pill". It ends for good once a pill
  is absorbed (the held count drops: `data.lessons.RootPillUsed`). It waits for
  free play **and QC5** with a pill actually held, never stepping in during the
  hook (user, 2026-10-23: "pill eating made no sense during onboarding. do not
  give me a heaven grade spirit root at the start"). Root pills are extremely
  rare boss and treasure drops and a grade takes several
  ([spirit root](../character/spirit-root.md)), so most players meet this long
  after the hook; the Studio test kit leaves them out
  (`Config.TestKit.SKIP_ITEMS`); admins give them from the F2 panel.
- **Guides** (`QuestState.guide`), computed per tick from where the player is
  and what they're doing: e.g. Circulate spotlights Cultivate (dim), then the
  seated Circulate tile; Root spotlights Travel -> Main Peak, then walks to the
  Testing Stone; Refine circulates where you stand if you can, else rides
  home from the sect or walks to the nearest qi node in the wilds. Climbing
  with too little raw qi for a run (`Circulation.enoughQi`, the same check
  the run's start makes) says meditate before the Breakthrough beat and hunt
  after it (`huntGuide`: ride to the Sect Gate from the sect, else the nearest
  beast). Any guide that rides somewhere (`travelTo`)
  uses the Travel button on sect ground, and out in the wilds, where that
  button is hidden, walks to the nearest array (`place = "Array"`) and points
  at the destination once its menu is open. Keys are listed at the top of
  `Quests.luau`.

### Talking to the elder (built 2026-10-23)
- His Talk prompt (`Workspace.Hub.Elder` `TalkPrompt`) opens the dialogue screen
  ([dialogue](../ui/dialogue.md)): speaker "Elder Qingyun", portrait `elder_qingyun`,
  2-4 short lines, then responses: the player's reply (lit, closes), "What should I aim
  for next?" in free play (opens the quest board) and "Farewell." (cancel).
- What he says (`conversation` in `Quests.luau`): the current beat's `talk`; in free
  play the guiding lesson's (or the first open one's) while unclaimed, then once ever
  FreePlay's `talk`, which names the loop ("Cultivate until you hit a wall. Go out and
  break it. Come home stronger."; marked `data.lessons.Loop`), then the top quest
  board goal ("Your next step: <name>." and its detail).
- Lines live on each quest def as `talk = { lines = {...}, reply = "..." }`, beside its
  `elder` one-liner. Adding a beat's or lesson's conversation is that one entry; a quest
  without one falls back on its `elder` line. Keep it to one new idea, said once, short
  enough for a phone (about 90 characters a line).
- The auto-shown one-liner (`ElderLine`, or `Guide.Callout` beside a spotlight) is kept
  as it was: it fires on its own when a beat or lesson begins and never blocks; the
  conversation is only for when the player walks up and talks. Talking no longer
  re-shows the one-liner (the old `repeatElder`), and free play's toast is gone.
- The loop is also FreePlay's auto one-liner (since the hook rework), so a player who
  never talks to him still hears it once.

### Rewarded objectives (decided 2026-10-21)
- **The objective line is the onboarding for now.** Every beat and lesson is a
  rewarded objective, claimed once per profile: finishing it pays a small
  reward (mostly Spirit Stones; raw qi for bigger moments), with a
  toast ("Objective complete: Plant a seed! +30 Spirit Stones"),
  the stones' floating number and the Pickup sound, and the Rewards feed. The
  tracker shows the reward after the objective ("Plant a seed · Reward: 30 Spirit
  Stones"; an icon and number once the tracker supports it).
- **An actual questing system is the intended direction.** Beats and lessons
  are already quest-shaped defs (`Quests.Quest`: `id`, `elder`, `objective`,
  `progress`, `done`, `reward`, `guide`; lessons add `when`, `open`, `early`,
  `persist`), and claimed state is kept by quest id in `data.quests` (schema
  v9), never by position, so a quest log, givers, chains and dailies can load
  the same defs and share the claim path.
- **What each one asks** (`done`; a lesson's objective applies while `open`,
  by default its `when`): the beats as above; RootPill: a pill absorbed;
  Home (from QC4): a herb planted; Seclusion (once offered, or found alone): the first
  seclusion finished (`data.seclusion.first`); Rumours (from QC5): a world cache
  claimed (not a `rack:` one); Herbs (from QC6): a herb eaten (`data.lessons.HerbEaten`,
  set in `Inventory.use`); DaoPractice (from QC7): a Practice Dao drill finished
  (`daoPracticeReadyUnix` set); HeartDemon (from QC9): the Qi Condensation trial faced
  (`data.heartDemon.trials`); Bottleneck (while a technique is bottlenecked): a
  technique comprehended past its first bottleneck; WeaponRack (from QR1): a weapon of
  a second class; Build (from QR2): a piece placed (`data.stats.placed`); Method: a
  cultivation method gained (claimed the moment it's given).
- **Claiming** is server-side in `Quests.check`: a beat when it's passed, a
  lesson when its objective is done while it applies (so planting before QC4
  pays at QC4). `claim` marks `data.quests[id]` before granting, so nothing
  pays twice. Raw qi only fills the room left in the dantian.
- **Objective line priority:** a guiding lesson's objective while unclaimed
  (what its guide points at) -> the current
  beat -> a tracked sect quest -> the first unclaimed open lesson shown this session
  -> the wall card -> the top quest board goal.
- **Rewards** are all in `Pacing.Quests` (the comment there sizes them
  against the early economy): the ten beats pay 85 stones in all (about 19
  wolf kills) plus a fifth of a dantian of raw qi at Cast and a quarter at QC3;
  lessons pay 20-50; a
  cultivation method pays 150.
- **Open questions** for the questing system: where quests come from (givers
  around the sect, the quest board, or auto-offered as now); dailies and
  repeatables (what resets, and what they pay without inflating stones);
  chains per zone and per realm (a region's quests leading into its
  exploring spots and its boss).

## Key files
- `src/server/Quests.luau`: the `Quest` def type, `Beats`, `Lessons`, guides,
  claiming and granting objective rewards (`claim`, `rewardText`, `onClaimed`),
  `goals` (quest board), `travelUnlocked`, elder and board prompts in `Workspace.Hub`.
- `src/shared/Pacing.luau` `Quests`: each objective's reward, by id.
- `src/shared/Gates.luau`: the arrays (ids, names, realm gate, standing range;
  tag `TravelGate` + attribute `Gate` in the place).
- `src/server/Travel.luau`: where you may travel from (sect ground, an array, the
  Sect Gate for the wilds), destinations, realm gate, cooldown,
  combat block, streaming the destination in; `Travel.arrival` for respawns.
- `src/client/Onboarding.luau`: objective tracker (with "· Reward: ..." after a
  rewarded objective), elder line, the elder's conversation (`Dialogue.open`), quest
  board window;
  hands `QuestState.guide` to `Guide`.
- `src/client/Guide.luau`: shows the guide. Button keys map to HUD controls in
  one table (`BUTTONS`), resolved every frame since seated tiles come and go;
  in-window keys (`INSIDE`) find the open window's control by its `GuideKey`
  attribute; a non-dim button pulses, and with `point` gets the pointer and
  callout too. With `dim`, `Hud.Guide.Dim` lays a gentle ink
  veil (a soft-edged `Hole` around the control plus four side frames), every
  other HUD control turns non-interactable (touch Jump and Dash excepted; the
  veil itself sinks no input, so walking and the camera work), and
  `Guide.Callout` carries the elder's line beside it. It lifts when the control
  is pressed or the guide changes, and never shows in combat (the player's
  `InCombat` attribute: hurt or hitting within `IN_COMBAT_SECONDS`), in the calm view or over a window the
  target isn't in. Travel + `to` moves to the destination button once the menu
  is open (dim or not). `place` resolves to the nearest target every second
  (`Garden` = your own peak's HerbPlots, `WeaponRack`, `QiNode`, living
  `Enemy` (`Hitbox.alive`: the Health attribute, enemies have no Humanoid),
  `Array` (nearest of any kind), `Array:<id>`, Hub pieces) and shows the guide
  visuals below (`GuideFX`), `Hud.GuideMarker` bobbing over it and
  `Guide.Arrow` at the screen edge while it's off screen; all hide within 8 studs
  and while a window is open.

### Guide visuals (built, `GuideFX.luau`, `Effects.Guide`)
Intent: the sect's qi shows a newcomer the way, calmly (no screen flash, no
darkening, no loud pulse). Job: telegraph "walk here", then confirm "you're
here". Template built by `tools/vfx_specs/Guide.luau`; this client only.
- **Path** (hero: `Stream`): flat jade beams along the ground, one per 4-stud
  ground sample from 2.5 studs ahead of the feet to the circle's edge (at most
  28 studs). Each sample is raycast onto the ground (characters, bodies with a
  Humanoid and near-invisible parts skipped), so it follows slopes and steps; a
  gap whose ends differ by more than 0.5 studs gets a sample between, and a
  drop over 10 studs (a cliff) or no ground ends it. The qi texture scrolls
  toward the target; it fades in at the feet and out at the end, over a wider
  unlit ink `Bed` so it reads on grass at noon. `Drift` motes (9 a second) run
  ahead along it at 11 studs/s, on a loop. Re-sampled when the player moves
  0.75 studs or every 0.2 s.
- **Marker** (hero: the formation): at the target's foot (ground raycast under
  its bounding box, pivot upright), a rune ring with eight spokes turning slowly
  over a counter-turning fret ring (`SurfaceGui` images on a flat carrier),
  sized to the footprint plus 3 studs (radius 3 to 9; the Testing Stone's is
  6.9), a faint camera-facing light column (~17 studs) for reading it from afar
  and a few rising motes (3.5 a second).
- **Arrival** (once per guide, on first coming within 8 studs): the formation
  flares on frame 1 at its own size and lifts away (`Seal`, 0.75 s), a soft
  ring of light runs out over the ground (+60 ms, 0.7 s) and 12 motes lift off
  the circle (+120 ms, up to 1.6 s), with a soft crystal chime
  (`SFX.GuideArrive`, library 131722051883127). Then the marker is gone.
- **Enemy guides** show the path only: no circle, column or flourish under a
  beast (it's a fight, and they would sit on it).
- Budget: 7 stream + 7 bed beams (up to 14 each with split gaps), 2 small
  emitters on loop, 3 bursts (1 + 1 + 12) on arrival; no lights, no parts that
  collide or query. `Hud.GuideTrail` (the old soft beam) is no longer used.
- `src/client/TravelMenu.luau`: offers Travel on the contextual tile on sect ground and at arrays (`ContextTile`), clones
  `Hud.TravelPrompt` onto every array (it opens the menu), binds every
  button under List named after a gate id (grouped in `List.Sect` / `List.Wilds`),
  hides the array you're on, greys out realm-gated arrays the player hasn't
  reached (Detail shows the realm, a cinnabar Seal marks locked; a tap only
  toasts why), greys out the wilds arrays away from the Sect Gate, and runs the trip under the `Veil` fade.
- `src/client/GateMarkers.luau`: a seal and name over each array (`Hud.GateMarker`)
  once travel is taught; `src/client/Veil.luau`: the travel fade (`StarterGui.Veil`).
- Analytics: each beat is an onboarding funnel step (`Analytics.beat`: beat position + 4, after the Joined, Creator opened, Enter World and First sit steps; [data](data.md)); each lesson logs the custom event `Lesson` (lesson id; `shown` when its line first fires, `claimed` when its objective pays).
- Front door (user, 2026-10-24, from [first-session review](../design-reviews/first-session.md) rec 1): join to the world in about 20 s. A new account (no character) skips the slot screen and opens on one page: the free Fate reveal (race with its rarity, clan), a drawn cultivator name to keep or redraw, and a big Enter World; the look is a preset, changed later through Edit look. Timeline: join, the veil lifts on the page (about 2-5 s with the server's draw), read the fate and keep the name (about 5-10 s), Enter World, the character spawns (about 2-5 s). `TimeToEnterWorld` measures it ([data](data.md)). Untimed in play so far.

## Data flow
Every second `Quests.check` marks met beats in `data.beats`, claims done
objectives in `data.quests` (granting their rewards: `Effect` "stones", "qi"
and a `Notify` toast) and pushes
`QuestState` `{ step, beat, elder, objective, reward, travel, goals, guide, lesson }`
(only when something visible changed, or a lesson fires); the elder's Talk sends
`{ talk = { lines, reply, board } }` and the board's Read `{ openBoard = true }` (before
QC5; from QC5 the sect's `{ sect, open }`, [sect](sect.md); a tracked sect quest takes the
objective line in free play before the open lessons); Onboarding passes `travel`
to `TravelMenu.setTaught`. `TravelAction(gateId)` checks unlock, where you
stand (sect ground or an array; the Sect Gate's or a wilds array for the wilds), the realm gate, combat and cooldown, streams the destination in,
then pivots the character onto that array.

## Tuning knobs
- Beat text (`elder`, `talk`, `objective`) and conditions in `Quests.Beats`, lessons'
  in `Quests.Lessons`; goals in `Quests.goals`.
- `Gates.List`, `Gates.RANGE`; `Config.Travel`: `SECT_GATE` (FirstKill's "at the gate" check),
  `COOLDOWN`; `Config.Spawn.HEIGHT` (arrival height above an array).
- Rewards shown on the board come from `Pacing.Rewards`; objective rewards
  from `Pacing.Quests` (stones, `qiShare` of the dantian).

## Known gaps
- The beats and lessons are the only `Quests.luau` quests; the sect's dailies, the
  Borderlands chain, bonus quests and the quest log live in [sect](sect.md) (see
  "Rewarded objectives" for the open questions).
- The objective's reward shares the tracker's one text line (scaled 9-14 px),
  so long objectives shrink; a separate reward line in `Hud.Objective` is UI
  work for the ui-designer.
- Method's objective can't wait for the Self card to be opened (the server
  doesn't know), so it pays as the method is given.
- The wall card's Store state reads health and the haul only; it doesn't know about
  a fight in progress, and it has no icon yet (text only, like the rest of the line).
- Only the Maze is taught: the other circulation games (from QC4) and the Practice
  Dao drill's game have no lesson of their own yet (one per breather is the plan).
- Seclusion's "second session" is kept in memory (the stage a session began at), so a
  server hop at QC4 counts as a new session.
- Analytics funnel steps are beat positions, so inserting a beat shifts the
  step numbers after it (compare funnels across versions with care). The hook
  rework and the front-door steps (2026-10-23, then 2026-10-24 when the
  creator became one page) renumbered them (`Analytics` FUNNEL_NAMES).
- The Store beat has no button to point at (the Store all control is the
  `store-all` branch's); its guide walks to an array, and on sect ground shows nothing.
- In the testbed, Home (QC4) can't be done (no herb plots), so its guide holds the
  rest of the session; a second player there has no peak to refine on.
- Rumours has no guide, by design; a cache taken before QC5 pays at QC5. The old
  Board and Wall lessons are gone: a profile that claimed them keeps the flag, unused.

## Sources
- Roblox Creator Docs, [Onboarding](https://create.roblox.com/docs/production/game-design/onboarding)
  and [Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md).
- DevForum, [Improving Onboarding through Funnel Events](https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458).
- RoLearn, [First week retention optimization](https://rolearn.dev/guidance/first-week-retention-optimization)
  (third-party benchmarks: below 20% D1 is critical, 30-40% good; unverified).
