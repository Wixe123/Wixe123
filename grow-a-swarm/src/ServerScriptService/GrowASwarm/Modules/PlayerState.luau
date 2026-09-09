--!strict
-- Owns the per-player session lifecycle: load-or-kick on join, leaderstats,
-- periodic autosave/heartbeat, and final save+release on leave or shutdown.
-- Other server modules read/mutate session.data directly (they're trusted,
-- server-only code) and then call PlayerState.PushState to replicate.

local Players = game:GetService("Players")

local DataStoreService = require(script.Parent.DataStoreService)
local PlotManager = require(script.Parent.PlotManager)

type SaveData = DataStoreService.SaveData

export type Session = {
	player: Player,
	data: SaveData,
	alive: boolean,
	cashStat: IntValue,
	rebirthStat: IntValue,
}

local HEARTBEAT_INTERVAL_SECONDS = 90

local Module = {}

local sessions: { [number]: Session } = {}
local remotes: { [string]: RemoteEvent | RemoteFunction } = {}

function Module.Init(remotesIn: { [string]: RemoteEvent | RemoteFunction })
	remotes = remotesIn
end

function Module.Get(userId: number): Session?
	return sessions[userId]
end

function Module.GetAll(): { [number]: Session }
	return sessions
end

function Module.PushState(session: Session)
	session.cashStat.Value = math.floor(session.data.cash)
	session.rebirthStat.Value = session.data.rebirths

	local stateEvent = remotes.StateChanged :: RemoteEvent
	stateEvent:FireClient(session.player, session.data)
end

function Module.Notify(session: Session, text: string, kind: string?)
	local notifyEvent = remotes.Notify :: RemoteEvent
	notifyEvent:FireClient(session.player, text, kind or "info")
end

local function startHeartbeatLoop(session: Session)
	task.spawn(function()
		while session.alive do
			task.wait(HEARTBEAT_INTERVAL_SECONDS)
			if not session.alive then
				break
			end
			DataStoreService.SaveProgress(session.player.UserId, session.data, true)
		end
	end)
end

local function buildLeaderstats(player: Player, data: SaveData): (IntValue, IntValue)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = math.floor(data.cash)
	cash.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
	return cash, rebirths
end

function Module.OnPlayerAdded(player: Player)
	local data, err = DataStoreService.Load(player.UserId)

	if not data then
		player:Kick(
			"Your save couldn't be loaded safely right now ("
				.. tostring(err)
				.. "). This protects your progress -- please rejoin in a moment."
		)
		return
	end

	if not player:IsDescendantOf(Players) then
		-- Player disconnected while we were waiting on the DataStore call.
		DataStoreService.SaveProgress(player.UserId, data, false)
		return
	end

	local cashStat, rebirthStat = buildLeaderstats(player, data)
	PlotManager.AssignPlot(player)

	local session: Session = {
		player = player,
		data = data,
		alive = true,
		cashStat = cashStat,
		rebirthStat = rebirthStat,
	}
	sessions[player.UserId] = session

	startHeartbeatLoop(session)
	Module.PushState(session)
end

function Module.OnPlayerRemoving(player: Player)
	local session = sessions[player.UserId]
	if not session then
		return
	end

	session.alive = false
	sessions[player.UserId] = nil

	DataStoreService.SaveProgress(player.UserId, session.data, false)
	PlotManager.FreePlot(player.UserId)
end

-- Called from Init's BindToClose. Saves every active session in parallel and
-- blocks until they're all done (or the game server's shutdown grace period
-- runs out, whichever comes first -- Roblox gives limited time here).
function Module.SaveAllForShutdown()
	local remaining = 0
	local done = false

	for userId, session in pairs(sessions) do
		remaining += 1
		task.spawn(function()
			session.alive = false
			DataStoreService.SaveProgress(userId, session.data, false)
			remaining -= 1
			if remaining == 0 then
				done = true
			end
		end)
	end

	local waited = 0
	while not done and waited < 25 do
		task.wait(0.25)
		waited += 0.25
	end
end

return Module
