--// ===== The Forge Core (FULL) =====
--// Features:
--// - nil-safe Settings branches (prevents "attempt to index nil with 'Rocks'")
--// - Rocks empty => ALL rocks allowed
--// - Zones empty => ALL zones allowed (optional toggle)
--// - Descendants scan for zone content
--// - Tween movement: SPEED ONLY
--// - Center-on-rock positioning (X/Z = rock center, only YOffset changes)
--// - Hard lock anti-fall (PlatformStand + CFrame lock + optional Anchored)
--// - Camera stabilize (BindToRenderStep + Scriptable), minimal shake

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CAMERA_BIND_NAME = "Forge_CameraFollow"

-- ========= DEBUG FLAGS =========
_G.ForgeDebug = (_G.ForgeDebug ~= nil) and _G.ForgeDebug or true
_G.ForgeDebugLevel = _G.ForgeDebugLevel or 1 -- 1 ringkas, 2 detail

local function D(tag, msg, extra)
	if not _G.ForgeDebug then return end
	local pfx = ("[ForgeDBG:%s] "):format(tag)
	if extra ~= nil then
		warn(pfx .. msg .. " | " .. tostring(extra))
	else
		warn(pfx .. msg)
	end
end

-- nil-safe boolCount
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

-- Prevent double load
if _G.__ForgeCoreLoaded then
	warn("[!] Forge Core already loaded.")
	D("BOOT", "Blocked by _G.__ForgeCoreLoaded")
	return
end
_G.__ForgeCoreLoaded = true
D("BOOT", "Core starting...")

local Player = Players.LocalPlayer

-- ========= DATA =========
local DATA = {
	Zones = {
		"Island2CaveDanger1","Island2CaveDanger2","Island2CaveDanger3",
		"Island2CaveDanger4","Island2CaveDangerClosed","Island2CaveDeep",
		"Island2CaveLavaClosed","Island2CaveMid","Island2CaveStart",
		"Island2GoblinCave","Island2VolcanicDepths",
	},
	Rocks = {
		"Basalt","Basalt Core","Basalt Rock","Basalt Vein","Boulder",
		"Crimson Crystal","Cyan Crystal","Earth Crystal","Lava Rock",
		"Light Crystal","Lucky Block","Pebble","Rock","Violet Crystal",
		"Volcanic Rock",
	},
	Ores = {
		"Aite","Amethyst","Arcane Crystal","Bananite","Blue Crystal",
		"Boneite","Cardboardite","Cobalt","Copper","Crimson Crystal",
		"Cuprite","Dark Boneite","Darkryte","Demonite","Diamond",
		"Emerald","Eye Ore","Fichillium","Fichilliumorite","Fireite",
		"Galaxite","Gold","Grass","Green Crystal","Iceite","Iron",
		"Jade","Lapis Lazuli","Lightite","Magenta Crystal","Magmaite",
		"Meteorite","Mushroomite","Mythril","Obsidian","Orange Crystal",
		"Platinum","Poopite","Quartz","Rainbow Crystal","Rivalite",
		"Ruby","Sand Stone","Sapphire","Silver","Slimite","Starite",
		"Stone","Tin","Titanium","Topaz","Uranium","Volcanic Rock",
	},
}

-- Export ASAP for GUI
_G.DATA = _G.DATA or DATA
D("BOOT", "_G.DATA ready")

-- ========= SETTINGS =========
_G.Settings = _G.Settings or {}
local Settings = _G.Settings

-- ensure branches exist
Settings.Zones = Settings.Zones or {}
Settings.Rocks = Settings.Rocks or {}
Settings.Ores  = Settings.Ores  or {}

local function setDefault(k, v)
	if Settings[k] == nil then Settings[k] = v end
end

-- Base settings
setDefault("AutoFarm", false)
setDefault("TweenSpeed", 40)       -- studs/sec
setDefault("YOffset", 0)           -- IMPORTANT: only vertical shift now
setDefault("CheckThreshold", 45)
setDefault("ScanInterval", 0.25)
setDefault("HitInterval", 0.15)
setDefault("TargetStickTime", 0.35)

-- UX toggles: allow all if none selected
setDefault("AllowAllZonesIfNoneSelected", true)
setDefault("AllowAllRocksIfNoneSelected", true)

-- Lock settings
setDefault("LockToTarget", true)
setDefault("LockVelocityZero", true)
setDefault("AnchorDuringLock", true) -- strongest anti-fall + reduces jitter

-- Camera settings
setDefault("CameraStabilize", true)
setDefault("CameraSmoothAlpha", 1) -- 1 = hard set (paling anti jitter)
setDefault("CameraOffsetWorld", Vector3.new(0, 10, 18)) -- world offset, not rotated by root

-- init checkbox keys
for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

D("BOOT", "Settings ready", ("AutoFarm=%s TweenSpeed=%s YOffset=%s"):format(
	tostring(Settings.AutoFarm), tostring(Settings.TweenSpeed), tostring(Settings.YOffset)
))

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
		local c2, r2 = GetCharAndRoot()
		if not (c2 and r2) then return end
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

-- ========= LOCK CONTROLLER =========
local lockConn = nil
local lockRoot = nil
local lockCFrame = nil
local lockHum = nil

local prevPlatformStand = nil
local prevAutoRotate = nil
local prevAnchored = nil

local function StopLock()
	if lockConn then lockConn:Disconnect() end
	lockConn = nil
	lockCFrame = nil

	if lockRoot and lockRoot.Parent then
		if prevAnchored ~= nil then
			lockRoot.Anchored = prevAnchored
		end
	end

	if lockHum and lockHum.Parent then
		if prevPlatformStand ~= nil then lockHum.PlatformStand = prevPlatformStand end
		if prevAutoRotate ~= nil then lockHum.AutoRotate = prevAutoRotate end
	end

	lockRoot = nil
	lockHum = nil
	prevPlatformStand, prevAutoRotate, prevAnchored = nil, nil, nil
end

local function StartLock(rootPart, cf)
	if not Settings.LockToTarget then
		StopLock()
		return
	end

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

		-- If anchored, this is mostly redundant but keeps it pinned if something toggles it back.
		lockRoot.CFrame = lockCFrame

		if Settings.LockVelocityZero then
			lockRoot.AssemblyLinearVelocity = Vector3.zero
			lockRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- ========= CAMERA STABILIZER =========
local camPrevType = nil
local camPrevSubject = nil
local camOffsetWorld = nil

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
	camOffsetWorld = nil
end

local function StartCameraStabilize()
	if not Settings.CameraStabilize then
		StopCameraStabilize()
		return
	end

	local cam = Workspace.CurrentCamera
	local _, r = GetCharAndRoot()
	local hum = GetHumanoid()
	if not (cam and r and hum) then return end

	pcall(function()
		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	end)

	camPrevType = cam.CameraType
	camPrevSubject = cam.CameraSubject

	-- World offset; by default uses Settings.CameraOffsetWorld
	camOffsetWorld = Settings.CameraOffsetWorld or Vector3.new(0, 10, 18)

	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local cam2 = Workspace.CurrentCamera
		local _, r2 = GetCharAndRoot()
		if not (cam2 and r2) then return end

		cam2.CameraType = Enum.CameraType.Scriptable

		local alpha = tonumber(Settings.CameraSmoothAlpha) or 1
		alpha = math.clamp(alpha, 0, 1)

		local desiredPos = r2.Position + camOffsetWorld
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
	if (now - lastHit) < (Settings.HitInterval or 0.15) then return end
	lastHit = now

	if (not toolActivatedRF) or (not toolActivatedRF.Parent) then
		ResolveToolActivated()
	end
	if not toolActivatedRF then return end

	task.spawn(function()
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

-- ========= TARGET VALIDATION =========
local function RockHasGoodOre(rockModel)
	for _, child in ipairs(rockModel:GetChildren()) do
		if child.Name == "Ore" then
			local oreType = child:GetAttribute("Ore")
			if oreType and Settings.Ores[oreType] then
				return true
			end
		end
	end
	return false
end

local function IsRockValid(rockModel)
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end

	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local curHP = hp or maxHP
	local pct = (maxHP > 0) and ((curHP / maxHP) * 100) or 100

	if pct > (Settings.CheckThreshold or 45) then
		return true
	end
	return RockHasGoodOre(rockModel)
end

-- ========= MOVE (CENTER-ON-ROCK, SPEED ONLY) =========
local activeTween = nil

local function TweenToPart(targetPart)
	if not (targetPart and targetPart.Parent) then return false end
	local c, r = GetCharAndRoot()
	if not (c and r and r.Parent) then return false end

	enableNoclip()

	local rockPos = targetPart.Position
	local myPos = r.Position
	local dist = (rockPos - myPos).Magnitude

	-- CENTER on rock (X/Z same as rock), YOffset only
	local yOff = tonumber(Settings.YOffset) or 0
	local targetPos = rockPos + Vector3.new(0, yOff, 0)

	-- Speed-only
	local speed = math.max(1, tonumber(Settings.TweenSpeed) or 40)
	local duration = dist / speed
	if duration < 0.01 then duration = 0.01 end

	StopCameraStabilize()
	StopLock()

	if activeTween then pcall(function() activeTween:Cancel() end) end
	activeTween = TweenService:Create(
		r,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(targetPos) } -- no lookAt to avoid rotation jitter
	)

	activeTween:Play()
	pcall(function() activeTween.Completed:Wait() end)

	-- HARD lock at exact center position
	local lockCF = CFrame.new(targetPos)
	StartLock(r, lockCF)
	StartCameraStabilize()

	disableNoclip()
	return true
end

-- ========= GET BEST TARGET (ALL ZONES/ROCKS LOGIC) =========
local function GetBestTargetPart()
	if not Settings.AutoFarm then return nil end

	local c, r = GetCharAndRoot()
	if not r then return nil end

	local rocksFolder = Workspace:FindFirstChild("Rocks")
	if not rocksFolder then return nil end

	local zonesAny = select(1, boolCount(Settings.Zones))
	local rocksAny = select(1, boolCount(Settings.Rocks))

	local allowAllZones = (Settings.AllowAllZonesIfNoneSelected == true) and (not zonesAny)
	local allowAllRocks = (Settings.AllowAllRocksIfNoneSelected == true) and (not rocksAny)

	local myPos = r.Position
	local closest, minDist = nil, math.huge

	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") then
			local zoneOk = allowAllZones or Settings.Zones[zone.Name]
			if zoneOk then
				-- Descendants scan [web:154]
				for _, inst in ipairs(zone:GetDescendants()) do
					if inst:IsA("Model") then
						local rockOk = allowAllRocks or Settings.Rocks[inst.Name]
						if rockOk and IsRockValid(inst) then
							local part = PickTargetPartFromRockModel(inst)
							if part then
								local d = (myPos - part.Position).Magnitude
								if d < minDist then
									minDist = d
									closest = part
								end
							end
						end
					end
				end
			end
		end
	end

	return closest
end

-- ========= MAIN LOOP =========
local lastScan = 0
local lockedTarget = nil
local lockedUntil = 0

task.spawn(function()
	D("LOOP", "Main loop started")
	while _G.FarmLoop ~= false do
		task.wait(0.05)

		if not Settings.AutoFarm then
			StopCameraStabilize()
			StopLock()
			task.wait(0.2)
			continue
		end

		local c, r = GetCharAndRoot()
		if not (c and r) then
			StopCameraStabilize()
			StopLock()
			task.wait(0.35)
			continue
		end

		local now = os.clock()
		if lockedTarget and lockedTarget.Parent and now < lockedUntil then
			-- keep
		else
			if (now - lastScan) >= (Settings.ScanInterval or 0.25) then
				lastScan = now
				lockedTarget = GetBestTargetPart()
				lockedUntil = now + (Settings.TargetStickTime or 0.35)
			end
		end

		if lockedTarget and lockedTarget.Parent then
			TweenToPart(lockedTarget)

			local rockModel = lockedTarget:FindFirstAncestorOfClass("Model")
			if rockModel then
				local hp = rockModel:GetAttribute("Health")
				if not hp or hp > 0 then
					HitPickaxe()
				end
			end

			task.wait(0.08)
		else
			StopCameraStabilize()
			StopLock()
			task.wait(0.12)
		end
	end

	if activeTween then pcall(function() activeTween:Cancel() end) end
	StopCameraStabilize()
	StopLock()
	disableNoclip()
end)

print("[✓] Forge Core Loaded Successfully! (CENTER + HARDLOCK + CAMERA STABLE)")
