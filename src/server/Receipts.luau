--!strict
-- The one MarketplaceService.ProcessReceipt for the game (Roblox allows a single
-- callback, so nothing else may set it). Features register a handler per
-- developer product id; a handler applies the purchase and returns true only once
-- it has been granted. Granted PurchaseIds are remembered in the profile, and the
-- profile is saved before Roblox hears PurchaseGranted, so a replayed receipt
-- never pays out twice.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

export type Info = { PlayerId: number, ProductId: number, PurchaseId: string, CurrencySpent: number }
export type Handler = (player: Player, data: PlayerData.Data, info: Info) -> boolean

local KEEP_SECONDS = 30 * 86400 -- forget granted ids after this; Roblox stops retrying long before

local handlers: { [number]: Handler } = {}
local busy: { [string]: boolean } = {} -- receipts being granted right now

local Receipts = {}

function Receipts.register(productId: number, handler: Handler)
	assert(handlers[productId] == nil, `Receipts: product {productId} registered twice`)
	handlers[productId] = handler
end

local function prune(data: PlayerData.Data, now: number)
	for id, at in data.receipts do
		if type(at) ~= "number" or now - at > KEEP_SECONDS then
			data.receipts[id] = nil
		end
	end
end

local function process(info: Info): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and PlayerData.get(player)
	local handler = handlers[info.ProductId]
	if not (player and data) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retried when they return
	end
	if not handler then
		warn(`Receipts: no handler for product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = tostring(info.PurchaseId)
	if data.receipts[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if busy[key] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	busy[key] = true
	local ok, granted = pcall(handler, player, data, info)
	if ok and granted then
		local now = os.time()
		prune(data, now)
		data.receipts[key] = now
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
