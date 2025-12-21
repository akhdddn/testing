--// ===== The Forge Core (FINAL HIT FIX) =====
--// Fixes: 
--// - Exact Remote Path (100% Hit Rate)
--// - Auto Equip Pickaxe
--// - Optimized Movement Engine

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
setDefault("YOffset", 0) -- 0 Paling aman untuk hit
setDefault("CheckThreshold", 45)
setDefault("ScanInterval", 0.25)
setDefault("HitInterval", 0.1) -- Cepat
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

-- ========= [NEW] AUTO EQUIP =========
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

-- ========= MOVEMENT LOGIC =========

local function MoveAndMine(targetPart)
	if not targetPart or not targetPart.Parent then return false end
	local _, root = GetCharAndRoot()
	if not root then return false end

	local speed = math.max(10, tonumber(Settings.TweenSpeed) or 40)
	local yOff = tonumber(Settings.YOffset) or 0
	
	local rockPos = targetPart.Position
	local finalPos = rockPos + Vector3.new(0, yOff, 0)
	
	local lookDir = (rockPos - finalPos)
	local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
	local finalCFrame
	
	if flatLook.Magnitude < 0.01 then
		finalCFrame = CFrame.new(finalPos) * root.CFrame.Rotation
	else
		finalCFrame = CFrame.lookAt(finalPos, finalPos + flatLook)
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

-- ========= [UPDATED] REMOTE TOOL HIT =========
local CACHED_REMOTE = nil
local lastHit = 0

local function GetHitRemote()
	if CACHED_REMOTE then return CACHED_REMOTE end
	
	-- Gunakan Path Exact dari user
	local success, result = pcall(function()
		return ReplicatedStorage
			:WaitForChild("Shared")
			:WaitForChild("Packages")
			:WaitForChild("Knit")
			:WaitForChild("Services")
			:WaitForChild("ToolService")
			:WaitForChild("RF")
			:WaitForChild("ToolActivated")
	end)
	
	if success and result then
		CACHED_REMOTE = result
		D("REMOTE", "ToolActivated Found & Cached!")
		return result
	else
		-- Jangan warn terus menerus, cukup return nil
		return nil
	end
end

local function HitPickaxe()
	-- 1. Pastikan pegang tool
	EquipPickaxe()

	-- 2. Cek cooldown
	local now = os.clock()
	if (now - lastHit) < (Settings.HitInterval or 0.1) then return end
	lastHit = now

	-- 3. Ambil Remote
	local remote = GetHitRemote()
	
	if remote then
		task.spawn(function()
			pcall(function()
				-- 4. Invoke dengan format user
				local args = { "Pickaxe" }
				remote:InvokeServer(unpack(args))
			end)
		end)
	end
end

-- ========= TARGETING =========
local function IsRockValid(rockModel)
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end
	
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local curHP = hp or maxHP
	local pct = (maxHP > 0) and ((curHP / maxHP) * 100) or 100

	if pct > (Settings.CheckThreshold or 45) then return true end
	
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

	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") or zone:IsA("Model") then
			if allowAllZones or Settings.Zones[zone.Name] then
				local spawnLoc = zone:FindFirstChild("SpawnLocation") 
				if spawnLoc then
					for _, rockModel in ipairs(spawnLoc:GetChildren()) do
						if rockModel:IsA("Model") then
							if (allowAllRocks or Settings.Rocks[rockModel.Name]) and IsRockValid(rockModel) then
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

-- ========= MAIN LOOP =========
local currentTarget = nil
local stickTime = 0

task.spawn(function()
	D("LOOP", "Final Hit Engine Started")
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
					HitPickaxe() -- HIT!
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

print("[✓] Forge Core: Exact Remote Path Applied.")
