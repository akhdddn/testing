-- ===== lprxsw - The Forge GUI (MAXIMIZED V4 - WITH DEBUG) =====
--// Features:
--// - Auto-Scale Layout (Fits any Mobile/PC screen)
--// - Search Filter for Zones/Rocks/Ores
--// - High Z-Index (Above Roblox Controls)
--// - Drag Fix + Mobile Friendly Scroll
--// - [NEW] Real-time Debug Panel + Log Viewer

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

--// --- [ DYNAMIC SCALING CONFIG ] ---
local cam = Workspace.CurrentCamera
local vp = cam.ViewportSize

local IS_MOBILE = (vp.Y < 600) or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
local TARGET_W = math.floor(vp.X * (IS_MOBILE and 0.9 or 0.6))
local TARGET_H = math.floor(vp.Y * (IS_MOBILE and 0.85 or 0.6))
local TITLE_H = IS_MOBILE and 60 or 50
local TAB_W = IS_MOBILE and math.floor(TARGET_W * 0.28) or 180
local FONT_MULT = IS_MOBILE and 1.8 or 1.5 
local function FS(n) return math.floor(n * FONT_MULT + 0.5) end

--// Services & Wait
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function waitForGlobals(timeoutSec)
	local t0 = os.clock()
	while os.clock() - t0 < timeoutSec do
		if _G.DATA and _G.Settings then return _G.DATA, _G.Settings end
		task.wait(0.1)
	end
	return nil, nil
end

local DATA, Settings = waitForGlobals(10)
if not DATA or not Settings then
	warn("[x] Timeout: _G.DATA/_G.Settings not found.")
	return
end

--// Config Ensure
local function ensureBranch(root, key) root[key] = root[key] or {}; return root[key] end
ensureBranch(Settings, "Zones"); ensureBranch(Settings, "Rocks"); ensureBranch(Settings, "Ores")
Settings.TweenSpeed = Settings.TweenSpeed or 40
Settings.YOffset = Settings.YOffset or 2
Settings.AutoFarm = Settings.AutoFarm or false
Settings.HitInterval = Settings.HitInterval or 0.15

ensureBranch(_G.Settings, "Zones"); ensureBranch(_G.Settings, "Rocks"); ensureBranch(_G.Settings, "Ores")
_G.Settings.TweenSpeed = _G.Settings.TweenSpeed or Settings.TweenSpeed
_G.Settings.YOffset = _G.Settings.YOffset or Settings.YOffset
_G.Settings.AutoFarm = _G.Settings.AutoFarm or Settings.AutoFarm
_G.Settings.HitInterval = _G.Settings.HitInterval or Settings.HitInterval

--// [TAMBAH] DEBUG SYSTEM
local DEBUG = {
	Enabled = true,
	Logs = {},
	MaxLogs = 50,
	LivePanel = nil,
}

local function DebugLog(tag, message, logType)
	logType = logType or "INFO"
	local timestamp = os.date("%H:%M:%S")
	local logEntry = string.format("[%s] [%s] [%s] %s", timestamp, tag, logType, message)
	
	table.insert(DEBUG.Logs, logEntry)
	if #DEBUG.Logs > DEBUG.MaxLogs then table.remove(DEBUG.Logs, 1) end
	
	print(logEntry)
	
	-- [UPDATE] Live panel if exists
	if DEBUG.LivePanel then
		UpdateDebugPanel()
	end
end

local function UpdateDebugPanel()
	-- Will be called when debug panel visible
end

_G.DebugLog = DebugLog

--// State
local scriptRunning = true
local minimized = false
local globalConnections = {}
local tabConnections = {}

local function track(scope, conn) table.insert(scope, conn); return conn end
local function disconnectAll(scope)
	for _, c in ipairs(scope) do if c and c.Connected then c:Disconnect() end end
	table.clear(scope)
end

--// Theme
local WHITE = Color3.fromRGB(255, 255, 255)
local THEME = {
	MainBg = Color3.fromRGB(15, 15, 15),
	PanelBg = Color3.fromRGB(22, 22, 22),
	ContentBg = Color3.fromRGB(12, 12, 12),
	TitleBg = Color3.fromRGB(45, 10, 10),
	Accent = Color3.fromRGB(220, 50, 50),
	Button = Color3.fromRGB(40, 10, 10),
	ButtonHover = Color3.fromRGB(80, 30, 30),
	ButtonActive = Color3.fromRGB(90, 20, 20),
	Header = Color3.fromRGB(60, 15, 15),
	Holder = Color3.fromRGB(28, 28, 28),
	Text = WHITE,
	BoxOn = Color3.fromRGB(220, 50, 50),
	BoxOff = Color3.fromRGB(50, 50, 50),
	DebugBg = Color3.fromRGB(20, 20, 20),
	DebugInfo = Color3.fromRGB(100, 150, 200),
	DebugError = Color3.fromRGB(220, 80, 80),
	DebugSuccess = Color3.fromRGB(80, 180, 80),
}

--// UI Helpers
local function uiCorner(parent, radius)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent; return c
end

local function mkLabel(parent, text, baseSize, bold)
	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1; lb.Text = text
	lb.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	lb.TextSize = FS(baseSize); lb.TextColor3 = THEME.Text
	lb.TextWrapped = true; lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.Parent = parent
	return lb
end

local function mkButton(parent, text, baseSize)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false; b.Text = text
	b.Font = Enum.Font.GothamBold; b.TextSize = FS(baseSize)
	b.TextColor3 = THEME.Text; b.TextWrapped = true
	b.BackgroundColor3 = THEME.Button; b.Parent = parent
	return b
end

--// GUI ROOT
local gui = Instance.new("ScreenGui")
gui.Name = "lprxsw_Forge_MAX_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local function stopScript()
	if not scriptRunning then return end
	scriptRunning = false
	if _G.FarmLoop ~= nil then _G.FarmLoop = false end
	if _G.Settings then _G.Settings.AutoFarm = false end
	Settings.AutoFarm = false
	disconnectAll(tabConnections)
	disconnectAll(globalConnections)
	DebugLog("GUI", "Script stopped", "SUCCESS")
	gui:Destroy()
end

--// MAIN FRAME
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(TARGET_W, TARGET_H)
MainFrame.Position = UDim2.new(0.5, -TARGET_W/2, 0.5, -TARGET_H/2)
MainFrame.BackgroundColor3 = THEME.MainBg
MainFrame.ClipsDescendants = true
MainFrame.Parent = gui
uiCorner(MainFrame, 12)

local Stroke = Instance.new("UIStroke")
Stroke.Color = THEME.Accent; Stroke.Thickness = 2; Stroke.Parent = MainFrame

--// TITLE BAR
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = THEME.TitleBg
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleLabel = mkLabel(TitleBar, "  The Forge Core", 16, true)
TitleLabel.Size = UDim2.new(1, -140, 1, 0)
TitleLabel.Position = UDim2.new(0, 5, 0, 0)

-- Control Buttons
local btnSize = math.floor(TITLE_H * 0.8)
local btnY = math.floor((TITLE_H - btnSize)/2)

local CloseBtn = mkButton(TitleBar, "×", 20)
CloseBtn.Size = UDim2.fromOffset(btnSize, btnSize)
CloseBtn.Position = UDim2.new(1, -btnSize - 8, 0, btnY)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
uiCorner(CloseBtn, 6)

local MinimizeBtn = mkButton(TitleBar, "−", 20)
MinimizeBtn.Size = UDim2.fromOffset(btnSize, btnSize)
MinimizeBtn.Position = UDim2.new(1, -btnSize*2 - 16, 0, btnY)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
uiCorner(MinimizeBtn, 6)

--// PANELS
local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(0, TAB_W, 1, -TITLE_H)
TabFrame.Position = UDim2.new(0, 0, 0, TITLE_H)
TabFrame.BackgroundColor3 = THEME.PanelBg
TabFrame.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.Padding = UDim.new(0, 8); TabLayout.Parent = TabFrame
local TabPad = Instance.new("UIPadding")
TabPad.PaddingTop = UDim.new(0, 10); TabPad.PaddingLeft = UDim.new(0,8); TabPad.PaddingRight=UDim.new(0,8); TabPad.Parent = TabFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -TAB_W, 1, -TITLE_H)
ContentFrame.Position = UDim2.new(0, TAB_W, 0, TITLE_H)
ContentFrame.BackgroundColor3 = THEME.ContentBg
ContentFrame.Parent = MainFrame

local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Size = UDim2.new(1, -10, 1, -10)
ContentScroll.Position = UDim2.new(0, 5, 0, 5)
ContentScroll.BackgroundTransparency = 1
ContentScroll.ScrollBarThickness = IS_MOBILE and 12 or 8
ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentScroll.Parent = ContentFrame
Instance.new("UIPadding", ContentScroll).PaddingTop = UDim.new(0,10)
Instance.new("UIPadding", ContentScroll).PaddingLeft = UDim.new(0,10)
Instance.new("UIPadding", ContentScroll).PaddingRight = UDim.new(0,4)

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 10); ContentLayout.Parent = ContentScroll

--// LOGIC: MINIMIZE
local function toggleMinimize()
	minimized = not minimized
	if minimized then
		MainFrame:TweenSize(UDim2.fromOffset(200, TITLE_H), "Out", "Quad", 0.3, true)
		TabFrame.Visible = false; ContentFrame.Visible = false
		MinimizeBtn.Text = "□"
	else
		MainFrame:TweenSize(UDim2.fromOffset(TARGET_W, TARGET_H), "Out", "Quad", 0.3, true)
		MinimizeBtn.Text = "−"
		task.delay(0.3, function() if not minimized then TabFrame.Visible = true; ContentFrame.Visible = true end end)
	end
end
track(globalConnections, MinimizeBtn.Activated:Connect(toggleMinimize))
track(globalConnections, CloseBtn.Activated:Connect(stopScript))

--// LOGIC: DRAG (Title Only)
local dragInput, dragStart, startPos
local function update(input)
	local delta = input.Position - dragStart
	MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
track(globalConnections, TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if input.Position.X > MinimizeBtn.AbsolutePosition.X then return end
		dragStart = input.Position; startPos = MainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragStart = nil end
		end)
	end
end))
track(globalConnections, TitleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if dragStart then update(input) end
	end
end))

--// COMPONENTS
local function clearContent()
	disconnectAll(tabConnections)
	for _, c in ipairs(ContentScroll:GetChildren()) do
		if not c:IsA("UILayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
	ContentScroll.CanvasPosition = Vector2.zero
end

local function createTabButton(text)
	local btn = mkButton(TabFrame, text, 12)
	btn.Size = UDim2.new(1, 0, 0, IS_MOBILE and 50 or 40)
	uiCorner(btn, 8)
	return btn
end
local curTabBtn = nil
local function setTabSelected(btn)
	if curTabBtn then curTabBtn.BackgroundColor3 = THEME.Button end
	curTabBtn = btn; btn.BackgroundColor3 = THEME.ButtonActive
end

local function createSearchBar(parent, onSearch)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 35)
	box.PlaceholderText = "Search..."
	box.Text = ""
	box.BackgroundColor3 = THEME.Holder
	box.TextColor3 = WHITE
	box.Font = Enum.Font.Gotham
	box.TextSize = FS(14)
	box.Parent = parent
	uiCorner(box, 8)
	
	track(tabConnections, box:GetPropertyChangedSignal("Text"):Connect(function()
		onSearch(box.Text)
	end))
	return box
end

local function createCheckbox(parent, text, val, cb)
	local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,45); row.BackgroundTransparency=1; row.Parent=parent
	local btn = Instance.new("TextButton"); btn.Size=UDim2.fromOffset(45,35); btn.Position=UDim2.new(0,0,0.5,-17.5)
	btn.Text=""; btn.AutoButtonColor=false; btn.BackgroundColor3=val and THEME.BoxOn or THEME.BoxOff; btn.Parent=row; uiCorner(btn,8)
	local lbl = mkLabel(row, text, 14, true); lbl.Size=UDim2.new(1,-55,1,0); lbl.Position=UDim2.new(0,55,0,0)
	
	track(tabConnections, btn.Activated:Connect(function()
		val = not val; btn.BackgroundColor3 = val and THEME.BoxOn or THEME.BoxOff
		cb(val)
		DebugLog("SETTINGS", "Toggled: "..text.." = "..tostring(val), "DEBUG")
	end))
	return row
end

local function createSlider(parent, text, min, max, val, cb)
	local h = Instance.new("Frame"); h.Size=UDim2.new(1,0,0,60); h.BackgroundTransparency=1; h.Parent=parent
	local lbl = mkLabel(h, text..": "..val, 12, false); lbl.Size=UDim2.new(1,0,0,25)
	local bar = Instance.new("Frame"); bar.Size=UDim2.new(1,-10,0,10); bar.Position=UDim2.new(0,5,0,35)
	bar.BackgroundColor3=THEME.Holder; bar.Parent=h; uiCorner(bar,5)
	local knob = Instance.new("Frame"); knob.Size=UDim2.fromOffset(20,20); knob.BackgroundColor3=THEME.Accent
	knob.Parent=bar; uiCorner(knob,10); knob.Position=UDim2.new((val-min)/(max-min), -10, 0.5, -10)
	
	local dragging = false
	local function update(input)
		local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
		val = math.floor(min + (max-min)*rel)
		knob.Position = UDim2.new(rel, -10, 0.5, -10)
		lbl.Text = text..": "..val
		cb(val)
	end
	track(tabConnections, bar.InputBegan:Connect(function(i) 
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; update(i)
		end
	end))
	track(tabConnections, UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
	end))
	track(tabConnections, UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then update(i) end
	end))
end

local function createCollapsible(title, list, setTable, setKey)
	ensureBranch(Settings, setKey); ensureBranch(_G.Settings, setKey)
	
	local holder = Instance.new("Frame"); holder.AutomaticSize = Enum.AutomaticSize.Y; holder.Size=UDim2.new(1,0,0,0)
	holder.BackgroundTransparency=1; holder.Parent=ContentScroll
	
	local head = mkButton(holder, "► "..title, 14); head.Size=UDim2.new(1,0,0,40); head.BackgroundColor3=THEME.Header; uiCorner(head,8)
	
	local content = Instance.new("Frame"); content.Size=UDim2.new(1,0,0,0); content.Visible=false; content.ClipsDescendants=true
	content.BackgroundColor3=THEME.Holder; content.Parent=holder; uiCorner(content,8)
	local cLay = Instance.new("UIListLayout"); cLay.Parent=content; cLay.Padding=UDim.new(0,5)
	Instance.new("UIPadding", content).PaddingTop=UDim.new(0,10); Instance.new("UIPadding", content).PaddingLeft=UDim.new(0,10)
	
	local allItems = {}
	
	local searchRow = Instance.new("Frame"); searchRow.Size=UDim2.new(1,-20,0,35); searchRow.BackgroundTransparency=1; searchRow.Parent=content
	createSearchBar(searchRow, function(text)
		text = text:lower()
		local visCount = 0
		for name, row in pairs(allItems) do
			if name:lower():find(text) then
				row.Visible = true; visCount += 1
			else
				row.Visible = false
			end
		end
		if content.Visible then
			content.Size = UDim2.new(1,0,0, cLay.AbsoluteContentSize.Y + 20)
		end
	end)

	for _, name in ipairs(list) do
		local row = Instance.new("Frame"); row.Size=UDim2.new(1,-20,0,40); row.BackgroundTransparency=1; row.Parent=content
		local btn = Instance.new("TextButton"); btn.Size=UDim2.fromOffset(30,30); btn.Position=UDim2.new(0,0,0.5,-15)
		local isActive = setTable[name]
		btn.BackgroundColor3 = isActive and THEME.BoxOn or THEME.BoxOff; btn.Text=""; btn.Parent=row; uiCorner(btn,6)
		local lb = mkLabel(row, name, 13, false); lb.Size=UDim2.new(1,-40,1,0); lb.Position=UDim2.new(0,40,0,0)
		
		track(tabConnections, btn.Activated:Connect(function()
			isActive = not isActive; btn.BackgroundColor3 = isActive and THEME.BoxOn or THEME.BoxOff
			setTable[name] = isActive; _G.Settings[setKey][name] = isActive
			DebugLog("SELECT", setKey..": "..name.." = "..tostring(isActive), "DEBUG")
		end))
		
		allItems[name] = row
	end
	
	local expanded = false
	track(tabConnections, head.Activated:Connect(function()
		expanded = not expanded
		head.Text = (expanded and "▼ " or "► ")..title
		content.Visible = expanded
		if expanded then
			content.Size = UDim2.new(1,0,0, cLay.AbsoluteContentSize.Y + 20)
		else
			content.Size = UDim2.new(1,0,0,0)
		end
	end))
end

-- [TAMBAH] DEBUG PANEL
local function buildDebug()
	clearContent()
	
	-- [TAMBAH] Status Header
	local statusHolder = Instance.new("Frame")
	statusHolder.AutomaticSize = Enum.AutomaticSize.Y
	statusHolder.Size = UDim2.new(1, 0, 0, 0)
	statusHolder.BackgroundTransparency = 1
	statusHolder.Parent = ContentScroll
	
	local statusLay = Instance.new("UIListLayout")
	statusLay.Parent = statusHolder
	statusLay.Padding = UDim.new(0, 5)
	
	-- Real-time status rows
	local function createStatusRow(label)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = THEME.Holder
		row.Parent = statusHolder
		uiCorner(row, 6)
		
		local lbl = mkLabel(row, label, 11, false)
		lbl.Size = UDim2.new(1, -10, 1, 0)
		lbl.Position = UDim2.new(0, 5, 0, 0)
		
		return lbl
	end
	
	local lblAutoFarm = createStatusRow("AutoFarm: OFF")
	local lblTarget = createStatusRow("Target: None")
	local lblHP = createStatusRow("Target HP: --")
	local lblHits = createStatusRow("Hits: 0")
	local lblDist = createStatusRow("Distance: --")
	
	-- [TAMBAH] Real-time update every frame
	local debugConn = RunService.RenderStepped:Connect(function()
		if not scriptRunning or minimized then return end
		
		lblAutoFarm.Text = "AutoFarm: "..(Settings.AutoFarm and "ON ✓" or "OFF")
		
		local char = player.Character
		if char and Settings.AutoFarm then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				-- Try to find target
				local rocksFolder = Workspace:FindFirstChild("Rocks")
				if rocksFolder then
					local closest = nil
					local minDist = math.huge
					
					for _, zone in ipairs(rocksFolder:GetChildren()) do
						if zone:IsA("Folder") then
							for _, inst in ipairs(zone:GetDescendants()) do
								if inst:IsA("Model") and inst.Parent.Name ~= "Rock" then
									local p = inst.PrimaryPart or inst:FindFirstChild("Hitbox")
									if p then
										local hp = inst:GetAttribute("Health") or 100
										if hp > 0 then
											local d = (root.Position - p.Position).Magnitude
											if d < minDist then
												minDist = d
												closest = inst
											end
										end
									end
								end
							end
						end
					end
					
					if closest then
						lblTarget.Text = "Target: "..closest.Name
						lblHP.Text = "Target HP: "..(closest:GetAttribute("Health") or "?").."/"..( closest:GetAttribute("MaxHealth") or "100")
						lblDist.Text = "Distance: "..string.format("%.1f", minDist)
					else
						lblTarget.Text = "Target: None"
						lblHP.Text = "Target HP: --"
						lblDist.Text = "Distance: --"
					end
				end
			end
		else
			lblTarget.Text = "Target: None"
			lblHP.Text = "Target HP: --"
			lblDist.Text = "Distance: --"
		end
	end)
	
	table.insert(tabConnections, debugConn)
	
	-- [TAMBAH] Log Viewer
	local logHolder = Instance.new("Frame")
	logHolder.Size = UDim2.new(1, 0, 0, 200)
	logHolder.BackgroundColor3 = THEME.DebugBg
	logHolder.Parent = ContentScroll
	uiCorner(logHolder, 8)
	
	local logScroll = Instance.new("ScrollingFrame")
	logScroll.Size = UDim2.new(1, -10, 1, -10)
	logScroll.Position = UDim2.new(0, 5, 0, 5)
	logScroll.BackgroundTransparency = 1
	logScroll.ScrollBarThickness = 6
	logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logScroll.Parent = logHolder
	
	local logLay = Instance.new("UIListLayout")
	logLay.Padding = UDim.new(0, 2)
	logLay.Parent = logScroll
	
	local logLabel = Instance.new("TextLabel")
	logLabel.Size = UDim2.new(1, 0, 0, 0)
	logLabel.AutomaticSize = Enum.AutomaticSize.Y
	logLabel.BackgroundTransparency = 1
	logLabel.Font = Enum.Font.Courier
	logLabel.TextSize = FS(10)
	logLabel.TextColor3 = THEME.Text
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.TextYAlignment = Enum.TextYAlignment.Top
	logLabel.TextWrapped = true
	logLabel.Parent = logScroll
	
	-- Update log display
	UpdateDebugPanel = function()
		local logText = ""
		for i = math.max(1, #DEBUG.Logs - 20), #DEBUG.Logs do
			logText = logText .. DEBUG.Logs[i] .. "\n"
		end
		logLabel.Text = logText
		logScroll.CanvasPosition = Vector2.new(0, logScroll.AbsoluteCanvasSize.Y)
	end
	
	-- [TAMBAH] Clear logs button
	local clearBtn = mkButton(ContentScroll, "Clear Logs", 12)
	clearBtn.Size = UDim2.new(1, 0, 0, 40)
	clearBtn.BackgroundColor3 = THEME.Header
	uiCorner(clearBtn, 6)
	
	track(tabConnections, clearBtn.Activated:Connect(function()
		table.clear(DEBUG.Logs)
		logLabel.Text = ""
		DebugLog("DEBUG", "Logs cleared", "SUCCESS")
	end))
	
	DebugLog("DEBUG", "Debug panel opened", "SUCCESS")
end

--// TABS BUILDER
local function buildAuto()
	clearContent()
	createCheckbox(ContentScroll, "Enable Auto Mining", Settings.AutoFarm, function(v)
		Settings.AutoFarm = v; _G.Settings.AutoFarm = v
		DebugLog("AUTO", "AutoFarm toggled: "..tostring(v), "DEBUG")
	end)
	createCollapsible("Zones ("..#DATA.Zones..")", DATA.Zones, Settings.Zones, "Zones")
	createCollapsible("Rocks ("..#DATA.Rocks..")", DATA.Rocks, Settings.Rocks, "Rocks")
	createCollapsible("Ores ("..#DATA.Ores..")", DATA.Ores, Settings.Ores, "Ores")
end

local function buildSettings()
	clearContent()
	createSlider(ContentScroll, "Tween Speed", 20, 100, Settings.TweenSpeed, function(v)
		Settings.TweenSpeed = v; _G.Settings.TweenSpeed = v
		DebugLog("SETTINGS", "TweenSpeed changed to "..v, "DEBUG")
	end)
	createSlider(ContentScroll, "Y Offset (Height)", -10, 10, Settings.YOffset, function(v)
		Settings.YOffset = v; _G.Settings.YOffset = v
		DebugLog("SETTINGS", "YOffset changed to "..v, "DEBUG")
	end)
	createSlider(ContentScroll, "Hit Interval", 0.05, 1.0, Settings.HitInterval, function(v)
		Settings.HitInterval = math.floor(v*100)/100
		_G.Settings.HitInterval = Settings.HitInterval
		DebugLog("SETTINGS", "HitInterval changed to "..Settings.HitInterval, "DEBUG")
	end)
end

--// INIT
local bAuto = createTabButton("Auto Farm")
local bSet = createTabButton("Settings")
local bDebug = createTabButton("Debug")

track(globalConnections, bAuto.Activated:Connect(function() setTabSelected(bAuto); buildAuto() end))
track(globalConnections, bSet.Activated:Connect(function() setTabSelected(bSet); buildSettings() end))
track(globalConnections, bDebug.Activated:Connect(function() setTabSelected(bDebug); buildDebug() end))

setTabSelected(bAuto)
buildAuto()

DebugLog("STARTUP", "GUI v4 Loaded with Debug System", "SUCCESS")
print("[✓] MAXIMIZED GUI v4 Loaded (With Debug Panel)")
