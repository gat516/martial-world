--!strict
-- Cultivation seat: M or the Cultivate tile (top right) sits the character down
-- to meditate (idle, safe to leave running).
-- Seated is a calm screen with only what you can do there: the meditation menu,
-- one row of tiles above the vitals (Stack.CultivatePrompt) that appear only when
-- they matter: Circulate (an active minigame, played seated; when the realm bar
-- is full it gives way to Break Through), Method (once you own one), Spirit Root
-- (once tested; a seal dot while a reformed element waits for a choice),
-- Practice, and Rise.
-- Practice (shown while either of its actions exists; a seal dot while a
-- technique is at a bottleneck) swaps the row for its own tiles (user decision,
-- 2026-10-21): Technique (comprehend a technique at a bottleneck, in the
-- MeditationMenu panel), Weapon Dao (a weapon drill for Dao XP, from
-- Pacing.DaoPractice.FROM until the class is mastered; a countdown while
-- resting; the character gets up for the drill, still locked in place and still
-- meditating, swings the weapon's chain one strike per tap, and sits back down
-- after) and Back. An action that isn't available shows dimmed and toasts why.
-- The main row comes back after a drill or the panel, on Back, and on standing.
-- Technique, Method and Spirit Root open a small panel (MeditationMenu).
-- The calm view: the lotus toggle (Stack.CalmToggle) folds the tiles away and
-- fades the rest of the HUD (Menus.setCalm) to just watch the world; it also
-- comes on by itself after CALM_AFTER seconds without input. A tap anywhere, a
-- key, the lotus again, or standing up brings everything back. Passive
-- cultivation runs either way.
-- The touch combat cluster hides while seated; the tile reads "Rise". The vitals
-- step aside for the cultivation bars (SeatBars: realm, progress to the next
-- breakthrough and past it, the dantian), via Menus.setSeated.
-- Seated, the character is locked in place: no walking, jumping, or turning to
-- follow the camera in shift lock (Movement.luau holds the facing). Getting up:
-- Rise, the tile, or M. Taking damage knocks you straight out of it (no get-up
-- animation), and the server (Meditation.luau) can end it too. Plays Animations.Meditate: Sit once, Loop
-- while seated, GetUp to stand. Where you sit sets the passive multiplier; a
-- toast says what it is whenever it changes.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Pacing = require(ReplicatedStorage.Shared.Pacing)
local Realms = require(ReplicatedStorage.Shared.Realms)
local Weapons = require(ReplicatedStorage.Shared.Weapons)

local BreakthroughView = require(script.Parent.BreakthroughView)
local CirculationMinigame = require(script.Parent.CirculationMinigame)
local Controls = require(script.Parent.Controls)
local Guide = require(script.Parent.Guide)
local Hud = require(script.Parent.Hud)
local Layout = require(script.Parent.Layout)
local MeditationMenu = require(script.Parent.MeditationMenu)
local Menus = require(script.Parent.Menus)
local Motion = require(script.Parent.Motion)
local SelfCard = require(script.Parent.SelfCard)
local State = require(script.Parent.State)

local remote = ReplicatedStorage.Remotes.Meditate :: RemoteEvent
local animations = (ReplicatedStorage:WaitForChild("Animations") :: Folder):WaitForChild("Meditate") :: Folder
local player = Players.LocalPlayer

local BLEND = 0.2 -- seconds each animation fades into the next
local CALM_AFTER = 20 -- seconds seated without input before the HUD fades by itself
local TAP_DRIFT = 12 -- px a press may move and still be a tap (more is a camera drag)
local TAP_SECONDS = 0.4 -- a longer press isn't a tap either
local CALM_ICON = 0.55 -- the lotus's transparency while the view is calm
local RESTING = 0.5 -- a Practice-row tile's transparency while resting or unavailable
local LOTUS_GAP = 22 -- px from the last tile's edge to the lotus (the row's own tile gap)

local Meditation = {}

type Phase = "idle" | "sitting" | "seated" | "rising"
local phase: Phase = "idle"
local token = 0 -- bumped on every sit and stand, so stale callbacks do nothing
local tracks: { [string]: AnimationTrack } = {}
local animator: Animator? = nil
local strikes: { [string]: { AnimationTrack } } = {} -- a class's chain steps, loaded on first drill
local strikeStep = 0
local button: TextButton
local row: Frame -- Stack.CultivatePrompt: the seated tiles
local calmToggle: ImageButton -- Stack.CalmToggle: the lotus
local wasCalm = false
local practiceRow = false -- the Practice tiles show instead of the main row
local lastInput = os.clock()

local function barFull(): boolean
	local value, max = player:GetAttribute("Cultivation") or 0, player:GetAttribute("CultivationMax") or 0
	return max > 0 and value >= max
end

local function tile(name: string): GuiObject
	return row:FindFirstChild(name) :: GuiObject
end

-- Practice Dao: the equipped class, and whether the tile belongs on the row
-- (reached Pacing.DaoPractice.FROM and that class isn't mastered yet).
local function practiceClass(): string
	local weapons = State.current.weapons
	return Weapons.classOf(if weapons and weapons.equipped ~= "" then weapons.equipped else nil)
end

local function daoOpen(): boolean
	local from = Realms.ByKey[Pacing.DaoPractice.FROM]
	local stage = Realms.byName(player:GetAttribute("Realm"))
	if not (from and stage) or Realms.index(stage.major, stage.minor) < Realms.index(from.major, from.minor) then
		return false
	end
	local dao = State.current.dao
	local entry = dao and dao[practiceClass()]
	return (if entry then entry.level else 0) < Weapons.MAX_LEVEL
end

-- Seconds until the next drill (0 = ready).
local function practiceWait(): number
	return math.max(0, (State.current.daoPracticeReady or 0) - os.time())
end

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function techniqueReady(): boolean
	return MeditationMenu.relevant().Comprehend == true
end

local function dim(t: GuiObject, dimmed: boolean)
	(t:FindFirstChild("Icon") :: ImageLabel).ImageTransparency = if dimmed then RESTING else 0;
	(t:FindFirstChild("Frame") :: ImageLabel).ImageTransparency = if dimmed then RESTING else 0
end

-- The Weapon Dao tile's caption is its countdown while resting; dimmed while
-- resting or locked. The Technique tile is dimmed with nothing to comprehend.
local function paintPractice()
	local t = tile("PracticeDao")
	local wait = practiceWait()
	local resting = daoOpen() and wait > 0;
	(t:FindFirstChild("Caption") :: TextLabel).Text = if resting then clock(wait) else "Weapon Dao"
	dim(t, resting or not daoOpen())
	dim(tile("PracticeTechnique"), not techniqueReady())
end

-- The lotus sits just past the row's last tile (Rise), whichever tiles show.
-- It keeps its spot while the calm view folds the row away, so the same tap
-- brings the row back. Offsets are in the stack's units: the row's own pop
-- scale is divided out.
local function placeLotus()
	if not row.Visible or Menus.isCalm() then
		return
	end
	local stack = row.Parent :: GuiObject
	local unscaled = stack.AbsoluteSize.X * row.Size.X.Scale
	if unscaled <= 0 then
		return
	end
	local factor = row.AbsoluteSize.X / unscaled
	local width = (row:FindFirstChildOfClass("UIListLayout") :: UIListLayout).AbsoluteContentSize.X / factor
	calmToggle.Position = UDim2.new(0.5, math.round(width / 2 + LOTUS_GAP), calmToggle.Position.Y.Scale, calmToggle.Position.Y.Offset)
end

local function refresh()
	local active = phase ~= "idle"
	local seated = phase == "sitting" or phase == "seated"
	local caption = button:FindFirstChild("Caption") :: TextLabel
	caption.Text = if active then "Rise" else "Cultivate"
	local trim = button:FindFirstChild("Trim") :: UIStroke
	trim.Thickness = if active then 2.5 else 1.2
	trim.Transparency = if active then 0 else 0.45
	local calm = Menus.isCalm()
	local open = Menus.isOpen()
	Motion.setShown(row, seated and not open and not calm, calm ~= wasCalm)
	wasCalm = calm
	-- a full bar has nothing to circulate into; Break Through shows instead
	local full = barFull()
	local relevant = MeditationMenu.relevant()
	local anyPractice = relevant.Comprehend == true or daoOpen()
	if not (seated and anyPractice) then
		practiceRow = false
	end
	local main = not practiceRow
	tile("Circulate").Visible = main and not full
	tile("Breakthrough").Visible = main and full
	for _, page in { "Method", "Root" } do
		tile(page).Visible = main and relevant[page] == true
	end
	(tile("Root"):FindFirstChild("Badge") :: GuiObject).Visible = MeditationMenu.rootPending()
	tile("Practice").Visible = main and anyPractice;
	(tile("Practice"):FindFirstChild("Badge") :: GuiObject).Visible = relevant.Comprehend == true
	tile("Rise").Visible = main
	for _, name in { "PracticeTechnique", "PracticeDao", "Back" } do
		tile(name).Visible = practiceRow
	end
	paintPractice()
	local root = SelfCard.currentRoot()
	if root then
		(tile("Root"):FindFirstChild("Icon") :: ImageLabel).Image = SelfCard.rootIcon(root.element)
	end
	calmToggle.Visible = seated and not open
	placeLotus()
	calmToggle.ImageTransparency = if calm then CALM_ICON else 0;
	(calmToggle:FindFirstChild("Icon") :: ImageLabel).ImageTransparency = if calm then CALM_ICON else 0
	Layout.showCluster(not active)
	Menus.setSeated(seated)
end

-- Call fn BLEND seconds before a non-looped track ends, so the next pose fades in
-- under it instead of snapping back to idle for a frame.
local function nearEnd(track: AnimationTrack, fn: () -> ())
	task.spawn(function()
		local waited = 0
		while track.Length == 0 and waited < 2 do
			waited += task.wait()
		end
		task.wait(math.max(0, track.Length - BLEND))
		fn()
	end)
end

function Meditation.isActive(): boolean
	return phase ~= "idle"
end

function Meditation.sit()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if phase ~= "idle" or not humanoid or humanoid.Health <= 0 or not tracks.Sit then
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	phase = "sitting"
	lastInput = os.clock()
	token += 1
	local mine = token
	remote:FireServer(true)
	Controls.lock("Meditation")
	tracks.Sit:Play(BLEND)
	nearEnd(tracks.Sit, function()
		if token == mine then
			phase = "seated"
			tracks.Loop:Play(BLEND)
		end
	end)
	refresh()
end

-- `fromServer`: the server already ended the session, so don't tell it again.
-- `abrupt`: knocked out of it (hit); skip the get-up animation.
function Meditation.stand(fromServer: boolean?, abrupt: boolean?)
	if phase == "idle" or (phase == "rising" and not abrupt) then
		return
	end
	token += 1
	local mine = token
	Menus.setCalm(false)
	MeditationMenu.close()
	if not fromServer and phase ~= "rising" then
		remote:FireServer(false)
	end
	tracks.Sit:Stop(BLEND)
	tracks.Loop:Stop(BLEND)
	if abrupt then
		tracks.GetUp:Stop(BLEND)
		phase = "idle"
		Controls.unlock("Meditation")
		refresh()
		return
	end
	phase = "rising"
	-- still locked from sitting: hold still through the get-up too
	tracks.GetUp:Play(BLEND)
	nearEnd(tracks.GetUp, function()
		if token == mine then
			phase = "idle"
			Controls.unlock("Meditation")
			refresh()
		end
	end)
	refresh()
end

-- Circulate from the seat; the tiles come back when the run ends.
local function circulate()
	Motion.setShown(row, false)
	CirculationMinigame.start()
	refresh()
end

-- The equipped class's chain (Animations.Weapons.<Class>/1..n, Fists for bare
-- hands), loaded once per character.
local function strikeTracks(class: string): { AnimationTrack }
	local list = strikes[class]
	if list or not animator then
		return list or {}
	end
	list = {}
	local root = ReplicatedStorage:WaitForChild("Animations")
	local step = 1
	while true do
		local path = string.split(Weapons.clip(class, step), "/")
		local found: Instance? = root
		for _, name in path do
			found = found and found:FindFirstChild(name)
		end
		if not (found and found:IsA("Animation")) then
			break
		end
		local track = (animator :: Animator):LoadAnimation(found)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		table.insert(list, track)
		step += 1
	end
	strikes[class] = list
	return list
end

-- Practice Dao from the seat; resting tells how long instead of asking the server.
-- Once the server starts the drill the character gets up (still meditating and
-- locked in place, weapon in hand), strikes on every tap, and sits back down.
local function practice()
	local wait = practiceWait()
	if wait > 0 then
		Hud.toast(`Rest your arms a while ({clock(wait)}).`)
		return
	end
	Motion.setShown(row, false)
	local mine = token
	local stood = false
	CirculationMinigame.practice({
		begin = function()
			if token ~= mine then
				return
			end
			stood = true
			strikeStep = 0
			Controls.lock("Meditation", true)
			tracks.Sit:Stop(BLEND)
			tracks.Loop:Stop(BLEND)
			tracks.GetUp:Play(BLEND)
		end,
		strike = function()
			local list = strikeTracks(practiceClass())
			if token ~= mine or #list == 0 then
				return
			end
			tracks.GetUp:Stop(0.1)
			strikeStep = strikeStep % #list + 1
			list[strikeStep]:Play(0.05)
		end,
	})
	practiceRow = false
	if stood and token == mine then
		-- back down onto the seat
		Controls.lock("Meditation")
		phase = "sitting"
		tracks.GetUp:Stop(BLEND)
		tracks.Sit:Play(BLEND)
		nearEnd(tracks.Sit, function()
			if token == mine then
				phase = "seated"
				tracks.Loop:Play(BLEND)
			end
		end)
	end
	refresh()
end

-- Swap the seated row between its main tiles and the Practice tiles, with a
-- small pop.
local function showPractice(on: boolean)
	if practiceRow == on then
		return
	end
	practiceRow = on
	lastInput = os.clock()
	refresh()
	if row.Visible then
		Motion.open(row)
	end
end

-- M and the tile: sit down to meditate, or stand straight back up.
function Meditation.toggle()
	if phase == "idle" then
		Meditation.sit()
	elseif not CirculationMinigame.isRunning() then
		Meditation.stand()
	end
end

local function onCharacter(character: Model)
	table.clear(tracks)
	table.clear(strikes)
	token += 1
	phase = "idle"
	Controls.unlock("Meditation")
	refresh()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local mine = humanoid:WaitForChild("Animator") :: Animator
	animator = mine
	for _, name in { "Sit", "Loop", "GetUp" } do
		local track = mine:LoadAnimation(animations:FindFirstChild(name) :: Animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = name == "Loop"
		tracks[name] = track
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last then
			Meditation.stand(false, true)
		end
		last = health
	end)
end

-- The calm view's clock and its way back: any input restarts the idle clock; a
-- key, or a tap that isn't a camera drag (and didn't land on our GUI), ends it.
local function watchInput()
	local presses: { [InputObject]: { at: number, pos: Vector3 } } = {}
	local function pointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		lastInput = os.clock()
		if pointer(input) then
			if not processed then
				presses[input] = { at = os.clock(), pos = input.Position }
			end
		elseif not processed and Menus.isCalm() and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType.Name:match("^Gamepad")) then
			Menus.setCalm(false)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.MouseWheel or kind == Enum.UserInputType.Touch
			or (kind.Name:match("^Gamepad") and input.Position.Magnitude > 0.2) then
			lastInput = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local press = presses[input]
		presses[input] = nil
		if press and Menus.isCalm() and os.clock() - press.at <= TAP_SECONDS and (input.Position - press.pos).Magnitude <= TAP_DRIFT then
			Menus.setCalm(false)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			-- never fade away a tile the onboarding guide is spotlighting
			if phase == "seated" and not Menus.isOpen() and not Menus.isCalm() and not CirculationMinigame.isRunning()
				and not Guide.spotlit() and os.clock() - lastInput >= CALM_AFTER then
				Menus.setCalm(true)
			end
		end
	end)
end

function Meditation.init(gui: ScreenGui)
	button = (gui:FindFirstChild("Buttons") :: Frame):FindFirstChild("CultivateButton") :: TextButton
	button.Activated:Connect(Meditation.toggle)
	local stack = gui:FindFirstChild("Stack") :: Frame
	row = stack:FindFirstChild("CultivatePrompt") :: Frame
	calmToggle = stack:FindFirstChild("CalmToggle") :: ImageButton
	local actions: { [string]: () -> () } = {
		Circulate = function()
			task.spawn(circulate)
		end,
		Breakthrough = function()
			task.spawn(BreakthroughView.attempt)
		end,
		Practice = function()
			showPractice(true)
		end,
		Back = function()
			showPractice(false)
		end,
		PracticeTechnique = function()
			if not techniqueReady() then
				Hud.toast("No technique is at a bottleneck yet.")
				return
			end
			practiceRow = false -- the panel hides the row; the main row comes back after
			MeditationMenu.toggle("Comprehend")
		end,
		Method = function()
			MeditationMenu.toggle("Method")
		end,
		Root = function()
			MeditationMenu.toggle("Root")
		end,
		PracticeDao = function()
			if daoOpen() then
				task.spawn(practice)
				return
			end
			local from = Realms.ByKey[Pacing.DaoPractice.FROM]
			local class = Weapons.Classes[practiceClass()]
			local stage = Realms.byName(player:GetAttribute("Realm"))
			if from and stage and Realms.index(stage.major, stage.minor) < Realms.index(from.major, from.minor) then
				Hud.toast(`Weapon Dao practice opens at {from.name}.`)
			else
				Hud.toast(`Your {if class then class.dao else "weapon Dao"} is mastered.`)
			end
		end,
		Rise = function()
			Meditation.stand()
		end,
	}
	for name, fn in actions do
		(row:FindFirstChild(name) :: GuiButton).Activated:Connect(fn)
	end
	(row:FindFirstChildOfClass("UIListLayout") :: UIListLayout):GetPropertyChangedSignal("AbsoluteContentSize"):Connect(placeLotus)
	calmToggle.Activated:Connect(function()
		lastInput = os.clock()
		Menus.setCalm(not Menus.isCalm())
	end)
	watchInput()
	ContextActionService:BindAction("Meditate", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			Meditation.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M)

	Menus.onChanged(refresh)
	player:GetAttributeChangedSignal("Cultivation"):Connect(refresh)
	player:GetAttributeChangedSignal("CultivationMax"):Connect(refresh)
	player:GetAttributeChangedSignal("Root"):Connect(refresh)
	player:GetAttributeChangedSignal("Realm"):Connect(refresh)
	-- the Practice countdown ticks while seated
	task.spawn(function()
		while true do
			task.wait(1)
			if phase ~= "idle" then
				paintPractice()
			end
		end
	end)
	State.onChanged(function()
		refresh()
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	remote.OnClientEvent:Connect(function(on: boolean)
		if not on then
			Meditation.stand(true)
		end
	end)

	local shown: number? = nil
	State.onChanged(function(s)
		local spot = s.meditation
		local multiplier = spot and spot.multiplier
		if spot and multiplier ~= shown then
			local where = if spot.place ~= "" then ` {spot.place}` else ""
			Hud.toast(`Meditating{where}: passive cultivation ×{spot.multiplier}`)
		end
		shown = multiplier
	end)
end

return Meditation
