# Character creator

## Purpose
The join screen's creator. A new character gets one page (the front door): the
race and clan the server drew for the slot, a drawn first name to keep or
change, and Enter World. Edit look (from the slot screen, or from the world for
the Self card) has the full steps: a starting outfit (shirt and pants), skin,
hair (any catalog hair accessory by id, plus a colour), the race's free looks
(tail and ear shapes and the like). A new account with no character skips the
slot screen ([save slots](save-slots.md)) and opens on the first-character page. It's a template: the look and every
list come from config; what a race does is [identity](identity.md).

## Design intent
- **Calm and readable** (user, 2026-10-23: the old screen was "tacky", "a bunch
  of stuff thrown at me", "hard to read", "the ornaments just dont really fit";
  "rethink the layout and flow but keep the current features"). This replaces
  the earlier "richly ornamented" brief. One thing at a time: the character on a
  stage, one panel beside it with one step showing. High contrast (cream on the
  kit's navy, gold labels, lacquer only for what needs fixing).
- **Matches the rest of the UI** (user, 2026-10-23, on the curl frame on every
  swatch and card: "ts does not match at all"; taste reference
  [hud_vitals_reference.webp](../reference/ui/hud_vitals_reference.webp)). The same
  house pieces as the Inventory ([inventory](../ui/inventory.md)): the house window
  frame (`panel_frame.png`) on the panel and the modal cards; the Inventory's gold
  and lacquer pills for the step tabs (gold = current) and every button (gold = the
  one thing to press); plain ink wells (`slot_plain.png`) with a thin dim edge
  (`slot_edge.png`) for swatches, arrow pickers, slot cards, text fields and the
  race and clan rows, the chosen one wearing the Inventory's cream ring 3 px
  outside; the slot screen's title on the gold house plaque (`Ribbon.luau`,
  [ribbons](../ui/ribbons.md)); one diamond divider; the Inventory's close seal on
  the odds card. No ornament on anything that repeats; no crests, corner sets,
  halos, ink wash, vignette or seals.
- **Arrows, not grids** (user, 2026-10-23: "these basically need to shift to
  arrows"). Shirt, pants and a race's looks are each one arrow picker: a lacquer
  arrow at each end, the pick's name centred with "1 / 3" under it, wrapping round.
  The big preview character shows the pick; there are no per-option thumbnails.
- **The front door** (user, 2026-10-24: "i like the front door idea, do it";
  [first-session review](../design-reviews/first-session.md) rec 1): join to the
  world in about 20 s, not 1.5-4 minutes of menus in Roblox's bounce window. A
  first character is one page: the Fate reveal (the drawn race and clan, each
  with its rarity beside its value in the rarity's colour; the reveal is the
  hook), the first name already filled with a drawn cultivator name
  (`GivenNames`; "New name" draws another, typing still works, so a phone needs
  no keyboard), the odds button, and a big gold Enter World (76 design px, 61 px on
  a phone). The look starts on the preset (the ranger outfit, the avatar's own
  skin and hair) and changes later through Edit look. No paid buttons. Picked by
  two critic rounds over a variant with the reveal only on the stage nameplate
  (2026-10-24; not yet approved by the user).
- **Paid rerolls are off** (user, 2026-10-24): Change Race / Change Clan are paid
  random rolls that carry stats; bloodlines will replace them. `Config.PAID_REROLLS`
  (false) hides the buttons and the server refuses `reroll`; the products, the
  receipt handlers and the reroll code stay, so turning it on brings them back.
- **Fate has its own step** in Edit look (user, 2026-10-23): race, the race's
  free looks under "Look" (hidden when it has none), clan (each with a paid
  Change while rerolls are on), the note and the odds button. Traits come only with
  rolled variants; looks carry no stats, so they're free ([identity](identity.md) Looks).
- **The odds are a button** (user, 2026-10-24: "the odds of race should be a
  button"; Roblox's paid-random-items guidance prefers a labelled button over a
  bare link): a lacquer pill like Back and New name, 200x56 design px (160x45 on
  a phone), a gold "%" glyph before "See the odds", centred in its own row under
  the clan row on the first-character page and after the note on the Fate step.
  It opens the Odds card. The `%` is live text, not art.
- **Calm motion:** a 0.15 s fade and 8 px slide between steps, Motion's hover and
  press on buttons. No flashes, shakes, pulses or full-screen darkening.
- **Mobile first:** the panel scales with the screen height and floors at 0.8, so
  phone text stays ~13-16 px and buttons ~45 px; the page scrolls and the
  character keeps the rest of the width.
- **Obvious gating** (user, 2026-10-23: "don't let me move on without picking
  something that's required, and make it really obvious"): only the first name
  is required (and starts filled). Until it's valid the field's edge is gold, the
  line under it says what's needed, Enter World is dimmed; pressing Enter World
  focuses the field (keyboard only).
- Exactly what the user asked for and no more: two clothing categories, hair is
  an asset id and a colour, race and clan can't be picked (only rerolled for
  Robux while that's on; the race reroll draws a variant too), no titles, roots or stats.
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
- **New** (an account's first join, the slot screen's Create, or Name & play on
  a migrated profile): one page (`Tabs/Begin`, `Pages.Begin`) under the "Your
  fate" plaque (dropped on phones so the page fits unscrolled): the race row
  ("Race" over "Spirit Fox Rare", the value a size up), the clan row, the
  odds button ("% See the odds", a centred lacquer pill), the name field with "New
  name". No "You will be known as" line: the nameplate under the character shows
  the full name as it changes. Footer: the big Enter World, and Back (to the
  slots) only when the account has a character. The race's looks keep their
  defaults until Edit look.
- **Edit** (Edit look): Appearance (skin, shirt, pants), Hair (up to 3 ids,
  colour), Fate (race, an arrow picker per look the race has, clan, a note that
  they stay with the slot, the odds button), Name (the first name locked: "A
  cultivator's name is set once"). Tabs at the top jump between steps. Footer:
  Cancel and Save look (on every step). Save returns to the slot screen, or, when
  opened from the world (`Controller.editLook()`, for the Self card to call), the
  server dresses the character in the new look and the screen hands the world back.
- Defaults: the ranger shirt and pants, the avatar's own skin, the first hair
  colour, each look's first option (a race reroll resets the looks to the new
  race's defaults), the avatar's own hairs (up to 3; edit starts from the slot's saved
  look). `State.missing` is the one list of what blocks Enter World.
- The Odds card (centred, no dimming) lists every race and clan with its rarity
  and chance, rarest first, the player's own marked.

## Key files
- `src/shared/CharacterCreator/` (`ReplicatedStorage.Shared.CharacterCreator`), one
  module per thing to tune:
  - Races and their variants live in `Shared.Identity` ([identity](identity.md)).
    The race row shows race and variant ("Beast Folk (Wolf)", in the variant's
    rarity), the preview wears that race's look (ears, tail, horns, Giant size;
    [identity](identity.md) Cosmetics), and the odds card lists only what the roll can give: the races, then
    each race's variants with their chance within it.
  - `Surnames.luau`: last names / clans (DisplayName, Glyph, Rarity, Weight).
  - `Rarities.luau`: tiers (label, colour, order), shared by races and clans.
  - `Clothing.luau`: Shirt and Pants options (Id, DisplayName, catalog AssetId or
    Template image; `Thumbnail` is no longer shown: the picker shows the name and
    the preview wears it).
  - `HairColors.luau`, `SkinColors.luau` (the first, `Avatar`, keeps the player's own skin).
  - `Products.luau`: reroll developer product ids and the price shown.
  - `Background.luau`: Live or Image, vantage tag / CFrame, sway, blur, fallback image.
  - `Rules.luau`: when the screen shows (`SHOW_ON_JOIN`), whether a spawn wears
    the look (`APPLY_TO_CHARACTER`), the paid rerolls (`PAID_REROLLS`, from
    `Config.PAID_REROLLS`), first-name length, hair asset types, the weighted
    roll, name and id checks, hair tinting.
  - `GivenNames.luau`: the cultivator first names the first-character page draws
    from (each must pass `Rules.checkFirstName`).
- `src/server/CharacterIdentity.luau`: rerolls (receipt handlers), hair loading,
  `confirm` (new slot or edited look, through `Slots`), `enter` (the played slot's
  identity, look and spawn); hooks `onConfirmed`, `onRerolled`.
- `src/client/CharacterCreator/`: Theme (colours, pill art, well edge, tweens,
  steps, fit), State (the
  previewed look; `load` starts over from a look), Components (tab, section, note,
  odds button, arrow row, swatch, text field, fate row, slot card, odds row, all cloned from
  the GUI's `Templates`), Look (a whole look on the preview), Preview (viewport
  dummy; it makes the viewport's Camera itself, since a Camera saved inside a
  ViewportFrame is lost in the Rojo sync), Backdrop, Bridge (every server call),
  Modals (odds, delete confirm), Tabs/Appearance (skin, shirt and pants
  pickers), Hair, Fate (race, looks, clan, rerolls; options for Begin), Name
  (first name; a drawn name for Begin), Begin (the first-character page: Fate's
  and Name's rows with an order offset), Controller (`init`, `open`, `editLook`,
  the slot screen and the creator, `fit`, the title plaque).
- `assets/CharacterCreator.rbxmx` (`ReplicatedStorage.CharacterCreatorGui`): the
  ScreenGui and templates, including a plain R6 dummy for the preview. Built by
  `art/ui/creator/build_gui.luau` (run it with the Studio MCP in Edit, then export).
  `Main.client` clones it into `PlayerGui.CharacterCreator` at start, before the
  Hud exists: StarterGui only reaches PlayerGui once a character spawns.

## Screen layout
- `PlayerGui.CharacterCreator` (DisplayOrder 20, ignores the inset, starts
  disabled): `Backdrop` (image, mist), `Root` (`Preview`, `Nameplate`, `Panel`,
  `Modal`), `Veil` (open/close fade) and `Templates`.
- The first-character page (2026-10-24, sandbox Edit view, sample data, Spirit
  Fox / Li): the panel hugs the page (head 76, or 20 on a phone with no plaque;
  footer = Enter 76 + 30 for the divider off phones). With the odds button
  (same day): 844x390: panel 384x342 at y 24, page 247 px holding 235 px of rows
  (no scroll), the odds button 160x45, Enter 346x61; 667x375: panel 384x342 at
  y 17, the same rows; 1920x1080: panel 576x617, odds 240x67, Enter 518x91;
  1366x768: panel 410x439, odds 171x48, Enter 369x65; the odds button centred on
  the panel (dx 0.0) at every size. The race value is
  Merriweather 24 (19 px on a phone), the rarity beside it in its colour.
- The panel is authored 480 design px wide and scaled by its `Fit` UIScale:
  `clamp(H / 900, 0.8, 1.4)` (`Theme.Fit`), 16 px from the right edge, centred
  vertically, at most 760 design px tall (the slot screen hugs its cards). Under
  600 design px (phones) the footer drops its divider. The preview fills the
  width to the left of it, the character centred there, with the nameplate
  (clan and first name over race) under it.
- Measured 2026-10-23 (sandbox Edit view, sample data, the screen sized to each
  resolution): 1920x1080 scale 1.2, panel 576x912 at x 1328-1904 (slots 576x485),
  top and bottom margins equal (84 / 84); 1366x768 scale 0.853, panel 410x649 at
  x 940-1350; 844x390 scale 0.8, panel 384x358 at x 444-828, margins 16.2 / 16.2,
  preview 16-428; 667x375 scale 0.8, panel 384x342, preview 15.5-250.5. At every
  size: right margin 16, the tab row, card rows, slot cards and buttons inset 24
  design px on both sides (28.8 / 20.5 / 19.2 px), tab gaps equal, the plaque and
  its text centred on the panel (dx 0), every well, swatch chip and
  button label centred to 0.00 px, the delete card centred on the screen and its
  buttons 36 design px in on both sides. Four tabs (same day, 1920x1080 stage):
  inset 24.00 / 24.00, gaps 8.00; every arrow row 24 in on both sides, its
  arrows 6 in at each end and vertically centred (dy 0.00), the pick's name
  centred (dx 0.00); arrows 56 design px (44.8 px at the phone floor).
- Footer `Buttons` also holds `Enter` (the first-character page's gold pill,
  76 tall, `SliceScale` 0.59 so the whole 128 px pill height maps to it with true
  round ends, a `UIFlexItem` Fill so it takes the row beside Back, label Builder
  Sans Bold 24); `Primary` shows on every other screen.
- Panel: `Head` (step tabs: four 102x44 pills, 8 apart, filling the 432 px row,
  labels Builder Sans Bold 16; or the slot screen's title plaque, 48 tall, fitted to its text), `Pages` (a CanvasGroup of
  ScrollingFrames: Slots, Begin, Appearance, Hair, Fate, Name; each canvas follows its list),
  `Footer` (divider, a status line, `Buttons`: Quiet (Delete), Secondary, Primary).
- Wells (`Templates`): a swatch is a 60 px well with a rounded colour chip (8 px
  in); an arrow row (`ArrowRow`) is a 68 px well, a 56x56 lacquer pill with a
  chevron 6 px in at each end, the pick's name (Merriweather 20, RichText for a
  gold "Tail:" prefix) and "1 / 3" (Builder Sans Bold 15, muted) centred between;
  the arrows hide when there's only one option; each well's `Edge` is tinted (150, 140, 120) at 0.35, its `Halo` (cream ring)
  shows while chosen (`Components.setSelected`).
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
is already played (QuickPlay); an account with no filled slot opens straight on
`new` for slot 1 behind the veil -> New / Edit: `new, id`, `edit, id` or, from
the world, `editPlayed` -> the
server shows the slot's race and clan as `Race` / `Surname` attributes ->
`state`, `templates` and `defaults` as before (the avatar's skin and hairs, once)
-> picks update the preview locally -> Apply hair: `hair, id` -> the server checks
the catalog and hands back a preview copy -> Change Race / Clan (only while
`Config.PAID_REROLLS`; refused otherwise): `reroll, kind`
for the open slot -> live product: the slot is remembered (`Account.rerollFor`),
the client prompts the purchase and `Receipts` calls the reroll; mock (id 0,
Studio or testbed): rerolled at once -> Enter World / Save look: `confirm, look`
(Enter World also sends `NameSource`, Kept / Rolled / Typed, for the
`TimeToEnterWorld` analytics event) -> the server checks everything and fills
the slot (new: and plays it; an edit from the world: and dresses the character)
-> the screen fades out once the character is in. Slot looks are stored in the slot's
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
  placeholders (0). Clans have no gameplay effect yet; races carry innate traits
  and modifiers ([identity](identity.md)), with first-guess values.
- No picker for races or variants made Select or Unlock in Availability (none
  are today): the old Identity tab's card pickers went with the rewrite, and the
  creator runs before a slot is played, when Traits has no profile to check
  Requires against. `Traits.choose` is the server side for when one is designed.
- Hair loads through `InsertService:LoadAsset`; a catalog hair Roblox won't load
  that way is refused with "That ID isn't a hair accessory".
- The front door is untested in play: the skip for a new account (the testbed
  seeds a Tester in slot 1 on a first visit, so it shows the slot screen; an
  account with no slot sees the skip), the drawn name passing the text filter
  (a filtered name says "Choose a different name"; press New name), Edit look
  from the world (the Self card's Edit look button calls `Controller.editLook`),
  and the timings. Previewed in the sandbox's Edit view with the
  real Begin, Fate, Name and Components modules on sample data.
- With `PAID_REROLLS` off there's no way to change a drawn race or clan until
  bloodlines land.
- Untested in play: everything (server calls, the flow between the slot screen
  and the creator, rerolls, hair on the dummy, the backdrop camera, the arrow
  pickers, the Fate step, look picks on the preview and on the spawned
  character, a reroll resetting the looks). The layout was previewed in Studio's Edit view with sample
  data built from the templates, not the client modules.
- The placeholder outfits (AssetId 0, no template) show the bare body on the
  preview until they get real ids.
- Only Spirit Fox has looks to pick today (tail and ears, three each); the
  other races' cosmetics are single pieces, so their Fate step has no Look rows.
- The `templates` reply is a table keyed by catalog id; over a RemoteFunction a
  sparse numeric-key table can arrive with string keys, so the client looks ids
  up both ways.
