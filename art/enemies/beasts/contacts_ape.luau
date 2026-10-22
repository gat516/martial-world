--!nocheck
-- Contact report for the Thunder Ape poses (sandbox, after pushing src modules): where the
-- fists land against each attack's area, the chest beats against ChestBeat*_FX, the cone
-- sweep through contact, and the length of the BodySlam lie. Studs, model space (root at
-- the origin, -Z forward), ground Y 0. Run through execute_luau:
--   _G.APE_PROBE = true; local check, M, contacts, solve = loadstring(HttpGet(".../qa_thunder_ape_poses.luau"))(); _G.APE_PROBE = nil
--   _G.PROBE = { check, M, contacts, solve }; return loadstring(HttpGet(".../contacts_ape.luau"))()
local check, M, contacts, solve = table.unpack(_G.PROBE)
local SCALE = 3.71
local function at(move, phase, u, input)
	return contacts(M.scaled(M.sample(move, phase, u, input or {}), SCALE))
end
local function xz(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function ang(v) return math.deg(math.atan2(v.X, -v.Z)) end
local out = {}
local function add(s) table.insert(out, s) end
-- chest beats
for move, beats in M.BEATS do
	local dur = M.durations[move].windup
	for i, t in beats do
		local c = at(move, "windup", t / dur, { duration = dur })
		local kind = if move == "Challenge" and i == 3 then "both" elseif i % 2 == 1 then "L" else "R"
		add(("%s beat %d t=%.2f (%s): fistL-to-hookL %.1f studs, fistR-to-hookR %.1f studs"):format(move, i, t, kind, c.dL, c.dR))
	end
end
-- the cone swings: fist (hand centre) bearing and distance at contact, through the sweep
for _, v in { "A", "B", "C" } do
	M.setVariant("ClubSwing", v)
	local line = {}
	for _, s in { { "windup", 0.5 }, { "windup", 0.8 }, { "windup", 1 }, { "active", 0.5 }, { "active", 1 } } do
		local c = at("ClubSwing", s[1], s[2])
		local p = c.fistR
		table.insert(line, ("%s%.1f: bearing %+.0f deg dist %.1f y %.1f"):format(s[1]:sub(1, 1), s[2], ang(p), math.sqrt(p.X ^ 2 + p.Z ^ 2), p.Y))
	end
	add("ClubSwing " .. v .. " right fist: " .. table.concat(line, " | "))
end
M.setVariant("ClubSwing", "A")
do
	local line = {}
	for _, s in { { "windup", 0.5 }, { "windup", 1 }, { "active", 0.5 }, { "active", 1 } } do
		local c = at("Backhand", s[1], s[2])
		local p = c.fistL
		table.insert(line, ("%s%.1f: bearing %+.0f dist %.1f y %.1f"):format(s[1]:sub(1, 1), s[2], ang(p), math.sqrt(p.X ^ 2 + p.Z ^ 2), p.Y))
	end
	add("Backhand left fist: " .. table.concat(line, " | "))
end
-- slams: fists planted at contact
for _, spec in { { "ThunderPound", "windup", 1, 18 }, { "SkyfallSlam", "active", 1, 0 }, { "Judgment", "active", 1, 0 } } do
	local c = at(spec[1], spec[2], spec[3], { duration = M.durations[spec[1]][spec[2]] })
	add(("%s %s u=%.0f: FistL_FX %s FistR_FX %s  (centre of fists %.1f studs from the area centre z -%d)"):format(spec[1], spec[2], spec[3], xz(c.fistFXL), xz(c.fistFXR), ((c.fistFXL + c.fistFXR) / 2 - Vector3.new(0, 0, -spec[4])).Magnitude, spec[4]))
end
-- BodySlam lie: furthest forward body point at the end of the dash
do
	local pose = M.scaled(M.sample("BodySlam", "active", 1, { duration = 0.62 }), SCALE)
	local boxes = solve(pose)
	local zmin, zmax, xmin, xmax = math.huge, -math.huge, math.huge, -math.huge
	for _, list in boxes do
		for _, b in list do
			local e = b.size / 2
			local ex = math.abs(b.cf.RightVector.X) * e.X + math.abs(b.cf.UpVector.X) * e.Y + math.abs(b.cf.LookVector.X) * e.Z
			local ez = math.abs(b.cf.RightVector.Z) * e.X + math.abs(b.cf.UpVector.Z) * e.Y + math.abs(b.cf.LookVector.Z) * e.Z
			zmin, zmax = math.min(zmin, b.cf.Z - ez), math.max(zmax, b.cf.Z + ez)
			xmin, xmax = math.min(xmin, b.cf.X - ex), math.max(xmax, b.cf.X + ex)
		end
	end
	add(("BodySlam lie: z from %.1f (fists) to %.1f (feet) = %.1f long, x %.1f..%.1f = %.1f wide (box 20 x 34)"):format(zmin, zmax, zmax - zmin, xmin, xmax, xmax - xmin))
end
-- boulder release and the lance
do
	local c = at("BoulderHurl", "windup", 0.6, { duration = 1.0 })
	add(("BoulderHurl release (0.60 s): right fist %s, left fist %s"):format(xz(c.fistR), xz(c.fistL)))
	for _, u in { 0.9, 1 } do
		local c2 = at("ThunderLance", "windup", u, { duration = 1.0 })
		add(("ThunderLance windup u=%.2f: right fist %s (bearing %+.0f)"):format(u, xz(c2.fistR), ang(c2.fistR)))
	end
end
return table.concat(out, "\n")
