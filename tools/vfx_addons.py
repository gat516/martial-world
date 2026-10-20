# Unpacks the vfxia add-ons installed in the user's plugin (stored as base64
# .rbxm under "vfxerAddons" in Studio's plugin settings) into readable .rbxmx
# under tools/frag/addons/ (gitignored), so their game modules can be read for
# tags and attributes. Usage: python3 tools/vfx_addons.py [settings.json]
import base64, glob, json, os, subprocess, sys, tempfile

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
