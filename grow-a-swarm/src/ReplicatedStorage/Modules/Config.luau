--!strict
-- Single source of truth for game balance. Change numbers here, not in the logic modules.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type CreatureDef = {
	Id: string,
	Name: string,
	Rarity: Rarity,
	Cost: number,
	IncomeRate: number, -- cash per second while the nest is healthy
	MinRebirths: number, -- rebirth count required before this appears in the shop
}

export type UpgradeType = "Capacity" | "Income" | "FeralResistance"

local Config = {}

Config.Currency = {
	StartingCash = 50,
}

Config.Plot = {
	Count = 12,
	Size = Vector3.new(40, 1, 40),
	Gap = 14,
	NestInteractRadius = 10, -- studs; how close a player must be to Tend or Clear their own nest
}

Config.Swarm = {
	BaseCapacity = 10,
	CapacityPerUpgradeLevel = 5,
	IncomeTickSeconds = 1,
	FeralTimeoutSeconds = 10 * 60, -- unattended time at full capacity before a swarm goes feral
	FeralCheckIntervalSeconds = 15,
}

Config.Infestation = {
	SpreadCheckIntervalSeconds = 30,
	SpreadChancePerCheck = 0.35,
	IncomeMultiplierWhileInfested = 0.4, -- an infested plot still earns 40%, it's a debuff not a shutdown
	RequiredClearHits = 12,
	MinClearDurationSeconds = 3, -- a legitimate clear can't finish faster than this
	MaxClearHitsPerSecond = 6, -- above this the server rejects the attempt as inhuman
	ClearRewardCash = 25,
	ReattemptCooldownSeconds = 2,
}

export type UpgradeDef = {
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
	PerLevelBonus: number?,
	PerLevelSeconds: number?,
}

-- Cast to an index-signature type (rather than letting Luau infer an exact
-- record) so Config.Upgrades[upgradeType] can be indexed dynamically by the
-- UpgradeType union in GetUpgradeCost/GetUpgradeMaxLevel below.
Config.Upgrades = {
	Capacity = {
		BaseCost = 100,
		CostGrowth = 1.6,
		MaxLevel = 10,
	},
	Income = {
		BaseCost = 150,
		CostGrowth = 1.7,
		PerLevelBonus = 0.15, -- +15% income per level
		MaxLevel = 10,
	},
	FeralResistance = {
		BaseCost = 200,
		CostGrowth = 1.8,
		PerLevelSeconds = 90, -- extra unattended time allowed per level
		MaxLevel = 8,
	},
} :: { [UpgradeType]: UpgradeDef }

-- cumulative lifetime cash earned required to unlock each successive rebirth
Config.Rebirth = {
	Requirements = { 2500, 10000, 35000, 100000, 300000 },
	IncomeMultiplierPerRebirth = 0.5, -- +50% income per rebirth, permanent, stacks additively
}

Config.Creatures = {
	{ Id = "gnat", Name = "Gnat", Rarity = "Common", Cost = 25, IncomeRate = 0.5, MinRebirths = 0 },
	{ Id = "roach", Name = "Roach", Rarity = "Common", Cost = 60, IncomeRate = 1.1, MinRebirths = 0 },
	{ Id = "locust", Name = "Locust", Rarity = "Uncommon", Cost = 150, IncomeRate = 2.6, MinRebirths = 0 },
	{ Id = "hornet", Name = "Hornet", Rarity = "Uncommon", Cost = 320, IncomeRate = 5.4, MinRebirths = 0 },
	{ Id = "mantis", Name = "Broodmantis", Rarity = "Rare", Cost = 800, IncomeRate = 13, MinRebirths = 0 },
	{ Id = "termite_queen", Name = "Termite Queen", Rarity = "Epic", Cost = 2200, IncomeRate = 34, MinRebirths = 1 },
	{ Id = "roach_king", Name = "Roach King", Rarity = "Epic", Cost = 5000, IncomeRate = 72, MinRebirths = 1 },
	{ Id = "hive_titan", Name = "Hive Titan", Rarity = "Legendary", Cost = 15000, IncomeRate = 210, MinRebirths = 2 },
} :: { CreatureDef }

function Config.GetCreature(id: string): CreatureDef?
	for _, def in ipairs(Config.Creatures) do
		if def.Id == id then
			return def
		end
	end
	return nil
end

function Config.GetUpgradeCost(upgradeType: UpgradeType, currentLevel: number): number
	local cfg = Config.Upgrades[upgradeType]
	return math.floor(cfg.BaseCost * (cfg.CostGrowth ^ currentLevel))
end

function Config.GetUpgradeMaxLevel(upgradeType: UpgradeType): number
	return Config.Upgrades[upgradeType].MaxLevel
end

return Config
