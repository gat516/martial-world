--!nocheck
-- Rig and body check for enemy templates. Run in Edit mode through execute_luau
-- (served over http://127.0.0.1:8767/check_rig.luau), with TARGETS set to the
-- templates to check, e.g. { "ServerStorage._RosterWolves.ElderWolfKing" }.
-- It returns a report per template and flags:
--   floating   a visible part that touches no other visible part (oriented-box test,
--              with TOLERANCE of slack), so it hangs in the air
--   unjointed  a part with no weld or motor path back to the HumanoidRootPart, which
--              falls off or stays behind when the rig moves
--   rig        no HRP, HRP not the PrimaryPart, a rotated HRP, or a missing Humanoid
-- A clean template reports "clean". Works on beasts and R6 humanoids alike.

local TARGETS = {}
local TOLERANCE = 0.05 -- studs of slack in the touch test

local function resolve(path)
	local node = game
	for name in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(name) or game:GetService(name)
	end
	return node
end

-- Oriented-box overlap by the separating axis theorem.
local function overlaps(a, b)
	local ca, cb = a.CFrame, b.CFrame
	local ea, eb = a.Size / 2 + Vector3.one * TOLERANCE, b.Size / 2
	local axA = { ca.RightVector, ca.UpVector, ca.LookVector }
	local axB = { cb.RightVector, cb.UpVector, cb.LookVector }
	local d = cb.Position - ca.Position
	local axes = {}
	for i = 1, 3 do
		table.insert(axes, axA[i])
		table.insert(axes, axB[i])
		for j = 1, 3 do
			local c = axA[i]:Cross(axB[j])
			if c.Magnitude > 1e-4 then
				table.insert(axes, c.Unit)
			end
		end
	end
	for _, n in axes do
		local ra = math.abs(axA[1]:Dot(n)) * ea.X + math.abs(axA[2]:Dot(n)) * ea.Y + math.abs(axA[3]:Dot(n)) * ea.Z
		local rb = math.abs(axB[1]:Dot(n)) * eb.X + math.abs(axB[2]:Dot(n)) * eb.Y + math.abs(axB[3]:Dot(n)) * eb.Z
		if math.abs(d:Dot(n)) > ra + rb then
			return false
		end
	end
	return true
end

local function check(model)
	local problems = {}
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then
		table.insert(problems, "rig: no HumanoidRootPart")
	else
		if model.PrimaryPart ~= hrp then
			table.insert(problems, "rig: PrimaryPart is not the HRP")
		end
		if hrp.CFrame.Rotation ~= CFrame.identity and (hrp.CFrame.LookVector - Vector3.new(0, 0, -1)).Magnitude > 1e-3 then
			table.insert(problems, "rig: HRP is rotated (the beast would spawn turned or on its side)")
		end
	end
	if not model:FindFirstChildOfClass("Humanoid") then
		table.insert(problems, "rig: no Humanoid")
	end

	local parts, links = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			links[d] = links[d] or {}
		elseif (d:IsA("JointInstance") or d:IsA("WeldConstraint")) and d.Part0 and d.Part1 then
			links[d.Part0] = links[d.Part0] or {}
			links[d.Part1] = links[d.Part1] or {}
			table.insert(links[d.Part0], d.Part1)
			table.insert(links[d.Part1], d.Part0)
		end
	end

	if hrp then
		local seen, queue = { [hrp] = true }, { hrp }
		while #queue > 0 do
			local p = table.remove(queue)
			for _, q in links[p] or {} do
				if not seen[q] then
					seen[q] = true
					table.insert(queue, q)
				end
			end
		end
		for _, p in parts do
			if not seen[p] then
				table.insert(problems, "unjointed: " .. p:GetFullName())
			end
		end
	end

	local visible = {}
	for _, p in parts do
		if p ~= hrp and p.Transparency < 1 then
			table.insert(visible, p)
		end
	end
	for _, p in visible do
		local touching = false
		for _, q in visible do
			if q ~= p and overlaps(p, q) then
				touching = true
				break
			end
		end
		if not touching then
			table.insert(problems, "floating: " .. p:GetFullName())
		end
	end

	if #problems == 0 then
		return model.Name .. ": clean (" .. #parts .. " parts)"
	end
	return model.Name .. ": " .. #problems .. " problem(s)\n  " .. table.concat(problems, "\n  ")
end

local out = {}
for _, path in TARGETS do
	local node = resolve(path)
	if not node then
		table.insert(out, path .. ": not found")
	elseif node:IsA("Model") then
		table.insert(out, check(node))
	else
		for _, m in node:GetChildren() do
			if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then
				table.insert(out, check(m))
			end
		end
	end
end
return table.concat(out, "\n")
