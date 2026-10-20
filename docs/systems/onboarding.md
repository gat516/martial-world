# Onboarding, quests and travel

## Purpose
Teach one system at a time in the first ten minutes, then hand players a quest
board of next goals. Teleport formations move players between their peak, the
main peak and the sect gate.

## Design intent
- Never blocking: beats advance on conditions checked every second, and players
  already past one skip straight through.
- The elder speaks one line per beat; an objective line and a pulse on the right
  button show what to do.
- Beats: Circulate -> Breakthrough -> Gate (travel unlocks here) -> FirstKill ->
  Technique (3 kills) -> Refine -> QC3 -> FreePlay (the top quest-board goal).
- Travel can't be used to flee a fight (blocked while in combat or mid-action).

## Key files
- `src/server/Quests.luau`: `Beats`, `goals` (quest board), `travelUnlocked`, elder
  and board prompts in `Workspace.Hub`.
- `src/server/Travel.luau`: destinations, cooldown, combat block.
- `src/client/Onboarding.luau`: objective tracker, elder line, quest board window.
- `src/client/TravelMenu.luau`.
- Analytics: each beat is an onboarding funnel step (`Analytics.funnel`).

## Data flow
Every second `Quests.check` advances `data.onboardingStep` and pushes
`QuestState` (only when something visible changed). `TravelAction(where)` checks
unlock, combat and cooldown, then pivots the character.

## Tuning knobs
- Beat text and conditions in `Quests.Beats`; goals in `Quests.goals`.
- `Config.Travel`: `MAIN_PEAK`, `SECT_GATE`, `COOLDOWN`; `Config.Spawn`.
- Rewards shown on the board come from `Pacing.Rewards`.

## Known gaps
- `GATE_BEAT` is an index asserted against the beat list; reordering beats needs care.
