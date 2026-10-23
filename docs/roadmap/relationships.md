# Roadmap 3d: relationships (masters, disciples, sect siblings)

Part of the [roadmap](../roadmap.md), section 3d. Proposed 2026-10-22; the user decisions are marked.

The genre's heart, and a strong retention and social hook.
- **An NPC master at QR1 (Inner Disciple).** The player picks one of several peak
  lords or elders, each with a specialty (a weapon class, the garden, a
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
  the garden, a signature art) and has its own trial chain and gifts. Rules:
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
