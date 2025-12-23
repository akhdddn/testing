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
setDefault("TweenSpeed", 45) -- Sedikit dipercepat untuk responsivitas
setDefault("YOffset", -4)
setDefault("ScanInterval", 0.25)
setDefault("HitInterval", 0.15)
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
local noclipConn
local function enableNoclip()
	if noclipConn then return end
	noclipConn = RunService.Stepped:Connect(function()
		local c = Players.LocalPlayer.Character
		if c then
			for _, v in ipairs(c:GetDescendants()) do
				if v:IsA("BasePart") and v.CanCollide then
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

-- ========= [5] CAMERA STABILIZER =========
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

-- ========= [6] TARGET LOGIC & HIT =========
local CACHED_REMOTE = nil
task.spawn(function()
	pcall(function()
		CACHED_REMOTE = game:GetService("ReplicatedStorage")
			:WaitForChild("Shared", 10)
			:WaitForChild("Packages", 10)
			:WaitForChild("Knit", 10)
			:WaitForChild("Services", 10)
			:WaitForChild("ToolService", 10)
			:WaitForChild("RF", 10)
			:WaitForChild("ToolActivated", 10)
	end)
end)

local function HitPickaxe()
	if CACHED_REMOTE then
		CACHED_REMOTE:InvokeServer("Pickaxe")
	end
end

local function IsRockValid(rockModel)
	-- Anti-KS
	local owner = rockModel:GetAttribute("LastHitPlayer")
	if owner and owner ~= Players.LocalPlayer.Name then return false end

	-- Dead Check
	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end
	
	-- Filter Logic
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local hpPercent = ((hp or maxHP)/maxHP)*100
	
	-- Cek Filter Ore/Rock Selection
	local anyR = false
	for _, v in pairs(Settings.Rocks) do if v then anyR = true break end end
	local anyO = false
	for _, v in pairs(Settings.Ores) do if v then anyO = true break end end

	if hpPercent <= 45 then -- Revealed
		if anyOreSelected then
			local hasTargetOre = false
			for _, child in ipairs(rockModel:GetChildren()) do
				if child.Name == "Ore" and child:IsA("Model") then
					if Settings.Ores[child:GetAttribute("Ore")] then return true end
				end
			end
			return false
		end
		if anyRockSelected then return Settings.Rocks[rockModel.Name] == true end
		return true
	else -- Hidden
		if anyRockSelected then return Settings.Rocks[rockModel.Name] == true end
		return true
	end
end

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
						local p = inst.PrimaryPart or inst:FindFirstChild("Hitbox")
						if p then
							local d = (r.Position - p.Position).Magnitude
							if d < minDist then minDist = d; closest = p end
						end
					end
				end
			end
		end
	end
	return closest
end

-- ========= [7] SIMPLIFIED MAIN LOOP =========
task.spawn(function()
	local currentTween = nil
	
	while _G.FarmLoop do
		-- Loop cepat agar responsif
		task.wait() 

		if Settings.AutoFarm then
			-- 1. Selalu Noclip
			enableNoclip()
			UpdateCameraState()

			local char, root = GetCharAndRoot()
			local hum = GetHumanoid()

			if root and hum and hum.Health > 0 then
				local target = GetBestTargetPart()

				if target then
					-- Kalkulasi Posisi
					local rockPos = target.Position
					local standPos = rockPos + Vector3.new(0, Settings.YOffset, 0)
					local lookCF = CFrame.lookAt(standPos, rockPos)
					local dist = (root.Position - standPos).Magnitude

					-- 2. Logika Gerak vs Diam
					if dist > 3 then
						-- MODE: TERBANG
						root.Anchored = false
						hum.PlatformStand = false 
						
						-- Hitung durasi tween
						local speed = Settings.TweenSpeed or 45
						local info = TweenInfo.new(dist / speed, Enum.EasingStyle.Linear)
						
						-- Cek apakah perlu buat tween baru (biar gak spam object)
						if not currentTween or currentTween.PlaybackState == Enum.PlaybackState.Completed then
							currentTween = TweenService:Create(root, info, {CFrame = lookCF})
							currentTween:Play()
						else
							-- Kalau target berubah drastis, cancel yg lama
							currentTween:Cancel()
							currentTween = TweenService:Create(root, info, {CFrame = lookCF})
							currentTween:Play()
						end
						
						-- Tunggu sebentar biar loop tidak spam CPU saat tween
						task.wait(0.05)
					else
						-- MODE: POSISI TETAP (MINING)
						if currentTween then currentTween:Cancel() currentTween = nil end
						
						-- Kunci Posisi secara Absolut
						root.CFrame = lookCF
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						root.Anchored = true -- Sesuai perintah: Posisi Tetap
						
						-- Pukul
						HitPickaxe()
						
						-- Delay Hit agar tidak terlalu cepat
						task.wait(Settings.HitInterval)
					end
				else
					-- Tidak ada target: Diam di tempat (atau unanchor bebas)
					if currentTween then currentTween:Cancel() end
					root.Anchored = false
				end
			end
		else
			-- AutoFarm Mati
			disableNoclip()
			local _, r = GetCharAndRoot()
			if r then r.Anchored = false end
		end
	end
end)

print("[✓] LOGIKA REVISI: FLY -> ANCHOR -> HIT")
