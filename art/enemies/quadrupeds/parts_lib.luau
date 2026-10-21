--!nocheck
-- Part helpers shared by the quadruped roster build scripts (stone boar, stone-shell
-- tortoise, nine-tail fox), in the style of spirit_wolf_b/build_spirit_wolf_b.luau.
-- Loaded over the local art server:
--   local P = loadstring(HttpService:GetAsync(BASE .. "quadrupeds/parts_lib.luau"))()("StoneBoar_R")
-- Model space: ground Y=0, the beast faces -Z, its left side is -X. A segment's primary
-- part carries the segment name; every other part gets a `Segment` attribute naming the
-- segment it welds to (rig_lib.luau reads it). Tell parts (Neon, flare on windup) also
-- get `Tell = true`, so the animator or vfx can find them without a name list.

return function(modelName)
	local ServerStorage = game:GetService("ServerStorage")
	local ChangeHistoryService = game:GetService("ChangeHistoryService")

	local P = {}
	local model = Instance.new("Model")
	model.Name = modelName
	P.model = model

	function P.v(x, y, z)
		return Vector3.new(x, y, z)
	end
	local v = P.v

	function P.add(seg, name, class, size, cf, color)
		local p = Instance.new(class)
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if name ~= seg then
			p:SetAttribute("Segment", seg)
		end
		p.Parent = model
		return p
	end
	local add = P.add

	function P.block(seg, name, size, pos, color, rot)
		return add(seg, name, "Part", size, CFrame.new(pos) * (rot or CFrame.identity), color)
	end

	function P.ball(seg, name, d, pos, color)
		local p = add(seg, name, "Part", Vector3.new(d, d, d), CFrame.new(pos), color)
		p.Shape = Enum.PartType.Ball
		return p
	end

	-- A cylinder from a to b, d across.
	function P.cyl(seg, name, a, b, d, color)
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		local p = add(seg, name, "Part", Vector3.new((b - a).Magnitude, d, d), cf, color)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- A block from a to b (Z along the bone), w wide and d deep, padded past both ends.
	-- roll turns it about the bone.
	function P.limb(seg, name, a, b, w, d, color, pad, roll)
		local dir = (b - a).Unit
		local up = if math.abs(dir.Y) > 0.7 then Vector3.new(0, 0, -1) else Vector3.yAxis
		local cf = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, 0, roll or 0)
		return add(seg, name, "Part", Vector3.new(w, d, (b - a).Magnitude + (pad or 0)), cf, color)
	end

	-- A wedge fin rising h from base: vertical face at the back, slope at the front, so the
	-- tip sweeps back. pitch leans it back (+) or flips it down (~pi); roll + tilts it to -X;
	-- yaw turns it about Y first.
	function P.fin(seg, name, base, h, depth, thick, color, pitch, roll, yaw)
		local cf = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0) * CFrame.Angles(pitch or 0, 0, roll or 0)
			* CFrame.new(0, h / 2, 0)
		return add(seg, name, "WedgePart", Vector3.new(thick, h, depth), cf, color)
	end

	-- A horn or spike from base toward tip: a wedge pair tapering to a ridge, w wide.
	function P.spike(seg, name, base, tip, w, color)
		local len = (tip - base).Magnitude
		local cf = CFrame.lookAt(base, tip) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, len / 2, 0)
		local a = add(seg, name, "WedgePart", Vector3.new(w, len, w / 2), cf * CFrame.new(0, 0, -w / 4), color)
		add(seg, name .. "B", "WedgePart", Vector3.new(w, len, w / 2),
			cf * CFrame.new(0, 0, w / 4) * CFrame.Angles(0, math.pi, 0), color)
		return a
	end

	-- An isosceles triangle (two wedges back to back) facing forward, h tall and w wide.
	function P.tri(seg, name, base, h, w, thick, color, tilt)
		local frame = CFrame.new(base) * (tilt or CFrame.identity)
		local a = add(seg, name, "WedgePart", Vector3.new(thick, h, w / 2),
			frame * CFrame.new(-w / 4, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
		add(seg, name .. "B", "WedgePart", Vector3.new(thick, h, w / 2),
			frame * CFrame.new(w / 4, h / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), color)
		return a
	end

	-- A sloped shoulder along Z: vertical face toward the midline, slope out to side s.
	function P.bevel(seg, name, pos, w, h, len, s, color)
		return add(seg, name, "WedgePart", v(len, h, w), CFrame.new(pos) * CFrame.Angles(0, -s * math.pi / 2, 0), color)
	end

	-- A sloped edge along X at the front (s = -1) or back (s = 1) of a box.
	function P.bevelZ(seg, name, pos, w, h, len, s, color)
		return add(seg, name, "WedgePart", v(w, h, len), CFrame.new(pos) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0), color)
	end

	-- Marks a part as a glowing tell: Neon, plus the Tell attribute.
	function P.tell(p)
		p.Material = Enum.Material.Neon
		p:SetAttribute("Tell", true)
		return p
	end

	-- Replaces <folder>.<modelName> in ServerStorage with the built model.
	function P.place(folderName)
		local recording = ChangeHistoryService:TryBeginRecording("Build " .. modelName)
		local folder = ServerStorage:FindFirstChild(folderName)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = folderName
			folder.Parent = ServerStorage
		end
		local old = folder:FindFirstChild(modelName)
		if old then
			old:Destroy()
		end
		model.Parent = folder
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		return ("%s body: %d parts"):format(modelName, #model:GetChildren())
	end

	return P
end
