# Design review: combat (M1, dodge, guard/parry, lock-on, telegraphs, touch)

**Verdict: keep with changes.** The defensive core is good. On a phone, though, the depth sits on the hardest buttons to press, and the basic hit has the least juice.

## Why it exists / arrow
- It is the "out: hunt" half of the loop (core-loop table). Every trip's raw qi, stones and Dao comes through it. It has no rival for the arrow.

## Who it's for
- Kid/casual: Auto mode (touch default, `Settings.luau:30` `autoAttack = true`) locks on, closes in and swings, so they only dodge and cast. Hardcore: perfect dodge (0.2 s, refunds 1.5 s of every cooldown), perfect parry (0.22 s), chain parries up to 6. Competence is well served. Autonomy comes from the weapon class.

## Is it fun? What carries it moment to moment
- The loop is telegraph read, dodge or parry, then punish. **Perfect dodge feeding cooldowns** is the best rule in the system: defence pays offence, which is a real decision. Keep it.
- The rhythm comes from telegraphs (one danger orange, a timing fill, a pulse at the last 0.25 s). But the new look ships only in the testbed (`NEW_TELEGRAPHS = TESTBED`). Live players still get the old red shapes that the doc itself calls clashing.
- **The basic hit is under-juiced.** An M1 landing gets a highlight flash, a sound, a number, Roblox's stock `sparkles_main.dds` and a 0.12 shake (`CombatController.luau:478-482, 766-769`). It has no hit-stop. Parries get a 0.05 s freeze and a punch (`guard-parry.md`), so the parry feels heavier than your own strikes. The M1 is the action players do most, and on phones juice is how they know a hit landed.

## Cost
- **Phone controls.** The cluster has Strike 70 px, plus Jump, Dash and Guard at 50 px, Lock and Surge. The 3 equipped arts sit on the bottom-centre hotbar at **35 px** (32 px in the words-only branch; `hud-vitals.md`). That is under the 44 pt floor and off the right thumb's arc. The skill expression (arts and their timing against perfect-dodge refunds) is the hardest thing to hit.
- **Auto on.** The biggest button (Strike, 70 px in the corner) does what Auto already does.
- Rules a player meets: M1 chain, dodge, perfect dodge, guard, guard break, perfect parry, chain parry, lock, combat qi, cooldowns, suppression. Onboarding teaches M1 and dodge only (`onboarding.md:87`). Guard and parry are never taught, so the phone Block button is an unexplained 50 px seal.

## Failure and abuse
- CC protection is solid: immunity and diminishing returns, so no stun-lock. That suits kids.
- Guard has known gaps: client-claimed raise time, and re-raising every `PARRY_RECOVER` keeps a parry window open about half the time. PvE only, so the risk is low.
- Untested on a phone and at real ping (combat.md and telegraphs.md Known gaps). Every judgement here about how it feels is from code and docs.

## Metrics
- First 60-180 s: a fight at ~2:00 is fine. What decides D1 for 72% of players is how the first fight *feels* on a phone, so hit juice and thumb reach are the levers.
- Instrumentation: none that I found for dodge or parry success, Auto on/off, or deaths per beast. Without it, tuning is blind.

## Interactions
- Three bars (health, qi, guard) plus a cooldown sweep is a lot to watch. The guard trough dims while full, which is right.
- The `InCombat` tag drives haul banking, travel, the surge and HUD folding. It's good to reuse one signal.

## Ranked recommendations
1. **Move the 3 equipped arts into the touch cluster.** Make them 54-60 px seals on an outer arc around Strike, using each art's colour and glyph with its cooldown sweep. On touch, the hotbar keeps items only. This is a replacement, not an addition: those 3 slots leave the hotbar. Brief: ui-designer.
2. **Give M1 a hit-stop and a real impact.** Freeze the attacker's clip for 40-60 ms on a landed swing (80 ms on the finisher), swap the stock sparkles for a library hit-spark per class, and scale the shake by step. Small client-only change in `CombatController`/`CombatEffects`. Brief: vfx.
3. **Ship `NEW_TELEGRAPHS` to main** after one phone check at 40 studs. Live players are fighting on the look the team already rejected.
4. **Teach guard once.** Add one elder line at the first boar charge: "Hold Block as it charges; raise it just before the hit to turn it aside."
5. **Log combat events:** perfect dodge, parry, guard break, death by beast, Auto on/off, as custom events.
6. While Auto is on, consider turning Strike into the "finisher" input (or shrinking it) so the biggest button earns its space.
