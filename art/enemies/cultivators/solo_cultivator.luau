--!nocheck
-- Places one cultivator alone on a plate at (600, 400, 3000) in
-- Workspace._RosterPreviewCultivators.Solo for close captures, optionally posed.
-- Set NAME and POSE ("rest", "windup", "stress") by gsub before loadstring. Uses the
-- pose tables in preview_cultivators.luau (loaded with RUN = false).
local BASE = _G.SERVE_BASE and (_G.SERVE_BASE .. "art/enemies/") or "http://127.0.0.1:8767/"
local NAME = "RogueCultivator"
local POSE = "rest"
local src = game:GetService("HttpService"):GetAsync(
	BASE .. "cultivators/preview_cultivators.luau?" .. os.clock())
local P = loadstring((src:gsub("local RUN = true", "local RUN = false")))()
local preview = workspace:FindFirstChild("_RosterPreviewCultivators")
if not preview then
	preview = Instance.new("Folder")
	preview.Name = "_RosterPreviewCultivators"
	preview:AddTag("EditorOnly")
	preview.Parent = workspace
end
local solo = preview:FindFirstChild("Solo")
if solo then
	solo:Destroy()
end
solo = Instance.new("Folder")
solo.Name = "Solo"
solo.Parent = preview
local plate = Instance.new("Part")
plate.Name = "Plate"
plate.Anchored = true
plate.Size = Vector3.new(16, 1, 16)
plate.CFrame = CFrame.new(600, 399.5, 3000)
plate.Color = Color3.fromHex("6E7F5A")
plate.Material = Enum.Material.SmoothPlastic
plate.Parent = solo
local copy, drift = P.place(NAME, CFrame.new(600, 400, 3000), POSE, solo)
return string.format("%s drift %.4f", copy:GetFullName(), drift)
