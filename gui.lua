--[[
    ===== THE FORGE GUI =====
    GUI untuk Auto Mining System
    Menggunakan Fluent UI Library
    Compatible dengan Core v9.1
]]

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Validasi Core sudah dimuat
if not _G.AutoMiner then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Error";
        Text = "Core script belum dimuat! Reload script.";
        Duration = 5;
    })
    return
end

local AutoMiner = _G.AutoMiner

-- ===================== KONFIGURASI GUI =====================
local Window = Fluent:CreateWindow({
    Title = "🔨 The Forge - Auto Mining System",
    SubTitle = "by akhdddn",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- ===================== TABS =====================
local Tabs = {
    Main = Window:AddTab({ Title = "⚙️ Main", Icon = "settings" }),
    Filters = Window:AddTab({ Title = "🔍 Filters", Icon = "filter" }),
    Stats = Window:AddTab({ Title = "📊 Statistics", Icon = "bar-chart-2" }),
    Settings = Window:AddTab({ Title = "⚡ Settings", Icon = "sliders" })
}

-- ===================== NOTIFIKASI HELPER =====================
local function Notify(title, content, duration)
    Fluent:Notify({
        Title = title,
        Content = content,
        Duration = duration or 3
    })
end

-- ===================== TAB: MAIN =====================
local MainSection = Tabs.Main:AddSection("Mining Control")

-- Toggle Auto Mining
local MiningToggle = Tabs.Main:AddToggle("AutoMining", {
    Title = "🚀 Auto Mining",
    Description = "Aktifkan/Nonaktifkan sistem mining otomatis",
    Default = false
})

MiningToggle:OnChanged(function(value)
    if value then
        AutoMiner.start()
        Notify("✅ Started", "Auto mining telah diaktifkan!", 3)
    else
        AutoMiner.stop()
        Notify("🛑 Stopped", "Auto mining telah dihentikan.", 3)
    end
end)

-- Button Rescan
Tabs.Main:AddButton({
    Title = "🔄 Rescan Workspace",
    Description = "Pindai ulang semua rock yang tersedia",
    Callback = function()
        local success = AutoMiner.rescan()
        if success then
            local stats = AutoMiner.getStats()
            Notify("✅ Rescan Selesai", 
                string.format("Ditemukan %d zones, %d rocks", 
                    stats.zones, stats.rocks), 5)
        else
            Notify("❌ Rescan Gagal", "Terjadi kesalahan saat scanning", 3)
        end
    end
})

-- Quick Actions
local QuickSection = Tabs.Main:AddSection("Quick Actions")

Tabs.Main:AddButton({
    Title = "🎯 Reset Prediction",
    Description = "Reset data prediksi swing damage",
    Callback = function()
        AutoMiner.resetPrediction()
        Notify("✅ Reset", "Data prediksi swing telah direset", 3)
    end
})

Tabs.Main:AddButton({
    Title = "📋 Print Status",
    Description = "Cetak status mining ke console (F9)",
    Callback = function()
        AutoMiner.printStatus()
        Notify("📋 Status", "Status dicetak ke console (tekan F9)", 3)
    end
})

-- ===================== TAB: FILTERS =====================
local FilterInfo = Tabs.Filters:AddParagraph({
    Title = "📌 Filter Information",
    Content = "Aktifkan filter untuk menambang rock/ore tertentu saja. Jika tidak ada filter aktif, semua rock akan ditambang."
})

-- Get data lists dari core
local dataLists = AutoMiner.getDataLists()

-- ZONES FILTER
local ZonesSection = Tabs.Filters:AddSection("🗺️ Zone Filters")

Tabs.Filters:AddParagraph({
    Title = "Zones",
    Content = string.format("Total: %d zones tersedia", #dataLists.Zones)
})

-- Buat toggle untuk setiap zone
for _, zoneName in ipairs(dataLists.Zones) do
    local toggle = Tabs.Filters:AddToggle("Zone_" .. zoneName, {
        Title = zoneName,
        Description = "Filter zone: " .. zoneName,
        Default = false
    })
    
    toggle:OnChanged(function(value)
        AutoMiner.setFilter("Zones", zoneName, value)
        local status = AutoMiner.getFilterStatus()
        if value then
            Notify("🗺️ Zone Aktif", zoneName, 2)
        end
    end)
end

-- ROCKS FILTER
local RocksSection = Tabs.Filters:AddSection("🪨 Rock Filters")

Tabs.Filters:AddParagraph({
    Title = "Rocks",
    Content = string.format("Total: %d jenis rock tersedia", #dataLists.Rocks)
})

for _, rockName in ipairs(dataLists.Rocks) do
    local toggle = Tabs.Filters:AddToggle("Rock_" .. rockName, {
        Title = rockName,
        Description = "Filter rock: " .. rockName,
        Default = false
    })
    
    toggle:OnChanged(function(value)
        AutoMiner.setFilter("Rocks", rockName, value)
        if value then
            Notify("🪨 Rock Aktif", rockName, 2)
        end
    end)
end

-- ORES FILTER
local OresSection = Tabs.Filters:AddSection("💎 Ore Filters")

Tabs.Filters:AddParagraph({
    Title = "Ores",
    Content = string.format("Total: %d jenis ore tersedia", #dataLists.Ores)
})

for _, oreName in ipairs(dataLists.Ores) do
    local toggle = Tabs.Filters:AddToggle("Ore_" .. oreName, {
        Title = oreName,
        Description = "Filter ore: " .. oreName,
        Default = false
    })
    
    toggle:OnChanged(function(value)
        AutoMiner.setFilter("Ores", oreName, value)
        if value then
            Notify("💎 Ore Aktif", oreName, 2)
        end
    end)
end

-- ===================== TAB: STATISTICS =====================
local StatsSection = Tabs.Stats:AddSection("📊 Real-Time Statistics")

-- Buat paragraf untuk statistik yang akan di-update
local MiningStatusPara = Tabs.Stats:AddParagraph({
    Title = "🔨 Mining Status",
    Content = "Menunggu data..."
})

local PerformancePara = Tabs.Stats:AddParagraph({
    Title = "⚡ Performance",
    Content = "Menunggu data..."
})

local FilterStatusPara = Tabs.Stats:AddParagraph({
    Title = "🔍 Filter Status",
    Content = "Menunggu data..."
})

local PredictionPara = Tabs.Stats:AddParagraph({
    Title = "🎯 Swing Prediction",
    Content = "Menunggu data..."
})

-- Update statistik setiap 2 detik
task.spawn(function()
    while true do
        task.wait(2)
        
        local stats = AutoMiner.getStats()
        local filterStatus = AutoMiner.getFilterStatus()
        local swingStats = AutoMiner.getSwingStats()
        
        -- Update Mining Status
        MiningStatusPara:SetDesc(string.format(
            "Status: %s\n" ..
            "Current Rock: %s\n" ..
            "Next Rock: %s\n" ..
            "Zones Found: %d\n" ..
            "Rocks Found: %d",
            stats.miningActive and "🟢 ACTIVE" or "🔴 INACTIVE",
            stats.currentRock,
            stats.nextRock,
            stats.zones,
            stats.rocks
        ))
        
        -- Update Performance
        PerformancePara:SetDesc(string.format(
            "Tween Speed: %d (Actual: %d studs/sec)\n" ..
            "Y Offset: %d studs\n" ..
            "Mining Interval: %.2f seconds",
            stats.tweenSpeed,
            stats.tweenSpeed * 2,
            stats.yOffset,
            stats.miningInterval
        ))
        
        -- Update Filter Status
        FilterStatusPara:SetDesc(string.format(
            "Filter Active: %s\n" ..
            "Active Zones: %d\n" ..
            "Active Rocks: %d\n" ..
            "Active Ores: %d",
            filterStatus.isActive and "🟢 YES" or "🔴 NO",
            filterStatus.zones,
            filterStatus.rocks,
            filterStatus.ores
        ))
        
        -- Update Prediction
        PredictionPara:SetDesc(string.format(
            "Average Damage: %d HP/swing\n" ..
            "Samples Collected: %d\n" ..
            "Rocks Tracked: %d",
            swingStats.averageDamage,
            swingStats.sampleCount,
            swingStats.rockDataCount
        ))
    end
end)

-- ===================== TAB: SETTINGS =====================
local MovementSection = Tabs.Settings:AddSection("🏃 Movement Settings")

-- Slider Tween Speed
local TweenSpeedSlider = Tabs.Settings:AddSlider("TweenSpeed", {
    Title = "⚡ Tween Speed",
    Description = "Kecepatan pergerakan karakter (20-80)",
    Default = AutoMiner.getTweenSpeed(),
    Min = 20,
    Max = 80,
    Rounding = 0,
    Callback = function(value)
        AutoMiner.setTweenSpeed(value)
    end
})

-- Display real speed
Tabs.Settings:AddParagraph({
    Title = "Speed Info",
    Content = "20 = 40 studs/sec\n50 = 100 studs/sec\n80 = 160 studs/sec"
})

-- Slider Y Offset
local YOffsetSlider = Tabs.Settings:AddSlider("YOffset", {
    Title = "📏 Y Offset",
    Description = "Tinggi posisi karakter saat mining (-7 hingga 7)",
    Default = AutoMiner.getYOffset(),
    Min = -7,
    Max = 7,
    Rounding = 0,
    Callback = function(value)
        AutoMiner.setYOffset(value)
    end
})

Tabs.Settings:AddParagraph({
    Title = "Y Offset Info",
    Content = "Negatif = Di bawah rock\n0 = Sejajar dengan rock\nPositif = Di atas rock"
})

-- Performance Section
local PerformanceSection = Tabs.Settings:AddSection("⚙️ Performance Info")

Tabs.Settings:AddParagraph({
    Title = "ℹ️ System Information",
    Content = 
        "• Mining Interval: 0.5 detik (fixed)\n" ..
        "• Scan Interval: 20 detik\n" ..
        "• Max Swings: 100 per rock\n" ..
        "• Ore Threshold: <45% HP\n" ..
        "• NoClip: Enabled saat mining\n" ..
        "• Anti-Gravity: Enabled saat mining"
})

-- Credits Section
local CreditsSection = Tabs.Settings:AddSection("👨‍💻 Credits")

Tabs.Settings:AddParagraph({
    Title = "Made by akhdddn",
    Content = 
        "🔨 The Forge Auto Mining System v9.1\n" ..
        "📚 Core: Optimized mining engine\n" ..
        "🎨 GUI: Fluent UI Library\n" ..
        "⚡ Features: Smart targeting, swing prediction, filters"
})

-- ===================== SAVE MANAGER & INTERFACE =====================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

-- Set folder untuk menyimpan konfigurasi
SaveManager:SetFolder("TheForge/AutoMining")

-- Build config section di settings tab
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

-- Load auto-load config jika ada
SaveManager:LoadAutoloadConfig()

-- ===================== WINDOW SETUP =====================
Fluent:Notify({
    Title = "🔨 The Forge",
    Content = "GUI berhasil dimuat! Selamat mining!",
    Duration = 5
})

-- Log success
print("✅ [GUI] The Forge GUI berhasil dimuat")
print("✅ [GUI] Tekan LeftControl untuk minimize/maximize")

-- Set window
Window:SelectTab(1)

-- Export AutoMiner ke global (sudah ada dari core, tapi untuk memastikan)
_G.AutoMiner = AutoMiner

return Window
