--// ===== The Forge Core (STRICT PATH VERSION) =====
--// Path: Workspace.Rocks.[ZoneName].[SpawnLocation].[RockName]
--// Remote: ReplicatedStorage...ToolActivated
--// Logic: Direct & Strict (No Guessing)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- [1] CONFIG UTAMA (Biar gampang diatur tanpa UI jika perlu)
local TWEEN_SPEED = 40
local Y_OFFSET = -6 -- Posisi player di bawah batu
local HIT_INTERVAL = 0.15

-- [2] SERVICES & DATA
local Player = Players.LocalPlayer
_G.Settings = _G.Settings or {}
local Settings = _G.Settings

-- Default Tables
Settings.Zones = Settings.Zones or {}
Settings.Rocks = Settings.Rocks or {}
Settings.Ores  = Settings.Ores  or {}

-- Fallback Defaults
if Settings.AutoFarm == nil then Settings.AutoFarm = false end
if Settings.TweenSpeed == nil then Settings.TweenSpeed = TWEEN_SPEED end
if Settings.YOffset == nil then Settings.YOffset = Y_OFFSET end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- [3] HELPER FUNCTIONS
local function boolCount(map)
	if type(map) ~= "table" then return false end
	for _, v in pairs(map) do if v then return true end end
	return false
end

local function GetCharAndRoot()
	local c = Player.Character
	if not c then return nil, nil end
	return c, c:FindFirstChild("HumanoidRootPart")
end

-- [4] LOGIKA FILTER ORE (STRICT)
local function CheckOre(rockModel)
	-- Cek apakah ada Ore yang dicentang di Settings
	local anyOreSelected = boolCount(Settings.Ores)
	if not anyOreSelected then return false end -- Kalau tidak ada ore yang dipilih, abaikan fungsi ini

	local foundOreName = nil

	-- Cek 1: Attribute "Ore"
	local att = rockModel:GetAttribute("Ore")
	if att then foundOreName = att end

	-- Cek 2: Child bernama "Ore" (StringValue)
	if not foundOreName then
		local child = rockModel:FindFirstChild("Ore")
		if child and child:IsA("StringValue") then
			foundOreName = child.Value
		end
	end

	-- Final: Apakah ore ini dicentang user?
	if foundOreName and Settings.Ores[foundOreName] then
		return true -- PRIORITAS: Ambil batu ini walau HP rendah
	end

	return false
end

-- [5] LOGIKA VALIDASI BATU
local function IsRockValid(rockModel)
	-- 1. Cek HP (Wajib ada Attribute Health)
	local hp = rockModel:GetAttribute("Health")
	if not hp or hp <= 0 then return false end

	-- 2. Cek Ore (Prioritas Utama)
	if CheckOre(rockModel) then
		return true
	end

	-- 3. Cek Threshold HP (Jika bukan Ore prioritas)
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local pct = (hp / maxHP) * 100
	if pct > (Settings.CheckThreshold or 45) then
		return true
	end

	return false
end

-- [6] LOGIKA PENCARIAN TARGET (STRICT PATH)
local function GetBestTargetPart()
	if not Settings.AutoFarm then return nil end
	local _, root = GetCharAndRoot()
	if not root then return nil end

	local rocksFolder = Workspace:FindFirstChild("Rocks")
	if not rocksFolder then return nil end

	-- Setup Filter Variables
	local zonesSelected = boolCount(Settings.Zones)
	local rocksSelected = boolCount(Settings.Rocks)
	
	-- Logic: Jika tidak ada yang dicentang, bolehkan semua? (Sesuai setting UI)
	local allowAllZones = (not zonesSelected) and (Settings.AllowAllZonesIfNoneSelected ~= false)
	local allowAllRocks = (not rocksSelected) and (Settings.AllowAllRocksIfNoneSelected ~= false)

	local myPos = root.Position
	local closest, minDist = nil, math.huge

	-- LOOP ZONE (Folder Zone)
	for _, zone in ipairs(rocksFolder:GetChildren()) do
		-- Filter Zone: Strict Name Matching
		if allowAllZones or Settings.Zones[zone.Name] then
			
			-- PATH WAJIB: Mencari folder SpawnLocation atau Spawnlocation
			local spawnLoc = zone:FindFirstChild("SpawnLocation") or zone:FindFirstChild("Spawnlocation")
			
			if spawnLoc then
				-- LOOP ROCKS (Model Batu)
				for _, rock in ipairs(spawnLoc:GetChildren()) do
					if rock:IsA("Model") then
						
						-- Filter Rock Name: Strict Name Matching
						if allowAllRocks or Settings.Rocks[rock.Name] then
							
							-- Validasi (HP & Ore)
							if IsRockValid(rock) then
								
								-- Cari Part untuk Target
								local pp = rock.PrimaryPart or rock:FindFirstChild("Hitbox") or rock:FindFirstChildWhichIsA("BasePart")
								
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

-- [7] MOVEMENT & ROTATION (Full Aim + Noclip)
local activeTween = nil
local noclipConn = nil
local lockConn = nil

local function TogglePhysics(enable)
	if enable then
		-- Noclip ON
		if not noclipConn then
			noclipConn = RunService.Stepped:Connect(function()
				local c = Player.Character
				if c then
					for _, v in ipairs(c:GetDescendants()) do
						if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
					end
				end
			end)
		end
	else
		-- Noclip OFF & Unanchor
		if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
		if lockConn then lockConn:Disconnect(); lockConn = nil end
		
		local _, r = GetCharAndRoot()
		if r then r.Anchored = false end
	end
end

local function MoveAndMine(targetPart)
	local _, root = GetCharAndRoot()
	if not root or not targetPart.Parent then return false end

	-- Configs
	local speed = tonumber(Settings.TweenSpeed) or 40
	local yOff = tonumber(Settings.YOffset) or -6
	
	-- Kalkulasi Posisi & Rotasi
	local rockPos = targetPart.Position
	local targetPos = rockPos + Vector3.new(0, yOff, 0)
	
	-- FULL AIM: Menghadap ke arah batu (Pitch + Yaw)
	local targetCFrame = CFrame.lookAt(targetPos, rockPos)

	local dist = (root.Position - targetPos).Magnitude

	-- Aktifkan Noclip
	TogglePhysics(true)

	-- Jika jauh, Tween
	if dist > 3 then
		-- Lepas anchor sebentar untuk tween
		root.Anchored = false
		
		local duration = math.max(0.1, dist / speed)
		local ti = TweenInfo.new(duration, Enum.EasingStyle.Linear)
		
		if activeTween then activeTween:Cancel() end
		activeTween = TweenService:Create(root, ti, {CFrame = targetCFrame})
		activeTween:Play()
		
		local t0 = os.clock()
		while (os.clock() - t0 < duration) do
			if not Settings.AutoFarm or not targetPart.Parent then 
				if activeTween then activeTween:Cancel() end
				return false 
			end
			task.wait(0.1)
		end
	end
	
	-- Sampai / Dekat: Kunci Posisi (Anchor)
	root.CFrame = targetCFrame
	root.Anchored = true
	
	-- Loop Lock agar tidak jatuh
	if not lockConn then
		lockConn = RunService.Heartbeat:Connect(function()
			if root and root.Parent then
				root.CFrame = targetCFrame
			end
		end)
	end
	
	return true
end

-- [8] REMOTE HIT (EXACT PATH)
local function HitPickaxe()
	-- 1. Auto Equip
	local c = Player.Character
	if c and not c:FindFirstChildOfClass("Tool") then
		local bp = Player:FindFirstChild("Backpack")
		local tool = bp and bp:FindFirstChildOfClass("Tool")
		if tool then 
			c:FindFirstChildOfClass("Humanoid"):EquipTool(tool) 
		end
	end

	-- 2. Invoke Remote (User Provided Path)
	pcall(function()
		local remote = ReplicatedStorage.Shared.Packages.Knit.Services.ToolService.RF.ToolActivated
		remote:InvokeServer("Pickaxe")
	end)
end

-- [9] MAIN LOOP
local currentTarget = nil
local stickTime = 0
local lastHit = 0

task.spawn(function()
	print("Strict Core Started")
	while _G.FarmLoop ~= false do
		task.wait(0.1)

		if not Settings.AutoFarm then
			TogglePhysics(false)
			if activeTween then activeTween:Cancel() end
			task.wait(0.5)
			continue
		end

		local now = os.clock()

		-- Cari Target
		if not currentTarget or not currentTarget.Parent or now > stickTime then
			currentTarget = GetBestTargetPart()
			if currentTarget then
				stickTime = now + (Settings.TargetStickTime or 5)
			end
		end

		-- Eksekusi
		if currentTarget and currentTarget.Parent then
			MoveAndMine(currentTarget)
			
			-- Hit Interval
			if (now - lastHit) >= HIT_INTERVAL then
				local model = currentTarget:FindFirstAncestorOfClass("Model")
				if model and (model:GetAttribute("Health") or 0) > 0 then
					HitPickaxe()
					lastHit = now
				else
					currentTarget = nil -- Batu hancur, cari lagi
				end
			end
		else
			TogglePhysics(false) -- Idle
		end
	end
end)
