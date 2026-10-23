# Rampaging Tiger Cleave visuals

Covers the `RampagingTiger` technique effect (templates `RampagingTiger_T1..T4`, spec `tools/vfx_specs/RampagingTiger.luau`, `TechniqueFX.RampagingTiger`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `RampagingTiger_T1..T4`, authored at radius 10
around the caster; `TechniqueFX.RampagingTiger`. Tawny amber qi over black
brush-ink, white-gold core at IV. Every cut flashes three claw strokes in the
air (`Claw`: amber Beams over ink, diagonal for Hit 1, vertical for the spin
hits and the landing) and an impact on each enemy in the circle. Leap: a
torus and dust ring. II+ while the blade wheels (1.0-1.78 clip) a spinning
amber swirl ring stands in its circle at the right side (`Wheel`, sized to
the blade's reach; III+ a counter-turning ForceField ring, embers). Landing
(last hit): flash where the blade bites, three claw rends fanned forward
(`Gouge`/`GougeKicks`, `BladeSkill.rend`), roar rings thrown forward (1/1/2/3), a torus
shockwave to the radius, heavy impacts by the front; III+ Craters rock
ring, cracks, rock kicks; IV a giant claw over the strike, a swirl shell,
the one PointLight, impact frames and a quake. Remade 2026-10-21 on the
saber and the clip's markers: the windup (0 -> Hit 1, 0.48 s) is a `Charge`
along the dadao's Base -> Tip (dark beam under an amber one, motes, a point
glint) instead of a hand gather; each cut (Hit 1-3) and the landing (Hit 4)
flare on the live blade tip as the marker fires (`Flare`: cross glint,
star-burst flipbook over an ink splat, sparks; 1.5x at the landing); and the
landing's heavy impacts are squeezed into Hit 4 -> Hit Stop 4 (0.117 s,
`WeaponFX.landing`) rather than following the 0.46 s torus out to r 10. All
hits also get the shared ink splat and star-burst flipbook. QA pass
2026-10-21: each Hit marker fires with the dadao still raised (Hit 1 has the
point behind the head), so the claws, flares and impacts of every cut and the
landing fire at the swing's peak inside its Hit window (`WeaponFX.swing`),
the flare facing the swing; the landing bites under the point at contact;
the Neon gouges are three claw rends (carved cracks under amber seams that
cool; the middle one kicks dust and chips); impact frames from III; a
hit-pause punch on the landing at II+; shake 1.1 / 1.8 / 2.8 / 3.8; a
cancelled cast no longer leaves its template copy behind. Layers T1 / T4:
charge 8 / 8, cut flare 6 / 7, claw 12, impact 10 / 17, landing 8 / 14,
rends 9 / 14.
