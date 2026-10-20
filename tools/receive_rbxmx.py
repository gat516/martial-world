# Loopback-only receiver for exporting Studio instances: run it, then in Studio
#   game:GetService("HttpService"):PostAsync("http://127.0.0.1:8766/Hud", _G.exportRbxmx("StarterGui.Hud"))
# (after loading tools/export_rbxmx.luau). The XML lands in frag/<name>.xml beside
# this script; wrap it in <roblox version="4">...</roblox> to make an .rbxmx.
# A path ending in .rbxm (from tools/export_rbxm.luau) carries base64 and lands
# decoded as frag/<name>.rbxm, ready to copy to assets/.
import base64, http.server, os, re
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frag")
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
http.server.HTTPServer(("127.0.0.1", 8766), H).serve_forever()
