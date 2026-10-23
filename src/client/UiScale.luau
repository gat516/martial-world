--!strict
-- Baseline scaling for new screens (docs/ui/overhaul-plan.md, "Resolution and
-- scaling"). A screen is laid out once at a baseline resolution, desktop
-- 1920x1080 or phone landscape 844x390, inside one authored canvas, and this
-- fits that canvas to the real screen with one authored UIScale.
--
-- Authoring (in Studio, in the screen's .rbxmx):
--   ScreenGui
--     Canvas (Frame, transparent, AnchorPoint 0.5,0.5, Position 0.5,0.5, Size 1,0,1,0)
--       UiScale (UIScale, Scale 1)
--       ...everything else, laid out as if the screen were the baseline size
--          (scale units or offsets; anchor to edges as usual)
-- In Edit view at the baseline size the canvas is the screen, so what you see
-- is what players see. A screen with a phone layout authors it as its own
-- subtree (e.g. Canvas.Desktop and Canvas.Phone) and shows one by
-- UiScale.isPhone(); the phone layout carries its own text-size floor.
--
-- At runtime UiScale.fit(canvas) sets scale = min(width / baseW, height / baseH)
-- (clamped) and sizes the canvas to the screen in baseline units, so it fills
-- the screen at any aspect: edges stay edges, the centre stays the centre, and
-- one baseline pixel is `scale` real pixels. It refits when the screen resizes.
-- Per-frame Motion UIScales inside the canvas multiply on top.

local UiScale = {}

UiScale.DESKTOP = Vector2.new(1920, 1080)
UiScale.PHONE = Vector2.new(844, 390)

export type Options = {
	base: Vector2?, -- the baseline to fit (default: PHONE on a phone, else DESKTOP)
	min: number?, -- clamp (default 0.4)
	max: number?, -- clamp (default 1.5)
}

local phone: boolean? = nil

-- Whether this session uses the phone layouts: a screen whose short side is under
-- 600 px, whatever the input (the Studio device emulator reports a mouse and
-- keyboard, so a touch check gave it the desktop layout squeezed to the 0.4 clamp:
-- tiny text in a box that covered the screen). Decided once, like
-- Platform.isTouch(); an unsized viewport (before the first frame) isn't cached.
function UiScale.isPhone(): boolean
	if phone == nil then
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.zero
		if math.min(view.X, view.Y) <= 2 then
			return false
		end
		phone = math.min(view.X, view.Y) < 600
	end
	return phone :: boolean
end

-- The baseline this session's screens are laid out at.
function UiScale.base(): Vector2
	return if UiScale.isPhone() then UiScale.PHONE else UiScale.DESKTOP
end

-- Fit an authored canvas (see the header) to its parent's size, now and on
-- every resize. Returns the canvas's UIScale (its Scale is the current factor).
function UiScale.fit(canvas: GuiObject, options: Options?): UIScale
	local scale = canvas:FindFirstChild("UiScale")
	assert(scale and scale:IsA("UIScale"), `UiScale.fit: {canvas:GetFullName()} has no UiScale UIScale`)
	local parent = canvas.Parent
	assert(parent and parent:IsA("GuiBase2d"), `UiScale.fit: {canvas:GetFullName()} isn't under a GUI`)
	local opts: Options = options or {}
	local base = opts.base or UiScale.base()
	local lo, hi = opts.min or 0.4, opts.max or 1.5
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)

	local function apply()
		local size = parent.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local s = math.clamp(math.min(size.X / base.X, size.Y / base.Y), lo, hi)
		scale.Scale = s
		canvas.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()
	return scale
end

return UiScale
