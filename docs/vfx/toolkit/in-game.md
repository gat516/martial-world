Playing templates in the game: which client module owns a moment, cloning and cleanup, the TechniqueVFX tier path, variants, server-triggered effects, and the hit feedback that already exists. Read when you wire an effect into client code.

# Playing effects in-game

- Client side, in the module that owns the moment (CombatEffects for casts and hits,
  BreakthroughView, WeatherFX, ...) or a small shared helper if several need it. Clone the
  template from `ReplicatedStorage.Effects`, position it (`PivotTo` keeping the template's
  pivot rotation, or attach to the character's attachment), parent it under
  `workspace.CurrentCamera` or `workspace.Terrain.TempVFX` like the existing effects, then
  `fx.emit(clone)` and `fx.debris(clone)` (or `destroyAfter` with `fx.maxLifetime`). Loops:
  `fx.enable` / `fx.disable`, then clean up. API: [plugin.md](plugin.md).
- Techniques go through `src/client/TechniqueVFX.luau`: it picks `Effects.<Id>.<Id>_T<tier>`
  from `Techniques.visualTier(level)`, steps EmitCounts +20% per level inside a tier, and
  falls back to plain emitters when the Game Module is missing (`TechniqueVFX.full` false).
  The cast payload carries the level. Extend this helper rather than adding a parallel path.
  A technique's own runtime is `src/client/TechniqueFX/<Id>.luau`, wired with `CastFX`
  ([pipeline.md](pipeline.md)).
- Use `fx.rescale` / `fx.recolor` for variants (technique tier, realm, enemy size) instead of
  duplicating templates.
- Server-triggered moments already arrive over the `Effect` remote (see the table in
  `docs/README.md`); add a new kind there rather than a new remote. The server never plays
  visuals.
- Anything a cast leaves running registers with `WeaponFX.onCancel`, so a dodge or stun
  clears it.
- Replace the old hand-built Neon-part effects in CombatEffects only when the task asks for
  it, one effect at a time, keeping the same timing and hooks.
- Run `tools/check.sh` after editing scripts.

## Feedback that already exists

Hits already have `CombatEffects.shake` (tiered by `SHAKE_BY_TIER`, only within 45 studs of
the camera), `CombatEffects.flash` (fired per impact, not at release), `CombatEffects.punch`
(hit-pause), damage numbers, and the technique's own Sfx cue. Build on them instead of
doubling them up.
