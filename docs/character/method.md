# Cultivation method

Covers cultivation methods: how players get them, the breakthrough message rule, what a method does (qi speed, reach, aura), switching and data; read it when working on `Methods.luau` or method rewards. Aura art is in [auras](../systems/auras.md); shared layer rules in [character](../systems/character.md).
**What it is:** how you cultivate. Until FE everyone uses the sect's unnamed
basic breathing method; it is only named when it stops being enough.

**Meeting it (built v1, 2026-10-21):** on reaching Foundation Establishment
(the breakthrough, or on joining for players already there) the elder gives you
a **random starter method** for your root (`Methods.giveStarter`): one of five,
one per basic element, plus the rare root's own for rare roots. No choice
screen. Better methods are **earned, not handed out**: Elder Qingyun's task and
exploring (caches with a `Method` attribute work today; ruins, bosses, events
to do). The switch UI is the meditation menu's Method tile. **Still to do:** the elder's task in
the quest line, method caches placed on the map.

**The breakthrough message must never mislead (decided 2026-10-21).** When a full
bar can't break through because the active method's `reaches` is the next stage's
limit, say so and point the way: "Your method can take you no further. Elder
Qingyun may have a task for you, or seek a stronger method out in the world."
Only when there is truly no next stage in the game does it say "You stand at the
peak of this world's cultivation, for now." Built in `Cultivation.breakthrough`,
the full-bar toast (`warning`) and the quest board ("Seek a stronger method").
Today FE1 is the real top, so the peak line shows there; Sect Breathing reaches
FE1 and starters FE9, so the method line first appears when FE2 exists.

**What a method does (three lines on its card):**
1. **Qi speed:** a multiplier on gathering, refining and passive cultivation.
2. **Reaches:** the highest realm it can take you to. This becomes the gate for
   later majors (e.g. a Spirit-grade method reaches Core Formation, an Earth one
   Nascent Soul). FE1 is the top realm today, so this line only matters once
   later stages exist.
3. **Aura (built 2026-10-21; per-method rebuild the same day):** a visual
   around you while seated (meditating or circulating), seen by everyone:
   `src/client/MethodAura.luau`, keyed on the player attributes `Meditating`
   and `Method`; templates `ReplicatedStorage.Effects.MethodAura.<MethodId>`
   (builder `tools/vfx_specs/MethodAura.luau`, preview
   `tools/aura_preview.luau`). **Every method has its own aura** (decided
   2026-10-21: the old shared tinted template read as the same ring in
   different colours; the user: "there will be different cultivation
   techniques so obviously the grade of their vfx should be way different").
   Each is built from its method's idea and lives on the body first (each
   method's look is in its file under `docs/auras/`). Sitting down, switching
   method and breaking through play the method's ignition surge first. Drawn
   within 140 studs for the 8 nearest (named methods first). Grade sets how
   grand it is (`GRADES` in MethodAura scales reach today; Spirit and up get
   their own pieces later). The per-method brief, what's built, the grade
   scale and the recipe for inventing new methods are in
   [auras.md](../systems/auras.md) (refs in `docs/reference/auras/`).

- A method matching your root gets a qi-speed bonus (the synergy rule).
- Better methods come from bosses, world events, caches and later realms' libraries.
- **Switching is free** while meditating, between methods you own. There is no
  lost progress, so trying one out is never a mistake.

**Data:** `data.methods = { owned: { [id]: true }, active: string }` (active
`""` = Sect Breathing, owned never lists it), player attribute `Method`, in the
`PlayerState` push as `methods`. Switch: `CultivationAction("method", id)`
(`Methods.switch`, while meditating). Effect `"method"` (id, becameActive) when
one is gained. Admin `method <id>` (no id resets). Server
`src/server/Methods.luau`; defs in
`src/shared/Methods.luau` (id, name, element, grade, qi multiplier, reaches,
aura). Tuning in `Pacing.Methods`.
