--!nocheck
-- Reads an animation's length and markers (animation events) in Studio, for
-- syncing effects to them. Run this file once through the Studio MCP's
-- execute_luau: it installs _G.animMarkers(animation) where `animation` is an
-- Animation instance, its path ("ReplicatedStorage.Animations.Fists.1") or an
-- "rbxassetid://..." id. Returns { id, kind, length, markers = { { name, time, value } } }
-- sorted by time. KeyframeSequenceProvider returns empty sequences for these
-- assets, so it loads the asset itself with game:GetObjects. Handles both
-- KeyframeSequence markers and CurveAnimation MarkerCurves.

local function resolve(animation)
	if typeof(animation) == "Instance" then
		return animation.AnimationId
	end
	if animation:match("^rbxassetid://") or animation:match("^%d+$") then
		return if animation:match("^%d+$") then "rbxassetid://" .. animation else animation
	end
	local node = game
	for part in string.gmatch(animation, "[^%.]+") do
		node = node:FindFirstChild(part) or game:GetService(part)
	end
	return node.AnimationId
end

_G.animMarkers = function(animation)
	local id = resolve(animation)
	assert(id ~= "", "animation has no AnimationId")
	local asset = game:GetObjects(id)[1]
	assert(asset, "couldn't load " .. id)
	local markers, length = {}, 0
	for _, d in asset:GetDescendants() do
		if d:IsA("Keyframe") then
			length = math.max(length, d.Time)
			-- markers live as KeyframeMarker children; GetMarkers() returns
			-- nothing for assets loaded with GetObjects, so read the instances
			for _, m in d:GetChildren() do
				if m:IsA("KeyframeMarker") then
					table.insert(markers, { name = m.Name, time = d.Time, value = m.Value })
				end
			end
		elseif d:IsA("MarkerCurve") then
			for _, m in d:GetMarkers() do
				table.insert(markers, { name = d.Name, time = m.Time, value = m.Value })
				length = math.max(length, m.Time)
			end
		end
	end
	if asset:IsA("CurveAnimation") then
		for _, d in asset:GetDescendants() do
			if d:IsA("FloatCurve") then
				for _, k in d:GetKeys() do
					length = math.max(length, k.Time)
				end
			end
		end
	end
	table.sort(markers, function(a, b)
		return a.time < b.time
	end)
	asset:Destroy()
	return { id = id, kind = asset.ClassName, length = length, markers = markers }
end
return "animMarkers installed"
