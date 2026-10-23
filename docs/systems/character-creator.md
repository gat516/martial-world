# Character creator

## Purpose
The join screen's creator: pick a starting outfit (shirt and pants), skin, hair
(any catalog hair accessory by id, plus a colour), see the race and clan the
server drew for the slot (paid rerolls), choose a first name, and enter the
world. It opens from the slot screen ([save slots](save-slots.md)) for a new
character, or on a slot's look to edit it. It's a template: the look and every
list come from config, and the gameplay hooks (what a race does) plug in later.

## Design intent
- **Calm and readable** (user, 2026-10-23: the old screen was "tacky", "a bunch
  of stuff thrown at me", "hard to read", "the ornaments just dont really fit";
  "rethink the layout and flow but keep the current features"). This replaces
  the earlier "richly ornamented" brief. One thing at a time: the character on a
  stage, one panel beside it with one step showing. High contrast (cream on the
  kit's navy, gold labels, lacquer only for what needs fixing). A few kit pieces
  that fit: the item-slot frame (panel, cards, swatches, fields, buttons; the lit
  frame marks a selection and the primary button), one diamond divider, the
  back seal. No crests, studs, corner sets, halos, ink wash, vignette or seals.
- **Calm motion:** a 0.15 s fade and 8 px slide between steps, Motion's hover and
  press on buttons. No flashes, shakes, pulses or full-screen darkening.
- **Mobile first:** the panel scales with the screen height and floors at 0.8, so
  phone text stays ~13-16 px and buttons ~45 px; the page scrolls and the
  character keeps the rest of the width.
- **Obvious gating** (user, 2026-10-23: "don't let me move on without picking
  something that's required, and make it really obvious"): only the first name
  is required, and Enter World sits right under it on the last step. Until it's
  valid the field's frame is lit, the line under it says what's needed, Enter
  World is dimmed and the footer says "Choose a first name to enter the world";
  pressing Enter World focuses the field (keyboard only).
- Exactly what the user asked for and no more: two clothing categories, hair is
  an asset id and a colour, race and clan can't be picked (only rerolled for
  Robux), no titles, roots or stats.
- The screen sits on the live sect world, as if the player stands on a high
  pillar (the camera parks at a vantage with a slow sway and a light blur). No
  menu-only scene. Where there is no `Workspace.Map` (the bare testbed) or
  `Background.Mode = "Image"`, a full-screen image (or a plain gradient) stands in.
- The server decides everything random, persistent or paid. The client only
  previews: it can't set its race or clan, a hair id is checked against the
  catalog (asset type HairAccessory) before anyone sees it, Enter World is
  checked again in full (clothing ids from config, colours from config, first
  name through Roblox's text filter), and a paid reroll happens only in the
  receipt handler.

## Flow
- **New** (from the slot screen's Create, or Name & play on a migrated profile):
  steps Appearance (skin, shirt, pants), Hair (up to 3 ids, colour), Name (first
  name, then the race and clan rows with Change, a note that they stay with the
  slot, and a link to the odds). Tabs at the top of the panel jump between
  steps; the footer has Back (on the first step: back to the slots) and "Next:
  <step>", or Enter World on Name.
- **Edit** (Edit look): the same steps, the last one titled Identity with the
  first name shown locked ("A cultivator's name is set once"); rerolls still
  work there. Footer: Cancel and Save look (on every step). Save returns to the
  slot screen.
- Defaults: the ranger shirt and pants, the avatar's own skin, the first hair
  colour, the avatar's own hairs (up to 3; edit starts from the slot's saved
  look). `State.missing` is the one list of what blocks Enter World.
- The Odds card (centred, no dimming) lists every race and clan with its rarity
  and chance, rarest first, the player's own marked.

## Key files
- `src/shared/CharacterCreator/` (`ReplicatedStorage.Shared.CharacterCreator`), one
  module per thing to tune:
  - `Races.luau`: races (DisplayName, Description, Rarity, Weight, Icon).
  - `Surnames.luau`: last names / clans (DisplayName, Glyph, Rarity, Weight).
  - `Rarities.luau`: tiers (label, colour, order), shared by races and clans.
  - `Clothing.luau`: Shirt and Pants options (Id, DisplayName, catalog AssetId or
    Template image, optional Thumbnail).
  - `HairColors.luau`, `SkinColors.luau` (the first, `Avatar`, keeps the player's own skin).
  - `Products.luau`: reroll developer product ids and the price shown.
  - `Background.luau`: Live or Image, vantage tag / CFrame, sway, blur, fallback image.
  - `Rules.luau`: when the screen shows (`SHOW_ON_JOIN`), whether a spawn wears
    the look (`APPLY_TO_CHARACTER`), first-name length, hair asset types, the
    weighted roll, name and id checks, hair tinting.
- `src/server/CharacterIdentity.luau`: rerolls (receipt handlers), hair loading,
  `confirm` (new slot or edited look, through `Slots`), `enter` (the played slot's
  identity, look and spawn); hooks `onConfirmed`, `onRerolled`.
- `src/client/CharacterCreator/`: Theme (colours, tweens, steps, fit), State (the
  previewed look; `load` starts over from a look), Components (tab, section, note,
  link, card, swatch, text field, fate row, slot card, odds row, all cloned from
  the GUI's `Templates`), Look (a whole look on the preview), Preview (viewport
  dummy; it makes the viewport's Camera itself, since a Camera saved inside a
  ViewportFrame is lost in the Rojo sync), Backdrop, Bridge (every server call),
  Modals (odds, delete confirm), Tabs/Appearance, Hair, Name, Controller (`init`,
  `open`, the slot screen and the creator, `fit`).
- `assets/CharacterCreator.rbxmx` (`ReplicatedStorage.CharacterCreatorGui`): the
  ScreenGui and templates, including a plain R6 dummy for the preview. Built by
  `art/ui/creator/build_gui.luau` (run it with the Studio MCP in Edit, then export).
  `Main.client` clones it into `PlayerGui.CharacterCreator` at start, before the
  Hud exists: StarterGui only reaches PlayerGui once a character spawns.

## Screen layout
- `PlayerGui.CharacterCreator` (DisplayOrder 20, ignores the inset, starts
  disabled): `Backdrop` (image, mist), `Root` (`Preview`, `Nameplate`, `Panel`,
  `Modal`), `Veil` (open/close fade) and `Templates`.
- The panel is authored 480 design px wide and scaled by its `Fit` UIScale:
  `clamp(H / 900, 0.8, 1.4)` (`Theme.Fit`), 16 px from the right edge, centred
  vertically, at most 760 design px tall (the slot screen hugs its cards). Under
  600 design px (phones) the footer drops its divider. The preview fills the
  width to the left of it, the character centred there, with the nameplate
  (clan and first name over race) under it. Numbers checked: 1920x1080 scale
  1.2, panel 576x912 at x 1328-1904; 1366x768 scale 0.853, panel 410x649 (16 px
  margins); 844x390 scale 0.8, panel 384x358 at x 444-828, preview 16-428;
  667x375 scale 0.8, panel 384x343, preview 16-251.
- Panel: `Head` (step tabs, or the slot screen's title), `Pages` (a CanvasGroup of
  ScrollingFrames: Slots, Appearance, Hair, Name; each canvas follows its list),
  `Footer` (divider, a status line, `Buttons`: Quiet (Delete), Secondary, Primary).
- Buttons with a `Motion` UIScale get the shared hover and press (`Motion.buttons`).
- The preview dummy is anchored and turned with `PivotTo`; each hair accessory is
  anchored and placed by matching its Handle attachment to the dummy's (else the
  head top + `AttachmentPoint`). "Drag to turn" hides after the first drag.

## Joining the world (test place)
- Nobody stands in the world behind the screen: the test place has
  `Players.CharacterAutoLoads` off, so a player has no character until a slot is
  played; `CharacterIdentity.enter` spawns them (`LoadCharacter`) once the join
  has finished on that slot. With auto loading off Roblox doesn't respawn the
  dead, so `CharacterIdentity` does, after `Players.RespawnTime` (the death screen
  shows meanwhile).
- Every spawn wears the slot's look on a clean body: the chosen skin colour (or
  the avatar's own), its hairs, the default head and the classic face, no other
  accessories. Hairs go on with `Humanoid:AddAccessory` from the same
  InsertService copies the preview used.
- Closing the screen hands the camera back as Custom. While open
  `Menus.setScreen(true)` keeps combat, prompts and menus shut.

## Data flow
Join -> the client asks `slots` (Bridge) and opens the slot screen unless a slot
is already played (QuickPlay) -> New / Edit: `new, id` or `edit, id` -> the
server shows the slot's race and clan as `Race` / `Surname` attributes ->
`state`, `templates` and `defaults` as before (the avatar's skin and hairs, once)
-> picks update the preview locally -> Apply hair: `hair, id` -> the server checks
the catalog and hands back a preview copy -> Change Race / Clan: `reroll, kind`
for the open slot -> live product: the slot is remembered (`Account.rerollFor`),
the client prompts the purchase and `Receipts` calls the reroll; mock (id 0,
Studio or testbed): rerolled at once -> Enter World / Save look: `confirm, look`
-> the server checks everything and fills the slot (new: and plays it) -> the
screen fades out once the character is in. Slot looks are stored in the slot's
profile (`character.look`, `character.firstName`).

## Tuning knobs
- Add a race, clan or rarity tier: edit its module only; the chance is
  Weight / total weight.
- Outfits, colours, prices, product ids, name length, backdrop: their modules
  above. Colours, sizes and fit of the screen: `Theme.luau` and the builder.
- Moving the backdrop view: tag a part `CharacterCreatorVantage` in
  `Workspace.Map` (its CFrame is the camera), or edit `Background.VantageCFrame`.
- Preview framing and drag feel: constants at the top of `Preview.luau`.

## Known gaps
- Test place only until the user approves it. The GUI, `CharacterAutoLoads =
  false` and `QuickPlay` are in `test.project.json` only; `Main.client` inits the
  screen and `Main.server` starts `CharacterIdentity` only under `Config.TESTBED`;
  `Rules.SHOW_ON_JOIN` and `Config.Slots.ENABLED` are `Config.TESTBED`. Shipping
  it: map the GUI and the Players property in `default.project.json`, drop those
  checks, and follow the save-slot release note ([save slots](save-slots.md)).
- No title screen yet (user, 2026-10-23); the slot screen is the first screen.
- The chosen hair colour tints every hair, the avatar's own included.
- Apart from the ranger shirt and pants, clothing ids and product ids are
  placeholders (0). Races and clans have no gameplay effect yet.
- Hair loads through `InsertService:LoadAsset`; a catalog hair Roblox won't load
  that way is refused with "That ID isn't a hair accessory".
- Untested in play: everything (server calls, the flow between the slot screen
  and the creator, rerolls, hair on the dummy, the backdrop camera). The layout
  was previewed in Studio's Edit view with sample data at 1616x784 and 844x390.
- The `templates` reply is a table keyed by catalog id; over a RemoteFunction a
  sparse numeric-key table can arrive with string keys, so the client looks ids
  up both ways.
