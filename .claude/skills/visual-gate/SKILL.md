---
name: visual-gate
description: The loop every visual agent (animator, vfx, world-fx, enemy-modeler, modeler, ui-designer, map-builder) runs around its work - a status line per phase, numeric targets from the reference, 2-3 cheap directions before polish, the discipline's mechanical lint to zero FAIL, one annotated contact sheet, a fresh-eyes visual-critic round (two at most) with a fix checklist, the best round kept, and a report that carries the critic's verdict. Nothing visual is reported done without it.
user-invocable: false
---

# The visual gate

Rules pile up and the same mistakes still ship, because the maker is the only one
who looks and it looks with the eyes that built it. This loop puts a lint and a
fresh critic between you and the user, so the user sees round two, not round zero.

## 0. Status lines

Post a one-line text message starting `## Status:` at every phase change
("## Status: direction sheet sent", "## Status: lint clean, calling the critic").
The user watches `tools/agent_feed.sh`; a status line is what they read, a tool
name is not. Keep a `Mistakes so far:` list in your latest status handoff (one
line each: what went wrong, what stops it) and hand it in under Workflow
learnings (`agent-report`).

## 0a. Two review modes (user, 2026-10-23)

The brief says `Review: human` or `Review: critic`; if it says nothing, it's **human**.
- **human** (the default; the user is at their desk, watching the stage): no
  self-review captures and no critic. Run the lints, put the thing on the review
  stage **looping** (`_G.reviewStage.anim{}` / `cast{}` / `enemy{}` replays on a
  Heartbeat inside Studio, `model{}` turns, `ui{}` shows the screen with sample
  data), post a `## Status:` line saying what's on the stage and what you'd pick,
  and **end your turn**. The loop keeps playing in Studio with no model calls at
  all; never re-trigger it from your side or poll for the user. The user answers
  in chat ("A", "ship", "the ring is too big") and the main session resumes you
  with the note; you carry on from your context. It plays until they say
  otherwise or you replace it with the next build. Commit what passes before
  ending the turn, and make the status line a handoff: branch, the stage call
  that's showing, the open choice. If your run is long, the main session may
  start a fresh agent from that line instead of resuming you.
- **critic** (only when the brief says the user is away): the loop below, with
  the capture cap.
Lints, targets, the fix checklist and keeping the best round (end of step 3) run
in both modes; in human mode the checklist is the user's notes. Never poll or
wait inside a turn for either.

## 0b. Show the work live, never stop for a look (user, 2026-10-23)

The user is the critic, and watches your sandbox window while you work. Build in
visible steps (blockout, primary forms, detail, surface for a body; key poses,
then timing, then secondary motion for a clip; hero layer, then support, then
accents for an effect; layout, then art, then states for a screen). After every
step, refresh the review stage so it shows the current state, post a status line
with the measured-against-target numbers, then keep going:
`tools/review_stage.luau` installs `_G.reviewStage` with one mode per
discipline, each on a lit plate in front of a parked camera:
- `model{ source }`: the body or prop beside a 5-stud R6 for scale, turning slowly
- `anim{ spec, move }`: the clip looping on the rig (the probe's FK), effects on
- `cast{ id, level }`: the technique looping on an R6 with its weapon, effects
  and sounds through the real cast path
- `enemy{ template, cue }`: the beast playing the move with its effect cues
- `ui{ screen, size }`: the ScreenGui with sample data at phone or PC size
- `stop()` clears it.
Loading: serve your worktree on a port of your own (`python3 -m http.server <port>`
from the worktree root; the shared ports may serve another checkout), set
`_G.REVIEW_STAGE = { base = "http://127.0.0.1:<port>/" }`, then load
`tools/review_stage.luau` through `execute_luau`. Details: `docs/tools.md`.
Leaving the stage running is the one exception to leaving the sandbox clean:
name the stop call in your report. In critic mode never pause for the user's
review. Until the tool lands on your branch, improvise it from
`vfxPreview`/`enemy_fx_shot`/the preview scripts.

## 0c. Budget

A task is one thing: one screen, one move set (2-4 clips), one effect, one
body. Plan for about 80 tool calls; at 150, stop at a save point (commit what
passes, list what's left with numbers) and report. Don't write a helper that
`docs/tools.md` already lists; don't paste files into `execute_luau` when the
brief gives you a served base URL; batch probe runs (`motion_audit`, `ui_lint`
over every size at once) instead of one move or one screen at a time. Look APIs
up in the running tool (Blender `bl_rna` enums, a probe in `execute_luau`,
`docs/tools.md`), never recall them.
**Captures: at most 8 per task**, and each one is a sheet (a direction, a
filmstrip, a four-view) that goes to the critic, never a peek between tweaks.
Tune by numbers and lints between captures; set the scene up in one stage call,
not by hand.
**Images count as captures,** wherever they come from: a Read of a PNG (a crop,
a zoom, a texture, a sheet re-opened), `blender__look`, a Figma screenshot. Each
stays in context for the rest of the run. Check cuts and crops by numbers
(`tools/ui_lint.py`, alpha bounds, pixel stats) and look once, at the end, on one
sheet. Print summaries from probes and lints (FAIL lines and totals, not every
PASS), and run helpers from files.

## 1. Targets, then direction before polish

**Targets first.** Before building anything new, write in your status handoff the
numbers you'll score each round against, measured from the reference:
proportions, timings, palette and value, sizes, as fits the discipline (your
agent file names the numbers and the tool). Give each element one line on why it
exists (what it reads as, what causes it); cut what has no answer.

For anything new or reworked (a new body, effect, clip, screen, area), build 2-3
cheap, clearly different directions first and put them on one sheet for the user
to pick from: silhouette blockouts for a body, the three hero poses for a clip,
one frozen peak per version for an effect, a Figma comp per look for a screen.
Describe each in a sentence as a picture and a feeling. Skip this (not the
targets) when the brief names an exact reference to match, or for a fix. Polish happens once, on the pick. If the user is
there, send the sheet and end the turn (one ask, no waiting). If the brief says
they're away, put all three on the review stage, take the top two by targets to
the critic's pairwise pick (step 3), record the three and the pick, and go on.

## 2. Lint to zero FAIL

Run your discipline's checks before any capture. A FAIL is fixed, not explained.
System Python has no Pillow: run the Python lints, sheets and pixel probes with
`uv run --with pillow python3 ...`.

| Discipline | Lint | Sheet (one or two images) |
|---|---|---|
| UI | `tools/ui_lint.luau` then `tools/ui_lint.py` at 1920x1080, 1366x768, 844x390, 667x375; export round-trip check (`docs/ui/slicing.md`) | the changed screen at PC and phone size, the changed element cropped and enlarged, in one image |
| animation | `art/enemies/motion_probe.luau` metrics (hitches, stops dead, chain lag, anticipation, lows), `keyframe_test.luau`, the family's pose QA | `tools/anim_filmstrip.luau`: 8 poses in a row, 3/4 and side, two captures |
| effects | `tools/vfx_origin_check.luau`, `tools/vfx_texture_audit.py`, `tools/enemy_fx_smoke.luau` for enemy cues | `tools/vfx_sheet.py` or the in-world six-moment filmstrip (`docs/vfx/toolkit/previewing.md`) |
| bodies and props | `art/enemies/check_rig.luau`, `keyframe_test.luau`, `tools/parts_audit.luau`; `tools/fidelity_check.py` against the reference | `tools/model_shot.luau` four-view, plus the fidelity composite |
| map | `docs/map/build-checks.md`, the contact checks (`map-builder` agent file) | eye-level captures from the area's view spots, day and night |
| world events | the three distances (`world-fx` agent file) | far, approach, close in one image |

Capture only what the sheet needs. The user reviews looks in Studio; the sheet is
for the critic. **Annotate it:** dots on landmarks, dimension lines, measured
values against targets and labels on the image (models don't see like we do;
enhance the data). Until your sheet tool draws them, list the numbers beside each
panel in the critic prompt. **Placement and fit pass on lints, not eyes:** gaps,
clips, floats, offsets, counts and left/right are judged by the lint numbers,
by you and the critic.

## 3. The critic

Spawn `visual-critic` (the Agent tool, `subagent_type: "visual-critic"`) with:
the brief or its summary and path; the reference image paths; the matching
exemplars and rejects from `docs/reference/approved/README.md`; the targets with
measured values; the sheet paths; the lint output (paste it, it's short); anything the user has said about this
item. Nothing else: it must not inherit your reasoning.

If the Agent tool says the `visual-critic` type isn't available (agent types load
when a session starts), spawn `general-purpose` with `model: "opus"` and tell it
to read and follow `.claude/agents/visual-critic.md` first; same inputs.

Read the verdict:
- **SHIP**: go to 4.
- **FIX**: apply the three fixes (subtract first), re-lint, re-sheet, one more
  critic round. Two rounds of your own at most; then hand what you have to the
  user with the critic's last verdict quoted, not hidden.
- **Picking a variant** (critic mode, the top two by targets): ask for
  `Pick: A|B`, then ask a fresh critic with A and B swapped. Only a consistent
  pick counts; a split goes to the targets' leader. The pair picks the direction
  before polish; the polished pick still gets its FIX rounds.
- **WRONG DIRECTION**: stop polishing. Go back to step 1 and send the user 2-3
  variants, with the critic's reason.

The user's own notes override the critic's. Restate each note as the fix you're
making, in plain words.

After each round, in both modes, tick a **fix checklist** item by item (every user
note, plus the critic's three fixes in critic mode), each landed with the number or lint line that shows it, or
redone. **Keep the best round:** if a round scores worse against targets and the
critic, revert to the better one unless it applies a user note; ship the best,
not the last.

## 4. Report

In the report (`agent-report`): the critic's final verdict and scores verbatim,
targets against final numbers, the lint summary line, the sheet paths, what the
critic listed as unseen, and what's untested in play. When the user approves the result, save the final sheet
to `docs/reference/approved/<discipline>/` with one line in its README (the
user's words if they said any). That gallery is the bar the next critic judges
against.
