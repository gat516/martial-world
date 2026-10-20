--!nocheck
-- Serializes an instance tree to .rbxmx text, for keeping MCP-authored instances
-- in git. Run this file once through the Studio MCP's execute_luau: it installs
-- _G.exportRbxmx(path, referentPrefix) in Studio's plugin context. Then
-- `return _G.exportRbxmx("StarterGui.Hud", "RBX")` returns the XML to write under
-- assets/ (tools/receive_rbxmx.py takes large exports over loopback HTTP). The
-- prefix keeps referents unique when splicing into an existing file.
-- Only properties that differ from a fresh instance of the same class are written.
-- Attributes and tags aren't supported (keep templates free of them).

local PROPS = {
	"Name", "Active", "AnchorPoint", "AutomaticSize", "BackgroundColor3", "BackgroundTransparency",
	"BorderSizePixel", "ClipsDescendants", "LayoutOrder", "Position", "Rotation", "Size", "Visible",
	"ZIndex", "AutoButtonColor", "Selectable", "Text", "TextColor3", "TextSize", "TextScaled",
	"TextWrapped", "TextXAlignment", "TextYAlignment", "TextTransparency", "TextStrokeTransparency",
	"TextStrokeColor3", "TextTruncate", "RichText", "FontFace", "LineHeight", "Image", "ImageColor3",
	"ImageTransparency", "ScaleType", "SliceCenter", "SliceScale", "ImageRectOffset", "ImageRectSize",
	"CanvasSize", "AutomaticCanvasSize", "ScrollBarThickness", "ScrollBarImageColor3",
	"ScrollBarImageTransparency", "ScrollingDirection", "ElasticBehavior", "VerticalScrollBarInset",
	"ResetOnSpawn", "ZIndexBehavior", "IgnoreGuiInset", "DisplayOrder", "ScreenInsets",
	"CornerRadius", "Color", "Thickness", "Transparency", "ApplyStrokeMode", "LineJoinMode", "Offset",
	"FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Padding", "Wraps",
	"CellSize", "CellPadding", "FillDirectionMaxCells", "StartCorner", "PaddingTop", "PaddingBottom",
	"PaddingLeft", "PaddingRight", "MinSize", "MaxSize", "AspectRatio", "AspectType", "DominantAxis",
	"Scale", "MaxTextSize", "MinTextSize", "FlexMode", "GrowRatio", "ShrinkRatio", "HorizontalFlex",
	"VerticalFlex", "ItemLineAlignment", "PlaceholderText", "PlaceholderColor3", "ClearTextOnFocus",
	"Anchored", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Massless", "Material",
	"Reflectance", "Shape", "TopSurface", "BottomSurface", "CFrame",
	"CanBeDropped", "RequiresHandle", "ManualActivationOnly", "ToolTip", "TextureId", "Grip", "Enabled",
	"Brightness", "Range", "Shadows", "Texture", "Lifetime", "Rate", "Speed", "SpreadAngle",
	"LightEmission", "LightInfluence", "RotSpeed", "Acceleration", "Drag", "EmissionDirection",
	"ZOffset", "LockedToPart", "ShapeStyle", "Squash", "Orientation",
	"Attachment0", "Attachment1", "Width0", "Width1", "FaceCamera", "TextureSpeed", "TextureLength",
	"Segments", "CurveSize0", "CurveSize1",
	"ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "RequiresLineOfSight",
	"KeyboardKeyCode", "GamepadKeyCode", "UIOffset", "Exclusivity",
	"StudsOffset", "StudsOffsetWorldSpace", "ExtentsOffset", "ExtentsOffsetWorldSpace", "AlwaysOnTop", "MaxDistance", "Adornee", "SizeOffset",
	"Part0", "Part1", "MeshType", "PrimaryPart", "AnimationId",
	"FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency", "DepthMode",
	"SoundId", "Volume", "Looped", "PlaybackSpeed", "RollOffMaxDistance", "RollOffMinDistance",
}

local INT = {
	ZIndex = true, LayoutOrder = true, BorderSizePixel = true, ScrollBarThickness = true,
	DisplayOrder = true, FillDirectionMaxCells = true, Segments = true, MaxTextSize = true,
	MinTextSize = true,
}
local CONTENT = { Image = true, Texture = true, TextureId = true, AnimationId = true, SoundId = true }
local RENAME = { Size = "size", Shape = "shape" } -- on parts only

local function num(n: number): string
	if n == math.floor(n) and math.abs(n) < 1e9 then
		return tostring(math.floor(n))
	end
	return string.format("%.6g", n)
end

local function esc(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local PREFIX = "RBX"
local refs = {}
local count = 0
local function ref(inst)
	if not refs[inst] then
		count += 1
		refs[inst] = PREFIX .. count
	end
	return refs[inst]
end

local function encode(inst, name, v): string?
	local t = typeof(v)
	local isPart = inst:IsA("BasePart")
	if isPart and name == "Color" then
		local c = v :: Color3
		local packed = 0xFF000000 + math.floor(c.R * 255 + 0.5) * 0x10000 + math.floor(c.G * 255 + 0.5) * 0x100 + math.floor(c.B * 255 + 0.5)
		return `<Color3uint8 name="Color3uint8">{packed}</Color3uint8>`
	end
	local tag = if isPart and RENAME[name] then RENAME[name] else name
	if CONTENT[name] then
		return `<Content name="{tag}"><url>{esc(tostring(v))}</url></Content>`
	elseif t == "string" then
		return `<string name="{tag}">{esc(v)}</string>`
	elseif t == "boolean" then
		return `<bool name="{tag}">{tostring(v)}</bool>`
	elseif t == "number" then
		return `<{if INT[name] then "int" else "float"} name="{tag}">{num(v)}</{if INT[name] then "int" else "float"}>`
	elseif t == "Color3" then
		return `<Color3 name="{tag}"><R>{num(v.R)}</R><G>{num(v.G)}</G><B>{num(v.B)}</B></Color3>`
	elseif t == "UDim" then
		return `<UDim name="{tag}"><S>{num(v.Scale)}</S><O>{num(v.Offset)}</O></UDim>`
	elseif t == "UDim2" then
		return `<UDim2 name="{tag}"><XS>{num(v.X.Scale)}</XS><XO>{num(v.X.Offset)}</XO><YS>{num(v.Y.Scale)}</YS><YO>{num(v.Y.Offset)}</YO></UDim2>`
	elseif t == "Vector2" then
		return `<Vector2 name="{tag}"><X>{num(v.X)}</X><Y>{num(v.Y)}</Y></Vector2>`
	elseif t == "Vector3" then
		return `<Vector3 name="{tag}"><X>{num(v.X)}</X><Y>{num(v.Y)}</Y><Z>{num(v.Z)}</Z></Vector3>`
	elseif t == "CFrame" then
		local c = { v:GetComponents() }
		local names = { "X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22" }
		local parts = {}
		for i, n in names do
			table.insert(parts, `<{n}>{num(c[i])}</{n}>`)
		end
		return `<CoordinateFrame name="{tag}">{table.concat(parts)}</CoordinateFrame>`
	elseif t == "EnumItem" then
		return `<token name="{tag}">{v.Value}</token>`
	elseif t == "ColorSequence" then
		local parts = {}
		for _, k in v.Keypoints do
			table.insert(parts, `{num(k.Time)} {num(k.Value.R)} {num(k.Value.G)} {num(k.Value.B)} 0 `)
		end
		return `<ColorSequence name="{tag}">{table.concat(parts)}</ColorSequence>`
	elseif t == "NumberSequence" then
		local parts = {}
		for _, k in v.Keypoints do
			table.insert(parts, `{num(k.Time)} {num(k.Value)} {num(k.Envelope)} `)
		end
		return `<NumberSequence name="{tag}">{table.concat(parts)}</NumberSequence>`
	elseif t == "NumberRange" then
		return `<NumberRange name="{tag}">{num(v.Min)} {num(v.Max)} </NumberRange>`
	elseif t == "Rect" then
		return `<Rect2D name="{tag}"><min><X>{num(v.Min.X)}</X><Y>{num(v.Min.Y)}</Y></min><max><X>{num(v.Max.X)}</X><Y>{num(v.Max.Y)}</Y></max></Rect2D>`
	elseif t == "Font" then
		return `<Font name="{tag}"><Family><url>{v.Family}</url></Family><Weight>{v.Weight.Value}</Weight><Style>{v.Style.Name}</Style></Font>`
	elseif t == "Instance" then
		return `<Ref name="{tag}">{ref(v)}</Ref>`
	end
	return nil
end

local defaults = {}
local function default(class)
	if defaults[class] == nil then
		local ok, inst = pcall(Instance.new, class)
		defaults[class] = if ok then inst else false
	end
	return defaults[class]
end

local function same(a, b): boolean
	if typeof(a) == "number" and typeof(b) == "number" then
		return math.abs(a - b) < 1e-6
	end
	return a == b
end

local out = {}
local function emit(inst, depth)
	local pad = string.rep(" ", depth)
	table.insert(out, `{pad}<Item class="{inst.ClassName}" referent="{ref(inst)}"><Properties>`)
	local base = default(inst.ClassName)
	-- parts and attachments: CFrame carries the transform; these just mirror it
	local derived = inst:IsA("BasePart") or inst:IsA("Attachment")
	for _, name in PROPS do
		if derived and (name == "Position" or name == "Orientation" or name == "Rotation") then
			continue
		end
		-- GuiObject.Transparency is a hidden alias of BackgroundTransparency
		if name == "Transparency" and inst:IsA("GuiObject") then
			continue
		end
		local ok, v = pcall(function()
			return inst[name]
		end)
		if ok and v ~= nil and typeof(v) ~= "RBXScriptSignal" and typeof(v) ~= "function" then
			local okBase, d = pcall(function()
				return base and base[name]
			end)
			local skip = okBase and base and same(v, d)
			if name == "Name" then
				skip = false
			end
			if inst:IsA("BasePart") and name == "CFrame" then
				skip = false
			end
			if not skip then
				local line = encode(inst, name, v)
				if line then
					table.insert(out, `{pad} {line}`)
				end
			end
		end
	end
	table.insert(out, `{pad}</Properties>`)
	for _, child in inst:GetChildren() do
		emit(child, depth + 1)
	end
	table.insert(out, `{pad}</Item>`)
end

_G.exportRbxmx = function(target: string, prefix: string?): string
	PREFIX = prefix or "RBX"
	table.clear(refs)
	count = 0
	table.clear(out)
	local node = game
	for part in string.gmatch(target, "[^%.]+") do
		node = node:FindFirstChild(part) or game:GetService(part)
	end
	emit(node, 1)
	return table.concat(out, "\n")
end
return "exportRbxmx installed"
