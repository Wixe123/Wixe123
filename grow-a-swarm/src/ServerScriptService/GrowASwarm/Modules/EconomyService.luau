--!strict
-- Every cash-affecting player action funnels through here as a RemoteFunction
-- so the client gets a synchronous ok/error result instead of guessing from a
-- later state push. All validation is server-side; the client's numbers are
-- only ever a preview.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local PlotManager = require(script.Parent.PlotManager)
local PlayerState = require(script.Parent.PlayerState)
local SwarmMath = require(script.Parent.SwarmMath)

type Result = { ok: boolean, error: string? }

local VALID_UPGRADE_TYPES: { [string]: boolean } = {
	Capacity = true,
	Income = true,
	FeralResistance = true,
}

local Module = {}

local function handleBuyCreature(player: Player, creatureId: any): Result
	if typeof(creatureId) ~= "string" then
		return { ok = false, error = "InvalidRequest" }
	end

	local session = PlayerState.Get(player.UserId)
	if not session then
		return { ok = false, error = "NoSession" }
	end

	local def = Config.GetCreature(creatureId)
	if not def then
		return { ok = false, error = "UnknownCreature" }
	end
	if session.data.rebirths < def.MinRebirths then
		return { ok = false, error = "LockedByRebirth" }
	end
	if session.data.cash < def.Cost then
		return { ok = false, error = "CannotAfford" }
	end
	if SwarmMath.Population(session.data) >= SwarmMath.Capacity(session.data) then
		return { ok = false, error = "NestFull" }
	end

	session.data.cash -= def.Cost
	session.data.ownedCreatures[creatureId] = (session.data.ownedCreatures[creatureId] or 0) + 1

	PlayerState.PushState(session)
	return { ok = true }
end

local function handleBuyUpgrade(player: Player, upgradeType: any): Result
	if typeof(upgradeType) ~= "string" or not VALID_UPGRADE_TYPES[upgradeType] then
		return { ok = false, error = "InvalidRequest" }
	end

	local session = PlayerState.Get(player.UserId)
	if not session then
		return { ok = false, error = "NoSession" }
	end

	-- session.data.upgrades is a fixed-shape record (not a map), so it's
	-- indexed by explicit branch rather than by the dynamic upgradeType
	-- string -- keeps this file typecheck-safe under --!strict.
	local upgrades = session.data.upgrades
	local currentLevel: number
	if upgradeType == "Capacity" then
		currentLevel = upgrades.Capacity
	elseif upgradeType == "Income" then
		currentLevel = upgrades.Income
	else
		currentLevel = upgrades.FeralResistance
	end

	local typedUpgrade = upgradeType :: Config.UpgradeType
	local maxLevel = Config.GetUpgradeMaxLevel(typedUpgrade)
	if currentLevel >= maxLevel then
		return { ok = false, error = "MaxLevel" }
	end

	local cost = Config.GetUpgradeCost(typedUpgrade, currentLevel)
	if session.data.cash < cost then
		return { ok = false, error = "CannotAfford" }
	end

	session.data.cash -= cost
	if upgradeType == "Capacity" then
		upgrades.Capacity = currentLevel + 1
	elseif upgradeType == "Income" then
		upgrades.Income = currentLevel + 1
	else
		upgrades.FeralResistance = currentLevel + 1
	end

	PlayerState.PushState(session)
	return { ok = true }
end

local function handleRebirth(player: Player): Result
	local session = PlayerState.Get(player.UserId)
	if not session then
		return { ok = false, error = "NoSession" }
	end

	local requirement = Config.Rebirth.Requirements[session.data.rebirths + 1]
	if requirement == nil then
		return { ok = false, error = "MaxRebirthReached" }
	end
	if session.data.totalEarned < requirement then
		return { ok = false, error = "RequirementNotMet" }
	end

	local data = session.data
	data.rebirths += 1
	data.cash = Config.Currency.StartingCash
	data.ownedCreatures = {}
	data.upgrades = { Capacity = 0, Income = 0, FeralResistance = 0 }
	data.isFeral = false
	data.isInfested = false
	data.lastTendedAt = os.time()

	PlotManager.SetVisualState(player.UserId, false, false, player.Name)
	PlayerState.Notify(session, ("Rebirth #%d! Permanent income multiplier increased."):format(data.rebirths), "success")
	PlayerState.PushState(session)
	return { ok = true }
end

function Module.Init(remotes: { [string]: RemoteEvent | RemoteFunction })
	(remotes.BuyCreature :: RemoteFunction).OnServerInvoke = handleBuyCreature
	(remotes.BuyUpgrade :: RemoteFunction).OnServerInvoke = handleBuyUpgrade
	(remotes.Rebirth :: RemoteFunction).OnServerInvoke = handleRebirth
end

return Module
