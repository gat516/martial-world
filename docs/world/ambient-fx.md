# World: ambient effects (AmbientFX)
The `ServerStorage.AmbientFX` templates map passes place (fireflies, lamp glows, mist, waterfall spray and mist, the Inner Wilds set), how to size and mount each, and the preview spot. Read it when placing or authoring ambient effects. Core: [world](../systems/world.md).

- Ambient world effects are templates in `ServerStorage.AmbientFX`
  (`assets/AmbientFX.rbxm`, built by `tools/ambient_fx_build.luau`), placed by
  map passes. Each is one invisible, anchored, non-colliding Part (the emission
  volume): move, rotate and resize it to fit.
  - `Fireflies`: fireflies + spirit motes over a lawn or garden (24x5x24;
    raise Rate with area). Night only (spirit motes keep a fifth by day).
  - `LanternGlow`, `JadeLampGlow`, `BrazierGlow`: halo, flame flicker (and
    embers/smoke) for the `_Templates` FX_StoneLantern / FX_JadeLamp /
    FX_Brazier. Pivot them on the flame:
    `glow:PivotTo(lamp:GetPivot() * CFrame.new(glow:GetAttribute("MountOffset")))`.
    No lights of their own (the lamp models carry those).
  - `MistWisps`: low drifting mist for cliff edges and the cloud-sea surface;
    the part's front face is the drift direction. Keep it just off the rock:
    particles have no soft edges and cut hard lines where they cross geometry.
  - `WaterfallSpray` (flat on the plunge pool where the water lands, front face
    away from the cliff) and `WaterfallLip` (thin strip on the top edge, front
    face out over the drop).
  - `FallingPetals`, `FallingLeaves`: under a flowering tree's canopy.
  - Inner Wilds set (2026-10-21; map anchors in brackets). "Scale Rate with area"
    means multiply every emitter's Rate by placed area / authored area.
    - `WaterfallMist` [`FX_FallMist`]: upright slab on the fall's face, front face
      out from the cliff; 12x24x2 authored. Hero fall (Jade Veil, ~40 tall): about
      20x38x3, Rates x2.6. Trickles: 4x14, Rates x0.3.
    - `PlungeBillow`: white billows rolling up and out at a hero fall's foot, on
      top of `WaterfallSpray` + `WaterKit.WaterfallFoam` [`FX_FallSpray`]; flat on
      the pool, front face away from the cliff, 16x2x8. Trickles skip it; at a
      trickle use `WaterfallSpray` alone, shrunk to the water's width.
    - `SpiritMotes` [`FX_Fireflies` at the shrine, the hollow]: jade-gold motes
      rising slowly plus twinkles, 20x6x20. Half rate by day, so they read in
      daylight; add a `Fireflies` clone for the night in gardens and the hollow.
    - `ShrineIncense` [`FX_ShrineIncense`]: one thin curling smoke ribbon and
      glowing tips; put the 0.4 part at the stick tips, one per censer.
    - `QiSpring` [`FX_QiSpring`]: jade motes, curling qi wisps and faint rings
      off a spring pool; flat on the water, 16x1x16, scale Rate with area.
    - `DenMist` [`FX_DenMist`]: low cold blue-grey mist; centre ~3 above the
      floor, 40x2x40, front face is the drift. Particles are squashed flat and
      kept level so they don't cut hard lines into the ground. Thicker at night.
    - `BambooLight`: slender leaves drifting down, dust motes and soft slanted
      light shafts. Size it to the open air under the canopy (30x16x30); tilt
      the part 10-25 degrees toward the sun to slant the shafts (they follow its
      down axis). Shafts and motes fade at night (DayScale 1, NightScale 0.1).
      Shafts need dark canopy or stems behind them; against open sky they vanish.
    - `LotusMere`: pink petals floating flat on the water, golden pollen,
      small ripples; ~0.1 above the surface, 30x0.2x30, scale Rate with area.
      Add a `Fireflies` clone over the mere for night.
    - `RimVeil`: a slow bank of big cloud billows (radius 20-32, ~9 alive) for
      the outer side of the valley walls, so flyers see cloud past the crest
      instead of the walls' backs. 20-40 studs outside the backs, centred at
      about crest height (lower and the wall hides it), 10+ off rock, one per
      ~80 studs of wall (~30 for the Inner ring, ~270 particles in all, few on
      screen at once). The existing `FX_RimMist` clones (`MistWisps`, 70x10x30
      at Y 24) sit too low to hide anything from the air; keep them as foot
      mist or replace them with `RimVeil`.
    - Preview: `Workspace._FxPreview` (place-only, over the cloud sea): a hero
      fall at (3550, 200, 3700), shrine (3640, 3700), spring (3720, 3700), den
      mist (3800, 3700), bamboo (3620, 3790), mere (3740, 3790), wall + veil
      (3850, 3790). Cameras: fall (3565, 214, 3762) to (3550, 216, 3690); shrine
      (3632, 206, 3712); bamboo (3655, 215, 3800); mere (3725, 208, 3815); veil
      from the air (3850, 400, 3900) to (3850, 280, 3700). Edit mode doesn't run
      the emitters' Rate between MCP calls, so emit by hand to see them.
- Emitters tagged `NightFX` scale their authored Rate in DayNight's night step, between their `DayScale` (default 0) and `NightScale` (default 1) attributes.
