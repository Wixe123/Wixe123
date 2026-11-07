-- Body panels per moped model. Each panel is its own part (own item, own paint) and can be removed individually.
-- Geometry in metres in the moped's space (x right, y up, z forward). shape: box | wedge | ball. role decides the
-- default colour (body = body colour, dark = black matt, white = white). alts = alternative panels in the shop:
-- { look, name, brand, price, description }. A new model = a new list here (+ engine/chassis positions in Config).
local Panels = {}

local function alts(price, extra)
	local a = { { "carbon", "kolfiberlook", "Snabbo", math.floor(price * 1.6), "Kolfiberlook, kan inte lackeras." } }
	for _, e in ipairs(extra or {}) do table.insert(a, e) end
	return a
end

Panels.jog = {
	{ id = "front", n = "Frontkåpa", role = "body", price = 600, shape = "box", size = { 0.4, 0.62, 0.12 }, pos = { 0, 0.6, 0.42 }, rot = { 10, 0, 0 },
		alts = alts(600, { { "sport", "sport", "Fartek", 850, "Spetsigare form." } }) },
	{ id = "headset", n = "Styrkåpa", role = "body", price = 350, shape = "box", size = { 0.3, 0.18, 0.22 }, pos = { 0, 1.0, 0.45 }, alts = alts(350) },
	{ id = "lightcover", n = "Kåpa runt lyktan", role = "body", price = 250, shape = "ball", size = { 0.22, 0.17, 0.08 }, pos = { 0, 0.98, 0.55 },
		alts = { { "clear", "tonad genomskinlig", "Vippa", 300, "Genomskinlig, rökfärgad." } } },
	{ id = "floor", n = "Fotplatta", role = "dark", price = 300, shape = "box", size = { 0.38, 0.05, 0.55 }, pos = { 0, 0.25, 0.08 }, alts = alts(300) },
	{ id = "side_l", n = "Sidokåpa vänster", role = "body", price = 450, shape = "box", size = { 0.03, 0.28, 0.6 }, pos = { -0.17, 0.5, -0.33 }, alts = alts(450) },
	{ id = "side_r", n = "Sidokåpa höger", role = "body", price = 450, shape = "box", size = { 0.03, 0.28, 0.6 }, pos = { 0.17, 0.5, -0.33 }, alts = alts(450) },
	{ id = "rear", n = "Bakkåpa", role = "body", price = 500, shape = "box", size = { 0.3, 0.12, 0.62 }, pos = { 0, 0.62, -0.33 }, alts = alts(500) },
	{ id = "fender_f", n = "Framskärm", role = "body", price = 300, shape = "box", size = { 0.14, 0.03, 0.34 }, pos = { 0, 0.38, 0.6 }, rot = { -5, 0, 0 },
		alts = alts(300, { { "chrome", "krom", "Bruksmek", 750, "Förkromad." } }) },
	{ id = "fender_r", n = "Bakre stänkskärm", role = "dark", price = 200, shape = "box", size = { 0.12, 0.02, 0.3 }, pos = { 0, 0.36, -0.75 }, rot = { 20, 0, 0 }, alts = alts(200) },
	{ id = "under", n = "Underkåpa", role = "dark", price = 250, shape = "box", size = { 0.3, 0.05, 0.4 }, pos = { 0, 0.17, -0.05 } },
}

Panels.rok = {
	{ id = "front", n = "Frontkåpa", role = "body", price = 900, shape = "wedge", size = { 0.36, 0.3, 0.45 }, pos = { 0, 0.95, 0.56 }, rot = { 0, 180, 0 },
		alts = alts(900, { { "sport", "sport", "Fartek", 1300, "Aggressivare front." } }) },
	{ id = "lightcover", n = "Framkåpa runt lyktan", role = "body", price = 450, shape = "box", size = { 0.34, 0.12, 0.2 }, pos = { 0, 0.86, 0.66 },
		alts = { { "clear", "tonad genomskinlig", "Vippa", 520, "Genomskinlig, rökfärgad." } } },
	{ id = "legshield", n = "Benskydd", role = "body", price = 650, shape = "box", size = { 0.4, 0.6, 0.12 }, pos = { 0, 0.6, 0.46 }, rot = { 18, 0, 0 }, alts = alts(650) },
	{ id = "side_l", n = "Sidokåpa vänster", role = "body", price = 600, shape = "box", size = { 0.03, 0.22, 0.65 }, pos = { -0.17, 0.55, -0.36 }, alts = alts(600) },
	{ id = "side_r", n = "Sidokåpa höger", role = "body", price = 600, shape = "box", size = { 0.03, 0.22, 0.65 }, pos = { 0.17, 0.55, -0.36 }, alts = alts(600) },
	{ id = "rearside_l", n = "Bakre sidokåpa vänster", role = "body", price = 400, shape = "wedge", size = { 0.03, 0.14, 0.3 }, pos = { -0.16, 0.62, -0.78 }, alts = alts(400) },
	{ id = "rearside_r", n = "Bakre sidokåpa höger", role = "body", price = 400, shape = "wedge", size = { 0.03, 0.14, 0.3 }, pos = { 0.16, 0.62, -0.78 }, alts = alts(400) },
	{ id = "under", n = "Underkåpa", role = "dark", price = 350, shape = "box", size = { 0.32, 0.05, 0.5 }, pos = { 0, 0.19, -0.1 } },
	{ id = "foot_l", n = "Fotplatta vänster", role = "dark", price = 250, shape = "box", size = { 0.14, 0.03, 0.52 }, pos = { -0.1, 0.27, 0.08 }, alts = alts(250) },
	{ id = "foot_r", n = "Fotplatta höger", role = "dark", price = 250, shape = "box", size = { 0.14, 0.03, 0.52 }, pos = { 0.1, 0.27, 0.08 }, alts = alts(250) },
	{ id = "fender_r", n = "Bakre stänkskärm", role = "dark", price = 300, shape = "box", size = { 0.12, 0.02, 0.3 }, pos = { 0, 0.44, -0.92 }, rot = { 20, 0, 0 },
		alts = alts(300, { { "short", "kort custom", "Snabbo", 450, "Kortare custom-stänkskärm." } }) },
	{ id = "fender_f", n = "Framskärm", role = "body", price = 350, shape = "box", size = { 0.13, 0.03, 0.32 }, pos = { 0, 0.56, 0.65 }, rot = { -5, 0, 0 }, alts = alts(350) },
	{ id = "grips", n = "Handtagskåpa", role = "dark", price = 300, shape = "box", size = { 0.55, 0.05, 0.12 }, pos = { 0, 1.05, 0.42 }, alts = alts(300) },
	{ id = "barcover", n = "Styrkåpa", role = "body", price = 400, shape = "box", size = { 0.3, 0.1, 0.18 }, pos = { 0, 1.1, 0.4 }, alts = alts(400) },
	{ id = "dash", n = "Kåpa runt instrumentpanelen", role = "dark", price = 300, shape = "box", size = { 0.22, 0.06, 0.12 }, pos = { 0, 1.16, 0.34 } },
}

Panels.dt = {
	{ id = "tankcover", n = "Tankkåpa", role = "body", price = 700, shape = "box", size = { 0.27, 0.12, 0.42 }, pos = { 0, 0.97, 0.12 }, rot = { -9, 0, 0 }, alts = alts(700) },
	{ id = "side_l", n = "Sidoskydd vänster", role = "white", price = 300, shape = "box", size = { 0.012, 0.17, 0.22 }, pos = { -0.115, 0.74, -0.3 }, alts = alts(300) },
	{ id = "side_r", n = "Sidoskydd höger", role = "white", price = 300, shape = "box", size = { 0.012, 0.17, 0.22 }, pos = { 0.115, 0.74, -0.3 }, alts = alts(300) },
	{ id = "fender_f", n = "Framskärm", role = "white", price = 350, shape = "box", size = { 0.11, 0.02, 0.42 }, pos = { 0, 0.5, 0.7 }, rot = { -8, 0, 0 }, alts = alts(350) },
	{ id = "fender_r", n = "Bakskärm", role = "white", price = 400, shape = "box", size = { 0.13, 0.02, 0.5 }, pos = { 0, 0.88, -0.86 }, rot = { 12, 0, 0 },
		alts = alts(400, { { "short", "kort custom", "Snabbo", 550, "Kortare bakskärm." } }) },
	{ id = "lampmask", n = "Lyktmask", role = "white", price = 350, shape = "box", size = { 0.22, 0.24, 0.04 }, pos = { 0, 0.9, 0.55 }, rot = { -25, 0, 0 }, alts = alts(350) },
}

-- look -> how the panel is drawn (carbon: fixed carbon colour, clear: smoked transparent, chrome: chrome, sport/short: different size)
Panels.LOOK = {
	std = {}, carbon = { fixed = "carbon" }, clear = { fixed = "clear" }, chrome = { fixed = "chrome" },
	sport = { scale = { 1.08, 0.92, 1.12 } }, short = { scale = { 1, 1, 0.65 } },
}
function Panels.find(mopId, panelId)
	for _, p in ipairs(Panels[mopId] or {}) do if p.id == panelId then return p end end
	return nil
end
return Panels
