-- Shared state between the client's scripts. Used only on the client.
local function ev() return Instance.new("BindableEvent") end
local ClientState = {
	profile = nil, -- latest profile from the server (incl. _plot, _carry, _out)
	ride = nil, -- riding state (Ride.client)
	mode = nil, -- active work mode: nil | "engine" | "shop" | "port" | "paint" | "styling"
	changed = ev(), toast = ev(),
	openShop = ev(), -- arg: filter (kind/panel) or nil
	openPort = ev(), openPaint = ev(), openStyling = ev(), modeEnded = ev(),
}
function ClientState.setMode(m) ClientState.mode = m end
return ClientState
