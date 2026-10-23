--!strict
-- The secret-realm rift card (ready to wire; rifts don't exist yet, roadmap 9
-- "Secret realms"). A centred card in the Events screen: the rift's name, its
-- recommended realm, its modifiers as violet tags, the daily first-clear bonus
-- and an Enter button, with a close seal. docs/ui/world-events.md, "Rifts".
--
-- API:
--   RiftCard.show({
--     name = "Sunken Bamboo Grotto",
--     realm = "Qi Condensation 6"?,             -- recommended realm, shown as is
--     modifiers = { "Frenzied beasts", ... },   -- up to 4, in order; keep each short (~20 chars)
--     bonus = "First clear today: double rewards"?,
--     enter = "Enter the Rift"?,                -- the button's label
--     onEnter = function() end?,                -- pressed Enter (the card closes)
--   })
--   RiftCard.close(), RiftCard.isOpen()
--   RiftCard.preview()  sample card (client console in play)

local Menus = require(script.Parent.Parent.Menus)
local Gui = require(script.Parent.Gui)

local MAX_MODIFIERS = 4 -- the tag list's room (each tag is 0.23 of it)

export type Data = {
	name: string,
	realm: string?,
	modifiers: { string }?,
	bonus: string?,
	enter: string?,
	onEnter: (() -> ())?,
}

local RiftCard = {}

local card: ImageLabel? = nil
local onEnter: (() -> ())? = nil

local function build(): ImageLabel
	if card then
		return card
	end
	local c = Gui.place("RiftCard", "Rift") :: ImageLabel
	c.Visible = false
	Menus.register(c);
	(c:FindFirstChild("Close") :: ImageButton).Activated:Connect(function()
		Menus.close(c)
	end);
	(c:FindFirstChild("Enter") :: ImageButton).Activated:Connect(function()
		local fn = onEnter
		Menus.close(c)
		if fn then
			fn()
		end
	end)
	card = c
	return c
end

function RiftCard.show(data: Data)
	local c = build()
	onEnter = data.onEnter;
	(c:FindFirstChild("Title") :: TextLabel).Text = data.name
	local realm = c:FindFirstChild("Realm") :: TextLabel
	realm.Visible = data.realm ~= nil
	realm.Text = if data.realm then `Recommended: {data.realm}` else ""
	local bonus = c:FindFirstChild("Bonus") :: TextLabel
	bonus.Visible = data.bonus ~= nil
	bonus.Text = data.bonus or ""
	local enter = c:FindFirstChild("Enter") :: ImageButton
	local mid = (enter:FindFirstChild("Art") :: Frame):FindFirstChild("Mid") :: ImageLabel;
	(mid:FindFirstChild("Label") :: TextLabel).Text = data.enter or "Enter the Rift"
	local list = c:FindFirstChild("Modifiers") :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local mods = data.modifiers or {}
	for i = 1, math.min(#mods, MAX_MODIFIERS) do
		local tag = Gui.clone("RiftTag") :: Frame
		tag.Name = `Tag{i}`
		tag.LayoutOrder = i;
		(((tag:FindFirstChild("Art") :: Frame):FindFirstChild("Mid") :: ImageLabel):FindFirstChild("Label") :: TextLabel).Text = mods[i]
		tag.Parent = list
	end
	(c:FindFirstChild("ModsKicker") :: TextLabel).Visible = #mods > 0
	Menus.open(c)
end

function RiftCard.close()
	if card then
		Menus.close(card)
	end
end

function RiftCard.isOpen(): boolean
	return card ~= nil and Menus.isOpen(card)
end

function RiftCard.preview()
	RiftCard.show({
		name = "Sunken Bamboo Grotto",
		realm = "Qi Condensation 6",
		modifiers = { "Frenzied beasts", "Herbs grow thick", "No healing pills" },
		bonus = "First clear today: double rewards",
		onEnter = function()
			print("RiftCard.preview: Enter pressed")
		end,
	})
end

return RiftCard
