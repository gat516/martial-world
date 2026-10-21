--!strict
-- Cultivation seat: M or the Cultivate tile (top right) sits the character down
-- to meditate (idle, safe to leave running).
-- Seated is a calm screen with only what you can do there: the meditation menu,
-- one row of tiles above the vitals (Stack.CultivatePrompt) that appear only when
-- they matter: Circulate (an active minigame, played seated; when the realm bar
-- is full it gives way to Break Through), Comprehend (a technique at a
-- bottleneck), Method (once you own one), Spirit Root (once tested; a seal dot
-- while a reformed element waits for a choice), Practise (a weapon drill for
-- Dao XP, from Pacing.DaoPractice.FROM until the class is mastered; dimmed with
-- a countdown while resting), and Rise.
-- Comprehend, Method and Spirit Root open a small panel (MeditationMenu).
-- The calm view: the lotus toggle (Stack.CalmToggle) folds the tiles away and
-- fades the rest of the HUD (Menus.setCalm) to just watch the world; it also
-- comes on by itself after CALM_AFTER seconds without input. A tap anywhere, a
-- key, the lotus again, or standing up brings everything back. Passive
-- cultivation runs either way.
-- The touch combat cluster hides while seated; the tile reads "Rise".
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
local RESTING = 0.5 -- the Practise tile's transparency while the drill is on cooldown

local Meditation = {}

type Phase = "idle" | "sitting" | "seated" | "rising"
local phase: Phase = "idle"
local token = 0 -- bumped on every sit and stand, so stale callbacks do nothing
local tracks: { [string]: AnimationTrack } = {}
local button: TextButton
local row: Frame -- Stack.CultivatePrompt: the seated tiles
local calmToggle: ImageButton -- Stack.CalmToggle: the lotus
local wasCalm = false
local lastInput = os.clock()

local function barFull(): boolean
	local value, max = player:GetAttribute("Cultivation") or 0, player:GetAttribute("CultivationMax") or 0
	return max > 0 and value >= max
end

local function tile(name: string): GuiObject
	return row:FindFirstChild(name) :: GuiObject
end

-- Practise Dao: the equipped class, and whether the tile belongs on the row
-- (reached Pacing.DaoPractice.FROM and that class isn't mastered yet).
local function practiceClass(): string
	local weapons = State.current.weapons
	return Weapons.classOf(if weapons and weapons.equipped ~= "" then weapons.equipped else nil)
end

local function practiceOpen(): boolean
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

-- The tile's caption is its countdown while resting; dimmed until the drill opens.
local function paintPractise()
	local t = tile("Practise")
	local wait = practiceWait()
	local resting = wait > 0;
	(t:FindFirstChild("Caption") :: TextLabel).Text = if resting then clock(wait) else "Practise";
	(t:FindFirstChild("Icon") :: ImageLabel).ImageTransparency = if resting then RESTING else 0;
	(t:FindFirstChild("Frame") :: ImageLabel).ImageTransparency = if resting then RESTING else 0
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
	tile("Circulate").Visible = not full
	tile("Breakthrough").Visible = full
	local relevant = MeditationMenu.relevant()
	for _, page in { "Comprehend", "Method", "Root" } do
		tile(page).Visible = relevant[page] == true
	end
	(tile("Root"):FindFirstChild("Badge") :: GuiObject).Visible = MeditationMenu.rootPending()
	tile("Practise").Visible = practiceOpen()
	paintPractise()
	local root = SelfCard.currentRoot()
	if root then
		(tile("Root"):FindFirstChild("Icon") :: ImageLabel).Image = SelfCard.rootIcon(root.element)
	end
	calmToggle.Visible = seated and not open
	calmToggle.ImageTransparency = if calm then CALM_ICON else 0;
	(calmToggle:FindFirstChild("Icon") :: ImageLabel).ImageTransparency = if calm then CALM_ICON else 0
	Layout.showCluster(not active)
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

-- Practise Dao from the seat; resting tells how long instead of asking the server.
local function practise()
	local wait = practiceWait()
	if wait > 0 then
		Hud.toast(`Rest your arms a while ({clock(wait)}).`)
		return
	end
	Motion.setShown(row, false)
	CirculationMinigame.practise()
	refresh()
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
	token += 1
	phase = "idle"
	Controls.unlock("Meditation")
	refresh()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	for _, name in { "Sit", "Loop", "GetUp" } do
		local track = animator:LoadAnimation(animations:FindFirstChild(name) :: Animation)
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
		Comprehend = function()
			MeditationMenu.toggle("Comprehend")
		end,
		Method = function()
			MeditationMenu.toggle("Method")
		end,
		Root = function()
			MeditationMenu.toggle("Root")
		end,
		Practise = function()
			task.spawn(practise)
		end,
		Rise = function()
			Meditation.stand()
		end,
	}
	for name, fn in actions do
		(row:FindFirstChild(name) :: GuiButton).Activated:Connect(fn)
	end
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
	-- the Practise countdown ticks while seated
	task.spawn(function()
		while true do
			task.wait(1)
			if phase ~= "idle" then
				paintPractise()
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
