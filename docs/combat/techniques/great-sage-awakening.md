# Great Sage Awakening visuals

Covers the `GreatSageAwakening` technique effect (templates `GreatSageAwakening_T1..T4`, spec `tools/vfx_specs/GreatSageAwakening.luau`, `TechniqueFX.GreatSageAwakening`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md) (weapon-skill helpers: `BladeSkill`, `WeaponFX`, swing/cancel/punch/rend).

Templates `GreatSageAwakening_T1..T4`, authored at radius 8 and 8 s;
`TechniqueFX.GreatSageAwakening`. The Monkey King wakes: the twirl gathers qi
into the spinning staff, the staff end bites the ground (the one peak), his
golden flame erupts up the body and a seal of script unfolds behind his head.
The seal is the buff indicator for the buff's seconds. The animation twirls the
staff flat overhead (`Twirl "start"` 0.167 to `"end"` 1.0, all on the `Hilt`
joint) and brings one end down ~5 studs ahead at `Hit` (1.15); markers, clip
and defs are untouched by the effect passes.

## Beats and layers (heavy pass, 2026-10-23)

| Beat (clip ms) | Layers (role) | Sound (`SFX.Techniques.GreatSageAwakening`) |
|---|---|---|
| windup 0-1150 | `Charge` beam (dark under gold) and motes along the whole staff (`WeaponFX.charge` full), qi into the right hand (`Windup`) | |
| twirl 167-1150 | gold ribbons on both staff ends (`Arc`, from the `Twirl "start"` marker), rune seal turning under the feet, streaks rising into the spin; III+ wind swirl climbing | `Spin` from 167, `Whirl` from 600, both cut at Hit or a cancel |
| Hit 1150, the peak | at the bite (`Slam`): white core, ink splat, star-burst flipbook, glint, sparks (`bladeFlare`), heave mesh in umber, dust flipbook, falling chips, III+ crack scar, shake; on the body (`Body`): **hero** flame burst flipbook over an ink copy, full height by +40 ms, gone by +450; a white star; II+ streaks shooting up; from the feet (`Ground`): the front (`WaveFront`) and a broken ring mesh (`GroundWave`) rolling to `def.radius`, a short dust ring (half the shared count, settled by +550 ms); III+ Craters rock ring; IV Explosion quake; II+ hit-pause punch | `Bite` + `Slam` + `Tail` at the bite |
| Hit -> Hit Stop | an impact (no torus rings) on each enemy as the front reaches it | |
| +60 ms | the sigil unfolds behind the head: 0.3 -> 1.1 -> 1 in ~0.2 s, its images flashing opaque then settling | `Awaken` from the head |
| buff 8 s | a dark solid gold circlet hugging the brow; small flame flipbook wisps off the torso; staff `BuffArc` trails; II+ cloud puffs at the feet, motes, the sigil (faint); III+ full sigil, golden eyes; IV the counter-turning outer script ring, both discs flaring on every staff swing, one soft light | II+ `Hum` loop from the head; IV `Pulse` per swing |
| end | the sigil collapses to 0.6x and fades over 0.45 s, mote puff | `End` |

Layers per beat T1 / T4: twirl 3+trails / 4+trails, peak at the bite 13 / 16
plus the heave mesh, peak on the body 3 / 4, ground 3 / 5, enemy impact 10 / 15,
buff 2 emitters + circlet / 6 emitters + circlet + 2 sigil discs + light.

### The sigil

Asked for by the user (2026-10-23): "a sigil aura on the back of the head, and
not a halo like we had before". Then: not a billboard; a flat sigil fixed behind
the head in the character's own frame, turning with the character and edge-on
from the side, like a disc welded to the back of the head, slowly turning about
its own normal.
- Built as held Parts in `Aura` (`Sigil`, IV `SigilOuter`): `Bone = "Head"`,
  `Offset` 0.45 up and 0.85 back from the head centre (~0.35 behind the skull,
  clear of the circlet), rotated so the part's Y is the head's look axis; `Spin`
  12 and -8 deg/s about that normal; `Gui`, `EmitDelay` (0.06 / 0.12),
  `PulseOnSwing` (IV). Each carries SurfaceGuis on both faces (`Back`, `Front`),
  each an `Ink` ImageLabel (1.05x, burnt-umber) under a `Gold` one, with their
  `Show` transparencies. SurfaceGui images stay crisp and in step where two
  turning particles drift apart.
- Glyph: script array 14191668646 (script rings, a six-point star, a character
  at the centre); IV outer ring: script band 16397769425.
- Sizes: II 1.7 studs (gold 0.5, ink 0.55: faint), III 2.0 (0.15 / 0.3), IV
  2.0 plus the outer ring at 2.5 (0.45 / 0.55).
- Swing pulse: the aura watches the staff's far end; its speed crossing 38
  studs/s after dropping under 18 (not in the first 0.7 s, at most every 0.4 s)
  swells each disc 1.12x and burns its gold opaque for ~0.3 s.

Three directions were built from one spec (`spec.variant`) and judged by the
critic against the gallery: A, the dense gold script array (picked: the only one
that reads as a glyph in one look); B, a ring of eight rune seals inside a band
of script (139744345977881; thinned to a plain ring with marks at play
distance); C, a meander seal brushed in ink with the gold held low, flaring on
every swing from II (87153714607286; muddy brown in daylight).

### Sounds (library ids)

`Spin` SwordSpinning 7769030990, `Whirl` WindWhirl 8520504070, `Bite` Metal (3)
4072627278, `Slam` Earth Slam 71472197762839, `Tail` Magic Rumbling Decay 1
9116407532, `Awaken` Transform 6497101230, `Hum` (looped) Magic Glow Constant
Pulsing Warbled Hum Ring 9125636597, `Pulse` Magic Hit 78280083196784, `End`
Wind Orb Activate 4580495407. No gong is in the library; the low tail is the
rumbling decay.

Cut in the heavy pass: the Neon pillar cylinder, the T4 spike "Crown" mesh, both
torus ground waves and the per-hit torus rings, the stock ray burst and body
glow, the Neon circlet glow (now a solid band).

## Known gaps
- The swing pulse reads the staff's motion, not a hit signal, so a fast
  non-attack staff move (a dodge with the staff out) can flare it too.
- In-game playback of the library sounds is untested (other creators' uploads).
- The twirl (`TechniqueFX.GreatSageAwakening.windup`: the staff trails,
  ground seal and rising streaks) plays on the caster only
  (`CombatEffects.windup` hands off to a technique module's `windup`), and
  observers only get the cast at the first hit, so they never see it (the
  same holds for every weapon technique's `Charge`). The buff aura runs
  `def.seconds` from the cast on each client (it stops early only if the
  caster dies or leaves), not from a server buff start/end signal.
