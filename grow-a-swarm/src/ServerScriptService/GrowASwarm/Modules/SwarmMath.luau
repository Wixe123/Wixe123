--!strict
-- Pure calculations shared by SwarmService (the tick loop) and EconomyService
-- (purchase validation), so nest capacity/income math can never drift between
-- the two call sites.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local DataStoreService = require(script.Parent.DataStoreService)

type SaveData = DataStoreService.SaveData

local Module = {}

function Module.Population(data: SaveData): number
	local total = 0
	for _, count in pairs(data.ownedCreatures) do
		total += count
	end
	return total
end

function Module.Capacity(data: SaveData): number
	return Config.Swarm.BaseCapacity + Config.Swarm.CapacityPerUpgradeLevel * data.upgrades.Capacity
end

function Module.FeralTimeoutSeconds(data: SaveData): number
	return Config.Swarm.FeralTimeoutSeconds + Config.Upgrades.FeralResistance.PerLevelSeconds * data.upgrades.FeralResistance
end

function Module.IncomePerSecond(data: SaveData): number
	local base = 0
	for id, count in pairs(data.ownedCreatures) do
		local def = Config.GetCreature(id)
		if def then
			base += def.IncomeRate * count
		end
	end

	local incomeMult = 1 + Config.Upgrades.Income.PerLevelBonus * data.upgrades.Income
	local rebirthMult = 1 + Config.Rebirth.IncomeMultiplierPerRebirth * data.rebirths
	local total = base * incomeMult * rebirthMult

	if data.isFeral then
		return 0
	elseif data.isInfested then
		return total * Config.Infestation.IncomeMultiplierWhileInfested
	end
	return total
end

return Module
