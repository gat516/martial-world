# Iron Skin visuals

Covers the `IronSkin` technique effect (templates `IronSkin_T1..T4`, spec `tools/vfx_specs/IronSkin.luau`, `TechniqueFX.IronSkin`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md).

Templates `IronSkin_T1..T4`, authored for the 4 s buff and a ground ring
of r 4; `TechniqueFX.IronSkin`; new 2026-10-21, it used to be a Highlight and
a burst of sparkles. The Golden Bell: the body hardens into plated
gold-bronze. Windup (0.2 s, caster only, the shared hand-gather stream at the
chest). At Hit (Fists.1) a flash and the shared flare on the torso, a gold
ground ring, and a bell: a ForceField sphere snapping out round the body with
a ring. Then the buff holds for `def.seconds` on every client: plate glints
flickering over dark soot flecks on the torso and gold gleams off the arms
(emitters moved onto the body parts named by their `Bone` attribute); II+ a
pulsing ForceField `Shell` part round the body; III+ a rune seal turning
under the feet; IV a ringed halo over the head. It ends with a ring and gold
dust (`Fade`), or stops at once if the caster dies. Layers T1 / T4: windup
2 / 3, release 9 / 10, ground 3 / 4, loop 4 / 6, end 2.
