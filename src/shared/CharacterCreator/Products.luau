--!strict
-- Developer products for the paid rerolls. Create each product in the Creator
-- Dashboard (Monetization > Developer Products) and paste its id here.
-- RobuxPrice is what the button shows; keep it in step with the dashboard price.
-- While an id is 0 the reroll runs in mock mode: free, and only in Studio or the
-- testbed (the server refuses it in a live game), so the flow can be tested
-- without real purchases.

export type Product = { ProductId: number, RobuxPrice: number }

local Products: { RerollRace: Product, RerollSurname: Product } = {
	RerollRace = { ProductId = 0, RobuxPrice = 299 },
	RerollSurname = { ProductId = 0, RobuxPrice = 99 },
}

return Products
