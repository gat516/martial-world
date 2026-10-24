r"""Beast Folk (Serpent) cosmetics: fin crests and face scale plates for the player's R6 avatar.

Directions (one row each on the sheet; see README.md):
  Veil      subtle-elegant: low ribbon fins swept straight back, a slim strip of round scales
  Sovereign ceremonial: tall upswept fan fins (the concept sheet), a two-lobed pointed plate
  Fang      fierce: horizontal barbed blades with hooked spines, a temple blade and a cheek fang
Each direction is two sets (any fins go with any plates): SerpentFins<Dir> and SerpentScales<Dir>,
both on Head.HatAttachment, each its own FBX + JSON beside this script.

Run in its own visible Blender window (parallel modelers don't share the MCP Blender):
    tools/blender_live.sh open serpent
    tools/blender_live.sh run serpent art/player/cosmetics/serpent/build_serpent.py [RENDER=True] [EXPORT=False]
(tools/blender_run.sh runs it headless the same way.) Sizes as head ratios go to renders/ratios.json.
then stitch the sheet: uv run --with pillow python3 -I art/player/cosmetics/serpent/make_sheet.py

Axes and units (art/rig/r6_rigged.fbx): 1 Blender unit = 1 stud, +X = the avatar's left, it
faces -Y, Z up. The R6 head is a 12-sided cylinder of radius 0.6 about the Z axis, z 2.08..3.1,
its top rounding in above z 2.9. HatAttachment = (0, 0, 3.1).
Head coordinates used here: phi = angle round the head from the face centre (0) toward the
avatar's left side (90) and the back (180); u = 0.6 * phi (arc length, studs), v = height z.
A point (u, v, h) is the head surface at (phi, v) pushed h along the surface normal; the
surface comes from ray casts onto the rig mesh, so plates hug it exactly. The right side is
the mirror image (x -> -x).

Regions (one mesh object = one MeshPart = one Color each, material named by region):
  Scale (dark teal plates), Seam (the glowing underlay that shows between the scales),
  FinWeb (translucent teal webbing), FinSpine (gilded spines and the root knuckle).
Rig (fins only; plates are rigid): Root -> FinLBase -> FinL -> FinLTip (and R).
  FinLBase holds the buried knuckle; FinL's head is the hinge on the head surface.
  Local Z of FinL/FinLTip is the fin's normal: rotate about local X to flare the fin out from
  the head (+) or fold it in, about local Z to sweep it up or down in its own plane.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "art", "rig"))
import rig_preview as rp  # noqa: E402

RENDER = globals().get("RENDER", True)
EXPORT = globals().get("EXPORT", True)

SCENE = "Cosmetics"
ROOT_COLLECTION = "SerpentCosmetics"
HAT = Vector((0.0, 0.0, 3.1))
HEAD_R = 0.6
SHARP_DEG = 28.0          # house crease angle (plates, spines)
WEB_SHARP_DEG = 60.0      # webbing: soft, only the rim creases

COLORS = {                # linear
    "Scale":    (0.014, 0.085, 0.072, 1),   # deep jade-teal
    "Seam":     (0.10, 0.95, 0.78, 1),      # glowing teal (Neon in Roblox)
    "FinWeb":   (0.08, 0.55, 0.52, 1),      # sea teal, translucent
    "FinSpine": (0.80, 0.52, 0.16, 1),      # gilded gold
}
EMIT = {"Seam": 1.6}
ALPHA = {"FinWeb": 0.78}  # preview alpha; Roblox Transparency about 0.35
MAT_PREFIX = "Serpent_"   # every material is Serpent_<Region>, so other races' rebuilds can't recolour it
SHADE_FILE = "serpent_shade.png"   # same settings as fox_shade.png, so the shared ramp asset fits
SHADE_MIN = 0.55
SHADE_REACH = 0.45

# ----------------------------------------------------------------------------------------------
# Fins. Built in a fin frame at the root: b (back, along the head's tangent turned YAW degrees
# outward), u (up, rolled ROLL degrees outward about b), n = b x u. Root at (PHI, Z) on the head,
# sunk SINK under the surface. SPINES: (angle from b toward u in degrees, length, sweep degrees
# the spine turns back toward b along its length, curl out of plane at the tip along n).
# WEB_END: how far up each spine the webbing reaches (spine points stand out past it);
# SCALLOP: how deep the webbing dips between spine tips (fraction of the length); CUSP > 1
# sharpens the dips into notches. SPINE_R spine root radius; HOOK bends the last 25% of every
# spine outward (degrees, Fang's barbs). KNUCKLE gilded root medallion radius.
FINS = {
    # a soft leaf: four short ribs inside one broad web with a lobed (convex) trailing edge,
    # swept back past the ear and flared out so it reads from the front
    "Veil": dict(PHI=96, Z=2.62, SINK=0.05, YAW=30, ROLL=10, KNUCKLE=0.09,
                 SPINES=[(-14, 0.80, 8, 0.03), (-2, 0.92, 10, 0.05), (10, 0.88, 12, 0.06), (22, 0.70, 14, 0.07)],
                 WEB_END=0.97, SCALLOP=-0.05, CUSP=1.0, SPINE_R=0.040, HOOK=0, WEB_T=0.045),
    # the concept sheet: an upswept fan, gilded spines standing past a scalloped web
    "Sovereign": dict(PHI=98, Z=2.84, SINK=0.05, YAW=25, ROLL=25, KNUCKLE=0.11,
                      SPINES=[(35, 0.75, 16, 0.04), (52, 0.92, 20, 0.06), (68, 0.95, 20, 0.08),
                              (84, 0.75, 16, 0.09)],
                      WEB_END=0.84, SCALLOP=0.12, CUSP=1.0, SPINE_R=0.050, HOOK=0, WEB_T=0.045),
    # level barbed blades thrown back and out like swept horns, tips kicking up and hooking out
    "Fang": dict(PHI=110, Z=2.88, SINK=0.05, YAW=62, ROLL=0, KNUCKLE=0.11,
                 SPINES=[(-28, 0.70, -12, 0.0), (-12, 0.95, -12, 0.02), (4, 1.08, -10, 0.04)],
                 WEB_END=0.60, SCALLOP=0.20, CUSP=2.2, SPINE_R=0.060, HOOK=25, WEB_T=0.05),
}
SPINE_SIDES = 5
SPINE_RINGS = 9
WEB_ROWS = 8          # rows along the fin
WEB_COLS_PER_GAP = 3  # columns between neighbouring spines
WEB_T0 = 0.06         # the webbing starts this far up the spines (inside the knuckle)

# ----------------------------------------------------------------------------------------------
# Plates: one solid, tight patch of small overlapping scales hugging the side of the face. Each
# patch is a band along a curve in head coordinates (u, v) with a WIDTH profile (studs); the
# curve runs from the scales' roots toward their free tips (Sovereign's and Veil's point down
# the cheek). The band is filled brick-wise: rows ROW studs apart, scales CELL studs apart
# across, odd rows half a cell over, so every tip covers the join below it. A glowing Seam
# underlay fills the band under them and shows only in the hairline gaps (GAP, a fraction of
# the cell). SHAPE round | point | blade, LEN scale length as a multiple of ROW (> 1 overlaps),
# LIFT tip height over the surface (low: the patch hugs), RIDGE centre ridge, GRADE scale size
# at the start and end, TIP_SCALE the last row's length multiplier (the patch's point).
PLATES = {
    # a slim temple-to-cheek crescent of round scales
    "Veil": [dict(CURVE=[(0.88, 2.96), (0.80, 2.76), (0.70, 2.55), (0.61, 2.36)],
                  WIDTH=[(0, 0.07), (0.2, 0.16), (0.65, 0.14), (1, 0.06)],
                  ROW=0.062, CELL=0.068, SHAPE="round", LEN=1.9, GAP=0.04, LIFT=0.026, RIDGE=0.008,
                  GRADE=(1.0, 0.85), TIP_SCALE=1.0)],
    # the concept sheet's leaf: a broad temple lobe, a waist, a cheek lobe ending in a point
    "Sovereign": [dict(CURVE=[(1.02, 3.00), (0.90, 2.85), (0.76, 2.66), (0.67, 2.46), (0.59, 2.24)],
                       WIDTH=[(0, 0.08), (0.22, 0.27), (0.50, 0.17), (0.74, 0.23), (1, 0.07)],
                       ROW=0.068, CELL=0.075, SHAPE="point", LEN=1.9, GAP=0.04, LIFT=0.034, RIDGE=0.014,
                       GRADE=(1.0, 0.9), TIP_SCALE=1.6)],
    # a short temple blade swept back toward the fin, and a cheek fang pointing down
    "Fang": [dict(CURVE=[(0.66, 2.80), (0.84, 2.86), (1.04, 2.94)],
                  WIDTH=[(0, 0.10), (0.3, 0.20), (1, 0.06)],
                  ROW=0.075, CELL=0.08, SHAPE="blade", LEN=1.9, GAP=0.05, LIFT=0.045, RIDGE=0.02,
                  GRADE=(1.0, 0.9), TIP_SCALE=1.8),
             dict(CURVE=[(0.76, 2.64), (0.68, 2.44), (0.60, 2.24)],
                  WIDTH=[(0, 0.08), (0.35, 0.17), (1, 0.05)],
                  ROW=0.075, CELL=0.08, SHAPE="blade", LEN=1.9, GAP=0.05, LIFT=0.045, RIDGE=0.02,
                  GRADE=(1.0, 0.9), TIP_SCALE=1.8)],
}
PLATE_SEAM_H = 0.012      # underlay top over the surface (scales sit above, gaps show it)
PLATE_BURY = 0.05         # every underside sits this far inside the head
PLATE_UNDER_W = 0.80      # underlay half-width as a fraction of the band's half-width
UNDER_ROWS = 12
SCALE_WIDE = 0.68          # scale half-width per cell: > 0.5 so the diamond outlines overlap and the seam shows as hairlines

DIRECTIONS = [
    ("Veil", "subtle-elegant", "low ribbon fins swept straight back; slim strip of round scales"),
    ("Sovereign", "ceremonial", "tall upswept fan (concept sheet); two-lobed pointed temple-cheek plate"),
    ("Fang", "fierce", "flared barbed blades, hooked spines past the web; temple blade + cheek fang"),
]


# ---------------------------------------------------------------------------------- helpers ---
def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def interp(profile, s):
    for (s0, r0), (s1, r1) in zip(profile, profile[1:]):
        if s0 <= s <= s1:
            u = (s - s0) / (s1 - s0)
            u = u * u * (3 - 2 * u)
            return r0 + (r1 - r0) * u
    return profile[-1][1] if s > profile[-1][0] else profile[0][1]


def shade_image():
    img = bpy.data.images.get(SHADE_FILE)
    if img is not None:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(SHADE_FILE, 4, 128, alpha=False)
    img.colorspace_settings.name = "sRGB"
    w, h = img.size
    px = []
    for y in range(h):
        g = SHADE_MIN + (1 - SHADE_MIN) * smoothstep(0.0, SHADE_REACH, (y + 0.5) / h)
        px += [g, g, g, 1.0] * w
    img.pixels.foreach_set(px)
    img.update()
    if EXPORT:
        img.filepath_raw = os.path.join(HERE, SHADE_FILE)
        img.file_format = "PNG"
        img.save()
    img.pack()
    return img


def material(name):
    """Region material: colour x shade ramp (what Roblox's SurfaceAppearance tint does)."""
    m = rp.preview_material(MAT_PREFIX + name, COLORS[name], emit=EMIT.get(name, 0.0))
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for n in [n for n in nt.nodes if n.type in ("TEX_IMAGE", "MIX")]:
        nt.nodes.remove(n)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.get(SHADE_FILE) or shade_image()
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    rgba_in = [s for s in mix.inputs if s.type == "RGBA"]
    rgba_in[0].default_value = COLORS[name]
    nt.links.new(tex.outputs["Color"], rgba_in[1])
    nt.links.new(next(s for s in mix.outputs if s.type == "RGBA"), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45 if name == "FinSpine" else 0.6
    if name in ALPHA:
        bsdf.inputs["Alpha"].default_value = ALPHA[name]
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, val)
            except (AttributeError, TypeError):
                pass
        m.use_backface_culling = False
    return m


def new_object(name, bm, mat, col, vvals, sharp):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = not (e.is_manifold and e.calc_face_angle(0) > math.radians(sharp))
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    if bpy.data.meshes.get(name):
        bpy.data.meshes.remove(bpy.data.meshes[name])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        uv.data[loop.index].uv = (0.5, min(0.995, max(0.005, vvals[loop.vertex_index])))
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    me.materials.append(mat)
    o["region"] = mat.name[len(MAT_PREFIX):] if mat.name.startswith(MAT_PREFIX) else mat.name
    return o


def collection(name, parent):
    col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if col.name not in parent.children:
        parent.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    lc = bpy.context.view_layer.layer_collection.children.get(parent.name)
    if lc and lc.children.get(col.name):
        lc.children[col.name].exclude = False   # objects in an excluded collection can't go active
    return col


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


# ---------------------------------------------------------------------------------- head ------
_RIG = None


def rig_mesh():
    global _RIG
    if _RIG is None:
        _RIG = next(o for o in rp.rig_objects() if o.type == "MESH")
    return _RIG


def head_surface(phi_deg, z):
    """(surface point, outward normal) on the left side at angle phi (deg from the face centre)
    and height z. The normal is the radial direction tipped up by the mesh's own slope (the
    rounded top), so plates follow the cap without picking up the facets' kinks."""
    rig = rig_mesh()
    ph = math.radians(phi_deg)
    radial = Vector((math.sin(ph), -math.cos(ph), 0.0))
    z = min(z, 3.07)
    inv = rig.matrix_world.inverted()
    origin = Vector((0, 0, z)) + radial * 2.0
    hit, loc, nrm, _ = rig.ray_cast(inv @ origin, (inv.to_3x3() @ -radial).normalized())
    assert hit, "missed the head at phi %.1f z %.2f" % (phi_deg, z)
    p = rig.matrix_world @ loc
    nz = (rig.matrix_world.to_3x3() @ nrm).normalized().z
    n = (radial * math.sqrt(max(0.0, 1 - nz * nz)) + Vector((0, 0, nz))).normalized()
    return p, n


def head_point(u, v, h, side=1):
    p, n = head_surface(math.degrees(u / HEAD_R), v)
    q = p + n * h
    return Vector((q.x * side, q.y, q.z))


# ---------------------------------------------------------------------------------- fins ------
def fin_frame(f):
    """Root point (sunk) and axes b, u, n of the left fin, avatar space."""
    p, o = head_surface(f["PHI"], f["Z"])
    ph = math.radians(f["PHI"])
    t = Vector((math.cos(ph), math.sin(ph), 0.0))           # along the surface toward the back
    y = math.radians(f["YAW"])
    b = (t * math.cos(y) + o * math.sin(y)).normalized()
    side = Vector((0, 0, 1)).cross(b)
    if side.dot(o) < 0:
        side = -side
    r = math.radians(f["ROLL"])
    u = (Vector((0, 0, 1)) * math.cos(r) + side * math.sin(r)).normalized()
    n = b.cross(u).normalized()
    if n.dot(o) < 0:
        n = -n
    return p - o * f["SINK"], b, u, n, p


def spine_points(f, spine, frame, steps=SPINE_RINGS):
    """Centreline of one spine: [(point, t)] from the root to the tip, t 0..1."""
    root, b, u, n, _ = frame
    ang, length, sweep, curl = spine
    pts, pos = [], root.copy()
    ds = length / steps
    for k in range(steps + 1):
        t = k / steps
        pts.append((pos + n * (curl * t * t), t))
        a = math.radians(ang - sweep * (t + 0.5 / steps))
        d = b * math.cos(a) + u * math.sin(a)
        if f["HOOK"] and t > 0.7:
            h = math.radians(f["HOOK"]) * (t - 0.7) / 0.3
            d = d * math.cos(h) + n * math.sin(h)
        pos = pos + d * ds
    return pts


def spine_at(pts, t):
    """Point at fraction t along a spine centreline."""
    x = t * (len(pts) - 1)
    i = min(int(x), len(pts) - 2)
    return pts[i][0].lerp(pts[i + 1][0], x - i)


def build_fin(f, frame):
    """bmesh pair (web, spines+knuckle) and per-vertex (t along the fin) for the left fin."""
    root, b, u, n, surf = frame
    spines = [spine_points(f, s, frame) for s in f["SPINES"]]
    # Spines: tapered tubes, closed, pointed at the tip.
    sb, st = bmesh.new(), []
    for sp, spec in zip(spines, f["SPINES"]):
        rings = []
        for k, (c, t) in enumerate(sp):
            if k == len(sp) - 1:
                rings.append([sb.verts.new(c)])
                st.append(t)
                continue
            nxt = sp[k + 1][0]
            ax = (nxt - c).normalized()
            s1 = ax.cross(n).normalized()
            s2 = ax.cross(s1).normalized()
            r = f["SPINE_R"] * (1 - t) ** 0.8 + 0.006
            rings.append([sb.verts.new(c + (s1 * math.cos(a) + s2 * math.sin(a) * 0.85) * r)
                          for a in (2 * math.pi * j / SPINE_SIDES + 0.3 for j in range(SPINE_SIDES))])
            st += [t] * SPINE_SIDES
        rp.loft(sb, rings, cap_start=True, cap_end=False)
    # Knuckle: a gilded lozenge at the root, half sunk in the head, axis along the surface normal.
    o = (surf - root).normalized()
    kr = f["KNUCKLE"]
    prof = [(-1.0, 0.0), (-0.7, 0.75), (-0.15, 1.0), (0.4, 0.8), (0.75, 0.45), (1.0, 0.0)]
    s1 = b
    s2 = o.cross(s1).normalized()
    rings = []
    for z, r in prof:
        c = surf + o * (z * kr * 0.75) - o * 0.02
        if r == 0:
            rings.append([sb.verts.new(c)])
        else:
            rings.append([sb.verts.new(c + (s1 * math.cos(a) * 1.25 + s2 * math.sin(a)) * kr * r)
                          for a in (2 * math.pi * j / 8 for j in range(8))])
        st += [0.0] * len(rings[-1])
    rp.loft(sb, rings, cap_start=False, cap_end=False)

    # Webbing: one sheet across all spines, two faces WEB_T apart, closed round the rim.
    ns = len(spines)
    cols = (ns - 1) * WEB_COLS_PER_GAP + 1
    top, bot, wt = [], [], []
    for j in range(cols):
        x = j / WEB_COLS_PER_GAP
        i0 = min(int(x), ns - 2)
        fr = x - i0
        dip = f["SCALLOP"] * math.sin(math.pi * fr) ** (1.0 / f["CUSP"])
        ext = f["WEB_END"] - dip
        rt, rb = [], []
        for i in range(WEB_ROWS + 1):
            t = WEB_T0 + (ext - WEB_T0) * (i / WEB_ROWS)
            p = spine_at(spines[i0], t).lerp(spine_at(spines[i0 + 1], t), fr)
            edge = 1.0 if j in (0, cols - 1) or i == WEB_ROWS else 0.0
            half = f["WEB_T"] * 0.5 * (1 - 0.55 * (i / WEB_ROWS)) * (1 - 0.4 * edge)
            rt.append(p + n * half)
            rb.append(p - n * half)
            wt.append(t)
        top.append(rt)
        bot.append(rb)
    wb = bmesh.new()
    vt = [[wb.verts.new(p) for p in col] for col in top]
    vb = [[wb.verts.new(p) for p in col] for col in bot]
    wvals = wt + wt
    for j in range(cols - 1):
        for i in range(WEB_ROWS):
            wb.faces.new((vt[j][i], vt[j + 1][i], vt[j + 1][i + 1], vt[j][i + 1]))
            wb.faces.new((vb[j][i + 1], vb[j + 1][i + 1], vb[j + 1][i], vb[j][i]))
    # rim: walk the sheet's boundary and stitch top to bottom
    loop = ([(0, i) for i in range(WEB_ROWS + 1)] + [(j, WEB_ROWS) for j in range(1, cols)]
            + [(cols - 1, i) for i in range(WEB_ROWS - 1, -1, -1)] + [(j, 0) for j in range(cols - 2, 0, -1)])
    for a, c in zip(loop, loop[1:] + loop[:1]):
        wb.faces.new((vt[a[0]][a[1]], vt[c[0]][c[1]], vb[c[0]][c[1]], vb[a[0]][a[1]]))
    return wb, wvals, sb, st, spines


def mirror_bm(bm):
    for v in bm.verts:
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=bm.faces)


def build_fins(name, f, root_col):
    col = collection(name, root_col)
    frame = fin_frame(f)
    root, b, u, n, surf = frame
    arm = new_armature(name + "_Rig", col)
    eb = arm.data.edit_bones
    rb = eb.new("Root")
    rb.head, rb.tail = HAT, HAT + Vector((0, 0, 0.25))
    rb.align_roll(Vector((1, 0, 0)))
    rb.use_deform = False
    mid_ang = math.radians(sum(s[0] for s in f["SPINES"]) / len(f["SPINES"]))
    mid_len = max(s[1] for s in f["SPINES"])
    d = (b * math.cos(mid_ang) + u * math.sin(mid_ang)).normalized()
    for tag, sx in (("L", 1), ("R", -1)):
        mx = lambda v: Vector((v.x * sx, v.y, v.z))  # noqa: E731
        nn = mx(n) if sx > 0 else Vector((-n.x, n.y, n.z))
        base = eb.new("Fin%sBase" % tag)
        base.head, base.tail = mx(root - (surf - root) * 1.5), mx(surf)
        base.align_roll(nn)
        base.parent = rb
        fin = eb.new("Fin%s" % tag)
        fin.head, fin.tail = mx(surf), mx(surf + d * mid_len * 0.5)
        fin.align_roll(nn)
        fin.parent, fin.use_connect = base, True
        tip = eb.new("Fin%sTip" % tag)
        tip.head, tip.tail = fin.tail, mx(surf + d * mid_len * 0.95)
        tip.align_roll(nn)
        tip.parent, tip.use_connect = fin, True
    bpy.ops.object.mode_set(mode="OBJECT")
    objs = []
    for tag, sx, nm in (("L", 1, "Left"), ("R", -1, "Right")):
        wb, wv, sb, sv, _ = build_fin(f, frame)
        if sx < 0:
            mirror_bm(wb)
            mirror_bm(sb)
        for bm, tv, region, mat, sharp in ((wb, wv, "Fin", "FinWeb", WEB_SHARP_DEG),
                                           (sb, sv, "FinSpines", "FinSpine", SHARP_DEG)):
            vv = [0.25 + 0.75 * t if mat == "FinWeb" else 1.0 for t in tv]   # webbing darker at the root
            o = new_object("%s_%s%s" % (name, nm, region), bm, material(mat), col, vv, sharp)
            w = [[("Fin%sBase" % tag, 1 - smoothstep(0.0, 0.08, t)),
                  ("Fin%s" % tag, smoothstep(0.0, 0.08, t) * (1 - smoothstep(0.35, 0.65, t))),
                  ("Fin%sTip" % tag, smoothstep(0.35, 0.65, t))] for t in tv]
            skin(o, arm, [[x for x in ws if x[1] > 1e-4] for ws in w])
            objs.append(o)
    return arm, objs


# ---------------------------------------------------------------------------------- plates ----
def catmull2(points, samples=200):
    pts = [Vector(p) for p in points]
    pts = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        n = samples // (len(pts) - 3)
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-2])
    return out


class Curve2:
    def __init__(self, points):
        self.p = catmull2(points)
        self.l = [0.0]
        for a, b in zip(self.p, self.p[1:]):
            self.l.append(self.l[-1] + (b - a).length)
        self.length = self.l[-1]

    def at(self, s):
        """(point, unit tangent, unit normal) at fraction s."""
        d = min(1.0, max(0.0, s)) * self.length
        for i in range(len(self.l) - 1):
            if self.l[i + 1] >= d:
                w = (d - self.l[i]) / max(1e-9, self.l[i + 1] - self.l[i])
                p = self.p[i].lerp(self.p[i + 1], w)
                t = (self.p[i + 1] - self.p[i]).normalized()
                return p, t, Vector((-t.y, t.x))
        t = (self.p[-1] - self.p[-2]).normalized()
        return self.p[-1], t, Vector((-t.y, t.x))


# Scale outlines, x from -1 (root) to +1 (free tip), y half-width 0..1: seven points, cheap and crisp.
SHAPES = {
    "round": [(-1.0, 0.0), (-0.55, 0.85), (0.35, 1.0), (0.9, 0.55), (0.9, -0.55), (0.35, -1.0), (-0.55, -0.85)],
    "point": [(-1.0, 0.0), (-0.55, 0.85), (0.1, 1.0), (0.6, 0.5), (1.0, 0.0), (0.6, -0.5), (0.1, -1.0), (-0.55, -0.85)],
    "blade": [(-1.0, 0.0), (-0.7, 0.9), (-0.1, 0.8), (0.5, 0.35), (1.0, 0.0), (0.5, -0.35), (-0.1, -0.8), (-0.7, -0.9)],
}


def add_scale(bm, vals, centre, tdir, ndir, half_len, half_w, pp, side):
    """One closed scale: its outline rising from root to tip, a raised centre (ridge), walls down
    to a smaller outline buried PLATE_BURY inside the head, so nothing is open or floating."""
    def lift(x):
        return PLATE_SEAM_H + 0.004 + (pp["LIFT"] - PLATE_SEAM_H) * ((x + 1) / 2) ** 1.5

    top, bot = [], []
    for x, w in SHAPES[pp["SHAPE"]]:
        q = centre + tdir * (x * half_len) + ndir * (w * half_w)
        top.append(bm.verts.new(head_point(q.x, q.y, lift(x), side)))
        vals.append(0.35 + 0.65 * (x + 1) / 2)          # darker where it tucks under the row above
        q2 = centre + tdir * (x * half_len * 0.7) + ndir * (w * half_w * 0.7)
        bot.append(bm.verts.new(head_point(q2.x, q2.y, -PLATE_BURY, side)))
        vals.append(1.0)
    cq = centre + tdir * (0.15 * half_len)
    peak = bm.verts.new(head_point(cq.x, cq.y, lift(0.15) + pp["RIDGE"], side))
    vals.append(0.9)
    m = len(top)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((top[i], top[j], peak))
        bm.faces.new((top[j], top[i], bot[i], bot[j]))
    bm.faces.new(list(reversed(bot)))


def build_patch(pp, side, sb, svals, ub, uvals):
    curve = Curve2(pp["CURVE"])
    # Underlay (Seam): a band along the curve, top PLATE_SEAM_H over the surface, bottom buried.
    across = 4
    top, bot = [], []
    for i in range(UNDER_ROWS + 1):
        s = i / UNDER_ROWS
        p, t, nrm = curve.at(s)
        w = interp(pp["WIDTH"], s) * 0.5 * PLATE_UNDER_W * (0.4 if i in (0, UNDER_ROWS) else 1.0)
        rt, rb = [], []
        for k in range(across):
            q = p + nrm * ((-1 + 2 * k / (across - 1)) * w)
            rt.append(ub.verts.new(head_point(q.x, q.y, PLATE_SEAM_H, side)))
            rb.append(ub.verts.new(head_point(q.x, q.y, -PLATE_BURY, side)))
            uvals += [1.0, 1.0]
        top.append(rt)
        bot.append(rb)
    for i in range(UNDER_ROWS):
        for k in range(across - 1):
            ub.faces.new((top[i][k], top[i][k + 1], top[i + 1][k + 1], top[i + 1][k]))
            ub.faces.new((bot[i + 1][k], bot[i + 1][k + 1], bot[i][k + 1], bot[i][k]))
    ring = ([(i, 0) for i in range(UNDER_ROWS + 1)] + [(UNDER_ROWS, k) for k in range(1, across)]
            + [(i, across - 1) for i in range(UNDER_ROWS - 1, -1, -1)] + [(0, k) for k in range(across - 2, 0, -1)])
    for a, c in zip(ring, ring[1:] + ring[:1]):
        ub.faces.new((top[a[0]][a[1]], top[c[0]][c[1]], bot[c[0]][c[1]], bot[a[0]][a[1]]))
    # Scales, brick-filled, root rows first.
    rows = max(2, round(curve.length / pp["ROW"]))
    spacing = curve.length / rows
    count = 0
    for r in range(rows):
        s = (r + 0.5) / rows
        p, t, nrm = curve.at(s)
        grade = pp["GRADE"][0] + (pp["GRADE"][1] - pp["GRADE"][0]) * s
        w = interp(pp["WIDTH"], s)
        last = r == rows - 1
        half_len = spacing * pp["LEN"] * 0.5 * grade * (pp["TIP_SCALE"] if last else 1.0)
        n = 1 if last else max(1, round(w / pp["CELL"]))
        cell = w / n
        brick = r % 2 == 1 and not last
        slots = [cell * (k + 0.5) - w / 2 for k in range(n)]
        if brick:
            slots = [cell * k - w / 2 for k in range(n + 1)]
            slots = [a for a in slots if abs(a) <= w / 2 - cell * 0.2] or [0.0]
        for a in slots:
            c = p + nrm * a + t * (half_len * 0.3 if last else 0.0)
            hw = max(0.03, cell * SCALE_WIDE * (1 - pp["GAP"]) * grade)
            if abs(a) > w / 2 - cell * 0.6:
                hw *= 0.85                                 # edge scales a little smaller: a clean rim
            add_scale(sb, svals, c, t, nrm, half_len, hw, pp, side)
            count += 1
    return count


def build_plates(name, patches, root_col):
    col = collection(name, root_col)
    objs = []
    for nm, side in (("Left", 1), ("Right", -1)):
        sb, sv, ub, uv = bmesh.new(), [], bmesh.new(), []
        for pp in patches:
            build_patch(pp, side, sb, sv, ub, uv)
        if side < 0:
            bmesh.ops.reverse_faces(sb, faces=sb.faces)
            bmesh.ops.reverse_faces(ub, faces=ub.faces)
        objs.append(new_object("%s_%sScales" % (name, nm), sb, material("Scale"), col, sv, SHARP_DEG))
        objs.append(new_object("%s_%sSeam" % (name, nm), ub, material("Seam"), col, uv, SHARP_DEG))
    return objs


# ---------------------------------------------------------------------------------- rig -------
def new_armature(name, col):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    if bpy.data.armatures.get(name):
        bpy.data.armatures.remove(bpy.data.armatures[name])
    ob = bpy.data.objects.new(name, bpy.data.armatures.new(name))
    col.objects.link(ob)
    ob.hide_render = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    return ob


def skin(obj, arm, weights_per_vert):
    obj.parent = arm
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    for vi, ws in enumerate(weights_per_vert):
        for name, w in ws:
            vg = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
            vg.add([vi], w, "REPLACE")


def pose(arm, flare=0.0, tip=0.0):
    """Fin check pose: FinL/R flared `flare` degrees about local X, the tips a further `tip`."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        if pb.name in ("FinL", "FinR"):
            pb.rotation_euler = (math.radians(flare), 0, 0)
        if pb.name in ("FinLTip", "FinRTip"):
            pb.rotation_euler = (math.radians(tip), 0, 0)
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------------- sheet -----
HEAD_T = Vector((0.0, 0.25, 2.75))
# (name, eye direction, target, ortho scale or None, distance)
VIEWS = [
    ("game", (-0.55, -1.0, 0.30), (0, 0, 1.5), None, 9.5),
    ("front", (0, -1, 0.05), HEAD_T, 3.3, 20),
    ("side", (1, 0, 0.05), HEAD_T, 3.3, 20),
    ("back", (0, 1, 0.12), HEAD_T, 3.3, 20),
    ("threequarter", (-0.8, -0.75, 0.25), HEAD_T, 3.3, 20),
    ("flared", (0.75, 0.9, 0.35), HEAD_T, 3.3, 20),
]
CLOSE = [("seat", (1.0, -0.55, 0.06), 1.9),      # plates from just above head height, front-side
         ("root", (0.35, 1.0, 0.25), 1.8)]       # fin root from behind and a little above


def render_tiles(scene, root_col, out_dir, res=420):
    rp.setup_render(scene, res=(res, res))
    layer = scene.view_layers[0].layer_collection.children[root_col.name]
    shots = []
    for d, _, _ in DIRECTIONS:
        fins, plates = "SerpentFins" + d, "SerpentScales" + d
        for c in layer.children:
            c.exclude = c.name not in (fins, plates)
        arm = bpy.data.objects[fins + "_Rig"]
        for view, e, tgt, ortho, dist in VIEWS:
            pose(arm, *((30.0, 20.0) if view == "flared" else (0.0, 0.0)))
            eye = Vector(tgt) + Vector(e).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (d, view)), tuple(eye),
                                   tuple(tgt), ortho=ortho, lens=50))
        pose(arm)
        pp = PLATES[d][0]
        mid = Curve2(pp["CURVE"]).at(0.5)[0]
        tgt = head_point(mid.x, mid.y, 0.0)
        f = FINS[d]
        root = head_surface(f["PHI"], f["Z"])[0]
        for (view, e, dist), t in zip(CLOSE, (tgt, root)):
            eye = t + Vector(e).normalized() * dist
            shots.append(rp.render(scene, os.path.join(out_dir, "%s_%s.png" % (d, view)), tuple(eye), tuple(t),
                                   lens=50))
    return shots


# ---------------------------------------------------------------------------------- ratios ----
def head_box():
    """The R6 head mesh's bounding box (rig vertices above the neck)."""
    rig = rig_mesh()
    vs = [rig.matrix_world @ v.co for v in rig.data.vertices]
    vs = [v for v in vs if v.z > 2.05]
    mn = Vector([min(v[i] for v in vs) for i in range(3)])
    mx = Vector([max(v[i] for v in vs) for i in range(3)])
    return mn, mx


def bbox(objs):
    vs = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return (Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)]))


def ratios(fobjs, pobjs):
    """Sizes as fractions of the head (width = X, depth = Y, height = Z of the head's box)."""
    hmn, hmx = head_box()
    hs = hmx - hmn
    lf = [o for o in fobjs if "_Left" in o.name]
    fmn, fmx = bbox(lf)
    root = min((o.matrix_world @ v.co for o in lf for v in o.data.vertices), key=lambda p: p.z).z
    lp = [o for o in pobjs if "_Left" in o.name]
    pmn, pmx = bbox(lp)
    allmn, allmx = bbox(fobjs)
    r = dict(
        head=dict(width=round(hs.x, 3), depth=round(hs.y, 3), height=round(hs.z, 3)),
        fin_height=round((fmx.z - fmn.z) / hs.z, 2),          # one fin's vertical extent / head height
        fin_length=round((fmx.y - fmn.y) / hs.y, 2),          # its front-to-back extent / head depth
        fin_rise=round((fmx.z - hmx.z) / hs.z, 2),            # how far it rises over the head top
        fin_reach_back=round((fmx.y - hmx.y) / hs.y, 2),      # how far it trails behind the head
        span=round((allmx.x - allmn.x) / hs.x, 2),            # fins tip to tip / head width
        plate_height=round((pmx.z - pmn.z) / hs.z, 2),        # one plate / head height
        plate_width=round(max(pmx.y - pmn.y, pmx.x - pmn.x) / hs.x, 2),  # its widest horizontal extent / head width
    )
    return r


# ---------------------------------------------------------------------------------- export ----
def r3(v):
    return [round(x, 3) for x in v]


def to_roblox(v):
    """Blender point in attachment space -> the attachment's Roblox frame (README, Space)."""
    return [round(-v[0], 3), round(v[2], 3), round(v[1], 3)]


def export_set(name, arm, objs, extra):
    """FBX + JSON in HatAttachment space (the attachment is the origin), then move back."""
    m = Matrix.Translation(-HAT)
    if arm:
        pose(arm)
        arm.data.transform(m)
    for o in objs:
        o.data.transform(m)
    bpy.context.view_layer.update()
    try:
        for o in bpy.context.selected_objects:
            o.select_set(False)
        sel = ([arm] if arm else []) + objs
        for o in sel:
            o.select_set(True)
        bpy.context.view_layer.objects.active = sel[0]
        bpy.ops.export_scene.fbx(filepath=os.path.join(HERE, name + ".fbx"), use_selection=True,
                                 object_types={"ARMATURE", "MESH"}, apply_unit_scale=True,
                                 apply_scale_options="FBX_SCALE_UNITS", axis_forward="-Z", axis_up="Y",
                                 mesh_smooth_type="EDGE", add_leaf_bones=False, bake_anim=False,
                                 primary_bone_axis="Y", secondary_bone_axis="X", use_armature_deform_only=False)
        meshes = {}
        for o in objs:
            ws = [v.co for v in o.data.vertices]
            mn = Vector([min(v[i] for v in ws) for i in range(3)])
            mx = Vector([max(v[i] for v in ws) for i in range(3)])
            meshes[o.name] = dict(region=o["region"], material=o.data.materials[0].name, tris=tri_count(o),
                                  center=r3((mn + mx) / 2), size=r3(mx - mn), roblox_center=to_roblox((mn + mx) / 2))
        bones = {}
        if arm:
            for b in arm.data.bones:
                bones[b.name] = dict(parent=b.parent.name if b.parent else None, head=r3(b.head_local),
                                     tail=r3(b.tail_local), roblox_head=to_roblox(b.head_local), deform=b.use_deform)
        report = dict(
            name=name, attachment="HatAttachment", attachment_avatar_space=r3(HAT),
            units="1 Blender unit = 1 stud; positions relative to HatAttachment (Blender +X avatar left, "
                  "-Y avatar front, Z up)",
            roblox_mapping="a Blender point (x, y, z) is (-x, z, y) in the attachment's Roblox frame; "
                           "mesh Size = (bx, bz, by), CFrame from the attachment = CFrame.new(-cx, cz, cy)",
            colors={k: r3(v[:3]) for k, v in COLORS.items()}, material_prefix=MAT_PREFIX,
            translucent={"FinWeb": 0.35}, neon=["Seam"],
            shade=dict(file=SHADE_FILE, uv="V only (U = 0.5)", darkest=SHADE_MIN, fade_to_white_at_v=SHADE_REACH,
                       note="identical to fox_shade.png: reuse rbxassetid://124559907609415"),
            meshes=meshes, tris_total=sum(q["tris"] for q in meshes.values()), bones=bones)
        report.update(extra)
        with open(os.path.join(HERE, name + ".json"), "w") as fh:
            json.dump(report, fh, indent=1)
    finally:
        mi = Matrix.Translation(HAT)
        if arm:
            arm.data.transform(mi)
        for o in objs:
            o.data.transform(mi)
        bpy.context.view_layer.update()


def lineup():
    """One R6 body per direction, side by side (tools/blender_lineup.py), rendered for the sheet."""
    tool = os.path.join(REPO, "tools", "blender_lineup.py")
    looks = [[["SerpentFins" + d, "SerpentScales" + d] for d, _, _ in DIRECTIONS]]
    exec(compile(open(tool).read(), tool, "exec"), {"LOOKS": looks, "SPACING": 4.5, "__name__": "__main__"})
    scn = bpy.data.scenes["Lineup"]
    if RENDER:
        rp.setup_render(scn, res=(1260, 420))
        for o in [o for o in scn.objects if o.name.startswith("Label_")]:
            o.hide_render = True
        for view, eye, tgt, ortho in (("front", (0, -30, 4.2), (0, 0, 1.4), 14.5),
                                      ("threequarter", (-17, -24, 9), (0, 0.3, 1.4), 15.5)):
            rp.render(scn, os.path.join(HERE, "renders", "Lineup_%s.png" % view), eye, tgt, ortho=ortho)
    return scn


# ---------------------------------------------------------------------------------- main ------
def main():
    scene = rp.use_scene(SCENE)
    blend = os.path.join(HERE, "Serpent.blend")
    if bpy.data.filepath != blend:
        bpy.ops.wm.save_as_mainfile(filepath=blend)   # early, so the window title names the set
    rp.import_rig(scene)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    root_col = bpy.data.collections.get(ROOT_COLLECTION) or bpy.data.collections.new(ROOT_COLLECTION)
    if root_col.name not in scene.collection.children:
        scene.collection.children.link(root_col)
    shade_image()
    report, built = {}, {}
    for d, _, _ in DIRECTIONS:
        arm, fobjs = build_fins("SerpentFins" + d, FINS[d], root_col)
        pobjs = build_plates("SerpentScales" + d, PLATES[d], root_col)
        report[d] = dict(fins={o.name: tri_count(o) for o in fobjs}, plates={o.name: tri_count(o) for o in pobjs})
        report[d]["fins_total"] = sum(report[d]["fins"].values())
        report[d]["plates_total"] = sum(report[d]["plates"].values())
        report[d]["ratios"] = ratios(fobjs, pobjs)
        built[d] = (arm, fobjs, pobjs)
    print(json.dumps(report, indent=1))
    os.makedirs(os.path.join(HERE, "renders"), exist_ok=True)
    with open(os.path.join(HERE, "renders", "ratios.json"), "w") as fh:
        json.dump({d: report[d]["ratios"] for d in report}, fh, indent=1)
    if EXPORT:
        for d, (arm, fobjs, pobjs) in built.items():
            q = report[d]["ratios"]
            export_set("SerpentFins" + d, arm, fobjs, dict(direction=d, ratios_to_head={
                k: q[k] for k in ("head", "fin_height", "fin_length", "fin_rise", "fin_reach_back", "span")}))
            export_set("SerpentScales" + d, None, pobjs, dict(direction=d, ratios_to_head={
                k: q[k] for k in ("head", "plate_height", "plate_width")}))
    if RENDER:
        print(len(render_tiles(scene, root_col, os.path.join(HERE, "renders"))), "tiles")
        for c in scene.view_layers[0].layer_collection.children[root_col.name].children:
            c.exclude = False
    lineup()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "Serpent.blend"))


main()
