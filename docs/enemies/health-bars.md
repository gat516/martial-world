# Enemy health bars (EnemyBars)

Part of [enemies](../systems/enemies.md). The overhead bar on regular beasts, its danger
tiers and omen lines; bosses use the [boss bar](../ui/boss-bars.md).

Regular beasts carry a `HealthBar` BillboardGui (Dead Cells layout in the
game's lacquer-and-seal dress): a dark ink nameplate strip with the beast's name
and realm tag (`QC 4`), sitting on a long thin bar whose right end is cut at 45 degrees. The
fill is blood-qi crimson, cut into ten talisman slips at the same 45 degrees (one per 10% of
health, the same count as the player's vitals bar; the divisions are drawn into
the rim art, so the slip size never depends on the beast's max health). A hit
drops the fill at once and a pale gold ghost (`Trail`) drains after it. The bar
shows while the beast is locked or for 8 s after it's hurt. The fill's slant
shows at full health; while draining, its leading edge is the `Fill` frame's
straight clip.

On tiers with an end gem (jade, gold, far) the gem is as tall as the bar and
set in the rim's metal, its upper-left face flush along the window's slant, so
the bar ends in the gem's point rather than running into it (user, 2026-10-23:
the old slant ran straight into the gem). The metal wedge under the gem fills
the rest of the end. Bronze keeps a bare slanted end.

Its dressing says how dangerous the beast is **to you**: the gap between the
beast's realm and the local player's (`Realms.index`, in ladder stages) picks a
tier from `Pacing.Danger`, re-picked live when the player's `Realm` changes, so
a breakthrough makes the same beast look tamer. Realm suppression overrides the
count: a beast one major realm up reads at least "far" (two majors: "deadly"), one a
major below reads "cowed" (it fears you: it won't hunt you, flinches as you arrive
and, two majors below, runs; [combat](../systems/combat.md#realm-pressure-owners-decision-2026-10-24)),
however few stages apart. While a stronger party member shelters you, a beast above
your major is read at the stage you fight it at (its own, capped at theirs), in the
usual tiers with no mark of its own. Bosses keep the five tiers below (BossThemes has
lines for them).

| Tier | Gap (default) | Look |
|---|---|---|
| below | <= -2 | muted bronze frame, grey tag |
| even | -1 to +1 | jade frame, vermilion gem capping the end |
| above | +2 to +3 | gold frame, gem end and lozenge cap on the left, omen line |
| far | +4 to +5 | violet frame, crimson gem drawn out into a talisman tip, pulsing qi aura, sheen sweep, omen line |
| deadly | >= +6 | no name, realm or health: a pulsing cracked skull seal and an omen, shown whenever the beast is in range (90 studs) |
| cowed | a major below you | the below frame and tag; on the omen row a gold down-chevron and "Cowed · it fears you" (the word bronze) |

Omen lines are short xianxia warnings under the bar (under the skull for
deadly), one picked at random per beast per tier so it never flickers; the pools
live in `STYLES` in `EnemyBars.luau` (keep lines under ~24 characters). Bosses
skip all of this: their overhead bar stays off and the boss you fight gets the
themed screen bar instead (`BossBars.luau`, see [boss bar](../ui/boss-bars.md)), dressed with the
same tiers and per-boss omen pools. Art: `art/ui/draw_ui.py enemybar` (`EB` geometry, `EB_TIERS`
colours), ids in `art/ui/assets.json` (`enemybar_*`); rims are set from `STYLES`, while
Back, Fill, Trail and Sheen ids live in every `HealthBar` in `assets/Enemies.rbxm`.
