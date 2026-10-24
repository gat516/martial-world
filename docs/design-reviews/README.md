# Design reviews

Red-team reviews by the `game-designer` agent (stern, independent; it proposes, the
owner decides). One file per feature; re-reviews overwrite. First pass 2026-10-23,
from docs and code only (nothing playtested).

| Review | Verdict |
|---|---|
| [first-session](first-session.md) | rework the front door; keep the hook with cuts |
| [onboarding-lessons](onboarding-lessons.md) | keep the system, rework the schedule |
| [pacing-and-realms](pacing-and-realms.md) | keep with changes |
| [breakthrough-and-foundation](breakthrough-and-foundation.md) | rework the feedback, keep the idea |
| [qi-surge](qi-surge.md) | rework or cut |
| [heart-demon](heart-demon.md) | keep with changes |
| [afk-seclusion-offline](afk-seclusion-offline.md) | keep with changes |
| [spirit-roots-and-pills](spirit-roots-and-pills.md) | keep with changes |
| [cultivation-minigames-and-meditation](cultivation-minigames-and-meditation.md) | keep for the hook, rework refining after QC |
| [combat](combat.md) | keep with changes |
| [techniques-and-dao](techniques-and-dao.md) | small rework; challenges the words-only hotbar |
| [enemies-and-variants](enemies-and-variants.md) | keep with changes |
| [haul-and-death](haul-and-death.md) | keep with changes |
| [world-events-and-exploration](world-events-and-exploration.md) | rework; challenges first-come events |
| [garden-and-herbarium](garden-and-herbarium.md) | keep with changes |
| [peak-building](peak-building.md) | keep with changes |
| [party-and-social](party-and-social.md) | keep with changes |
| [sect](sect.md) | keep with changes |
| [hud-and-menus](hud-and-menus.md) | rework the tile row |
| [retention-and-monetization](retention-and-monetization.md) | rework monetization; keep the retention base |

## Cross-cutting findings
- **Paid randomness:** Change Race (299 R$), Change Clan/Last Name (99 R$) are paid
  random rolls (race variants carry stats), offered before the first play, with no
  `PolicyService` check. Grow now (3-9 R$) buys progress on long herbs.
- **The front door:** 1.5-4 min of menus before the first action; the bounce window
  (0-180 s) is spent in the slot screen and creator.
- **Vocabulary and meters:** about 20 named numbers by FE; "qi" names seven things;
  foundation shown three ways. Fix by cutting, not building.
- **HUD:** about 12 persistent elements on a phone against ~5; cut the tile row to four
  before adding People, Seclusion or quest-log tiles.
- **Bugs against decisions:** QR7, FE4 and FE7 bars are smaller than the stage before
  ("bars never go down"); the first breakthrough is stamped "Unsteady 0%"; summoned
  wolves pay full rewards (a farm); leaving in combat on a phone disconnect loses half
  the haul; `haul.md` says spending eats the banked part first, the code does the
  opposite.
- **Co-play:** realm suppression stops friends of different majors fighting together;
  nothing calls `PromptGameInvite` or offers private servers (co-play days are a
  ranking signal).
