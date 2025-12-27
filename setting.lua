-- ReplicatedStorage/ForgeSettings (ModuleScript)
local M = {}

M.DATA = {
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

M.DEFAULTS = {
	-- Base
	AutoFarm = false,
	TweenSpeed = 55,
	YOffset = 3,
	CheckThreshold = 0, -- kept for compatibility
	ScanInterval = 0.12,
	HitInterval = 0.12,
	TargetStickTime = 0.25,
	ArriveDistance = 2.25,
	RetweenDistance = 6,

	-- ORE REVEAL
	OreRevealThreshold = 50,
	AllowUnknownOreAboveReveal = true,

	-- Selection behavior
	AllowAllZonesIfNoneSelected = true,
	AllowAllRocksIfNoneSelected = true,
	AllowAllOresIfNoneSelected = true,

	-- ORE-STRICT
	RequireOreMatchWhenSelected = true,

	-- Lock
	LockToTarget = true,
	LockMode = "Constraint", -- "Constraint" or "Hard"
	LockVelocityZero = true,
	AnchorDuringLock = false,
	KeepNoclipWhileLocked = true,

	-- Facing + smooth lock updates
	FaceTargetWhileMining = true,
	LockSmoothAlpha = 0.35,

	-- LastHit ownership (SIMPLE)
	RespectLastHitPlayer = true,

	-- Constraint tuning
	ConstraintResponsiveness = 200,
	ConstraintMaxForce = 1e9,

	-- Camera
	CameraStabilize = true,
	CameraSmoothAlpha = 1,
	CameraOffsetMode = "World",
	CameraOffset = Vector3.new(0, 10, 18),
}

function M.ApplyToGlobals()
	_G.Settings = _G.Settings or {}
	local S = _G.Settings

	-- defaults
	for k, v in pairs(M.DEFAULTS) do
		if S[k] == nil then S[k] = v end
	end

	-- tables used by GUI
	S.Zones = S.Zones or {}
	S.Rocks = S.Rocks or {}
	S.Ores  = S.Ores  or {}

	for _, n in ipairs(M.DATA.Zones) do
		if S.Zones[n] == nil then S.Zones[n] = false end
	end
	for _, n in ipairs(M.DATA.Rocks) do
		if S.Rocks[n] == nil then S.Rocks[n] = false end
	end
	for _, n in ipairs(M.DATA.Ores) do
		if S.Ores[n] == nil then S.Ores[n] = false end
	end

	_G.DATA = _G.DATA or M.DATA
	if _G.FarmLoop == nil then _G.FarmLoop = true end

	return S, _G.DATA
end

return M
