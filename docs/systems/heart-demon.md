# Heart-demon trial

Built 2026-10-23 (Phase A, untuned, untested in play). An optional inner trial at
each major's stage 9 that asks how the player actually climbed, and tempers old
foundation grades ([cultivation](cultivation.md#foundation-grade)). The user's ask:
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
Built on the server from the record (`HeartDemon.questions`), up to `QUESTIONS` (4),
2-3 answers each, shuffled. One answer per question is usually a **denial** (the record
contradicts it); every other answer is honest and calms the demon. The demon's reply
to each answer opens the next question.
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
3. **Fear** (deaths >= 1): "You have fallen 3 times. Each time, you rose. Are you afraid
   to fall again?" (denial: "I'm never afraid."). No deaths: **pride**, "Do you think
   you can't?" (denial: "Nothing can touch me.").
4. **Forced breakthroughs** (>= 1): "Was it worth the debt?" (denial: "I've never rushed.").
5. **Seclusion** (from `SECLUDED_MIN_HOURS` = 8 h in [seclusion](seclusion.md), online
   and offline): "You sat in seclusion for 40 hours. Were you hiding?" (gathering or
   "the world is loud", honest; denial: "I never shut myself away.").
6. **Stillness** (from `STILL_MIN_HOURS` = 0.5 h seated, seclusion not counted): "Were
   you searching, or only waiting?" (denial: "I hardly ever sit.").
7. **Why climb**, the filler: three honest answers.
Order of preference after the path: slain, fear/pride, forced, seclusion, stillness, why climb.
Answer labels stay at 27 characters or fewer so they fit the response buttons on a phone.

## Outcome
`HeartDemon.answer` counts denials. Steps = `max(TEMPER_ROUGH, TEMPER_CALM - denials)`
(3 with none, 2 with one, else 1). `Foundation.temper` raises that many old grades one
step each, lowest first (ties: the earliest stage), never past Deep, never lowering any;
`applyStats` refreshes the Foundation bonus. No denials: "The demon was calmed." The
closing lines name what was tempered ("Qi Condensation 2 is now Steady, ...") or say
there was nothing to temper.

Recorded in `data.heartDemon.trials[major]`: `{ calm, denials, tempered, note, at }`.
`note` is the heart line the player keeps, from the first two answers: "You walked the
blade's road, and remembered every beast you slew. The demon was calmed." Sent in
`PlayerState.heartDemon.trials` for the Self card (not shown yet).

## Data
- `data.stats` gained `slain` (kills by enemy id, `Progression.onKill`), `harvests`
  (`Garden.harvest`), `deaths` (Main's `Humanoid.Died`), `seated` (seconds meditating
  outside seclusion, Cultivation's tick), `forced` (forced breakthroughs) and
  `secluded` (seconds in seclusion, online and offline, Seclusion.luau). Old profiles get them at 0
  through the missing-field defaults (no schema bump).
- `data.heartDemon = { trials = {}, declined = {} }`.
- Remotes: `CultivationAction` "heartDemon" (start, seated only: `{ major, name,
  questions = { { lines, answers = { { text, reply } } } } }`, honesty stays on the
  server), "heartDemonAnswer" (one answer index per question -> `{ calm, lines, note,
  tempered }`), "heartDemonDecline". `PlayerState.heartDemon = { open, name, atPeak,
  snoozed, trials }`.

## Files
`src/server/HeartDemon.luau` (questions, outcome, state), `src/server/Foundation.luau`
(`temper`, `rank`), `src/client/HeartDemon.luau` (offers, the dialogue run), hooks in
Cultivation (seat check, refresh, `seated`, `forced`), Circulation (actions), Meditation
(client: on seated, Break Through), Progression, Garden, Main. Admin: F2 panel Player
chips "Realm QC9", "Realm QR9" and "Reset heart demons" (`heartReset`).

## Tuning
`Pacing.HeartDemon`: `QUESTIONS`, `TEMPER_CALM`, `TEMPER_ROUGH`, `HARVEST_WEIGHT`,
`HUNTER_SHARE`, `GARDENER_SHARE`, `LEAN_MIN`, `SLAIN_MIN`, `STILL_MIN_HOURS`, `SECLUDED_MIN_HOURS`,
`OFFER_COOLDOWN`. Lines and answers are in `HeartDemon.luau`.

## Keeping it current
The trial is only as good as what it remembers (user, 2026-10-23: "when we add new
systems / mechanics the heart demon should be updated. this is important"). Every new
system that says something about how a player plays adds, in the same commit:
1. a counter in `data.stats` (missing-field defaults, no schema bump);
2. a question, or answers on an existing one, built from it in `HeartDemon.luau`,
   with one answer the record contradicts;
3. a line in "The questions" above.
Open now: the qi surge (`forced` still counts the removed forced breakthrough, so
surges should count there or get their own question), deaths that spilled a haul,
Store all, peak building and the Herbarium.

## Known gaps
- **Later (user, 2026-10-23): a real heart-demon sequence.** Not only dialogue: a
  physical heart demon, e.g. a mirror copy of the player with red eyes, in its own
  short scene (inner-world space, the copy speaking the questions). Needs a
  designer brief, then vfx/animator; the dialogue flow stays the backbone.
- UI: the speaker uses the generic `unnamed` gray silhouette and the ruby name tab. A
  heart-demon silhouette of its own (uploaded and added to `Dialogue` `PORTRAITS`) and
  the crimson demon tab (Codex sheet A7) are ui-designer work. No sound or vfx cue.
- The Self card doesn't show the heart notes yet.
- A cracked foundation doesn't make the trial harder (roadmap open question); qi surges
  aren't asked about yet (the surge isn't on this branch).
- Garden time is read as harvest count; hunting vs meditation income isn't tracked.
