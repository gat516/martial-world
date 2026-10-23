Timing effects to the animation the move plays: finding it, reading its markers, mapping phases, runtime timing from Config, and when to stop and report. Read when you plan any effect tied to a move (techniques, combat, enemy attacks).

# Sync to the animation's events

Effects follow the animation the move actually plays. Before designing an effect, read that
animation's markers (animation events):

1. **Find the animation.** A technique's def has `animation = n`, meaning
   `ReplicatedStorage.Animations.Fists.<n>` (Palm Strike and Fire Seal play 4, Sword Qi Wave
   3, Lightning Talisman 2, Iron Skin 1). Other moves (dashes, meditation, enemy attacks)
   name theirs in their own module. Check the code path: a technique may get its own
   animation later.
2. **Read the markers.** Run `tools/anim_markers.luau` through `execute_luau`, then
   `_G.animMarkers("ReplicatedStorage.Animations.Fists.4")` (or an Animation instance, or an
   `rbxassetid://` id). It returns the length and every marker with its time and value. It
   reads the `KeyframeMarker` instances under each Keyframe (`GetMarkers()` returns nothing
   for assets loaded with `GetObjects`).
3. **Design around the events it has.** Today the Fists animations carry `Hit` (release, the
   hitbox opens) and `Hit Stop` (the hitbox closes): charge during windup, release and the
   impact burst at `Hit`, the strongest part through the window to `Hit Stop`, fade during
   recovery. Other moves may carry other events (a beam's start/hold/end, each blow of a
   barrage, a channel loop). Map every phase of the effect to a marker.
4. **At runtime, take times from the game's own source, not hard-coded delays.** Combat
   derives the action profile from `Config.Combat` (`src/shared/Config.luau`, the chain's
   `hit`/`hitStop`/`speed`) in `src/shared/ActionRules.luau`. For techniques use
   `Rules.castProfile(def)` (windup / active / recovery, the same numbers the caster and
   observers run on); `Rules.hitAt(action)` is the Hit moment of a live action. Listen to
   `AnimationTrack:GetMarkerReachedSignal(name)` on the playing track for events Combat
   doesn't model. Compare the markers with Config first; if they disagree, report it (known:
   Fists.4 Hit Stop 0.45 vs Config 0.50; Fists.5 0.333/0.350 vs 0.35/0.533). Effects follow
   Config, so they stay in step with the hitbox either way.
   - Fit phases with the template contract ([building.md](building.md), "Template layout"):
     `Phase = "active"` emitters are refit to the active window, the `Windup` part to the
     windup, and untagged emitters are aftermath and keep their own fade.
     `TechniqueVFX.fit(inst, phase, authored, actual)` scales Lifetime and EmitDelay.
   - Time per-target impacts from the wave emitter's own Size curve (when the front reaches
     that distance, `frontTime` in CombatEffects), not from constants. A projectile's arrival
     is squeezed into the blow's window: `WeaponFX.hitWindow(def, i)` is hit i's Hit -> Hit
     Stop at play speed and `WeaponFX.landing(arrival, travel, window)` returns the delay
     (never later than max(window, 0.1 s)), so the impact stack lands with the damage number
     instead of up to 0.3 s after it. Authored flights are 0.12-0.18 s.
5. **Stop and report** if the effect needs events the animation doesn't have: a held beam
   with no start/end markers, a barrage with one `Hit` for many blows, a charge with no
   release marker. Say which animation, which markers you'd need (names and roughly where),
   and what the effect would do with them. Don't fake the timing with guessed delays.
   Animations are the user's to edit.

In previews a scrubbed track never fires its markers ([previewing.md](previewing.md)).
