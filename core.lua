--// Forge Core (OPTIMAL) - CACHED SCAN + ORE-STRICT + ORE-REVEAL LOGIC
--// Drop as a LocalScript (client). Keeps _G.DATA / _G.Settings compatibility.

-- ========= SERVICES =========
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local CAMERA_BIND_NAME = "Forge_CameraFollow_Optim"

-- ========= DATA (Synced with latest screenshots) =========
local DATA = {
	Zones = {
		"Island2CaveDanger1", "Island2CaveDanger2", "Island2CaveDanger3",
		"Island2CaveDanger4", "Island2CaveDangerClosed", "Island2CaveDeep",
		"Island2CaveLavaClosed", "Island2CaveMid", "Island2CaveStart",
		"Island2GoblinCave", "Island2VolcanicDepths", "Iceberg",
		"Island3CavePeakEnd", "Island3CavePeakLeft", "Island3CavePeakRight",
		"Island3CavePeakStart", "Island3RedCave", "Island3SpiderCaveMid",
		"Island3SpiderCaveMid0", "Island3SpiderCaveMid2", "Island3SpiderCaveStart",
		"Island3SpiderCaveStart0", "Island3SpiderCaveStart2",
	},
	Rocks = {
		"Basalt", "Basalt Core", "Basalt Rock", "Basalt Vein", "Boulder",
		"Crimson Crystal", "Cyan Crystal", "Earth Crystal", "Floating Crystal",
		"Heart Of The Island", "Iceberg", "Icy Boulder", "Icy Pebble", "Icy Rock",
		"Large Ice Crystal", "Lava Rock", "Light Crystal", "Lucky Block",
		"Medium Ice Crystal", "Pebble", "Rock", "Small Ice Crystal",
		"Violet Crystal", "Volcanic Rock",
	},
	Ores = {
		"Aether Lotus", "Aetherit", "Aite", "Amethyst", "Aqujade",
		"Arcane Crystal", "Bananite", "Blue Crystal", "Boneite", "Cardboardite",
		"Ceyite", "Cobalt", "Coinite", "Copper", "Crimson Crystal",
		"Crimsonite", "Cryptex", "Cuprite", "Dark Boneite", "Darkryte",
		"Demonite", "Diamond", "Emerald", "Eye Ore", "Fichillium",
		"Fichilliumorite", "Fireite", "Galaxite", "Galestor", "Gargantuan",
		"Gold", "Graphite", "Grass", "Green Crystal", "Heavenite",
		"Iceite", "Iron", "Jade", "Lapis Lazuli", "Larimar",
		"Lgarite", "Lightite", "Magenta Crystal", "Magmaite", "Malachite",
		"Marblite", "Meteorite", "Mistvein", "Moltenfrost", "Mosasaursit",
		"Mushroomite", "Mythril", "Neurotite", "Obsidian", "Orange Crystal",
		"Platinum", "Poopite", "Pumice", "Quartz", "Rainbow Crystal",
		"Rivalite", "Ruby", "Sanctis", "Sand Stone", "Sapphire",
		"Scheelite", "Silver", "Slimite", "Snowite", "Starite",
		"Stone", "Tin", "Titanium", "Topaz", "Uranium", "Volcanic Rock",
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

-- Base & Farm
setDefault("AutoFarm", false)
setDefault("TweenSpeed", 55)
setDefault("YOffset", 3)
setDefault("CheckThreshold", 0) -- Diabaikan karena kita pakai logika OreReveal
setDefault("ScanInterval", 0.12)
setDefault("HitInterval", 0.12)
setDefault("TargetStickTime", 0.25)
setDefault("ArriveDistance", 2.25)
setDefault("RetweenDistance", 6)

-- ORE REVEAL LOGIC (OPSI B)
setDefault("OreRevealThreshold", 50)            -- HP % saat ore muncul
setDefault("AllowUnknownOreAboveReveal", true) -- Target rock walau ore belum muncul

-- Behavior
setDefault("AllowAllZonesIfNoneSelected", true)
setDefault("AllowAllRocksIfNoneSelected", true)
setDefault("AllowAllOresIfNoneSelected", true)
setDefault("RequireOreMatchWhenSelected", true)

-- Lock & Camera Settings... (Sama seperti sebelumnya)
setDefault("LockToTarget", true)
setDefault("LockMode", "Constraint")
setDefault("LockVelocityZero", true)
setDefault("KeepNoclipWhileLocked", true)
setDefault("ConstraintResponsiveness", 200)
setDefault("ConstraintMaxForce", 1e9)
setDefault("CameraStabilize", true)
setDefault("CameraSmoothAlpha", 1)
setDefault("CameraOffsetMode", "World")
setDefault("CameraOffset", Vector3.new(0, 10, 18))

-- Init Checkboxes
for _, n in ipairs(DATA.Zones) do if Settings.Zones[n] == nil then Settings.Zones[n] = false end end
for _, n in ipairs(DATA.Rocks) do if Settings.Rocks[n] == nil then Settings.Rocks[n] = false end end
for _, n in ipairs(DATA.Ores)  do if Settings.Ores[n]  == nil then Settings.Ores[n]  = false end end

if _G.FarmLoop == nil then _G.FarmLoop = true end

-- ========= UTILS =========
local function GetHealthPct(rockModel)
	local hp = rockModel:GetAttribute("Health")
	local maxHP = rockModel:GetAttribute("MaxHealth") or 100
	local curHP = hp or maxHP
	return (maxHP > 0) and ((curHP / maxHP) * 100) or 100
end

local function AnyOreSelected()
	local any = false
	for _, v in pairs(Settings.Ores) do if v == true then any = true break end end
	return any
end

local function GetOreType(rockModel)
	for _, child in ipairs(rockModel:GetChildren()) do
		if child.Name == "Ore" then
			return child:GetAttribute("Ore")
		end
	end
	return nil
end

--// LOGIKAL ORE REVEAL (OPSI B)
local function RockMatchesOreSelection(rockModel, cachedOreType)
	local oresAny = AnyOreSelected()
	local allowAllOres = (Settings.AllowAllOresIfNoneSelected == true) and (not oresAny)
	if allowAllOres then return true end

	local oreType = cachedOreType or GetOreType(rockModel)
	
	-- Jika ore belum muncul (nil)
	if oreType == nil then
		if oresAny and Settings.AllowUnknownOreAboveReveal then
			local pct = GetHealthPct(rockModel)
			-- Boleh target jika HP masih di atas ambang reveal
			if pct > (Settings.OreRevealThreshold or 50) then
				return true 
			end
		end
		return false
	end

	-- Jika ore sudah muncul: Cek apakah sesuai pilihan
	return Settings.Ores[oreType] == true
end

-- ========= CORE LOGIC (STRIPPED VERSION FOR BREVITY) =========
-- (Fungsi GetChar, StartLock, Tween, Noclip, dll tetap sama dengan script asli kamu)

--// [REDACTED: Helper functions like StartLock, StartCamera, HitPickaxe are identical to your source]
--// Pastikan menyalin bagian Character Utils, Noclip, Camera, Tool Remote, dan RockIndex dari script asli Anda ke sini.

-- ========= TARGET SELECTION (CACHED) =========
local function GetBestTargetPart()
	if not Settings.AutoFarm then return nil end
	local Player = game:GetService("Players").LocalPlayer
	local char = Player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	if not r then return nil end

	local zonesAny = false
	for _, v in pairs(Settings.Zones) do if v == true then zonesAny = true break end end
	local rocksAny = false
	for _, v in pairs(Settings.Rocks) do if v == true then rocksAny = true break end end

	local allowAllZones = (Settings.AllowAllZonesIfNoneSelected == true) and (not zonesAny)
	local allowAllRocks = (Settings.AllowAllRocksIfNoneSelected == true) and (not rocksAny)

	local myPos = r.Position
	local closestPart, minDist = nil, math.huge

	-- Menggunakan RockIndex yang sudah di-cache (Event Driven)
	for _, e in ipairs(RockIndex.entries) do
		local model = e.model
		if model and model.Parent then
			if allowAllZones or Settings.Zones[e.zoneName] == true then
				if allowAllRocks or Settings.Rocks[model.Name] == true then
					-- Gunakan fungsi toleran baru di sini
					if RockMatchesOreSelection(model, e.oreType) then
						local hp = model:GetAttribute("Health")
						if (not hp) or hp > 0 then
							local part = e.part or PickTargetPartFromRockModel(model)
							e.part = part
							if part and part.Parent then
								local d = (myPos - part.Position).Magnitude
								if d < minDist then
									minDist = d
									closestPart = part
								end
							end
						end
					end
				end
			end
		end
	end
	return closestPart
end

-- ========= MAIN LOOP (STRICT RE-CHECK) =========
task.spawn(function()
	while _G.FarmLoop ~= false do
		task.wait(0.03)
		if not Settings.AutoFarm then 
			-- Stop logic... 
			continue 
		end

		local now = os.clock()
		-- Target Validation
		local targetInvalid = (not lockedTarget) or (not lockedTarget.Parent)
		if not targetInvalid then
			local rockModel = lockedTarget:FindFirstAncestorOfClass("Model")
			if not rockModel or not rockModel.Parent or (rockModel:GetAttribute("Health") or 1) <= 0 then
				targetInvalid = true
			else
				-- RE-CHECK KETAT: Jika HP < 50% dan ore muncul, script otomatis drop target jika ore salah
				if not RockMatchesOreSelection(rockModel, GetOreType(rockModel)) then
					targetInvalid = true
				end
			end
		end

		if targetInvalid then
			lockedTarget = nil
		end

		-- Scanning logic...
		if not lockedTarget and (now - lastScan) >= (Settings.ScanInterval or 0.12) then
			lastScan = now
			lockedTarget = GetBestTargetPart()
		end

		if lockedTarget then
			EnsureAtPart(lockedTarget) -- Tween & Lock
			HitPickaxe()
		end
	end
end)

print("[✓] Forge Core OPT + ORE-REVEAL Loaded!")
