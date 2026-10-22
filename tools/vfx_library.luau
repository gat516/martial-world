--!nocheck
-- Searches the VFX plugin's (vfxia) Asset Library from the Studio MCP, by typing
-- into the library window's own search box and reading the tiles it shows. The
-- user must have opened the Asset Library window once this Studio session, in
-- Edit mode (it lives in CoreGui.ViewSelectorScreenGui.Selection.Seperate.Library,
-- formerly under RobloxGui; closing
-- it only hides it). Run this file once through
-- execute_luau: it installs
--   _G.vfxLibrary.search(query, limit?) -> { { id, kind, name? } }
--   _G.vfxLibrary.index(queries, limit?) -> JSON { [query] = { ... } }
-- kind is "image", "mesh", "flipbook" or "sound" (sounds also carry a name).
-- Tiles only carry the asset id; to judge an image, fetch its thumbnail:
-- https://thumbnails.roblox.com/v1/assets?assetIds=<id>&size=150x150&format=Png
--   _G.vfxLibrary.dump(queries, name, limit?) -> posts index() to the receiver
--     (tools/ensure_receiver.sh) as tools/frag/<name>.xml instead of returning
--     it, for tools/vfx_contact_sheet.py's layer mode (one sheet per layer)
-- tools/vfx_library.json is a keyword index built with index().

local HttpService = game:GetService("HttpService")

local function library()
	-- the plugin has parented its window under both of these
	local node
	for _, root in { "ViewSelectorScreenGui", "RobloxGui" } do
		node = game:GetService("CoreGui"):FindFirstChild(root)
		for _, name in { "Selection", "Seperate", "Library" } do
			node = node and node:FindFirstChild(name)
		end
		if node then
			break
		end
	end
	-- search keeps working after the window is closed, as long as it was opened once
	assert(node, "Open the VFX plugin's Asset Library window in Edit mode first")
	return node.Top.Search.Box, node.Folder.Right.Scroll
end

local function tiles(query: string)
	local box, scroll = library()
	box.Text = query
	task.wait(0.6)
	local found = {}
	for _, tile in scroll:GetChildren() do
		if tile:IsA("GuiButton") and tile.Visible and tile.Name:match("^%d+$") then
			table.insert(found, tile)
		end
	end
	table.sort(found, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	return found
end

-- Flipbooks look like images in the grid; the library tags them "flipbook".
local flipbooks
local function isFlipbook(id: string): boolean
	if not flipbooks then
		flipbooks = {}
		for _, tile in tiles("flipbook") do
			flipbooks[tile.Name] = true
		end
	end
	return flipbooks[id] == true
end

local function describe(tile)
	if tile:FindFirstChildWhichIsA("ViewportFrame") then
		return { id = tile.Name, kind = "mesh" }
	end
	local label = tile:FindFirstChildWhichIsA("TextLabel")
	if label then
		return { id = tile.Name, kind = "sound", name = label.Text }
	end
	return { id = tile.Name, kind = if isFlipbook(tile.Name) then "flipbook" else "image" }
end

local function search(query: string, limit: number?)
	isFlipbook("") -- run the flipbook search first so it doesn't replace this query
	local results = {}
	for _, tile in tiles(query) do
		if limit and #results >= limit then
			break
		end
		table.insert(results, describe(tile))
	end
	return results
end

local function index(queries, limit)
	local out = {}
	for _, q in queries do
		out[q] = search(q, limit)
	end
	library().Text = ""
	return HttpService:JSONEncode(out)
end

_G.vfxLibrary = {
	search = search,
	index = index,
	dump = function(queries, name, limit)
		local json = index(queries, limit or 120)
		HttpService:PostAsync("http://127.0.0.1:8766/" .. name, json)
		return `{#queries} words -> tools/frag/{name}.xml ({#json} bytes)`
	end,
}
return "vfxLibrary installed"
