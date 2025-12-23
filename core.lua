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
setDefault("AutoReequip", true)

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

-- ========= [4] NOCLIP ENGINE =========
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

-- ========= [6] REMOTE CACHE (IMPROVED) =========
local CACHED_REMOTES = {
	ToolActivated = nil,
	ToolHit = nil,
}

task.spawn(function()
	pcall(function()
		-- [UBAH] Path lengkap ke ToolActivated
		CACHED_REMOTES.ToolActivated = ReplicatedStorage
			:WaitForChild("Shared", 10)
			:WaitForChild("Packages", 10)
			:WaitForChild("Knit", 10)
			:WaitForChild("Services", 10)
			:WaitForChild("ToolService", 10)
			:WaitForChild("RF", 10)
			:WaitForChild("ToolActivated", 10)
		print("[✓] ToolActivated Remote Found")
	end)
	
	-- [TAMBAH] Cari path alternatif untuk Hit Remote
	pcall(function()
		CACHED_REMOTES.ToolHit = ReplicatedStorage
			:WaitForChild("Shared", 10)
			:WaitForChild("Packages", 10)
			:WaitForChild("Knit", 10)
			:WaitForChild("Services", 10)
			:WaitForChild("ToolService", 10)
			:WaitForChild("RF", 10)
			:WaitForChild("ToolHit", 10)
		print("[✓] ToolHit Remote Found")
	end)
end)

-- ========= [7] PICKAXE MANAGEMENT (IMPROVED) =========
local lastPickaxeEquipTime = 0
local EQUIP_COOLDOWN = 0.3

local function EnsurePickaxeEquipped()
	local plr = Players.LocalPlayer
	local char = plr.Character
	if not char then return false end

	-- [CEK] Apakah pickaxe sudah di character
	local pickaxeInChar = char:FindFirstChild("Pickaxe")
	if pickaxeInChar then return true end
	
	-- [AMBIL] Dari backpack
	local backpackPickaxe = plr.Backpack:FindFirstChild("Pickaxe")
	if backpackPickaxe then
		-- [COOLDOWN] Agar tidak spam equip
		local now = tick()
		if (now - lastPickaxeEquipTime) < EQUIP_COOLDOWN then
			return false
		end
		lastPickaxeEquipTime = now
		
		backpackPickaxe.Parent = char
		task.wait(0.1)
		return true
	end
	
	return false
end

-- ========= [8] HIT SYSTEM (REDESIGNED) =========
local function HitPickaxeOptimized()
	local plr = Players.LocalPlayer
	local char = plr.Character
	if not (char and char:FindFirstChild("Humanoid")) then return end

	-- [PASTIKAN] Pickaxe sudah equipped
	if not EnsurePickaxeEquipped() then return end
	
	-- [INVOKE] ToolActivated untuk mulai mining
	if CACHED_REMOTES.ToolActivated then
		pcall(function()
			CACHED_REMOTES.ToolActivated:InvokeServer("Pickaxe")
		end)
	end
	
	-- [INVOKE] ToolHit untuk hit damage (jika ada)
	if CACHED_REMOTES.ToolHit then
		pcall(function()
			CACHED_REMOTES.ToolHit:InvokeServer()
		end)
	end
end

-- ========= [9] TARGET VALIDATION (IMPROVED) =========
local function IsRockValid(rockModel)
	if not rockModel or not rockModel.Parent then return false end
	
	local owner = rockModel:GetAttribute("LastHitPlayer")
	if owner and owner ~= Players.LocalPlayer.Name then return false end

	local hp = rockModel:GetAttribute("Health")
	if hp and hp <= 0 then return false end
	
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local hpPercent = ((hp or maxHP)/maxHP)*100
	
	-- [CEK] Rock selection
	local anyRockSelected = false
	for _, v in pairs(Settings.Rocks) do if v then anyRockSelected = true break end end
	
	-- [CEK] Ore selection
	local anyOreSelected = false
	for _, v in pairs(Settings.Ores) do if v then anyOreSelected = true break end end
	
	-- [LOGIC] Validasi berdasarkan HP
	if hpPercent <= 45 then
		if anyOreSelected then
			for _, child in ipairs(rockModel:GetChildren()) do
				if child.Name == "Ore" and child:IsA("Model") then
					if Settings.Ores[child:GetAttribute("Ore")] then return true end
				end
			end
			return false
		end
		if anyRockSelected then return Settings.Rocks[rockModel.Name] == true end
		return true
	else
		if anyRockSelected then return Settings.Rocks[rockModel.Name] == true end
		return true
	end
end

-- ========= [10] TARGET FINDER =========
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

-- ========= [11] MAIN FARM LOOP (REFACTORED) =========
task.spawn(function()
	local currentTween = nil
	local hitCounter = 0
	
	while _G.FarmLoop do
		task.wait() 

		if Settings.AutoFarm then
			enableNoclip()
			UpdateCameraState()

			local char, root = GetCharAndRoot()
			local hum = GetHumanoid()

			if root and hum and hum.Health > 0 then
				local target = GetBestTargetPart()

				if target then
					local rockPos = target.Position
					local standPos = rockPos + Vector3.new(0, Settings.YOffset, 0)
					local lookCF = CFrame.lookAt(standPos, rockPos)
					local dist = (root.Position - standPos).Magnitude

					if dist > 3 then
						-- ===== MOVEMENT PHASE =====
						root.Anchored = false
						hum.PlatformStand = false 
						
						local speed = Settings.TweenSpeed or 45
						-- [FIX] Duration clamp untuk prevent NumberSequence error
						local duration = math.max(0.15, dist / speed)
						local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
						
						if not currentTween or currentTween.PlaybackState == Enum.PlaybackState.Completed then
							pcall(function()
								currentTween = TweenService:Create(root, info, {CFrame = lookCF})
								currentTween:Play()
							end)
						else
							pcall(function()
								currentTween:Cancel()
								currentTween = TweenService:Create(root, info, {CFrame = lookCF})
								currentTween:Play()
							end)
						end
						
						hitCounter = 0 -- Reset hit counter saat bergerak
						task.wait(0.05)
						
					else
						-- ===== MINING PHASE =====
						if currentTween then 
							pcall(function() currentTween:Cancel() end)
							currentTween = nil 
						end
						
						-- [ANCHOR] Character agar stabil
						root.CFrame = lookCF
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						root.Anchored = true 
						
						-- [HIT] Pickaxe berkali-kali untuk damage
						HitPickaxeOptimized()
						hitCounter = hitCounter + 1
						
						-- [LOG] Debug info
						if hitCounter % 10 == 0 then
							local targetHP = target.Parent:GetAttribute("Health") or 100
							print(string.format("[MINING] Hit #%d | Target HP: %d", hitCounter, targetHP))
						end
						
						task.wait(Settings.HitInterval)
					end
				else
					-- [IDLE] Tidak ada target
					if currentTween then 
						pcall(function() currentTween:Cancel() end)
					end
					root.Anchored = false
					hitCounter = 0
					task.wait(0.5)
				end
			end
		else
			-- [DISABLE] AutoFarm mode
			disableNoclip()
			local _, r = GetCharAndRoot()
			if r then r.Anchored = false end
		end
	end
end)

print("[✓] FARM SCRIPT V2 LOADED - DAMAGE SYSTEM FIXED")
print("[✓] Features: Auto Equip | Dual Remote | Hit Optimization")
