--[[
Palette pass on the spirit peaks' own parts (docs/systems/map.md palette), on every peak, the
ServerStorage.PeakPillar template and the catalogue Dwelling. Run in Studio Edit mode via the MCP; re-runnable.

The user found parts on the peaks that read "not coloured": the near-white flagstones and terrace slabs
(sunlit Slate tops render far lighter than their tint: the tints here are chosen by eye in game), plain SmoothPlastic house walls and Plastic roofs, and the abode hall's
SmoothPlastic walls. Library MeshParts keep their SurfaceAppearances; this only touches plain parts.
  - Dressing.Path flagstones, Pillar.Terrace slabs and walls: warm stone grays a step darker, per-stone variation
  - Dressing.Stones column stubs: the pillar rock's grays, darker than the lawn-side stone
  - Dwelling (and BuildCatalog.Dwelling) walls/gables/door head: Plaster, warm cream; roof slabs and ridges:
    Slate, dark blue-gray (CaveAbode.Facade's roof too)
  - BridgeGate pillar bases, Bridge post caps, NameStele base and cap: from a pale 96948E to warm 7E776B; the
    BridgeGate flank walls from Pavement (black-looking sides) to Slate in the same 7E776B
  - Pillar.AbodeWalls (hall inside the pillar): Slate, warm gray (place_peak_pillar.luau STYLE matches)
]]

local CHS = game:GetService("ChangeHistoryService")
local CFG = _G.RECOLOR_PEAKS or {}
local PEAKS = CFG.peaks or { 1, 2, 3, 4, 5, 6, 7, 8 }

local FLAG = { "6A6358", "625B51", "72695E", "5D564C" }
local SLAB = { "7E766A", "756D61", "857C70" }
local TERRACE_WALL = "6E675C"
local STUB = { "6E6A65", "66625D", "5E5A55", "726D67" }
local PLASTER = "E6DFCF"
local ROOF = "3E464D"
local RIDGE = "2E363C"
local ABODE_WALLS = "8A847D"
local PALE_STONE = "7E776B"

local count = 0
local function set(p: BasePart, material: Enum.Material, hex: string)
	p.Material = material
	p.MaterialVariant = ""
	p.Color = Color3.fromHex(hex)
	count += 1
end

local function house(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not d:FindFirstChildWhichIsA("SurfaceAppearance") then
			local hex = d.Color:ToHex()
			local plain = d.Material == Enum.Material.SmoothPlastic or d.Material == Enum.Material.Plastic
			if plain and (hex == "e8e2d2" or hex == "e6dfcf") then
				set(d, Enum.Material.Plaster, PLASTER)
			elseif d.Name == "RoofSlab" and (plain or d.Material == Enum.Material.Slate) then
				set(d, Enum.Material.Slate, ROOF)
			elseif (d.Name == "Ridge" or d.Name == "RidgeEnd") and (plain or d.Material == Enum.Material.Slate) then
				set(d, Enum.Material.Slate, RIDGE)
			end
		end
	end
end

local function pick(list: { string }, k: number): string
	return list[(k % #list) + 1]
end

local function peakPass(peak: Model)
	local dressing = peak:FindFirstChild("Dressing")
	if dressing then
		local path = dressing:FindFirstChild("Path")
		if path then
			for k, f in path:GetChildren() do
				if f:IsA("BasePart") then
					set(f, Enum.Material.Slate, pick(FLAG, k * 7))
				end
			end
		end
		local stones = dressing:FindFirstChild("Stones")
		if stones then
			for k, d in stones:GetDescendants() do
				if d:IsA("BasePart") then
					set(d, Enum.Material.Slate, pick(STUB, #d.Name + k // 3))
				end
			end
		end
	end
	local pillar = peak:FindFirstChild("Pillar")
	local terrace = pillar and pillar:FindFirstChild("Terrace")
	if terrace then
		for k, d in terrace:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Slab" then
					set(d, Enum.Material.Slate, pick(SLAB, k * 5))
				elseif d.Name:match("^Body") or d.Name:match("^Corner") or d.Name:match("^Step") then
					set(d, Enum.Material.Slate, TERRACE_WALL)
				end
			end
		end
	end
	local walls = pillar and pillar:FindFirstChild("AbodeWalls")
	if walls then
		set(walls :: BasePart, Enum.Material.Slate, ABODE_WALLS)
	end
	local dwelling = peak:FindFirstChild("Dwelling")
	if dwelling then
		house(dwelling)
	end
	-- the gate's pillar bases, the bridge's post caps and the stele's base and cap were a pale 96948E
	-- the gate's flank walls were Pavement with the "Stylized Pavement II" variant, whose metalness map renders
	-- the sides near black (a dark slab with a void under it, next to the bridge landing)
	for _, n in { "BridgeGate", "Bridge", "NameStele" } do
		local m = peak:FindFirstChild(n)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d.Material == Enum.Material.Slate and d.Color:ToHex() == "96948e" then
					set(d, Enum.Material.Slate, PALE_STONE)
				elseif d:IsA("BasePart") and d.Name == "FlankWall" and d.Material == Enum.Material.Pavement then
					set(d, Enum.Material.Slate, PALE_STONE)
				end
			end
		end
	end
	local facade = peak:FindFirstChild("CaveAbode") and (peak:FindFirstChild("CaveAbode") :: Instance):FindFirstChild("Facade")
	if facade then
		house(facade)
	end
end

local recording = CHS:TryBeginRecording("RecolorSpiritPeaks")
local ok, err = pcall(function()
	for _, i in PEAKS do
		peakPass(workspace.Map.Sect.SpiritPeaks:FindFirstChild("Peak_" .. i) :: Model)
	end
	local t = game:GetService("ServerStorage"):FindFirstChild("PeakPillar")
	local tw = t and t:FindFirstChild("AbodeWalls")
	if tw then
		set(tw :: BasePart, Enum.Material.Slate, ABODE_WALLS)
	end
	local cat = game:GetService("ReplicatedStorage"):FindFirstChild("BuildCatalog")
	local d = cat and cat:FindFirstChild("Dwelling")
	if d then
		house(d)
	end
end)
if recording then
	CHS:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
end
assert(ok, err)
return count .. " parts recoloured"
