"""Offline check of the names effect code looks up: rig hooks against the rig
docs, template names against the exported templates. Catches a renamed or
mistyped attachment or template before anything runs.

  python3 tools/vfx_hooks_check.py [Module ...] [--no-templates] [--quiet]

Enemy effects (src/client/EnemyFX/<Module>.luau):
  - hooks: the first argument of every point / K.point / K.host / K.attachment /
    groundFrame / hookPart / attachmentNamed call, FindFirstChild(name, true),
    and every "..._FX" string. Literals, "A" .. side .. "_FX" concatenations and
    `A{side}_FX` interpolations (the variable part matches any name) are
    checked against the attachments the body's rig doc defines
    (art/enemies/*/RIGS.md and art/enemies/*/rigs/*.md: backticked names, the
    first column of an Attachment/Hook table, "Name (Part, ...)" lists on a
    line about attachments or hooks). A plain variable is listed as dynamic.
  - templates: the first string argument of play / make / template /
    windupPlay / K.play / K.template / K.beam, against the template names in
    assets/Effects.rbxm (`rojo build` to a temp .rbxmx) under the module's group.
Player techniques (src/client/TechniqueFX/*.luau, CastFX, CombatEffects):
  - body hooks (FindFirstChild on character / child / arm / hand / weapon)
    against the R6/R15 rig names, the rig's own attachments and the weapon
    attachments the docs name (docs/systems/weapons.md,
    docs/combat/technique-visuals.md, docs/combat/techniques/*.md,
    docs/vfx/toolkit/building.md);
  - template children (FindFirstChild / take / TechniqueVFX.part on a copy),
    against the instance names in that technique's exported templates.

Exit 1 on any hook or template name that isn't defined. The live counterpart is
tools/vfx_origin_check.luau (what the real body exposes, where each layer sits).
"""

import collections
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMY_FX = os.path.join(ROOT, "src", "client", "EnemyFX")
TECH_FX = os.path.join(ROOT, "src", "client", "TechniqueFX")
ART = os.path.join(ROOT, "art", "enemies")

# modules whose body has no rig doc of its own: the family doc covers them
DOC_OVERRIDE = {"SpiritWolf": ["wolf_family/RIGS.md"], "ElderWolfKing": ["wolf_family/RIGS.md"]}
GROUP_OVERRIDE = {"Impact": "EnemyImpact"}
SKIP = {"BeastKit", "init"}
NO_BODY = {"Impact"}  # shared stacks played at points the caller passes

R6 = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}
R15 = {"UpperTorso", "LowerTorso"} | {f"{s}{p}" for s in ("Left", "Right") for p in ("Hand", "LowerArm", "UpperArm", "Foot", "LowerLeg", "UpperLeg")}
RIG_ATTACH = {f"{s}GripAttachment" for s in ("Left", "Right")} | {"RootAttachment", "NeckAttachment", "HatAttachment", "HairAttachment", "FaceFrontAttachment", "BodyFrontAttachment", "BodyBackAttachment", "WaistFrontAttachment", "WaistBackAttachment"}
TECH_DOCS = ["docs/systems/weapons.md", "docs/combat/technique-visuals.md", "docs/vfx/toolkit/building.md"]
NOT_HOOKS = {"Body", "Effects", "TempVFX", "vfx", "Humanoid", "Animator", "HumanoidRootPart"}

HOOK_CALL = re.compile(r"\b(?:K\.point|K\.host|K\.attachment|point|groundFrame|hookPart|attachmentNamed)\(\s*(?:model\s*,\s*)?(?:cue(?:\.model)?\s*,\s*)?")
TEMPLATE_CALL = re.compile(r"\b(?:K\.play|K\.template|K\.beam|play|make|template|windupPlay)\(\s*(?=[\"`])")
STRING_ARG = re.compile(r"\"([^\"]*)\"(?:\s*\.\.\s*(\w+)\s*\.\.\s*\"([^\"]*)\")?|`([^`]*)`|(\w+)")


# ---------------------------------------------------------------- docs

def expand(token):
    """FangL_FX/FangR_FX, Ground_Tail4/9/14, TailBase<i>_FX -> names / regexes."""
    out = []
    parts = [p.strip() for p in re.split(r"\s*/\s*", token) if p.strip()]
    first = parts[0]
    for p in parts:
        if p.isdigit() and re.search(r"\d+$", first):
            p = re.sub(r"\d+$", p, first)
        elif p.isdigit():
            continue
        out.append(p)
    return out


def doc_hooks(paths):
    """(hook names, hook regexes, every word in the docs) for the rig docs."""
    names, patterns, words = set(), [], set()
    for rel in paths:
        path = os.path.join(ART, rel)
        if not os.path.exists(path):
            continue
        text = open(path).read()
        words |= set(re.findall(r"\w+", text))
        words |= {re.sub(r"<\w+>", "1", t) for t in re.findall(r"`([\w<>]+)`", text)}
        in_table = False
        para = []
        for line in text.split("\n") + [""]:
            if line.startswith("|"):
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                if re.search(r"attachment|hook", cells[0], re.I):
                    in_table = True
                elif in_table and not set(cells[0]) <= set("-: "):
                    for t in expand(cells[0].replace("`", "")):
                        add(t, names, patterns)
                continue
            in_table = False
            if line.strip() and not line.startswith("#"):
                para.append(line)
                continue
            block, para = " ".join(para), []
            if not re.search(r"attachment|hook", block, re.I):
                continue
            for t in re.findall(r"`([^`]+)`", block):
                for e in expand(t):
                    add(e, names, patterns)
            # prose lists: "Hooks (attachments): Mouth (Skull, ...), FangL_FX/FangR_FX (fang tips)"
            for t in re.findall(r"(?:[:,]\s+|\)\s*,\s*|^)([A-Z][\w<>]*(?:\s*/\s*[\w<>]+)*)\s+\(", block):
                for e in expand(t):
                    add(e, names, patterns)
    return names, patterns, words


def add(token, names, patterns):
    token = token.strip()
    if not re.fullmatch(r"[A-Za-z][\w<>]*", token):
        return
    if "<" in token:
        patterns.append(re.compile("^" + re.sub(r"<\w+>", r"\\d+", token) + "$"))
    else:
        names.add(token)


def module_docs(module):
    if module in DOC_OVERRIDE:
        return DOC_OVERRIDE[module]
    want = module.lower()
    found = []
    for family in sorted(os.listdir(ART)):
        rigs = os.path.join(ART, family, "rigs")
        if os.path.isdir(rigs):
            for f in sorted(os.listdir(rigs)):
                stem = f[:-3].replace("-", "").lower()
                if f.endswith(".md") and (stem in (want, want + "b") or want.startswith(stem)):
                    found.append(f"{family}/rigs/{f}")
    return found


# ---------------------------------------------------------------- templates

def export_names():
    """{ group: set(every instance name under it) } from assets/Effects.rbxm."""
    tmp = tempfile.mkdtemp(prefix="vfx_hooks_")
    proj, out = os.path.join(tmp, "e.project.json"), os.path.join(tmp, "e.rbxmx")
    open(proj, "w").write('{"name":"Effects","tree":{"$path":"%s"}}' % os.path.join(ROOT, "assets", "Effects.rbxm"))
    try:
        subprocess.run(["rojo", "build", proj, "-o", out], cwd=ROOT, check=True, capture_output=True)
    except (OSError, subprocess.CalledProcessError) as ex:
        print(f"(template names skipped: rojo build failed: {ex})")
        return None
    groups = collections.defaultdict(set)
    tops = collections.defaultdict(set)

    def name_of(item):
        props = item.find("Properties")
        for p in props if props is not None else []:
            if p.get("name") == "Name":
                return p.text or ""
        return ""

    def walk(item, group, depth):
        for child in item.findall("Item"):
            n = name_of(child)
            groups[group].add(n)
            if depth == 0:
                tops[group].add(n)
            walk(child, group, depth + 1)

    root = ET.parse(out).getroot().find("Item")
    for g in root.findall("Item"):
        walk(g, name_of(g), 0)
    return {"all": groups, "top": tops}


# ---------------------------------------------------------------- code

def first_arg(src, at):
    """The first argument at `at`: ("lit", name) / ("glob", regex) / ("var", name)."""
    m = STRING_ARG.match(src, at)
    if not m:
        return None
    if m.group(1) is not None:
        if m.group(2):
            return ("glob", m.group(1) + "*" + m.group(3))
        nxt = src[m.end():m.end() + 6]
        return ("glob", m.group(1) + "*") if nxt.lstrip().startswith("..") else ("lit", m.group(1))
    if m.group(4) is not None:
        return ("glob", re.sub(r"\{[^}]*\}", "*", m.group(4))) if "{" in m.group(4) else ("lit", m.group(4))
    return ("var", m.group(5))


def line_no(src, at):
    return src.count("\n", 0, at) + 1


def matches(kind, value, names, patterns):
    if kind == "lit":
        return value in names or any(p.match(value) for p in patterns)
    rx = re.compile("^" + re.escape(value).replace(r"\*", r"[A-Za-z0-9]+") + "$")
    sample = value.replace("*", "1")  # a glob against a doc pattern (TailTip<i>_FX)
    return any(rx.match(n) for n in names) or any(p.match(sample) for p in patterns)


def enemy_module(module, exported, quiet):
    src = open(os.path.join(ENEMY_FX, module + ".luau")).read()
    m = re.search(r"BeastKit\.new\(\s*\"(\w+)\"", src) or re.search(r"effects:FindFirstChild\(\"(\w+)\"\)", src)
    group = GROUP_OVERRIDE.get(module) or (m.group(1) if m else module)
    docs = module_docs(module)
    names, patterns, words = doc_hooks(docs)
    used = collections.OrderedDict()
    for call in HOOK_CALL.finditer(src):
        if src[max(0, call.start() - 9):call.start()].endswith("function "):
            continue
        arg = first_arg(src, call.end())
        if arg:
            used.setdefault(arg, []).append(line_no(src, call.start()))
    for fc in re.finditer(r"FindFirstChild\(\s*", src):
        tail = src[fc.end():fc.end() + 80]
        if re.match(r"[^)]*,\s*true\s*\)", tail):
            arg = first_arg(src, fc.end())
            if arg and arg[0] != "var":
                used.setdefault(arg, []).append(line_no(src, fc.start()))
    for s in re.finditer(r"\"(\w+_FX)\"", src):
        used.setdefault(("lit", s.group(1)), []).append(line_no(src, s.start()))
    problems, lines = 0, []
    for (kind, value), at in used.items():
        if kind == "var":
            if not quiet:
                lines.append(f"  dynamic  {value:24} lines {fmt(at)}")
            continue
        if value in NOT_HOOKS:
            continue
        ok = matches(kind, value, names, patterns)
        label = "ok" if ok else "NOT IN DOC"
        if not ok and not value.endswith("_FX") and matches(kind, value, words, []):
            ok, label = True, "part"  # a part the doc names (a tell, a segment)
        if not ok:
            problems += 1
        if not ok or not quiet:
            lines.append(f"  {label:10} {value:24} lines {fmt(at)}")
    tmissing = []
    if exported:
        have = exported["top"].get(group, set())
        for t in sorted({first_arg(src, c.end()) for c in TEMPLATE_CALL.finditer(src)} - {None}):
            if t[0] != "var" and not matches(t[0], t[1], have, []):
                tmissing.append(t[1])
        problems += len(tmissing)
    doc_txt = ", ".join(docs) if docs else ("no body" if module in NO_BODY else "NO RIG DOC FOUND")
    if not docs and module not in NO_BODY:
        problems += 1
    verdict = "ok" if problems == 0 else f"{problems} problem(s)"
    print(f"== {module} (group {group}; doc {doc_txt}): {verdict}")
    for l in lines:
        print(l)
    if tmissing:
        print(f"  TEMPLATE MISSING in Effects.{group}: {', '.join(tmissing)}")
    return problems


def tech_names():
    names = set(R6 | R15 | RIG_ATTACH)
    paths = [os.path.join(ROOT, p) for p in TECH_DOCS]
    tdir = os.path.join(ROOT, "docs", "combat", "techniques")
    paths += [os.path.join(tdir, f) for f in sorted(os.listdir(tdir)) if f.endswith(".md")]
    for p in paths:
        for t in re.findall(r"`(\w+)`", open(p).read()):
            names.add(t)
    return names


CHILD_CALL = re.compile(r"\b(?:copy|clone|template|source|p|part|land|zone|charge)\s*:\s*FindFirstChild\(\s*|TechniqueVFX\.take\(\s*[\w.]+\s*,\s*|TechniqueVFX\.part\(\s*[^,\n]+,\s*[^,\n]+,\s*")
BODY_RECEIVERS = r"(?:character|char|child|arm|hand|weapon|tool|b\.character)"


def technique_files(exported, quiet, only):
    defined = tech_names()
    problems = 0
    files = sorted(f for f in os.listdir(TECH_FX) if f.endswith(".luau"))
    extra = [os.path.join("..", "CastFX.luau"), os.path.join("..", "CombatEffects.luau")]
    for f in files + extra:
        module = os.path.basename(f)[:-5]
        if only and module not in only:
            continue
        src = open(os.path.join(TECH_FX, f)).read()
        lines, bad = [], 0
        for m in re.finditer(BODY_RECEIVERS + r":FindFirstChild\(\s*", src):
            arg = first_arg(src, m.end())
            if not arg or arg[0] == "var" or arg[1] in NOT_HOOKS:
                continue
            ok = matches(arg[0], arg[1], defined, [])
            bad += 0 if ok else 1
            if not ok or not quiet:
                lines.append(f"  {'ok' if ok else 'UNKNOWN':8} body {arg[1]:24} line {line_no(src, m.start())}")
        group = module if exported and module in exported["all"] else None
        if group:
            have = exported["all"][group]
            seen = set()
            for m in CHILD_CALL.finditer(src):
                arg = first_arg(src, m.end())
                if not arg or arg[0] == "var" or arg in seen:
                    continue
                seen.add(arg)
                ok = matches(arg[0], arg[1], have, [])
                label = "ok" if ok else "MISSING"
                # `local x = take(copy, "Name")` followed by `if x then`: optional
                lm = re.match(r"[^\n]*?local (\w+)\s*=\s*$", src[src.rfind("\n", 0, m.start()) + 1:m.start()])
                after = src[m.end():m.end() + 160]
                if not ok and lm and re.search(r"\n\s*if (?:not )?" + lm.group(1) + r"\b", after):
                    ok, label = True, "absent"  # the code checks for it
                bad += 0 if ok else 1
                if label != "ok" or not quiet:
                    lines.append(f"  {label:8} template child {arg[1]:16} line {line_no(src, m.start())}")
        problems += bad
        if lines or not quiet:
            print(f"== TechniqueFX.{module}{' (templates Effects.' + group + ')' if group else ''}: {'ok' if not bad else str(bad) + ' problem(s)'}")
            for l in lines:
                print(l)
    return problems


def fmt(lines):
    s = ",".join(str(l) for l in lines[:6])
    return s + ("..." if len(lines) > 6 else "")


def main():
    args = sys.argv[1:]
    quiet = "--quiet" in args
    exported = None if "--no-templates" in args else export_names()
    only = [a for a in args if not a.startswith("--")]
    problems = 0
    for f in sorted(os.listdir(ENEMY_FX)):
        module = f[:-5]
        if not f.endswith(".luau") or module in SKIP or (only and module not in only):
            continue
        problems += enemy_module(module, exported, quiet)
    problems += technique_files(exported, quiet, only)
    print(f"verdict: {problems} undefined hook or template name(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
