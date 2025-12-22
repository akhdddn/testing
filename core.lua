--// ==========================================================
--// THE FORGE CORE: ULTRA-COMPLETE INTEGRATION (LOOP FIX V2)
--// ==========================================================
--// Status: FINAL (Deadzone Logic Implemented)
--// Fix: Removed Micro-Tweening that paused the Attack Loop
--// Logic: If Distance < 8, SNAP instead of TWEEN.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CAMERA_BIND_NAME = "Forge_CameraFollow"

-- ========= [1] DATA REPOSITORY (UTUH) =========
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
_G.DATA = DATA

-- ========= [2] SETTINGS & DEFAULTS =========
_G.Settings = _G.Settings or {}
local Settings = _G.Settings
Settings.Zones = Settings.Zones or {}
Settings.Rocks = Settings.Rocks or {}
Settings.Ores  = Settings.Ores  or {}

local function setDefault(k, v)
	if Settings[k] == nil then Settings[k] = v end
end

setDefault("AutoFarm", false)
setDefault("TweenSpeed", 40)
setDefault("YOffset", -4)
setDefault("CheckThreshold", 45)
setDefault("ScanInterval", 0.25)
setDefault("HitInterval", 0.15)
setDefault("TargetStickTime", 0.35)
setDefault("LockToTarget", true)
setDefault("LockVelocityZero", true)
setDefault("AnchorDuringLock", true)
setDefault("CameraStabilize", true)

for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- ========= [3] UTILS & HELPERS =========
local function GetCharAndRoot()
	local c = Players.LocalPlayer.Character
	if not (c and c.Parent) then return nil, nil end
	local r = c:FindFirstChild("HumanoidRootPart")
	return c, r
end

local function GetHumanoid()
	local c = Players.LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

-- ========= [4] NOCLIP ENGINE (GHOST MODE) =========
local noclipConn, descConn
local partsSet = {}
local originalStates = {} 

local function cacheCharacterParts(c)
	table.clear(partsSet)
	table.clear(originalStates)
	if not c then return end
	for _, inst in ipairs(c:GetDescendants()) do
		if inst:IsA("BasePart") then
			partsSet[inst] = true
			originalStates[inst] = {
				CanCollide = inst.CanCollide,
				CanTouch = inst.CanTouch,
				CanQuery = inst.CanQuery
			}
		end
	end
end

local function enableNoclip()
	if noclipConn then return end
	local c = Players.LocalPlayer.Character
	cacheCharacterParts(c)

	if descConn then descConn:Disconnect() end
	if c then
		descConn = c.DescendantAdded:Connect(function(inst)
			if inst:IsA("BasePart") then
				partsSet[inst] = true
				inst.CanCollide = false
				inst.CanTouch = false
				inst.CanQuery = false
			end
		end)
	end

	noclipConn = RunService.Stepped:Connect(function()
		for part in pairs(partsSet) do
			if part and part.Parent then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			else
				partsSet[part] = nil
			end
		end
	end)
end

local function disableNoclip()
	if noclipConn then noclipConn:Disconnect() end
	if descConn then descConn:Disconnect() end
	noclipConn, descConn = nil, nil

	for part, states in pairs(originalStates) do
		if part and part.Parent then 
			part.CanCollide = states.CanCollide
			part.CanTouch = states.CanTouch
			part.CanQuery = states.CanQuery
		end
	end
	table.clear(partsSet)
	table.clear(originalStates)
end

-- ========= [5] HARD LOCK =========
local lockConn, lockRoot, lockCFrame, lockHum
local prevPlatformStand, prevAutoRotate, prevAnchored

local DRIFT_POS_EPS = 0.02
local DRIFT_ANG_EPS = math.rad(0.25)

local function StopLock()
	if lockConn then lockConn:Disconnect() end
	lockConn = nil

	if lockRoot and lockRoot.Parent and prevAnchored ~= nil then
		lockRoot.Anchored = prevAnchored
	end

	if lockHum and lockHum.Parent then
		lockHum.PlatformStand = prevPlatformStand or false
		lockHum.AutoRotate = prevAutoRotate or true
	end

	lockRoot, lockHum, lockCFrame = nil, nil, nil
end

local function StartLock(rootPart, cf)
	if not Settings.LockToTarget then StopLock() return end

	-- Force Ghost Mode
	for _, v in ipairs(rootPart.Parent:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.CanTouch = false
			v.CanQuery = false
		end
	end

	if lockConn and lockRoot == rootPart then
		lockCFrame = cf
		return 
	end

	lockRoot, lockCFrame = rootPart, cf
	lockHum = GetHumanoid()

	if lockHum then
		prevPlatformStand, prevAutoRotate = lockHum.PlatformStand, lockHum.AutoRotate
		lockHum.PlatformStand, lockHum.AutoRotate = true, false
	end

	if lockRoot then
		prevAnchored = lockRoot.Anchored
		if Settings.AnchorDuringLock then
			lockRoot.Anchored = true
		end

		lockRoot.CFrame = lockCFrame
		if Settings.LockVelocityZero then
			lockRoot.AssemblyLinearVelocity = Vector3.zero
			lockRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if lockConn then lockConn:Disconnect() end

	lockConn = RunService.PreSimulation:Connect(function()
		if not (lockRoot and lockRoot.Parent and lockCFrame) then return end

		local cur = lockRoot.CFrame
		local dp = (cur.Position - lockCFrame.Position).Magnitude
		local _, ang = (cur:ToObjectSpace(lockCFrame)):ToAxisAngle()

		if dp > DRIFT_POS_EPS or math.abs(ang) > DRIFT_ANG_EPS then
			lockRoot.CFrame = lockCFrame
		end

		if Settings.LockVelocityZero then
			lockRoot.AssemblyLinearVelocity = Vector3.zero
			lockRoot.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- ========= [6] CAMERA (PASSIVE) =========
local camApplied = false
local prevOcclusionMode = nil
local prevCamType = nil
local prevCamSubject = nil

local function IsMiningState()
	if not Settings.AutoFarm then return false end
	return (lockConn ~= nil and lockRoot ~= nil and lockCFrame ~= nil)
end

local function StopCameraStabilize()
	pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND_NAME) end)

	local cam = Workspace.CurrentCamera
	local plr = Players.LocalPlayer

	if cam then
		if prevCamType ~= nil then cam.CameraType = prevCamType end
		if prevCamSubject ~= nil then cam.CameraSubject = prevCamSubject end
	end
	if plr and prevOcclusionMode ~= nil then
		pcall(function()
			plr.DevCameraOcclusionMode = prevOcclusionMode
		end)
	end

	prevOcclusionMode, prevCamType, prevCamSubject = nil, nil, nil
	camApplied = false
end

local function StartCameraStabilize()
	if not Settings.CameraStabilize then StopCameraStabilize() return end
	if camApplied then return end

	local cam = Workspace.CurrentCamera
	local plr = Players.LocalPlayer
	if not (cam and plr) then return end

	prevOcclusionMode = plr.DevCameraOcclusionMode
	prevCamType = cam.CameraType
	prevCamSubject = cam.CameraSubject

	cam.CameraType = Enum.CameraType.Custom
	local hum = GetHumanoid()
	if hum then cam.CameraSubject = hum end

	if IsMiningState() then
		pcall(function()
			plr.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
		end)
	end

	camApplied = true
end

local camStateConn = nil
local lastMining = nil

local function StartCameraStateManager()
	if camStateConn then return end
	camStateConn = RunService.Heartbeat:Connect(function()
		if not camApplied then return end

		local cam = Workspace.CurrentCamera
		local plr = Players.LocalPlayer
		if not (cam and plr) then return end

		local mining = IsMiningState()
		if mining ~= lastMining then
			lastMining = mining

			cam.CameraType = Enum.CameraType.Custom
			local hum = GetHumanoid()
			if hum then cam.CameraSubject = hum end

			if mining then
				pcall(function()
					plr.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
				end)
			else
				if prevOcclusionMode ~= nil then
					pcall(function()
						plr.DevCameraOcclusionMode = prevOcclusionMode
					end)
				end
			end
		end
	end)
end

local function StopCameraStateManager()
	if camStateConn then camStateConn:Disconnect() end
	camStateConn = nil
	lastMining = nil
end

-- ========= [7] TARGET LOGIC =========
local toolActivatedRF = nil
local lastHit = 0

local function ResolveToolActivated()
	pcall(function()
		toolActivatedRF = ReplicatedStorage.Shared.Packages.Knit.Services.ToolService.RF.ToolActivated
	end)
end

local function HitPickaxe()
	local now = os.clock()
	if (now - lastHit) < (Settings.HitInterval or 0.15) then return end
	lastHit = now
	
	if not toolActivatedRF then ResolveToolActivated() end
	if toolActivatedRF then
		task.spawn(function() 
			pcall(function() toolActivatedRF:InvokeServer("Pickaxe") end) 
		end)
	end
end

local function IsRockValid(rockModel, anyOreSelected, anyRockSelected)
	-- [RULE 1]: OWNERSHIP CHECK
	local owner = rockModel:GetAttribute("LastHitPlayer")
	if owner and owner ~= Players.LocalPlayer.Name then
		return false
	end

	-- [RULE 2]: HEALTH PREDICTION
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end

	-- [RULE 3]: STRICT ORE FILTER
	if anyOreSelected then
		local hasTargetOre = false
		for _, child in ipairs(rockModel:GetChildren()) do
			if child.Name == "Ore" and child:IsA("Model") then
				local oreName = child:GetAttribute("Ore")
				if oreName and Settings.Ores[oreName] then
					hasTargetOre = true
					break
				end
			end
		end
		if hasTargetOre then return true else return false end
	end

	-- [RULE 4]: STRICT ROCK FILTER
	if anyRockSelected then
		return Settings.Rocks[rockModel.Name] == true
	end

	-- [RULE 5]: DEFAULT MODE
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	if ((hp or maxHP)/maxHP)*100 > (Settings.CheckThreshold or 45) then return true end
	
	return false
end

local function GetBestTargetPart()
	local _, r = GetCharAndRoot()
	if not (Settings.AutoFarm and r) then return nil end
	local rocksFolder = Workspace:FindFirstChild("Rocks")
	if not rocksFolder then return nil end

	local anyZ = false
	for _, v in pairs(Settings.Zones) do if v then anyZ = true break end end
	local anyR = false
	for _, v in pairs(Settings.Rocks) do if v then anyR = true break end end
	local anyO = false
	for _, v in pairs(Settings.Ores) do if v then anyO = true break end end

	local cl, md = nil, math.huge
	
	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") and (not anyZ or Settings.Zones[zone.Name]) then
			for _, inst in ipairs(zone:GetDescendants()) do
				if inst:IsA("Model") and inst.Parent.Name ~= "Rock" then 
					if IsRockValid(inst, anyO, anyR) then
						local p = inst.PrimaryPart or inst:FindFirstChild("Hitbox") or inst:FindFirstChildWhichIsA("BasePart")
						if p then
							local d = (r.Position - p.Position).Magnitude
							if d < md then md = d; cl = p end
						end
					end
				end
			end
		end
	end
	return cl
end

-- ========= [8] MOVEMENT ENGINE (DEADZONE FIX) =========
local activeTween = nil
local function TweenToPart(targetPart)
	local _, r = GetCharAndRoot()
	if not (r and targetPart and targetPart.Parent) then return end

	local rockPos = targetPart.Position
	local targetPos = rockPos + Vector3.new(0, tonumber(Settings.YOffset) or -4, 0)
	local lookAtCF = CFrame.lookAt(targetPos, rockPos)

	local dist = (r.Position - targetPos).Magnitude
	
	-- [FIX]: DEADZONE LOGIC (Toleransi 8 Studs)
	-- Jika jarak ke titik target < 8 studs, ANGGAP SUDAH SAMPAI.
	-- Jangan Tween lagi. Cukup Snap (StartLock) dan biarkan kode lanjut ke HitPickaxe.
	-- Ini mencegah loop "Tween -> Stop Attack -> Tween".
	if dist < 8 then
		if not lockConn then 
			StartLock(r, lookAtCF)
		else
			StartLock(r, lookAtCF) 
		end
		return -- Langsung kembali ke Loop Utama untuk memukul
	end

	StopLock()

	local speed = math.max(1, tonumber(Settings.TweenSpeed) or 40)
	local duration = dist / speed

	if activeTween then activeTween:Cancel() end
	activeTween = TweenService:Create(r, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = lookAtCF})
	activeTween:Play()
	activeTween.Completed:Wait() -- Hanya Wait jika perjalanan jauh

	if Settings.AutoFarm then
		StartLock(r, lookAtCF)
	end
end

-- ========= [9] MAIN EXECUTION LOOP =========
task.spawn(function()
	local lastScan, lockedTarget, lockedUntil = 0, nil, 0
	
	if Settings.AutoFarm then
		StartCameraStabilize()
		StartCameraStateManager()
	end
	
	while _G.FarmLoop do
		task.wait(0.05)
		
		pcall(function()
			if Settings.AutoFarm then
				enableNoclip()

				local _, r = GetCharAndRoot()
				if r then
					local now = os.clock()
					
					-- 1. Scan Target
					if not (lockedTarget and lockedTarget.Parent) or now >= lockedUntil then
						if now - lastScan >= (Settings.ScanInterval or 0.25) then
							lastScan = now
							lockedTarget = GetBestTargetPart()
							lockedUntil = now + (Settings.TargetStickTime or 0.35)
						end
					end

					-- 2. Attack
					if lockedTarget and lockedTarget.Parent then
						-- TweenToPart sekarang akan return instant jika sudah dekat (Deadzone)
						TweenToPart(lockedTarget)
						
						local m = lockedTarget:FindFirstAncestorOfClass("Model")
						if m then
							local hp = m:GetAttribute("Health") or 0
							local owner = m:GetAttribute("LastHitPlayer")
							
							if hp <= 0 then
								lockedTarget = nil
								lockedUntil = 0 
							elseif owner and owner ~= Players.LocalPlayer.Name then
								lockedTarget = nil
								lockedUntil = 0
							else
								HitPickaxe() -- Pukulan dieksekusi lancar karena tidak ada wait di TweenToPart
							end
						end
					end
				end
			else
				StopLock()
				StopCameraStateManager()
				StopCameraStabilize()
				disableNoclip()
			end
		end)
	end

	StopLock()
	StopCameraStateManager()
	StopCameraStabilize()
	disableNoclip()
end)

print("[✓] FORGE CORE: LOOP FIXED (NO MICRO-TWEEN STUTTER)")
