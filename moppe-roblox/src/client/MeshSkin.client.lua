-- Gives every moped in the world smooth 3D panels. The server builds panels from blocks (they are the
-- click targets and the fallback); this client builds a MeshPart for each panel with EditableMesh, shows it
-- with the panel's paint, and hides the blocks locally. If Roblox refuses EditableMesh, the blocks stay.
local RS = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local Shared = RS:WaitForChild("Shared")
local MeshGen = require(Shared.MeshGen)
local MopedDef = require(Shared.MopedDef)
local EngineDef = require(Shared.EngineDef)
local AeroxMesh = require(Shared.AeroxMesh)

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

---------------------------------------------------------------- the full Aerox body (imported model) for a complete Sprint
local CLASS_LOOK = {
	seat = { Color3.fromRGB(24, 24, 26), Enum.Material.Leather, 0 },
	dark = { Color3.fromRGB(34, 34, 37), Enum.Material.SmoothPlastic, 0.02 },
	metal = { Color3.fromRGB(172, 176, 182), Enum.Material.Metal, 0.1 },
	ex = { Color3.fromRGB(62, 62, 66), Enum.Material.Metal, 0.05 },
	tire = { Color3.fromRGB(22, 22, 24), Enum.Material.Rubber, 0 },
	rim = { Color3.fromRGB(40, 40, 44), Enum.Material.Metal, 0.05 },
	disc = { Color3.fromRGB(205, 210, 216), Enum.Material.Metal, 0.2 },
}
local body = nil -- list of { part, class, center } or false
local function bodyTemplates()
	if body ~= nil then return body end
	body = false
	if disabled then return false end
	local list = {}
	local ok, err = pcall(function()
		for cls, chunks in pairs(AeroxMesh.classes) do
			for _, chunk in ipairs(chunks) do
				local verts, tris = AeroxMesh.decode(chunk)
				local mn, mx = verts[1], verts[1]
				for _, v in ipairs(verts) do mn = mn:Min(v); mx = mx:Max(v) end
				local center = (mn + mx) / 2
				local em = AssetService:CreateEditableMesh()
				local ids = {}
				for i, v in ipairs(verts) do ids[i] = em:AddVertex(v - center) end
				for _, t in ipairs(tris) do em:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]]) end
				local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
				part.Name = "Aerox_" .. cls
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				list[#list + 1] = { part = part, class = cls, center = center, size = mx - mn }
			end
		end
	end)
	if not ok then
		disabled = true
		warn("Moppe: Aerox-modellen gick inte att skapa (EditableMesh), visar delarna i stället: " .. tostring(err))
		return false
	end
	body = list
	return body
end
-- complete = every chassis slot, every panel and all 29 engine parts are on (seen from the model itself)
local function isComplete(moped, def)
	local have = {}
	for _, c in ipairs(moped:GetChildren()) do
		local slot = c:GetAttribute("Slot")
		if slot then have[slot] = c end
	end
	for _, s in ipairs(MopedDef.SLOTS) do if not have[s.id] then return false end end
	for _, p in ipairs(def.panels) do if not have["pan:" .. p.id] then return false end end
	local eng = have.motor
	return eng ~= nil and #eng:GetChildren() >= #EngineDef.SOCKETS
end
local function hideBlocks(moped)
	for _, d in ipairs(moped:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Name ~= "Seat" then d.LocalTransparencyModifier = 1 end
	end
end
local function skinAerox(moped, root, rootCF)
	local list = bodyTemplates()
	if not list then return false end
	-- paint from the left side panel (the main colour of the body)
	local paint
	local side = moped:FindFirstChild("pan:sidaV")
	for _, d in ipairs(side and side:GetDescendants() or {}) do if d:IsA("BasePart") then paint = d; break end end
	hideBlocks(moped)
	local holder = Instance.new("Model")
	holder.Name = "Aerox3D"
	for _, e in ipairs(list) do
		local mp = e.part:Clone()
		mp.Size = e.size
		mp.CFrame = rootCF * CFrame.new(e.center)
		if e.class == "paint" and paint then
			mp.Color, mp.Material, mp.Reflectance = paint.Color, paint.Material, paint.Reflectance
		else
			local look = CLASS_LOOK[e.class] or CLASS_LOOK.dark
			mp.Color, mp.Material, mp.Reflectance = look[1], look[2], look[3]
		end
		mp.Anchored = false
		mp.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = mp
		w.Parent = mp
		mp.Parent = holder
	end
	holder.Parent = moped
	return true
end

local function skin(moped)
	if moped:GetAttribute("Skinned") then return end
	local modelId = moped:GetAttribute("Model")
	local def = modelId and MopedDef.MODELS[modelId]
	local root = moped.PrimaryPart
	if not (def and root) then return end
	moped:SetAttribute("Skinned", true)
	local rootCF = root.CFrame * CFrame.new(0, -def.r, 0)
	-- a complete Sprint gets the detailed imported body; anything taken apart shows its parts
	if modelId == "sprint" and isComplete(moped, def) and skinAerox(moped, root, rootCF) then return end
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
