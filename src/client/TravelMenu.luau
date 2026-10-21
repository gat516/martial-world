--!strict
-- The teleport formation menu, once the elder has taught the formation. Two ways
-- in: the Travel button, shown anywhere on the sect's safe ground (so a gardener
-- can hop between their peak and the main peak from wherever they are), and a
-- Travel prompt on every teleport array (Hud.TravelPrompt, cloned onto each
-- TravelGate-tagged array), the only way to travel out in the wilds. The menu
-- closes when you leave both. Every button under the menu's List named after a
-- gate id travels there (List.Sect and List.Wilds group them); the array you're
-- standing on hides its own button. Each button has a Label (the name), a
-- Detail line and a Seal: realm-gated arrays show the realm they open at, and
-- while the player's realm is short of it the button greys out under a cinnabar
-- seal and a tap only says why. The wilds arrays also grey out (no seal) unless
-- you stand on the Sect Gate's array or a wilds array (Gates.leadsOut): you
-- leave the sect through its gate. A trip fades the screen out (Veil), travels,
-- and fades back in at the destination.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gates = require(ReplicatedStorage.Shared.Gates)
local Realms = require(ReplicatedStorage.Shared.Realms)
local GateMarkers = require(script.Parent.GateMarkers)
local Hud = require(script.Parent.Hud)
local ListWindow = require(script.Parent.ListWindow)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local MyPeak = require(script.Parent.MyPeak)
local Veil = require(script.Parent.Veil)

local remote = ReplicatedStorage.Remotes.TravelAction :: RemoteFunction
local player = Players.LocalPlayer

local CHECK_SECONDS = 0.25
local INVOKE_TIMEOUT = 10 -- give up waiting on the server after this (the veil lifts)
local SETTLE_SECONDS = 0.2 -- stay dark a moment after arriving so the ground draws

local OPEN = {
	art = Color3.new(1, 1, 1),
	label = Color3.fromRGB(250, 240, 220),
	detail = Color3.fromRGB(150, 225, 170),
}
local LOCKED = {
	art = Color3.fromRGB(115, 115, 115),
	label = Color3.fromRGB(190, 182, 168),
	detail = Color3.fromRGB(255, 140, 115),
}
local AWAY = { -- a wilds array while you're not at the Sect Gate
	art = Color3.fromRGB(115, 115, 115),
	label = Color3.fromRGB(190, 182, 168),
	detail = Color3.fromRGB(205, 195, 175),
}
local AWAY_TEXT = "From the Sect Gate"
local AWAY_TOAST = "Take the formation to the Sect Gate first; the wilds arrays answer only from there."

local TravelMenu = {}

local taught = false
local busy = false
local out = false -- standing on an array that leads into the wilds (Gates.leadsOut)

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The array the character stands on and its gate id. Someone else's peak array
-- counts as an array but not as "Peak" (that one still takes you home).
local function standingOn(root: BasePart): (Instance?, string?)
	for _, tagged in CollectionService:GetTagged(Gates.TAG) do
		if Gates.on(tagged, root.Position) then
			local id = tagged:GetAttribute("Gate")
			if id == "Peak" and not MyPeak.owns(tagged.Parent) then
				return tagged, nil
			end
			return tagged, if typeof(id) == "string" then id else nil
		end
	end
	return nil, nil
end

-- The part a prompt or marker hangs on: the arrays are Models or a bare part.
local function coreOf(array: Instance): BasePart?
	if array:IsA("BasePart") then
		return array
	end
	return (array :: Model).PrimaryPart or array:FindFirstChildWhichIsA("BasePart", true)
end

-- What an array's prompt calls it: its gate's name, or "Teleport Array" for
-- someone else's peak and the leave-only arrays (Gate ids not in Gates.List).
local function arrayName(array: Instance): string
	local id = array:GetAttribute("Gate")
	local gate = if typeof(id) == "string" then Gates.ById[id] else nil
	if not gate or (gate.id == "Peak" and not MyPeak.owns(array.Parent)) then
		return "Teleport Array"
	end
	return gate.name
end

local function myStage(): Realms.Stage
	return Realms.byName(player:GetAttribute("Realm")) or Realms.Stages[1]
end

-- Onboarding calls this with the server's word on whether travel is taught.
function TravelMenu.setTaught(on: boolean)
	taught = on
	GateMarkers.setTaught(on)
end

-- Fade out, ask the server to travel, fade back in. The veil lifts on every
-- path: a refusal, an error, a server that never answers (and its own timer).
local function travel(window: Frame, gate: Gates.Gate)
	if busy then
		return
	end
	busy = true
	Menus.close(window)
	local cover = Veil.cover(gate.name)
	local done, ok, message = false, false, nil :: string?
	task.spawn(function()
		local called, result, text = pcall(remote.InvokeServer, remote, gate.id)
		if called then
			ok, message = result == true, if type(text) == "string" then text else nil
		else
			message = "The formation flickers out. Try again."
		end
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < INVOKE_TIMEOUT do
		task.wait()
	end
	if ok then
		task.wait(SETTLE_SECONDS)
		Veil.reveal(cover)
	else
		Veil.reveal(cover, true)
		if message then
			Hud.toast(message)
		end
	end
	busy = false
end

function TravelMenu.init(gui: ScreenGui)
	local window = gui:FindFirstChild("TravelMenu") :: Frame
	Menus.register(window)
	ListWindow.bindClose(window)
	GateMarkers.init(gui)
	local button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("TravelButton") :: TextButton
	button.Visible = false
	button.Activated:Connect(function()
		Menus.toggle(window)
	end)

	-- a Travel prompt on every array; arrays stream in and out, so follow the tag
	local promptTemplate = gui:FindFirstChild("TravelPrompt") :: ProximityPrompt
	local prompts: { [Instance]: ProximityPrompt } = {}
	local function addPrompt(array: Instance)
		local core = coreOf(array)
		if prompts[array] or not core then
			return
		end
		local prompt = promptTemplate:Clone()
		prompt.ObjectText = arrayName(array)
		prompt.Enabled = false -- the check loop turns it on once taught
		prompt.Parent = core
		prompt.Triggered:Connect(function()
			if not busy then
				Menus.open(window)
			end
		end)
		prompts[array] = prompt
	end
	for _, array in CollectionService:GetTagged(Gates.TAG) do
		addPrompt(array)
	end
	CollectionService:GetInstanceAddedSignal(Gates.TAG):Connect(function(array)
		task.defer(addPrompt, array) -- after the streamed model's parts are in
	end)
	CollectionService:GetInstanceRemovedSignal(Gates.TAG):Connect(function(array)
		local prompt = prompts[array]
		prompts[array] = nil
		if prompt then
			prompt:Destroy()
		end
	end)
	player:GetAttributeChangedSignal("Peak"):Connect(function()
		for array, prompt in prompts do
			prompt.ObjectText = arrayName(array)
		end
	end)

	local list = window:FindFirstChild("List") :: Frame
	local buttons: { [string]: ImageButton } = {}
	for _, gate in Gates.List do
		local destination = list:FindFirstChild(gate.id, true) :: ImageButton?
		if destination then
			buttons[gate.id] = destination
			destination.Activated:Connect(function()
				local need = Gates.required(gate)
				if need and not Gates.open(gate, myStage()) then
					Motion.tap(destination)
					Hud.toast(`The {gate.name} array opens at {need.name}.`)
					return
				end
				if Gates.wild(gate) and not out then
					Motion.tap(destination)
					Hud.toast(AWAY_TOAST)
					return
				end
				task.spawn(travel, window, gate)
			end)
		end
	end

	-- realm-gated buttons: the realm each opens at, locked while short of it;
	-- open ones still grey out away from the Sect Gate
	local function refreshLocks()
		local stage = myStage()
		for id, destination in buttons do
			local gate = Gates.ById[id]
			local need = Gates.required(gate)
			if need then
				local open = Gates.open(gate, stage)
				local away = open and Gates.wild(gate) and not out
				local look = if not open then LOCKED elseif away then AWAY else OPEN
				destination.ImageColor3 = look.art;
				(destination:FindFirstChild("Label") :: TextLabel).TextColor3 = look.label
				local detail = destination:FindFirstChild("Detail") :: TextLabel
				detail.Text = if not open then `Opens at {need.name}` elseif away then AWAY_TEXT else need.name
				detail.TextColor3 = look.detail;
				(destination:FindFirstChild("Seal") :: GuiObject).Visible = not open
			end
		end
	end
	refreshLocks()
	player:GetAttributeChangedSignal("Realm"):Connect(refreshLocks)

	task.spawn(function()
		while true do
			local array, here, inSect = nil, nil, false
			local root = rootPart()
			if taught and root then
				array, here = standingOn(root)
				inSect = Gates.inSect(root.Position)
			end
			button.Visible = inSect
			if not (array or inSect) and window.Visible then
				Menus.close(window)
			end
			for _, prompt in prompts do
				prompt.Enabled = taught and not window.Visible
			end
			local leadsOut = array ~= nil and Gates.leadsOut(array:GetAttribute("Gate"))
			if leadsOut ~= out then
				out = leadsOut
				refreshLocks()
			end
			for id, destination in buttons do
				destination.Visible = id ~= here
			end
			GateMarkers.setHere(array)
			task.wait(CHECK_SECONDS)
		end
	end)
end

return TravelMenu
