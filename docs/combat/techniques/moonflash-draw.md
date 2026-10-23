# Moonflash Draw visuals

Covers the `MoonflashDraw` technique effect (templates `MoonflashDraw_T1..T4`, spec `tools/vfx_specs/MoonflashDraw.luau`, `TechniqueFX.MoonflashDraw`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `MoonflashDraw_T1..T4`, authored along a 14-stud dash
with width 5; `TechniqueFX.MoonflashDraw`. An iaido dash-cut in silver
moonlight: the clip draws the blade from the right hip and sweeps it flat
round the front at chest height while the caster lunges `def.lunge` from Hit
to Hit Stop. Windup: a glint on the drawing hand. At Hit a crescent-moon
flash and swirl air rings burst on the hand. A horizontal crescent of Beams
(`Front`) rides `def.length - def.lunge` studs ahead of the caster's live
root (with a time floor so it never stalls), dragging a wake band as wide as
the hitbox, a streak Beam from the dash start (`Streak`) and a glowing slit
on the ground (`Cut`) that cools into an ink scar (`Scar`). Each enemy on the
line gets a silver `impactStack` and a crescent cut as the front passes it.
The dash ends in a crescent mark and ground torus at the feet (`Finish`).
II+ leaves Neon afterimages of the body along the path (1/2/3 by tier), an
echo crescent, and the signature "sheathe": ~0.12 s after the dash every
target cut flashes again with a crossing crescent and a standing white ring
while the slit flares (`Sheathe`). III adds 2 air rings, impact bubbles and
rock kicks, path cracks and a Craters ring at the finish; IV a gold core,
three afterimages, one point light on the front, a crescent moon rising
behind the finish, impact frames at the sheathe and a quake on the first
impact. `WeaponFX` (same folder) holds the helpers the weapon skills share.
Remade 2026-10-21 on the jian itself (`WeaponFX.rig`, the model's Base ->
Tip): the windup is a `Charge` along the blade (dark beam under a cold bright
one, motes, a glint at the point: the blade catching the light as it clears
the scabbard, 0.067 s); the draw flash, moon and air rings burst on the
blade 0.8 of the way to the tip rather than on the hand; through the dash an
`Edge` rides Base -> Tip (a solid moon ribbon, II+ a long afterimage, a Glow
beam, shed motes); the crescent front has an ink crescent under it; every cut
gets a crescent-moon flipbook (and the shared ink splat and star-burst
flipbook), fired as the front passes it, so all of it sits inside the
lunge window (Hit 0.067 -> Hit Stop 0.233, the clip's Lunge markers); a
`SheatheGlint` (star, halo, crescent flipbook, motes) flares on the live tip
as the blade is put away, 0.12 s after the dash. Layers T1 / T4: charge 8 /
8, release 5 / 8, edge 3 / 4, travel 13 / 13, impact 10 / 16, sheathe 4 / 9,
finish 3 / 4.
