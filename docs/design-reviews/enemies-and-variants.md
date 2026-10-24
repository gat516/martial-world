# Design review: enemies, realm variants, bosses, spawn zones

**Verdict: keep with changes.** The fights are designed with care, and variants are the right cheap way to fill 27 stages. The problem is that almost none of it is live. Players get wolves and boars while ten beasts and bosses wait in the testbed.

## Why it exists / arrow
- Beasts are "out: hunt": the source of raw qi, stones, Dao and drops (`enemies.md` Purpose). Variants exist so the existing roster fills QC1 to FE9 (roadmap 8). The arrow is direct.

## Who it's for
- Kid: readable beasts ("a beginner mob plays like one"), young wolves at the gate, danger names on the bar. Hardcore: elites and apexes unlock follow-up chains, so they learn new patterns, not just bigger numbers. Social: bosses as meeting points with shared credit (party).

## Is it fun?
- Good: **windups never shorten by tier; higher tiers add tells and combos** (`enemies.md` Realm variants). That is fun as learning, and it stays fair to phones. It is the best rule in this doc.
- Good: per-beast design (packs circling, howls, hops back) makes each fight its own puzzle. Telegraph rules ("every movement ends in a blow", "ranged bosses make their own range") are strong.
- Risk: three beast types stretched by tint and size across QC (~2.5 h) becomes reskin fatigue, unless the per-tier extra moves (art pending) ship.

## Cost
- **Shipped:** Spirit Wolf, Stone Boar, plus the Borderlands serpent zones and the old Elder Wolf King. **Testbed only:** Serpent, Tortoise, Shadow Mane, Centipede, Raven, Bat, four reworked bosses, and `VARIANTS` itself (`Config.Wilds.VARIANTS`, roster table). Content sitting in the testbed is worth zero D7. Roblox charts reward weekly beats.
- New words on screen: "Young/Elite/Apex" plus the danger tier ("below/far/deadly"). Both are icons-plus-word on the bar, which is acceptable. Long names ("Apex Shadow Mane Wolf") on a 150 px billboard are untested on a phone.

## Failure and abuse
- **Farming exploit, documented and unfixed:** summoned wolves "pay full rewards… a player who leaves and re-engages a lone wolf can farm up to 3 extra wolves per howl" (`spirit-wolf.md`). With elite x1.6 and apex x2.4 rewards, that loop becomes the dominant farm.
- Boss tiers are undecided against principle 1 ("no difficulty modes"; Known gaps). Leaving it open blocks boss work.
- Suppression of 0.2x per major makes a QC player in the Outer Wastes (all apex, QR1-3) nearly unable to scratch anything. That's correct as a wall only if the bar says so before engaging. It does ("far/deadly"), so keep it.

## Metrics
- Variants plus first-kill-per-tier Hunt experiences (`hunt:<id>:<tier>@<band>`) are a ready collection. Nothing displays it, so the long tail is invisible.
- Bosses: optional is right. Boss counts double for foundation, and the Peak manuals also sit in caches, so nobody is barred.

## Recommendations (ranked)
1. **Ship what's built.** Turn `VARIANTS` on in main and promote the second wave (Serpent, Tortoise, Shadow Mane) after one playtest each. One beast or boss a week is an update cadence that needs no new art.
2. **Close the howl farm.** Summoned (`fleeting`) beasts give qi but no stones or drops, or a howler summons once per its life. One field in the reward path.
3. **A Bestiary page** (mirror the Herbarium): each beast x tier as a silhouette until killed, with a stones bonus per completed row. It reuses the Hunt experiences that already exist and is the cheap long tail the research calls for.
4. **Decide boss tiers as world variants, not modes.** A rarer "corrupted" boss spawns as a world event: darker palette, heavier vfx, one extra follow-up. It keeps principle 1, creates a meeting point and carries an update thumbnail. My pick over a difficulty menu.
5. Phone-check variant names on the bar and drop the tier word if it truncates (the tint already says it).
