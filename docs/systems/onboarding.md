# Onboarding, quests and travel

## Purpose
Teach one system at a time in the first ten minutes, then hand players a quest
board of next goals. Teleport formations move players between their peak, the
main peak, the sect gate and the wilds arrays, always from one array to another
(see [map](map.md), "World structure").

## Design intent
- Never blocking: beats advance on conditions checked every second, and players
  already past one skip straight through.
- The elder speaks one line per beat; an objective line and a pulse on the right
  button show what to do.
- Beats: Circulate -> Breakthrough -> Root (travel unlocks here: ride to the
  Main Peak and touch the Testing Stone, see [character](character.md)) -> Gate -> FirstKill ->
  Technique (3 kills) -> Refine -> QC3 -> FreePlay (the top quest-board goal).
- Travel can't be used to flee a fight (blocked while in combat or mid-action).
- Travel only works standing on a teleport array: the Travel button shows only
  there (and once taught), and arrivals and respawns land on arrays. Wilds arrays
  open by realm (`Gates.required`, from the region's `realm`).

## Key files
- `src/server/Quests.luau`: `Beats`, `goals` (quest board), `travelUnlocked`, elder
  and board prompts in `Workspace.Hub`.
- `src/shared/Gates.luau`: the arrays (ids, names, realm gate, standing range;
  tag `TravelGate` + attribute `Gate` in the place).
- `src/server/Travel.luau`: standing check, destinations, realm gate, cooldown,
  combat block, streaming the destination in; `Travel.arrival` for respawns.
- `src/client/Onboarding.luau`: objective tracker, elder line, quest board window.
- `src/client/TravelMenu.luau`: shows the Travel button on an array, binds every
  button under List named after a gate id (grouped in `List.Sect` / `List.Wilds`),
  hides the array you're on, greys out realm-gated arrays the player hasn't
  reached (Detail shows the realm, a cinnabar Seal marks locked; a tap only
  toasts why), and runs the trip under the `Veil` fade.
- `src/client/GateMarkers.luau`: a seal and name over each array (`Hud.GateMarker`)
  once travel is taught; `src/client/Veil.luau`: the travel fade (`StarterGui.Veil`).
- Analytics: each beat is an onboarding funnel step (`Analytics.funnel`).

## Data flow
Every second `Quests.check` advances `data.onboardingStep` and pushes
`QuestState` (only when something visible changed); Onboarding passes `travel`
to `TravelMenu.setTaught`. `TravelAction(gateId)` checks unlock, that you stand
on an array, the realm gate, combat and cooldown, streams the destination in,
then pivots the character onto that array.

## Tuning knobs
- Beat text and conditions in `Quests.Beats`; goals in `Quests.goals`.
- `Gates.List`, `Gates.RANGE`; `Config.Travel`: `SECT_GATE` (Gate beat check),
  `COOLDOWN`; `Config.Spawn.HEIGHT` (arrival height above an array).
- Rewards shown on the board come from `Pacing.Rewards`.

## Known gaps
- `TRAVEL_BEAT` is an index asserted against the beat list, and PlayerData's v5
  migration assumes Root is the 3rd beat; reordering beats needs care.
- Inserting Root shifted the analytics funnel's step numbers from 3 up.
