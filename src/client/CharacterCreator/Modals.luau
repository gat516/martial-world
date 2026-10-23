--!strict
-- The two cards that open over the join screen, centred, with no dimming
-- behind them: the odds of every race and clan, and the delete confirm (hold
-- to delete; letting go early cancels).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Components)
local Defs = require(script.Parent.Defs)
local Theme = require(script.Parent.Theme)

local Modals = {}

local modal: Frame
local odds: ImageLabel
local confirm: ImageLabel
local holdFill: Frame
local holdLabel: TextLabel
local bodyLabel: TextLabel
local onHeld: (() -> (boolean, string?))? = nil
local holding: Tween? = nil
local working = false

local function show(card: ImageLabel?)
	modal.Visible = card ~= nil
	odds.Visible = card == odds
	confirm.Visible = card == confirm
	if card then
		local pop = card:FindFirstChild("Pop") :: UIScale?
		if not pop then
			local p = Instance.new("UIScale")
			p.Name = "Pop"
			p.Parent = card
			pop = p
		end
		local s = pop :: UIScale
		s.Scale = 0.96
		TweenService:Create(s, Theme.Tween.Page, { Scale = 1 }):Play()
	end
end

function Modals.close()
	if holding then
		holding:Cancel()
		holding = nil
	end
	onHeld = nil
	show(nil)
end

function Modals.isOpen(): boolean
	return modal.Visible
end

local function fillOdds()
	local list = odds:FindFirstChild("List") :: ScrollingFrame
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local order = 0
	for _, group in { { "Races", Defs.Races, "Race" }, { "Clans", Defs.Surnames, "Surname" } } do
		local title, defs, attribute = group[1], group[2] :: { [string]: any }, group[3]
		order += 1
		Components.section(list, title, order)
		local keys = {}
		for key in defs do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			if defs[a].Weight ~= defs[b].Weight then
				return defs[a].Weight < defs[b].Weight
			end
			return defs[a].DisplayName < defs[b].DisplayName
		end)
		local mine = Players.LocalPlayer:GetAttribute(attribute)
		for _, key in keys do
			order += 1
			local chance = Defs.Rules.chance(defs, key)
			local text = if chance >= 1 then `{math.floor(chance + 0.5)}%` else `{math.floor(chance * 10 + 0.5) / 10}%`
			local name = if key == mine then `{defs[key].DisplayName} (yours)` else defs[key].DisplayName
			Components.oddsRow(list, order, name, Defs.Rarities[defs[key].Rarity], text)
		end
	end
	-- after the rows have laid out (content size is in screen px, after the Fit scale)
	task.defer(function()
		local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		local fit = odds:FindFirstChild("Fit") :: UIScale
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / math.max(fit.Scale, 0.01) + 12)
	end)
end

function Modals.openOdds()
	(odds:FindFirstChild("Title") :: TextLabel).Text = "The odds"
	show(odds)
	fillOdds()
end

local function cancelHold()
	if holding then
		holding:Cancel()
		holding = nil
	end
	TweenService:Create(holdFill, Theme.Tween.Select, { Size = UDim2.fromScale(0, 1) }):Play()
end

-- Asks before deleting. `title`/`body` describe the slot; `run` deletes it and
-- returns (ok, message). The card stays open with the message if it fails.
function Modals.confirmDelete(title: string, body: string, run: () -> (boolean, string?))
	(confirm:FindFirstChild("Title") :: TextLabel).Text = title
	bodyLabel.Text = body
	bodyLabel.TextColor3 = Theme.Color.Muted
	holdLabel.Text = "Hold to delete"
	holdFill.Size = UDim2.fromScale(0, 1)
	onHeld = run
	working = false
	show(confirm)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.ButtonA
end

function Modals.init(root: Frame)
	modal = root:WaitForChild("Modal") :: Frame
	odds = modal:WaitForChild("Odds") :: ImageLabel
	confirm = modal:WaitForChild("Delete") :: ImageLabel
	bodyLabel = confirm:WaitForChild("Body") :: TextLabel
	local buttons = confirm:WaitForChild("Buttons") :: Frame
	local hold = buttons:WaitForChild("Hold") :: ImageButton
	holdFill = (hold:WaitForChild("Track") :: Frame):WaitForChild("Fill") :: Frame
	holdLabel = hold:WaitForChild("Label") :: TextLabel
	show(nil)

	;(odds:WaitForChild("Close") :: ImageButton).Activated:Connect(Modals.close)
	;(buttons:WaitForChild("Keep") :: ImageButton).Activated:Connect(Modals.close)

	hold.InputBegan:Connect(function(input)
		if not isPress(input) or working or not onHeld then
			return
		end
		cancelHold()
		holdFill.Size = UDim2.fromScale(0, 1)
		local tween = TweenService:Create(holdFill, TweenInfo.new(Theme.Tween.Hold, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1, 1),
		})
		holding = tween
		tween:Play()
		tween.Completed:Once(function(state)
			if state ~= Enum.PlaybackState.Completed or holding ~= tween then
				return
			end
			holding = nil
			working = true
			holdLabel.Text = "Deleting..."
			local run = onHeld
			local ok, message = false, "Try again"
			if run then
				ok, message = run()
			end
			working = false
			if ok then
				Modals.close()
			else
				holdLabel.Text = "Hold to delete"
				holdFill.Size = UDim2.fromScale(0, 1)
				bodyLabel.Text = message or "That didn't work. Try again."
				bodyLabel.TextColor3 = Theme.Color.Lacquer
			end
		end)
	end)
	local function release(input: InputObject)
		if holding and isPress(input) then
			cancelHold()
		end
	end
	hold.InputEnded:Connect(release)
	UserInputService.InputEnded:Connect(release)
end

return Modals
