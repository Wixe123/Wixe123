-- Delivery times for Moppelagret.se. Small orders about 1 minute, medium 3–5 minutes, large 10 minutes.
-- Backordered items (stock "Beställningsvara") add 2 minutes.
local Catalog = require(script.Parent.Catalog)
local Delivery = {}
function Delivery.seconds(lines)
	local n, back = 0, false
	for _, l in ipairs(lines) do
		n = n + l.q
		local p = Catalog.BY_SKU[l.sku]
		if p and p.stock == "Beställningsvara" then back = true end
	end
	local t
	if n <= 2 then t = 60 elseif n <= 6 then t = 180 + (n - 3) * 30 else t = 600 end
	if back then t = t + 120 end
	return t
end
return Delivery
