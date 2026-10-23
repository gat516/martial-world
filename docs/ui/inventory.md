# Inventory windows

Covers the Inventory's Weapons tab, the Arts grid and technique icons, the bottleneck and Comprehend controls, and sort and filter; read it when working on `Inventory`, `InventoryFilter`, `SlotArt` or `HotbarView`. General HUD rules are in [ui](../systems/ui.md).

- Weapons live in the Inventory's Weapons tab: Bare Fists first (choosing them
  puts the weapon away), then owned weapons with their grade glow and a cinnabar
  佩 seal on the equipped one; Equip/Unequip go through `WeaponAction`. With no
  weapon chosen the pane lists every class's Dao comprehension (level and XP bar);
  a chosen weapon shows its own class's row. Arts that need a weapon class wear a
  small round class badge in the Arts grid; on the hotbar the badge (and a dimmed
  icon) shows only while that class isn't in hand, and the slot still casts so
  the server can say "Requires a sword". Weapon and class icons live in
  `SlotArt` (drawn in `art/ui/draw_icons.py`; a def's own `icon` wins), so Spirit
  grades share their model's art and differ by glow colour.
- Technique icons are flat white glyphs tinted by the technique's colour; the
  class weapon skills' are drawn in `art/ui/draw_techniques.py`.
- A chosen art in the Inventory shows its tier, level and XP bar (a `DaoList`
  row cloned from `RowTemplate`). At a bottleneck (XP full at level 3, 6 or 9) the
  bar turns cinnabar and reads "Bottleneck", the grid's "Lv" turns the same
  colour, two cost rows (insight and Spirit Stones icons, "need · you have") show
  up, and the Secondary button becomes Comprehend (jade). While it can't run it
  stays lacquer and dimmed and its caption is the reason ("Meditate to
  comprehend", "Need insight", "Need stones"); a tap toasts the longer reason.
  Comprehending belongs to the seated Practice row's Technique tile; the button
  here still works while seated (`Bottleneck` holds the shared logic). Success is the
  server's notify. While the Inventory is open, tapping a hotbar slot shows that
  art or item in the detail pane instead of casting or holding it, so arts on the
  hotbar can be comprehended too.
- Sort and filter (`InventoryFilter`): once the Arts or Weapons tab holds 3 or
  more entries, a square sort button closes the tab row. It opens a small menu of
  class chips (All, Any for universal arts, then only the classes the player has)
  over three sort pills (Arts: Level, Name, Bottleneck; Weapons: Grade, Class,
  Name) and a caption naming the view ("Sword arts, highest level first"). Taps
  apply at once; the button again, a tap outside or a tab switch closes it. While
  a class is chosen the button turns gold wearing that class's icon. Unfiltered,
  the Arts grid lists only arts off the hotbar; a class filter lists every art of
  that class, hotbar ones included (slot number on PC, not draggable). Weapons keep
  the equipped one first, then Bare Fists. The choice lasts the session, per tab.
