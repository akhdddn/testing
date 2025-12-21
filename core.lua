--// ===== The Forge Core (FINAL FIXED + OPTIMIZED) =====
--// Target Path: Workspace.Rocks.[Zone].SpawnLocation.[Rock]
--// [FIX APPLIED] Anti-NaN CFrame Math (Prevents console spam/crash)
--// [FIX APPLIED] Robust Stepped Noclip

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CAMERA_BIND_NAME = "Forge_CameraFollow"

-- ========= DEBUG SYSTEM =========
_G.ForgeDebug = (_G.ForgeDebug ~= nil) and _G.ForgeDebug or true
local function D(tag, msg)
	if _G.ForgeDebug then warn(("[ForgeDBG:%s] %s"):format(tag, tostring(msg))) end
end

-- Prevent double load
if _G.__ForgeCoreLoaded then
	warn("[!] Forge Core already loaded.")
	return
end
_G.__ForgeCoreLoaded = true

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
_G.DATA = _G.DATA or DATA

-- ========= SETTINGS =========
_G.Settings = _G.Settings or {}
local Settings = _G.Settings

-- Ensure tables exist
Settings.Zones = Settings.Zones or {}
Settings.Rocks = Settings.Rocks or {}
Settings.Ores  = Settings.Ores  or {}

local function setDefault(k, v)
	if Settings[k] == nil then Settings[k] = v end
end

-- Default Configs
setDefault("AutoFarm", false)
setDefault("TweenSpeed", 40)
setDefault("YOffset", 0) -- Center on rock + this offset
setDefault("CheckThreshold", 45) -- Min HP % to attack (unless valuable ore)
setDefault("ScanInterval", 0.25)
setDefault("HitInterval", 0.15)
setDefault("TargetStickTime", 0.35)

-- Filters
setDefault("AllowAllZonesIfNoneSelected", true)
setDefault("AllowAllRocksIfNoneSelected", true)

-- Lock & Cam
setDefault("LockToTarget", true)
setDefault("LockVelocityZero", true)
setDefault("AnchorDuringLock", true)
setDefault("CameraStabilize", true)
setDefault("CameraSmoothAlpha", 1)
setDefault("CameraOffsetWorld", Vector3.new(0, 10, 18))

-- Init toggles
for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- ========= UTILS =========
local function GetCharAndRoot()
	local c = Player.Character
	if not c then return nil, nil end
	local r = c:FindFirstChild("HumanoidRootPart")
	return c, r
end

local function GetHumanoid()
	local c = Player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function boolCount(map)
	if type(map) ~= "table" then return false end
	for _, v in pairs(map) do if v then return true end end
	return false
end

-- ========= [FIXED] ROBUST NOCLIP =========
local noclipConn = nil

local function enableNoclip()
	if noclipConn then return end
	local step = RunService.Stepped -- Gunakan Stepped untuk fisika yang lebih stabil
	noclipConn = step:Connect(function()
		local c = Player.Character
		if c then
			for _, v in ipairs(c:GetDescendants()) do
				if v:IsA("BasePart") and v.CanCollide == true then
					v.CanCollide = false
				end
			end
		end
	end)
end

local function disableNoclip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
end

Player.CharacterAdded:Connect(function() disableNoclip() end)

-- ========= LOCK CONTROLLER =========
local lockConn = nil
local lockRoot = nil
local lockCFrame = nil -- Now includes Rotation
local lockHum = nil
local prevPlatformStand, prevAutoRotate, prevAnchored = nil, nil, nil

local function StopLock()
	if lockConn then lockConn:Disconnect() end
	lockConn = nil
	if lockRoot and lockRoot.Parent then
		if prevAnchored ~= nil then lockRoot.Anchored = prevAnchored end
	end
	if lockHum and lockHum.Parent then
		if prevPlatformStand ~= nil then lockHum.PlatformStand = prevPlatformStand end
		if prevAutoRotate ~= nil then lockHum.AutoRotate = prevAutoRotate end
	end
	lockRoot, lockHum, lockCFrame = nil, nil, nil
end

local function StartLock(rootPart, cf)
	if not Settings.LockToTarget then StopLock() return end

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
		if Settings.AnchorDuringLock then lockRoot.Anchored = true end
	end

	if lockConn then lockConn:Disconnect() end
	local stepSignal = RunService.PreSimulation or RunService.Stepped
	lockConn = stepSignal:Connect(function()
		if not (lockRoot and lockRoot.Parent and lockCFrame) then return end
		
		-- Force Position AND Rotation (Hard Lock)
		lockRoot.CFrame = lockCFrame 
		
		if Settings.LockVelocityZero then
			lockRoot.AssemblyLinearVelocity = Vector3.zero
			lockRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- ========= CAMERA STABILIZER =========
local camPrevType, camPrevSubject, camOffsetWorld

local function StopCameraStabilize()
	pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND_NAME) end)
	local cam = Workspace.CurrentCamera
	if cam then
		if camPrevType then cam.CameraType = camPrevType end
		if camPrevSubject then cam.CameraSubject = camPrevSubject end
	end
	camPrevType, camPrevSubject = nil, nil
end

local function StartCameraStabilize()
	if not Settings.CameraStabilize then StopCameraStabilize() return end
	local cam = Workspace.CurrentCamera
	local _, r = GetCharAndRoot()
	if not (cam and r) then return end

	pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND_NAME) end)
	camPrevType = cam.CameraType
	camPrevSubject = cam.CameraSubject
	camOffsetWorld = Settings.CameraOffsetWorld or Vector3.new(0, 10, 18)

	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local cam2 = Workspace.CurrentCamera
		local _, r2 = GetCharAndRoot()
		if not (cam2 and r2) then return end
		
		cam2.CameraType = Enum.CameraType.Scriptable
		local alpha = tonumber(Settings.CameraSmoothAlpha) or 1
		local desiredPos = r2.Position + camOffsetWorld
		
		-- Camera looks steadily at player
		local desired = CFrame.new(desiredPos, r2.Position)

		if alpha >= 0.99 then
			cam2.CFrame = desired
		else
			cam2.CFrame = cam2.CFrame:Lerp(desired, alpha)
		end
	end)
end

-- ========= REMOTE TOOL =========
local toolActivatedRF = nil
local lastHit = 0
local function ResolveToolActivated()
	-- Dynamic Knit lookup
	local s = ReplicatedStorage:FindFirstChild("Shared")
	local rf = s and s.Packages.Knit.Services.ToolService.RF.ToolActivated
	if rf then toolActivatedRF = rf end
end

local function HitPickaxe()
	local now = os.clock()
	if (now - lastHit) < (Settings.HitInterval or 0.15) then return end
	lastHit = now
	if not (toolActivatedRF and toolActivatedRF.Parent) then ResolveToolActivated() end
	if toolActivatedRF then
		task.spawn(function() pcall(function() toolActivatedRF:InvokeServer("Pickaxe") end) end)
	end
end

-- ========= TARGETING (SPAWNLOCATION OPTIMIZATION) =========
local function IsRockValid(rockModel)
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end
	
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local curHP = hp or maxHP
	local pct = (maxHP > 0) and ((curHP / maxHP) * 100) or 100

	-- Condition A: HP is good
	if pct > (Settings.CheckThreshold or 45) then return true end
	
	-- Condition B: HP is bad, BUT contains valuable Ore
	for _, c in ipairs(rockModel:GetChildren()) do
		if c.Name == "Ore" then
			local t = c:GetAttribute("Ore")
			if t and Settings.Ores[t] then return true end
		end
	end
	return false
end

local function GetBestTargetPart()
	if not Settings.AutoFarm then return nil end
	local _, r = GetCharAndRoot()
	if not r then return nil end

	local rocksFolder = Workspace:FindFirstChild("Rocks")
	if not rocksFolder then return nil end

	local zonesAny = boolCount(Settings.Zones)
	local rocksAny = boolCount(Settings.Rocks)
	local allowAllZones = Settings.AllowAllZonesIfNoneSelected and (not zonesAny)
	local allowAllRocks = Settings.AllowAllRocksIfNoneSelected and (not rocksAny)

	local myPos = r.Position
	local closest, minDist = nil, math.huge

	-- 1. Loop Zone Folders
	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") or zone:IsA("Model") then
			
			-- 2. Check Zone Filter
			if allowAllZones or Settings.Zones[zone.Name] then
				
				-- 3. DIRECT PATH OPTIMIZATION: "SpawnLocation"
				local spawnLoc = zone:FindFirstChild("SpawnLocation") 
				
				if spawnLoc then
					-- 4. Loop only Rocks inside SpawnLocation
					for _, rockModel in ipairs(spawnLoc:GetChildren()) do
						if rockModel:IsA("Model") then
							
							-- 5. Check Rock Name & Conditions
							if (allowAllRocks or Settings.Rocks[rockModel.Name]) and IsRockValid(rockModel) then
								
								-- 6. Pick Target Part
								local pp = rockModel.PrimaryPart or rockModel:FindFirstChild("Hitbox") or rockModel:FindFirstChildWhichIsA("BasePart")
								if pp then
									local d = (myPos - pp.Position).Magnitude
									if d < minDist then
										minDist = d
										closest = pp
									end
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

-- ========= [FIXED] ANTI-NAN TWEEN LOGIC =========
local activeTween = nil

local function TweenToPart(targetPart)
	-- 1. Validasi Target
	if not (targetPart and targetPart.Parent) then return false end
	local c, r = GetCharAndRoot()
	if not (c and r and r.Parent) then return false end

	-- 2. Hitung Posisi Tujuan
	local rockPos = targetPart.Position
	local yOff = tonumber(Settings.YOffset) or 0
	
	-- Pastikan yOff bukan NaN (Safety)
	if type(yOff) ~= "number" then yOff = 0 end
	
	local targetPos = rockPos + Vector3.new(0, yOff, 0)

	-- 3. [FIX UTAMA] Perhitungan Rotasi Anti-NaN
	-- Kita ingin karakter menghadap batu, TAPI horizontal saja (Y lock).
	-- Error NaN terjadi jika (rockPos.X == targetPos.X) dan (rockPos.Z == targetPos.Z)
	
	local lookPos = Vector3.new(rockPos.X, targetPos.Y, rockPos.Z)
	local vecDiff = (lookPos - targetPos)
	local targetCFrame
	
	-- Cek apakah jarak pandang terlalu dekat (hampir 0)
	if vecDiff.Magnitude < 0.05 then
		-- Jika posisi sama persis, JANGAN putar badan (pakai rotasi sekarang)
		-- Ini mencegah CFrame.lookAt meledak jadi NaN
		targetCFrame = CFrame.new(targetPos) * r.CFrame.Rotation
	else
		-- Jika aman, baru gunakan lookAt
		targetCFrame = CFrame.lookAt(targetPos, lookPos)
	end

	-- 4. Hitung Durasi & Kecepatan
	local dist = (r.Position - targetPos).Magnitude
	local speed = math.max(1, tonumber(Settings.TweenSpeed) or 40)
	
	local duration = dist / speed
	
	-- [SAFETY] Durasi tidak boleh 0 atau negatif
	if duration < 0.1 then duration = 0.1 end

	-- 5. Eksekusi
	enableNoclip() -- Nyalakan noclip sebelum jalan
	StopCameraStabilize()
	StopLock()

	if activeTween then 
		pcall(function() activeTween:Cancel() end) 
		activeTween = nil
	end

	activeTween = TweenService:Create(
		r,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = targetCFrame }
	)

	activeTween:Play()
	
	-- Tunggu sampai selesai (dengan safety pcall)
	local success = pcall(function() activeTween.Completed:Wait() end)
	
	if success then
		-- Hanya kunci jika tween sukses sampai tujuan
		StartLock(r, targetCFrame)
		StartCameraStabilize()
	end

	disableNoclip() -- Matikan noclip setelah sampai
	return true
end

-- ========= MAIN LOOP =========
local lastScan = 0
local lockedTarget = nil
local lockedUntil = 0

task.spawn(function()
	D("LOOP", "Core Loop Started")
	while _G.FarmLoop ~= false do
		task.wait(0.05) -- Fast Tick

		if not Settings.AutoFarm then
			StopCameraStabilize(); StopLock(); task.wait(0.5); continue
		end

		local c, r = GetCharAndRoot()
		if not r then task.wait(0.5) continue end

		local now = os.clock()
		
		-- Sticky Target Logic
		if lockedTarget and lockedTarget.Parent and now < lockedUntil then
			-- Keep current target
		else
			if (now - lastScan) >= (Settings.ScanInterval or 0.25) then
				lastScan = now
				local newTarget = GetBestTargetPart()
				if newTarget then
					lockedTarget = newTarget
					lockedUntil = now + (Settings.TargetStickTime or 0.35)
				end
			end
		end

		-- Execution Logic
		if lockedTarget and lockedTarget.Parent then
			TweenToPart(lockedTarget) -- Handles Movement + Lock

			local rockModel = lockedTarget:FindFirstAncestorOfClass("Model")
			-- Simple health check before swinging
			if rockModel and (rockModel:GetAttribute("Health") or 1) > 0 then
				HitPickaxe()
			end
			task.wait(0.05)
		else
			StopLock()
			StopCameraStabilize()
			task.wait(0.1)
		end
	end
	
	-- Cleanup
	StopLock(); StopCameraStabilize(); disableNoclip()
	if activeTween then pcall(function() activeTween:Cancel() end) end
end)

print("[✓] Forge Core (NaN Fixed & Stabilized) Loaded!")
