--// ==========================================================
--// THE FORGE CORE: ULTRA-COMPLETE INTEGRATION
--// ==========================================================
--// Status: FINAL (No Summaries / No Cuts)
--// Features:
--// - Position: -6 Studs (Under Rock) via Settings.YOffset
--// - Rotation: LookAt (Mendongak ke atas)
--// - Stability: High-Priority Anti-Shake Camera
--// - Physics: Constant Noclip & Hard Lock

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
setDefault("YOffset", -6) -- Player di bawah batu
setDefault("CheckThreshold", 45)
setDefault("ScanInterval", 0.25)
setDefault("HitInterval", 0.15)
setDefault("TargetStickTime", 0.35)
setDefault("AllowAllZonesIfNoneSelected", true)
setDefault("AllowAllRocksIfNoneSelected", true)
setDefault("LockToTarget", true)
setDefault("LockVelocityZero", true)
setDefault("AnchorDuringLock", true)
setDefault("CameraStabilize", true)
setDefault("CameraSmoothAlpha", 1) -- 1 = Anti guncang total
setDefault("CameraOffsetWorld", Vector3.new(0, 10, 18))

for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- ========= [3] UTILS =========
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

-- ========= [4] NOCLIP ENGINE (STATE-BASED) =========
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
	local c = Players.LocalPlayer.Character
	cacheCharacterParts(c)

	if descConn then descConn:Disconnect() end
	if c then
		descConn = c.DescendantAdded:Connect(function(inst)
			if inst:IsA("BasePart") then
				partsSet[inst] = true
				inst.CanCollide = false
			end
		end)
	end

	noclipConn = RunService.Stepped:Connect(function()
		for part in pairs(partsSet) do
			if part and part.Parent then
				part.CanCollide = false
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

	for part, was in pairs(originalCollide) do
		if part and part.Parent then
			part.CanCollide = was
		end
	end
	table.clear(partsSet)
	table.clear(originalCollide)
end

-- ========= [5] STABLE LOCK & CAMERA =========
local lockConn, lockRoot, lockCFrame, lockHum
local prevPlatformStand, prevAutoRotate, prevAnchored

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
	if not Settings.LockToTarget then
		StopLock()
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
	end

	if lockConn then lockConn:Disconnect() end
	lockConn = RunService.Stepped:Connect(function()
		if lockRoot and lockRoot.Parent and lockCFrame then
			lockRoot.CFrame = lockCFrame
			if Settings.LockVelocityZero then
				lockRoot.AssemblyLinearVelocity = Vector3.zero
				lockRoot.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end)
end

local function StopCameraStabilize()
	pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND_NAME) end)
	local cam = Workspace.CurrentCamera
	if cam then cam.CameraType = Enum.CameraType.Custom end
end

local function StartCameraStabilize()
	if not Settings.CameraStabilize then
		StopCameraStabilize()
		return
	end

	local cam = Workspace.CurrentCamera
	local _, r = GetCharAndRoot()
	if not (cam and r) then return end

	pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND_NAME) end)

	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local _, r2 = GetCharAndRoot()
		if not r2 then return end

		cam.CameraType = Enum.CameraType.Scriptable
		local alpha = tonumber(Settings.CameraSmoothAlpha) or 1
		local desiredPos = r2.Position + (Settings.CameraOffsetWorld or Vector3.new(0, 10, 18))
		local desiredCF = CFrame.new(desiredPos, r2.Position)

		if alpha >= 1 then
			cam.CFrame = desiredCF
		else
			cam.CFrame = cam.CFrame:Lerp(desiredCF, alpha)
		end
	end)
end

-- ========= [6] TOOL & TARGET LOGIC =========
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
	task.spawn(function()
		pcall(function()
			toolActivatedRF:InvokeServer("Pickaxe")
		end)
	end)
end

local function IsRockValid(rockModel)
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end

	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	if ((hp or maxHP)/maxHP)*100 > (Settings.CheckThreshold or 45) then
		return true
	end

	for _, c in ipairs(rockModel:GetChildren()) do
		if c.Name == "Ore" and Settings.Ores[c:GetAttribute("Ore") or ""] then
			return true
		end
	end
	return false
end

local function GetBestTargetPart()
	local _, r = GetCharAndRoot()
	if not (Settings.AutoFarm and r) then return nil end

	local rocksFolder = Workspace:FindFirstChild("Rocks")
	if not rocksFolder then return nil end

	local anyZ = false
	for _, v in pairs(Settings.Zones) do
		if v then anyZ = true break end
	end

	local anyR = false
	for _, v in pairs(Settings.Rocks) do
		if v then anyR = true break end
	end

	local cl, md = nil, math.huge
	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") and (not anyZ or Settings.Zones[zone.Name]) then
			for _, inst in ipairs(zone:GetDescendants()) do
				if inst:IsA("Model") and (not anyR or Settings.Rocks[inst.Name]) and IsRockValid(inst) then
					local p = inst.PrimaryPart or inst:FindFirstChild("Hitbox") or inst:FindFirstChildWhichIsA("BasePart")
					if p then
						local d = (r.Position - p.Position).Magnitude
						if d < md then
							md = d
							cl = p
						end
					end
				end
			end
		end
	end
	return cl
end

-- ========= [7] MOVEMENT ENGINE (TWEEN + NOCLIP STATE + LOCK) =========
local activeTween = nil

local function TweenToPart(targetPart)
	local _, r = GetCharAndRoot()
	if not (r and targetPart and targetPart.Parent) then return end

	-- Saat mulai bergerak ke target: lepas lock lama agar bisa "terbang" ke target baru.
	StopCameraStabilize()
	StopLock()

	local rockPos = targetPart.Position
	local yOff = tonumber(Settings.YOffset) or -6
	local targetPos = rockPos + Vector3.new(0, yOff, 0)

	-- Di bawah target + menghadap target (lookAt)
	local lookAtCF = CFrame.lookAt(targetPos, rockPos)

	local speed = math.max(1, tonumber(Settings.TweenSpeed) or 40)
	local duration = (r.Position - targetPos).Magnitude / speed

	if activeTween then activeTween:Cancel() end
	activeTween = TweenService:Create(r, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = lookAtCF})
	activeTween:Play()
	activeTween.Completed:Wait()

	if Settings.AutoFarm then
		-- Setelah sampai: kunci posisi + arah menghadap target agar tidak jatuh/gagal mining
		StartLock(r, lookAtCF)
		StartCameraStabilize()
	end
end

-- ========= [8] MAIN EXECUTION LOOP =========
task.spawn(function()
	local lastScan, lockedTarget, lockedUntil = 0, nil, 0

	while _G.FarmLoop do
		task.wait(0.05)

		if Settings.AutoFarm then
			-- Noclip wajib aktif selama AutoFarm ON
			enableNoclip()

			local _, r = GetCharAndRoot()
			if r then
				local now = os.clock()

				if not (lockedTarget and lockedTarget.Parent) or now >= lockedUntil then
					if now - lastScan >= (Settings.ScanInterval or 0.25) then
						lastScan = now
						lockedTarget = GetBestTargetPart()
						lockedUntil = now + (Settings.TargetStickTime or 0.35)
					end
				end

				if lockedTarget and lockedTarget.Parent then
					TweenToPart(lockedTarget)
					local m = lockedTarget:FindFirstAncestorOfClass("Model")
					if m and (m:GetAttribute("Health") or 1) > 0 then
						HitPickaxe()
					end
				end
			end
		else
			StopLock()
			StopCameraStabilize()
			disableNoclip()
		end
	end

	StopLock()
	StopCameraStabilize()
	disableNoclip()
end)

print("[✓] FORGE CORE: FULL INTEGRATION COMPLETE (ANTI-SHAKE + LOOKAT + NOCLIP)")
