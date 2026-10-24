# Heart-demon trial

Built 2026-10-23 (Phase A, untuned, untested in play). An optional inner trial at
each major's stage 9 that asks how the player actually climbed, and tempers old
foundation percents ([cultivation](cultivation.md#foundation-grade)). The user's ask:
"have you mostly been gardening vs mostly fighting.. do you feel guilt at the
monsters youve killed etc. that would be REALLY good if u could temper old foundations."

Rules (roadmap Phase A, 9b item 2): choice-based, no reflexes, story over rules, kid-
and mobile-friendly; it never blocks a breakthrough and never costs a stage or
cultivation. Once per major; it can be declined and taken later.

## When it's offered
A trial opens for a major (Qi Condensation, Qi Refining, Foundation Establishment)
once the player reaches its stage 9; the lowest unfaced one is the open one
(`HeartDemon.open`). Both offers are from the meditation seat (client `HeartDemon.luau`):
- **Break Through at any stage 9** with a trial open (QC9, QR9) asks first, once a
  session: Face it first / Break through now / Not now. Facing it ends on "Break
  through." or "Stay seated a while." "Break through now" goes straight on; a second
  press in the session doesn't ask again. The server's breakthrough is untouched.
- **Sitting down** with a trial open (stage 9 or anywhere past it, FE9 at the peak)
  offers it 2.5 s after seating, once a session: Face it / Not now. "Not now" snoozes
  the seat offer for `OFFER_COOLDOWN` (20 h, `data.heartDemon.declined`).
- Closing the screen mid-trial records nothing; it can be faced again (a player who
  retakes it can learn which answers calm it, which is fine).

## The questions
Built on the server from the record (`HeartDemon.questions`), `QUESTIONS` (4) at most and
never fewer than 3, 2-3 answers each, shuffled. One answer per question is usually a
**denial** (the record contradicts it); every other answer is honest and calms the demon.
The demon's reply to each answer opens the next question.

**How they're picked.** The path is always first. Every record question below that has
something to say is a candidate with a **weight**, how loudly the record speaks: 1 at its
threshold, +1 per doubling past it (`weigh`), capped at `WEIGHT_CAP` (4), so 300 kills don't
drown out 3 surges. Rarer acts (danger, surges, spills, root pills) get +0.5; a full
Herbarium page +0.5 each; pride weighs 1, stillness one less than its doubling count. The
highest weights fill the remaining slots (ties keep the list order), one per group
(stillness and seclusion share "sit": only the louder is asked), and "why climb" fills in
when fewer than three are left. Fear or pride always qualifies, so every trial has at least
path, fear/pride and one more.

1. **The path**, always first: `kills` vs `harvests x HARVEST_WEIGHT`. Kill share at or
   above `HUNTER_SHARE` (0.65): "Is there nothing in you but the fight?" (denial: "I'm a
   gardener at heart."). At or below `GARDENER_SHARE` (0.35): "Were you hiding from the
   world?" (denial: "No, I fight every day."). Between: "Which road is truly yours?"
   (honest: both). Under `LEAN_MIN` (6) of either: the still road, "Were you waiting for
   the world to come to you?".
2. **The slain** (from `SLAIN_MIN` = 10 kills): the most-slain beast by name and count
   ("312 Spirit Wolves. Do their howls follow you?", an echo line per beast in
   `ECHOES`), the most-slain boss ("Even the Elder Wolf King fell to you."), then
   "What do you feel for them?": guilt, resolve (honest) or indifference (denial).
   Kills from before the per-beast counter show as a total.
3. **Danger sought** (elites + apexes x2 >= `DANGER_MIN` = 3, realm-variant tiers): "You
   went looking for the strongest: 4 elites and 1 apex beast. What were you hoping to
   find?" (denial: "I keep to easy prey.").
4. **Fear** (deaths >= 1): "You have fallen 3 times. Each time, you rose. Are you afraid
   to fall again?" (denial: "I'm never afraid."). No deaths: **pride**, "Do you think
   you can't?" (denial: "Nothing can touch me.").
5. **The qi surge** (surges + old forced breakthroughs >= `SURGE_MIN` = 1): "You burned
   your qi to survive 3 times, beaten and bleeding. Was it worth what it cost?" (denial:
   "I've never needed it.").
6. **The haul**, greed or caution ([haul](haul.md)). **Greed**: spills + mid-fight
   logouts >= `HAUL_LOST_MIN` (2) while lost x `HAUL_LOST_WEIGHT` (4) >= Store all uses:
   "Your haul spilled on the ground 3 times. You went back for it twice. Why carry so
   much, so far from home?" (denial: "I always bring it home."). **Caution**: Store all
   >= `HAUL_STORED_MIN` (5) and nothing ever lost: "You came home 12 times and stored every
   grain." (plus "Even your ring held..." with ring use) "Is caution all you have?"
   (denial: "I gamble it all.").
7. **The peak**, builder or wanderer ([build](build.md)). **Builder** (pieces placed >=
   `BUILD_MIN` = 10): "40 pieces set on your peak, one by one. Its score rose to 120. Are
   you building a home, or a wall?" (denial: "I don't care for my peak."). **Wanderer**
   (placed <= `WANDER_MAX` = 2, with `SLAIN_MIN` kills): "Your peak stands bare. Is
   anywhere home to you?" (denial: "My peak is my pride.").
8. **The Herbarium** (herbs discovered >= `HERB_MIN` = 5, read from `data.herbarium`):
   "14 of 30 herbs written in your book. One page full. What were you looking for?"
   (denial: "I never stopped to look.").
9. **Root pills** (washing + rebirth pills >= `ROOT_MIN` = 1,
   [spirit root](../character/spirit-root.md)): "You burned your marrow with 3 pills, and
   remade your root once. Were you not enough as you were?" (denial: "I'm content as I
   am.").
10. **Seclusion** (from `SECLUDED_MIN_HOURS` = 8 h in [seclusion](seclusion.md), online
    and offline): "You sat in seclusion for 40 hours. Were you hiding?" (gathering or
    "the world is loud", honest; denial: "I never shut myself away.").
11. **Stillness** (from `STILL_MIN_HOURS` = 0.5 h seated, seclusion not counted): "Were
    you searching, or only waiting?" (denial: "I hardly ever sit.").
12. **Why climb**, the filler: three honest answers.
13. **Company** (`partied`, seconds in a [party](party.md) with a member within 120
    studs): under `SOLITARY_MAX_MINUTES` (2) "You never walked with another. Do you trust
    no one?" (denial: "I always walk with friends."); from `COMPANY_MIN_MINUTES` (30)
    "... walking beside others. Did you lean on them?" (denial: "I've always walked
    alone."). Between: no question. Solitude weighs 1; company weighs by its minutes.
    From `Pacing.Shelter.HEART_LINE_AT` (3) kills under the party shelter the second
    line names it: "A stronger friend sheltered you. Did you lean on them?"
    (`stats.leaned`), else "You sheltered weaker friends. Did you lean on them, too?"
    (`stats.sheltered`).
14. **The sect** ([sect](sect.md)). **Duty** (`dailies` >= `DUTY_MIN` = 10): "You
    answered the sect's board 24 times. 900 contribution to your name. Do you serve the
    sect, or yourself?" (denial: "I walk alone."). **Lone wolf** (at most `LONE_MAX` = 1
    daily, the board read): "The sect's board called for you, day after day. You walked
    past it. Do you need no one?" (denial: "I serve the sect well."). Weight: duty its
    doubling count, lone wolf 1.
Answer labels stay at 27 characters or fewer so they fit the response buttons on a phone.
Heart notes are verb phrases ("remembered every beast you slew") so any second question
joins the path's line.

## Outcome
`HeartDemon.answer` counts denials. Steps = `max(TEMPER_ROUGH, TEMPER_CALM - denials)`
(3 with none, 2 with one, else 1). `Foundation.temper` raises that many old stages
25 points of foundation percent each, lowest first (ties: the earliest stage), never past 150%, never lowering any;
`applyStats` refreshes the Foundation bonus. No denials: "The demon was calmed." The
closing lines name what was tempered ("Qi Condensation 5 is now 125%, ...", the percent
only) or say there was nothing to temper ("You have no old foundations yet." /
"Your old foundations are all 150% or more.").

**Dao heart** ([titles](titles.md); design review rec 1): each path answer carries a
`title`, and the one chosen picks the trial's Dao-heart title (hunter: Heart of the
Blade, or Restless Blade for "I lost my peace out there"; gardener: Heart of the Lotus,
or Unhidden Heart for "Yes. It frightened me."; both roads: Two-Road Heart; the still
road: Heart of Stillness). A denial picks the road the record shows, so the title is
never a penalty. The closing lines end "Your Dao heart: <name>.", and the trial's
state push grants it. A calmed trial also grants Calm Heart.

Recorded in `data.heartDemon.trials[major]`: `{ calm, denials, tempered, note, at, title }`.
`note` is the heart line the player keeps, from the first two answers: "You walked the
blade's road, and remembered every beast you slew. The demon was calmed." Sent in
`PlayerState.heartDemon.trials`; the Self card's Heart demon section shows the latest
note and every trial's in its detail ([character window](../character/character-window.md)).

## Data
- `data.stats` counters the trial reads, all at 0 for old profiles through the
  missing-field defaults (no schema bump):
  - `slain` (kills by enemy id, `Progression.onKill`), `harvests` (`Garden.harvest`),
    `deaths` (Main's `Humanoid.Died`), `seated` (seconds meditating outside seclusion,
    Cultivation's tick), `secluded` (seconds in seclusion, online and offline,
    Seclusion.luau).
  - `forced`: forced breakthroughs, removed (nothing increments it now); old counts fold
    into the surge question. `surges` (`QiSurge.fire`).
  - Haul: `spills` (`Haul.died`, a death that took something), `reclaimed` (a spill
    walked back to), `fled` (`Haul.leaving` mid-fight with something spilled), `stored`
    (`Haul.storeAll` that banked something), `ringed` (stacks put in the spirit ring).
  - Peak: `placed` (Build "place"), `peakBest` (highest uncapped peak score,
    `Peaks.refreshScore`).
  - `elites`, `apexes` (variant tier of the kill, `Progression.onKill`).
  - `washed` (`Roots.wash`, Marrow Washing Pills), `rerolls` (`Roots.reroll`, Root
    Rebirth Pills).
  - The Herbarium needs no counter: discovered herbs and full pages are
    `data.herbarium.herbs` / `.tiers`.
  `secluded` (seconds in seclusion, online and offline, Seclusion.luau) and `partied`
- `data.heartDemon = { trials = {}, declined = {} }`.
- Remotes: `CultivationAction` "heartDemon" (start, seated only: `{ major, name,
  questions = { { lines, answers = { { text, reply } } } } }`, honesty stays on the
  server), "heartDemonAnswer" (one answer index per question -> `{ calm, lines, note,
  tempered }`), "heartDemonDecline". `PlayerState.heartDemon = { open, name, atPeak,
  snoozed, trials }`.

## Files
`src/server/HeartDemon.luau` (questions, outcome, state), `src/server/Foundation.luau`
(`temper`, `rank`), `src/client/HeartDemon.luau` (offers, the dialogue run), hooks in
Cultivation (seat check, refresh, `seated`), Circulation (actions), Meditation
(client: on seated, Break Through), Progression (slain, tiers), Garden, Main, QiSurge, Titles (the Dao heart),
Haul, Build, Peaks, Roots, Seclusion. Admin: F2 panel Player
chips "Realm QC9", "Realm QR9" and "Reset heart demons" (`heartReset`).

## Tuning
`Pacing.HeartDemon`: `QUESTIONS`, `TEMPER_CALM`, `TEMPER_ROUGH`, `HARVEST_WEIGHT`,
`HUNTER_SHARE`, `GARDENER_SHARE`, `LEAN_MIN`, `SLAIN_MIN`, `STILL_MIN_HOURS`, `SECLUDED_MIN_HOURS`,
`SURGE_MIN`, `DANGER_MIN`, `HAUL_LOST_MIN`, `HAUL_LOST_WEIGHT`, `HAUL_STORED_MIN`, `BUILD_MIN`,
`WANDER_MAX`, `HERB_MIN`, `ROOT_MIN`, `WEIGHT_CAP`, `OFFER_COOLDOWN`. Lines and answers are in `HeartDemon.luau`.

## Keeping it current
The trial is only as good as what it remembers (user, 2026-10-23: "when we add new
systems / mechanics the heart demon should be updated. this is important"). Every new
system that says something about how a player plays adds, in the same commit:
1. a counter in `data.stats` (missing-field defaults, no schema bump);
2. a question, or answers on an existing one, built from it in `HeartDemon.luau`,
   with one answer the record contradicts;
3. a line in "The questions" above, and a weight so the picker can rank it.
Open now: nothing (brought current 2026-10-23: surge, haul, peak, Herbarium, tiers, root
pills, seclusion, the sect's dailies).

## Known gaps
- **Later (user, 2026-10-23): a real heart-demon sequence.** Not only dialogue: a
  physical heart demon, e.g. a mirror copy of the player with red eyes, in its own
  short scene (inner-world space, the copy speaking the questions). Needs a
  designer brief, then vfx/animator; the dialogue flow stays the backbone.
- UI: the speaker uses the generic `unnamed` gray silhouette and the ruby name tab. A
  heart-demon silhouette of its own (uploaded and added to `Dialogue` `PORTRAITS`) and
  the crimson demon tab (Codex sheet A7) are ui-designer work. No sound or vfx cue.
- A cracked foundation doesn't make the trial harder (roadmap open question).
- Counters start at the commit that added them, so a veteran's first trial undercounts
  spills, surges, building and pills from before.
- Garden time is read as harvest count; hunting vs meditation income isn't tracked.
