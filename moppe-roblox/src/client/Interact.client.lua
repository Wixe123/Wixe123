-- Walking around the garage: hover a part to see what it is, click to pick it up (it sits in your hand),
-- click a shelf, the bench, the floor, the vise or the paint stand to put it down. Prompts and the side menu
-- open the work modes; the side menu walks you to the station first.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PPS = game:GetService("ProximityPromptService")
local Shared = RS:WaitForChild("Shared")
local Parts = require(Shared.Parts)
local GarageBuilder = require(Shared.GarageBuilder)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local mouse = plr:GetMouse()

-- where each station is (garage-local) and which mode it opens
local STATIONS = {
	engine = Vector3.new(9, 3, -2.5), work = Vector3.new(-3, 3, -4), shop = Vector3.new(10.5, 3, 11),
	port = Vector3.new(17.5, 3, 8), paint = Vector3.new(17, 3, -5.5), jobs = Vector3.new(10.5, 3, 11), studio = Vector3.new(-3, 3, -4),
}
local PLACE = { shelf = "hylla", bench = "bank", floor = "golv", portbench = "port", booth = "lack" }
local PLACE_TEXT = { hylla = "lägga den på hyllan", bank = "lägga den på arbetsbänken", golv = "ställa den på golvet", port = "spänna fast den i skruvstädet", lack = "hänga den i lackboxen" }

local hl = Instance.new("Highlight")
hl.FillTransparency = 0.75
hl.OutlineColor = Color3.fromRGB(255, 255, 255)
hl.FillColor = Color3.fromRGB(74, 152, 255)
hl.DepthMode = Enum.HighlightDepthMode.Occluded
hl.Enabled = false
hl.Parent = workspace

local function ownerName(inst)
	local plot = inst:FindFirstAncestorWhichIsA("Folder")
	while plot and not plot:GetAttribute("Plot") do plot = plot.Parent and plot.Parent:IsA("Folder") and plot.Parent or nil end
	local id = plot and plot:GetAttribute("OwnerId")
	local owner = id and Players:GetPlayerByUserId(id)
	return owner and owner.DisplayName or "någon annan"
end
-- what is under the mouse: an item model (picked up by click) or a surface to put things on
local function target()
	local t = mouse.Target
	if not t then return nil end
	local m = t
	while m and m ~= workspace do
		if m:IsA("Model") and m:GetAttribute("Item") and not m:GetAttribute("Tool") and not m:GetAttribute("InHand") then return "item", m end
		if m:GetAttribute("Interact") then return "surface", m end
		m = m.Parent
	end
end
local function holding()
	local p = S.profile
	if not p then return nil end
	for id, it in pairs(p.items) do if it.loc == "hand" then return id, it end end
end
local function near(inst, dist)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local pos = inst:IsA("Model") and inst:GetPivot().Position or inst.Position
	return root and (root.Position - pos).Magnitude <= (dist or 14)
end

RunService.RenderStepped:Connect(function()
	if S.mode or S.menu or not S.profile then hl.Enabled = false; return end
	local kind, obj = target()
	local heldId, held = holding()
	if kind == "item" then
		hl.Adornee = obj
		hl.Enabled = true
		local part = Parts.get(obj:GetAttribute("Sku") or "")
		local name = part and part.name or "Del"
		if not S.isMine(obj) then S.tip(name .. " (tillhör " .. ownerName(obj) .. ")")
		elseif held then S.tip("Du bär redan " .. Parts.get(held.sku).name .. ". Lägg ner den först.")
		elseif not near(obj) then S.tip(name .. " – gå närmare")
		else S.tip("Klicka för att plocka upp " .. name) end
	elseif kind == "surface" and held and S.isMine(obj) then
		local loc = PLACE[obj:GetAttribute("Interact")]
		if loc then
			hl.Adornee = obj
			hl.Enabled = true
			S.tip("Klicka för att " .. PLACE_TEXT[loc] .. " (" .. Parts.get(held.sku).name .. ")")
		else
			hl.Enabled = false
			S.tip("Du bär " .. Parts.get(held.sku).name .. ". Klicka på hyllan, bänken eller golvet för att lägga ner den.")
		end
	else
		hl.Enabled = false
		if held then S.tip("Du bär " .. Parts.get(held.sku).name .. ". Klicka på hyllan, bänken eller golvet för att lägga ner den.")
		else S.tip(nil) end
	end
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp or S.mode or S.menu or not S.profile then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local kind, obj = target()
	if not kind or not S.isMine(obj) then return end
	if kind == "item" and not holding() then
		if near(obj) then S.api("pickup", obj:GetAttribute("Item")) else S.toast("Gå närmare", "info") end
	elseif kind == "surface" and holding() then
		local loc = PLACE[obj:GetAttribute("Interact")]
		if loc then
			if near(obj, 18) then S.api("place", loc) else S.toast("Gå närmare", "info") end
		end
	end
end)

-- prompts: the work modes open on the client after an ownership check
PPS.PromptTriggered:Connect(function(pp)
	local action = pp:GetAttribute("Action")
	local plotI = pp:GetAttribute("Plot")
	if S.menu or not action or action == "openBox" or action == "ride" or action == "mount" then return end
	if plotI and plotI ~= S.meta.plot then
		S.toast("Det här är " .. ownerName(pp) .. "s garage. Du kan titta men inte jobba här.", "info")
		return
	end
	S.open:Fire(action, true)
end)

-- side menu / buttons: walk to the station, then open
S.open.Event:Connect(function(what, atStation)
	if S.menu then return end
	if what == "ride" then
		if S.mode then return end
		S.walkTo(Vector3.new(-2, 3, -4), function() S.api("ride") end, 12)
		return
	end
	local st = STATIONS[what]
	if st and not atStation and not S.mode then
		S.walkTo(st, function() S.open:Fire(what, true) end, 7)
	end
end)

-- escape always leaves a work mode
UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and S.mode then
		-- a work mode may use Esc first (e.g. to put down the part in your hand)
		if S.escCapture and S.escCapture() then return end
		S.endMode()
	end
end)
