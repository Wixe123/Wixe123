--!strict
-- Tracks which plot belongs to which currently-connected player, and the
-- physical/visual side of that (billboard text, base color). Ownership is
-- purely in-memory: when a player leaves, their plot frees up immediately.
-- Their progress lives in DataStore via PlayerState, not in the physical plot.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)

local PLOT_TAG = "GrowASwarmPlot"

export type PlotHandle = {
	model: Model,
	base: BasePart,
	nest: BasePart,
	label: TextLabel,
}

local Module = {}

local plotByUserId: { [number]: PlotHandle } = {}

local function toHandle(model: Instance): PlotHandle?
	if not model:IsA("Model") then
		return nil
	end

	local baseInstance = model:FindFirstChild("Base")
	if not (baseInstance and baseInstance:IsA("BasePart")) then
		return nil
	end
	local base = baseInstance :: BasePart

	local nestInstance = model:FindFirstChild("Nest")
	if not (nestInstance and nestInstance:IsA("BasePart")) then
		return nil
	end
	local nest = nestInstance :: BasePart

	local billboard = nest:FindFirstChild("StatusBillboard")
	local labelInstance = billboard and billboard:FindFirstChild("Label")
	if not (labelInstance and labelInstance:IsA("TextLabel")) then
		return nil
	end
	local label = labelInstance :: TextLabel

	return { model = model :: Model, base = base, nest = nest, label = label }
end

function Module.AssignPlot(player: Player): PlotHandle?
	for _, tagged in ipairs(CollectionService:GetTagged(PLOT_TAG)) do
		if tagged:GetAttribute("OwnerUserId") == 0 then
			local handle = toHandle(tagged)
			if handle then
				tagged:SetAttribute("OwnerUserId", player.UserId)
				plotByUserId[player.UserId] = handle
				Module.SetVisualState(player.UserId, false, false, player.Name)
				return handle
			end
		end
	end
	warn("[GrowASwarm] No free plot available for " .. player.Name .. " -- raise Config.Plot.Count")
	return nil
end

function Module.FreePlot(userId: number)
	local handle = plotByUserId[userId]
	if not handle then
		return
	end
	handle.model:SetAttribute("OwnerUserId", 0)
	handle.model:SetAttribute("IsFeral", false)
	handle.model:SetAttribute("IsInfested", false)
	handle.base.Color = Color3.fromRGB(90, 130, 80)
	handle.label.Text = "Empty Plot"
	plotByUserId[userId] = nil
end

function Module.GetPlot(userId: number): PlotHandle?
	return plotByUserId[userId]
end

-- Every userId currently occupying a plot in this server, i.e. valid targets
-- for infestation spread and neighbor lookups.
function Module.GetOnlineOwnedUserIds(): { number }
	local ids = {}
	for userId in pairs(plotByUserId) do
		table.insert(ids, userId)
	end
	return ids
end

function Module.IsPlayerNearOwnNest(player: Player): boolean
	local handle = plotByUserId[player.UserId]
	if not handle then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - handle.nest.Position).Magnitude <= Config.Plot.NestInteractRadius
end

function Module.SetVisualState(userId: number, isFeral: boolean, isInfested: boolean, ownerName: string?)
	local handle = plotByUserId[userId]
	if not handle then
		return
	end
	handle.model:SetAttribute("IsFeral", isFeral)
	handle.model:SetAttribute("IsInfested", isInfested)

	local status = "Healthy"
	local color = Color3.fromRGB(90, 130, 80)
	if isFeral then
		status = "FERAL SWARM"
		color = Color3.fromRGB(130, 40, 40)
	elseif isInfested then
		status = "INFESTED"
		color = Color3.fromRGB(150, 115, 30)
	end

	handle.base.Color = color
	handle.label.Text = (ownerName or "Player") .. "\n" .. status
end

return Module
