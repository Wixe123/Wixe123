--!strict
-- Procedurally builds the plots at server start. There's no hand-built level to
-- sync from Studio here, so the game constructs its own map on boot. Idempotent:
-- if plots tagged "GrowASwarmPlot" already exist (e.g. a dev later hand-builds
-- nicer plots in Studio and tags them), this does nothing and defers to those.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)

local PLOT_TAG = "GrowASwarmPlot"
local BASE_HEIGHT = 1

local Module = {}

local function buildOnePlot(index: number, gridPos: Vector3): Model
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. tostring(index)

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = true
	base.Size = Config.Plot.Size
	base.CFrame = CFrame.new(gridPos.X, BASE_HEIGHT / 2, gridPos.Z)
	base.Color = Color3.fromRGB(90, 130, 80)
	base.Material = Enum.Material.Grass
	base.Parent = plot

	local nest = Instance.new("Part")
	nest.Name = "Nest"
	nest.Anchored = true
	nest.CanCollide = false
	nest.Shape = Enum.PartType.Cylinder
	nest.Size = Vector3.new(2, 6, 6)
	nest.Color = Color3.fromRGB(120, 90, 60)
	nest.Material = Enum.Material.Wood
	nest.CFrame = base.CFrame * CFrame.new(0, BASE_HEIGHT / 2 + 3, 0) * CFrame.Angles(0, 0, math.rad(90))
	nest.Parent = plot

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatusBillboard"
	billboard.Size = UDim2.new(0, 200, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = nest
	billboard.Parent = nest

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Empty Plot"
	label.Parent = billboard

	plot.PrimaryPart = base
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("IsFeral", false)
	plot:SetAttribute("IsInfested", false)

	CollectionService:AddTag(plot, PLOT_TAG)

	return plot
end

function Module.EnsurePlotsExist()
	if #CollectionService:GetTagged(PLOT_TAG) > 0 then
		return
	end

	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "Plots"
		plotsFolder.Parent = Workspace
	end

	local count = Config.Plot.Count
	local columns = math.ceil(math.sqrt(count))
	local step = Config.Plot.Size.X + Config.Plot.Gap

	for i = 1, count do
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		local gridPos = Vector3.new(col * step, 0, row * step)
		local plot = buildOnePlot(i, gridPos)
		plot.Parent = plotsFolder
	end

	if not Workspace:FindFirstChildOfClass("SpawnLocation") then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "GrowASwarmSpawn"
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.CFrame = CFrame.new(-step, BASE_HEIGHT / 2, -step)
		spawn.Color = Color3.fromRGB(150, 150, 160)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Duration = 0
		spawn.Parent = Workspace
	end
end

return Module
