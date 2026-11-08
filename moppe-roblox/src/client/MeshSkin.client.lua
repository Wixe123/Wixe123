-- Gives every moped in the world smooth 3D panels. The server builds panels from blocks (they are the
-- click targets and the fallback); this client builds a MeshPart for each panel with EditableMesh, shows it
-- with the panel's paint, and hides the blocks locally. If Roblox refuses EditableMesh, the blocks stay.
local RS = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local Shared = RS:WaitForChild("Shared")
local MeshGen = require(Shared.MeshGen)
local MopedDef = require(Shared.MopedDef)

local templates = {} -- "model/panel" -> { part = MeshPart, center, size } or false
local disabled = false

local function template(model, panel)
	local key = model .. "/" .. panel
	if templates[key] ~= nil then return templates[key] end
	templates[key] = false
	if disabled then return false end
	local data = MeshGen.panel(model, panel)
	if not data then return false end
	local ok, res = pcall(function()
		local em = AssetService:CreateEditableMesh()
		local ids = {}
		for i, v in ipairs(data.verts) do ids[i] = em:AddVertex(v) end
		for _, t in ipairs(data.tris) do em:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]]) end
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		return part
	end)
	if not ok or not res then
		disabled = true
		warn("Moppe: släta kåpor gick inte att skapa (EditableMesh), visar block i stället: " .. tostring(res))
		return false
	end
	res.Name = "Kåpa3D"
	res.Anchored = true
	res.CanCollide = false
	res.CanQuery = false
	res.CanTouch = false
	res.CastShadow = true
	templates[key] = { part = res, center = data.center, size = data.size }
	return templates[key]
end

local function skin(moped)
	if moped:GetAttribute("Skinned") then return end
	local modelId = moped:GetAttribute("Model")
	local def = modelId and MopedDef.MODELS[modelId]
	local root = moped.PrimaryPart
	if not (def and root) then return end
	moped:SetAttribute("Skinned", true)
	local rootCF = root.CFrame * CFrame.new(0, -def.r, 0)
	for _, sub in ipairs(moped:GetChildren()) do
		local panel = sub:IsA("Model") and sub.Name:match("^pan:(.+)$")
		if panel then
			local t = template(modelId, panel)
			if t then
				local blocks = {}
				for _, d in ipairs(sub:GetDescendants()) do
					if d:IsA("BasePart") and d:GetAttribute("Panel") then blocks[#blocks + 1] = d end
				end
				local paintFrom = blocks[1]
				local mp = t.part:Clone()
				mp.Size = t.size
				mp.CFrame = rootCF * CFrame.new(t.center)
				if paintFrom then
					mp.Color = paintFrom.Color
					mp.Material = paintFrom.Material
					mp.Reflectance = paintFrom.Reflectance
				end
				-- welded to the root so it follows when the moped is ridden (anchored root keeps it still)
				mp.Anchored = false
				mp.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = mp
				w.Parent = mp
				mp.Parent = sub
				for _, b in ipairs(blocks) do b.LocalTransparencyModifier = 1 end
			end
		end
	end
end

local function watch(inst)
	if inst:IsA("Model") and inst.Name == "Moped" and inst:IsDescendantOf(workspace) then
		-- wait until the server has filled the model
		task.delay(0.3, function() if inst.Parent then skin(inst) end end)
	end
end
workspace.DescendantAdded:Connect(watch)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end
