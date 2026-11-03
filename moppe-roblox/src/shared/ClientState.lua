-- Shared state between the client's scripts (Ride and UI). Used only on the client.
local ClientState = {
	profile = nil, -- latest profile from the server
	ride = nil, -- riding state (speed, rpm, temperature ...), set by Ride.client
	changed = Instance.new("BindableEvent"), -- fired when the profile changes
	toast = Instance.new("BindableEvent"), -- short messages to the HUD
}
return ClientState
