--!strict
-- Party and player-interaction UI (StarterGui.Social, assets/Social.rbxmx, built by
-- tools/build_social.luau; contract in docs/systems/party.md):
--   the player card   tap another player's character (touch) or namecard, a People row
--                     or a party pip; the buttons follow the card's flags
--   People            everyone in the server, friends first (Social.openPeople, for the
--                     HUD's People tile shown in safe zones)
--   the invite prompt a small card under the top bar with a countdown, Accept / Decline
--   party pips        a tiny stack at the left edge: each member's name, a health sliver,
--                     the leader's seal, dimmed when not near; tap your own for Leave;
--                     the party shelter's marks (a jade shield on a sheltered member, the
--                     jade qi swirl on the one sheltering them; player attribute ShelteredBy)
--   friend toast      "<name> is on this mountain" through the HUD toast
-- Laid out at the phone baseline (844x390) and fitted by UiScale (max 1.3), like Sect.
--
--   Social.openCard(userId, fromPeople?)  Social.openPeople()  Social.togglePeople()
--   Social.preview()  sample card, people, invite and pips (client console in play):
--     require(game.Players.LocalPlayer.PlayerScripts.Client.Social).preview()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Hud = require(script.Parent.Hud)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local Nameplates = require(script.Parent.Nameplates)
local Platform = require(script.Parent.Platform)
local UiScale = require(script.Parent.UiScale)

local Social = {}

local player = Players.LocalPlayer

local BUTTON = {
	gold = "rbxassetid://89951515494594", -- sized/button_gold_h64
	jade = "rbxassetid://132904097543542", -- sized/button_jade_h64
	lacquer = "rbxassetid://70679462267599", -- sized/button_lacquer_h64
}
local CREAM = Color3.fromRGB(236, 232, 220)
local DARK = Color3.fromRGB(46, 28, 8) -- text on the gold button
local GOLD = Color3.fromRGB(226, 186, 104)
local MUTED = Color3.fromRGB(140, 136, 126)
local JADE = Color3.fromRGB(120, 214, 170)
local DANGER = Color3.fromRGB(236, 128, 112) -- Remove: the one action that undoes something
local MARK_HEX = "#78D6AA" -- JADE, for the card's rich-text marks
local ACTIONS_WIDTH = 392 -- the card's button row, baseline px
local ACTION_GAP = 8
local ACTION_MAX = 112
local LEAVE_SECONDS = 4 -- the Leave button beside your pip hides itself after this
local TAP_MAX_PIXELS = 12 -- as CombatController: further is a drag
local TAP_MAX_SECONDS = 0.35
local AVATAR_FOV = 30
local AVATAR_YAW = math.rad(-14)

type Invite = { from: number, name: string, realm: string?, partySize: number, expires: number, total: number }

local action: RemoteFunction
local canvas: Frame
local scale: UIScale
local card: Frame
local people: Frame
local invitePrompt: Frame
local pips: Frame
local refreshShelter: () -> ()
local leave: GuiButton
local templates: Frame

local cardUser: number? = nil
local cardFromPeople = false
local cardToken = 0
local party: any = nil
local invites: { Invite } = {}
local shownInvite: Invite? = nil
local leaveToken = 0
local ready = false

-- PartyAction, with the server's message as a toast (refusals, and "Invited X.").
local function call(name: string, arg: any?): (boolean, any)
	local ok, success, payload = pcall(action.InvokeServer, action, name, arg)
	if not ok then
		return false, nil
	end
	if type(payload) == "string" and payload ~= "" then
		Hud.toast(payload)
	end
	return success == true, payload
end

local function text(parent: Instance, name: string): TextLabel
	return parent:FindFirstChild(name, true) :: TextLabel
end

-- Card --------------------------------------------------------------------------------

local function renderAvatar(userId: number)
	local view = card:FindFirstChild("View", true) :: ViewportFrame?
	if not view then
		return
	end
	local world = view:FindFirstChildOfClass("WorldModel") :: WorldModel
	local camera = view:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera") -- a Camera inside a ViewportFrame doesn't survive the Rojo sync
		camera.FieldOfView = AVATAR_FOV
		camera.Parent = view
	end
	view.CurrentCamera = camera
	world:ClearAllChildren()
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ForceField") or d:IsA("LayerCollector") or d:IsA("ParticleEmitter") or d:IsA("Tool") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy:PivotTo(CFrame.new())
	copy.Parent = world
	local cf, size = copy:GetBoundingBox()
	local height = size.Y * 1.12
	local distance = (height / 2) / math.tan(math.rad(AVATAR_FOV / 2))
	local facing = CFrame.Angles(0, AVATAR_YAW, 0) * Vector3.new(0, 0, -1);
	(camera :: Camera).CFrame = CFrame.lookAt(cf.Position + facing * distance, cf.Position)
end

local function setRow(key: string, value: string, muted: boolean)
	local row = card:FindFirstChild(key, true) :: Frame
	local label = row:FindFirstChild("Value") :: TextLabel
	label.Text = value
	label.TextColor3 = if muted then MUTED else CREAM
end

local function partyLine(c: any): string
	local p = c.party or {}
	if not p.inParty then
		return "Travelling alone"
	elseif p.withYou then
		return if p.leader then "Leads your party" else "In your party"
	end
	return if p.leader then `Leads a party of {p.size}` else `In a party of {p.size}`
end

local renderCard: (c: any) -> ()

local function refreshCard()
	local userId = cardUser
	if not userId or not card.Visible then
		return
	end
	cardToken += 1
	local token = cardToken
	local ok, c = call("card", userId)
	if token ~= cardToken or not card.Visible then
		return
	end
	if ok and type(c) == "table" then
		renderCard(c)
	else
		Menus.close(card) -- they left
	end
end

local function addAction(row: Frame, order: number, caption: string, style: string, fn: () -> (), danger: boolean?)
	local b = (templates:FindFirstChild("ActionButton") :: ImageButton):Clone()
	b.Name = caption
	b.Image = BUTTON[style]
	b.LayoutOrder = order
	local label = b:FindFirstChild("Label") :: TextLabel
	label.Text = caption
	label.TextColor3 = if style == "gold" then DARK else CREAM
	label.TextStrokeTransparency = if style == "gold" then 1 else 0
	if danger then
		label.TextColor3 = DANGER
	end
	b.Activated:Connect(fn)
	b.Parent = row
end

renderCard = function(c: any)
	text(card, "PlayerName").Text = c.name or c.displayName or "";
	-- marks after the realm, in jade
	local marks = {}
	if c.friend then
		table.insert(marks, "Friend")
	end
	if c.party and c.party.withYou then
		table.insert(marks, "With you")
	end
	local realm = text(card, "Realm")
	local base = c.realm or ""
	realm.Text = if #marks > 0 then `{base}  <font color="{MARK_HEX}">· {table.concat(marks, " · ")}</font>` else base
	local race = c.raceName
	if race and c.variantName and c.variantName ~= "" then
		race = `{race} · {c.variantName}`
	end
	setRow("Race", race or "Not chosen yet", race == nil)
	setRow("Bloodline", c.bloodline or "None", c.bloodline == nil)
	setRow("Hall", c.hall or "No Hall", c.hall == nil)
	setRow("Party", partyLine(c), false)

	local row = card:FindFirstChild("Actions") :: Frame
	for _, b in row:GetChildren() do
		if b:IsA("GuiButton") then
			b:Destroy()
		end
	end
	local userId = c.userId
	local function act(name: string, after: (() -> ())?)
		return function()
			local ok = call(name, userId)
			if ok and after then
				after()
			else
				refreshCard()
			end
		end
	end
	local closeAll = function()
		Menus.close(card)
	end
	if c.invitedYou then
		addAction(row, 1, "Accept", "gold", act("accept"))
		addAction(row, 2, "Decline", "lacquer", act("decline"))
	elseif c.canInvite then
		addAction(row, 1, "Invite", "gold", act("invite"))
	end
	if c.canJoin then
		addAction(row, 3, "Travel to", "jade", act("join", closeAll)) -- the "join" ride, not joining the party
	end
	if c.canVisit then
		addAction(row, 4, "Visit peak", "jade", act("visit", closeAll))
	end
	if c.canKick then
		addAction(row, 5, "Make leader", "lacquer", act("promote"))
		addAction(row, 6, "Remove", "lacquer", act("kick"), true)
	end
	local buttons = {}
	for _, b in row:GetChildren() do
		if b:IsA("GuiButton") then
			table.insert(buttons, b)
		end
	end
	local n = #buttons
	local width = if n > 0 then math.min(ACTION_MAX, math.floor((ACTIONS_WIDTH - ACTION_GAP * (n - 1)) / n)) else ACTION_MAX
	for _, b in buttons do
		b.Size = UDim2.fromOffset(width, b.Size.Y.Offset)
		local label = b:FindFirstChild("Label") :: TextLabel
		label.TextSize = if width < ACTION_MAX then 14 else 15 -- four buttons share the row
	end
	row.Visible = n > 0
end

function Social.openCard(userId: number, fromPeople: boolean?)
	if not ready or userId == player.UserId then
		return
	end
	cardToken += 1
	local token = cardToken
	local ok, c = call("card", userId)
	if token ~= cardToken or not ok or type(c) ~= "table" then
		return
	end
	cardUser = userId
	cardFromPeople = fromPeople == true
	renderCard(c)
	renderAvatar(userId)
	Menus.open(card)
end

-- People ------------------------------------------------------------------------------

local peopleToken = 0

local function renderPeople(rows: { any })
	local list = people:FindFirstChild("List") :: ScrollingFrame
	for _, r in list:GetChildren() do
		if r:IsA("GuiButton") then
			r:Destroy()
		end
	end
	for i, p in rows do
		local r = (templates:FindFirstChild("PersonRow") :: ImageButton):Clone()
		r.Size = UDim2.new(1, 0, 0, r.Size.Y.Offset)
		r.LayoutOrder = i
		text(r, "PlayerName").Text = p.name or "";
		text(r, "Sub").Text = if p.raceName then `{p.realm or ""} · {p.raceName}` else (p.realm or "")
		local mark = text(r, "Mark")
		local parts = {}
		if p.friend then
			table.insert(parts, "Friend")
		end
		if p.withYou then
			table.insert(parts, "With you")
		elseif p.inParty then
			table.insert(parts, "In a party")
		end
		mark.Text = table.concat(parts, " · ")
		mark.TextColor3 = if p.withYou then GOLD elseif p.friend then JADE else MUTED
		local userId = p.userId
		r.Activated:Connect(function()
			Social.openCard(userId, true)
		end)
		r.Parent = list
	end
	(people:FindFirstChild("Empty") :: GuiObject).Visible = #rows == 0
	list.CanvasPosition = Vector2.zero
end

local function refreshPeople()
	peopleToken += 1
	local token = peopleToken
	local ok, rows = call("people")
	if token == peopleToken and ok and type(rows) == "table" then
		renderPeople(rows)
	end
end

function Social.openPeople()
	if not ready then
		return
	end
	Menus.open(people)
	refreshPeople()
end

function Social.togglePeople()
	if people and people.Visible then
		Menus.close(people)
	else
		Social.openPeople()
	end
end

-- Invite prompt -----------------------------------------------------------------------

local function nextInvite()
	local now = workspace:GetServerTimeNow()
	for i = #invites, 1, -1 do
		if invites[i].expires <= now then
			table.remove(invites, i)
		end
	end
	local invite = invites[1]
	shownInvite = invite
	if not invite then
		if invitePrompt.Visible then
			Motion.close(invitePrompt)
		end
		return
	end
	text(invitePrompt, "Message").Text = `{invite.name} invites you to travel together`
	local size = if invite.partySize > 1 then ` · party of {invite.partySize}` else ""
	text(invitePrompt, "Sub").Text = `{invite.realm or ""}{size}`
	if not invitePrompt.Visible then
		Motion.open(invitePrompt)
	end
end

local function dropInvite(from: number)
	for i, invite in invites do
		if invite.from == from then
			table.remove(invites, i)
			break
		end
	end
	nextInvite()
end

local function addInvite(view: any)
	if type(view) ~= "table" or type(view.from) ~= "number" then
		return
	end
	for i, invite in invites do
		if invite.from == view.from then
			table.remove(invites, i)
			break
		end
	end
	local remaining = math.max(1, (tonumber(view.expires) or 0) - workspace:GetServerTimeNow())
	table.insert(invites, {
		from = view.from,
		name = tostring(view.name or ""),
		realm = view.realm,
		partySize = tonumber(view.partySize) or 1,
		expires = tonumber(view.expires) or 0,
		total = math.max(remaining, 30),
	})
	nextInvite()
end

local function tickInvite()
	local invite = shownInvite
	if not invite or not invitePrompt.Visible then
		return
	end
	local left = invite.expires - workspace:GetServerTimeNow()
	if left <= 0 then
		dropInvite(invite.from)
		return
	end
	text(invitePrompt, "Seconds").Text = `{math.ceil(left)}s`
	local fill = (invitePrompt:FindFirstChild("Timer") :: Frame):FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(math.clamp(left / invite.total, 0, 1), 1)
end

-- Party pips --------------------------------------------------------------------------

local function hideLeave()
	leaveToken += 1
	leave.Visible = false
end

local function showLeave(row: GuiObject)
	leaveToken += 1
	local token = leaveToken
	local k = math.max(scale.Scale, 0.01)
	local at = (row.AbsolutePosition - canvas.AbsolutePosition) / k
	-- under the row, over the pips below it (it hides again in a few seconds); beside it
	-- it would reach the invite prompt and the vitals
	leave.Position = UDim2.fromOffset(at.X + 20, at.Y + row.AbsoluteSize.Y / k + 4)
	Motion.open(leave)
	task.delay(LEAVE_SECONDS, function()
		if leaveToken == token then
			hideLeave()
		end
	end)
end

local function updatePipsShown()
	local any = party ~= nil and #party.members > 1
	pips.Visible = any and not Menus.isOpen() and not Menus.isCalm()
	if not pips.Visible then
		hideLeave()
	end
end

local rowsByUser: { [number]: GuiButton } = {}

-- The party shelter on the pips (docs/systems/combat.md "Realm pressure"): a jade
-- shield on a member a stronger one shelters, the jade qi swirl on that patron. From
-- each member's ShelteredBy attribute (the patron's UserId; Social.preview's members
-- carry `shelteredBy` instead).
local NAME_WIDTH = UDim2.new(1, -36, 0, 16) -- PlayerName as authored
local NAME_WIDTH_MARKED = UDim2.new(1, -52, 0, 16) -- clear of the mark

local function shelteredBy(m: any): number?
	if type(m.shelteredBy) == "number" then
		return m.shelteredBy
	end
	local other = Players:GetPlayerByUserId(m.userId)
	local id = other and other:GetAttribute("ShelteredBy")
	return if type(id) == "number" then id else nil
end

refreshShelter = function()
	local members = if party then party.members else {}
	local patrons: { [number]: boolean } = {}
	local sheltered: { [number]: boolean } = {}
	for _, m in members do
		local id = shelteredBy(m)
		if id then
			sheltered[m.userId] = true
			patrons[id] = true
		end
	end
	for userId, row in rowsByUser do
		local band = row:FindFirstChild("Band") :: ImageLabel
		local shield = band:FindFirstChild("Sheltered") :: GuiObject?
		local swirl = band:FindFirstChild("Patron") :: GuiObject?
		local isSheltered, isPatron = sheltered[userId] == true, patrons[userId] == true and not sheltered[userId]
		if shield then
			shield.Visible = isSheltered
		end
		if swirl then
			swirl.Visible = isPatron
		end
		(band:FindFirstChild("PlayerName") :: GuiObject).Size = if isSheltered or isPatron then NAME_WIDTH_MARKED else NAME_WIDTH
	end
end

local function renderPips(snap: any)
	party = if type(snap) == "table" and type(snap.members) == "table" then snap else nil
	local seen = {}
	if party then
		for i, m in party.members do
			local row = rowsByUser[m.userId]
			if not row then
				local fresh = (templates:FindFirstChild("PipRow") :: TextButton):Clone()
				local userId, isSelf = m.userId, m.self == true
				fresh.Activated:Connect(function()
					if isSelf then
						if leave.Visible then
							hideLeave()
						else
							showLeave(fresh)
						end
					else
						hideLeave()
						Social.openCard(userId)
					end
				end)
				fresh.Parent = pips
				rowsByUser[userId] = fresh
				row = fresh
			end
			local r = row :: GuiButton
			seen[m.userId] = true
			r.LayoutOrder = i
			local band = r:FindFirstChild("Band") :: ImageLabel
			local name = band:FindFirstChild("PlayerName") :: TextLabel
			name.Text = if m.self then "You" else tostring(m.name or "")
			local near = m.near ~= false
			band.ImageTransparency = if near then 0 else 0.5
			name.TextTransparency = if near then 0 else 0.45
			name.TextStrokeTransparency = if near then 0 else 0.6
			local fill = (band:FindFirstChild("Health") :: Frame):FindFirstChild("Fill") :: Frame
			fill.BackgroundTransparency = if near then 0 else 0.5
			Motion.ease(fill, { Size = UDim2.fromScale(math.clamp(tonumber(m.health) or 0, 0, 1), 1) });
			(r:FindFirstChild("Leader") :: GuiObject).Visible = m.leader == true
		end
	end
	for userId, row in rowsByUser do
		if not seen[userId] then
			row:Destroy()
			rowsByUser[userId] = nil
		end
	end
	refreshShelter()
	updatePipsShown()
end

-- Tapping another player --------------------------------------------------------------

local function playerAt(position: Vector3): Player?
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, camera }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	while model do
		local other = Players:GetPlayerFromCharacter(model)
		if other then
			return other
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Touch only: a tap on a character (a mouse click there is a Strike).
local function bindCharacterTaps()
	local starts: { [InputObject]: { at: number, position: Vector3 } } = {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.Touch then
			starts[input] = { at = os.clock(), position = input.Position }
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local start = starts[input]
		starts[input] = nil
		if not start or Menus.isOpen() or os.clock() - start.at > TAP_MAX_SECONDS then
			return
		end
		if (input.Position - start.position).Magnitude > TAP_MAX_PIXELS then
			return
		end
		local other = playerAt(input.Position)
		if other and other ~= player then
			Social.openCard(other.UserId)
		end
	end)
end

-- Init --------------------------------------------------------------------------------

local function bindWindow(window: Frame, onClose: () -> ())
	Menus.register(window);
	(window:FindFirstChild("Close") :: GuiButton).Activated:Connect(onClose)
end

function Social.init()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("Social") :: ScreenGui
	canvas = gui:WaitForChild("Canvas") :: Frame
	scale = UiScale.fit(canvas, { base = UiScale.PHONE, max = 1.3 })
	card = canvas:WaitForChild("Card") :: Frame
	people = canvas:WaitForChild("People") :: Frame
	invitePrompt = canvas:WaitForChild("Invite") :: Frame
	pips = canvas:WaitForChild("Pips") :: Frame
	leave = canvas:WaitForChild("Leave") :: GuiButton
	templates = canvas:WaitForChild("Templates") :: Frame
	-- the authored samples go; the script fills everything
	for _, list in { pips, people:FindFirstChild("List") :: Instance } do
		for _, child in list:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
	end
	card.Visible, people.Visible, invitePrompt.Visible, pips.Visible, leave.Visible = false, false, false, false, false
	Motion.buttons(canvas)

	bindWindow(card, function()
		if cardFromPeople then
			Social.openPeople() -- back to the list it came from
		else
			Menus.close(card)
		end
	end)
	bindWindow(people, function()
		Menus.close(people)
	end)
	Menus.onChanged(updatePipsShown)
	-- the shelter marks follow every player's ShelteredBy
	local function watchShelter(other: Player)
		other:GetAttributeChangedSignal("ShelteredBy"):Connect(refreshShelter)
	end
	for _, other in Players:GetPlayers() do
		watchShelter(other)
	end
	Players.PlayerAdded:Connect(watchShelter)
	-- rows size the list's canvas (AutomaticCanvasSize misses them; docs/systems/ui.md)
	local list = people:FindFirstChild("List") :: ScrollingFrame
	local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	local function fitCanvas()
		-- (it settles once the window's open pop ends at scale 1)
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y / math.max(scale.Scale, 0.01))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)
	scale:GetPropertyChangedSignal("Scale"):Connect(fitCanvas)

	local buttons = invitePrompt:FindFirstChild("Buttons") :: Frame
	(buttons:FindFirstChild("Accept") :: GuiButton).Activated:Connect(function()
		local invite = shownInvite
		if invite then
			call("accept", invite.from)
			dropInvite(invite.from)
		end
	end);
	(buttons:FindFirstChild("Decline") :: GuiButton).Activated:Connect(function()
		local invite = shownInvite
		if invite then
			call("decline", invite.from)
			dropInvite(invite.from)
		end
	end)
	leave.Activated:Connect(function()
		hideLeave()
		call("leave")
	end)
	RunService.Heartbeat:Connect(tickInvite)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	action = remotes:WaitForChild("PartyAction") :: RemoteFunction
	local state = remotes:WaitForChild("PartyState") :: RemoteEvent
	state.OnClientEvent:Connect(function(kind: string, payload: any, reason: any)
		if kind == "party" then
			renderPips(payload)
			if card.Visible then
				task.spawn(refreshCard)
			end
		elseif kind == "invite" then
			addInvite(payload)
		elseif kind == "inviteGone" then
			dropInvite(tonumber(payload) or 0)
		elseif kind == "friendHere" and type(payload) == "table" then
			Hud.toast(`{payload.name} is on this mountain`)
		end
	end)
	-- the list follows arrivals and departures while it's open
	local function peopleChanged()
		if people.Visible then
			task.delay(1, refreshPeople) -- the newcomer's profile loads first
		end
	end
	Players.PlayerAdded:Connect(peopleChanged)
	Players.PlayerRemoving:Connect(peopleChanged)

	Nameplates.onTap = function(other: Player)
		Social.openCard(other.UserId)
	end
	if Platform.isTouch() then
		bindCharacterTaps()
	end
	ready = true

	-- restore an open party and pending invites (a respawn or a late load)
	task.spawn(function()
		for _ = 1, 10 do
			local ok, success, payload = pcall(action.InvokeServer, action, "state")
			if ok and success == true and type(payload) == "table" then
				renderPips(payload.party)
				for _, invite in payload.invites or {} do
					addInvite(invite)
				end
				return
			end
			task.wait(2) -- "Still loading"
		end
	end)
end

-- Sample everything (client console in play): a card, the list, an invite and pips.
function Social.preview()
	renderCard({
		userId = 0,
		name = "Li Wei",
		realm = "Qi Condensation 3",
		raceName = "Beast Folk",
		variantName = "Wolf",
		friend = true,
		party = { inParty = true, size = 2, leader = true, withYou = true },
		canJoin = true,
		canVisit = true,
		canKick = true,
	})
	cardUser = nil
	Menus.open(card)
	addInvite({ from = -1, name = "Han Yue", realm = "Qi Condensation 5", partySize = 2, expires = workspace:GetServerTimeNow() + 30 })
	renderPips({
		members = {
			{ userId = -2, name = "Li Wei", health = 0.8, leader = true, near = true },
			{ userId = player.UserId, name = "You", health = 1, near = true, self = true, shelteredBy = -2 },
			{ userId = -3, name = "Mo Lan", health = 0.35, near = false },
		},
	})
end

return Social
