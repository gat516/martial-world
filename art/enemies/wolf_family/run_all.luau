--!nocheck
-- Rebuilds, rigs, previews and checks the whole wolf family in one call. Run in Edit
-- mode through execute_luau:
-- loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/wolf_family/run_all.luau?" .. os.clock()))()
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"
local MODELS = {
	{ "build_elder_wolf_king.luau", "ElderWolfKing" },
	{ "build_shadow_mane_wolf.luau", "ShadowManeWolf" },
}
local H = game:GetService("HttpService")
local function src(p)
	return H:GetAsync(BASE .. p .. "?" .. os.clock())
end
local out = {}
local targets = {}
for _, m in MODELS do
	table.insert(out, loadstring(src("wolf_family/" .. m[1]))())
	_G.WOLF_TARGET = m[2]
	table.insert(out, loadstring(src("wolf_family/rig_wolf_family.luau"))())
	table.insert(targets, ('"ServerStorage._RosterWolves.%s"'):format(m[2]))
end
_G.WOLF_TARGET = nil
table.insert(out, loadstring(src("wolf_family/preview_wolf_family.luau"))())
local check = src("check_rig.luau"):gsub("local TARGETS = {}", "local TARGETS = { " .. table.concat(targets, ", ") .. " }", 1)
table.insert(out, tostring(loadstring(check)()))
return table.concat(out, "\n")
