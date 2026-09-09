-- Client UI, built entirely in code since there's no hand-designed layout to
-- sync from Studio. Deliberately plain/functional styling, not art -- swap in
-- real design once the loop is proven fun. All numbers shown here are a
-- preview; the server is the only source of truth and validates every action.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local RemoteNames = require(ReplicatedStorage.Modules.RemoteNames)

local remotesFolder = ReplicatedStorage:WaitForChild(RemoteNames.FolderName)
local BuyCreatureRemote = remotesFolder:WaitForChild(RemoteNames.BuyCreature) :: RemoteFunction
local BuyUpgradeRemote = remotesFolder:WaitForChild(RemoteNames.BuyUpgrade) :: RemoteFunction
local RebirthRemote = remotesFolder:WaitForChild(RemoteNames.Rebirth) :: RemoteFunction
local TendNestRemote = remotesFolder:WaitForChild(RemoteNames.TendNest) :: RemoteEvent
local ClearAttemptRemote = remotesFolder:WaitForChild(RemoteNames.ClearAttempt) :: RemoteEvent
local StateChangedRemote = remotesFolder:WaitForChild(RemoteNames.StateChanged) :: RemoteEvent
local NotifyRemote = remotesFolder:WaitForChild(RemoteNames.Notify) :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- small helpers
--------------------------------------------------------------------------------

local function new(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function formatNumber(n: number): string
	n = math.floor(n)
	local suffixes = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, pair in ipairs(suffixes) do
		if n >= pair[1] then
			return string.format("%.2f%s", n / pair[1], pair[2])
		end
	end
	return tostring(n)
end

local UPGRADE_LABELS: { [string]: string } = {
	Capacity = "Nest Capacity",
	Income = "Income Multiplier",
	FeralResistance = "Feral Resistance",
}

--------------------------------------------------------------------------------
-- root gui
--------------------------------------------------------------------------------

local screenGui = new("ScreenGui", {
	Name = "GrowASwarmUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	Parent = playerGui,
}) :: ScreenGui

--------------------------------------------------------------------------------
-- toast notifications (defined early: shop/upgrade/rebirth buttons below use it)
--------------------------------------------------------------------------------

local toastContainer = new("Frame", {
	Name = "ToastContainer",
	Size = UDim2.new(0, 420, 0, 220),
	Position = UDim2.new(0.5, -210, 0, 64),
	BackgroundTransparency = 1,
	Parent = screenGui,
}) :: Frame

new("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Parent = toastContainer,
})

local TOAST_COLORS: { [string]: Color3 } = {
	info = Color3.fromRGB(60, 60, 70),
	success = Color3.fromRGB(50, 120, 60),
	warning = Color3.fromRGB(160, 120, 30),
	error = Color3.fromRGB(150, 50, 50),
}

local function showToast(text: string, kind: string)
	local label = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		Parent = toastContainer,
	}) :: TextLabel

	task.delay(4, function()
		label:Destroy()
	end)
end

NotifyRemote.OnClientEvent:Connect(function(text: string, kind: string)
	showToast(text, kind)
end)

-- RemoteFunctions (BuyCreature/BuyUpgrade/Rebirth) return {ok, error} directly
-- rather than going through a server Notify, since the caller already has the
-- result synchronously. Translate the error codes into readable text here.
local ERROR_MESSAGES: { [string]: string } = {
	CannotAfford = "You can't afford that yet.",
	NestFull = "Your nest is full -- upgrade capacity first.",
	LockedByRebirth = "Locked -- rebirth further to unlock this.",
	UnknownCreature = "That creature doesn't exist.",
	InvalidRequest = "Something went wrong with that request.",
	NoSession = "Your session isn't ready yet -- try again in a moment.",
	MaxLevel = "That upgrade is already maxed out.",
	MaxRebirthReached = "You've reached the maximum rebirth.",
	RequirementNotMet = "You haven't earned enough lifetime cash yet.",
}

local function showResultError(result: { ok: boolean, error: string? }?)
	if result and result.ok then
		return
	end
	local code = result and result.error
	showToast((code and ERROR_MESSAGES[code]) or code or "Something went wrong.", "error")
end

--------------------------------------------------------------------------------
-- top bar: cash / rebirths / status
--------------------------------------------------------------------------------

local topBar = new("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundColor3 = Color3.fromRGB(25, 25, 30),
	BackgroundTransparency = 0.1,
	Parent = screenGui,
}) :: Frame

local cashLabel = new("TextLabel", {
	Name = "CashLabel",
	Size = UDim2.new(0, 220, 1, 0),
	Position = UDim2.new(0, 12, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(120, 230, 120),
	Text = "$0",
	Parent = topBar,
}) :: TextLabel

local rebirthLabel = new("TextLabel", {
	Name = "RebirthLabel",
	Size = UDim2.new(0, 160, 1, 0),
	Position = UDim2.new(0, 240, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(200, 170, 255),
	Text = "Rebirths: 0",
	Parent = topBar,
}) :: TextLabel

local statusLabel = new("TextLabel", {
	Name = "StatusLabel",
	Size = UDim2.new(0, 260, 1, 0),
	Position = UDim2.new(1, -272, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(150, 220, 150),
	Text = "Nest: Healthy",
	Parent = topBar,
}) :: TextLabel

--------------------------------------------------------------------------------
-- shop panel (right side, scrolling list of creatures)
--------------------------------------------------------------------------------

local shopFrame = new("Frame", {
	Name = "ShopFrame",
	Size = UDim2.new(0, 300, 1, -160),
	Position = UDim2.new(1, -312, 0, 64),
	BackgroundColor3 = Color3.fromRGB(20, 20, 24),
	BackgroundTransparency = 0.15,
	Parent = screenGui,
}) :: Frame

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Swarm Shop",
	Parent = shopFrame,
})

local shopList = new("ScrollingFrame", {
	Name = "List",
	Size = UDim2.new(1, -8, 1, -32),
	Position = UDim2.new(0, 4, 0, 30),
	BackgroundTransparency = 1,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	Parent = shopFrame,
}) :: ScrollingFrame

new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = shopList,
})

--------------------------------------------------------------------------------
-- upgrades panel (left side)
--------------------------------------------------------------------------------

local upgradesFrame = new("Frame", {
	Name = "UpgradesFrame",
	Size = UDim2.new(0, 260, 0, 190),
	Position = UDim2.new(0, 12, 0, 64),
	BackgroundColor3 = Color3.fromRGB(20, 20, 24),
	BackgroundTransparency = 0.15,
	Parent = screenGui,
}) :: Frame

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Upgrades",
	Parent = upgradesFrame,
})

local upgradesList = new("Frame", {
	Name = "List",
	Size = UDim2.new(1, -8, 1, -32),
	Position = UDim2.new(0, 4, 0, 30),
	BackgroundTransparency = 1,
	Parent = upgradesFrame,
}) :: Frame

new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = upgradesList,
})

local upgradeButtons: { [string]: TextButton } = {}
for _, upgradeType in ipairs({ "Capacity", "Income", "FeralResistance" }) do
	local button = new("TextButton", {
		Name = upgradeType,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(50, 90, 160),
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = UPGRADE_LABELS[upgradeType],
		Parent = upgradesList,
	}) :: TextButton
	upgradeButtons[upgradeType] = button

	button.MouseButton1Click:Connect(function()
		showResultError(BuyUpgradeRemote:InvokeServer(upgradeType))
	end)
end

--------------------------------------------------------------------------------
-- action bar (bottom center): tend, clear infestation, rebirth
--------------------------------------------------------------------------------

local actionBar = new("Frame", {
	Name = "ActionBar",
	Size = UDim2.new(0, 560, 0, 64),
	Position = UDim2.new(0.5, -280, 1, -76),
	BackgroundTransparency = 1,
	Parent = screenGui,
}) :: Frame

new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = actionBar,
})

local tendButton = new("TextButton", {
	Name = "TendButton",
	Size = UDim2.new(0, 170, 1, 0),
	BackgroundColor3 = Color3.fromRGB(80, 150, 90),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Tend Nest",
	Parent = actionBar,
}) :: TextButton

tendButton.MouseButton1Click:Connect(function()
	TendNestRemote:FireServer()
end)

local clearButton = new("TextButton", {
	Name = "ClearButton",
	Size = UDim2.new(0, 170, 1, 0),
	BackgroundColor3 = Color3.fromRGB(180, 130, 40),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Clear Infestation",
	Visible = false,
	Parent = actionBar,
}) :: TextButton

local rebirthButton = new("TextButton", {
	Name = "RebirthButton",
	Size = UDim2.new(0, 200, 1, 0),
	BackgroundColor3 = Color3.fromRGB(140, 70, 200),
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Rebirth",
	Parent = actionBar,
}) :: TextButton

rebirthButton.MouseButton1Click:Connect(function()
	showResultError(RebirthRemote:InvokeServer())
end)

--------------------------------------------------------------------------------
-- infestation-clear minigame
--------------------------------------------------------------------------------

local ROUND_DURATION = 8

local minigameOverlay = new("Frame", {
	Name = "MinigameOverlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Visible = false,
	ZIndex = 10,
	Parent = screenGui,
}) :: Frame

local playArea = new("Frame", {
	Name = "PlayArea",
	Size = UDim2.new(0, 500, 0, 340),
	Position = UDim2.new(0.5, -250, 0.5, -170),
	BackgroundColor3 = Color3.fromRGB(35, 30, 20),
	ZIndex = 10,
	Parent = minigameOverlay,
}) :: Frame

local minigameLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 36),
	Position = UDim2.new(0, 0, 0, -40),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Squash the swarm! Click the bugs.",
	ZIndex = 10,
	Parent = playArea,
})

local minigameActive = false

local function runClearMinigame()
	if minigameActive then
		return
	end
	minigameActive = true
	minigameOverlay.Visible = true

	local hits = 0
	local startTime = os.clock()
	local roundOver = false
	local currentBug: TextButton? = nil

	local function clearCurrentBug()
		if currentBug then
			currentBug:Destroy()
			currentBug = nil
		end
	end

	local function spawnBug()
		clearCurrentBug()
		if roundOver then
			return
		end

		local size = 46
		local maxX = playArea.AbsoluteSize.X - size
		local maxY = playArea.AbsoluteSize.Y - size
		local x = math.random(0, math.max(0, math.floor(maxX)))
		local y = math.random(0, math.max(0, math.floor(maxY)))

		local bug = new("TextButton", {
			Size = UDim2.new(0, size, 0, size),
			Position = UDim2.new(0, x, 0, y),
			BackgroundColor3 = Color3.fromRGB(90, 160, 60),
			Text = "\u{1F41B}",
			Font = Enum.Font.SourceSansBold,
			TextScaled = true,
			ZIndex = 11,
			Parent = playArea,
		}) :: TextButton
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = bug

		currentBug = bug

		bug.MouseButton1Click:Connect(function()
			if roundOver or currentBug ~= bug then
				return
			end
			hits += 1
			spawnBug()
		end)
	end

	spawnBug()

	task.delay(ROUND_DURATION, function()
		roundOver = true
		clearCurrentBug()

		local duration = os.clock() - startTime
		minigameOverlay.Visible = false
		minigameActive = false

		ClearAttemptRemote:FireServer(hits, duration)
	end)
end

clearButton.MouseButton1Click:Connect(function()
	runClearMinigame()
end)

--------------------------------------------------------------------------------
-- state replication: rebuild dynamic panels whenever the server pushes state
--------------------------------------------------------------------------------

type ServerState = {
	cash: number,
	totalEarned: number,
	rebirths: number,
	ownedCreatures: { [string]: number },
	upgrades: { Capacity: number, Income: number, FeralResistance: number },
	isFeral: boolean,
	isInfested: boolean,
}

local function population(state: ServerState): number
	local total = 0
	for _, count in pairs(state.ownedCreatures) do
		total += count
	end
	return total
end

local function capacity(state: ServerState): number
	return Config.Swarm.BaseCapacity + Config.Swarm.CapacityPerUpgradeLevel * state.upgrades.Capacity
end

local shopButtons: { [string]: { button: TextButton, label: TextLabel } } = {}

local function buildShop()
	for _, def in ipairs(Config.Creatures) do
		local row = new("TextButton", {
			Name = def.Id,
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = Color3.fromRGB(45, 45, 55),
			AutoButtonColor = true,
			Text = "",
			Parent = shopList,
		}) :: TextButton

		local label = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "",
			Parent = row,
		}) :: TextLabel

		row.MouseButton1Click:Connect(function()
			showResultError(BuyCreatureRemote:InvokeServer(def.Id))
		end)

		shopButtons[def.Id] = { button = row, label = label }
	end
end
buildShop()

local function refreshShop(state: ServerState)
	local pop = population(state)
	local cap = capacity(state)
	for _, def in ipairs(Config.Creatures) do
		local entry = shopButtons[def.Id]
		local owned = state.ownedCreatures[def.Id] or 0
		local locked = state.rebirths < def.MinRebirths

		if locked then
			entry.label.Text = ("%s -- unlocks at rebirth %d"):format(def.Name, def.MinRebirths)
			entry.button.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		else
			local afford = state.cash >= def.Cost
			local full = pop >= cap
			entry.label.Text = ("%s [%s]  Income: $%.1f/s  Cost: $%s  Owned: %d"):format(
				def.Name,
				def.Rarity,
				def.IncomeRate,
				formatNumber(def.Cost),
				owned
			)
			if full then
				entry.button.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
			elseif afford then
				entry.button.BackgroundColor3 = Color3.fromRGB(45, 80, 45)
			else
				entry.button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
			end
		end
	end
end

local function refreshUpgrades(state: ServerState)
	for _, upgradeType in ipairs({ "Capacity", "Income", "FeralResistance" }) do
		local button = upgradeButtons[upgradeType]
		local level: number
		if upgradeType == "Capacity" then
			level = state.upgrades.Capacity
		elseif upgradeType == "Income" then
			level = state.upgrades.Income
		else
			level = state.upgrades.FeralResistance
		end

		local upgradeCfg = (Config.Upgrades :: any)[upgradeType]
		if level >= upgradeCfg.MaxLevel then
			button.Text = ("%s: MAX"):format(UPGRADE_LABELS[upgradeType])
			button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		else
			local cost = Config.GetUpgradeCost(upgradeType :: any, level)
			button.Text = ("%s (Lv %d) -- $%s"):format(UPGRADE_LABELS[upgradeType], level, formatNumber(cost))
			button.BackgroundColor3 = if state.cash >= cost
				then Color3.fromRGB(50, 110, 170)
				else Color3.fromRGB(50, 60, 80)
		end
	end
end

local function refreshRebirth(state: ServerState)
	local requirement = Config.Rebirth.Requirements[state.rebirths + 1]
	if requirement == nil then
		rebirthButton.Text = "Rebirth: MAX"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	else
		rebirthButton.Text = ("Rebirth (%s / %s)"):format(formatNumber(state.totalEarned), formatNumber(requirement))
		rebirthButton.BackgroundColor3 = if state.totalEarned >= requirement
			then Color3.fromRGB(160, 80, 220)
			else Color3.fromRGB(70, 55, 90)
	end
end

local function refreshTopBar(state: ServerState)
	cashLabel.Text = "$" .. formatNumber(state.cash)
	rebirthLabel.Text = "Rebirths: " .. tostring(state.rebirths)

	if state.isFeral then
		statusLabel.Text = "Nest: FERAL"
		statusLabel.TextColor3 = Color3.fromRGB(230, 90, 90)
	elseif state.isInfested then
		statusLabel.Text = "Nest: INFESTED"
		statusLabel.TextColor3 = Color3.fromRGB(230, 180, 90)
	else
		statusLabel.Text = ("Nest: Healthy (%d/%d)"):format(population(state), capacity(state))
		statusLabel.TextColor3 = Color3.fromRGB(150, 220, 150)
	end

	clearButton.Visible = state.isInfested
end

StateChangedRemote.OnClientEvent:Connect(function(state: ServerState)
	refreshTopBar(state)
	refreshShop(state)
	refreshUpgrades(state)
	refreshRebirth(state)
end)
