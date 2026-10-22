--!nocheck
-- Skeleton-only forward kinematics for the Thunder Ape, from the joint pivots in
-- build_thunder_ape.luau (unit space, scale 1). It needs no rig, so poses can be
-- authored and checked before (and without) the real body: ape_fk.luau returns
-- fk(pose) -> { [pointName] = Vector3 } in model space.
-- Points ride a segment; the key ones are the knuckle line of each fist, the wrist,
-- the ChestBeat spots, the head and the lowest sole corners.
local V = Vector3.new
local P = {
	JointRoot = V(0, 3.1, 1.3), JointSpine = V(0, 3.7, 0.6), JointHead = V(0, 5.6, -1.6), JointJaw = V(0, 4.9, -2.4),
}
local PARENT = { JointRoot = false, JointSpine = "JointRoot", JointHead = "JointSpine", JointJaw = "JointHead" }
for _, s in { -1, 1 } do
	local f, b = if s < 0 then "FL" else "FR", if s < 0 then "BL" else "BR"
	P["JointLeg" .. f], P["JointElbow" .. f], P["JointWrist" .. f] = V(s * 2.0, 5.6, -0.8), V(s * 2.45, 3.4, -1.3), V(s * 2.55, 1.25, -1.7)
	P["JointFingers" .. f] = V(s * 2.6, 0.75, -2.3)
	PARENT["JointLeg" .. f], PARENT["JointElbow" .. f], PARENT["JointWrist" .. f], PARENT["JointFingers" .. f] = "JointSpine", "JointLeg" .. f, "JointElbow" .. f, "JointWrist" .. f
	P["JointLeg" .. b], P["JointKnee" .. b], P["JointAnkle" .. b] = V(s * 1.1, 2.9, 1.7), V(s * 1.4, 1.6, 0.9), V(s * 1.4, 0.55, 1.7)
	PARENT["JointLeg" .. b], PARENT["JointKnee" .. b], PARENT["JointAnkle" .. b] = "JointRoot", "JointLeg" .. b, "JointKnee" .. b
end
-- optional new joints (pivots are guesses until RIGS.md lists them)
local PTS = {
	-- name = { joint, rest position }
	BeatL = { "JointSpine", V(-0.7, 5.15, -1.95) }, BeatR = { "JointSpine", V(0.7, 5.15, -1.95) },
	Hump = { "JointSpine", V(0, 6.9, -0.9) }, Belly = { "JointSpine", V(0, 4.0, -1.0) },
	Skull = { "JointHead", V(0, 5.45, -2.25) }, HeadTop = { "JointHead", V(0, 6.2, -2.2) },
	Mouth = { "JointJaw", V(0, 4.95, -3.0) }, Chin = { "JointJaw", V(0, 4.7, -2.9) },
}
for _, s in { -1, 1 } do
	local f, b, n = if s < 0 then "FL" else "FR", if s < 0 then "BL" else "BR", if s < 0 then "L" else "R"
	PTS["Elbow" .. n] = { "JointElbow" .. f, V(s * 2.45, 3.4, -1.3) }
	PTS["Wrist" .. n] = { "JointWrist" .. f, V(s * 2.55, 1.25, -1.7) }
	PTS["Fist" .. n] = { "JointWrist" .. f, V(s * 2.6, 0.0, -2.0) } -- under the fist, ground contact
	PTS["Knuckle" .. n] = { "JointFingers" .. f, V(s * 2.6, 0.0, -2.7) }
	PTS["FistTop" .. n] = { "JointWrist" .. f, V(s * 2.6, 1.1, -1.8) }
	PTS["Shoulder" .. n] = { "JointLeg" .. f, V(s * 2.0, 5.6, -0.8) }
	PTS["Heel" .. n] = { "JointAnkle" .. b, V(s * 1.4, 0.0, 2.2) }
	PTS["Toe" .. n] = { "JointAnkle" .. b, V(s * 1.4, 0.0, 0.3) }
	PTS["Knee" .. n] = { "JointKnee" .. b, V(s * 1.4, 1.6, 0.9) }
	PTS["Hip" .. n] = { "JointLeg" .. b, V(s * 1.1, 2.9, 1.7) }
end
local ORDER = {}
do
	local seen = {}
	local function add(j)
		if seen[j] then return end
		if PARENT[j] then add(PARENT[j]) end
		seen[j] = true
		table.insert(ORDER, j)
	end
	for j in P do add(j) end
end
local function fk(pose)
	local F = {}
	for _, j in ORDER do
		local par = PARENT[j]
		local base = if par then F[par] * CFrame.new(P[j] - P[par]) else CFrame.new(0, 0, 0) * CFrame.new(P[j])
		F[j] = base * (pose[j] or CFrame.identity)
	end
	local out = {}
	for name, pt in PTS do
		out[name] = F[pt[1]]:PointToWorldSpace(pt[2] - P[pt[1]])
	end
	out._F = F
	return out
end
return { fk = fk, P = P, PARENT = PARENT, PTS = PTS }
