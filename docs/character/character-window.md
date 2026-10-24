# Character window

Covers the character window (Self card), the root reveal card, how they open and how the window grows with the player; read it when working on `SelfCard`, `RootReveal` or the Self tile. Shared HUD rules are in [ui](../systems/ui.md).

**Where weapons live:** weapons and Dao comprehension are in the Inventory's
Weapons & Arts tab. The character window does not list weapons; it shows
only the equipped class's Weapon Dao row (level, XP, what it gives).

**The reveal card** (`src/client/RootReveal.luau`, `Hud.RootReveal`): on the
local player's first test (Effect "root" with `first`), a small centre card: the
element's seal (`art/ui/draw_icons.py`, `icon_Root<Element>`) on rays in its
colour, "Spirit Root", the element's name, the grade in its colour and the
one-line perk. Rare roots add a gold ring round the seal and a "RARE!" tag. A tap
closes it after a beat, or it closes itself after 6 s. A repeat test shows no card
(the server toasts).

**Opening it:** the **Self tile** in the top-right row (`Hud.Buttons.SelfButton`,
between Cultivate and Inventory; a bust with a topknot, `art/ui/draw_ui.py`
`self_icon`). It is hidden until the root is tested; when the reveal card closes
it pops in, swells once and wears a small seal dot until the window is first
opened (not saved across sessions). Its close seal shuts the card (the
top-right tiles fade away while any window is open). Tapping the **realm
crest** in the vitals (`Crest.Open`) is a shortcut to the same card, with no dot of
its own. The elder pointing at it is still to do.

**Built (v2, `src/client/SelfCard.luau`, `Hud.SelfCard`):** one card (at most
380 px wide, grows to fit) with the realm name, its stage bar (cultivation toward
the next stage), then the Self page, a scrolling list of rows that all share one
shape. **Decided 2026-10-21** (the user found the old rows unclear: "Iron Marrow
Art is a what?", a truncated weapon name read as a technique, "Guandao Dao 0"):
each row is labelled by kind in small gold capitals, then names the thing, then
shows only its effects, one line each, gains in jade and losses in a muted red,
with the numbers taken from the shared defs. No flavour text, no techniques, no
weapon names.
- **Foundation** (3, 2026-10-23; the user: "players should optionally try to
  solidify their breakthrough by seeing what they have to do in self"): "Steady
  foundation" (the grade breaking through now would give, the grade word in its
  colour: Cracked muted red, Steady steel blue, Solid jade, Deep gold; the server now sends Unsteady for Cracked and a percent that can pass 100%, see [cultivation UI](../ui/cultivation.md#foundation-row-in-the-self-card-built)), a bar of
  this stage's weighted experiences toward Deep ("2 / 4 experiences",
  right-aligned on the trough, with marks at the Steady and Solid shares of
  `Pacing.Foundation.GRADES`, dark on the fill and pale on the trough), the
  bonus of past grades in jade ("+4% max health and power from your
  foundations"), then the open experiences from the server's hints, one line
  each, the category in small gold capitals ("HUNT  Slay a Stone Boar for the
  first time"). At Deep the hints give way to one jade line. Data: PlayerState
  `foundation` (`count`, `target`, `grade`, `bonus`, `hints`), read only through
  `foundationOf()` in `SelfCard`. Chosen over a four-cell Cracked | Steady |
  Solid | Deep step track (the critic: one bar in the card's family, no row of
  tinted chips).
- **Dantian** (5, decided 2026-10-22): "Raw qi", a violet bar ("180 / 260 raw
  qi", from `RawQi` / `DantianCap`, live while the card is open) and one line on
  refining it. Standing, this is the only place the dantian shows; the HUD shows
  it only while seated.
- **Race** (8): race and variant ("Beast Folk · Wolf", from the `Race` and
  `RaceVariant` attributes, [identity](../systems/identity.md)), the rarity on
  the right in its rarity colour lifted for contrast, then the race's, the
  variant's and the innate traits' modifiers summed, one line each ("+1 run
  speed", "+5% herb growth"). Hidden before a race is set.
- **Bloodline** (9): deferred ([bloodline](bloodline.md)), so it always reads
  "None", muted (dimmed seal, Kind and name, no effect lines). When bloodlines
  land it fills like Race and takes the tabs below.
- **Spirit Root** (10): "Metal Root", grade on the right; the perk at this grade
  (`Pacing.Roots.PERKS` x grade), "+15% Metal technique damage"
  (`Pacing.Roots.MATCH`), and the grade's cultivation speed (`Roots.speed`).
  **12-19** stay free for root actions (a Reroll button, a stored-roots strip).
- **Cultivation Method** (20, from Foundation; hidden on Sect Breathing): name and
  grade in its grade colour; "+20% cultivation speed (matches your root)"
  (`Methods.speed`) and "Takes you up to the end of Foundation" (`reaches`, the
  one limit that matters to the player). Read-only; switching is in the
  meditation menu.
- **Weapon Dao** (30): the equipped class's Dao ("Guandao Dao"), "Level 0" on
  the right, an XP bar ("12 / 30 Dao XP", or "Mastered"), the weapon damage it
  gives now (`Weapons.daoMultiplier`, e.g. "-20% weapon damage" below the
  neutral level) and at the next level.

The list grows up to what fits on screen (`LIST_MARGIN` from the top and
bottom) and then scrolls (on a phone it always scrolls; the window never grows past its
phone size); later systems add rows of the same shape. Tabs go between the stage bar and `Body.Pages` (each tab
a page frame in `Pages`).

**It grows with the player:**

| Stage | What the window shows |
|---|---|
| Before the root reveal | the crest isn't tappable yet |
| After the root reveal | one card, **Self**: realm, stage bar, Foundation, Dantian, Race, Bloodline (None), Spirit Root, Weapon Dao. No tabs. |
| FE (method) | Self gains a **Cultivation Method** row (built): element seal, name and grade in its grade colour, cultivation speed (with the root match) and how far it takes you. Read-only; switching is in the meditation menu (built). Hidden while on Sect Breathing. |
| First bloodline | tabs appear: **Self** \| **Body** (bloodline card, stage pips, skill, passive) |
| Later layers | at most four tabs |

Each tab shows icon seals plus a short label. A new section gets a dot on the
crest until it has been opened. Exact numbers (multipliers, odds) appear only
when you tap a card.

The window is built by the `ui-designer` agent (AGENTS.md) and follows the
one-window rule in `Menus` (see [ui](../systems/ui.md)).
