--[[  
    ===== THE FORGE ULTIMATE LOADER =====
    Author: akhdddn
    Features: 
    - Auto Raw Link Converter
    - Anti-Cache (Always Latest Version)
    - Robust Error Handling
    - Notification System
    - (Updated) Load setting.lua first
]]

local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

-- // KONFIGURASI URL (Bisa pakai link blob biasa, script akan otomatis convert)
local SCRIPT_CONFIG = {
    Setting = "https://github.com/akhdddn/testing/blob/main/setting.lua", -- NEW
    Core    = "https://github.com/akhdddn/testing/blob/main/core.lua",
    GUI     = "https://github.com/akhdddn/testing/blob/main/gui.lua"
}

-- // 1. SYSTEM UTILS
local function SendNotif(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title;
            Text = text;
            Duration = duration or 5;
            Icon = "rbxassetid://12345678"
        })
    end)
end

local function GetRawURL(url)
    if url:find("github.com") and url:find("/blob/") then
        -- Convert: github.com/user/repo/blob/main/file -> raw.githubusercontent.com/user/repo/main/file
        url = url:gsub("github.com", "raw.githubusercontent.com")
        url = url:gsub("/blob/", "/")
    end

    -- Anti-Cache: Tambahkan timestamp agar executor tidak mengambil file lama
    -- Kalau url sudah punya query, pakai '&' bukan '?'
    local sep = url:find("%?") and "&" or "?"
    return url .. sep .. "t=" .. tostring(os.time())
end

-- // 2. EXECUTION HANDLER
local function LoadScript(name, url)
    local cleanUrl = GetRawURL(url)
    print("Downloading " .. name .. " from: " .. cleanUrl)

    -- Tahap 1: Download
    local success, response = pcall(function()
        return game:HttpGet(cleanUrl)
    end)

    if not success then
        warn("[Loader] Gagal download " .. name .. ": " .. tostring(response))
        SendNotif("Download Error", "Gagal mengunduh " .. name .. ". Cek koneksi/link.", 5)
        return false
    end

    -- Tahap 2: Loadstring (Compile)
    local func, syntaxErr = loadstring(response)
    if not func then
        warn("[Loader] Syntax Error di " .. name .. ": " .. tostring(syntaxErr))
        SendNotif("Syntax Error", "Ada kesalahan kode di " .. name .. "!", 5)
        return false
    end

    -- Tahap 3: Eksekusi
    local execSuccess, execErr = pcall(func)
    if not execSuccess then
        warn("[Loader] Runtime Error di " .. name .. ": " .. tostring(execErr))
        SendNotif("Runtime Error", "Error saat menjalankan " .. name, 5)
        return false
    end

    return true
end

-- // 3. MAIN SEQUENCE
if _G.ForgeLoaderRunning then
    SendNotif("Warning", "Script sudah berjalan! Rejoin jika ingin restart.", 3)
    return
end
_G.ForgeLoaderRunning = true

task.spawn(function()
    SendNotif("The Forge", "Memulai Loader...", 2)

    -- 1) Load Setting dulu (PENTING)
    local settingLoaded = LoadScript("Setting Script", SCRIPT_CONFIG.Setting)
    if not settingLoaded then
        SendNotif("Failed", "Setting gagal dimuat. Core & GUI dibatalkan.", 5)
        _G.ForgeLoaderRunning = false
        return
    end

    -- beri jeda agar _G.Settings/_G.DATA siap (kalau setting menginisialisasi globals)
    task.wait(0.2)

    -- 2) Load Core
    local coreLoaded = LoadScript("Core Script", SCRIPT_CONFIG.Core)
    if not coreLoaded then
        SendNotif("Failed", "Core gagal dimuat. GUI dibatalkan.", 5)
        _G.ForgeLoaderRunning = false
        return
    end

    -- Beri jeda sedikit agar Core menginisialisasi state
    task.wait(0.5)

    -- 3) Load GUI
    local guiLoaded = LoadScript("GUI Script", SCRIPT_CONFIG.GUI)
    if guiLoaded then
        SendNotif("Success", "The Forge Berhasil Dimuat!", 5)
        print("[Loader] All scripts loaded successfully.")
    else
        _G.ForgeLoaderRunning = false -- Reset jika GUI gagal
    end
end)
