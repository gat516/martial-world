# Great Sage Awakening visuals

Covers the `GreatSageAwakening` technique effect (templates `GreatSageAwakening_T1..T4`, spec `tools/vfx_specs/GreatSageAwakening.luau`, `TechniqueFX.GreatSageAwakening`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `GreatSageAwakening_T1..T4`, authored at radius
8 and 8 s; `TechniqueFX.GreatSageAwakening`. The Monkey King wakes: his
golden circlet, golden flame, the somersault cloud, fiery eyes. The staff
animation twirls the staff flat overhead (`Twirl "start"` 0.167 to `"end"`
1.0, all on the `Hilt` joint) and brings one end down on the ground ~5
studs ahead at `Hit` (1.15). Windup (`windup()`, needs the
CombatEffects hook, see known gaps): from the Twirl start, gold ribbon
Trails on both ends of the staff (the weapon's `Tip`/`Base` attachments)
draw a spinning disc of arcs over the head; a rune seal grows under the
feet with motes rising into the spin (`Twirl`), qi gathers into the right
hand (`Windup`); III+ a wind swirl climbs the body. At Hit: a slam impact
where the low staff end meets the ground (`Slam`), a gold flash on the body
(`Body`), the shared ground shockwave to `def.radius` and a pillar of gold
light (stretched Neon ball) from the feet (`Ground`), and a gold impact on
each enemy as the front reaches it. Then the buff aura holds for
`def.seconds` on every client (`Aura`): a gold Neon circlet round the head,
gold flame wisps rising off the torso, and short gold arcs off the staff on
every swing (`Staff`); it ends with a puff (`Fade`) or stops if the caster
dies. II adds rays, an echo ring, pillar streaks, cloud puffs at the feet,
rising motes and a pulsing circlet; III a ground seal, slam cracks, a
Craters rock ring, impact bubbles and kicks, and two glowing golden eyes;
IV a second torus, a taller pillar with a spike crown, an Explosion quake,
a turning halo behind the back and the move's one light (flashed at the
strike, then a soft gold glow for the buff). Remade 2026-10-21 on the staff
and the Hit window: the twirl's trails and the buff's arcs now ride the
staff's real ends (the model's `butt` and `Tip`; `Base` is only the grip side
of the head, so the old trail started a hand's width from the head), a
`Charge` (a dark beam under a gold one, motes along the whole staff,
`WeaponFX.charge` full) runs along it while it spins, the slam gets the
shared flare (cross glint, star-burst flipbook over ink, sparks) where the
end bites, and every impact is squeezed into Hit 1.15 -> Hit Stop 1.25
(`WeaponFX.landing`; a sandbox run with a staff landed them 0.04-0.05 s after
the release). The `windup` hook now exists in `CombatEffects.windup`, so the
twirl plays. QA pass 2026-10-21: a cancelled twirl (dodge, stun) drops its
trails, seal, gather and `Charge` at once (`WeaponFX.onCancel`) instead of
spinning on to the Hit time; a hit-pause punch on the slam at II+. Layers T1
/ T4: charge 8 / 8, twirl 3 / 4, slam 14 / 19, ground 4 / 10, impact 10 /
17.

## Known gaps
- The twirl (`TechniqueFX.GreatSageAwakening.windup`: the staff trails,
  ground seal and rising streaks) plays on the caster only
  (`CombatEffects.windup` hands off to a technique module's `windup`), and
  observers only get the cast at the first hit, so they never see it (the
  same holds for every weapon technique's `Charge`). The buff aura runs
  `def.seconds` from the cast on each client (it stops early only if the
  caster dies or leaves), not from a server buff start/end signal.
