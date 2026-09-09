--!strict
-- The core loop: passive income, going feral when an unattended nest is full,
-- and feral swarms spreading infestation to other online players' plots.
-- Everything here is server-authoritative; the client only ever sends intent
-- (Tend, ClearAttempt) and the server decides whether it's valid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local PlotManager = require(script.Parent.PlotManager)
local PlayerState = require(script.Parent.PlayerState)
local SwarmMath = require(script.Parent.SwarmMath)

type Session = PlayerState.Session

local Module = {}

local remotes: { [string]: RemoteEvent | RemoteFunction } = {}
-- Ephemeral, not persisted: last time each player attempted to clear an
-- infestation, purely to rate-limit the ClearAttempt remote.
local lastClearAttemptAt: { [number]: number } = {}

local function incomeTick()
	local tick = Config.Swarm.IncomeTickSeconds
	for _, session in pairs(PlayerState.GetAll()) do
		local income = SwarmMath.IncomePerSecond(session.data) * tick
		if income > 0 then
			session.data.cash += income
			session.data.totalEarned += income
		end
	end
	for _, session in pairs(PlayerState.GetAll()) do
		PlayerState.PushState(session)
	end
end

local function feralCheck()
	for userId, session in pairs(PlayerState.GetAll()) do
		if session.data.isFeral then
			continue
		end
		local population = SwarmMath.Population(session.data)
		local capacity = SwarmMath.Capacity(session.data)
		if population < capacity then
			continue
		end
		local elapsed = os.time() - session.data.lastTendedAt
		if elapsed > SwarmMath.FeralTimeoutSeconds(session.data) then
			session.data.isFeral = true
			PlotManager.SetVisualState(userId, true, session.data.isInfested, session.player.Name)
			PlayerState.Notify(session, "Your swarm went feral! Tend your nest before it starts infesting others.", "warning")
			PlayerState.PushState(session)
		end
	end
end

local function infestationSpread()
	local allSessions = PlayerState.GetAll()

	for sourceUserId, sourceSession in pairs(allSessions) do
		if not sourceSession.data.isFeral then
			continue
		end
		if math.random() > Config.Infestation.SpreadChancePerCheck then
			continue
		end

		local candidates: { number } = {}
		for candidateUserId, candidateSession in pairs(allSessions) do
			if candidateUserId ~= sourceUserId and not candidateSession.data.isInfested and not candidateSession.data.isFeral then
				table.insert(candidates, candidateUserId)
			end
		end
		if #candidates == 0 then
			continue
		end

		local targetUserId = candidates[math.random(1, #candidates)]
		local targetSession = allSessions[targetUserId]
		targetSession.data.isInfested = true

		PlotManager.SetVisualState(targetUserId, targetSession.data.isFeral, true, targetSession.player.Name)
		PlayerState.Notify(targetSession, "A feral swarm infested your nest! Clear it to restore full income.", "warning")
		PlayerState.Notify(sourceSession, "Your feral swarm spread to " .. targetSession.player.Name .. "'s nest.", "info")
		PlayerState.PushState(targetSession)
	end
end

local function onTendNest(player: Player)
	local session = PlayerState.Get(player.UserId)
	if not session then
		return
	end
	if not PlotManager.IsPlayerNearOwnNest(player) then
		PlayerState.Notify(session, "You need to be at your own nest to tend it.", "error")
		return
	end

	session.data.lastTendedAt = os.time()
	local wasFeral = session.data.isFeral
	session.data.isFeral = false

	PlotManager.SetVisualState(player.UserId, false, session.data.isInfested, player.Name)
	if wasFeral then
		PlayerState.Notify(session, "You calmed your swarm.", "success")
	end
	PlayerState.PushState(session)
end

local function onClearAttempt(player: Player, hits: any, duration: any)
	if typeof(hits) ~= "number" or typeof(duration) ~= "number" then
		return
	end
	if hits ~= hits or duration ~= duration then -- NaN guard
		return
	end

	local session = PlayerState.Get(player.UserId)
	if not session then
		return
	end
	if not session.data.isInfested then
		return
	end
	if not PlotManager.IsPlayerNearOwnNest(player) then
		PlayerState.Notify(session, "You need to be at your own nest to clear it.", "error")
		return
	end

	local now = os.time()
	if now - (lastClearAttemptAt[player.UserId] or 0) < Config.Infestation.ReattemptCooldownSeconds then
		return
	end
	lastClearAttemptAt[player.UserId] = now

	local cfg = Config.Infestation
	local isValid = hits >= cfg.RequiredClearHits
		and duration >= cfg.MinClearDurationSeconds
		and duration > 0
		and (hits / duration) <= cfg.MaxClearHitsPerSecond

	if not isValid then
		PlayerState.Notify(session, "Clear attempt failed -- try again.", "error")
		return
	end

	session.data.isInfested = false
	session.data.cash += cfg.ClearRewardCash
	session.data.totalEarned += cfg.ClearRewardCash

	PlotManager.SetVisualState(player.UserId, session.data.isFeral, false, player.Name)
	PlayerState.Notify(session, ("Infestation cleared! +%d cash."):format(cfg.ClearRewardCash), "success")
	PlayerState.PushState(session)
end

function Module.Init(remotesIn: { [string]: RemoteEvent | RemoteFunction })
	remotes = remotesIn

	(remotes.TendNest :: RemoteEvent).OnServerEvent:Connect(onTendNest)
	(remotes.ClearAttempt :: RemoteEvent).OnServerEvent:Connect(onClearAttempt)

	task.spawn(function()
		while true do
			task.wait(Config.Swarm.IncomeTickSeconds)
			incomeTick()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Swarm.FeralCheckIntervalSeconds)
			feralCheck()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Infestation.SpreadCheckIntervalSeconds)
			infestationSpread()
		end
	end)
end

return Module
