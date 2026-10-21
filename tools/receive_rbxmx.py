# Loopback-only receiver for exporting Studio instances: run it, then in Studio
#   game:GetService("HttpService"):PostAsync("http://127.0.0.1:8766/Hud", _G.exportRbxmx("StarterGui.Hud"))
# (after loading tools/export_rbxmx.luau). The XML lands in frag/<name>.xml beside
# this script; wrap it in <roblox version="4">...</roblox> to make an .rbxmx.
# A path ending in .rbxm (from tools/export_rbxm.luau) carries base64 and lands
# decoded as frag/<name>.rbxm, ready to copy to assets/.
# GET /<file>.luau serves a .luau file from tools/ (or tools/vfx_specs/), so
# Studio can load the VFX session helpers without pasting them:
#   local m = Instance.new("ModuleScript")
#   m.Source = game:GetService("HttpService"):GetAsync("http://127.0.0.1:8766/vfx_session.luau")
#   return require(m)
import base64, http.server, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "frag")
os.makedirs(OUT, exist_ok=True)
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        path = self.path.strip("/")
        binary = path.endswith(".rbxm")
        name = re.sub(r"[^A-Za-z0-9_]", "", path[:-5] if binary else path) or "out"
        body = self.rfile.read(int(self.headers["Content-Length"]))
        with open(os.path.join(OUT, name + (".rbxm" if binary else ".xml")), "wb") as f:
            f.write(base64.b64decode(body) if binary else body)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def do_GET(self):
        rel = self.path.strip("/")
        # only plain .luau files directly in tools/ or tools/vfx_specs/
        if not re.fullmatch(r"(vfx_specs/)?[A-Za-z0-9_]+\.luau", rel) or not os.path.isfile(os.path.join(HERE, rel)):
            self.send_response(404); self.end_headers(); return
        with open(os.path.join(HERE, rel), "rb") as f:
            body = f.read()
        self.send_response(200); self.send_header("Content-Type", "text/plain"); self.end_headers(); self.wfile.write(body)
http.server.HTTPServer(("127.0.0.1", 8766), H).serve_forever()
