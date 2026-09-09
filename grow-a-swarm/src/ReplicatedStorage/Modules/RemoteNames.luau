--!strict
-- Shared string constants so client and server never typo a remote name against each other.

return {
	FolderName = "GrowASwarmRemotes",

	-- RemoteFunctions (client invokes, server returns {ok: boolean, error: string?, ...})
	BuyCreature = "BuyCreature",
	BuyUpgrade = "BuyUpgrade",
	Rebirth = "Rebirth",

	-- RemoteEvents (fire and forget, one direction each)
	TendNest = "TendNest", -- client -> server
	ClearAttempt = "ClearAttempt", -- client -> server
	StateChanged = "StateChanged", -- server -> client, full state push
	Notify = "Notify", -- server -> client, toast message
}
