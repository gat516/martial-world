# Character window

Covers the character window (Self card), the root reveal card, how they open and how the window grows with the player; read it when working on `SelfCard`, `RootReveal` or the Self tile. Shared HUD rules are in [ui](../systems/ui.md).

**Where weapons live:** weapons and Dao comprehension are in the Inventory's
Weapons & Arts tab. The character window names no weapons; it lists the Weapon
Dao of every class trained (level, progress, what it gives).

**The reveal card** (`src/client/RootReveal.luau`, `Hud.RootReveal`): on the
local player's first test (Effect "root" with `first`), a small centre card: the
element's seal (`art/ui/draw_icons.py`, `icon_Root<Element>`) on rays in its
colour, "Spirit Root", the element's name, the grade in its colour and the
one-line perk. Rare roots add a gold ring round the seal and a "RARE!" tag. A tap
closes it after a beat, or it closes itself after 6 s. A repeat test shows no card
(the server toasts).

**Opening it:** the **Self tile** at the right end of the top-right row
(`Hud.Buttons.SelfButton`, after Inventory; a bust with a topknot, `art/ui/draw_ui.py`
`self_icon`; it stays in combat, since it holds Settings). It always shows; until the
root is tested it opens Settings directly. When the reveal card closes it pops in,
swells once and wears a small seal dot until the window is first opened (not saved
across sessions). **Header seals** (four-tile row, user 2026-10-24): left of the close
seal, two 44 px round seals (the touch cluster's seal art) with cream glyphs: **People**
(two busts, `draw_ui.py people`, composited from `self_icon`; only while `InSafeZone`)
opens Social's People list, **Settings** (the gear) the Settings window; closing either
by its own seal comes back to the card (`Menus.openFrom`). On phones the tab row is
96 px shorter to make room. Its close seal shuts the card (the
top-right tiles fade away while any window is open). Tapping the **realm
crest** in the vitals (`Crest.Open`) is a shortcut to the same card, with no dot of
its own. The elder pointing at it is still to do.

**Built (v3, 2026-10-23, `src/client/SelfCard.luau`, `Hud.SelfCard`, built by
`tools/build_self_card.luau`).** The user: "redesign the self card entirely. make it
as big as inventory ui, and then display different things at once cleanly without
overwhelming the player." Inventory-sized (0.94 x 0.86 of the screen, at most
760x500, centred; the Inventory's frame, title plaque "Self" and close seal), with
three areas at once. Chosen over "ink wells" (each column in a dark inset well:
boxes in a box, and it overflowed) and "portrait hero" (name and race over the
avatar's foot); runner-up: ink wells.
- **Desktop** (`SelfCard.Desktop`): three columns, Self 179 px | Cultivation 258 |
  Path 237, 22 px inset from the frame like the Inventory, 1 px gold hairlines
  10 px from each column, each a title (Merriweather 15) over a hairline rule and
  a scrolling `Body`. Every column fits 406 px with all sections folded, so
  nothing scrolls until a detail opens.
- **Phone** (`SelfCard.Phone`, `UiScale.isPhone()`): the Inventory's tab pills
  (Self | Cultivation | Path, gold when chosen) at the top, the title plaque
  hidden, and one page at a time, each in two columns: Self (the avatar | who
  you are), Cultivation (Realm, Dantian, Heart | Foundation), Path (Root,
  Method | Weapon Dao). On a short screen Menus moves the window under Roblox's
  top bar (705x299 from y 62 at 844x390; 627x305 at 667x375), and every page fits
  without scrolling (219 and 225 px). Body text 14 px, labels 12 px.
- **Sections**, one shape for all (the 2026-10-21 decision kept: labelled by
  kind, effects only, gains in jade, losses in a muted red, numbers from the
  shared defs): `Kind` (small gold capitals, with a "+" when it has detail),
  `Top` (`NameLabel`, with `Right` taking only its text's width), an optional
  8 px `Bar` (dark trough with a faint gold edge; its value is the `Right` label,
  never text on the bar), `Summary` (a few lines at a glance) and `Detail` (the
  exact numbers, hidden). **Tap a section to expand it in place** ("+" turns to
  "–"); every detail folds again when the window reopens. A faint wash on hover.
- **Self:** the avatar, a still copy of your own character in a plain ink well
  (`slot_plain`; `Avatar.View`, a ViewportFrame with a WorldModel and a camera
  made in code, three-quarter turn, lit from the upper left, rebuilt on each
  open and on respawn), **Edit look** under it (a lacquer pill, 32 px on PC in
  its own `EditLookRow`, 44 px at the foot of the phone's avatar column; it closes
  the card and calls `CharacterCreator.Controller.editLook()`, the creator's
  Appearance, Hair, Fate and Name steps on the played slot; shown only while
  `Shared.CharacterCreator.Rules.SHOW_ON_JOIN` is on, today the testbed, and on a
  phone the well takes its room when hidden), your name (`Nameplates.nameOf`:
  "Surname FirstName") with the **worn title** under it (`TitleRow`, below),
  **Race** (race · variant, the rarity on the right in its lifted colour; the
  summed race, variant and innate-trait modifiers in the detail; hidden before a
  race is set), **Bloodline** (deferred, [bloodline](bloodline.md): always
  "None", muted, no detail) and **Strength** ("120 health", "Power x1.26" on the
  right: the realm's power times the foundation bonus, as `Combat.power` minus a
  qi surge; the split in the detail).
- **Cultivation:** **Realm** (the stage name in gold, its bar with the share on
  the right, "Next: Qi Condensation 4" or "Ready to break through"; the exact
  cultivation in the detail). **Foundation** (the user: "players should
  optionally try to solidify their breakthrough by seeing what they have to do
  in self"): the percent only, "Foundation 86%" (owner, 2026-10-24: no grade
  words, no count / target), a bar spanning 0-150 % with marks at 50 % (below
  it the stage is unsteady) and 100 % (full) whose fill runs gold to the 100 %
  mark and on in a pale gold past it (past 150 % the bar stays full and the
  label keeps counting to the stage's max, 150 %, where "150%: the most this
  stage can hold" replaces the hints), and the next two open experiences ("HUNT
  Slay a Stone Boar for the first time"); the rest of them and the bonus from
  past stages in the detail. Past 110 % the server sends `veiled` and no hints:
  the summary reads "Beyond this, the Dao hides its lessons." in a muted grey
  ([cultivation](../systems/cultivation.md), "The extra is hidden"). Data:
  PlayerState `foundation` (`percent`, `max`, `bonus`, `hints`, `veiled`), read
  only through `foundationOf()`. **Dantian** (raw qi bar,
  "180 / 260" on the right, live while open; standing, this is the only place it
  shows). **Heart demon** (hidden until a trial is done): "Calmed" in jade or
  "Still whispers" in muted red with the major on the right, the latest heart
  note (`heartDemon.trials[major].note`); every trial's note and the foundations
  it tempered in the detail.
- **Path:** **Spirit Root** (element name in its colour, grade on the right, the
  perk; "Washed 1 / 3 toward Earth grade" once a Marrow Washing Pill is in, else
  in the detail with the element bonus and the speed). **12-19** stay free for
  root actions. **Cultivation Method** (from Foundation; hidden on Sect
  Breathing): name and grade in its grade colour, the cultivation speed; the
  root match and "Takes you up to the end of Foundation" in the detail;
  switching is in the meditation menu. **Weapon Dao:** one plain row per class
  trained (any level or XP), the class in hand first and always shown in the
  Inventory's equipped gold, then `Weapons.ClassOrder`: the class glyph in its
  colour, "Sword Dao", "Lv 2 · 45%" on the right, a 6 px XP bar; tap a row for
  "12 / 30 Dao XP" and the weapon damage now and at the next level. Cloned from
  `Dao.Rows.RowTemplate`.
- **Title** (built 2026-10-24, [titles](../systems/titles.md)): the name block
  (`TitleRow`, a TextButton holding `PlayerName` and a `Line`) shows the worn title
  under the name in its rarity colour (or "No title", muted) with a gold chevron;
  the whole 46 px block taps open the **Titles page**. The line shows once a title
  is earned. The count earned is on the page, not the row: the 160 px PC column
  fits "Foundation Perfected" or a count, not both.
- **Titles page** (`SelfCard.Titles`; chosen over expanding the list inline in the
  Self column, which cut the how lines off at 160 px; critic pick both orders):
  swaps in for the card's body (Desktop, or Phone with its tabs) in the same window.
  `Bar`: a Back seal (the header seals' art, `icon_back` glyph), "Titles", "12 / 43
  earned", and a **Wear none** pill only while a title is worn. `List`: one group
  per `Titles.Categories` (gold capitals, "2 / 4" on the right) holding a grid of
  plain cells in `Titles.Order` (3 columns x 56 px on PC, 2 x 58 px on phones, how
  lines 13 / 14 px, at most two lines). Earned: the name in its rarity colour and
  the how line; locked: a gray bar the name's width (earning is the reveal) over the
  how line; worn: a gold wash, a 1 px gold edge (`WornEdge`) and the kit's tick.
  Tap an earned cell to wear it, the worn one (or Wear none) to take it off
  (`CultivationAction("title", ...)`; the result shows at once, the next
  PlayerState confirms). The card always reopens on its columns.
Later systems add sections of the same shape to the column they belong to; a
column scrolls once it outgrows its height.

**It grows with the player:**

| Stage | What the window shows |
|---|---|
| Before the root reveal | the crest isn't tappable yet |
| After the root reveal | the three columns: avatar, Race, Bloodline (None), Strength; Realm, Foundation, Dantian; Spirit Root, Weapon Dao. |
| First heart-demon trial | Cultivation gains **Heart demon**. |
| First title earned | the title line under the name appears; it opens the Titles page. |
| FE (method) | Path gains **Cultivation Method** (built). Hidden while on Sect Breathing. |
| First bloodline | Bloodline fills like Race (bloodline card, stage pips, skill, passive in its detail). |
| Later layers | new sections in the column they belong to; at most three areas (the phone's three tabs). |

A new section gets a dot on the crest until it has been opened (not built).
Exact numbers (multipliers, odds) appear only when you tap a section.

The window is built by the `ui-designer` agent (AGENTS.md) and follows the
one-window rule in `Menus` (see [ui](../systems/ui.md)).
