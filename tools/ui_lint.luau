--!nocheck
-- UI layout dump for tools/ui_lint.py (Edit mode, any Studio that has the GUIs).
-- Lays every ScreenGui in StarterGui (and ReplicatedStorage, e.g. the character
-- creator) out at each lint size inside a fixed-size frame (so Scale units resolve
-- against that size, not the Studio viewport), applies UiScale's fit the way the
-- client does, shows the Phone/Desktop subtree that size would get, then records
-- every visible GuiObject's rectangle, its nearest clipping ancestor, image, slice
-- and text facts, and posts one JSON document per size to the receiver on 8766
-- (tools/ensure_receiver.sh), as tools/frag/uilint_<W>x<H>_<gui>.xml (one per gui: Studio caps a
-- post at 1 MB). Everything it
-- creates lives in StarterGui._UiLint and is destroyed at the end, so it's safe in
-- a Rojo-connected place.
--
-- Scenes: most of the UI is hidden until opened (windows, cards, templates, state
-- overlays). Besides the screen as authored ("base"), every hidden GuiObject whose
-- ancestors are shown is opened on its own ("scene"): it and the hidden things
-- inside it are shown, except children of a UIListLayout/UIGridLayout parent
-- (mutually exclusive rows: each of those opens as a scene of its own, nested up
-- to three deep). A scene records only what it opened (or, when that sits in a
-- layout, the layout's parent, since it reflows). Templates are linted this way.
--
-- Use:
--   _G.UILINT = { sizes = { {1920,1080}, {1366,768}, {844,390}, {667,375} },  -- default
--                 guis = { "Hud", "Inventory" },  -- optional: only these ScreenGuis
--                 scenes = false,                 -- only the screens as authored
--                 keep = false }                  -- true leaves _UiLint for a look
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:<port>/ui_lint.luau"))()
--   (or paste this file into execute_luau)
--
-- Limits: script-driven layout (Hud's touch cluster, anything a module resizes or
-- fills at runtime) is measured as authored; a runtime-filled grid is linted
-- through its template. A detached template (parked in a Templates holder, sized
-- against wherever code mounts it) is flagged `detached`: the python skips the
-- size-dependent checks on it. Put a `LintIgnore` attribute on an instance to skip
-- it and its descendants (true), or only some checks on them ("oversize,clip"),
-- with a `LintIgnoreReason` string saying why.

local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local opts = _G.UILINT or {}
local SIZES = opts.sizes or { { 1920, 1080 }, { 1366, 768 }, { 844, 390 }, { 667, 375 } }
-- DeviceSafeInsets per size (left, top, right, bottom): 844x390 is a notched phone
-- in landscape (the notch side and the home indicator); the others have none
local SAFE = opts.safe or { ["844x390"] = { 47, 0, 47, 21 } }
-- "Device" UIScales shrink a piece on a phone (PHONE_SCALE in CultivationGui.luau
-- and DeathScreen.luau); keep these in step with those constants
local DEVICE = opts.device or { Cultivation = 0.62, DeathScreen = 0.72 }
local ONLY = opts.guis
local SCENES = opts.scenes ~= false
local MAX_DEPTH = 3
local DESKTOP, PHONE = Vector2.new(1920, 1080), Vector2.new(844, 390)
local HOVER = 1.05 -- Motion.luau HOVER_SCALE on buttons with a "Motion" UIScale

local old = StarterGui:FindFirstChild("_UiLint")
if old then
	old:Destroy()
end
local host = Instance.new("ScreenGui")
host.Name = "_UiLint"
host.IgnoreGuiInset = true
host.ScreenInsets = Enum.ScreenInsets.None
host.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
host.ResetOnSpawn = false
host.Parent = StarterGui

local function rect(o)
	local p, s = o.AbsolutePosition, o.AbsoluteSize
	return { p.X, p.Y, s.X, s.Y }
end

local function intersect(a, b)
	local x0, y0 = math.max(a[1], b[1]), math.max(a[2], b[2])
	local x1, y1 = math.min(a[1] + a[3], b[1] + b[3]), math.min(a[2] + a[4], b[2] + b[4])
	return { x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0) }
end

local function isPhoneSize(w, h)
	return math.min(w, h) < 600
end

local function isCanvas(o)
	local s = o:FindFirstChild("UiScale")
	return s ~= nil and s:IsA("UIScale")
end

-- Mirror UiScale.fit for one canvas at a given viewport size.
local function fitCanvas(canvas, w, h, phone)
	local scale = canvas:FindFirstChild("UiScale")
	local base = if phone then PHONE else DESKTOP
	local s = math.clamp(math.min(w / base.X, h / base.Y), 0.4, 1.5)
	scale.Scale = s
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(w / s, h / s)
end

local function pathOf(o, root)
	local parts = {}
	while o and o ~= root do
		table.insert(parts, 1, o.Name)
		o = o.Parent
	end
	return table.concat(parts, ".")
end

local function hasLayout(o)
	return o and (o:FindFirstChildWhichIsA("UIListLayout") or o:FindFirstChildWhichIsA("UIGridLayout")) ~= nil
end

local function isSwitch(o) -- Phone/Desktop pairs are set per size, never opened
	if o.Name ~= "Phone" and o.Name ~= "Desktop" then
		return false
	end
	local sib = o.Parent and o.Parent:FindFirstChild(if o.Name == "Phone" then "Desktop" else "Phone")
	return sib ~= nil and sib:IsA("GuiObject")
end

local function isDetachedTemplate(o)
	if o:GetAttribute("LintMount") ~= nil and not (o.Parent and o.Parent.Name == "Templates") then
		return false -- moved to its mount for this scene
	end
	local p = o.Parent
	if not (p and p:IsA("GuiObject")) then
		return false
	end
	if p.Name == "Templates" or o.Name == "Templates" then
		return true
	end
	return string.sub(o.Name, -8) == "Template" and not hasLayout(p)
end

-- LintIgnore = true skips an instance and everything in it; a string names the
-- checks to skip on it and everything in it ("oversize", "clip,text-cap", ...)
local function ignored(o)
	return o:GetAttribute("LintIgnore") == true
end

-- the nearest button (self or ancestor) that grows on hover, and its rect
local function hoverOwner(o, stop)
	while o and o ~= stop and o:IsA("GuiObject") do
		if o:IsA("GuiButton") then
			local m = o:FindFirstChild("Motion")
			if m and m:IsA("UIScale") then
				return o
			end
		end
		o = o.Parent
	end
	return nil
end

-- A ribbon cap's plain run: per horizontal band of rows (BANDS of them), how many
-- source columns next to its inner edge (the side that joins the middle) continue
-- the band there (same colour and alpha as the inner edge column, row by row), read
-- from the uploaded image itself (so it works for art missing from assets.json).
-- Past that run is ornament (a curl, a stud, the pointed end); text whose glyphs
-- reach it runs under the cap.
local AssetService = game:GetService("AssetService")
local BANDS = 10
local capCache = {}
local function capPlain(image, left)
	local key = image .. (if left then "L" else "R")
	if capCache[key] == nil then
		capCache[key] = false
		local ok, img = pcall(function()
			return AssetService:CreateEditableImageAsync(Content.fromUri(image))
		end)
		if ok and img then
			local w, h = img.Size.X, img.Size.Y
			local px = img:ReadPixelsBuffer(Vector2.zero, img.Size)
			img:Destroy()
			local edge = if left then w - 1 else 0
			local step = if left then -1 else 1
			local function differs(x, y)
				local i, j = (y * w + x) * 4, (y * w + edge) * 4
				local d = 0
				for c = 0, 3 do
					d = math.max(d, math.abs(buffer.readu8(px, i + c) - buffer.readu8(px, j + c)))
				end
				return d > 64
			end
			local bands = {}
			for band = 1, BANDS do
				local y0, y1 = math.floor((band - 1) * h / BANDS), math.max(math.floor(band * h / BANDS) - 1, math.floor((band - 1) * h / BANDS))
				local run, x = 0, edge
				while x >= 0 and x < w do
					local stop = false
					for y = y0, y1 do
						if differs(x, y) then
							stop = true
							break
						end
					end
					if stop then
						break
					end
					run += 1
					x += step
				end
				bands[band] = run
			end
			capCache[key] = { bands = bands, size = { w, h } }
		end
	end
	return capCache[key] or nil
end

local function record(o, stand, view, clipRect, clipPath, clipInst, scene, items, detached, skip)
	local r = rect(o)
	local item = {
		gui = stand.Name,
		path = pathOf(o, stand),
		class = o.ClassName,
		scene = scene,
		rect = r,
		parent = if o.Parent and o.Parent:IsA("GuiObject") then rect(o.Parent) else rect(view),
		clip = clipRect,
		clipPath = clipPath,
		anchor = { o.AnchorPoint.X, o.AnchorPoint.Y },
		rotation = o.Rotation,
		zIndex = o.ZIndex,
		canvas = isCanvas(o),
		-- a Frame that draws nothing itself (its children are checked on their own)
		bare = o.ClassName == "Frame" and o.BackgroundTransparency >= 1 or nil,
		detached = detached or nil,
		skip = skip,
		siblings = 0,
		visibleSiblings = 0,
	}
	-- hover growth: the rect scaled about its button's centre, when the clipper is
	-- outside that button (a button growing inside itself clips nothing)
	local owner = hoverOwner(o, stand)
	if owner and not (clipInst and clipInst:IsDescendantOf(owner)) and clipInst ~= owner then
		local orr = rect(owner)
		local cx, cy = orr[1] + orr[3] / 2, orr[2] + orr[4] / 2
		item.hover = { cx + (r[1] - cx) * HOVER, cy + (r[2] - cy) * HOVER, r[3] * HOVER, r[4] * HOVER }
	end
	local layout = o.Parent and (o.Parent:FindFirstChildWhichIsA("UIListLayout") or o.Parent:FindFirstChildWhichIsA("UIGridLayout"))
	item.layout = if layout then layout.ClassName else nil
	if layout then
		item.layoutAlign = { layout.HorizontalAlignment.Name, layout.VerticalAlignment.Name }
	end
	if o.Parent then
		for _, s in ipairs(o.Parent:GetChildren()) do
			if s:IsA("GuiObject") then
				item.siblings += 1
				if s.Visible then
					item.visibleSiblings += 1
				end
			end
		end
	end
	if o:IsA("ImageLabel") or o:IsA("ImageButton") then
		item.image = o.Image
		item.scaleType = o.ScaleType.Name
		item.sliceCenter = { o.SliceCenter.Min.X, o.SliceCenter.Min.Y, o.SliceCenter.Max.X, o.SliceCenter.Max.Y }
		item.sliceScale = o.SliceScale
		item.rectSize = { o.ImageRectSize.X, o.ImageRectSize.Y }
		item.rectOffset = { o.ImageRectOffset.X, o.ImageRectOffset.Y }
		item.imageTransparency = o.ImageTransparency
		if (o.Name == "CapL" or o.Name == "CapR") and o.Image ~= "" then
			local c = capPlain(o.Image, o.Name == "CapL")
			if c then
				item.capBands, item.srcSize = c.bands, c.size
			end
		end
	end
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		item.text = o.Text
		item.textScaled = o.TextScaled
		item.autoSize = o.AutomaticSize.Name
		item.textTruncate = o.TextTruncate.Name
		item.textSize = o.TextSize
		item.textFits = o.TextFits
		item.textBounds = { o.TextBounds.X, o.TextBounds.Y }
		item.textWrapped = o.TextWrapped
		item.textTransparency = o.TextTransparency
		item.textX = o.TextXAlignment.Name
		item.textY = o.TextYAlignment.Name
		item.font = o.FontFace.Family
		local c = o:FindFirstChildWhichIsA("UITextSizeConstraint")
		item.maxTextSize = if c then c.MaxTextSize else nil
	end
	items[#items + 1] = item
end

-- Walk a gui and record every shown, unignored GuiObject inside `scope` (nil: all).
local function walkGui(stand, view, scope, scene, items)
	local function walk(o, clipRect, clipPath, clipInst, inScope, detached, skip)
		if o:IsA("GuiObject") then
			if not o.Visible or ignored(o) then
				return
			end
			inScope = inScope or scope == nil or o == scope
			local own = o:GetAttribute("LintIgnore")
			if type(own) == "string" then
				skip = if skip then skip .. "," .. own else own
			end
			-- a detached template (in a Templates holder, or not in a layout) is placed
			-- by code: only clippers inside it limit it, not where it's parked
			if isDetachedTemplate(o) then
				clipRect, clipPath, clipInst, detached = nil, "<template>", nil, true
			end
			local r = rect(o)
			if inScope and r[3] > 0 and r[4] > 0 then
				record(o, stand, view, clipRect, clipPath, clipInst, scene, items, detached, skip)
			end
			if o:IsA("ScrollingFrame") then
				-- content may run past the window along a scrolling axis (code often
				-- sizes the canvas at runtime), never above or left of the canvas, nor
				-- across a fixed axis. Y scrolls whenever the direction allows it; X only
				-- for an X scroller or an XY one whose canvas is wider than the window.
				local dir = o.ScrollingDirection
				local auto = o.AutomaticCanvasSize
				local BIG = 1e5
				local lim = { r[1], r[2], r[3], r[4] }
				local xs = dir == Enum.ScrollingDirection.X
					or (dir == Enum.ScrollingDirection.XY and (auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY
						or o.AbsoluteCanvasSize.X > r[3] + 1))
				if xs then
					lim[3] = BIG
				end
				if dir ~= Enum.ScrollingDirection.X then
					lim[4] = BIG
				end
				clipRect, clipPath, clipInst = lim, pathOf(o, stand), o
			elseif o.ClipsDescendants then
				clipRect, clipPath, clipInst = if clipRect then intersect(clipRect, r) else r, pathOf(o, stand), o
			elseif isCanvas(o) and clipRect then
				-- a UiScale canvas is the screen in baseline units: its children are
				-- limited by what of it is on screen
				clipRect, clipPath, clipInst = intersect(clipRect, r), pathOf(o, stand), o
			end
		end
		if scope ~= nil and not inScope and not (o == stand or scope:IsDescendantOf(o)) then
			return -- not on the way to the scope
		end
		for _, c in ipairs(o:GetChildren()) do
			walk(c, clipRect, clipPath, clipInst, inScope, detached, skip)
		end
	end
	walk(stand, rect(view), "<screen>", nil, scope == nil)
end

-- Show root and the hidden things inside it, except children of a layout (they
-- become nested scenes). A template with a `LintMount` attribute (a path from its
-- ScreenGui, e.g. "Canvas.Window.LeftPage") is first moved where code mounts it,
-- so it's measured at its real size. Returns the undo list and the nested
-- candidates; an undo entry is an instance to hide or {instance, old parent}.
local function open(root, stand)
	local undo, nested = {}, {}
	local mount = root:GetAttribute("LintMount")
	if type(mount) == "string" then
		local target = stand
		for part in string.gmatch(mount, "[^%.]+") do
			target = target and target:FindFirstChild(part)
		end
		if target then
			undo[#undo + 1] = { root, root.Parent }
			root.Parent = target
			-- the window it mounts in may be closed: open the way to it
			local up = target
			while up and up ~= stand do
				if up:IsA("GuiObject") and not up.Visible then
					up.Visible = true
					undo[#undo + 1] = up
				end
				up = up.Parent
			end
		else
			warn(`ui_lint: {root:GetFullName()} LintMount {mount} not found`)
		end
	end
	local function show(o)
		if not o.Visible then
			o.Visible = true
			undo[#undo + 1] = o
		end
	end
	show(root)
	local function walk(o)
		for _, c in ipairs(o:GetChildren()) do
			if c:IsA("GuiObject") and not ignored(c) then
				if c:GetAttribute("LintMount") ~= nil then
					nested[#nested + 1] = c -- measured where it mounts, as a scene of its own
					continue
				end
				if not c.Visible then
					if isSwitch(c) then
						continue -- stays as the size set it
					elseif hasLayout(o) then
						nested[#nested + 1] = c
						continue
					end
					show(c)
				end
				walk(c)
			end
		end
	end
	walk(root)
	return undo, nested
end

-- Hidden GuiObjects under a shown path (scene roots), not inside a hidden one.
local function hiddenRoots(o, out)
	for _, c in ipairs(o:GetChildren()) do
		if c:IsA("GuiObject") and not ignored(c) then
			if not c.Visible then
				if not isSwitch(c) then
					out[#out + 1] = c
				end
			else
				hiddenRoots(c, out)
			end
		end
	end
	return out
end

local function dump(size, guis0)
	local w, h = size[1], size[2]
	local phone = isPhoneSize(w, h)
	local view = Instance.new("Frame")
	view.Name = "View"
	view.BackgroundTransparency = 1
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromOffset(w, h)
	view.ClipsDescendants = true
	view.Parent = host

	local guis = {}
	for _, g in ipairs(guis0) do
		-- a frame standing in for the ScreenGui
		local stand = Instance.new("Frame")
		stand.Name = g.Name
		stand.BackgroundTransparency = 1
		stand.Size = UDim2.fromScale(1, 1)
		local safe = g.ScreenInsets == Enum.ScreenInsets.DeviceSafeInsets and SAFE[w .. "x" .. h]
		if safe then
			stand.Position = UDim2.fromOffset(safe[1], safe[2])
			stand.Size = UDim2.new(1, -safe[1] - safe[3], 1, -safe[2] - safe[4])
		end
		stand:SetAttribute("SafeW", w - (if safe then safe[1] + safe[3] else 0))
		stand:SetAttribute("SafeH", h - (if safe then safe[2] + safe[4] else 0))
		for _, c in ipairs(g:GetChildren()) do
			if c:IsA("GuiObject") or c:IsA("UIBase") then
				c:Clone().Parent = stand
			end
		end
		stand.Parent = view
		guis[#guis + 1] = stand
	end

	-- UiScale canvases and Phone/Desktop subtrees
	for _, stand in ipairs(guis) do
		for _, d in ipairs(stand:GetDescendants()) do
			if d:IsA("UIScale") and d.Name == "UiScale" and d.Parent:IsA("GuiObject") then
				fitCanvas(d.Parent, stand:GetAttribute("SafeW"), stand:GetAttribute("SafeH"), phone)
			end
		end
		for _, d in ipairs(stand:GetDescendants()) do
			if d:IsA("UIScale") and d.Name == "Device" and DEVICE[stand.Name] then
				d.Scale = if phone then DEVICE[stand.Name] else 1
			end
		end
		for _, d in ipairs(stand:GetDescendants()) do
			if d:IsA("GuiObject") and isSwitch(d) then
				d.Visible = (d.Name == "Phone") == phone
			end
		end
	end
	task.wait()
	task.wait()

	local items = {}
	local scenes = 0
	for _, stand in ipairs(guis) do
		walkGui(stand, view, nil, "base", items)
		if SCENES then
			local queue = {}
			for _, r in ipairs(hiddenRoots(stand, {})) do
				queue[#queue + 1] = { r }
			end
			local i = 0
			while i < #queue do
				i += 1
				local chain = queue[i]
				local undos = {}
				local nested
				for _, r in ipairs(chain) do
					local u
					u, nested = open(r, stand)
					undos[#undos + 1] = u
				end
				task.wait()
				local last = chain[#chain]
				local scope = if hasLayout(last.Parent) then last.Parent else last
				walkGui(stand, view, scope, pathOf(last, stand), items)
				scenes += 1
				if #chain < MAX_DEPTH then
					for _, n in ipairs(nested) do
						local c = table.clone(chain)
						c[#c + 1] = n
						queue[#queue + 1] = c
					end
				end
				for k = #undos, 1, -1 do
					for j = #undos[k], 1, -1 do
						local o = undos[k][j]
						if type(o) == "table" then
							o[1].Parent = o[2]
						else
							o.Visible = false
						end
					end
				end
			end
		end
	end

	-- one post per gui (Studio caps a post at 1 MB)
	local byGui = {}
	for _, it in ipairs(items) do
		byGui[it.gui] = byGui[it.gui] or {}
		table.insert(byGui[it.gui], it)
	end
	for gui, list in pairs(byGui) do
		HttpService:PostAsync(
			("http://127.0.0.1:8766/uilint_%dx%d_%s"):format(w, h, gui),
			HttpService:JSONEncode({ size = { w, h }, phone = phone, gui = gui, items = list }),
			Enum.HttpContentType.ApplicationJson
		)
	end
	if not opts.keep then
		view:Destroy()
	end
	return #items, scenes
end

local guis0 = {}
for _, parent in ipairs({ StarterGui, ReplicatedStorage }) do
	for _, g in ipairs(parent:GetChildren()) do
		-- names starting with "_" are previews and staging copies, not the build
		if g:IsA("ScreenGui") and g ~= host and string.sub(g.Name, 1, 1) ~= "_" and (not ONLY or table.find(ONLY, g.Name)) then
			guis0[#guis0 + 1] = g
		end
	end
end

local counts = {}
local ok, err = pcall(function()
	for _, size in ipairs(SIZES) do
		local n, s = dump(size, guis0)
		counts[#counts + 1] = ("%dx%d: %d items, %d scenes"):format(size[1], size[2], n, s)
	end
end)
if not opts.keep then
	host:Destroy()
end
if not ok then
	error(err)
end
return "ui_lint dumped " .. table.concat(counts, "; ")
