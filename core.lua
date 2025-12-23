local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========= [1] DATA REPOSITORY =========
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

-- [GUI COMPATIBILITY] Farm Status Container
-- Ini agar GUI bisa membaca status target saat ini
_G.FarmStatus = {
	TargetName = "None",
	Distance = 0,
	TargetHP = 0,
	MaxHP = 0
}

local function setDefault(k, v)
	if Settings[k] == nil then Settings[k] = v end
end

setDefault("AutoFarm", false)
setDefault("TweenSpeed", 45)
setDefault("YOffset", -4)
setDefault("HitInterval", 0.15)
setDefault("CameraStabilize", true)

-- Ensure keys exist for GUI switches
for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- ========= [3] DYNAMIC DEBUG SYSTEM (GUI LINKED) =========
-- Fungsi ini mengecek apakah GUI sudah mendefinisikan _G.DebugLog.
-- Jika ya, ia menggunakan logger GUI. Jika tidak, pakai print biasa.
local function DebugLog(tag, message, logType)
	if _G.DebugLog and typeof(_G.DebugLog) == "function" then
		pcall(function() _G.DebugLog(tag, message, logType) end)
	else
		-- Fallback jika GUI belum load
		local timestamp = os.date("%H:%M:%S")
		local prefix = (logType == "ERROR" and "⚠️") or (logType == "SUCCESS" and "✓") or "ℹ️"
		print(string.format("[%s] %s [%s] %s", timestamp, prefix, tag, message))
	end
end

-- Init Debug log default jika belum ada (agar tidak error sebelum GUI load)
if not _G.DebugLog then
	_G.DebugLog = DebugLog
end

-- ========= [4] UTILS & HELPERS =========
local function GetCharAndRoot()
	local c = Players.LocalPlayer.Character
	if not (c and c.Parent) then return nil, nil end
	local r = c:FindFirstChild("HumanoidRootPart")
	return c, r
end

local function GetHumanoid()
	local c = Players.LocalPlayer.Character
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

-- ========= [5] NOCLIP ENGINE =========
local noclipConn
local function enableNoclip()
	if noclipConn then return end
	noclipConn = RunService.Stepped:Connect(function()
		local c = Players.LocalPlayer.Character
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
	if noclipConn then noclipConn:Disconnect() end
	noclipConn = nil
end

-- ========= [6] CAMERA STABILIZER =========
local function UpdateCameraState()
	local plr = Players.LocalPlayer
	local c = plr.Character
	
	if Settings.AutoFarm and Settings.CameraStabilize and c then
		local hum = c:FindFirstChild("Humanoid")
		if hum then
			Workspace.CurrentCamera.CameraSubject = hum
			plr.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
		end
	end
end

-- ========= [7] REMOTE CACHE =========
local CACHED_REMOTE = nil
local REMOTE_FOUND = false

task.spawn(function()
	DebugLog("REMOTE", "Scanning for ToolActivated...", "DEBUG")
	pcall(function()
		local rf = ReplicatedStorage:WaitForChild("Shared", 5)
			:WaitForChild("Packages", 5):WaitForChild("Knit", 5)
			:WaitForChild("Services", 5):WaitForChild("ToolService", 5)
			:WaitForChild("RF", 5)
		
		CACHED_REMOTE = rf:WaitForChild("ToolActivated", 10)
		REMOTE_FOUND = true
		DebugLog("REMOTE", "ToolActivated Found & Cached", "SUCCESS")
	end)
	
	if not REMOTE_FOUND then
		DebugLog("REMOTE", "FAILED to find Remote. Script may fail.", "ERROR")
	end
end)

-- ========= [8] PICKAXE MANAGER =========
local function CheckPickaxeEquipped()
	local plr = Players.LocalPlayer
	local char = plr.Character
	if not char then return false end

	if char:FindFirstChild("Pickaxe") then return true end
	
	local bp = plr.Backpack:FindFirstChild("Pickaxe")
	if bp then
		bp.Parent = char
		return true
	end
	return false
end

-- ========= [9] HIT SYSTEM =========
local function HitTargetDamage(targetPart)
	if not CheckPickaxeEquipped() then return false end
	if not REMOTE_FOUND or not CACHED_REMOTE then return false end

	local success, _ = pcall(function()
		return CACHED_REMOTE:InvokeServer("Pickaxe", targetPart)
	end)

	return success
end

-- ========= [10] TARGET VALIDATION =========
local function IsRockValid(rockModel)
	if not rockModel or not rockModel.Parent then return false end
	
	local owner = rockModel:GetAttribute("LastHitPlayer")
	if owner and owner ~= Players.LocalPlayer.Name and owner ~= "" then
		-- return false -- Uncomment to respect ownership
	end

	local hp = rockModel:GetAttribute("Health")
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	
	if hp and hp <= 0 then return false end
	
	local hpPercent = ((hp or maxHP)/maxHP)*100
	local anyRockSelected = false
	for _, v in pairs(Settings.Rocks) do if v then anyRockSelected = true break end end
	local anyOreSelected = false
	for _, v in pairs(Settings.Ores) do if v then anyOreSelected = true break end end

	if hpPercent <= 45 then
		if anyOreSelected then
			for _, child in ipairs(rockModel:GetChildren()) do
				if child.Name == "Ore" and child:IsA("Model") then
					if Settings.Ores[child:GetAttribute("Ore")] then return true end
				end
			end
			if anyRockSelected then return Settings.Rocks[rockModel.Name] == true end
			return false
		end
		if anyRockSelected then return Settings.Rocks[rockModel.Name] == true end
		return true
	else
		if anyRockSelected then return Settings.Rocks[rockModel.Name] == true end
		return true
	end
end

-- ========= [11] TARGET FINDER =========
local function GetBestTargetPart()
	local _, r = GetCharAndRoot()
	if not r then return nil end
	
	local rocksFolder = Workspace:FindFirstChild("Rocks")
	if not rocksFolder then return nil end

	local anyZ = false
	for _, v in pairs(Settings.Zones) do if v then anyZ = true break end end

	local closest, minDist = nil, math.huge
	
	for _, zone in ipairs(rocksFolder:GetChildren()) do
		if zone:IsA("Folder") and (not anyZ or Settings.Zones[zone.Name]) then
			for _, inst in ipairs(zone:GetDescendants()) do
				if inst:IsA("Model") and inst.Parent.Name ~= "Rock" then
					if IsRockValid(inst) then
						local p = inst.PrimaryPart or inst:FindFirstChild("Hitbox") or inst:FindFirstChild("Part")
						if p then
							local d = (r.Position - p.Position).Magnitude
							if d < minDist then 
								minDist = d
								closest = p
							end
						end
					end
				end
			end
		end
	end
	
	return closest
end

-- ========= [12] MAIN LOOP =========
task.spawn(function()
	local currentTween = nil
	local loopCounter = 0
	
	DebugLog("CORE", "Logic loop initialized", "SUCCESS")
	
	while _G.FarmLoop do
		task.wait() 
		loopCounter = loopCounter + 1

		if Settings.AutoFarm then
			enableNoclip()
			UpdateCameraState()

			local char, root = GetCharAndRoot()
			local hum = GetHumanoid()

			if not (root and hum and hum.Health > 0) then
				task.wait(0.5)
				goto loop_end
			end

			local target = GetBestTargetPart()

			-- [GUI SYNC] Update Status Global
			if target and target.Parent then
				local pModel = target.Parent
				_G.FarmStatus.TargetName = pModel.Name
				_G.FarmStatus.Distance = math.floor((root.Position - target.Position).Magnitude)
				_G.FarmStatus.TargetHP = math.floor(pModel:GetAttribute("Health") or 0)
				_G.FarmStatus.MaxHP = math.floor(pModel:GetAttribute("MaxHealth") or 100)
			else
				_G.FarmStatus.TargetName = "Searching..."
				_G.FarmStatus.Distance = 0
				_G.FarmStatus.TargetHP = 0
			end

			if not target then
				if currentTween then currentTween:Cancel() end
				task.wait(0.2)
				goto loop_end
			end

			local rockPos = target.Position
			local standPos = rockPos + Vector3.new(0, Settings.YOffset, 0)
			local lookCF = CFrame.lookAt(standPos, Vector3.new(rockPos.X, standPos.Y, rockPos.Z))
			local dist = (root.Position - standPos).Magnitude

			if dist > 3.5 then
				-- MOVEMENT
				root.Anchored = false
				local speed = Settings.TweenSpeed or 45
				local duration = math.max(0.1, dist / speed)
				local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
				
				if not currentTween or currentTween.PlaybackState == Enum.PlaybackState.Completed then
					pcall(function()
						currentTween = TweenService:Create(root, info, {CFrame = lookCF})
						currentTween:Play()
						DebugLog("MOVE", "Moving to " .. target.Parent.Name .. " ("..math.floor(dist).." studs)", "DEBUG")
					end)
				else
					if (currentTween.Instance ~= root) then currentTween:Cancel() end
				end
				task.wait(0.1)
			else
				-- MINING
				if currentTween then 
					pcall(function() currentTween:Cancel() end)
					currentTween = nil 
				end
				
				root.AssemblyLinearVelocity = Vector3.zero 
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = lookCF
				root.Anchored = true 
				
				local hitSuccess = HitTargetDamage(target)
				
				-- Optional: Log hit jarang-jarang agar tidak spam
				if loopCounter % 20 == 0 then
					DebugLog("MINE", "Hitting " .. target.Parent.Name .. " | HP: " .. _G.FarmStatus.TargetHP, "DEBUG")
				end

				task.wait(Settings.HitInterval)
			end

			::loop_end::
		else
			disableNoclip()
			local _, r = GetCharAndRoot()
			if r then r.Anchored = false end
			if currentTween then currentTween:Cancel() end
			
			_G.FarmStatus.TargetName = "Idle"
			task.wait(1)
		end
	end
end)

-- ========= [13] READY SIGNAL =========
task.wait(0.5)
DebugLog("CORE", "Core Script Ready for GUI", "SUCCESS")
