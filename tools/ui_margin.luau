--!nocheck
-- Studio half of tools/ui_margin.py (Edit mode; a sandbox, or a staging copy in a
-- Rojo-connected place). Run the generated table first (it sets _G.UIMARGIN:
-- old id -> { new, l, t, r, b }, the new copy's clear margin on each side as a share
-- of its art), then this file. For every ImageLabel/ImageButton under StarterGui and
-- ReplicatedStorage ScreenGuis showing an old id, it swaps in the new id and grows
-- the element by the margin so the art stays exactly where it was:
--   Size' = Size * f (f = 1 + l + r across, 1 + t + b down), Position moved by the
--   left/top margin and the anchor, an aspect constraint's ratio times fx/fy, a size
--   constraint's limits times f; its GuiObject children keep their place (scale
--   parts divided by f, plus the margin's share).
-- An element in a UIListLayout/UIGridLayout, or with a layout of its own, can't be
-- grown in place without moving its neighbours: it is listed, not changed.
-- Returns a report. Previews (names starting with "_") are skipped.

local map = _G.UIMARGIN or error("run the generated UIMARGIN table first")
local roots = {}
for _, parent in ipairs({ game:GetService("StarterGui"), game:GetService("ReplicatedStorage") }) do
	for _, g in ipairs(parent:GetChildren()) do
		if g:IsA("ScreenGui") and string.sub(g.Name, 1, 1) ~= "_" then
			table.insert(roots, g)
		end
	end
end

local function hasLayout(o)
	return o:FindFirstChildWhichIsA("UIListLayout") ~= nil or o:FindFirstChildWhichIsA("UIGridLayout") ~= nil
end

-- UDim offsets are whole pixels (Roblox truncates toward zero): round them
local function px(v)
	return math.floor(v + 0.5)
end

local function scaleU(u, f)
	return UDim.new(u.Scale * f, px(u.Offset * f))
end

local changed, manual = {}, {}
for _, root in ipairs(roots) do
	for _, o in ipairs(root:GetDescendants()) do
		if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" then
			local id = string.match(o.Image, "%d+$")
			local e = id and map["rbxassetid://" .. id]
			if e then
				if o.ScaleType == Enum.ScaleType.Slice then
					table.insert(manual, o:GetFullName() .. " (9-sliced: left as is)")
					continue
				end
				local inLayout = o.Parent and hasLayout(o.Parent)
				if inLayout or hasLayout(o) then
					o.Image = e.new
					table.insert(manual, o:GetFullName() .. (if inLayout then " (in a layout)" else " (has a layout)"))
					continue
				end
				local fx, fy = 1 + e.l + e.r, 1 + e.t + e.b
				local s, p, a = o.Size, o.Position, o.AnchorPoint
				local sx, sy = s.X, s.Y
				o.Size = UDim2.new(scaleU(sx, fx), scaleU(sy, fy))
				-- P' = P + S * (anchor * (f - 1) - leftMargin)
				local kx, ky = a.X * (fx - 1) - e.l, a.Y * (fy - 1) - e.t
				o.Position = UDim2.new(p.X.Scale + sx.Scale * kx, px(p.X.Offset + sx.Offset * kx), p.Y.Scale + sy.Scale * ky, px(p.Y.Offset + sy.Offset * ky))
				for _, c in ipairs(o:GetChildren()) do
					if c:IsA("UIAspectRatioConstraint") then
						c.AspectRatio = c.AspectRatio * fx / fy
					elseif c:IsA("UISizeConstraint") then
						local function lim(v, f)
							return if v == math.huge then v else v * f
						end
						c.MinSize = Vector2.new(lim(c.MinSize.X, fx), lim(c.MinSize.Y, fy))
						c.MaxSize = Vector2.new(lim(c.MaxSize.X, fx), lim(c.MaxSize.Y, fy))
					elseif c:IsA("GuiObject") then
						local cs, cp = c.Size, c.Position
						c.Size = UDim2.new(cs.X.Scale / fx, cs.X.Offset, cs.Y.Scale / fy, cs.Y.Offset)
						c.Position = UDim2.new((cp.X.Scale + e.l) / fx, cp.X.Offset, (cp.Y.Scale + e.t) / fy, cp.Y.Offset)
					elseif c:IsA("UIPadding") then
						c.PaddingLeft = UDim.new(c.PaddingLeft.Scale / fx, c.PaddingLeft.Offset)
						c.PaddingRight = UDim.new(c.PaddingRight.Scale / fx, c.PaddingRight.Offset)
						c.PaddingTop = UDim.new(c.PaddingTop.Scale / fy, c.PaddingTop.Offset)
						c.PaddingBottom = UDim.new(c.PaddingBottom.Scale / fy, c.PaddingBottom.Offset)
					end
				end
				o.Image = e.new
				table.insert(changed, o:GetFullName())
			end
		end
	end
end
return ("ui_margin: %d grown in place; %d need a hand fix:\n%s"):format(#changed, #manual, table.concat(manual, "\n"))
