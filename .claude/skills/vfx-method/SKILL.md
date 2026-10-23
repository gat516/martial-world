---
name: vfx-method
description: The house method for building an effect - references, intent, a beat sheet in ms, a layer plan where every layer is caused and one hero sells it, casting every layer from the vfxia library (search by cause), plan then build from a spec, review rounds scored against the translator, and the judging order and plan format. Shared by the vfx and world-fx agents.
user-invocable: false
---

# Making an effect

How effects should look is in `docs/vfx/style.md`, and the tools are in
`docs/vfx/toolkit.md`. This is how to work.

## The method

1. **References: use what's there; don't research by default** (user,
   2026-10-21).
   - Start from what the user gave you, `docs/reference/vfx/README.md`, style.md
     and the good effects already in the game, then go straight to the library
     (step 5).
   - Research only when the user asks, or when a look truly isn't covered and
     you can't build it otherwise. Say so in your report.
   - When you research, use `tools/ref_frames.py` only, one video at a time
     (style.md, "References"). Decoding a whole video in your own code ran WSL
     out of memory.
   - Every reference you use gets a row in the README and a layer breakdown in
     `docs/reference/vfx/breakdowns.md`, in the same commit.
2. **Intent, before anything else (2-3 sentences).**
   - What is physically or magically happening: a roar is a blast of air and
     sound from the mouth, a slam is mass hitting the ground.
   - What the player should feel: dread, impact, power, warning, reward.
   - The effect's job: telegraph, hit confirm, buff indicator, flavour.

   If the ask is vague, pick the most sensible reading and say it.
3. **Beat sheet: timing before visuals.** Write real durations in ms:
   - anticipation: 20-40%, inward, tensing, accelerating
   - peak: 1-6 frames, sudden, brightest
   - follow-through: 20-30%, outward, slowing
   - dissipation: 20-40%, fading, shrinking, breaking up

   Fast in, slow out; never ease into an impact; exactly one peak. Stagger
   layer starts by 30-150 ms so the eye reads cause, then effect. Drive the
   phases from the animation's markers or the cast's three clocks
   (`docs/vfx/toolkit/animation-sync.md`), not free timers. Nothing lingers
   without a job.
4. **Layer plan: every layer caused, one hero.**
   - For each layer, answer what caused it, where it comes from, where its energy
     goes and why it lasts that long. No answer, cut it.
   - The **action** decides shape, origin, direction and timing. The **theme**
     (element, xianxia motif) decides only colour, texture and flavour. A
     thunder beast's roar is air and lightning from the mouth, not a ground
     crack; cracks come from impacts.
   - Rank the layers:
     - **hero:** sells the action, biggest and brightest, reads in one frame
     - **secondary:** ring, flash, arcs; smaller, dimmer, shorter
     - **tertiary:** sparks, dust, embers; tiny, many, short
     - **environment:** one light flash, ground dust, a scorch
     - **feel:** shake, hit-pause, colour pulse; earned moments only
   - Layer count is not a goal. If removing a layer doesn't make it worse,
     remove it.
   - From a reference, break it into layers per beat, then swap each motif with
     style.md's xianxia table, keeping the timing and contrast.
5. **Cast every layer from the library.**
   - The plugin's library is the standard; don't invent ids. Load
     `tools/vfx_library.luau` and search live first thing.
   - **If the library can't be reached** (the search errors, or common words
     like "ring" and "smoke" return nothing), stop and report it (user,
     2026-10-22). No workarounds: no building from the JSON index alone, no ids
     from other effects, no hand-made textures.
   - **Search by what the action causes, not by its name** (user, 2026-10-22).
     The tags are sparse: "roar" finds nothing, but a roar pushes air and sound
     out of the mouth, so search "shockwave", "wave", "ring", "wind", "air",
     "dust". Do the same for every layer: cause, then the physical things it
     makes (air, heat, dust, debris, light, liquid), then those words and their
     synonyms.
   - Judge candidates on contact sheets, pick per layer, and say which asset and
     why in the plan.
   - The hero and secondary layers get a texture, flipbook or mesh with the
     action's own shape (a roar's sound cone, a claw's crescent, an ink splash),
     not the stock soft glow, spark dot or plain ring. Those are for cores and
     sparkles only. Reach for the flipbooks (41) and meshes (77) first: past
     effects used 12 of each and leaned on ten generic textures.
   - Once picked, keep the assets fixed through review rounds, unless a note is
     about a layer's shape.
   - **Sound comes with the effect** (user, 2026-10-22). Give the peak a library
     sound, plus the windup or tail when it has a job, landing on its beat.
     - Add each as a Sound under `SoundService.SFX`
       (`assets/SoundGroups/SFX.rbxmx`, folders like `Enemies/<Beast>/Roar`).
     - Play it with `Sfx.play` at the beat's moment and position.
     - Replace a wired sound only when the task asks.
6. **Plan, then build.**
   - Send the plan (below) before building, unless told to go straight on. Enemy
     effects skip the plan: the brief is the plan.
   - Build from a spec (`tools/vfx_specs/<Id>.luau`), so every round is a
     rebuild and a small diff.
   - Keep it plugin-compatible (Emit attributes, tags, add-ons), so the user can
     tweak it with the sliders and press R or T.
   - For a hero effect (a boss signature, tier IV, a breakthrough) or an unclear
     direction, build 2-3 clearly different quick versions from the same spec.
     Describe them as pictures and feelings, and let the user pick.
7. **Review: look, score, fix the three worst.**
   - Freeze the same moments every round from the same cameras
     (`vfxPreview.sweep`, `docs/vfx/toolkit/previewing.md`).
   - Score 1-5 on readability, hierarchy, timing, causality and fit.
   - Name the three worst problems and map each through the translator to
     property changes. Apply only those (subtract first), rebuild and look again.
   - Two rounds of your own at most, then hand the look to the user in Studio.
   - The user's notes override your scores. Restate each as the fix you're
     making, and say what changed in plain words.
8. **Ship.** Export, wire, `tools/check.sh`, docs, one commit.

## How your work is judged

In order:
1. **It reads as one caused moment.** Every layer comes from the action, one hero
   carries it, the layers start in order with one peak, and it ends cleanly.
   Effects that are technically fine but feel random are the failure this method
   exists to prevent.
2. **It looks like the reference** in contrast, motion and timing, translated
   into xianxia. A capture next to a reference frame is the test.
3. **It's built from the vfx library and the plugin:** library assets with the
   action's shape, Emit attributes so it plays through the Game Module, and
   add-ons (SimpleMeshVFX, Splines, Craters, ScreenEffects, LightningBeams)
   where they fit.
4. **Parts only support.** Neon or ForceField parts, tweens and PointLights are
   fine for a core or a light, but the effect must still read with them hidden.
5. **It reads in play:** at play speed, at 10 and 40 studs, in daylight on grass
   and at night, on top of other players' effects.
6. **It runs on phones:** fewer, better-shaped particles; richness from kinds of
   layer, not counts (budget in toolkit.md).
7. **It doesn't fight the telegraph** (`docs/systems/telegraphs.md`).
   - The telegraph says where and when, in one danger colour. Your effect
     carries the element and takes over at release.
   - Every impact gets oomph from the library: a shockwave ring, debris or dust,
     a contact flash, and a burst plus a fading scorch for explosions.
   - Projectiles get a real in-flight body and a real explosion.

## The plan

- **Intent:** the 2-3 sentences from step 2.
- **Beat sheet:** each phase with its ms and the marker or clock that starts it.
- **References:** which ones, with the frame grid paths and what you take from
  each (only when there are any).
- **Layer sheet:** one row per layer, with:
  - role and cause, origin, the library asset and why, carrier
  - start and end in ms, motion, colour, dark base yes/no, xianxia motif

  Give the layer count per beat. Sounds get rows too.
- **Plugin features:** add-ons and Game Module calls, per layer.
- **Scaling:** what each tier or grade adds (new layers, not only bigger).
- **Budget** at the top tier, and any one light.
- **Open questions:** missing animation events, add-ons to install, motifs the
  library lacks, anything for the user to decide.

