--!strict
-- Session-locked DataStore wrapper. No external dependencies (no ProfileService).
--
-- The one rule that matters here: if we can't confirm we hold the lock, we must
-- NEVER let the player play on a fresh/default profile that later gets saved --
-- that would silently overwrite their real save with an empty one. On any load
-- failure or lock conflict, Load() returns nil and the caller (PlayerState) is
-- required to kick the player instead of proceeding.

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("GrowASwarm_v1")

-- Unique per server instance. JobId is empty in Studio test play, so fall back
-- to a random id there so local multi-instance testing doesn't collide.
local SESSION_ID = if game.JobId ~= "" then game.JobId else ("studio_" .. tostring(math.random(1, 1e9)))

local MAX_RETRIES = 5
local RETRY_BASE_SECONDS = 1.4

-- How long a session's lock is honored after its last heartbeat before another
-- server is allowed to take over. PlayerState renews the heartbeat well inside
-- this window (every 90s) while the player is connected. This is deliberately
-- generous: a slower failover after a real crash is a fine trade for never
-- racing two servers on the same save.
local LOCK_STALE_SECONDS = 300

export type SaveData = {
	cash: number,
	totalEarned: number,
	rebirths: number,
	ownedCreatures: { [string]: number },
	upgrades: { Capacity: number, Income: number, FeralResistance: number },
	lastTendedAt: number,
	isFeral: boolean,
	isInfested: boolean,
}

type SessionInfo = { id: string, heartbeat: number }

local function defaultData(): SaveData
	return {
		cash = 50,
		totalEarned = 0,
		rebirths = 0,
		ownedCreatures = {},
		upgrades = { Capacity = 0, Income = 0, FeralResistance = 0 },
		lastTendedAt = os.time(),
		isFeral = false,
		isInfested = false,
	}
end

local function attempt<T>(fn: () -> T): (boolean, T?)
	for i = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if i < MAX_RETRIES then
			task.wait(RETRY_BASE_SECONDS * i)
		else
			warn(("[GrowASwarm] DataStore call failed after %d attempts: %s"):format(MAX_RETRIES, tostring(result)))
		end
	end
	return false, nil
end

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

local function backfillDefaults(data: any)
	local fresh = defaultData()
	for k, v in pairs(fresh) do
		if data[k] == nil then
			data[k] = v
		end
	end
	if type(data.upgrades) ~= "table" then
		data.upgrades = fresh.upgrades
	else
		for k, v in pairs(fresh.upgrades) do
			if data.upgrades[k] == nil then
				data.upgrades[k] = v
			end
		end
	end
	if type(data.ownedCreatures) ~= "table" then
		data.ownedCreatures = {}
	end
end

local Module = {}

-- Returns (data, nil) on success, or (nil, reason) on failure. Callers MUST
-- treat a nil result as "cannot safely start this session" and kick the player.
function Module.Load(userId: number): (SaveData?, string?)
	local key = keyFor(userId)

	local ok, result = attempt(function()
		return store:UpdateAsync(key, function(old: any)
			local data = old
			if type(data) ~= "table" then
				data = defaultData()
			end

			local session: SessionInfo? = data.session
			if session ~= nil and session.id ~= SESSION_ID and (os.time() - session.heartbeat) < LOCK_STALE_SECONDS then
				error("SessionLocked")
			end

			data.session = { id = SESSION_ID, heartbeat = os.time() }
			return data
		end)
	end)

	if not ok then
		return nil, "DataStoreUnavailableOrLocked"
	end
	if type(result) ~= "table" then
		return nil, "CorruptData"
	end

	local data = result :: any
	data.session = nil
	backfillDefaults(data)
	return data :: SaveData, nil
end

-- keepSession = true: periodic autosave/heartbeat while the player is still connected.
-- keepSession = false: final save on leave/shutdown, releases the lock for the next server.
function Module.SaveProgress(userId: number, data: SaveData, keepSession: boolean): boolean
	local key = keyFor(userId)
	local ok = attempt(function()
		store:UpdateAsync(key, function(old: any)
			-- Don't clobber another server's lock if we somehow lost ours (e.g. this
			-- server stalled past LOCK_STALE_SECONDS and someone else took over).
			if type(old) == "table" and old.session and old.session.id ~= SESSION_ID then
				local theirs: SessionInfo = old.session
				if (os.time() - theirs.heartbeat) < LOCK_STALE_SECONDS then
					error("LostLockToAnotherSession")
				end
			end

			local payload = table.clone(data) :: any
			if keepSession then
				payload.session = { id = SESSION_ID, heartbeat = os.time() }
			else
				payload.session = nil
			end
			return payload
		end)
	end)
	return ok
end

return Module
