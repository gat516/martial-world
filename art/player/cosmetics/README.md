# Player cosmetics

`assets/Cosmetics/` is mapped to `ReplicatedStorage.Cosmetics` (the creator
preview runs on the client). It holds one binary file per set, and each file is
a Folder of rigged Accessory prototypes. Traits looks up an accessory id through
every set. Sets: `Fox.rbxm` (Spirit Fox, below), `BeastFolk.rbxm` (the Beast Folk
variants) and `Spirits.rbxm` (Stone Spirit, Dragonblood, Demonic Human, Ghost).


New and reworked cosmetics are modeled in Blender by the `modeler` (user,
2026-10-23: "from now on, we're going to make player / r6 related assets in
blender"). The fox is remade; the part-built Beast Folk and Spirits sets below are
placeholders until they're remade (how: `docs/character/player-accessories.md`).

## Fox (`assets/Cosmetics/Fox.rbxm`)

Skinned Blender meshes with bones, three Spirit Fox variants (`src/shared/Identity/Variants/SpiritFox.luau`).
Model, rig, colours, asset ids and the Studio build (`fox/place_fox_cosmetics.luau`) are in
[`fox/README.md`](fox/README.md).

| Accessory | Attaches to (R6) | Worn by |
| --- | --- | --- |
| `FoxTailPlume`, `FoxEarsSleek` | Torso.WaistBackAttachment, Head.HatAttachment | Spirit Fox, Plume |
| `FoxTailCrescent`, `FoxEarsBroad` | same | Spirit Fox, Crescent |
| `FoxTailWisp`, `FoxEarsLong` | same | Spirit Fox, Wisp |

Export the `Fox` folder (`_G.exportRbxm("ReplicatedStorage.Cosmetics.Fox")`, or from a
sandbox's staging folder) to `assets/Cosmetics/Fox.rbxm`.

## Beast Folk (`assets/Cosmetics/BeastFolk.rbxm`)

The Folder `BeastFolk` (mapped into `ReplicatedStorage.Cosmetics`) holds eight
rigged Accessories, two per Beast Folk variant, as listed in
`src/shared/Identity/Variants/BeastFolk.luau`. They are built by
`build_beastfolk_cosmetics.luau` in the fox set's shape language: plain
SmoothPlastic, invisible 0.2 Handles, and every part unanchored and Massless with
CanCollide, CanQuery and CanTouch off. Each set has one loud piece: the wolf's
tall grey ears, the tiger's banded tail, the crane's red cap and plume, and the
serpent's long tail.

| Accessory | Attaches (R6) | Parts | Look |
| --- | --- | --- | --- |
| `WolfEars` | HatAttachment | 13 | upright grey ears 0.6 x 1.3, warm cream inner, charcoal tip |
| `WolfTail` | WaistBackAttachment | 9 | bushy grey brush that arcs out and hangs down, cream belly lobes |
| `TigerEars` | HatAttachment | 11 | short round orange discs on a stem, black rim, white inner, white spot on the back |
| `TigerTail` | WaistBackAttachment | 13 | long slim S-curve, five black bands, black tip |
| `CraneCrest` | HatAttachment | 10 | flat red cap pressed into the hair, three black-tipped white plumes and two black ones swept back |
| `CraneTail` | WaistBackAttachment | 12 | white rump with a fan of five black-tipped white feathers, outer ones lifted |
| `SerpentScales` | FaceFrontAttachment | 11 | five jade diamonds per side on the temple and cheek, flat on the head wall |
| `SerpentTail` | WaistBackAttachment | 15 | long tapering jade tail with a dark dorsal line, drooping, tip curling to the right |

(Part counts include the Handle.)

### Joints

Same conventions as the fox (Motor6Ds parented to Part0, identity frames at rest,
X pitches, Y yaws, Z rolls). The part and joint names match the fox's, so a clip
keyed on `LeftEar`/`RightEar` or `TailSeg1..n` drives any race:

| Accessory | Joints | Notes |
| --- | --- | --- |
| `WolfEars`, `TigerEars` | `EarL` (Handle -> `LeftEar`), `EarR` (-> `RightEar`) | hinge at the ear base; inner, tip, rim, stem and spot pieces are welded |
| `WolfTail` | `Tail1..5` (Handle -> `TailSeg1` -> ... -> `TailSeg5`) | `TailBelly3..5` are welded to their segment |
| `TigerTail` | `Tail1..7` (`TailSeg1..7`) | `TailBand1..5` are welded to segments 2-6; `TailSeg7` is the black tip |
| `SerpentTail` | `Tail1..7` (`TailSeg1..7`) | `TailDorsal1..7` are welded to their segment |
| `CraneCrest` | `Plume` (Handle -> `CrestPlume`) | the whole plume sways from its root; the crown is welded to the Handle |
| `CraneTail` | `Tail1` (Handle -> `TailSeg1`, the rump), `Feather1..5` (`TailSeg1` -> `TailFeather1..5`) | yaw the outer feathers outward to spread the fan; tips are welded |
| `SerpentScales` | none | flat, welded to the Handle |

Safe ranges: tail joints take about ±0.35 rad of yaw each, and fan feathers
about ±0.4 rad. Bending a drooping tail forward (negative X pitch on `Tail1`)
brings it into the legs.

### Clearances (checked numerically)

- **Walk:** the stock R6 walk (`rbxassetid://180426354`) swings the legs back to
  about Z 1.5 behind the waist at hip height. So every tail runs out level
  (above Y 0) until about Z 1.6 before it droops. Worst limb penetration over
  the clip is 0.01 to 0.05, all at the hip root; FoxTail measures 0.27.
- **Hair:** the head pieces stand clear of a normal hair (hair box top 0.30 above
  HatAttachment). The wolf ear tops are at 1.34, the tiger's at about 0.7, the
  crane plume's at about 1.1. Very tall hair hides the tiger ears and the crane
  cap.
- **Scale:** after the character's `ScaleTo(1.15)`, every part sits at exactly
  1.15x its distance from its attachment, with no joint gaps.

### Rebuild

Run `build_beastfolk_cosmetics.luau` in Edit mode (execute_luau, or `loadstring`
it from a served checkout). It replaces `ReplicatedStorage.Cosmetics.BeastFolk`.
Then load `tools/export_rbxm.luau` and post
`_G.exportRbxm("ReplicatedStorage.Cosmetics.BeastFolk")` to the receiver
(`/BeastFolk.rbxm`), and move the file to `assets/Cosmetics/BeastFolk.rbxm`. In a
Rojo-connected place, build in an unmapped staging folder and export it under
the name `BeastFolk` instead.

## Spirits (`assets/Cosmetics/Spirits.rbxm`)

The Folder `Spirits` (mapped into `ReplicatedStorage.Cosmetics`) holds one
Accessory per race, as named in `src/shared/Identity/Races.luau`. They are built
by `build_spirit_cosmetics.luau` in the fox and Beast Folk shape language: plain
SmoothPlastic, Neon only where something glows, invisible 0.2 Handles, and every
part unanchored and Massless with CanCollide, CanQuery and CanTouch off. Each is
one telling feature on a plain R6 cultivator, not a costume.

| Accessory | Race | Attaches (R6) | Parts | Look |
| --- | --- | --- | --- | --- |
| `StoneShards` | Stone Spirit | BodyBackAttachment | 21 | grey-brown stone shards (block body + wedge chisel cap, diamond-turned) on two shoulder crusts, 2 per shoulder leaning out and back, 2 between the shoulder blades; 3 shards carry flush Neon jade vein insets |
| `DragonHorns` | Dragonblood | HatAttachment | 11 | antler beams from the temples sweeping up and back, ivory to pale gold, two gold tines each |
| `DemonHorns` | Demonic Human | HatAttachment | 7 | short thick horns from the upper forehead, rising out and hooking forward, black to crimson tip; no tines |
| `GhostWisps` | Ghost | BodyBackAttachment | 10 | three Neon soul flames (core, tapered tongue leaning outward, faint shell): one over each shoulder beside the face, one on the upper back, plus one mist emitter |

(Part counts include the Handle.) Horns and flames are ellipsoids (Sphere
SpecialMesh), which scale with `ScaleTo`.

### Joints

Same conventions as the fox (Motor6Ds parented to Part0, identity frames at rest,
X pitches, Y yaws, Z rolls; the character faces -Z, its left is -X):

| Accessory | Joints | Notes |
| --- | --- | --- |
| `DragonHorns`, `DemonHorns` | `HornL` (Handle -> `LeftHorn`), `HornR` (-> `RightHorn`) | hinge at the horn root; `<Side>HornSeg2/3` and the dragon's `<Side>HornTine1/2` are welded |
| `GhostWisps` | `Wisp1` (Handle -> `WispL`), `Wisp2` (-> `WispR`), `Wisp3` (-> `WispBack`) | hinge at the flame core, so `Transform` translation bobs a flame; `<Wisp>Flame` and `<Wisp>Shell` are welded |
| `StoneShards` | none | rigid, welded to the Handle |

Safe ranges: a wisp bob of about ±0.2 studs in Y keeps the side flames above the
arm tops; don't move them inward (X toward 0) or they enter the head. Horn twitches
look right up to about 0.2 rad.

### Emitter

`GhostWisps.Handle.MistFX.Mist`: built-in smoke texture, pale blue, Rate 1.2,
Lifetime 2.5-3.5 s (about 3-4 particles alive), size 0.8 to 1.8, transparency
0.86 at its densest, drifting back and slowly up. No other race uses effects.

### Clearances (checked numerically)

- **Walk:** over the stock R6 walk (`rbxassetid://180426354`) and a ±1 rad
  limb-swing stress pose, the horns never touch a limb, and the wisps only
  graze the arm tops by 0.015 with their faint outer shell (the side flames sit
  over the shoulder centres, 0.4 above the torso top, just outside the face). The stone
  shards and crusts graze at most 0.07 to 0.1 studs, at their roots on the
  shoulder top, against a 1.2 cube standing in for the rounded head mesh and the
  arm top corners; the shoulder room between the head and the arms is only about
  0.4, so wider or more outward-leaning shards hit the arms.
- **Hair:** with Pal Hair (box top 0.15 above HatAttachment) the dragon horn tips
  stand at 1.31 and the demon horn tips at 1.04. Very tall hair can bury the
  demon horn roots.
- **Scale:** after the character's `ScaleTo(1.15)`, every part sits at exactly
  1.15x its distance from its body part, with no joint gaps.

### Rebuild

Run `build_spirit_cosmetics.luau` in Edit mode (execute_luau, or `loadstring`
it from a served checkout). It replaces `ReplicatedStorage.Cosmetics.Spirits`;
the tunables are at the top. Then load `tools/export_rbxm.luau`, post
`_G.exportRbxm("ReplicatedStorage.Cosmetics.Spirits")` to the receiver
(`/Spirits.rbxm`), and move the file to `assets/Cosmetics/Spirits.rbxm`. In a
Rojo-connected place, build in an unmapped staging folder and export it under
the name `Spirits` instead.
