--// Forge Core (OPTIMAL) - CACHED SCAN + ORE-STRICT + CONSTRAINT LOCK
--// Drop as a LocalScript (client). Keeps _G.DATA / _G.Settings compatibility for your GUI.

-- ========= SERVICES =========
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local CAMERA_BIND_NAME = "Forge_CameraFollow_Optim"

-- ========= DEBUG =========
_G.ForgeDebug = (_G.ForgeDebug ~= nil) and _G.ForgeDebug or false
local function D(tag, msg, extra)
	if not _G.ForgeDebug then return end
	local pfx = ("[ForgeDBG:%s] "):format(tag)
	if extra ~= nil then
		warn(pfx .. msg .. " | " .. tostring(extra))
	else
		warn(pfx .. msg)
	end
end

local function boolCount(map)
	if type(map) ~= "table" then
		return false, 0
	end
	local any, count = false, 0
	for _, v in pairs(map) do
		if v == true then
			any = true
			count += 1
		end
	end
	return any, count
end

-- ========= ANTI DOUBLE LOAD =========
if _G.__ForgeCoreLoaded_OPT then
	warn("[!] Forge Core OPT already loaded.")
	return
end
_G.__ForgeCoreLoaded_OPT = true

-- ========= DATA =========
local DATA = {
	Zones = {
    -- Zona Island2 yang sudah ada
    "Island2CaveDanger1", "Island2CaveDanger2", "Island2CaveDanger3",
    "Island2CaveDanger4", "Island2CaveDangerClosed", "Island2CaveDeep",
    "Island2CaveLavaClosed", "Island2CaveMid", "Island2CaveStart",
    "Island2GoblinCave", "Island2VolcanicDepths", "Iceberg",
	"Island3CavePeakEnd", "Island3CavePeakLeft", "Island3CavePeakRight",
	"Island3CavePeakStart", "Island3RedCave", "Island3SpiderCaveMid",
	"Island3SpiderCaveMid0", "Island3SpiderCaveMid2", "Island3SpiderCaveStart",
	"Island3SpiderCaveStart0", "Island3SpiderCaveStart2",
	},
	Rocks = {
    "Basalt", "Basalt Core", "Basalt Rock", "Basalt Vein", "Boulder",
    "Crimson Crystal", "Cyan Crystal", "Earth Crystal", "Floating Crystal",
    "Heart Of The Island", "Iceberg", "Icy Boulder", "Icy Pebble", "Icy Rock",
    "Large Ice Crystal", "Lava Rock", "Light Crystal", "Lucky Block",
    "Medium Ice Crystal", "Pebble", "Rock", "Small Ice Crystal",
    "Violet Crystal", "Volcanic Rock",
	},
	Ores = {
    "Aether Lotus", "Aetherit", "Aite", "Amethyst", "Aqujade",
    "Arcane Crystal", "Bananite", "Blue Crystal", "Boneite", "Cardboardite",
    "Ceyite", "Cobalt", "Coinite", "Copper", "Crimson Crystal",
    "Crimsonite", "Cryptex", "Cuprite", "Dark Boneite", "Darkryte",
    "Demonite", "Diamond", "Emerald", "Eye Ore", "Fichillium",
    "Fichilliumorite", "Fireite", "Galaxite", "Galestor", "Gargantuan",
    "Gold", "Graphite", "Grass", "Green Crystal", "Heavenite",
    "Iceite", "Iron", "Jade", "Lapis Lazuli", "Larimar",
    "Lgarite", "Lightite", "Magenta Crystal", "Magmaite", "Malachite",
    "Marblite", "Meteorite", "Mistvein", "Moltenfrost", "Mosasaursit",
    "Mushroomite", "Mythril", "Neurotite", "Obsidian", "Orange Crystal",
    "Platinum", "Poopite", "Pumice", "Quartz", "Rainbow Crystal",
    "Rivalite", "Ruby", "Sanctis", "Sand Stone", "Sapphire",
    "Scheelite", "Silver", "Slimite", "Snowite", "Starite",
    "Stone", "Tin", "Titanium", "Topaz", "Uranium", "Volcanic Rock",
	},
}

-- Export for GUI compatibility
_G.DATA = _G.DATA or DATA

-- ========= SETTINGS =========
_G.Settings = _G.Settings or {}
local Settings = _G.Settings
Settings.Zones = Settings.Zones or {}
Settings.Rocks = Settings.Rocks or {}
Settings.Ores  = Settings.Ores  or {}

local function setDefault(k, v)
	if Settings[k] == nil then Settings[k] = v end
end

-- Base
setDefault("AutoFarm", false)
setDefault("TweenSpeed", 55)          -- faster default; scanning is cheap now
setDefault("YOffset", 3)              -- safer (avoid being inside rock)
setDefault("CheckThreshold", 45)      -- % HP
setDefault("ScanInterval", 0.12)      -- cheap now; can be lower
setDefault("HitInterval", 0.12)
setDefault("TargetStickTime", 0.25)
setDefault("ArriveDistance", 2.25)    -- studs: when considered "already at target"
setDefault("RetweenDistance", 6)      -- studs: re-tween if drifted

-- Selection behavior
setDefault("AllowAllZonesIfNoneSelected", true)
setDefault("AllowAllRocksIfNoneSelected", true)
setDefault("AllowAllOresIfNoneSelected", true)

-- ORE-STRICT: if any ore is selected, target MUST match those ores
setDefault("RequireOreMatchWhenSelected", true)

-- Lock mode
setDefault("LockToTarget", true)
setDefault("LockMode", "Constraint")  -- "Constraint" (recommended) or "Hard"
setDefault("LockVelocityZero", true)
setDefault("AnchorDuringLock", false) -- only used in "Hard" mode (kept for compatibility)
setDefault("KeepNoclipWhileLocked", true)

-- Constraint lock tuning
setDefault("ConstraintResponsiveness", 200)
setDefault("ConstraintMaxForce", 1e9)

-- Camera
setDefault("CameraStabilize", true)
setDefault("CameraSmoothAlpha", 1)
setDefault("CameraOffsetMode", "World") -- "World" or "Relative"
setDefault("CameraOffset", Vector3.new(0, 10, 18))

-- init checkbox keys
for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- ========= CHARACTER UTILS =========
local function GetChar()
	local c = Player.Character
	if not c or not c.Parent then return nil end
	return c
end

local function GetHumanoid()
	local c = GetChar()
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

local function GetCharAndRoot()
	local c = GetChar()
	if not c then return nil, nil end
	local r = c:FindFirstChild("HumanoidRootPart")
	return c, r
end

-- ========= NOCLIP =========
local noclipConn, descConn
local partsSet = {}
local originalCollide = {}

local function cacheCharacterParts(c)
	table.clear(partsSet)
	table.clear(originalCollide)
	if not c then return end
	for _, inst in ipairs(c:GetDescendants()) do
		if inst:IsA("BasePart") then
			partsSet[inst] = true
			originalCollide[inst] = inst.CanCollide
		end
	end
end

local function enableNoclip()
	if noclipConn then return end

	local c = Player.Character
	cacheCharacterParts(c)

	if descConn then descConn:Disconnect() end
	if c then
		descConn = c.DescendantAdded:Connect(function(inst)
			if inst:IsA("BasePart") then
				partsSet[inst] = true
				if originalCollide[inst] == nil then
					originalCollide[inst] = inst.CanCollide
				end
				inst.CanCollide = false
			end
		end)
	end

	local stepSignal = RunService.PreSimulation or RunService.Stepped
	noclipConn = stepSignal:Connect(function()
		for part in pairs(partsSet) do
			if part and part.Parent then
				part.CanCollide = false
			else
				partsSet[part] = nil
				originalCollide[part] = nil
			end
		end
	end)
end

local function disableNoclip()
	if noclipConn then noclipConn:Disconnect() end
	if descConn then descConn:Disconnect() end
	noclipConn, descConn = nil, nil

	for part, was in pairs(originalCollide) do
		if part and part.Parent then
			part.CanCollide = was
		end
	end
	table.clear(partsSet)
	table.clear(originalCollide)
end

Player.CharacterAdded:Connect(function()
	D("CHAR", "CharacterAdded -> reset")
	disableNoclip()
end)

-- ========= CAMERA STABILIZER =========
local camPrevType = nil
local camPrevSubject = nil

local function StopCameraStabilize()
	pcall(function()
		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	end)

	local cam = Workspace.CurrentCamera
	if cam then
		if camPrevType then cam.CameraType = camPrevType end
		if camPrevSubject then cam.CameraSubject = camPrevSubject end
	end

	camPrevType = nil
	camPrevSubject = nil
end

local function StartCameraStabilize()
	if not Settings.CameraStabilize then
		StopCameraStabilize()
		return
	end

	local cam = Workspace.CurrentCamera
	local _, r = GetCharAndRoot()
	if not (cam and r) then return end

	pcall(function()
		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	end)

	camPrevType = cam.CameraType
	camPrevSubject = cam.CameraSubject

	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local cam2 = Workspace.CurrentCamera
		local _, r2 = GetCharAndRoot()
		if not (cam2 and r2) then return end

		cam2.CameraType = Enum.CameraType.Scriptable

		local alpha = math.clamp(tonumber(Settings.CameraSmoothAlpha) or 1, 0, 1)
		local offset = Settings.CameraOffset or Vector3.new(0, 10, 18)

		local desiredPos
		if Settings.CameraOffsetMode == "Relative" then
			desiredPos = (r2.CFrame * CFrame.new(offset)).Position
		else
			desiredPos = r2.Position + offset
		end

		local desired = CFrame.new(desiredPos, r2.Position)
		if alpha >= 0.999 then
			cam2.CFrame = desired
		else
			cam2.CFrame = cam2.CFrame:Lerp(desired, alpha)
		end
	end)
end

-- ========= TOOL REMOTE =========
local toolActivatedRF = nil
local lastHit = 0

local function ResolveToolActivated()
	toolActivatedRF = nil
	local shared = ReplicatedStorage:FindFirstChild("Shared"); if not shared then return end
	local packages = shared:FindFirstChild("Packages"); if not packages then return end
	local knit = packages:FindFirstChild("Knit"); if not knit then return end
	local services = knit:FindFirstChild("Services"); if not services then return end
	local toolService = services:FindFirstChild("ToolService"); if not toolService then return end
	local rf = toolService:FindFirstChild("RF"); if not rf then return end

	local toolActivated = rf:FindFirstChild("ToolActivated")
	if toolActivated and toolActivated:IsA("RemoteFunction") then
		toolActivatedRF = toolActivated
	end
end

local function HitPickaxe()
	local now = os.clock()
	if (now - lastHit) < (Settings.HitInterval or 0.12) then return end
	lastHit = now

	if (not toolActivatedRF) or (not toolActivatedRF.Parent) then
		ResolveToolActivated()
	end
	if not toolActivatedRF then return end

	task.defer(function()
		pcall(function()
			toolActivatedRF:InvokeServer("Pickaxe")
		end)
	end)
end

-- ========= TARGET PART PICKER =========
local function PickTargetPartFromRockModel(rockModel)
	local pp = rockModel.PrimaryPart
	if pp and pp:IsA("BasePart") then return pp end

	local hb = rockModel:FindFirstChild("Hitbox")
	if hb and hb:IsA("BasePart") then return hb end

	for _, inst in ipairs(rockModel:GetDescendants()) do
		if inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

-- ========= ORE HELPERS =========
local function AnyOreSelected()
	return select(1, boolCount(Settings.Ores))
end

local function GetOreType(rockModel)
	for _, child in ipairs(rockModel:GetChildren()) do
		if child.Name == "Ore" then
			local oreType = child:GetAttribute("Ore")
			if oreType ~= nil then
				return oreType
			end
		end
	end
	return nil
end

local function RockMatchesOreSelection(rockModel, cachedOreType)
	local oresAny = AnyOreSelected()
	local allowAllOres = (Settings.AllowAllOresIfNoneSelected == true) and (not oresAny)
	if allowAllOres then return true end
	local oreType = cachedOreType or GetOreType(rockModel)
	return oreType ~= nil and Settings.Ores[oreType] == true
end

-- ========= VALIDATION =========
local function IsRockAliveEnough(rockModel)
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end

	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local curHP = hp or maxHP
	local pct = (maxHP > 0) and ((curHP / maxHP) * 100) or 100

	if pct > (Settings.CheckThreshold or 45) then
		return true
	end

	-- below threshold: allow only if ore matches (or no ore filtering)
	if Settings.RequireOreMatchWhenSelected and AnyOreSelected() then
		return true -- ore match handled earlier; if we got here, it's fine to finish it
	end
	return true
end

-- ========= ROCK CACHE (EVENT-DRIVEN) =========
local RockIndex = {
	entries = {},    -- array of entry
	byModel = {},    -- [Model] = entry
	conns = {},
}

function RockIndex:_removeModel(model)
	local e = self.byModel[model]
	if not e then return end

	self.byModel[model] = nil

	if e._ancConn then e._ancConn:Disconnect() end
	if e._childConn then e._childConn:Disconnect() end
	if e._childRemConn then e._childRemConn:Disconnect() end

	local idx = e._idx
	local last = self.entries[#self.entries]
	if last and idx and self.entries[idx] == e then
		self.entries[idx] = last
		last._idx = idx
	end
	self.entries[#self.entries] = nil
end

function RockIndex:_upsertModel(model, zoneName)
	if not (model and model:IsA("Model")) then return end

	-- Heuristic: rock models have HP attributes (based on your script)
	local hp = model:GetAttribute("Health")
	local maxHP = model:GetAttribute("MaxHealth")
	if hp == nil and maxHP == nil then
		return
	end

	local e = self.byModel[model]
	if not e then
		e = {
			model = model,
			zoneName = zoneName,
			oreType = GetOreType(model),
			part = PickTargetPartFromRockModel(model),
			_idx = #self.entries + 1,
		}
		self.byModel[model] = e
		self.entries[e._idx] = e

		e._ancConn = model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:_removeModel(model)
			end
		end)

		-- track ore changes cheaply
		e._childConn = model.ChildAdded:Connect(function(ch)
			if ch.Name == "Ore" then
				e.oreType = GetOreType(model)
			end
		end)
		e._childRemConn = model.ChildRemoved:Connect(function(ch)
			if ch.Name == "Ore" then
				e.oreType = GetOreType(model)
			end
		end)
	else
		e.zoneName = zoneName
		e.oreType = GetOreType(model)
		-- part will be refreshed lazily on selection if nil/invalid
	end
end

function RockIndex:_indexZone(zoneFolder)
	-- Initial scan ONCE per zone
	for _, inst in ipairs(zoneFolder:GetDescendants()) do
		if inst:IsA("Model") then
			self:_upsertModel(inst, zoneFolder.Name)
		end
	end

	local addConn = zoneFolder.DescendantAdded:Connect(function(inst)
		if inst:IsA("Model") then
			self:_upsertModel(inst, zoneFolder.Name)
		end
	end)

	local remConn = zoneFolder.DescendantRemoving:Connect(function(inst)
		if inst:IsA("Model") then
			self:_removeModel(inst)
		end
	end)

	table.insert(self.conns, addConn)
	table.insert(self.conns, remConn)
end

function RockIndex:Init()
	local rocksFolder = Workspace:FindFirstChild("Rocks")
	if not rocksFolder then
		local wsConn
		wsConn = Workspace.ChildAdded:Connect(function(ch)
			if ch.Name == "Rocks" then
				wsConn:Disconnect()
				self:Init()
			end
		end)
		table.insert(self.conns, wsConn)
		return
	end

	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") then
			self:_indexZone(zone)
		end
	end

	local zConn = rocksFolder.ChildAdded:Connect(function(ch)
		if ch:IsA("Folder") then
			self:_indexZone(ch)
		end
	end)
	table.insert(self.conns, zConn)
end

RockIndex:Init()

-- ========= LOCK CONTROLLER (CONSTRAINT RECOMMENDED) =========
local lockConn = nil
local lockRoot = nil
local lockCFrame = nil
local lockHum = nil

-- restore
local prevPlatformStand = nil
local prevAutoRotate = nil
local prevAnchored = nil
local prevWalkSpeed = nil
local prevJumpPower = nil

-- constraint objects
local lockTargetPart = nil
local rootAtt = nil
local targetAtt = nil
local alignPos = nil
local alignOri = nil

local function DestroyConstraintLock()
	if alignPos then alignPos:Destroy() end
	if alignOri then alignOri:Destroy() end
	if rootAtt then rootAtt:Destroy() end
	if lockTargetPart then lockTargetPart:Destroy() end
	alignPos, alignOri, rootAtt, targetAtt, lockTargetPart = nil, nil, nil, nil, nil
end

local function StopLock()
	if lockConn then lockConn:Disconnect() end
	lockConn = nil
	lockCFrame = nil

	DestroyConstraintLock()

	if lockRoot and lockRoot.Parent then
		if prevAnchored ~= nil then
			lockRoot.Anchored = prevAnchored
		end
	end

	if lockHum and lockHum.Parent then
		if prevPlatformStand ~= nil then lockHum.PlatformStand = prevPlatformStand end
		if prevAutoRotate ~= nil then lockHum.AutoRotate = prevAutoRotate end
		if prevWalkSpeed ~= nil then lockHum.WalkSpeed = prevWalkSpeed end
		if prevJumpPower ~= nil then lockHum.JumpPower = prevJumpPower end
	end

	lockRoot, lockHum = nil, nil
	prevPlatformStand, prevAutoRotate, prevAnchored = nil, nil, nil
	prevWalkSpeed, prevJumpPower = nil, nil
end

local function StartConstraintLock(rootPart, cf)
	lockRoot = rootPart
	lockCFrame = cf
	lockHum = GetHumanoid()

	if lockHum then
		prevAutoRotate = lockHum.AutoRotate
		prevWalkSpeed = lockHum.WalkSpeed
		prevJumpPower = lockHum.JumpPower
		prevPlatformStand = lockHum.PlatformStand

		-- soft freeze
		lockHum.PlatformStand = false
		lockHum.AutoRotate = false
		lockHum.WalkSpeed = 0
		lockHum.JumpPower = 0
	end

	if lockRoot then
		prevAnchored = lockRoot.Anchored
		lockRoot.Anchored = false
		lockRoot.AssemblyLinearVelocity = Vector3.zero
		lockRoot.AssemblyAngularVelocity = Vector3.zero
	end

	lockTargetPart = Instance.new("Part")
	lockTargetPart.Name = "Forge_LockTarget"
	lockTargetPart.Size = Vector3.new(0.2, 0.2, 0.2)
	lockTargetPart.Anchored = true
	lockTargetPart.CanCollide = false
	lockTargetPart.CanQuery = false
	lockTargetPart.CanTouch = false
	lockTargetPart.Transparency = 1
	lockTargetPart.CFrame = cf
	lockTargetPart.Parent = Workspace

	rootAtt = Instance.new("Attachment")
	rootAtt.Name = "Forge_RootAtt"
	rootAtt.Parent = lockRoot

	targetAtt = Instance.new("Attachment")
	targetAtt.Name = "Forge_TargetAtt"
	targetAtt.Parent = lockTargetPart

	alignPos = Instance.new("AlignPosition")
	alignPos.Name = "Forge_AlignPos"
	alignPos.Attachment0 = rootAtt
	alignPos.Attachment1 = targetAtt
	alignPos.RigidityEnabled = true
	alignPos.Responsiveness = tonumber(Settings.ConstraintResponsiveness) or 200
	alignPos.MaxForce = tonumber(Settings.ConstraintMaxForce) or 1e9
	alignPos.Parent = lockRoot

	alignOri = Instance.new("AlignOrientation")
	alignOri.Name = "Forge_AlignOri"
	alignOri.Attachment0 = rootAtt
	alignOri.Attachment1 = targetAtt
	alignOri.RigidityEnabled = true
	alignOri.Responsiveness = tonumber(Settings.ConstraintResponsiveness) or 200
	alignOri.MaxTorque = tonumber(Settings.ConstraintMaxForce) or 1e9
	alignOri.Parent = lockRoot

	-- lightweight: just keep velocity zeroed if requested
	if lockConn then lockConn:Disconnect() end
	if Settings.LockVelocityZero then
		local stepSignal = RunService.PreSimulation or RunService.Stepped
		lockConn = stepSignal:Connect(function()
			if lockRoot and lockRoot.Parent then
				lockRoot.AssemblyLinearVelocity = Vector3.zero
				lockRoot.AssemblyAngularVelocity = Vector3.zero
			end
		end)
	end
end

local function StartHardLock(rootPart, cf)
	lockRoot = rootPart
	lockCFrame = cf
	lockHum = GetHumanoid()

	if lockHum then
		prevPlatformStand = lockHum.PlatformStand
		prevAutoRotate = lockHum.AutoRotate
		lockHum.PlatformStand = true
		lockHum.AutoRotate = false
	end

	if lockRoot then
		prevAnchored = lockRoot.Anchored
		if Settings.AnchorDuringLock then
			lockRoot.Anchored = true
		end
	end

	if lockConn then lockConn:Disconnect() end
	local stepSignal = RunService.PreSimulation or RunService.Stepped
	lockConn = stepSignal:Connect(function()
		if not (lockRoot and lockRoot.Parent and lockCFrame) then return end
		lockRoot.CFrame = lockCFrame
		if Settings.LockVelocityZero then
			lockRoot.AssemblyLinearVelocity = Vector3.zero
			lockRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

local function StartLock(rootPart, cf)
	if not Settings.LockToTarget then
		StopLock()
		return
	end

	StopLock()

	if Settings.LockMode == "Hard" then
		StartHardLock(rootPart, cf)
	else
		StartConstraintLock(rootPart, cf)
	end
end

-- ========= TARGET SELECTION (CACHED) =========
local function GetBestTargetPart()
	if not Settings.AutoFarm then return nil end

	local _, r = GetCharAndRoot()
	if not r then return nil end

	local zonesAny = select(1, boolCount(Settings.Zones))
	local rocksAny = select(1, boolCount(Settings.Rocks))
	local oresAny  = AnyOreSelected()

	local allowAllZones = (Settings.AllowAllZonesIfNoneSelected == true) and (not zonesAny)
	local allowAllRocks = (Settings.AllowAllRocksIfNoneSelected == true) and (not rocksAny)
	local allowAllOres  = (Settings.AllowAllOresIfNoneSelected  == true) and (not oresAny)

	local requireOre = (Settings.RequireOreMatchWhenSelected == true) and oresAny

	local myPos = r.Position
	local closestPart, minDist = nil, math.huge

	for _, e in ipairs(RockIndex.entries) do
		local model = e.model
		if model and model.Parent then
			-- Zone filter
			if allowAllZones or Settings.Zones[e.zoneName] == true then
				-- Rock name filter
				if allowAllRocks or Settings.Rocks[model.Name] == true then
					-- Ore strict filter
					if (not requireOre) or RockMatchesOreSelection(model, e.oreType) then
						-- HP validation
						if IsRockAliveEnough(model) then
							-- part refresh lazily
							local part = e.part
							if not (part and part.Parent) then
								part = PickTargetPartFromRockModel(model)
								e.part = part
							end
							if part and part.Parent then
								local d = (myPos - part.Position).Magnitude
								if d < minDist then
									minDist = d
									closestPart = part
								end
							end
						end
					end
				end
			end
		end
	end

	return closestPart
end

-- ========= MOVE (SMART: ONLY IF NEEDED) =========
local activeTween = nil
local currentTargetPart = nil

local function CancelTween()
	if activeTween then
		pcall(function() activeTween:Cancel() end)
	end
	activeTween = nil
end

local function EnsureAtPart(targetPart)
	if not (targetPart and targetPart.Parent) then return false end
	local _, r = GetCharAndRoot()
	if not (r and r.Parent) then return false end

	-- compute desired position (center XZ, Y offset only)
	local rockPos = targetPart.Position
	local yOff = tonumber(Settings.YOffset) or 0
	local targetPos = rockPos + Vector3.new(0, yOff, 0)
	local desiredCF = CFrame.new(targetPos)

	local dist = (r.Position - targetPos).Magnitude
	local arriveDist = tonumber(Settings.ArriveDistance) or 2.25
	local retweenDist = tonumber(Settings.RetweenDistance) or 6

	-- already close enough: just lock/cam (no tween)
	if dist <= arriveDist then
		CancelTween()
		StartLock(r, desiredCF)
		StartCameraStabilize()
		if Settings.KeepNoclipWhileLocked then
			enableNoclip()
		else
			disableNoclip()
		end
		return true
	end

	-- if we are locked but drifted a bit: retween only if far enough
	if dist < retweenDist and currentTargetPart == targetPart then
		-- minor drift: constraint lock usually fixes it; no tween spam
		StartLock(r, desiredCF)
		StartCameraStabilize()
		if Settings.KeepNoclipWhileLocked then enableNoclip() end
		return true
	end

	-- need to move: tween
	enableNoclip()
	StopCameraStabilize()
	StopLock()
	CancelTween()

	local speed = math.max(1, tonumber(Settings.TweenSpeed) or 55)
	local duration = math.max(0.06, dist / speed)

	activeTween = TweenService:Create(
		r,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = desiredCF } -- no rotation tween (anti jitter)
	)

	activeTween:Play()
	pcall(function() activeTween.Completed:Wait() end)
	activeTween = nil

	-- lock at destination
	StartLock(r, desiredCF)
	StartCameraStabilize()

	-- keep noclip optional during lock
	if Settings.KeepNoclipWhileLocked then
		enableNoclip()
	else
		disableNoclip()
	end

	return true
end

-- ========= MAIN LOOP =========
local lastScan = 0
local lockedTarget = nil
local lockedUntil = 0

task.spawn(function()
	D("LOOP", "Main loop started (OPT)")

	while _G.FarmLoop ~= false do
		task.wait(0.03)

		if not Settings.AutoFarm then
			currentTargetPart = nil
			lockedTarget = nil
			StopCameraStabilize()
			StopLock()
			disableNoclip()
			task.wait(0.15)
			continue
		end

		local _, r = GetCharAndRoot()
		if not r then
			currentTargetPart = nil
			lockedTarget = nil
			StopCameraStabilize()
			StopLock()
			disableNoclip()
			task.wait(0.25)
			continue
		end

		local now = os.clock()

		-- refresh target periodically or if invalid
		local targetInvalid = (not lockedTarget) or (not lockedTarget.Parent)
		if not targetInvalid then
			local rockModel = lockedTarget:FindFirstAncestorOfClass("Model")
			if not rockModel or not rockModel.Parent then
				targetInvalid = true
			else
				local hp = rockModel:GetAttribute("Health")
				if hp and hp <= 0 then
					targetInvalid = true
				end
				-- ore strict re-check (in case ore selection changed)
				if (not targetInvalid) and Settings.RequireOreMatchWhenSelected and AnyOreSelected() then
					if not RockMatchesOreSelection(rockModel, GetOreType(rockModel)) then
						targetInvalid = true
					end
				end
			end
		end

		if targetInvalid then
			lockedTarget = nil
			currentTargetPart = nil
		end

		if lockedTarget and now < lockedUntil then
			-- stick
		else
			if (now - lastScan) >= (Settings.ScanInterval or 0.12) then
				lastScan = now
				lockedTarget = GetBestTargetPart()
				lockedUntil = now + (Settings.TargetStickTime or 0.25)
				currentTargetPart = lockedTarget
			end
		end

		if lockedTarget and lockedTarget.Parent then
			EnsureAtPart(lockedTarget)

			-- Hit if alive
			local rockModel = lockedTarget:FindFirstAncestorOfClass("Model")
			if rockModel then
				local hp = rockModel:GetAttribute("Health")
				if (not hp) or hp > 0 then
					HitPickaxe()
				end
			end
		else
			StopCameraStabilize()
			StopLock()
			disableNoclip()
			task.wait(0.08)
		end
	end

	CancelTween()
	StopCameraStabilize()
	StopLock()
	disableNoclip()
end)

print("[✓] Forge Core OPT Loaded! (CACHE + ORE-STRICT + CONSTRAINT LOCK)")
