# Onboarding, quests and travel

## Purpose
Teach one system at a time in the first ten minutes, then hand players a quest
board of next goals. Teleport formations move players between their peak, the
main peak, the sect gate and the wilds arrays (see [map](map.md), "World structure").

## Design intent
- Never blocking: beats advance on conditions checked every second, and players
  already past one skip straight through.
- The elder speaks one line per beat; an objective line and a pulse on the right
  button show what to do.
- Beats: Circulate -> Breakthrough -> Root (travel unlocks here: ride to the
  Main Peak and touch the Testing Stone, see [character](character.md)) -> Gate -> FirstKill ->
  Technique (3 kills, done once the 3-kill milestone's manual is earned) -> Refine
  (done once a run is finished, or when the bar is already full, since a full
  bar can't take a run) -> QC3 -> FreePlay (the top quest-board goal).
- A beat can show progress after its objective (`progress`, e.g. Technique's
  kills "(1/3)").
- Travel can't be used to flee a fight (blocked while in combat or mid-action).
- In the sect, travel works from anywhere: the Travel button shows on the sect's
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
(`Analytics.funnel`, one step per beat) shows where players leave.

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
   - `place`: a path to walk (a soft trail of light on the ground plus an
     edge-of-screen arrow when it's off screen) to the target.
   - The elder's line sits beside the spotlight; one line, auto-hides.
3. **Fewer steps to the first fight.** Measure time-to-first-kill in the funnel;
   cut anything between the root reveal and the wilds that isn't fun.
4. **Celebrate the highs:** the root reveal, the first breakthrough and the
   first technique are the moments to ask players to favourite the game.

**The first session (decided 2026-10-21):** own peak -> one short, forgiving
circulation -> an instant, celebrated breakthrough -> travel (spotlit) to the
Testing Stone -> **the root reveal, the hook**, then the game asks once to be
favourited (`RootReveal`, `AvatarEditorService:PromptSetFavorite`, 1.5 s after
the card closes) -> "Spirit wolves prowl just past the Sect Gate. Go!" with
Travel -> Sect Gate spotlit -> first kill -> a technique -> refine (once the
dantian is actually full) -> QC3 -> free play. Home (garden and peak, QC4) and
the weapon rack (QC7) are lessons, not beats. Still to do here: timing the funnel
to the first kill.

### Beats and lessons (built)
- Beats are kept **by id** in `data.beats` (schema v8; v7's position count is
  migrated), so beats can be inserted or reordered. `travel = true` marks the
  beat from which the formation is taught (Root).
- **Lessons** (`Quests.Lessons`, `data.lessons`), in priority order: RootPill
  (first, so a standing lesson like DaoPractice can't hide it), Home
  (QC4, nothing planted: walk to your garden), Bottleneck, WeaponRack (QC7, a
  single weapon class: the Main Peak rack), DaoPractice (QC7), Method. In free
  play, the first lesson whose condition holds says
  its elder line once ever (`QuestState.lesson`), and its guide shows for the
  rest of that session while the condition still holds (`persist`: every
  session until done). A lesson's `objective` replaces the objective line
  while its guide shows.
- **Root pill (decided 2026-10-21):** a tested root plus a pill that can act
  (a Root Rebirth Pill, or a Marrow Washing Pill below the purest grade, and no
  reforming root waiting) brings the elder's line and a step-by-step guide:
  Cultivate ("Sit in meditation") -> the Spirit Root tile ("Open your Spirit
  Root") -> the pill's Absorb button on that page ("Absorb it to purify/reform
  your root"), each with the pointer and callout, the objective reading
  "Meditate, open Spirit Root and absorb the pill". It ends for good once a pill
  is absorbed (the held count drops: `data.lessons.RootPillUsed`). Pills drop
  from early wolves, so it is `early`: it doesn't wait for free play, but steps
  in during the beats only **between steps**: on the sect's safe ground (no
  fights there), while the beat's own guide isn't a spotlight (`dim`: the hook
  steps, a full bar's Break Through), and it only takes the guide while the
  player isn't seated (a seat is usually a beat's step under way). Once it has
  the guide it keeps it, seated or not, until one of those stops holding;
  then the beat resumes. No veil (`dim` stays for the first-session hook beats
  only); the pointer is the stronger-than-a-pulse indicator.
- **Guides** (`QuestState.guide`), computed per tick from where the player is
  and what they're doing: e.g. Circulate spotlights Cultivate (dim), then the
  seated Circulate tile; Root spotlights Travel -> Main Peak, then walks to the
  Testing Stone; Refine circulates where you stand if you can, else rides
  home from the sect or walks to the nearest qi node in the wilds. Climbing
  with too little raw qi for a run (`Circulation.enoughQi`, the same check
  the run's start makes) says meditate before the Breakthrough beat (passive
  cultivation fills the rest; travel isn't taught yet) and go out to the Sect
  Gate or a qi node after it. Any guide that rides somewhere (`travelTo`)
  uses the Travel button on sect ground, and out in the wilds, where that
  button is hidden, walks to the nearest array (`place = "Array"`) and points
  at the destination once its menu is open. Keys are listed at the top of
  `Quests.luau`.

## Key files
- `src/server/Quests.luau`: `Beats`, `Lessons`, guides, `goals` (quest board),
  `travelUnlocked`, elder and board prompts in `Workspace.Hub`.
- `src/shared/Gates.luau`: the arrays (ids, names, realm gate, standing range;
  tag `TravelGate` + attribute `Gate` in the place).
- `src/server/Travel.luau`: where you may travel from (sect ground, an array, the
  Sect Gate for the wilds), destinations, realm gate, cooldown,
  combat block, streaming the destination in; `Travel.arrival` for respawns.
- `src/client/Onboarding.luau`: objective tracker, elder line, quest board window;
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
  is pressed or the guide changes, and never shows in combat (hurt within
  `Config.Combat.IN_COMBAT_SECONDS`), in the calm view or over a window the
  target isn't in. Travel + `to` moves to the destination button once the menu
  is open (dim or not). `place` resolves to the nearest target every second
  (`Garden` = your own peak's HerbPlots, `WeaponRack`, `QiNode`, living
  `Enemy` (`Hitbox.alive`: the Health attribute, enemies have no Humanoid),
  `Array` (nearest of any kind), `Array:<id>`, Hub pieces) and shows `Hud.GuideTrail`'s Beam from
  the hips toward it (at most 28 studs), `Hud.GuideMarker` bobbing over it and
  `Guide.Arrow` at the screen edge while it's off screen; all hide within 8 studs
  and while a window is open.
- `src/client/TravelMenu.luau`: shows the Travel button on sect ground, clones
  `Hud.TravelPrompt` onto every array (it opens the menu), binds every
  button under List named after a gate id (grouped in `List.Sect` / `List.Wilds`),
  hides the array you're on, greys out realm-gated arrays the player hasn't
  reached (Detail shows the realm, a cinnabar Seal marks locked; a tap only
  toasts why), greys out the wilds arrays away from the Sect Gate, and runs the trip under the `Veil` fade.
- `src/client/GateMarkers.luau`: a seal and name over each array (`Hud.GateMarker`)
  once travel is taught; `src/client/Veil.luau`: the travel fade (`StarterGui.Veil`).
- Analytics: each beat is an onboarding funnel step (`Analytics.funnel`).

## Data flow
Every second `Quests.check` marks met beats in `data.beats` and pushes
`QuestState` `{ step, beat, elder, objective, travel, goals, guide, lesson }`
(only when something visible changed, or a lesson fires); Onboarding passes `travel`
to `TravelMenu.setTaught`. `TravelAction(gateId)` checks unlock, where you
stand (sect ground or an array; the Sect Gate's or a wilds array for the wilds), the realm gate, combat and cooldown, streams the destination in,
then pivots the character onto that array.

## Tuning knobs
- Beat text and conditions in `Quests.Beats`; goals in `Quests.goals`.
- `Gates.List`, `Gates.RANGE`; `Config.Travel`: `SECT_GATE` (Gate beat check),
  `COOLDOWN`; `Config.Spawn.HEIGHT` (arrival height above an array).
- Rewards shown on the board come from `Pacing.Rewards`.

## Known gaps
- Analytics funnel steps are beat positions, so inserting a beat shifts the
  step numbers after it (compare funnels across versions with care).

## Sources
- Roblox Creator Docs, [Onboarding](https://create.roblox.com/docs/production/game-design/onboarding)
  and [Retention](https://create.roblox.com/docs/en-us/production/analytics/retention.md).
- DevForum, [Improving Onboarding through Funnel Events](https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458).
- RoLearn, [First week retention optimization](https://rolearn.dev/guidance/first-week-retention-optimization)
  (third-party benchmarks: below 20% D1 is critical, 30-40% good; unverified).
