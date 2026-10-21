# Unpacks the vfxia add-ons installed in the user's plugin (stored as base64
# .rbxm under "vfxerAddons" in Studio's plugin settings) into readable .rbxmx
# under tools/frag/addons/ (gitignored), so their game modules can be read for
# tags and attributes. Usage: python3 tools/vfx_addons.py [settings.json]
#   python3 tools/vfx_addons.py --summary   (after unpacking) writes
#   tools/vfx_addons.md: each add-on's tag, the attributes its game module
#   reads (with defaults and types where it declares them), and our own notes
#   (CSV formats, gotchas). The cheat-sheet holds only that summary, no source.
import base64, glob, json, os, re, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "frag", "addons")
ROJO = os.path.expanduser("~/.rokit/bin/rojo")

def settings_path():
    if len(sys.argv) > 1:
        return sys.argv[1]
    for path in glob.glob("/mnt/c/Users/*/AppData/Local/Roblox/*/InstalledPlugins/0/settings.json"):
        with open(path, encoding="utf-8", errors="replace") as f:
            if '"vfxerAddons"' in f.read():
                return path
    sys.exit("no plugin settings with vfxerAddons found; pass the path")

# Our own notes per add-on, learned building effects with them.
NOTES = {
    "Craters": [
        "Put the tag on an Attachment (or Part); rocks spawn around its world CFrame, raycast down `RaycastDistance`.",
        "`Shape=Ring, Fill=true, EmissionStart=Progressive, Duration=<active>` erupts rocks outward over Duration (a ring that grows with a wave).",
        "`Shape=Cone` + `ConeAngle` kicks rocks out along the attachment's look direction (impacts).",
        "Rays skip player characters and anything tagged `CraterIgnore`, not enemies: tag beasts `CraterIgnore` on the client.",
        "`Collision` defaults to true: set false. Parts land in TempVFX with no CastShadow option, so count them in the budget.",
        "`MatchGround` copies the hit surface's colour, material and textures (green rocks on grass). `UseMesh`+`MeshId` (e.g. Inno Rock_03 17608108317) reads better than blocks; raise/tilt them (YOffset ~0.45, AngleX 25-50).",
    ],
    "SimpleMeshVFX": [
        "A Model/Folder with `Start` and `End` BaseParts (or a part with an `End` child, or the `MeshVFX` tag): clones Start EmitCount times and tweens each to End's Size/Color/CFrame, fading to `EndTransparency` (default 1).",
        "`Part_TweenParams` = \"Style,Direction,repeatCount,reverses(t),delay,time\" (e.g. \"Quad,Out\").",
        "Keep Start and End at Transparency 1 in the template; clones show from `StartTransparency`, so the plain fallback shows nothing.",
        "Only emits for instances under workspace.",
    ],
    "Splines": [
        "Tag `SplineVFX` on a Part or Attachment. Control points: child Attachments named `1`, `2`, ... plus `End` (or an ObjectValue). The first other PVInstance child is the template moved along the TCB path (put a Trail on it).",
        "Start points come from the part's volume (`Shape`/`ShapeStyle`/`SpreadAngle`); `SyncPosition` maps the path onto the part's live CFrame (move the part to make the path follow a hand).",
        "Children named `EmitOnHit` / `EmitOnFinish` are emitted at the end.",
        "The Game Module doesn't descend from a Part into Parts nested in it: emit a nested SplineVFX part on its own.",
        "Trails move on Heartbeat and can't be frozen for a still.",
    ],
    "ScreenEffects": [
        "CSV attributes; fields parse by the default's type: NumberRange `30~120`, Vector3 `1;2;3`, empty field = default. Color3 didn't parse in any format tried, so leave TintColor empty.",
        "`CameraShake` = `Preset,FalloffDistance,Magnitude,FadeOutTime,Roughness,FadeInTime,RotInfluence,PosInfluence`; presets Custom, Explosion, Earthquake, Vibration. Default falloff 100~500 studs: set your own (e.g. `25~90`).",
        "`ImpactFrames` = `Count,TintColor,Range,Contrast,Saturation,MinVisiblity,-Duration,+Duration`: flips a ColorCorrection's contrast (desaturated) Count times, only within Range and when the point is visible.",
        "Put each attribute on its own empty Attachment, so inherited emit attributes don't fire it once per child emitter.",
        "In Edit mode CameraShake moves the editor camera (captures inherit the roll): strip it in previews.",
    ],
    "LightningBeams": ["Not used yet; read its game module before the lightning technique."],
    "AnimationUtil": ["Plugin-side only (no game module)."],
}


def sources(path):
    """{module path: source} for every script in an unpacked add-on."""
    out = {}
    def walk(item, prefix):
        props = item.find("Properties")
        name = props.find("*[@name='Name']").text if props is not None and props.find("*[@name='Name']") is not None else "?"
        here = prefix + "." + name if prefix else name
        if props is not None:
            src = props.find("*[@name='Source']")
            if src is not None and src.text:
                out[here] = src.text
        for child in item.findall("Item"):
            walk(child, here)
    for item in ET.parse(path).getroot().findall("Item"):
        walk(item, "")
    return out


def lua_type(value):
    v = value.strip().rstrip(",")
    for prefix, kind in (("NumberRange", "NumberRange"), ("Vector3", "Vector3"), ("Vector2", "Vector2"), ("vector", "Vector3"),
                         ("Color3", "Color3"), ("NumberSequence", "NumberSequence"), ("Enum.", "Enum"), ("CFrame", "CFrame")):
        if v.startswith(prefix):
            return kind
    if v.startswith("{"):
        return "one of"
    if v in ("true", "false"):
        return "boolean"
    if v.startswith('"'):
        return "string"
    if re.match(r"^-?[\d.]+", v):
        return "number"
    return "?"


def defaults_of(src):
    """Entries of the module's `defaults`/`Defaults` table: (key, value text)."""
    m = re.search(r"local\s+[Dd]efaults\s*=\s*\{", src)
    if not m:
        return []
    i, depth, start = m.end(), 1, m.end()
    while depth and i < len(src):
        depth += {"{": 1, "}": -1}.get(src[i], 0)
        i += 1
    body = src[start:i - 1]
    entries, depth, cur = [], 0, ""
    for ch in body:
        if ch in "{(":
            depth += 1
        elif ch in "})":
            depth -= 1
        if ch == "," and depth == 0:
            entries.append(cur)
            cur = ""
        else:
            cur += ch
    entries.append(cur)
    out = []
    for e in entries:
        e = " ".join(e.split())
        km = re.match(r'^(?:\[\s*"([^"]+)"\s*\]|(\w+))\s*=\s*(.+)$', e)
        if km:
            out.append((km.group(1) or km.group(2), km.group(3)))
    return out


def summary():
    lines = ["# vfxia add-ons: cheat-sheet", "",
             "Generated by `python3 tools/vfx_addons.py --summary` from the installed add-ons'",
             "game modules (unpacked to tools/frag/addons/), plus our own notes. Re-run after",
             "the plugin updates. Attribute names are what each `game` module reads off the",
             "effect; defaults/types come from its defaults table where it has one.", ""]
    for path in sorted(glob.glob(os.path.join(OUT, "*.rbxmx"))):
        name = os.path.basename(path)[:-6]
        srcs = sources(path)
        game = next((s for k, s in srcs.items() if k.endswith(".game")), "")
        lines += [f"## {name}", ""]
        tags = sorted(set(re.findall(r'HasTag\("(\w+)"\)', game)) | set(re.findall(r'\btag\s*=\s*"(\w+)"', game))
                      | set(re.findall(r'selector\s*=\s*"\.(\w+)"', game)))
        if not game:
            lines += ["No `game` module (plugin-side only).", ""]
        else:
            selectors = sorted(set(re.findall(r'selector\s*=\s*[`"]([^`"]+)[`"]', game)))
            lines += [f"- Tag: {', '.join('`' + t + '`' for t in tags) if tags else 'none (driven by attributes)'}"]
            if selectors:
                lines += [f"- Selector (instances it handles): {', '.join('`' + x + '`' for x in selectors)}"]
            defaults = defaults_of(game)
            if defaults:
                lines += ["", "| Attribute | Default | Type |", "|---|---|---|"]
                for k, v in defaults:
                    shown = v if len(v) < 60 else v[:57] + "..."
                    lines.append(f"| `{k}` | `{shown}` | {lua_type(v)} |")
            used = sorted((set(re.findall(r"\battrs?\.(\w+)", game)) | set(re.findall(r"\battributes\.(\w+)", game)))
                          - {k for k, _ in defaults} - {"EmitBreak"})
            if used:
                lines += ["", "Also reads: " + ", ".join(f"`{u}`" for u in used)]
            lines.append("")
        for note in NOTES.get(name, []):
            lines.append(f"- {note}")
        lines.append("")
    target = os.path.join(HERE, "vfx_addons.md")
    open(target, "w").write("\n".join(lines))
    print(target)


if "--summary" in sys.argv:
    summary()
    sys.exit(0)

data = json.load(open(settings_path(), encoding="utf-8"))
os.makedirs(OUT, exist_ok=True)
for name, blob in data.get("vfxerAddons", {}).items():
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "m.rbxm"), "wb") as f:
            f.write(base64.b64decode(blob))
        with open(os.path.join(tmp, "default.project.json"), "w") as f:
            json.dump({"name": name, "tree": {"$path": "m.rbxm"}}, f)
        target = os.path.join(OUT, name + ".rbxmx")
        # rojo must run from this project so rokit finds it
        subprocess.run([ROJO, "build", os.path.join(tmp, "default.project.json"), "-o", target],
                       cwd=os.path.dirname(HERE), check=True, capture_output=True)
        print(target)
