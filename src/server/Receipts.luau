--!strict
-- The one MarketplaceService.ProcessReceipt for the game (Roblox allows a single
-- callback, so nothing else may set it). Features register a handler per
-- developer product id; a handler applies the purchase and returns true only once
-- it has been granted. Granted PurchaseIds are remembered in the profile, and the
-- profile is saved before Roblox hears PurchaseGranted, so a replayed receipt
-- never pays out twice. Receipts are the account's (shared by every save slot):
-- a reroll is bought on the character screen, before any slot is played, so a
-- handler gets the played slot's profile or nil and returns false (retried
-- later) if it needs one.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

export type Info = { PlayerId: number, ProductId: number, PurchaseId: string, CurrencySpent: number }
export type Handler = (player: Player, data: PlayerData.Data?, info: Info) -> boolean

local KEEP_SECONDS = 30 * 86400 -- forget granted ids after this; Roblox stops retrying long before

local handlers: { [number]: Handler } = {}
local busy: { [string]: boolean } = {} -- receipts being granted right now

local Receipts = {}

function Receipts.register(productId: number, handler: Handler)
	assert(handlers[productId] == nil, `Receipts: product {productId} registered twice`)
	handlers[productId] = handler
end

local function prune(receipts: { [string]: number }, now: number)
	for id, at in receipts do
		if type(at) ~= "number" or now - at > KEEP_SECONDS then
			receipts[id] = nil
		end
	end
end

local function process(info: Info): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local account = player and PlayerData.account(player)
	local handler = handlers[info.ProductId]
	if not (player and account) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retried when they return
	end
	if not handler then
		warn(`Receipts: no handler for product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = tostring(info.PurchaseId)
	local receipts = account.receipts
	if receipts[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if busy[key] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	busy[key] = true
	local ok, granted = pcall(handler, player, PlayerData.get(player), info)
	if ok and granted then
		local now = os.time()
		prune(receipts, now)
		receipts[key] = now
		PlayerData.save(player)
	elseif not ok then
		warn("Receipts: handler failed:", granted)
	end
	busy[key] = nil
	return if ok and granted
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function Receipts.start()
	MarketplaceService.ProcessReceipt = process :: any
end

return Receipts
