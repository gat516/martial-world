# Character creator

## Purpose
The screen a player sees on joining: pick a starting outfit (shirt and pants),
hair (any catalog hair accessory by id, plus a colour), see the race and last name
the server rolled for them (paid rerolls), choose a first name, and enter the world.
It's a template: the look and every list come from config, and the gameplay hooks
(saving, what a race does) plug in later.

## Design intent
- Three columns (user's reference images, 2026-10-22): the left nav (Clothes,
  Hair, Identity, Confirm), the R6 character in the centre (a ViewportFrame, drag
  to turn), and a parchment panel on the right with the chosen tab's controls.
  Every tab uses the same panel, section headers, padding and selection mark
  (gold glow and check).
- Richly ornamented (user, 2026-10-23: "it's character customization ... don't
  make it so minimal"), with a hierarchy so it stays readable: heaviest on the
  outer frames and titles, lighter on inner controls; gold, navy, cream and a
  little ruby. All art is the Figma kit's cut ornaments (see Art below); the flow
  and the required-field highlighting stay the clearest thing on screen.
- A guided flow (user, 2026-10-23: "don't let me move on without picking
  something that's required, and make it really obvious"): see Flow below.
- The screen sits on the live sect world, as if the player stands on a stone
  pillar looking over the sect (the user's fourth reference: the real map from a
  high peak). The camera parks at a vantage over the map with a slow sway, a
  light blur and a vignette behind the panels. No menu-only scene. Where there is
  no `Workspace.Map` (the bare testbed) or `Background.Mode = "Image"`, a full-screen image (or a
  plain ink-wash gradient) stands in.
- Exactly what the user asked for and no more: two clothing categories (no robes,
  belts, accessories); hair is an asset id and a colour (no hairstyle grid); race
  and last name can't be picked, only rerolled for Robux; the summary has no
  titles, roots or stats.
- Kit ornaments, not Roblox frames (user, 2026-10-23; this replaces the earlier
  "no new drawn art" rule). Nothing is repainted: pieces are cut from the Codex
  sheets, mirrored or joined (`art/ui/creator/build.py`).
- The server decides everything random, persistent or paid. The client only
  previews: it can't set its race or last name, a hair id is checked against the
  catalog (asset type HairAccessory) before anyone sees it, Enter World is checked
  again in full (clothing ids from config, colour from config, first name through
  Roblox's text filter), and a paid reroll happens only in the receipt handler.

## Key files
- `src/shared/CharacterCreator/` (`ReplicatedStorage.Shared.CharacterCreator`), one
  module per thing to tune:
  - `Races.luau`: races (DisplayName, Description, Rarity, Weight, Icon).
  - `Surnames.luau`: last names (DisplayName, Glyph, Rarity, Weight).
  - `Rarities.luau`: tiers (label, colour, order), shared by races and last names.
  - `Clothing.luau`: Shirt and Pants options (Id, DisplayName, catalog AssetId or Template image,
    optional Thumbnail).
  - `HairColors.luau`: the swatch list.
  - `SkinColors.luau`: skin swatches on the Clothes tab; the first, `Avatar`
    (no Color), keeps the player's own skin and is the default.
  - `Products.luau`: reroll developer product ids and the price shown.
  - `Background.luau`: Live or Image, vantage tag / CFrame, sway, blur, fallback image.
  - `Rules.luau`: when the screen shows (`SHOW_ON_JOIN`), whether Enter World
    dresses the live character (`APPLY_TO_CHARACTER`), first-name length, hair asset
    types, the weighted roll, name and id checks, hair tinting.
- `src/server/CharacterIdentity.luau`: rolls, rerolls (receipt handlers),
  hair loading, Enter World; hooks `onConfirmed`, `onRerolled`, `load(player, saved)`.
- `src/client/CharacterCreator/`: Theme (colours, fonts, sizes, tweens), State
  (the previewed look), Components (nav button, card, swatch, section header,
  rarity pill, Robux button, summary row, text field, keyplate, all cloned from
  the GUI's `Templates`), Preview (viewport dummy; it makes the viewport's Camera itself, since a
  Camera saved inside a ViewportFrame is lost in the Rojo sync), Backdrop (live camera or image), Bridge
  (every server call, plus the `onEnterWorld` hook), Tabs/* (one per tab),
  Controller (`init`, `open`, the step flow and footer, `fit`). State also says what
  is missing (`State.missing`).
- `assets/CharacterCreator.rbxmx` (`ReplicatedStorage.CharacterCreatorGui`): the
  ScreenGui shell and templates, including a plain R6 dummy for the preview.
  `Main.client` clones it into `PlayerGui.CharacterCreator` at start, before the
  Hud exists: StarterGui only reaches PlayerGui once a character spawns.

## Joining the world (test place)
- Nobody stands in the world behind the screen (user, 2026-10-23): the test place
  has `Players.CharacterAutoLoads` off (`test.project.json`), so a player has no
  character until Enter World, and the server's first `confirm` spawns them
  (`LoadCharacter`). With auto loading off Roblox doesn't respawn the dead, so
  `CharacterIdentity` does, after `Players.RespawnTime`.
- Every spawn wears the confirmed look on a clean body (user, 2026-10-23): the
  chosen skin colour (or the avatar's own), its chosen hairs (by default the avatar's own), the
  default head and the classic face, no other accessories. Hairs go on with
  `Humanoid:AddAccessory` from the same InsertService copies the preview used;
  `HumanoidDescription.HairAccessory` left newer hair off.
- Closing the screen hands the camera back as Custom: before a character exists
  it sits in Fixed, and restoring that left it parked at the vantage.
- The Identity tab lists every race and last name with its rarity and chance,
  rarest first, the player's own marked (user, 2026-10-23). The default outfit is
  the ranger shirt and pants, which are template images (`Clothing.Template`), so
  they're worn as is rather than looked up in the catalog.
- While the screen is open `Menus.setScreen(true)` makes `Menus.isOpen()` true,
  so combat, prompts and anything else gated on an open menu stay shut, even when
  the screen is reopened over a live character.

## Flow
- Steps in nav order: Clothes, Hair, Identity, Confirm. The panel's footer has
  Back (hidden on the first step) and the primary button, "Next: <step>" with the
  next step's glyph in its ring, or Enter World on Confirm. Above them a lacquer
  line says what's missing ("Missing: first name") whenever the primary is
  blocked.
- Required: only the **first name** (Rules.checkFirstName: 2-14 letters, then
  the server's text filter). Race and last name are the server's roll and only
  "missing" until the attributes land. Everything else starts picked and is
  harmless as a default: shirt and pants (the ranger outfit), skin (the avatar's
  own), hair colour (the first swatch), hair (optional, the avatar's own if any).
  `State.missing` is the one list of what blocks Enter World.
- Gating: a step after one with something missing is locked (Confirm, until the
  name is valid). Pressing a locked nav plate, the dimmed Next or Enter World
  jumps to the first missing field: its step opens, its nav plate shakes, the
  page scrolls to it, the field's rim flares lacquer and (keyboard only) takes
  focus. Tabs register how to show a field with `ctx.registerField`.
- Nav plate states: current (lit plate, ruby on its tip, slid right), done
  (visited and complete: gold check), missing (lacquer "!"), locked (dimmed,
  lock), not yet visited (plain).
- Missing fields are obvious: the First Name header carries a lacquer "Required"
  tag, the empty field reads "Choose a first name" with a gold rim and a lacquer
  "Required: 2 to 14 letters." line, the Confirm summary shows "Not chosen" in
  lacquer (pressing it jumps to the field), and the name plinth under the
  character reads "Choose a first name" until one is typed.
- Client gating is only UX. The server's `confirm` checks everything again,
  including that the race and last name have been rolled.

## Art
Cut ornaments from the kit (`art/ui/codex/cut/ornament_*.png`, copied from
`ui-assemble`), assembled by `art/ui/creator/build.py` into `art/ui/creator/out/`
(mirrored corner sets, the three-part response button joined so it 9-slices),
uploaded with ids in `art/ui/assets.json`:
- Panel: `window_corner` set on the parchment, ruby studs on the side rims, the
  `title_crest` plaque with the step title on its band and the subtitle under it,
  `divider_cloud` rules in section headers (gold stud before the label),
  `divider_diamond` over the footer.
- Nav: a navy column with the `window_corner_small` set and gold studs; each step
  is a `response_button` plate (glyph in its ring, label on the bar), the current
  one `response_button_hi` with a ruby on its tip; status marks are the kit's
  checkmark and its white `glyph_exclaim` / `glyph_lock`, tinted.
- Footer: Back is a plate with the kit chevron in its ring, the primary is the lit
  plate (its baked chevron points on).
- Preview: the `portrait_corner` set frames it, a faint `dao_ring` halo sits
  behind the head and chest, an `inkwash_a` cloud at the feet, the screen title
  between two `name_scroll` flourishes on top, and a `seat_plate` name plinth at
  the bottom with the family glyph on a `seal_square` chop.
- First-name field: the family glyph on a `keyplate` before it.
- 9-slice note: Roblox mangles a slice whose centre is taller than its corners
  (the caps render magnified and cropped), so the plate slices with a thin centre
  band (`Rect(381, 100, 438, 120)`, `SliceScale` = height / 221) and the rule with
  `Rect(100, 38, 924, 43)`. The Fit UIScale scales slices along with everything
  else; don't scale `SliceScale` by hand.

## Screen layout
- `PlayerGui.CharacterCreator` (DisplayOrder 20, ignores the inset, starts
  disabled; `Controller.open` enables it): `Backdrop` (image, mist, vignette),
  `Root` (`Nav`, `Preview`, `Panel`), `Veil` (open/close fade) and `Templates`
  (a hidden Frame of everything Components clones, plus the R6 `Dummy`).
- Nav and Panel are authored at a design size (270x440 and 520x740) and scaled
  together by their `Fit` UIScale: `clamp(min(H / 790, (W - 224) / (nav + 520)), 0.66, 1.25)`
  (`Theme.Fit`); both shorten to the screen height. The preview fills the gap
  between them. When that gap would be under 240 px (phones) the nav turns
  compact: only the plates' glyph rings (104 px wide), status marks on the rings'
  shoulders. At a phone the scale floors at 0.66 and the panel scrolls.
- Tab pages are ScrollingFrames in the `Pages` CanvasGroup, so a tab switch fades
  and slides the whole page. Each page's canvas follows its list's content size.
- Buttons with a `Motion` UIScale get the shared hover and press (`Motion.buttons`).
- Hair: up to `Rules.MAX_HAIRS` (3) accessories, one id field each (user,
  2026-10-23); an emptied field takes its hair off. The fields start with the
  player's own Roblox hair (the server's `defaults`), and the preview takes the
  avatar's skin until a character exists.
- The preview dummy is anchored and turned with `PivotTo`; each hair accessory is
  anchored and placed by matching its Handle attachment to the dummy's (else the
  head top + `AttachmentPoint`).

## Data flow
Join -> server rolls `Race` and `Surname` (player attributes) -> client opens the
screen if `Rules.SHOW_ON_JOIN` and `CharacterConfirmed` isn't set -> `CharacterAction`
`state` (prices, live or mock), `templates` (catalog id -> clothing image, looked
up once by the server) and `defaults` (once: the avatar's skin and up to 3 hairs,
each with a preview copy) -> picks update the preview locally -> Apply hair:
`hair, id` -> server checks the catalog, loads the accessory, puts a copy in that
player's `PlayerGui.CharacterPreview` and returns it -> preview wears and tints it.
Change Race / Last Name: `reroll, kind` -> live product: client prompts the purchase
and `Receipts` calls the reroll; mock (id 0, Studio or testbed): rerolled at once ->
the attribute changes and the screen updates. Enter World: `confirm, look` -> server
checks everything (each of `HairIds`), sets `FirstName` and `CharacterConfirmed`,
spawns the character if there is none yet, dresses it (and again on respawn), runs `onConfirmed` -> the screen fades out and gives the
camera and HUD back.

## Tuning knobs
- Add a race, last name or rarity tier: edit its module only; the chance is
  Weight / total weight.
- Outfits, hair colours, prices, product ids, name length, backdrop: their modules
  above. Colours, fonts and sizes of the screen: `Theme.luau`.
- Moving the backdrop view: tag a part `CharacterCreatorVantage` in `Workspace.Map`
  (its CFrame is the camera), or edit `Background.VantageCFrame`. The default is
  high above the East Sentinels karst pillar (400, 880, 420) looking west at
  MainPeak and its ring of spirit peaks. A place without
  `Workspace.Map` (the bare testbed) ignores `VantageCFrame` and shows the image
  unless a tagged part exists.
- Preview framing and drag feel: constants at the top of `Preview.luau`.

## Known gaps
- Test place only until the user approves it (user, 2026-10-22: it syncs to the
  test place alone). The GUI and `CharacterAutoLoads = false` are in
  `test.project.json` only, not `default.project.json`; `Main.client` inits the
  screen and `Main.server` starts `CharacterIdentity` only under `Config.TESTBED`;
  `Rules.SHOW_ON_JOIN` is `Config.TESTBED` too. Shipping it: map the GUI and the
  Players property in `default.project.json` and drop those three checks. Check
  first that nothing in the main game expects a character at join.
- No title screen yet: the user wants joining to land on a title or menu screen
  first (2026-10-23). For now the character screen is that first screen.
- The chosen hair colour tints every hair, the avatar's own included (it starts
  Ink Black), so their hair loses its texture. A "natural" option is a next step.
- Nothing is saved: race, last name, first name and look live for the session, so
  a rejoin rolls again and shows the screen again. Wire `CharacterIdentity.load`
  and `onConfirmed`/`onRerolled` into `PlayerData` to keep them. Until then, don't
  create the live reroll products (a bought reroll would be lost on rejoin).
- Apart from the ranger shirt and pants, clothing ids and product ids are
  placeholders (0): those outfit cards show names only and dress nothing until
  real catalog ids or templates go in.
- Races and last names are placeholders with no gameplay effect.
- Hair loads through `InsertService:LoadAsset`; a catalog hair Roblox won't load
  that way is refused with "That ID isn't a hair accessory".
- Untested in play: everything (drag-rotate, server calls, hair and clothing on
  the viewport dummy, the purchase prompt and its 60 s wait, the live backdrop
  camera and its restore, hiding the HUD, the tab and open/close fades, the
  gating, the nudge and focus). The layout was previewed in Studio's edit view
  only (stubbed server), at 1914x793 and phone sizes.
- The Change Race / Last Name Robux buttons and the hair Apply button still use
  the older Pillow button art; a kit restyle (plate or Button/Solid) is a next step.
- The name plinth's ink-wash and halo sizes are tuned by eye at desktop size.
- The `templates` reply is a table keyed by catalog id; over a RemoteFunction a
  sparse numeric-key table can arrive with string keys, so the client looks ids
  up both ways.
