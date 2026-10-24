# World overview
The setting and the world at a glance: what each area is, its realm, look and mood, and
where beasts, events and treasures live. Read this for setting instead of the full map
docs; follow the pointers for detail.

## Setting
A xianxia/wuxia cultivation world. The player is a disciple of a sect on floating stone
peaks above a sea of clouds, climbing the realms (Qi Condensation 1-9, then Foundation
Establishment, later majors). The loop ([core-loop](core-loop.md)): cultivate at home until
you hit a wall, go out into the wilds below to hunt and explore, come home stronger. Each
realm opens a new region. Motifs are xianxia ones: formation arrays, talisman seals, jade
and gold, ink, lotus, incense, mist and heavenly light ([vfx style](vfx/style.md)).

## At a glance
+X east, -Z north. One place, an 8-player hub server (one spirit peak per player).
- **The sect, in the sky.** The main peak at the origin (plaza floor Y ~648.6), eight
  spirit peaks ringing it at r 300 (plateaus Y 553.5), linked by rope bridges to the main
  peak's ring terrace (Y 582). Below them a flat white cloud sea (top Y 440 by the docs; the
  place measured ~339.6, see [world](systems/world.md) "Known gaps"), and karst pillars rising
  through it all round.
- **The wilds, on the ground** (Y ~0-10), south of the sect gate (0, 9, 500): one
  continuous walk from the Inner Wilds over the border river into the Ruined Borderlands;
  the Outer Wastes are still the old ring further out.
- **Travel** is by teleport arrays (tag `TravelGate`): My Peak, Main Peak (plaza, also the
  death respawn), Sect Gate (48, 6, 470), Inner Wilds (18, 4.2, 676), Middle Wilds
  (234, 1.4, 1662), Outer Wilds. Sword flight (Foundation, later) moves freely inside a zone
  only, under a flight ceiling of Y 420.

## Regions (`src/shared/Regions.luau`)
| Region | Bounds | Realm | Banner line | Ambient beasts |
|---|---|---|---|---|
| The Sect | ring 0-410 on the ground, ring 0-470 above Y 150 | safe | "Sheltered ground. No beast dares come here." | none |
| Inner Wilds | box x -1020..1020, z 470..1560, below Y 420 | QC1 | "Bamboo and old stone, where young beasts hunt." | Spirit Wolves (1-3), Venom Serpent, Stone Boar |
| Ruined Borderlands (`MiddleWilds`) | box x -320..620, z 1560..2060, below Y 420 | QC5 | "Dead villages. The beasts here have eaten cultivators." | mixed packs of wolves, boars, serpents |
| Outer Wastes | ring 1600-2200, below Y 420 | Foundation 1 | "Only those who have laid their foundation return." | placeholder packs (boars, wolves, serpents) until Foundation beasts exist |

Packs are in `src/shared/Spawns.luau`; regions are checked in that order.

## Areas: what each is, and its look
- **Main peak** ([main-peak](map/main-peak.md)): the ceremonial hub. A paved plaza on the
  procession axis (spawn, cauldron, main hall), the spire cluster behind with the
  tribulation disc on top (Y ~855), side courts (Elder, Stele, Seed Market; Quest Board,
  Spirit Market, plaza array), the Testing Stone, a south balcony over the cloud sea and
  grand stairs down to the ring terrace. Lacquer red, gold trims, slate-teal roofs, warm
  stone, lanterns and jade lamps.
- **Spirit peaks** ([spirit-peaks](map/spirit-peaks.md)): each player's home. A lawn
  plateau with a dwelling on a stone terrace, a fenced herb garden, a signature tree, a
  well, a stele, its own array and a bridge gate; a cave abode below.
- **Cloud sea and karst** ([cloud-sea](map/cloud-sea.md), [karst-pillars](map/karst-pillars.md)):
  matte cumulus with cool undersides and warm crowns over a flat plane; Zhangjiajie-style
  stone pillars with lawn tops framing the views from the peaks.
- **Under the sect** ([under-sect](map/under-sect.md)): a forest floor so a fall lands
  somewhere; the Ascension Array at the main peak's foot and the path south to the sect
  wall and gate.
- **Inner Wilds** ([wilds](map/wilds.md), [inner-wilds-rework](map/inner-wilds-rework.md)):
  a walled valley ~1800 x 920 with giant mossy cliff-rock walls and waterfalls as its edge.
  A spine runs south from the array to the hero, the Shrine Terrace and the Jade Veil
  Falls under the SouthHorizon karst. Pockets off it: Wolf Den Hollow (boss ring), the
  Bamboo Sea and Bamboo Hollow, the Fallen Giant ravine, Twin-Jade Spring, the Hunter's
  Camp, the Three Pillars Hermitage, the Lotus Mere; ~31 small finds between. Mood: sandy
  paths sunk between grass banks, layered canopy, pale rounded boulders, blue/white
  flowers, blue haze; sunlit tops bright green, shade cool blue-violet, bright cyan water.
- **Ruined Borderlands** ([wilds](map/wilds.md)): through the gorge gate and over the
  stone bridge. Dead, burned villages: the Ashen Hollow village, the Fallen Outpost boss
  arena, the Broken Pagoda (hero, three leaning burned tiers), Cultivators' Graves, Serpent
  Fen and Serpent Grotto, a marsh with the Drowned Shrine, the Deserters' Camp, a caravan.
  Mud and bare ground, cold jade "ghost" lanterns, ash drift, ghost lights, marsh mist.
  Not yet reworked to the walled-valley standard.
- **Outer Wastes**: not built; still the old sprinkled ring dressing (sealed ruins).

## Where things live (`assets/Wilds.rbxmx`, `Workspace.Wilds`)
- **Lairs** (`Wilds.Zones`; their realms, young near the gate and stronger farther out, are in
  `Spawns.Zones`, see [realm variants](enemies/variants.md)): Inner GateWolves (3 Spirit Wolves by the sect gate, the
  first-kill target), WolfPocket (3 wolves), WolfDen (4 wolves, the boss ring), BoarMeadow
  (3 boars), BoarField (2 boars); Borderlands SerpentMarsh (3 serpents), SerpentFen (2),
  BossArena (the Elder Wolf King). Other beasts and bosses (Nine-Tailed Fox, Thunder Ape,
  Jade Jiao, ...) are testbed trials: see [enemies](systems/enemies.md) "Roster".
- **Qi nodes** (`Wilds.QiNodes`, QiNode1-7): raw qi and stones on a per-player cooldown.
- **Event grounds** (`Wilds.EventGrounds`): open flat discs where world events and
  treasures land: Inner North Terrace (300, 680) r 48, West Field (-400, 1000) r 55, East
  Flat (470, 1120) r 55; Borderlands Graves Field (0, 1750) r 32, South Flat (360, 1928)
  r 30 (interim).
- **Manual caches and racks**: five manual caches in the wilds and the weapon rack in the
  plaza's west court ([map](systems/map.md) "Hard constraints").
- **Tribulation** happens on the summit disc above the main peak.

## Weather and events ([world](systems/world.md))
One shared weather at a time, back to Clear between: Rain, Storm, Windy, and the rare
anomalies Auspicious Mist (violet), Rainbow Aurora (pearl) and Heaven Split (gold), which
drop heavenly treasures onto the event grounds. World events (Thousand-Year Ginseng under a
guardian beast, Beast Surge, Auspicious / Violet Cloud Mist / Golden Auspicious Clouds round
a sealed relic) are announced, seen from the peaks as light pillars and sky arrays, and
first-come: everyone races for them. Day/night runs a warm day, golden hour, violet dusk
and an indigo night lit by lanterns, jade lamps and qi glows.

## Where the details are
- Map rules, art direction, palette, hard constraints: [map](systems/map.md) (area files
  in `docs/map/`).
- Weather, events, treasures, ambience: [world](systems/world.md) (detail in `docs/world/`).
- The loop and when each region opens: [core-loop](core-loop.md); per-stage tuning in
  `src/shared/Pacing.luau`.
- Every system's files and remotes: [README](README.md).
