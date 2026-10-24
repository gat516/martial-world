# Design review: techniques and the Dao ladder

**Verdict: rework (small).** Gating learning on Dao and keeping found manuals are right. Comprehension stacks four conditions, the first boss's reward is usually dead on arrival, and techniques still have no job to do. The words-only hotbar fails the reading-level test. **Challenges a decision.**

## Why it exists / arrow
- Techniques are how you answer "beasts too strong" and the main thing Explore pays out (core-loop "Techniques: many, found, chosen"). Dao ties them to the weapon you actually fight with. The arrow is strong.

## Who it's for
- Kid: a spectacular move that visibly grows over T1 to T4. Hardcore: picking 3 of many (`Techniques.SLOTS = 3`), then mastering a class. Teen: status from showing a Peak art.

## Is it fun?
- Good: a manual found too early is kept, reads "Requires Saber Dao 8" and is learned on the level-up that reaches it (`Weapons.onLevelUp -> Progression.learnReady`). A drop becomes a goal, which is textbook. Peak arts are multi-beat set pieces.
- Weak, as the roadmap's own diagnosis says (section 4): techniques are damage plus a cooldown. No enemy asks for one, no status exists per class, and nothing combines. It isn't learning (Koster) when the only lesson is "press when off cooldown".
- Choice is thin. Before Dao 5 there are only the starter arts (Fire Seal at 3 kills, Sword Qi Wave at 12, Iron Skin at 30), which fill all 3 slots with no decision. The plain Dao 2 skills don't exist yet (`weapons.md`).

## Cost
- **Comprehension needs four things at once:** the art at its bottleneck level, Spirit Stones (60/250/600), the class Dao at `learn + 2k` (or `+k`), and sitting in meditation (`combat.md` Key files, `Pacing.Comprehension`). The elder can't say that in one sentence. The Dao part is also the second time Dao gates the same art (it already gated learning).
- **Content cost:** a target of ~28 arts x 4 visual tiers is ~112 effect templates, plus a clip per class skill. The vfx pipeline is the bottleneck, so keep the count honest.
- **Words-only hotbar** (branch `mw-hotbar-words`, `HotbarView`): 1-2 words in Oswald Bold 11 on 32-35 px slots. That is under the 14-16 px text floor and under 44 pt targets. Words also demand reading from an 8-10-year-old, and auto-translation will lengthen and truncate them ("Deity Peach", "Heaven Dew" are already strained). Colour plus a glyph reads at a glance in any language.

## Failure and abuse
- **The first boss reward is usually unusable.** Its guaranteed manual is Twin Phoenix Cannon (`Pacing.Rewards.BOSS_FIRST_MANUAL`), a **Fist** Dao 5 art. New players start holding a Jian, with Fist at Dao 2, so the biggest drop of the QC run sits in Arts until they switch to fists for ~360 landed swings (XP 30+30L per level, 1 per swing). The milestone's spectacle lands as a "Requires" toast.
- The Dao math is gentle elsewhere: ~1,080 landed swings take an untrained class to Dao 8. That's fine.

## Metrics
- Kept manuals give a reason to return ("I'm 2 levels from Rampaging Tiger"), which is a good D7 hook. Auto-learning on a Dao level-up is a felt milestone, but today it is only a toast.

## Interactions
- Dao, technique level, comprehension tier and visual tier are four progress numbers on one art. Show them as one thing: the tier seal.

## Ranked recommendations
1. **Make the first boss drop an art for the class in hand.** It can be the Dao 5 skill of the killer's current class, or the first-boss manual can roll from the class with the highest Dao. A one-line change in the drop logic.
2. **Cut Dao from comprehension.** Comprehending = meditate + stones; Dao gates learning only. Elder line: "Your art has reached its limit. Sit, spend stones, and see further." This removes `comprehendDao` and its toasts.
3. **Make an auto-learned art a moment.** When a kept manual unlocks on a Dao level-up, show a card with the art's T1 effect playing, not a toast. Reuse the BreakthroughView card.
4. **Replace words-only with seal art on touch** (colour plus element or class glyph, cooldown sweep). Hold-to-peek for the name stays. Pairs with combat rec 1, which moves arts off the hotbar.
5. **Give one job before adding twenty arts.** Ship one armoured beast (the Stone Tortoise) and one status (greatsword guard-break) before the next batch of skills, so an art answers a question.
6. Cap visual tiers for new arts at T1-T2 until analytics show players reach T3.
