--[[  
    ===== THE FORGE ULTIMATE LOADER =====
    Author: akhdddn
    Features: 
    - Auto Raw Link Converter
    - Anti-Cache (Always Latest Version)
    - Robust Error Handling
    - Notification System
    - Module-return Support (Setting/Core can return table)
]]

local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

-- // KONFIGURASI URL
local SCRIPT_CONFIG = {
    Setting = "https://github.com/akhdddn/testing/blob/main/setting.lua",
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
        url = url:gsub("github.com", "raw.githubusercontent.com")
        url = url:gsub("/blob/", "/")
    end
    -- Anti-Cache: aman untuk url yg sudah punya query
    local sep = url:find("%?") and "&" or "?"
    return url .. sep .. "t=" .. tostring(os.time())
end

-- // Helper: tunggu globals siap
local function WaitForGlobals(timeout)
    local t0 = os.clock()
    while os.clock() - t0 < (timeout or 5) do
        if _G.Settings and _G.DATA then
            return true
        end
        task.wait(0.1)
    end
    return false
end

-- // 2. EXECUTION HANDLER
-- return: (ok:boolean, ret:any)
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
        return false, nil
    end

    -- Tahap 2: Loadstring (Compile)
    local func, syntaxErr = loadstring(response)
    if not func then
        warn("[Loader] Syntax Error di " .. name .. ": " .. tostring(syntaxErr))
        SendNotif("Syntax Error", "Ada kesalahan kode di " .. name .. "!", 5)
        return false, nil
    end

    -- Tahap 3: Eksekusi (ambil return value)
    local execSuccess, retOrErr = pcall(func)
    if not execSuccess then
        warn("[Loader] Runtime Error di " .. name .. ": " .. tostring(retOrErr))
        SendNotif("Runtime Error", "Error saat menjalankan " .. name, 5)
        return false, nil
    end

    return true, retOrErr
end

-- // 3. MAIN SEQUENCE
if _G.ForgeLoaderRunning then
    SendNotif("Warning", "Script sudah berjalan! Rejoin jika ingin restart.", 3)
    return
end
_G.ForgeLoaderRunning = true

task.spawn(function()
    SendNotif("The Forge", "Memulai Loader...", 2)

    -- (1) SETTING
    local okSetting, settingRet = LoadScript("Setting Script", SCRIPT_CONFIG.Setting)
    if not okSetting then
        SendNotif("Failed", "Setting gagal dimuat. Core & GUI dibatalkan.", 5)
        _G.ForgeLoaderRunning = false
        return
    end

    -- Jika setting.lua adalah module style: return table { ApplyToGlobals = fn }
    if type(settingRet) == "table" and type(settingRet.ApplyToGlobals) == "function" then
        local okCall, err = pcall(settingRet.ApplyToGlobals)
        if not okCall then
            warn("[Loader] Error calling Setting.ApplyToGlobals(): " .. tostring(err))
            SendNotif("Runtime Error", "ApplyToGlobals() gagal.", 5)
            _G.ForgeLoaderRunning = false
            return
        end
    end

    -- Pastikan globals siap (buat GUI/Core yang pakai _G)
    WaitForGlobals(5)

    task.wait(0.2)

    -- (2) CORE
    local okCore, coreRet = LoadScript("Core Script", SCRIPT_CONFIG.Core)
    if not okCore then
        SendNotif("Failed", "Core gagal dimuat. GUI dibatalkan.", 5)
        _G.ForgeLoaderRunning = false
        return
    end

    -- Jika core.lua adalah module style: return table { Start = fn }
    if type(coreRet) == "table" and type(coreRet.Start) == "function" then
        local okCall, err = pcall(coreRet.Start, _G.Settings, _G.DATA)
        if not okCall then
            warn("[Loader] Error calling Core.Start(): " .. tostring(err))
            SendNotif("Runtime Error", "Core.Start() gagal.", 5)
            _G.ForgeLoaderRunning = false
            return
        end
    end

    task.wait(0.5)

    -- (3) GUI
    local okGui, guiRet = LoadScript("GUI Script", SCRIPT_CONFIG.GUI)
    if not okGui then
        _G.ForgeLoaderRunning = false
        return
    end

    -- Optional: kalau GUI kamu juga module style
    if type(guiRet) == "table" then
        if type(guiRet.Start) == "function" then
            pcall(guiRet.Start, _G.Settings, _G.DATA)
        elseif type(guiRet.Init) == "function" then
            pcall(guiRet.Init, _G.Settings, _G.DATA)
        end
    elseif type(guiRet) == "function" then
        pcall(guiRet)
    end

    SendNotif("Success", "The Forge Berhasil Dimuat!", 5)
    print("[Loader] All scripts loaded successfully.")
end)
