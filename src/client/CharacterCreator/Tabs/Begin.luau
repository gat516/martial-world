--!strict
-- The first-character screen (user, 2026-10-24: "the front door"): one page for a
-- new character instead of four steps. The free Fate reveal comes first (the
-- race the server drew with its rarity, the clan, the odds link; the race's
-- free looks wait for Edit look), then the name, already filled with a drawn cultivator name the
-- player can keep, redraw or type over, and the big Enter World in the footer.
-- The look starts on the preset (the ranger outfit, the avatar's own skin and
-- hair; Appearance and Hair are built but not shown); "Edit look" changes it
-- later (Controller.editLook, from the slot screen or in the world).
-- The rows are the Fate and Name steps' own (Tabs/Fate, Tabs/Name), built here
-- with an order offset, so both screens behave the same.

local Fate = require(script.Parent.Fate)
local NameTab = require(script.Parent:FindFirstChild("Name") :: ModuleScript)

local Begin = {}

function Begin.build(page: ScrollingFrame, ctx: any)
	-- the race and clan rows and the odds link; the race's free looks wait for
	-- Edit look (the Fate step), so the page fits a phone without scrolling
	-- (critic, 2026-10-24: each rarity beside its value, in its colour, at the
	-- value's size, so the draw is the hero, not the field labels)
	local fate = Fate.build(page, ctx, { order = 0, note = false, looks = false, inline = true })
	-- the odds link reads as a link and is a 44 px tap target
	fate.link.RichText = true
	fate.link.Text = "<u>See the odds of every race and clan</u>"
	fate.link.Size = UDim2.new(1, 0, 0, 44)
	-- the drawn race is the one value that stands out (critic, round 2)
	local raceValue = page:FindFirstChild("RaceRow") and (page :: any).RaceRow.Row:FindFirstChild("Value")
	if raceValue and raceValue:IsA("TextLabel") then
		raceValue.TextSize = 24
	end
	-- no heading and no "You will be known as" line: the nameplate under the
	-- character shows the full name as it changes
	local name = NameTab.build(page, ctx, { order = 100, generate = true, heading = false, quiet = true })

	local handle = {}
	function handle.reset()
		fate.reset()
		name.reset("new", nil)
	end
	handle.source = name.source
	return handle
end

return Begin
