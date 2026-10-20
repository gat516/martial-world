# Loopback-only receiver for exporting Studio instances: run it, then in Studio
#   game:GetService("HttpService"):PostAsync("http://127.0.0.1:8766/Hud", _G.exportRbxmx("StarterGui.Hud"))
# (after loading tools/export_rbxmx.luau). The XML lands in frag/<name>.xml beside
# this script; wrap it in <roblox version="4">...</roblox> to make an .rbxmx.
import http.server, os, re
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frag")
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        name = re.sub(r"[^A-Za-z0-9_]", "", self.path.strip("/")) or "out"
        body = self.rfile.read(int(self.headers["Content-Length"]))
        with open(os.path.join(OUT, name + ".xml"), "wb") as f:
            f.write(body)
        self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
http.server.HTTPServer(("127.0.0.1", 8766), H).serve_forever()
