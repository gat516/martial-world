--!strict
-- The character's full name on the front band of the jade pedestal, under the
-- preview (Root.Preview.NamePlate): the last name the server rolled, then the
-- first name, typed in place (user, 2026-10-23). Same rules as before
-- (Rules.checkFirstName, Rules.FIRST_NAME), a counter while typing, a status line
-- under the band, and state "FirstName", which the Confirm tab reads.
-- Layout: Preview.NamePlate { Fit (UIScale, set by Controller.fit), FullName
-- { Surname, First { Input, Line } }, Counter, Status }.

local NamePlate = {}

local box: TextBox? = nil

function NamePlate.build(plate: Frame, ctx: any)
	local defs, theme, state = ctx.defs, ctx.theme, ctx.state
	local rules = defs.Rules
	local name = plate:FindFirstChild("FullName") :: Frame
	local surname = name:FindFirstChild("Surname") :: TextLabel
	local first = name:FindFirstChild("First") :: Frame
	local input = first:FindFirstChild("Input") :: TextBox
	local line = first:FindFirstChild("Line") :: Frame
	local counter = plate:FindFirstChild("Counter") :: TextLabel
	local status = plate:FindFirstChild("Status") :: TextLabel
	box = input
	local max = rules.FIRST_NAME.MAX

	ctx.onAttribute("Surname", function(key: string?)
		local def = key and defs.Surnames[key]
		surname.Text = if def then def.DisplayName else ""
		surname.Visible = def ~= nil
	end)

	local function validate()
		local text = input.Text
		counter.Text = `{utf8.len(text) or #text}/{max}`
		if text:match("^%s*$") then
			status.Text = `Type your first name ({rules.FIRST_NAME.MIN} to {max} letters).`
			status.TextColor3 = theme.Color.Cream
			return
		end
		local ok, why = rules.checkFirstName(text)
		if ok then
			status.Text = ""
		else
			status.Text = why
			status.TextColor3 = Color3.fromRGB(240, 140, 120)
		end
	end
	input:GetPropertyChangedSignal("Text"):Connect(function()
		local text = input.Text
		local length = utf8.len(text)
		if length and length > max then
			input.Text = text:sub(1, (utf8.offset(text, max + 1) or (#text + 1)) - 1)
			return -- the change re-enters with the trimmed text
		end
		state:set("FirstName", text)
		validate()
	end)
	-- the counter and the underline brighten while typing
	input.Focused:Connect(function()
		counter.Visible = true
		line.BackgroundColor3 = theme.Color.GoldBright
	end)
	input.FocusLost:Connect(function()
		counter.Visible = false
		line.BackgroundColor3 = theme.Color.GoldDim
	end)
	counter.Visible = false
	validate()
end

-- Puts the cursor in the first name (Confirm's blocker sends the player here).
function NamePlate.focus()
	if box then
		box:CaptureFocus()
	end
end

return NamePlate
