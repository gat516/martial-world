--!strict
-- The character screen's only line to the server: ReplicatedStorage.Remotes.
-- CharacterAction (src/server/CharacterIdentity.luau). Every call returns
-- (ok, payload | message) and never throws.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bridge = {}

-- Runs after a successful Enter World with the confirmed look. Append functions
-- here to hook the rest of the game in (saving, onboarding, ...).
Bridge.onEnterWorld = {} :: { (look: { [string]: any }) -> () }

local remote: RemoteFunction? = nil
local function action(): RemoteFunction
	if not remote then
		remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CharacterAction") :: RemoteFunction
	end
	return remote :: RemoteFunction
end

local function invoke(name: string, arg: any?): (boolean, any)
	local ok, success, payload = pcall(function()
		return action():InvokeServer(name, arg)
	end)
	if not ok then
		return false, "Couldn't reach the sect. Try again."
	end
	return success == true, payload
end

-- { products = { Race = { price, live }, Surname = {...} }, mock }
function Bridge.getState(): (boolean, any)
	return invoke("state")
end

local templates: { [number]: string }? = nil
-- catalog id -> Shirt/Pants template image, fetched once.
function Bridge.fetchTemplates(): { [number]: string }
	if templates then
		return templates
	end
	local ok, payload = invoke("templates")
	if ok and type(payload) == "table" then
		templates = payload
		return payload
	end
	return {}
end

-- Asks the server to load a hair accessory by catalog id. Returns (true, a copy
-- of the Accessory to preview) or (false, a message to show).
function Bridge.loadHair(id: number): (boolean, any)
	local ok, payload = invoke("hair", id)
	if ok and typeof(payload) == "Instance" and payload:IsA("Accessory") then
		return true, payload
	end
	return false, if type(payload) == "string" then payload else "That hair couldn't be loaded"
end

-- The player's own avatar as a starting look: (true, { skin: Color3?, hairs =
-- { { id, accessory } } }) or (false, message).
function Bridge.getDefaults(): (boolean, any)
	local ok, payload = invoke("defaults")
	if ok and type(payload) == "table" and type(payload.hairs) == "table" then
		return true, payload
	end
	return false, payload
end

-- A paid reroll of "Race" or "Surname". Returns:
--   "prompted", productId  the purchase prompt is up; the attribute changes if bought
--   "rolled", key          a mock reroll (Studio/testbed) already happened
--   "error", message
function Bridge.requestReroll(kind: string): (string, any)
	local ok, payload = invoke("reroll", kind)
	if not ok then
		return "error", if type(payload) == "string" then payload else "Not available"
	end
	if type(payload) == "table" and payload.productId then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, payload.productId)
		return "prompted", payload.productId
	elseif type(payload) == "table" and payload.rolled then
		return "rolled", payload.rolled
	end
	return "error", "Not available"
end

-- Save slots (src/server/Slots.luau). Each returns (ok, payload | message).
-- { slots = { Summary }, max, canSave, last, playing }
function Bridge.slots(): (boolean, any)
	return invoke("slots")
end

-- Opens the creator on an empty (or unnamed) slot; the server draws or shows its
-- race and clan as the player's attributes. { id, mode = "new", progress }
function Bridge.newSlot(id: string): (boolean, any)
	return invoke("new", id)
end

-- Opens the creator on a named slot's look: { id, mode = "edit", look, firstName }
function Bridge.editSlot(id: string): (boolean, any)
	return invoke("edit", id)
end

function Bridge.cancel(): (boolean, any)
	return invoke("cancel")
end

function Bridge.play(id: string): (boolean, any)
	return invoke("play", id)
end

-- { token } for the hold-to-delete
function Bridge.deleteAsk(id: string): (boolean, any)
	return invoke("deleteAsk", id)
end

function Bridge.delete(id: string, token: string, name: string): (boolean, any)
	return invoke("delete", { id = id, token = token, name = name })
end

-- Preview copies of a slot's hairs: { { id, accessory } }
function Bridge.slotHairs(id: string): { { id: number, accessory: Accessory } }
	local ok, payload = invoke("slotHairs", id)
	return if ok and type(payload) == "table" then payload else {}
end

-- Sends the finished look. On success runs the onEnterWorld hooks.
function Bridge.enterWorld(look: { [string]: any }): (boolean, any)
	local ok, payload = invoke("confirm", look)
	if ok then
		for _, hook in Bridge.onEnterWorld do
			task.spawn(hook, payload)
		end
	end
	return ok, payload
end

return Bridge
