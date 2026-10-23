# Character creator

## Purpose
The screen a player sees on joining: pick a starting outfit (shirt and pants),
hair (any catalog hair accessory by id, plus a colour), see the race and last name
the server rolled for them (paid rerolls), type a first name on the pedestal under
their character, and enter the world.
It's a template: the look and every list come from config, and the gameplay hooks
(saving, what a race does) plug in later.

## Design intent
- Three columns (user's reference images, 2026-10-22): the left nav (Clothes,
  Hair, Identity, Confirm: dark jade plates with gold rims, the chosen one cream
  and gold), the R6 character in the centre (a ViewportFrame, drag to turn), and a
  parchment panel on the right with the chosen tab's controls. Every tab uses the
  same panel, section headers ("◆ Name ———"), padding and selection mark (gold
  glow and check).
- The screen sits on the live sect world, as if the player stands on a stone
  pillar looking over the sect (the user's fourth reference: the real map from a
  high peak). The camera parks at a vantage over the map with a slow sway, a
  light blur and a vignette behind the panels. No menu-only scene. Where there is
  no `Workspace.Map` (the bare testbed) or `Background.Mode = "Image"`, a full-screen image (or a
  plain ink-wash gradient) stands in.
- Exactly what the user asked for and no more: two clothing categories (no robes,
  belts, accessories); hair is an asset id and a colour (no hairstyle grid); race
  and last name are rerolled for Robux (a race or variant can be picked only where
  Availability makes it Select or Unlock; the picker stays hidden otherwise); the summary has no
  titles, roots or stats.
- Native Roblox UI plus art the game already uploaded; no new drawn art (the user
  asked for something achievable without many custom images).
- The server decides everything random, persistent or paid. The client only
  previews: it can't set its race or last name, a hair id is checked against the
  catalog (asset type HairAccessory) before anyone sees it, Enter World is checked
  again in full (clothing ids from config, colour from config, first name through
  Roblox's text filter), and a paid reroll happens only in the receipt handler.

## Key files
- `src/shared/CharacterCreator/` (`ReplicatedStorage.Shared.CharacterCreator`), one
  module per thing to tune:
  - Races moved to `Shared.Identity` (Races, Beast Folk variants, traits and who can get them): see [identity](identity.md). The race block shows race and variant ("Beast Folk (Wolf)"), and the odds list only the races the roll can give.
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
  rarity pill, Robux button, summary row, text field, all cloned from the GUI's
  `Templates`), Preview (viewport dummy; it makes the viewport's Camera itself, since a
  Camera saved inside a ViewportFrame is lost in the Rojo sync), NamePlate (the
  full name on the pedestal, first name typed in place), Backdrop (live camera or image), Bridge
  (every server call, plus the `onEnterWorld` hook), Tabs/* (one per tab),
  Controller (`init`, `open`).
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
  rarest first, the player's own marked (user, 2026-10-23); for a race with variants
  (Beast Folk) its rollable variants follow the race block the same way, rebuilt when the
  race changes (Hidden and Disabled ones never show). The default outfit is
  the ranger shirt and pants, which are template images (`Clothing.Template`), so
  they're worn as is rather than looked up in the catalog.
- The name lives on the pedestal, not in a tab (user, 2026-10-23): the front band
  of the jade pedestal under the preview shows the full name, last name first as on
  the namecard ("Li Wei"), with the first name typed in place (`Root.Preview.NamePlate`,
  `NamePlate.luau`): same `Rules.checkFirstName` messages in a status line under the
  band, a counter while the box has focus, state `FirstName` for Confirm. The plate
  sits at a fixed share of the preview's height (the camera keeps 9 studs in view),
  and `Controller.fit` scales it with the preview (`NamePlate.Fit`). The Identity tab
  keeps the race and last-name blocks with their paid rerolls; Confirm's first-name
  blocker says "Type it under your character" and Enter World puts the cursor there.
- Race and last-name notes wrap and their card grows to fit (Beast Folk shows the
  race and variant descriptions together, the longest note).
- While the screen is open `Menus.setScreen(true)` makes `Menus.isOpen()` true,
  so combat, prompts and anything else gated on an open menu stay shut, even when
  the screen is reopened over a live character.

## Screen layout
- `PlayerGui.CharacterCreator` (DisplayOrder 20, ignores the inset, starts
  disabled; `Controller.open` enables it): `Backdrop` (image, mist, vignette),
  `Root` (`Nav`, `Preview`, `Panel`), `Veil` (open/close fade) and `Templates`
  (a hidden Frame of everything Components clones, plus the R6 `Dummy`).
- Nav and Panel are authored at a design size (250x380 and 520x740) and scaled
  together by their `Fit` UIScale: `clamp(min(H / 790, (W - 224) / 770), 0.66, 1.25)`
  (`Theme.Fit`). The preview fills the gap between them. At a 750x340 phone
  the scale floors at 0.66 and the panel scrolls.
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
- The first name and look aren't saved: a rejoin shows the screen again (race, variant and last name are saved in the profile's `identity`, see [identity](identity.md)). Wire `onConfirmed` into `PlayerData` to keep the rest. The paid race reroll is now safe to make live; the surname reroll too.
- Apart from the ranger shirt and pants, clothing ids and product ids are
  placeholders (0): those outfit cards show names only and dress nothing until
  real catalog ids or templates go in.
- Last names are placeholders with no gameplay effect; races now carry innate traits and modifiers ([identity](identity.md)), with first-guess values.
- Hair loads through `InsertService:LoadAsset`; a catalog hair Roblox won't load
  that way is refused with "That ID isn't a hair accessory".
- Untested in play: everything (drag-rotate, server calls, hair and clothing on
  the viewport dummy, the purchase prompt and its 60 s wait, the live backdrop
  camera and its restore, hiding the HUD, the tab and open/close fades). The
  layout was previewed in Studio's edit view only, at 1673x793 and 750x340
  (screenshots in the project files, `character-creator/`).
- The `templates` reply is a table keyed by catalog id; over a RemoteFunction a
  sparse numeric-key table can arrive with string keys, so the client looks ids
  up both ways.
