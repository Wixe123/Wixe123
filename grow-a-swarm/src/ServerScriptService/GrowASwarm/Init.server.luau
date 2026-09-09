--!strict
-- Boot script: builds the remotes, builds the map if needed, wires up every
-- service in dependency order, and hooks player join/leave + shutdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Modules.RemoteNames)

-- Init.server.luau is a sibling of Modules/ under the GrowASwarm folder, not
-- a child of it, hence script.Parent.Modules rather than script.Modules.
local PlotBuilder = require(script.Parent.Modules.PlotBuilder)
local PlayerState = require(script.Parent.Modules.PlayerState)
local SwarmService = require(script.Parent.Modules.SwarmService)
local EconomyService = require(script.Parent.Modules.EconomyService)

local function createRemotes(): { [string]: RemoteEvent | RemoteFunction }
	local folder = Instance.new("Folder")
	folder.Name = RemoteNames.FolderName

	local remotes: { [string]: RemoteEvent | RemoteFunction } = {}

	local function newEvent(name: string)
		local instance = Instance.new("RemoteEvent")
		instance.Name = name
		instance.Parent = folder
		remotes[name] = instance
	end

	local function newFunction(name: string)
		local instance = Instance.new("RemoteFunction")
		instance.Name = name
		instance.Parent = folder
		remotes[name] = instance
	end

	newFunction(RemoteNames.BuyCreature)
	newFunction(RemoteNames.BuyUpgrade)
	newFunction(RemoteNames.Rebirth)
	newEvent(RemoteNames.TendNest)
	newEvent(RemoteNames.ClearAttempt)
	newEvent(RemoteNames.StateChanged)
	newEvent(RemoteNames.Notify)

	folder.Parent = ReplicatedStorage
	return remotes
end

PlotBuilder.EnsurePlotsExist()

local remotes = createRemotes()
PlayerState.Init(remotes)
SwarmService.Init(remotes)
EconomyService.Init(remotes)

Players.PlayerAdded:Connect(PlayerState.OnPlayerAdded)
Players.PlayerRemoving:Connect(PlayerState.OnPlayerRemoving)

-- Cover the case where this script starts after players already connected
-- (e.g. hot-reload tooling in Studio). The event connections above are made
-- first so nobody who joins during this loop is missed.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerState.OnPlayerAdded, player)
end

game:BindToClose(function()
	PlayerState.SaveAllForShutdown()
end)
