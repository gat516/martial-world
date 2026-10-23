The plugin's asset library: live search, contact sheets, judging and using textures, flipbooks, meshes and sounds, and asset gotchas. Read when you pick assets for an effect (every new effect).

# The asset library (textures, meshes, sounds)

Build effects from the plugin's Asset Library; you pick the assets yourself. Search fresh for
every effect, with words from its own references and idea. Don't start from ids another
effect used, and nothing records which assets were picked.

## Searching

- **Live search is the method.** Run `tools/vfx_library.luau` through `execute_luau`, then
  `_G.vfxLibrary.search("vortex", 40)`. It types into the plugin's own library search (the
  vfxLib window, `CoreGui.ViewSelectorScreenGui.Selection.Seperate.Library`). The plugin
  builds that window hidden when Studio starts, but a fresh sandbox has no library until the
  user clicks vfxLib once; if search errors, ask for that click. If the library can't be
  reached at all, flag it and stop (AGENTS.md): no falling back to the JSON index, old ids
  or hand-made textures.
- The search only matches the library's own tags, which are sparse ("roar" finds nothing,
  "ink" one image), so search by what the action causes rather than its name: a roar is
  "shockwave", "ring", "wind", "air", "dust", with sounds under "air" ("Air Blast"),
  "shockwave", "monster" and "scream". Search sounds by name ("explosion", "slash",
  "thunder").
- **One call per effect:** write the cause words for every layer, run
  `_G.vfxLibrary.dump(words, "<name>")` (posts the live results to `tools/frag/<name>.xml`),
  then
  `~/.local/bin/uv run -q --with pillow python3 -I tools/vfx_contact_sheet.py OUT layers PLAN.json tools/frag/<name>.xml`
  with `PLAN.json` = `{"<layer>": ["cause word", ...]}`: one sheet per layer (images,
  flipbooks and meshes together) and that layer's sounds as text, in seconds. Raw thumbnails
  are cached in `~/.cache/vfx_thumbs` and fetched 16 at a time.
- **Never scroll the library window through to its end** to list everything: loading every
  tile crashed the user's Studio (2026-10-22). Search instead.
- `tools/vfx_library.json` is a partial offline index: 7,087 assets (6,218 images, 41 mesh
  flipbooks, 77 meshes, 751 named sounds) in library order, each with `kind` and the search
  `keywords` it matched (ring, slash, lightning, flame, smoke, crack, rune, seal, aura,
  beam...), from a fixed word list, so an asset can fit without matching your word. It was
  built from keyword searches of a window that only lists tiles as you scroll; the library
  passed 7,600 tiles and was still growing (2026-10-22), so expect 10,000+. Grep it first
  for candidates; search live for other words, and never use it in place of an unreachable
  library.

## Judging an asset

- Tiles only carry ids, so judge looks from thumbnails on a contact sheet before using one:
  `~/.local/bin/uv run -q --with pillow python3 -I tools/vfx_contact_sheet.py OUT NAME kw1,kw2 [kind] [max]`
  (or `ids:a;b;c` instead of keywords) writes a labelled sheet; Read the PNG. `--size 420`
  gives big tiles (16 a sheet) to read a flipbook's grid, fine detail or a background.
- A black tile means an opaque black background, useless for tinted or alpha use: skip it
  (e.g. 8952281337, 10365552478, 11037528577, 8214519774). Flipbooks drawn on black
  (9470659899, 14990829312) show as black boxes unless LightEmission is 1, so check the
  background on a `--size 420` sheet before picking LightEmission.
- Contact-sheet labels can drop the last digit of long ids. Grep the dump for the id before
  using it ("Request asset was not found" at runtime otherwise).
- Many sheets and splats fill only part of their cell or image (the tan dust puff
  11509655546 about half a cell, the splatter 243457340 about half the image): author their
  sizes 1.7-2x the area you want covered.
- Don't vet ids with `ContentProvider:PreloadAsync`: it reports Failure for many library
  images that render fine. Render-test instead.

## Using assets

- Ids as `rbxassetid://<id>`. Meshes are MeshIds, sounds SoundIds.
- Flipbook ids are sprite sheets: put them on a ParticleEmitter with `FlipbookLayout`
  Grid2x2 or Grid4x4 (read the grid off a large thumbnail); no mesh needed. Only real
  flipbooks animate: use ids the library marks as flipbooks, or test an image sheet's grid
  before relying on it. The library's mesh-flipbook layout is a Part with a SpecialMesh and a
  Decal whose `Flipbook` attribute lists the frames; ask the user to insert one if you need
  its exact setup.
- Soft glow 867619398 shows a square edge when large and bright; use the hard dot 9841273544
  for flashes and heartbeats.
- A turning sigil is steadier as a turning SurfaceGui image than as two overlapping rotating
  particles, which drift out of step.
- Assets already in `ServerStorage.AssetLibrary`, existing effects and
  `rbxasset://textures/particles/*` are fine to reuse alongside library picks.
- Known gap (audit, 2026-10-22): the shipped templates (`Effects`, `AmbientFX`, `WorldFX`,
  `GuardFX`) use 201 of the 7,087 indexed assets, 12 of the 41 flipbooks and 12 of the 77
  meshes, and ten generic textures (the soft glows 9841273544 and 867619398, the ring mesh
  471124075, stock sparks and impact rings) are about half of all texture uses. About 690
  Neon parts are still doing the drawing. Hero and secondary layers should get a texture,
  flipbook or mesh with the action's own shape; keep the generic glows and sparks for cores
  and sparkles. To redo the audit, `rojo build` each `.rbxm` to an `.rbxmx` in your
  scratchpad and count the `rbxassetid://` ids against `vfx_library.json`.

## Own textures (only when the user asks)

Don't draw textures with Pillow unless the user asks. When asked: the system python has no
Pillow, so run `~/.local/bin/uv run --with pillow --with numpy python art/<x>/draw_<x>.py`.
To upload, serve the folder with
`python3 -m http.server 8771 --bind 127.0.0.1 --directory art/<x>` (in the background) and
pass `http://127.0.0.1:8771/<file>.png` to `upload_image`; keep the returned ids in
`art/<x>/assets.json` and stop the server after.

## Sounds

Sounds belong with `SoundService.SFX` / `src/client/Sfx.luau`; don't hide Sounds inside
effect templates unless the plugin should emit them with it. Library sounds are other
creators' uploads, so one may not play in our experience if its owner hasn't made it public:
say in the report that in-game playback is untested, and swap any the user reports as silent.
