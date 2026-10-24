# 3D and VFX workflows with agents: what the research says

Citations checked by title only; re-verify an id before quoting a number from it.

Collected 2026-10-23 for the visual agents. Three passes: a
practitioner thread (r/ClaudeAI, a pro artist's Blender-pipeline post and its
comments), papers on agents driving Blender, and studies of VLM judges. Vendor
comparisons and lightly-installed skill files are marked as such. Where a lesson
became a rule, the "Here" column or the line names the file that owns it.

## Bottom line

- No study shows numerically that several agents beat one on a single model.
- The measured gains come from three things:
  - feedback loops: render, critique, revise
  - breadth: parallel variants, keeping the best
  - verification: checking that each fix landed
- Splitting one model into regions between blind agents gives seams and style drift.
- So the visual agents stay one agent per item. Parallel variants are the gate's
  2-3 directions, and the user is the critic (user, 2026-10-23).
- Multi-agent runs cost about 15x a chat in tokens (Anthropic, "How we built our
  multi-agent research system", 2025), and pay off only on work that splits cleanly.

## Agents on one model

| Lesson | Source | Here |
|---|---|---|
| A role split works: planner, coder, critic on 5 renders, and a verifier that checks each critique was applied. Without the verifier, 1 of 3 fixes was silently dropped. The win over a single agent is shown on examples, not benchmarked. | LL3M, arxiv.org/html/2508.08228 | the measurer and ledger; visual-gate fix checklist |
| A coder without the current script in context makes a different asset. Without docs, it "fixes" errors by deleting the lines that raise them. | LL3M | mesh-pipeline |
| Spending on verification beats spending on generation. A breadth of about 4 parallel proposals, pruned by a verifier, helps most on subtle edits. | BlenderGym CVPR 2025, arxiv.org/pdf/2504.01786; VIGA arxiv.org/abs/2601.11109 (+35% over one-shot, best-of-4 about 2x) | 2-3 variants, scored |
| 4 rounds x 8 hypotheses beat both 32x1 and 1x32. Alternate small tweaks with structural leaps, and keep the best so far: without reverting, quality drifted below the first edit. | BlenderAlchemy, arxiv.org/html/2404.17672v1 | visual-gate "Keep the best round" |
| A planner writes the skeleton with its parameters empty, generators fill each piece in parallel, and a critic and refiner work on the whole. Output the best iteration, capped at 4. Its symptom-to-cause library stopped fixes landing on the wrong module. | ParticleGen, arxiv.org/html/2608.00629 | the contract, then owners; modeler's words table |
| Spatial relations as numeric constraints, and helpers that worked promoted into a shared library. | SceneCraft, arxiv.org/html/2403.01248v1 | contract asserts; promote helpers at ship |
| Parallel agents on shared files overwrite each other. Give file-level ownership, and keep the orchestrator out of implementation. | morphllm.com/claude-orchestrator; mindstudio.ai | one writer per file |
| Linked libraries and overrides resync slowly and break, for example on shape keys. | docs.blender.org library overrides; code.blender.org 2022/02 | append and re-run, no live links |

## Seeing and judging

- **A sheet for VLM judges.** Six oblique RGB views in one grid is as good as fourteen.
  Colour-free inputs make judging worse, and rubric prompts help only a little.
  - Judges almost never catch pose or placement errors (recall 0.05).
  - They under-call misplaced texture and over-call missing parts.
  - Sources: 3D-DefectBench, alphaxiv.org/abs/2607.10826; Gen3DEval, arxiv.org/html/2504.08125v1.
- **VLMs are weak at precise spatial work.** Counting, left and right, and distances all
  fail: MIRAGE drops about 20 points on compositional tasks, SpatialScore tops out near
  60%. Practitioners say placement comes out "approximately right". Rule: visual-gate §2
  (placement and fit pass on lints).
- **Judge bias.** In one medical study all 8 judge models ranked their own model's
  answers higher, and hiding who wrote them barely helped (researchsquare rs-11022502;
  tianpan.co 2026-05). When every candidate is Opus, the bias that matters is position
  and phrasing: swap the order and count only consistent picks (visual-gate §3).
- **Pairwise beats absolute scores** (BlenderAlchemy's tournament).
- **Annotated data helps.** The thread's author: "AI doesn't see like we do; enhancing
  the data is the trick". Rule: visual-gate §2 (annotated sheets).
- **Numbers aren't enough.** A metric pass doesn't mean the model looks right. The human
  stays the last judge (cc-blender-skill README).

## Building in Blender

- **Claude is reliable for** primitives, hard-surface assembly, simple materials and
  export. **It is weak at** organic sculpting, big node graphs, light placement and
  weight painting, so rig by script and check by numbers. Sources: mindstudio.ai Blender
  MCP review; Anthropic's Blender connector coverage, digitalproduction.com 2026-04-30.
- **Bevels.** "Nothing in the real world has perfectly cut edges." One no-razor-edge
  rule plus smooth surfaces was the biggest single jump the thread reported. Weighted
  Normal (Face Area, Keep Sharp) keeps faces flat; Auto Smooth was removed in Blender 4.1
  (docs.blender.org). Rule and scope: modeler, Style.
- **Generators are blockout only.** TRELLIS, Tripo and Hunyuan output is dense and soft,
  and needs retopology or decimation (huggingface 2506.15442; the comparisons are mostly
  vendor-written). Rule: mesh-pipeline.
- **No standard mesh validator exists.** Use bmesh checks (non-manifold, loose geometry,
  normals, zero-area faces, n-gons). MeshLint and uGame are open references.
- **Turn the reference into numbers first.** Measure brightness, near-black and near-white
  shares, warm against cool and key colours, and score every render against them. Use the
  full-res views one at a time; the collage is for the human (thread). A multi-angle
  reference fed at once gave one commenter "a beak on the forehead".
- **Physics checks.** Every placed prop stands on a surface with its centre of mass over
  it and no interpenetration, or lamps hang off tables (thread). Rule: modeler, "Before you
  call it done".
- **Effort matters.** A commenter reported that Medium to Max effort stopped the beak
  defect. Anecdotal; effort stays the user's call.

## Roblox specs (create.roblox.com)

- At most 20,000 triangles per mesh. Meshes should be watertight, with no backfaces.
- Rigid accessories (UGC marketplace only; not our in-game accessories, which are skinned,
  one mesh per colour region):
  - a single mesh, at most 4,000 triangles, textures up to 2048
  - a correctly named attachment (HatAttachment, HairAttachment, BodyBackAttachment...)
  - per-type bounds, Classic column: Hat 3x4x3, Hair 3x5x3.5, Back 10x7x4.5, Face 3x2x2
- Third-party numbers conflict; trust the official pages.

## VFX

Thin. No first-hand write-ups were found of agents making good particle VFX from
references, for Roblox or any other engine.
- Aura, an Unreal Niagara agent, is in alpha, and its docs say token costs aren't
  optimised yet.
- Community Roblox VFX skills are lightly vetted, with about 54 installs.
- The repo's pipeline is already ahead: the library index, specs, the origin and texture
  lints, filmstrips and `tools/ref_frames.py`.

What carries over:
- **A symptom-to-cause table** (ParticleGen) is what `docs/vfx/translator.md` already is.
- **Single frames miss transient events** (MMGR, arxiv.org/pdf/2512.14691; coplay.dev
  ai-vfx). Keep the six-moment filmstrip.
- **One grid image plus a defect checklist** for the critic (3D-DefectBench).
- **Measure exposure.** The thread's lighting rule ("measure levels, never overexpose")
  maps to the user's "went overboard, can't see much" and to pale tints blooming to white.
  An exposure lint (not built) would measure the share of pixels clipped to white, the
  bloomed area, the hero layer's value against the body and the screen share at 40 studs.
- **Recipes on demand beat a giant prompt** (Coplay). The vfx library already works this way.
- **Contact sheets with ffmpeg:** `fps=1/N,tile`, scene-change `select`, and drawtext
  timestamps; possible additions to `ref_frames.py`.

## What we have, what we lack

| Area | Have | Lack |
|---|---|---|
| Silhouette | `tools/fidelity_check.py` (bands, composite) | per-part scores; a validated `art/rig/silhouette_render.py`; cutting busy backgrounds |
| Reference numbers | gallery images, modeling-checks validation table, targets in visual-gate §1 | `ref_metrics.py`; numeric gallery baselines |
| Mesh quality | normals recalculated in build scripts; `tools/parts_audit.luau` on the Studio side | a Blender mesh lint (planned `mesh_qa.py`) |
| Visible parallel Blender | `tools/blender_live.sh`, `tools/blender_lineup.py` | - |
| Verification | the critic, 2 rounds; fix checklist, best round and pairwise picks (visual-gate §3) | `pairwise_sheet.py`, `turntable_grid.py`; the measurer script |
| Rig | enemy `check_rig.luau`, FK stress poses | a pose sweep for Blender-rigged player assets |
| Props | `tools/snap_to_ground.luau`; support and grip-clip rules (modeler) | a centre-of-mass and grip-clip check tool |
| VFX | origin, texture and hook lints; filmstrips | an exposure and bloom lint |
