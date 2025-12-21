--// ===== The Forge Core (FULL AIM ROTATION + ZONE/ORE FIX) =====
--// Fixes applied ONLY to Targeting:
--// - Zone Filter: Recursive Scan (Bisa deteksi batu di folder manapun)
--// - Ore Filter: Cek Attribute & Child Value

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========= DEBUG SYSTEM =========
_G.ForgeDebug = true 
local function D(tag, msg)
	if _G.ForgeDebug then warn(("[ForgeDBG:%s] %s"):format(tag, tostring(msg))) end
end

if _G.__ForgeCoreLoaded then
	warn("[!] Forge Core already loaded. Restart executor to reload.")
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

Settings.Zones = Settings.Zones or {}
Settings.Rocks = Settings.Rocks or {}
Settings.Ores  = Settings.Ores  or {}

local function setDefault(k, v)
	if Settings[k] == nil then Settings[k] = v end
end

setDefault("AutoFarm", false)
setDefault("TweenSpeed", 40)
setDefault("YOffset", -6) 
setDefault("CheckThreshold", 45)
setDefault("ScanInterval", 0.25)
setDefault("HitInterval", 0.1) 
setDefault("TargetStickTime", 5)

setDefault("AllowAllZonesIfNoneSelected", true)
setDefault("AllowAllRocksIfNoneSelected", true)

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

-- ========= AUTO EQUIP =========
local function EquipPickaxe()
	local c = Player.Character
	if not c then return end
	
	local held = c:FindFirstChildOfClass("Tool")
	if held then return end 
	
	local bp = Player:FindFirstChild("Backpack")
	if bp then
		local tool = bp:FindFirstChildOfClass("Tool")
		if tool then
			local hum = c:FindFirstChildOfClass("Humanoid")
			if hum then hum:EquipTool(tool) end
		end
	end
end

-- ========= STATE ENGINE =========
local ActiveTween = nil
local MiningCFrame = nil 
local NoclipConn = nil
local LockConn = nil

local function StartNoclip()
	if NoclipConn then return end
	NoclipConn = RunService.Stepped:Connect(function()
		local c = Player.Character
		if c then
			for _, v in ipairs(c:GetDescendants()) do
				if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
			end
		end
	end)
end

local function StopNoclip()
	if NoclipConn then NoclipConn:Disconnect() end
	NoclipConn = nil
end

local function StartLock(targetCF)
	MiningCFrame = targetCF
	local _, r = GetCharAndRoot()
	local hum = GetHumanoid()
	
	if r then r.Anchored = true end 
	if hum then hum.PlatformStand = true end 

	if LockConn then return end
	LockConn = RunService.Heartbeat:Connect(function()
		if MiningCFrame and r and r.Parent then
			r.CFrame = MiningCFrame 
			r.AssemblyLinearVelocity = Vector3.zero 
			r.AssemblyAngularVelocity = Vector3.zero
		else
			StopLock()
		end
	end)
end

local function StopLock()
	if LockConn then LockConn:Disconnect() end
	LockConn = nil
	MiningCFrame = nil
	local _, r = GetCharAndRoot()
	local hum = GetHumanoid()
	if r then r.Anchored = false end
	if hum then hum.PlatformStand = false end
end

local function ResetState()
	if ActiveTween then ActiveTween:Cancel() end
	ActiveTween = nil
	StopLock()
	StopNoclip()
end

-- ========= MOVEMENT LOGIC (FULL AIM ROTATION) =========
local function MoveAndMine(targetPart)
	if not targetPart or not targetPart.Parent then return false end
	local _, root = GetCharAndRoot()
	if not root then return false end

	local speed = math.max(10, tonumber(Settings.TweenSpeed) or 40)
	local yOff = tonumber(Settings.YOffset) or -6
	
	local rockPos = targetPart.Position
	local finalPos = rockPos + Vector3.new(0, yOff, 0)
	
	local lookDir = (rockPos - finalPos)
	local finalCFrame
	
	if lookDir.Magnitude < 0.01 then
		finalCFrame = CFrame.new(finalPos) * root.CFrame.Rotation
	else
		finalCFrame = CFrame.lookAt(finalPos, rockPos)
	end
	
	local dist = (root.Position - finalPos).Magnitude
	
	StartNoclip()

	if dist < 4 then
		StopLock() 
		StartLock(finalCFrame)
		return true
	end

	StopLock() 
	
	local duration = dist / speed
	if duration < 0.1 then duration = 0.1 end
	
	local ti = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	
	if ActiveTween then ActiveTween:Cancel() end
	ActiveTween = TweenService:Create(root, ti, {CFrame = finalCFrame})
	ActiveTween:Play()
	
	local t0 = os.clock()
	while (os.clock() - t0 < duration) do
		if not Settings.AutoFarm then ActiveTween:Cancel(); return false end
		if not targetPart.Parent then ActiveTween:Cancel(); return false end
		task.wait(0.1)
	end
	
	StartLock(finalCFrame)
	return true
end

-- ========= REMOTE HIT =========
local CACHED_REMOTE = nil
local lastHit = 0

local function GetHitRemote()
	if CACHED_REMOTE then return CACHED_REMOTE end
	
	local success, result = pcall(function()
		return ReplicatedStorage.Shared.Packages.Knit.Services.ToolService.RF.ToolActivated
	end)
	
	if success and result then
		CACHED_REMOTE = result
		D("REMOTE", "Cached Successfully.")
		return result
	end
	return nil
end

local function HitPickaxe()
	EquipPickaxe()

	local now = os.clock()
	if (now - lastHit) < (Settings.HitInterval or 0.1) then return end
	lastHit = now

	local remote = GetHitRemote()
	if remote then
		task.spawn(function()
			pcall(function()
				remote:InvokeServer("Pickaxe")
			end)
		end)
	end
end

-- ========= TARGETING (FILTER IMPLEMENTATION) =========

-- [FIX 1] IsRockValid: Mendeteksi Ore dengan lebih teliti
local function IsRockValid(rockModel)
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end
	
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local curHP = hp or maxHP
	local pct = (maxHP > 0) and ((curHP / maxHP) * 100) or 100

	-- Kalau HP masih bagus, cek Threshold
	if pct > (Settings.CheckThreshold or 45) then return true end
	
	-- Kalau HP sekarat, cek apakah ada Ore mahal
	local foundOre = nil
	
	-- Cek Attribute Ore
	local attOre = rockModel:GetAttribute("Ore")
	if attOre then foundOre = attOre end
	
	-- Cek Child Ore (StringValue/AttributeValue)
	if not foundOre then
		local child = rockModel:FindFirstChild("Ore")
		if child then
			if child:IsA("StringValue") or child:IsA("AttributeValue") then
				foundOre = child.Value
			end
		end
	end
	
	-- Validasi Filter Ore
	if foundOre and Settings.Ores[foundOre] then
		return true
	end
	
	return false
end

-- [FIX 2] Helper Scan Recursive: Menembus folder apapun di dalam Zone
local function ScanForRocksInZone(zoneFolder, allowAllRocks, myPos, currentBest, currentDist)
	local best = currentBest
	local minDist = currentDist
	
	local function checkItem(item)
		if item:IsA("Model") and item:GetAttribute("Health") then
			if (allowAllRocks or Settings.Rocks[item.Name]) and IsRockValid(item) then
				local pp = item.PrimaryPart or item:FindFirstChild("Hitbox") or item:FindFirstChildWhichIsA("BasePart")
				if pp then
					local d = (myPos - pp.Position).Magnitude
					if d < minDist then
						minDist = d
						best = pp
					end
				end
			end
		end
	end

	-- Scan Anak Langsung
	for _, item in ipairs(zoneFolder:GetChildren()) do
		checkItem(item)
		-- Scan Sub-folder (SpawnLocation/Spawns/Apapun)
		if item:IsA("Folder") or (item:IsA("Model") and not item:GetAttribute("Health")) then
			for _, subItem in ipairs(item:GetChildren()) do
				checkItem(subItem)
			end
		end
	end
	return best, minDist
end

-- [FIX 3] GetBestTargetPart: Menggunakan Scan Recursive
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

	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") or zone:IsA("Model") then
			if allowAllZones or Settings.Zones[zone.Name] then
				-- PANGGIL SCANNER
				closest, minDist = ScanForRocksInZone(zone, allowAllRocks, myPos, closest, minDist)
			end
		end
	end
	return closest
end

-- ========= MAIN LOOP =========
local currentTarget = nil
local stickTime = 0

task.spawn(function()
	D("LOOP", "Full Aim Engine Started")
	while _G.FarmLoop ~= false do
		task.wait(0.1)

		if not Settings.AutoFarm then
			if ActiveTween then ResetState() end
			task.wait(0.5)
			continue
		end

		local now = os.clock()

		if (not currentTarget) or (not currentTarget.Parent) or (now > stickTime) then
			if currentTarget then StopLock() end
			
			local newTarget = GetBestTargetPart()
			if newTarget then
				currentTarget = newTarget
				stickTime = now + (Settings.TargetStickTime or 5)
			else
				currentTarget = nil
				task.wait(0.2)
			end
		end

		if currentTarget and currentTarget.Parent then
			MoveAndMine(currentTarget)
			
			local model = currentTarget:FindFirstAncestorOfClass("Model")
			if model then
				local hp = model:GetAttribute("Health")
				if not hp or hp > 0 then
					HitPickaxe() 
				else
					currentTarget = nil
					StopLock()
				end
			end
		else
			StopLock()
		end
	end
	ResetState()
end)

print("[✓] Forge Core: Filter Zone & Ore Fixed.")
