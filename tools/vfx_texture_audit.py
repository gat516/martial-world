"""Texture-reuse lint: the "stock soft glow / spark dot / plain ring" rule in
docs/vfx/style.md, made mechanical.

  python3 tools/vfx_texture_audit.py [SPEC ...] [--top N] [--no-templates] [--all]

1. Counts asset-id uses (textures, flipbooks, meshes) over the exported
   templates (assets/Effects.rbxm, converted with `rojo build` to an .rbxmx in
   a temp dir; one use per instance property) and prints the N (default 10)
   most used. With --no-templates (or if rojo fails) it counts references in
   the specs instead.
2. Reads the roles each spec marks for its layers, in three forms:
     - a LAYER SHEET line in the header (ThunderApe, ElderWolfKing):
         -- SwingArc     HERO: the fist ... -> crescent 88807999398470 ...; secondary arcs 7697...
       every id after HERO belongs to the hero until the next role word
       (secondary, tertiary, environment, support);
     - a trailing `-- hero` / `-- secondary` comment on an emitter line;
     - prose in the comment above a template block, "... dust ring (hero) ...":
       the words before "(hero" are matched to the block's emitter names
       (DustRing), and the emitter's texture is read off the exported template
       (or the spec line's TEX.key / id(N) when the template isn't exported).
3. Flags every hero or secondary layer whose asset is one of the top N.
   A use right after "core", "cores", "shadow" or "sparkle" in a layer sheet
   is allowed (the style rule keeps generic glows for cores and sparkles).

Exit 1 when any hero layer is flagged (secondary flags are warnings).
Specs that mark no roles are listed as "roles unmarked": the lint can't judge
them, so mark a LAYER SHEET when you next touch one.
"""

import collections
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPECS = os.path.join(ROOT, "tools", "vfx_specs")
EFFECTS = os.path.join(ROOT, "assets", "Effects.rbxm")
ROLE_WORDS = ("hero", "secondary", "tertiary", "environment", "support")
ALLOWED_BEFORE = ("core", "cores", "shadow", "shadows", "sparkle", "sparkles")
ASSET_PROPS = {"TextureContent", "Texture", "MeshId", "MeshContent", "TextureID", "Image", "ImageContent"}
ID = re.compile(r"(?:rbxassetid://|asset/\?id=)(\d+)")


# ---------------------------------------------------------------- templates

def load_templates():
    """{ "Group.Template": [(instance path, class, asset id), ...] } from the
    exported Effects.rbxm, or None if rojo can't convert it."""
    tmp = tempfile.mkdtemp(prefix="vfx_audit_")
    proj = os.path.join(tmp, "e.project.json")
    out = os.path.join(tmp, "e.rbxmx")
    open(proj, "w").write('{"name":"Effects","tree":{"$path":"%s"}}' % EFFECTS)
    try:
        subprocess.run(["rojo", "build", proj, "-o", out], cwd=ROOT, check=True, capture_output=True)
    except (OSError, subprocess.CalledProcessError) as ex:
        print(f"(templates skipped: rojo build failed: {ex})")
        return None
    templates = collections.defaultdict(list)

    def walk(item, path):
        props = item.find("Properties")
        name = "?"
        if props is not None:
            for p in props:
                if p.get("name") == "Name":
                    name = p.text or "?"
            here = path + [name]
            for p in props:
                if p.get("name") in ASSET_PROPS:
                    text = "".join(p.itertext())
                    for m in ID.finditer(text):
                        key = ".".join(here[1:3]) if len(here) >= 3 else ".".join(here[1:])
                        templates[key].append((".".join(here[3:]) or name, item.get("class"), m.group(1)))
        else:
            here = path + [name]
        for child in item.findall("Item"):
            walk(child, here)

    tree = ET.parse(out)
    for top in tree.getroot().findall("Item"):
        walk(top, [])
    return templates


# ---------------------------------------------------------------- specs

def tex_table(src):
    """TEX.key / MESH.key -> id, from `key = id(N)` / `key = "rbxassetid://N"`."""
    table = {}
    for m in re.finditer(r"\b([A-Za-z_]\w*)\s*=\s*(?:id\(\s*(\d+)\s*\)|\"rbxassetid://(\d+)\")", src):
        table[m.group(1)] = m.group(2) or m.group(3)
    return table


def line_ids(line, table):
    ids = [m.group(1) for m in re.finditer(r"\bid\(\s*(\d+)\s*\)", line)]
    ids += ID.findall(line)
    ids += [table[k] for k in re.findall(r"\b(?:TEX|MESH|FLIP|IDS)\.(\w+)", line) if k in table]
    return ids


def sheet_roles(src):
    """LAYER SHEET lines -> [(template, role, id, allowed, line no)]."""
    out = []
    lines = src.split("\n")
    start = next((i for i, l in enumerate(lines) if "LAYER SHEET" in l), None)
    if start is None:
        return out
    for i in range(start + 1, len(lines)):
        l = lines[i]
        if not l.startswith("--"):
            break
        body = l[2:].strip()
        m = re.match(r"([A-Z][\w/ ]*?)\s{2,}|([A-Z]\w*(?: / [A-Z]\w*)*)\s+(?=HERO|hero|secondary|tertiary|environment|support)", body)
        if not m:
            continue
        names = [n.strip() for n in (m.group(1) or m.group(2)).split("/") if n.strip()]
        rest = body[m.end():]
        role = None
        for tok in re.finditer(r"[A-Za-z]+|\d{6,}", rest):
            w = tok.group(0)
            if w.lower() in ROLE_WORDS:
                role = w.lower()
            elif w.isdigit() and role:
                before = re.findall(r"[a-z]+", rest[max(0, tok.start() - 40):tok.start()].lower())[-3:]
                after = re.match(r"\s*\(([^)]*)\)", rest[tok.end():])
                note = re.findall(r"[a-z]+", after.group(1).lower()) if after else []
                allowed = any(b in ALLOWED_BEFORE for b in before + note)
                for n in names:
                    out.append((n, role, w, allowed, i + 1))
    return out


TEMPLATE_START = re.compile(r"\b(?:part|anchor)\(\s*(?:root\s*,\s*)?\"(\w+)\"")
EMITTER = re.compile(r"\b(?:em|emitter)\(\s*[^,]+,\s*\"(\w+)\"")


def blocks(src):
    """Template blocks: [(template name, comment text above it, [(emitter, line, line no)])]."""
    lines = src.split("\n")
    out = []
    cur = None
    for i, l in enumerate(lines):
        m = TEMPLATE_START.search(l)
        if m and not l.lstrip().startswith("--") and "function" not in l:
            # comment block directly above (skipping a `do`)
            j, comment = i - 1, []
            while j >= 0 and (lines[j].strip() in ("do", "") or lines[j].lstrip().startswith("--")):
                if lines[j].lstrip().startswith("--"):
                    comment.insert(0, lines[j].lstrip()[2:].strip())
                elif lines[j].strip() == "" and comment:
                    break
                j -= 1
            cur = (m.group(1), " ".join(comment), [])
            out.append(cur)
        if cur:
            for e in EMITTER.finditer(l):
                cur[2].append((e.group(1), l, i + 1))
    return out


def camel_words(name):
    return [w.lower() for w in re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])|\d+", name)]


def prose_roles(src):
    """(hero) / (secondary) in a block's comment -> [(template, role, emitter, line, line no)]."""
    out = []
    for template, comment, ems in blocks(src):
        for m in re.finditer(r"\((hero|secondary)\b", comment, re.I):
            role = m.group(1).lower()
            phrase = re.split(r"[,.;:]|\+\d+", comment[:m.start()])[-1].lower()
            words = set(re.findall(r"[a-z]{3,}", phrase))
            words |= {w[:-1] for w in words if w.endswith("s")}
            best, score = None, 0
            for name, line, no in ems:
                s = len(words & set(camel_words(name)))
                if s > score and not name.lower().endswith(("dark", "slate", "ink")):
                    best, score = (name, line, no), s
            if best:
                out.append((template, role, best[0], best[1], best[2]))
            else:
                out.append((template, role, None, phrase.strip()[-50:], None))
    return out


def explicit_roles(src):
    out = []
    for template, _, ems in blocks(src):
        for name, line, no in ems:
            m = re.search(r"--\s*(hero|secondary)\b", line, re.I)
            if m:
                out.append((template, m.group(1).lower(), name, line, no))
    return out


def template_asset(templates, group, template, emitter):
    """Asset ids of an emitter (by name, any tier) in the exported template."""
    if not templates:
        return []
    ids = []
    for key in (f"{group}.{template}", *[f"{group}.{template}_T{t}" for t in range(1, 5)]):
        for path, cls, aid in templates.get(key, []):
            if path.split(".")[-1] == emitter and aid not in ids:
                ids.append(aid)
    return ids


# ---------------------------------------------------------------- main

def main():
    args = sys.argv[1:]
    top_n = 10
    if "--top" in args:
        i = args.index("--top")
        top_n = int(args[i + 1])
        del args[i:i + 2]
    use_templates = "--no-templates" not in args
    show_all = "--all" in args
    args = [a for a in args if not a.startswith("--")]
    spec_files = sorted(args) if args else sorted(
        os.path.join(SPECS, f) for f in os.listdir(SPECS) if f.endswith(".luau"))

    templates = load_templates() if use_templates else None
    counts = collections.Counter()
    where = collections.defaultdict(set)
    if templates:
        for key, uses in templates.items():
            for path, cls, aid in uses:
                counts[aid] += 1
                where[aid].add(key.split(".")[0])
        basis = f"uses in {len(templates)} exported templates"
    else:
        for f in sorted(os.listdir(SPECS)):
            if f.endswith(".luau"):
                src = open(os.path.join(SPECS, f)).read()
                for aid in re.findall(r"\b(\d{7,})\b", src):
                    counts[aid] += 1
                    where[aid].add(f[:-5])
        basis = "references in the specs"
    total = sum(counts.values())
    top = [aid for aid, _ in counts.most_common(top_n)]
    share = sum(counts[a] for a in top) / max(1, total)
    print(f"== top {top_n} asset ids ({basis}; {total} uses, the top {top_n} are {share:.0%})")
    for aid in top:
        groups = sorted(where[aid])
        print(f"  {aid:>16} {counts[aid]:5}  in {len(groups)} groups: {', '.join(groups[:8])}{' ...' if len(groups) > 8 else ''}")
    topset = set(top)

    heroes, seconds, unmarked = 0, 0, []
    for path in spec_files:
        src = open(path).read()
        group = os.path.basename(path)[:-5]
        table = tex_table(src)
        flags, checked = [], 0
        for template, role, aid, allowed, no in sheet_roles(src):
            if role not in ("hero", "secondary"):
                continue
            checked += 1
            if aid in topset:
                flags.append((role, template, f"sheet:{no}", aid, allowed))
        for template, role, emitter, line, no in prose_roles(src) + explicit_roles(src):
            if emitter is None:
                if show_all:
                    flags.append((role, template, "prose", f"unmatched '{line}'", True))
                continue
            checked += 1
            ids = template_asset(templates, group, template, emitter) or line_ids(line, table)
            for aid in ids:
                if aid in topset:
                    flags.append((role, f"{template}.{emitter}", f"line {no}", aid, False))
        if not checked:
            unmarked.append(group)
            continue
        bad = [f for f in flags if not f[4]]
        verdict = "FAIL" if any(f[0] == "hero" for f in bad) else ("WARN" if bad else "ok")
        print(f"== {group}: {verdict} ({checked} role-marked layers, {len(bad)} on a top-{top_n} asset)")
        seen = set()
        for role, what, at, aid, allowed in flags:
            if (role, what, aid) in seen or (allowed and not show_all):
                continue
            seen.add((role, what, aid))
            tag = ("unmatched" if at == "prose" else "ok (core)") if allowed else role.upper()
            print(f"  {tag:10} {what:28} {aid:>16}  ({at})")
            if not allowed and role == "hero":
                heroes += 1
            elif not allowed:
                seconds += 1
    if unmarked:
        print(f"== roles unmarked ({len(unmarked)} specs, can't judge): {', '.join(unmarked)}")
    print(f"verdict: {heroes} hero and {seconds} secondary layers on a top-{top_n} asset")
    return 1 if heroes else 0


if __name__ == "__main__":
    sys.exit(main())
