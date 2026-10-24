--!strict
-- Name step: the first name, nothing else (race and clan moved to the Fate
-- step, user 2026-10-23). The first name is the one required field of a new character, so Enter World
-- sits right under it in the footer. Once a slot is named the name is locked
-- (edit shows it read-only).
-- The first-character screen (Tabs/Begin) builds this field on its own page with
-- opts.generate: it starts on a drawn cultivator name (GivenNames) and a "New
-- name" button beside it draws another, so nobody has to type on a phone (user,
-- 2026-10-24). The name stays editable.

local Name = {}

-- quiet: no "You will be known as ..." line (the nameplate under the character
-- already shows the full name); only what needs fixing shows under the field
export type Options = { order: number?, generate: boolean?, heading: boolean?, quiet: boolean? }

function Name.build(page: ScrollingFrame, ctx: any, opts: Options?)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local rules = defs.Rules
	local base = if opts and opts.order then opts.order else 0
	local generate = opts ~= nil and opts.generate == true
	local quiet = opts ~= nil and opts.quiet == true
	local locked = false
	local drawn: string? = nil -- the last name drawn for the player
	local rolls = 0 -- "New name" presses since the field was reset

	if not (opts and opts.heading == false) then
		components.section(page, "First name", base + 1)
	end
	local field = components.textField(page, {
		name = "FirstNameField",
		placeholder = "Choose a first name",
		order = base + 2,
		counter = true,
		action = if generate then "New name" else nil,
	})
	local box: TextBox = field.input
	local max = rules.FIRST_NAME.MAX
	local function validate()
		local text = box.Text
		field.counter.Text = if locked then "" else `{utf8.len(text) or #text}/{max}`
		if locked then
			field.setStatus("A cultivator's name is set once.", "info")
			field.setNeed(false)
			return
		end
		if text:match("^%s*$") then
			field.setStatus(`Required: {rules.FIRST_NAME.MIN} to {max} letters.`, "need")
			field.setNeed(true)
			return
		end
		local name, why = rules.checkFirstName(text)
		if name then
			local family = defs.Surnames[ctx.player:GetAttribute("Surname") or ""]
			field.setStatus(if quiet then nil else `You will be known as {if family then family.DisplayName .. " " else ""}{name}.`, "ok")
			field.setNeed(false)
		else
			field.setStatus(why, "error")
			field.setNeed(true)
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if locked then
			return
		end
		local text = box.Text
		local length = utf8.len(text)
		if length and length > max then
			text = text:sub(1, (utf8.offset(text, max + 1) or (#text + 1)) - 1)
			box.Text = text
			return -- the change re-enters with the trimmed text
		end
		state:set("FirstName", text)
		validate()
	end)
	-- Enter World with the name missing brings the player here
	ctx.registerField("FirstName", function()
		page.CanvasPosition = Vector2.zero
		if not ctx.isTouch then
			box:CaptureFocus()
		end
	end)

	-- a cultivator name other than the one showing (GivenNames)
	local function draw()
		local list = defs.GivenNames
		local pick = list[math.random(1, #list)]
		if #list > 1 then
			while pick == box.Text do
				pick = list[math.random(1, #list)]
			end
		end
		drawn = pick
		box.Text = pick
	end
	if generate then
		field.action.Activated:Connect(function()
			if not locked then
				rolls += 1
				draw()
			end
		end)
	end

	-- "You will be known as Murong ..." follows a clan reroll on the Fate step
	ctx.onAttribute("Surname", validate)

	local handle = {}
	-- mode "new": an empty, required field (generate: a drawn name); "edit": the
	-- slot's name, locked
	function handle.reset(mode: string, firstName: string?)
		locked = mode == "edit"
		field.setLocked(locked)
		field.action.Visible = generate and not locked
		rolls = 0
		drawn = nil
		box.Text = if locked then firstName or "" else ""
		if generate and not locked then
			draw()
		end
		validate()
	end
	-- How the name was chosen, for the front-door analytics: "Kept" (the first
	-- drawn name), "Rolled" (a later draw), "Typed" (anything else).
	function handle.source(): string
		if drawn and box.Text == drawn then
			return if rolls == 0 then "Kept" else "Rolled"
		end
		return "Typed"
	end
	return handle
end

return Name
