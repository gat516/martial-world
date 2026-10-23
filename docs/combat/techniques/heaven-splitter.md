# Heaven-Splitting Descent visuals

Covers the `HeavenSplitter` technique effect (templates `HeavenSplitter_T1..T4`, spec `tools/vfx_specs/HeavenSplitter.luau`, `TechniqueFX.HeavenSplitter`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `HeavenSplitter_T1..T4`, authored at radius 12
centred 4 ahead; `TechniqueFX.HeavenSplitter`. Heaven-azure qi, white core
(gold at IV), ink scars. Light hits (Hit 1 sweep, Hit 2 rising cut): a light
impact on each enemy in the circle. Leap: a torus and dust ring at the feet,
II+ swirl rings rising up the body. Airborne: the blade glows and sheds
motes; III+ a faint rune seal opens over the landing circle (following the
predicted landing) and a vertical rift tears open in the sky above it; III+
a phantom greatsword (ForceField at III, Neon at IV) rides the real blade
down and bites the ground, holds and dissolves. Slam (last hit, at the
root's live position): a star flash where the blade bites, a rend split
from there through the circle (`Rend`/`RendKicks`, `BladeSkill.rend`), a torus
shockwave rolling out to the radius with a dust skirt and rays, heavy
impacts timed by the torus front; II+ a pillar of light collapses onto the
bite and an echo torus; III+ Craters rock ring, crater and cracks, rock
kicks, the rend's crack web and rock kicks; IV a dome shell, the one PointLight, impact frames
and an Explosion quake. Remade 2026-10-21 on the greatsword and the clip's
markers: the windup (0 -> Hit 1, 0.14 s at 1.3x) is a `Charge` along the
model's Base -> Tip (dark beam under an azure one, motes, a point glint)
instead of a hand gather; each Hit marker flares on the live blade tip
(`Flare`: cross glint, star-burst flipbook over an ink splat, sparks; 1.5x at
the slam); the slam's heavy impacts are squeezed into Hit 3 -> Hit Stop 3
(`WeaponFX.landing`) instead of following the 0.5 s torus; every impact also
carries the shared ink splat and star-burst flipbook. QA pass 2026-10-21:
the flares, light impacts and the slam fire at each swing's peak inside its
Hit window (`WeaponFX.swing`; Hit 3 fires with the blade still overhead), so
the bite is under the point where it lands, ~9 studs ahead of the root (it
was clamped to 1.5 ahead); the Neon fissure is a rend (carved crack, azure
slit and seam cooling to ink, puffs, chips, star cracks at II+, a crack web
and rock kicks at III+); impact frames from III; a hit-pause punch at II+;
shake 1.4 / 2.2 / 3.4 / 4.6; a cancelled cast no longer leaves its template
copy behind. Layers T1 / T4: charge 8 / 8, flare 6 / 7, light impact 10 /
15, slam 8 / 15, rend 10 / 15, impact 10 / 17.

## Known gaps
- The first hit (def 0.18 -> 0.37 clip) ends before the blade actually
  sweeps the front (0.45 -> 0.58), so its flare and light impacts land at
  the window's end with the blade still out to the right. Moving the hit (or
  the animation) is a gameplay call; the effects follow the def.
