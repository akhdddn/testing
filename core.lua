buat gui secara manual menggunakan instance, dengan latar batik yang bertemakan api dan besi, warna paduan adalah hitam dan merah saja. gui memiliki 2 tab: 1. Auto Mining (a. Saklar On/Off Auto Mining, b. Laci Zone dengan isi yang bisa dicentang, c. Laci Rock dengan isi yang bisa dicentang, d. Laci Ore dengan isi yang bisa dicentang) 2. Setting (a. Tween Speed Slider  dari 20 sampai 80, b. Y Offset Slider dari -7 studs sampai dengan 7 studs). gui yang ada punya minimize (keybind L), dan close (menghentikan dan menghapus efek dari script jika diclose). gui harus bisa diseret, dan buat slider tidak menyeret guinya. sesuaikan dengan core : -- ============================================
-- AUTO MINING SCRIPT - OPTIMIZED VERSION 9.1
-- Struktur yang benar berdasarkan informasi:
-- Workspace.Rocks.Zone (Folder).SpawnLocation (Part).Rock (Model)
-- ============================================

local Players, Workspace, RunService, TweenService, ReplicatedStorage = 
      game:GetService("Players"), game:GetService("Workspace"), 
      game:GetService("RunService"), game:GetService("TweenService"),
      game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local USER_ID = localPlayer.UserId

-- ===================== KONSTANTA & DATA =====================
local DATA = {
    Zones = {
        "Island2CaveDanger1", "Island2CaveDanger2", "Island2CaveDanger3",
        "Island2CaveDanger4", "Island2CaveDangerClosed", "Island2CaveDeep",
        "Island2CaveLavaClosed", "Island2CaveMid", "Island2CaveStart",
        "Island2GoblinCave", "Island2VolcanicDepths"
    },
    Rocks = {
        "Basalt", "Basalt Core", "Basalt Rock", "Basalt Vein", "Boulder",
        "Crimson Crystal", "Cyan Crystal", "Earth Crystal", "Lava Rock",
        "Light Crystal", "Lucky Block", "Pebble", "Rock", "Violet Crystal",
        "Volcanic Rock"
    },
    Ores = {
        "Aite", "Amethyst", "Arcane Crystal", "Bananite", "Blue Crystal",
        "Boneite", "Cardboardite", "Cobalt", "Copper", "Crimson Crystal",
        "Cuprite", "Dark Boneite", "Darkryte", "Demonite", "Diamond",
        "Emerald", "Eye Ore", "Fichillium", "Fichilliumorite", "Fireite",
        "Galaxite", "Gold", "Grass", "Green Crystal", "Iceite", "Iron",
        "Jade", "Lapis Lazuli", "Lightite", "Magenta Crystal", "Magmaite",
        "Meteorite", "Mushroomite", "Mythril", "Obsidian", "Orange Crystal",
        "Platinum", "Poopite", "Quartz", "Rainbow Crystal", "Rivalite",
        "Ruby", "Sand Stone", "Sapphire", "Silver", "Slimite", "Starite",
        "Stone", "Tin", "Titanium", "Topaz", "Uranium", "Volcanic Rock"
    }
}

-- ===================== LOOKUP TABLES O(1) =====================
local ZONES_LOOKUP, ROCKS_LOOKUP, ORES_LOOKUP = {}, {}, {}

-- Inisialisasi lookup tables (sangat cepat untuk validasi)
for _, v in ipairs(DATA.Zones) do ZONES_LOOKUP[v] = true end
for _, v in ipairs(DATA.Rocks) do ROCKS_LOOKUP[v] = true end
for _, v in ipairs(DATA.Ores) do ORES_LOOKUP[v] = true end

-- ===================== KONFIGURASI GUI =====================
local CONFIG = {
    -- GUI Sliders
    TweenSpeed = 50,        -- Range: 20-80
    YOffset = -6,           -- Range: -7 to 7
    MiningInterval = 0.5,
    
    -- Game Constants
    OreThreshold = 45,      -- Ore muncul saat health < 45%
    
    -- Performance Settings
    ScanInterval = 20,
    MaxSwingsPerRock = 100,
    SwingSampleSize = 10
}

-- ===================== SISTEM UTAMA =====================
local SYSTEMS = {
    -- State Management
    MiningActive = false,
    CurrentRock = nil,
    NextRock = nil,
    Connection = nil,
    
    -- Remote Cache
    MiningRemote = nil,
    
    -- Instance Cache (LRU Pattern)
    Cache = {
        Zones = {},        -- ZoneName → ZoneInstance
        Rocks = {},        -- RockName → {rock, zone, oreType}
        ZoneRocks = {},    -- ZoneName → {rock1, rock2, ...}
        LastUpdate = 0
    },
    
    -- Filter System
    Filter = {
        Zones = {},        -- ZoneName → boolean
        Rocks = {},        -- RockName → boolean  
        Ores = {},         -- OreName → boolean
        IsActive = false
    },
    
    -- Swing Prediction
    Predictor = {
        Samples = {},           -- Global damage samples
        RockData = {},          -- Per-rock data
        AverageDamage = 20,     -- Default value
    }
}

-- ===================== INISIALISASI FILTER =====================
for _, zone in ipairs(DATA.Zones) do SYSTEMS.Filter.Zones[zone] = false end
for _, rock in ipairs(DATA.Rocks) do SYSTEMS.Filter.Rocks[rock] = false end
for _, ore in ipairs(DATA.Ores) do SYSTEMS.Filter.Ores[ore] = false end

-- ===================== FUNGSI UTAMA =====================

-- Fungsi untuk mendapatkan mining remote (lazy loading)
local function getMiningRemote()
    if not SYSTEMS.MiningRemote then
        SYSTEMS.MiningRemote = ReplicatedStorage:WaitForChild("Shared")
            :WaitForChild("Packages"):WaitForChild("Knit")
            :WaitForChild("Services"):WaitForChild("ToolService")
            :WaitForChild("RF"):WaitForChild("ToolActivated")
    end
    return SYSTEMS.MiningRemote
end

-- Fungsi untuk update status filter
local function updateFilterStatus()
    local active = false
    
    -- Cek jika ada filter yang aktif
    for _, enabled in pairs(SYSTEMS.Filter.Zones) do
        if enabled then active = true; break end
    end
    
    if not active then
        for _, enabled in pairs(SYSTEMS.Filter.Rocks) do
            if enabled then active = true; break end
        end
    end
    
    if not active then
        for _, enabled in pairs(SYSTEMS.Filter.Ores) do
            if enabled then active = true; break end
        end
    end
    
    SYSTEMS.Filter.IsActive = active
    return active
end

-- Fungsi untuk validasi apakah rock lolos filter
local function rockPassesFilter(rockName, oreType)
    if not SYSTEMS.Filter.IsActive then return true end
    
    -- Cek rock filter
    if SYSTEMS.Filter.Rocks[rockName] then
        return true
    end
    
    -- Cek ore filter
    if oreType and SYSTEMS.Filter.Ores[oreType] then
        return true
    end
    
    return false
end

-- Fungsi untuk validasi apakah zone lolos filter
local function zonePassesFilter(zoneName)
    if not SYSTEMS.Filter.IsActive then return true end
    return SYSTEMS.Filter.Zones[zoneName] == true
end

-- ===================== SCANNING SYSTEM =====================
-- Berdasarkan struktur: Workspace.Rocks.Zone.SpawnLocation.Rock
local function scanWorkspace()
    local startTime = tick()
    local rocksFolder = Workspace:FindFirstChild("Rocks")
    
    if not rocksFolder then
        warn("Folder 'Rocks' tidak ditemukan di Workspace!")
        return
    end
    
    -- Reset cache
    local newCache = {
        Zones = {},
        Rocks = {},
        ZoneRocks = {},
        LastUpdate = tick()
    }
    
    -- Iterasi melalui semua zone
    for _, zone in ipairs(rocksFolder:GetChildren()) do
        local zoneName = zone.Name
        
        -- Validasi zone
        if not ZONES_LOOKUP[zoneName] then
            continue  -- Zone tidak valid, skip
        end
        
        -- Filter zone jika aktif
        if SYSTEMS.Filter.IsActive and not zonePassesFilter(zoneName) then
            continue
        end
        
        -- Zone lolos semua filter
        newCache.Zones[zoneName] = zone
        newCache.ZoneRocks[zoneName] = {}
        
        -- Cari SpawnLocation (Part) di dalam Zone
        for _, spawnLocation in ipairs(zone:GetChildren()) do
            -- SpawnLocation harus Part
            if not spawnLocation:IsA("BasePart") then
                continue
            end
            
            -- Cek pattern nama SpawnLocation
            if not (string.find(spawnLocation.Name:lower(), "spawn") or 
                    spawnLocation.Name == "SpawnLocation") then
                continue
            end
            
            -- Iterasi melalui semua Rock (Model) di SpawnLocation
            for _, rock in ipairs(spawnLocation:GetChildren()) do
                local rockName = rock.Name
                
                -- Validasi rock
                if not ROCKS_LOOKUP[rockName] or not rock:IsA("Model") then
                    continue
                end
                
                -- Validasi health dan ownership
                local health = rock:GetAttribute("Health")
                local owner = rock:GetAttribute("LastHitPlayer")
                
                if not health or health <= 0 then
                    continue  -- Rock sudah hancur
                end
                
                if owner and owner ~= USER_ID then
                    continue  -- Dimiliki pemain lain
                end
                
                -- Dapatkan ore type dari attribute rock
                local oreType = rock:GetAttribute("Ore")
                
                -- Filter rock
                if not rockPassesFilter(rockName, oreType) then
                    continue
                end
                
                -- Rock valid, tambahkan ke cache
                local rockData = {
                    Instance = rock,
                    Zone = zoneName,
                    Name = rockName,
                    OreType = oreType,
                    Health = health,
                    Position = rock:GetPivot().Position
                }
                
                table.insert(newCache.ZoneRocks[zoneName], rockData)
                newCache.Rocks[rockName] = rockData
            end
        end
    end
    
    -- Update cache system
    SYSTEMS.Cache = newCache
    
    -- Logging
    local scanTime = tick() - startTime
    local rockCount = 0
    for _, rocks in pairs(SYSTEMS.Cache.ZoneRocks) do
        rockCount = rockCount + #rocks
    end
    
    print(string.format("✅ Scan selesai: %.3f detik", scanTime))
    print(string.format("📁 Zones: %d", countTable(SYSTEMS.Cache.Zones)))
    print(string.format("🪨 Rocks: %d", rockCount))
    
    return true
end

-- ===================== SWING PREDICTION SYSTEM =====================
-- Sistem prediksi untuk mengetahui swing terakhir

local function updateSwingPrediction(rock, newHealth)
    if not rock then return end
    
    local rockKey = tostring(rock)
    local oldHealth = SYSTEMS.Predictor.RockData[rockKey] and 
                      SYSTEMS.Predictor.RockData[rockKey].LastHealth
    
    if oldHealth and oldHealth > 0 then
        local damage = oldHealth - newHealth
        
        if damage > 0 then
            -- Update global samples
            table.insert(SYSTEMS.Predictor.Samples, damage)
            if #SYSTEMS.Predictor.Samples > CONFIG.SwingSampleSize then
                table.remove(SYSTEMS.Predictor.Samples, 1)
            end
            
            -- Update average damage
            local total = 0
            for _, dmg in ipairs(SYSTEMS.Predictor.Samples) do
                total = total + dmg
            end
            SYSTEMS.Predictor.AverageDamage = math.floor(total / #SYSTEMS.Predictor.Samples)
            
            -- Update rock-specific data
            if not SYSTEMS.Predictor.RockData[rockKey] then
                SYSTEMS.Predictor.RockData[rockKey] = {
                    DamageHistory = {},
                    LastHealth = newHealth
                }
            end
            
            local rockData = SYSTEMS.Predictor.RockData[rockKey]
            table.insert(rockData.DamageHistory, damage)
            if #rockData.DamageHistory > 5 then
                table.remove(rockData.DamageHistory, 1)
            end
        end
    end
    
    -- Update last health
    if SYSTEMS.Predictor.RockData[rockKey] then
        SYSTEMS.Predictor.RockData[rockKey].LastHealth = newHealth
    end
end

local function predictRemainingSwings(rock)
    if not rock then return 0 end
    
    local currentHealth = rock:GetAttribute("Health") or 0
    local rockKey = tostring(rock)
    local rockData = SYSTEMS.Predictor.RockData[rockKey]
    
    -- Jika ada data spesifik rock, gunakan itu
    if rockData and #rockData.DamageHistory > 0 then
        local total = 0
        for _, dmg in ipairs(rockData.DamageHistory) do
            total = total + dmg
        end
        local rockAvg = math.floor(total / #rockData.DamageHistory)
        
        -- Weighted average: 70% rock-specific, 30% global
        local weightedAvg = math.floor((rockAvg * 0.7) + (SYSTEMS.Predictor.AverageDamage * 0.3))
        
        if weightedAvg > 0 then
            return math.ceil(currentHealth / weightedAvg)
        end
    end
    
    -- Fallback ke global average
    if SYSTEMS.Predictor.AverageDamage > 0 then
        return math.ceil(currentHealth / SYSTEMS.Predictor.AverageDamage)
    end
    
    return math.ceil(currentHealth / 20)  -- Default fallback
end

-- ===================== MOVEMENT SYSTEM =====================
-- Sistem pergerakan dengan NoClip dan Anti-Gravity

local function prepareCharacter(character)
    if not character then return false end
    
    -- Enable NoClip
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    
    -- Enable Anti-Gravity
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    return true
end

local function restoreCharacter(character)
    if not character then return false end
    
    -- Disable NoClip
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    
    -- Disable Anti-Gravity
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
    end
    
    return true
end

local function moveToRock(character, targetPosition)
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    -- Hitung posisi target dengan Y offset
    local targetPos = Vector3.new(
        targetPosition.X,
        targetPosition.Y + CONFIG.YOffset,
        targetPosition.Z
    )
    
    -- Hitung jarak dan durasi
    local distance = (humanoidRootPart.Position - targetPos).Magnitude
    local actualSpeed = CONFIG.TweenSpeed * 2  -- Konversi: 20-80 → 40-160 studs/detik
    local duration = distance / actualSpeed
    
    -- Buat tween
    local tween = TweenService:Create(
        humanoidRootPart,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {Position = targetPos}
    )
    
    -- Persiapan karakter
    prepareCharacter(character)
    
    -- Jalankan tween
    tween:Play()
    
    -- Tunggu tween selesai (non-blocking)
    local startTime = tick()
    while tick() - startTime < duration do
        if not SYSTEMS.MiningActive then break end
        RunService.Heartbeat:Wait()
    end
    
    -- Batalkan jika masih berjalan
    if tween.PlaybackState == Enum.PlaybackState.Playing then
        tween:Cancel()
    end
    
    -- Hadapkan karakter ke target
    local direction = (targetPosition - humanoidRootPart.Position).Unit
    humanoidRootPart.CFrame = CFrame.lookAt(
        humanoidRootPart.Position,
        humanoidRootPart.Position + Vector3.new(direction.X, 0, direction.Z)
    )
    
    return true
end

-- ===================== MINING PROCESS =====================
-- Proses mining untuk satu rock

local function mineRock(rockData)
    if not rockData or not SYSTEMS.MiningActive then return false end
    
    local character = localPlayer.Character
    if not character then return false end
    
    local rock = rockData.Instance
    local rockName = rockData.Name
    local oreType = rockData.OreType
    local zoneName = rockData.Zone
    
    print(string.format("🚀 Menuju: %s (Zone: %s, Ore: %s)", 
        rockName, zoneName, oreType or "Unknown"))
    
    -- Bergerak ke rock
    if not moveToRock(character, rockData.Position) then
        print("❌ Gagal bergerak ke rock")
        return false
    end
    
    print("✅ Sampai di posisi rock")
    
    -- Tunggu stabilisasi
    wait(0.5)
    
    -- Validasi ulang rock sebelum mining
    local health = rock:GetAttribute("Health")
    local owner = rock:GetAttribute("LastHitPlayer")
    
    if not health or health <= 0 then
        print("❌ Rock sudah hancur")
        return false
    end
    
    if owner and owner ~= USER_ID then
        print("❌ Rock dimiliki pemain lain")
        return false
    end
    
    SYSTEMS.CurrentRock = rock
    
    -- Proses mining
    local swingCount = 0
    local oreSpawned = false
    local maxSwings = CONFIG.MaxSwingsPerRock
    
    while SYSTEMS.MiningActive and swingCount < maxSwings do
        -- Cek validitas rock
        if not rock or not rock.Parent then
            print("❌ Rock tidak ditemukan")
            break
        end
        
        local currentHealth = rock:GetAttribute("Health")
        if not currentHealth or currentHealth <= 0 then
            print(string.format("✅ Rock hancur: %s", rockName))
            
            if oreSpawned then
                print(string.format("💰 Ore dikumpulkan: %s", oreType or "Unknown"))
            end
            
            break
        end
        
        -- Cek ownership
        local currentOwner = rock:GetAttribute("LastHitPlayer")
        if currentOwner and currentOwner ~= USER_ID then
            print("❌ Kepemilikan berubah")
            break
        end
        
        -- Cek jika ore muncul
        if not oreSpawned and currentHealth < CONFIG.OreThreshold then
            oreSpawned = true
            print(string.format("💎 Ore muncul: %s (Health: %d)", 
                oreType or "Unknown", currentHealth))
        end
        
        -- Prediksi swing tersisa
        local remainingSwings = predictRemainingSwings(rock)
        
        -- Persiapan target berikutnya jika sudah dekat akhir
        if remainingSwings <= 3 and not SYSTEMS.NextRock then
            print(string.format("🎯 Mempersiapkan target berikutnya (%d swing tersisa)", remainingSwings))
            
            -- Cari target berikutnya secara async
            task.spawn(function()
                SYSTEMS.NextRock = findNextRock(rock)
            end)
        end
        
        -- Log prediksi
        if remainingSwings <= 5 then
            print(string.format("⏳ %s: %d HP (~%d swing tersisa)", 
                rockName, currentHealth, remainingSwings))
        end
        
        -- Eksekusi mining action
        local success = pcall(function()
            getMiningRemote():InvokeServer("Pickaxe")
        end)
        
        if success then
            swingCount = swingCount + 1
            
            -- Update swing prediction
            local newHealth = rock:GetAttribute("Health")
            updateSwingPrediction(rock, newHealth)
            
            -- Log swing terakhir yang diprediksi
            if remainingSwings <= 2 then
                print("⚡ SWING TERAKHIR DIPREDIKSI - Siap beralih")
            end
        else
            print("❌ Mining action gagal")
        end
        
        -- Tunggu interval mining
        wait(CONFIG.MiningInterval)
    end
    
    -- Reset state
    if SYSTEMS.CurrentRock == rock then
        SYSTEMS.CurrentRock = nil
    end
    
    -- Restore karakter
    restoreCharacter(character)
    
    return swingCount > 0
end

-- ===================== TARGET SELECTION =====================
-- Sistem pemilihan target berikutnya

local function findNextRock(currentRock)
    local cache = SYSTEMS.Cache
    
    for zoneName, rocks in pairs(cache.ZoneRocks) do
        for _, rockData in ipairs(rocks) do
            local rock = rockData.Instance
            
            -- Skip rock yang sedang ditambang
            if rock == currentRock then
                continue
            end
            
            -- Validasi rock
            if not rock or not rock.Parent then
                continue
            end
            
            local health = rock:GetAttribute("Health")
            local owner = rock:GetAttribute("LastHitPlayer")
            
            if not health or health <= 0 then
                continue
            end
            
            if owner and owner ~= USER_ID then
                continue
            end
            
            -- Rock valid, return
            return rockData
        end
    end
    
    return nil
end

-- ===================== MAIN MINING LOOP =====================

local function miningLoop()
    if not SYSTEMS.MiningActive then return end
    
    while SYSTEMS.MiningActive do
        local character = localPlayer.Character
        if not character then
            wait(2)
            continue
        end
        
        -- Pilih target
        local targetRock = nil
        
        if SYSTEMS.NextRock then
            -- Gunakan target yang sudah dipersiapkan
            targetRock = SYSTEMS.NextRock
            SYSTEMS.NextRock = nil
            print(string.format("🎯 Menggunakan target yang sudah dipersiapkan: %s", 
                targetRock.Name))
        else
            -- Cari target baru
            targetRock = findNextRock(SYSTEMS.CurrentRock)
        end
        
        -- Proses mining
        if targetRock then
            mineRock(targetRock)
        else
            print("⏳ Tidak ada rock yang tersedia, rescan...")
            wait(2)
        end
        
        -- Periodic rescan
        if tick() - SYSTEMS.Cache.LastUpdate > CONFIG.ScanInterval then
            task.spawn(scanWorkspace)
        end
    end
    
    -- Restore character state saat berhenti
    local character = localPlayer.Character
    if character then
        restoreCharacter(character)
    end
end

-- ===================== UTILITY FUNCTIONS =====================

local function countTable(tbl, value)
    if not tbl then return 0 end
    
    local count = 0
    if value ~= nil then
        for _, v in pairs(tbl) do
            if v == value then
                count = count + 1
            end
        end
    else
        for _ in pairs(tbl) do
            count = count + 1
        end
    end
    
    return count
end

-- ===================== PUBLIC API =====================
-- Interface untuk GUI

local AutoMiner = {}

-- 1. SAKLAR AUTO MINING
function AutoMiner.start()
    if SYSTEMS.MiningActive then
        warn("⚠️ Auto mining sudah aktif!")
        return
    end
    
    SYSTEMS.MiningActive = true
    
    -- Setup mining remote
    getMiningRemote()
    
    -- Initial scan
    scanWorkspace()
    
    -- Start mining loop
    SYSTEMS.Connection = RunService.Heartbeat:Connect(function()
        if SYSTEMS.MiningActive then
            miningLoop()
        end
    end)
    
    print("🚀 Auto Mining System Started")
    print(string.format("⚙️ Tween Speed: %d (Actual: %d studs/sec)", 
        CONFIG.TweenSpeed, CONFIG.TweenSpeed * 2))
    print(string.format("⚙️ Y Offset: %d studs", CONFIG.YOffset))
    print(string.format("⚙️ Mining Interval: %.2f sec", CONFIG.MiningInterval))
end

function AutoMiner.stop()
    SYSTEMS.MiningActive = false
    SYSTEMS.CurrentRock = nil
    SYSTEMS.NextRock = nil
    
    if SYSTEMS.Connection then
        SYSTEMS.Connection:Disconnect()
        SYSTEMS.Connection = nil
    end
    
    -- Restore character
    local character = localPlayer.Character
    if character then
        restoreCharacter(character)
    end
    
    print("🛑 Auto mining stopped.")
end

function AutoMiner.isActive()
    return SYSTEMS.MiningActive
end

-- 2. SLIDER TWEEN SPEED (20-80)
function AutoMiner.setTweenSpeed(speed)
    CONFIG.TweenSpeed = math.clamp(speed, 20, 80)
    print(string.format("⚙️ Tween Speed diatur: %d", CONFIG.TweenSpeed))
    return CONFIG.TweenSpeed
end

function AutoMiner.getTweenSpeed()
    return CONFIG.TweenSpeed
end

-- 3. SLIDER Y OFFSET (-7 sampai 7)
function AutoMiner.setYOffset(offset)
    CONFIG.YOffset = math.clamp(offset, -7, 7)
    print(string.format("⚙️ Y Offset diatur: %d", CONFIG.YOffset))
    return CONFIG.YOffset
end

function AutoMiner.getYOffset()
    return CONFIG.YOffset
end

-- Filter Configuration
function AutoMiner.setFilter(category, name, value)
    if SYSTEMS.Filter[category] then
        SYSTEMS.Filter[category][name] = value
        updateFilterStatus()
        return true
    end
    return false
end

function AutoMiner.getFilter(category, name)
    if SYSTEMS.Filter[category] then
        return SYSTEMS.Filter[category][name]
    end
    return nil
end

function AutoMiner.getFilterStatus()
    return {
        isActive = SYSTEMS.Filter.IsActive,
        zones = countTable(SYSTEMS.Filter.Zones, true),
        rocks = countTable(SYSTEMS.Filter.Rocks, true),
        ores = countTable(SYSTEMS.Filter.Ores, true)
    }
end

function AutoMiner.getDataLists()
    return {
        Zones = DATA.Zones,
        Rocks = DATA.Rocks,
        Ores = DATA.Ores
    }
end

-- Stats and Info
function AutoMiner.getStats()
    local rockCount = 0
    for _, rocks in pairs(SYSTEMS.Cache.ZoneRocks) do
        rockCount = rockCount + #rocks
    end
    
    return {
        miningActive = SYSTEMS.MiningActive,
        tweenSpeed = CONFIG.TweenSpeed,
        yOffset = CONFIG.YOffset,
        miningInterval = CONFIG.MiningInterval,
        zones = countTable(SYSTEMS.Cache.Zones),
        rocks = rockCount,
        filterActive = SYSTEMS.Filter.IsActive,
        currentRock = SYSTEMS.CurrentRock and SYSTEMS.CurrentRock.Name or "None",
        nextRock = SYSTEMS.NextRock and SYSTEMS.NextRock.Name or "None",
        avgDamage = SYSTEMS.Predictor.AverageDamage
    }
end

-- Mining Control
function AutoMiner.rescan()
    return scanWorkspace()
end

-- Swing Prediction
function AutoMiner.getSwingStats()
    return {
        averageDamage = SYSTEMS.Predictor.AverageDamage,
        sampleCount = #SYSTEMS.Predictor.Samples,
        rockDataCount = countTable(SYSTEMS.Predictor.RockData)
    }
end

function AutoMiner.resetPrediction()
    SYSTEMS.Predictor = {
        Samples = {},
        RockData = {},
        AverageDamage = 20
    }
    print("✅ Swing prediction data direset")
end

-- Debug
function AutoMiner.printStatus()
    print("=== MINING STATUS ===")
    print(string.format("Aktif: %s", SYSTEMS.MiningActive and "YA" or "TIDAK"))
    print(string.format("Rock saat ini: %s", 
        SYSTEMS.CurrentRock and SYSTEMS.CurrentRock.Name or "None"))
    print(string.format("Target berikutnya: %s", 
        SYSTEMS.NextRock and SYSTEMS.NextRock.Name or "None"))
    print(string.format("Tween Speed: %d", CONFIG.TweenSpeed))
    print(string.format("Y Offset: %d", CONFIG.YOffset))
    
    local stats = AutoMiner.getSwingStats()
    print(string.format("Prediksi Swing - Avg Damage: %d, Samples: %d", 
        stats.averageDamage, stats.sampleCount))
end

return AutoMiner
