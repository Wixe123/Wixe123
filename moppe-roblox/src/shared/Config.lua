-- Game-wide constants. 1 stud = 0.3 m for vehicles and parts.
local Config = {}

Config.STUD = 0.3
Config.START_MONEY = 4000
Config.MAX_PLAYERS = 6
Config.REACH = 16 -- studs a player may be from what they work on
Config.PAINT_DRY = 20 -- seconds
Config.PORT_MIN_TIME = 6 -- a porting session must take at least this long (server check)
Config.PAINT_MIN_TIME = 3
Config.SELL_FACTOR = 0.5 -- used parts sell for half the price
Config.SAVE_KEY = "MoppeMekaniker_v3"

-- plots: garages along Garagegatan; the street runs along x at z = STREET_Z
Config.PLOT_SPACING = 56
Config.STREET_Z = -34
function Config.plotOrigin(i)
	return (i - (Config.MAX_PLAYERS + 1) / 2) * Config.PLOT_SPACING
end

-- UI palette (dark panels, blue accent, green money), like the reference pictures
Config.UI = {
	panel = { 18, 20, 26 }, panel2 = { 30, 33, 42 }, line = { 60, 66, 80 },
	text = { 236, 239, 244 }, dim = { 150, 158, 172 },
	accent = { 43, 124, 230 }, accent2 = { 74, 152, 255 },
	green = { 46, 204, 113 }, red = { 231, 76, 60 }, yellow = { 241, 196, 15 }, orange = { 243, 156, 18 },
}

return Config
