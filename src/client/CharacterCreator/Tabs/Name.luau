--!strict
-- Name step: the first name, nothing else (race and clan moved to the Fate
-- step, user 2026-10-23). The first name is the one required field of a new character, so Enter World
-- sits right under it in the footer. Once a slot is named the name is locked
-- (edit shows it read-only).

local Name = {}

function Name.build(page: ScrollingFrame, ctx: any)
	local state, defs, components = ctx.state, ctx.defs, ctx.components
	local rules = defs.Rules
	local locked = false

	components.section(page, "First name", 1)
	local field = components.textField(page, {
		name = "FirstNameField",
		placeholder = "Choose a first name",
		order = 2,
		counter = true,
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
			field.setStatus(`You will be known as {if family then family.DisplayName .. " " else ""}{name}.`, "ok")
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

	-- "You will be known as Murong ..." follows a clan reroll on the Fate step
	ctx.onAttribute("Surname", validate)

	local handle = {}
	-- mode "new": an empty, required field; "edit": the slot's name, locked
	function handle.reset(mode: string, firstName: string?)
		locked = mode == "edit"
		field.setLocked(locked)
		box.Text = if locked then firstName or "" else ""
		validate()
	end
	return handle
end

return Name
