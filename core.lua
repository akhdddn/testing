local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
setDefault("TweenSpeed", 45)
setDefault("YOffset", -4)
setDefault("HitInterval", 0.15)
setDefault("CameraStabilize", true)

for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- ========= [3] DEBUG SYSTEM (ADDED) =========
local DEBUG = {
	Enabled = true,
	Logs = {},
	MaxLogs = 100,
}

-- [TAMBAH] Debug log function
local function DebugLog(tag, message, logType)
	logType = logType or "INFO"
	local timestamp = os.date("%H:%M:%S")
	local logEntry = string.format("[%s] [%s] [%s] %s", timestamp, tag, logType, message)
	
	table.insert(DEBUG.Logs, logEntry)
	if #DEBUG.Logs > DEBUG.MaxLogs then table.remove(DEBUG.Logs, 1) end
	
	print(logEntry)
	
	-- [TAMBAH] Color coding untuk error
	if logType == "ERROR" then
		warn("⚠️ ERROR: " .. message) -- Menggunakan warn agar kuning di console
	elseif logType == "SUCCESS" then
		print("✓ SUCCESS: " .. message)
	elseif logType == "DEBUG" then
		print("🔍 DEBUG: " .. message)
	end
end

-- [TAMBAH] Dump debug logs
local function DumpDebugLogs()
	print("\n========= DEBUG LOG DUMP ==========")
	for i, log in ipairs(DEBUG.Logs) do
		print(string.format("%d. %s", i, log))
	end
	print("====================================\n")
end

_G.DebugLog = DebugLog
_G.DumpDebugLogs = DumpDebugLogs

-- ========= [4] UTILS & HELPERS =========
local function GetCharAndRoot()
	local c = Players.LocalPlayer.Character
	if not (c and c.Parent) then 
		DebugLog("CHAR", "Character not found", "ERROR")
		return nil, nil 
	end
	local r = c:FindFirstChild("HumanoidRootPart")
	if not r then
		DebugLog("CHAR", "HumanoidRootPart not found", "ERROR")
		return nil, nil
	end
	return c, r
end

local function GetHumanoid()
	local c = Players.LocalPlayer.Character
	if not c then return nil end
	return c:FindFirstChildOfClass("Humanoid")
end

-- ========= [5] NOCLIP ENGINE (OPTIMIZED) =========
local noclipConn
local function enableNoclip()
	if noclipConn then return end
	noclipConn = RunService.Stepped:Connect(function()
		local c = Players.LocalPlayer.Character
		if c then
			for _, v in ipairs(c:GetDescendants()) do
				if v:IsA("BasePart") and v.CanCollide == true then
					-- ARCHITECT NOTE: Hanya set jika true untuk hemat performa
					v.CanCollide = false
				end
			end
		end
	end)
	DebugLog("NOCLIP", "Enabled", "SUCCESS")
end

local function disableNoclip()
	if noclipConn then noclipConn:Disconnect() end
	noclipConn = nil
	DebugLog("NOCLIP", "Disabled", "SUCCESS")
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

-- ========= [7] REMOTE CACHE WITH DEBUG =========
local CACHED_REMOTE = nil
local REMOTE_FOUND = false

task.spawn(function()
	DebugLog("REMOTE", "Attempting to cache ToolActivated remote...", "DEBUG")
	pcall(function()
		local shared = ReplicatedStorage:WaitForChild("Shared", 10)
		DebugLog("REMOTE", "Found: Shared", "DEBUG")
		
		local packages = shared:WaitForChild("Packages", 10)
		DebugLog("REMOTE", "Found: Packages", "DEBUG")
		
		local knit = packages:WaitForChild("Knit", 10)
		DebugLog("REMOTE", "Found: Knit", "DEBUG")
		
		local services = knit:WaitForChild("Services", 10)
		DebugLog("REMOTE", "Found: Services", "DEBUG")
		
		local toolService = services:WaitForChild("ToolService", 10)
		DebugLog("REMOTE", "Found: ToolService", "DEBUG")
		
		local rf = toolService:WaitForChild("RF", 10)
		DebugLog("REMOTE", "Found: RF", "DEBUG")
		
		CACHED_REMOTE = rf:WaitForChild("ToolActivated", 10)
		REMOTE_FOUND = true
		DebugLog("REMOTE", "✓ ToolActivated cached successfully", "SUCCESS")
		print("Remote object:", CACHED_REMOTE)
		print("Remote class:", CACHED_REMOTE.ClassName)
	end)
	
	if not REMOTE_FOUND then
		DebugLog("REMOTE", "FAILED to cache remote (Check Paths)", "ERROR")
	end
end)

-- ========= [8] PICKAXE MANAGER WITH DEBUG =========
local function CheckPickaxeEquipped()
	local plr = Players.LocalPlayer
	local char = plr.Character
	if not char then
		DebugLog("PICKAXE", "Character not found", "ERROR")
		return false
	end

	local pickaxeInChar = char:FindFirstChild("Pickaxe")
	if pickaxeInChar then
		-- DebugLog("PICKAXE", "Already equipped", "DEBUG") -- Spammy log
		return true
	end
	
	DebugLog("PICKAXE", "Not in character, checking backpack", "DEBUG")
	local backpackPickaxe = plr.Backpack:FindFirstChild("Pickaxe")
	
	if backpackPickaxe then
		DebugLog("PICKAXE", "Found in backpack, equipping...", "DEBUG")
		backpackPickaxe.Parent = char
		task.wait(0.1) -- Beri waktu sedikit untuk server mereplikasi
		
		local equipped = char:FindFirstChild("Pickaxe")
		if equipped then
			DebugLog("PICKAXE", "✓ Successfully equipped", "SUCCESS")
			return true
		else
			DebugLog("PICKAXE", "Failed to equip (parent change failed)", "ERROR")
			return false
		end
	else
		DebugLog("PICKAXE", "Pickaxe NOT found in Backpack!", "ERROR")
		return false
	end
end

-- ========= [9] HIT SYSTEM WITH DEBUG (LOGIC FIXED) =========
local hitCounter = 0

-- ARCHITECT FIX: Menambahkan parameter targetPart agar remote tahu apa yang dipukul
local function HitTargetDamage(targetPart)
	hitCounter = hitCounter + 1
	local hitID = hitCounter
	
	-- DebugLog("HIT", "Hit attempt #" .. hitID, "DEBUG") -- Un-comment jika perlu trace detail
	
	local plr = Players.LocalPlayer
	local char = plr.Character
	
	if not char then return false end
	
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end

	-- [DEBUG] Check pickaxe
	if not CheckPickaxeEquipped() then return false end

	-- [DEBUG] Check remote
	if not REMOTE_FOUND or not CACHED_REMOTE then
		DebugLog("HIT", "[#" .. hitID .. "] Remote invalid", "ERROR")
		return false
	end

	-- [ARCHITECT FIX] Invoking dengan target part
	-- Banyak game membutuhkan instance target sebagai argumen
	local success, result = pcall(function()
		return CACHED_REMOTE:InvokeServer("Pickaxe", targetPart)
	end)

	if success then
		-- DebugLog("HIT", "[#" .. hitID .. "] ✓ Remote invoked", "SUCCESS")
		return true
	else
		DebugLog("HIT", "[#" .. hitID .. "] Remote invoke failed: " .. tostring(result), "ERROR")
		return false
	end
end

-- ========= [10] TARGET VALIDATION WITH DEBUG =========
local function IsRockValid(rockModel)
	if not rockModel or not rockModel.Parent then
		return false
	end
	
	-- Check ownership (agar tidak mencuri batu orang lain jika game membatasinya)
	local owner = rockModel:GetAttribute("LastHitPlayer")
	if owner and owner ~= Players.LocalPlayer.Name and owner ~= "" then
		-- Opsional: return false jika ingin menghindari KS (Kill Steal)
		-- return false 
	end

	local hp = rockModel:GetAttribute("Health")
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	
	if hp and hp <= 0 then
		return false
	end
	
	local hpPercent = ((hp or maxHP)/maxHP)*100
	
	local anyRockSelected = false
	for _, v in pairs(Settings.Rocks) do if v then anyRockSelected = true break end end
	
	local anyOreSelected = false
	for _, v in pairs(Settings.Ores) do if v then anyOreSelected = true break end end

	-- Prioritas Ore (biasanya muncul saat HP batu rendah)
	if hpPercent <= 45 then
		if anyOreSelected then
			for _, child in ipairs(rockModel:GetChildren()) do
				if child.Name == "Ore" and child:IsA("Model") then
					if Settings.Ores[child:GetAttribute("Ore")] then return true end
				end
			end
			-- Jika tidak ada ore spesifik, cek apakah batu itu sendiri dipilih
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

-- ========= [11] TARGET FINDER WITH DEBUG =========
local targetFindCounter = 0

local function GetBestTargetPart()
	targetFindCounter = targetFindCounter + 1
	
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

-- ========= [12] MAIN LOOP WITH DEBUG =========
task.spawn(function()
	local currentTween = nil
	local loopCounter = 0
	
	DebugLog("LOOP", "Farm loop started", "SUCCESS")
	
	while _G.FarmLoop do
		task.wait() 
		loopCounter = loopCounter + 1

		if Settings.AutoFarm then
			-- [DEBUG] Heartbeat check
			if loopCounter % 120 == 0 then
				DebugLog("LOOP", "Heartbeat (Active)", "DEBUG")
			end
			
			enableNoclip()
			UpdateCameraState()

			local char, root = GetCharAndRoot()
			local hum = GetHumanoid()

			if not (root and hum and hum.Health > 0) then
				task.wait(0.5)
				goto loop_end
			end

			local target = GetBestTargetPart()

			if not target then
				-- Jika tidak ada target, diamkan karakter
				if currentTween then currentTween:Cancel() end
				task.wait(0.5)
				goto loop_end
			end

			local rockPos = target.Position
			local standPos = rockPos + Vector3.new(0, Settings.YOffset, 0)
			local lookCF = CFrame.lookAt(standPos, Vector3.new(rockPos.X, standPos.Y, rockPos.Z))
			local dist = (root.Position - standPos).Magnitude

			if dist > 3.5 then
				-- ===== MOVEMENT PHASE =====
				root.Anchored = false
				
				local speed = Settings.TweenSpeed or 45
				local duration = math.max(0.1, dist / speed)
				local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
				
				if not currentTween or currentTween.PlaybackState == Enum.PlaybackState.Completed then
					pcall(function()
						currentTween = TweenService:Create(root, info, {CFrame = lookCF})
						currentTween:Play()
					end)
				else
					-- Logic untuk memperbarui tween jika target bergerak sedikit
					if (currentTween.Instance == root) then
						-- Biarkan tween berjalan, kecuali target berubah drastis
					else
						currentTween:Cancel()
					end
				end
				
				task.wait(0.05)
				
			else
				-- ===== MINING PHASE =====
				if currentTween then 
					pcall(function() currentTween:Cancel() end)
					currentTween = nil 
				end
				
				-- Kunci posisi & hapus momentum
				root.AssemblyLinearVelocity = Vector3.zero 
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = lookCF -- Paksa hadap target
				root.Anchored = true 
				
				-- [ARCHITECT FIX] Pass 'target' ke fungsi hit
				local hitSuccess = HitTargetDamage(target)
				
				task.wait(Settings.HitInterval)
			end

			::loop_end::
		else
			disableNoclip()
			local _, r = GetCharAndRoot()
			if r then r.Anchored = false end
			if currentTween then currentTween:Cancel() end
			task.wait(1)
		end
	end
	
	DebugLog("LOOP", "Farm loop ended", "SUCCESS")
end)

-- ========= [13] STARTUP DEBUG =========
task.wait(1)
print("\n========= ARCHITECT FIXED SCRIPT STARTED ==========")
DebugLog("STARTUP", "Script loaded & Optimized", "SUCCESS")
DebugLog("STARTUP", "AutoFarm setting: " .. tostring(Settings.AutoFarm), "DEBUG")
DebugLog("STARTUP", "Type: _G.DumpDebugLogs() to see full log", "INFO")
print("==================================================\n")
