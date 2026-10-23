# Dragon-Piercing Thrust visuals

Covers the `DragonPierce` technique effect (templates `DragonPierce_T1..T4`, spec `tools/vfx_specs/DragonPierce.luau`, `TechniqueFX.DragonPierce`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `DragonPierce_T1..T4`, authored at length 22
and width 4; `TechniqueFX.DragonPierce`. A red-tasselled spear dragon in
crimson and gold: the clip draws the spear back along the right side, then
drives it round and forward from Hit to Hit Stop while the caster lunges.
Windup: crimson qi spirals into the hands (II+ Spline wisps, III+ a seal).
At Hit a forward-facing vortex disc, a star and swirl air rings burst where the
lance starts on the line, at the height of the live spear point (the
weapon's `Tip` attachment, else the right hand). A
drill of qi (`Lance`: twisted spiral-cone MeshWaves stretched to the line,
`Stretch = true`) shoots from the point to the line's end on `TravelCurve`
over `TravelTime` (0.16 s), with a gold core and crimson glow Beam and a hot
head shedding sparks; swirl rings (`Ring1..n`, `Station` = fraction along
the line) burst across the line as the front passes them. A ray stops it at
a wall. Each enemy gets a crimson `impactStack` plus sparks punched out of
its far side when the front reaches it, and the lance bursts at its end
(`Terminal`: impact stack and vortex). A rend opens in the ground under the
lance as its front passes (`Rend`/`RendKicks`, `BladeSkill.rend`) and cools. II adds a gold dragon helix coiled round the lance, path dust
and motes, impact swirl; III a counter-wound second helix, impact bubbles
and rock kicks, a Craters ring at the terminal, path cracks; IV a gold-white
core, five rings, the dragon seal flashing at the point with impact frames,
one point light on the lance head and a quake at the terminal. Remade
2026-10-21 on the spear and the thrust's window: the 0.3 s windup is a
`Charge` along the whole spear (butt -> head, `full`: a dark beam under a
crimson one, motes along the shaft, a glint on the head) instead of a hand
gather; the release on the live spear head gets the shared flare (cross
glint, star-burst flipbook over ink, sparks); the lance has an ink beam under
its glow; the front crosses the line in 0.12 s (was 0.16) and every impact is
squeezed into Hit 0.30 -> Hit Stop 0.40 (`WeaponFX.landing`; a sandbox run
with a spear on the rig landed the impacts 0.06 s and the terminal 0.07 s
after the release); impacts carry the shared ink splat and star-burst
flipbook. QA pass 2026-10-21: sampled on the clip, the head is out to the
right at Hit and points straight ahead ~1.6 right of the root's line at
3.1 high by Hit Stop, so the lance runs down that thrust line (`Lance`
attributes `Lateral`, `Height`, `StartAlong`) instead of the root's centre
line; the shared flare (now part `Flare`) plays on the live head where the
thrust peaks (`WeaponFX.swing`); the dark furrow is a rend (carved crack,
crimson slit and seam cooling, puffs and chips along the line, star cracks
at II+, a crack web and rock kicks at III+); a hit-pause punch on the
terminal at III+; shake 0.8 / 1.3 / 2.0 / 2.8. Layers T1 / T4: charge 8 / 8, release 9 / 13, lance 9 / 14,
impact 9 / 15, terminal 9 / 15.
