--!nocheck
-- Shared part helpers for the roster beasts (venom serpent, jade python, flame raven,
-- thunder ape), in the style of spirit_wolf_b/build_spirit_wolf_b.luau. Each build
-- script loads this over the local art server and calls it with the model's name:
--   local B = loadstring(HttpService:GetAsync(BASE .. "lib.luau"))()("VenomSerpent")
--
-- Model space: ground Y=0, the beast faces -Z, its left side is -X. Each segment's
-- primary part carries the segment name; detail parts carry a `Segment` attribute.
-- B.joint(name, parentSegment, segment, pivot) records a Motor6D for the rig; finish()
-- writes it onto the segment part as attributes (Joint, JointParent, JointPivot), which
-- rig_core.luau reads, so the pivots live next to the geometry they bend.
-- Tell parts (Neon, flare on windup) get a `Tell` attribute.

return function(modelName: string)
	local B = {}
	local model = Instance.new("Model")
	model.Name = modelName
	B.model = model
	local joints = {}

	local function v(x, y, z)
		return Vector3.new(x, y, z)
	end
	B.v = v

	function B.add(seg, name, class, size, cf, color)
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
	local add = B.add

	function B.block(seg, name, size, pos, color, rot)
		return add(seg, name, "Part", size, CFrame.new(pos) * (rot or CFrame.identity), color)
	end

	function B.ball(seg, name, d, pos, color)
		local p = add(seg, name, "Part", v(d, d, d), CFrame.new(pos), color)
		p.Shape = Enum.PartType.Ball
		return p
	end

	-- A frame at the middle of a..b, Z along the bone, Y toward `up` (default world up).
	function B.bone(a, b, up)
		local dir = (b - a).Unit
		up = up or (if math.abs(dir.Y) > 0.7 then v(0, 0, -1) else Vector3.yAxis)
		return CFrame.lookAt((a + b) / 2, b, up)
	end

	-- A block from a to b (Z along the bone), w wide and d deep, padded past both ends.
	function B.limb(seg, name, a, b, w, d, color, pad, up)
		return add(seg, name, "Part", v(w, d, (b - a).Magnitude + (pad or 0)), B.bone(a, b, up), color)
	end

	-- A part placed in a frame's local space.
	function B.on(frame, seg, name, class, size, offset, color)
		return add(seg, name, class, size, frame * offset, color)
	end

	-- A wedge fin rising h from base: vertical face at the back, slope at the front, so the
	-- tip sweeps back. pitch leans it back (+) or flips it down (~pi); roll + tilts it to -X.
	-- frame (optional) puts base in that frame's local space.
	function B.fin(seg, name, base, h, depth, thick, color, pitch, roll, frame)
		local cf = (frame or CFrame.identity) * CFrame.new(base) * CFrame.Angles(pitch or 0, 0, roll or 0)
			* CFrame.new(0, h / 2, 0)
		return add(seg, name, "WedgePart", v(thick, h, depth), cf, color)
	end

	-- An isosceles triangle (two wedges back to back) facing forward, h tall and w wide.
	function B.tri(seg, name, base, h, w, thick, color, tilt)
		local frame = CFrame.new(base) * (tilt or CFrame.identity)
		local a = add(seg, name, "WedgePart", v(thick, h, w / 2),
			frame * CFrame.new(-w / 4, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
		add(seg, name .. "B", "WedgePart", v(thick, h, w / 2),
			frame * CFrame.new(w / 4, h / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0), color)
		return a
	end

	-- A sloped shoulder along a frame's Z: vertical face toward the midline, slope out to
	-- side s, w wide, h tall and len long, centred at pos in that frame.
	function B.bevel(seg, name, pos, w, h, len, s, color, frame)
		return add(seg, name, "WedgePart", v(len, h, w),
			(frame or CFrame.identity) * CFrame.new(pos) * CFrame.Angles(0, -s * math.pi / 2, 0), color)
	end

	-- A rounded-back tube segment from a to b: a core block, a narrower top block and two
	-- bevels, and a belly plate on the local -Y side. Returns the core part and its frame.
	-- up picks which way the back faces (default world up); belly goes opposite it.
	-- bellyW is the belly plate's share of the width (default full, a thin line at the
	-- ground); a narrower one stands proud of the core as a ventral stripe.
	function B.tube(seg, a, b, w, h, back, belly, pad, up, backHi, bellyW)
		local frame = B.bone(a, b, up)
		local len = (b - a).Magnitude + (pad or 0)
		local coreH, topH = h * 0.7, h * 0.3
		local core = add(seg, seg, "Part", v(w, coreH, len), frame * CFrame.new(0, -h / 2 + coreH / 2, 0), back)
		local top = backHi or back
		add(seg, seg .. "Top", "Part", v(w * 0.5, topH, len), frame * CFrame.new(0, h / 2 - topH / 2, 0), top)
		for _, s in { -1, 1 } do
			B.bevel(seg, seg .. "Bevel" .. s, v(s * w * 0.375, h / 2 - topH / 2, 0), w * 0.25, topH, len, s, back, frame)
		end
		if bellyW then
			add(seg, seg .. "Belly", "Part", v(w * bellyW, h * 0.2, len * 0.96),
				frame * CFrame.new(0, -h / 2 + h * 0.06, 0), belly)
		else
			add(seg, seg .. "Belly", "Part", v(w + 0.06, h * 0.16, len * 0.96),
				frame * CFrame.new(0, -h / 2 + h * 0.07, 0), belly)
		end
		return core, frame
	end

	function B.tell(p)
		p.Material = Enum.Material.Neon
		p:SetAttribute("Tell", true)
		return p
	end

	function B.joint(name, parentSeg, seg, pivot)
		table.insert(joints, { name, parentSeg, seg, pivot })
	end

	-- Writes the joints onto their segment parts and replaces ServerStorage._RosterBeasts.<name>.
	function B.finish()
		local ServerStorage = game:GetService("ServerStorage")
		local ChangeHistoryService = game:GetService("ChangeHistoryService")
		for _, j in joints do
			local part
			for _, c in model:GetChildren() do
				if c.Name == j[3] and c:IsA("BasePart") and not c:GetAttribute("Segment") then
					assert(not part, modelName .. ": two segment parts named " .. j[3])
					part = c
				end
			end
			assert(part, modelName .. ": no segment part " .. j[3])
			part:SetAttribute("Joint", j[1])
			part:SetAttribute("JointParent", j[2])
			part:SetAttribute("JointPivot", j[4])
		end
		local recording = ChangeHistoryService:TryBeginRecording("Build " .. modelName)
		local staging = ServerStorage:FindFirstChild("_RosterBeasts")
		if not staging then
			staging = Instance.new("Folder")
			staging.Name = "_RosterBeasts"
			staging.Parent = ServerStorage
		end
		local old = staging:FindFirstChild(modelName)
		if old then
			old:Destroy()
		end
		model.Parent = staging
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		return ("%s body: %d parts, %d joints"):format(modelName, #model:GetChildren(), #joints)
	end

	return B
end
