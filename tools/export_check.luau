--!nocheck
-- Live half of the export round-trip check (tools/export_check.py). Run right after
-- exporting a GUI with tools/export_rbxmx.luau (it needs _G.exportRbxmxEncode):
--   _G.EXPORTCHECK = { target = "StarterGui.Hud", name = "Hud" }
--   loadstring(<this file>)()
-- For every instance under the target it lists, through ReflectionService, each
-- serialized property whose value differs from a fresh instance of its class, with
-- the exporter's own encoding of the value (or "<unsupported>" when the exporter
-- has no encoding for its type), plus its string/bool/number attributes, and posts
-- the lot to the receiver as tools/frag/exportcheck_<name>.xml (JSON). The python
-- half compares it with the .rbxmx: a property that differs from the default live
-- but is missing from the file, or written with another value, is a FAIL: the
-- exporter dropped or substituted it (how a crop shipped when SizeConstraint was
-- missing from its list).

local HttpService = game:GetService("HttpService")
local Reflection = game:GetService("ReflectionService")
local opts = _G.EXPORTCHECK or error("set _G.EXPORTCHECK = { target = ..., name = ... }")
local encode = _G.exportRbxmxEncode or error("run tools/export_rbxmx.luau first")

-- properties that never matter to a GUI's look (or Studio-only bookkeeping)
local SKIP = {
	Capabilities = true, Sandboxed = true, SourceAssetId = true, UniqueId = true, HistoryId = true,
	Tags = true, AttributesSerialize = true, DefinesCapabilities = true, RootLocalizationTable = true,
	SelectionBehaviorDown = true, SelectionBehaviorLeft = true, SelectionBehaviorRight = true,
	SelectionBehaviorUp = true, SelectionGroup = true, SelectionOrder = true, NextSelectionDown = true,
	NextSelectionLeft = true, NextSelectionRight = true, NextSelectionUp = true, SelectionImageObject = true,
	AutoLocalize = true, Draggable = true, ScriptGuid = true, LinkedSource = true, Source = true,
}

local node = game
for part in string.gmatch(opts.target, "[^%.]+") do
	node = node:FindFirstChild(part) or game:GetService(part)
end

local defaults = {}
local function default(class)
	if defaults[class] == nil then
		local ok, inst = pcall(Instance.new, class)
		defaults[class] = if ok then inst else false
	end
	return defaults[class]
end

local propsOf = {}
local function props(class)
	if not propsOf[class] then
		local list = {}
		for _, p in ipairs(Reflection:GetPropertiesOfClass(class)) do
			if p.Serialized and not SKIP[p.Name] then
				table.insert(list, p.Name)
			end
		end
		propsOf[class] = list
	end
	return propsOf[class]
end

local function same(a, b)
	if typeof(a) == "number" and typeof(b) == "number" then
		return math.abs(a - b) < 1e-6
	end
	return a == b
end

local out = {}
local function walk(inst, path)
	local base = default(inst.ClassName)
	local rec = { class = inst.ClassName, props = {}, attrs = {} }
	for _, name in ipairs(props(inst.ClassName)) do
		local ok, v = pcall(function()
			return inst[name]
		end)
		if ok and v ~= nil and typeof(v) ~= "Instance" then
			local okD, d = pcall(function()
				return base and base[name]
			end)
			-- UICorner's per-corner radii follow CornerRadius unless set apart
			local alias = string.match(name, "^%a+Radius$") and name ~= "CornerRadius" and inst:IsA("UICorner")
				and v == inst.CornerRadius
			if not alias and (name == "Name" or not (okD and base and same(v, d))) then
				local okE, line = pcall(encode, inst, name, v)
				rec.props[name] = if okE and line then line else "<unsupported " .. typeof(v) .. ">"
			end
		end
	end
	for k, v in pairs(inst:GetAttributes()) do
		rec.attrs[k] = if typeof(v) == "string" or typeof(v) == "boolean" or typeof(v) == "number" then v else "<" .. typeof(v) .. ">"
	end
	out[path] = rec
	local seen = {}
	for _, c in ipairs(inst:GetChildren()) do
		seen[c.Name] = (seen[c.Name] or 0) + 1
		walk(c, path .. "/" .. c.Name .. "#" .. seen[c.Name])
	end
end
walk(node, node.Name .. "#1")

local body = HttpService:JSONEncode(out)
HttpService:PostAsync("http://127.0.0.1:8766/exportcheck_" .. opts.name, body, Enum.HttpContentType.ApplicationJson)
local n = 0
for _ in pairs(out) do
	n += 1
end
return ("export_check: %d instances posted (%d KB)"):format(n, #body // 1024)
