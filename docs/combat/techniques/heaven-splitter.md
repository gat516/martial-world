# Heaven-Splitting Descent visuals

Covers the `HeavenSplitter` technique effect (templates `HeavenSplitter_T1..T4`, spec `tools/vfx_specs/HeavenSplitter.luau`, `TechniqueFX.HeavenSplitter`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `HeavenSplitter_T1..T4`, authored at radius 12 centred 4 ahead
(root `AuthoredHeight` 20 / 28 / 36 / 46, the sky column); `TechniqueFX.HeavenSplitter`.
Heaven-azure qi, white core (gold at IV), ink and umber darks. The effects follow
the clip's markers (`BladeSkill`, `WeaponFX.swing`); the animation is not touched.

## Heavy pass (2026-10-23): the sky comes down

Intent: the greatsword falls from the top of the leap and the heavens follow it
down. One peak, at the bite; weight and finality; the fight's hero hit confirm.
Beat sheet, intent and the LAYER SHEET are in the spec header.

Three directions for the slam peak were built from one spec (`spec.variant`,
`tools/vfx_specs/HeavenSplitter.luau`; rebuild with another letter to switch):
- **A "Sky cleave" (shipped, picked by the critic):** a streaked column of light
  (12781750620, FacingCameraWorldUp, squashed thin) lands on the bite wide, then
  thins out over 0.22-0.32 s on an ink copy; B's explosive dust burst (flipbook
  12360899465 over an umber copy) erupts under it.
- **B "Earth break":** the dust burst is the hero, bigger, with a slate shard fan
  (mesh 114192967647602) heaving up and a rock-coloured shock ring on an ink copy.
  Rejected: reads as a generic smoke explosion and loses the heaven.
- **C "Heaven's judgement":** a needle-thin white line (107059622686856) from the
  sky for two frames, then a cold mist (137279303567615) creeping flat over the
  circle. Rejected: the weakest peak; reads as A turned down.

Layers per beat (T1 / T4):
- Cast (Hit 1): the `Charge` on the blade; sound Draw.
- Sweep and rising cut: the blade's Edge trails, a `Flare` at each swing's peak,
  light impacts per enemy; sounds Sweep, Rise, Hit per enemy.
- Leap: a ragged wind ring (mesh 107819007023719) and dust at the feet, II+ updraft
  swirls, III+ streaks; sound Leap.
- Hang: blade glow and motes, III+ the rune seal over the landing (the T4 gold
  "Halo" ring was cut: no halos) and the sky rift, III+ the phantom blade; sound
  Gather, a rising charge cut off at the bite.
- Slam peak at the bite (`Strike`, facing along the cut): core dot + star burst
  (cores), the column on its ink copy, the dust burst on its umber copy, chips;
  sounds Bite + Break + Rumble, III+ Thunder, at the bite point. 6 / 7 emitters.
- Follow-through from the circle's centre (`Slam`): a jagged shock ring
  (85827484380910) snapping out to r 6 in 0.1 s, the ragged wind ring mesh
  (99300490107593, `GroundWave`, times the heavy impacts) rolling to r 12, a dust
  cloud flipbook wall (113990972016632); III+ Craters rock ring and the scar
  (crater + cracks, 2.2 s); IV the one PointLight; shake 1.4 / 4.6, III+ impact
  frames, II+ punch. 3 / 6 emitters plus the mesh.
- Rend (`BladeSkill.rend`, unchanged) from the bite through the circle; sound Rend
  60 ms after the bite. Heavy impacts per enemy as the front reaches it.
- Cut in this pass: the plain torus ground wave and echo, the Neon pillar
  cylinder, the T4 dome shell and its runtime emit.

Sounds (`SoundService.SFX.Techniques.HeavenSplitter`, `assets/SoundGroups/SFX.rbxmx`,
vfx library ids; `Sfx.play` at the beat, positioned): Draw 109903968999295,
Sweep 3755635374, Rise 135315310485417, Hit 935843979, Leap 3809084884,
Gather 140049602451857, Bite 7601865567, Break 100457174196725, Rumble 9114221327,
Thunder 12222019, Rend 78919029033811. No sound was wired before (the generic
`Sfx.play(def.id)` in `CombatEffects.cast` finds no `HeavenSplitter` sound).

Previews: `tools/vfx_skill_preview.luau` (`_G.skillPreview.filmstrip`, the real
clip on `workspace.Rig` holding a greatsword; `_G.reviewLoop` for a repeating cast
in a sandbox window).

History: remade 2026-10-21 on the greatsword and the clip's markers (the Charge
along Base -> Tip, the Hit-marker flares, the slam's impacts squeezed into
Hit 3 -> Hit Stop 3); QA pass 2026-10-21 (flares, light impacts and the slam at
each swing's peak via `WeaponFX.swing`, the bite under the point ~9 ahead, the
Neon fissure replaced by the rend, III+ impact frames, II+ punch, shake 1.4 /
2.2 / 3.4 / 4.6, a cancelled cast leaves nothing behind).

## Known gaps
- Sounds are other creators' library uploads; in-game playback is untested
  (swap any that are silent).
- Observers get the cast at Hit 1, so they hear no Draw before it.
- The first hit (def 0.18 -> 0.37 clip) ends before the blade actually
  sweeps the front (0.45 -> 0.58), so its flare and light impacts land at
  the window's end with the blade still out to the right. Moving the hit (or
  the animation) is a gameplay call; the effects follow the def.
