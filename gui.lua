-- ===== lprxsw - The Forge GUI (FONT 2X + SLIDER FIX + DRAG REGION SMALL) =====
-- LocalScript

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Config
local FONT_MULT = 2 -- sebelumnya 4 (jadi 2x lebih kecil)
local function FS(n) return math.floor(n * FONT_MULT + 0.5) end

-- Layout (biarkan sama; font lebih kecil akan jadi lebih lega)
local MAIN_W, MAIN_H = 980, 680
local TITLE_H = 120
local TAB_W = 240

--// Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// Wait globals
local function waitForGlobals(timeoutSec)
	local t0 = os.clock()
	while os.clock() - t0 < timeoutSec do
		if _G.DATA and _G.Settings then
			return _G.DATA, _G.Settings
		end
		task.wait(0.1)
	end
	return nil, nil
end

local DATA, Settings = waitForGlobals(10)
if not DATA or not Settings then
	warn("[x] _G.DATA / _G.Settings tidak ter-load (timeout). GUI dibatalkan.")
	return
end

--// Ensure settings branches
local function ensureBranch(root, key)
	root[key] = root[key] or {}
	return root[key]
end

ensureBranch(Settings, "Zones")
ensureBranch(Settings, "Rocks")
ensureBranch(Settings, "Ores")
Settings.TweenSpeed = Settings.TweenSpeed or 40
Settings.YOffset = Settings.YOffset or 2
Settings.AutoFarm = Settings.AutoFarm or false

ensureBranch(_G.Settings, "Zones")
ensureBranch(_G.Settings, "Rocks")
ensureBranch(_G.Settings, "Ores")
_G.Settings.TweenSpeed = _G.Settings.TweenSpeed or Settings.TweenSpeed
_G.Settings.YOffset = _G.Settings.YOffset or Settings.YOffset
_G.Settings.AutoFarm = _G.Settings.AutoFarm or Settings.AutoFarm

--// State
local scriptRunning = true
local minimized = false

--// Connection manager
local globalConnections = {}
local tabConnections = {}

local function track(scope, conn)
	table.insert(scope, conn)
	return conn
end

local function disconnectAll(scope)
	for _, c in ipairs(scope) do
		if c and c.Connected then
			c:Disconnect()
		end
	end
	table.clear(scope)
end

--// Theme (all fonts white)
local WHITE = Color3.fromRGB(255, 255, 255)
local THEME = {
	MainBg = Color3.fromRGB(15, 15, 15),
	PanelBg = Color3.fromRGB(20, 20, 20),
	ContentBg = Color3.fromRGB(10, 10, 10),
	TitleBg = Color3.fromRGB(40, 0, 0),
	Accent = Color3.fromRGB(200, 40, 40),

	Button = Color3.fromRGB(35, 0, 0),
	ButtonHover = Color3.fromRGB(70, 30, 30),
	ButtonActive = Color3.fromRGB(70, 10, 10),

	Header = Color3.fromRGB(50, 10, 10),
	Holder = Color3.fromRGB(25, 25, 25),

	Text = WHITE,
	BoxOn = Color3.fromRGB(200, 40, 40),
	BoxOff = Color3.fromRGB(40, 40, 40),
}

--// UI helpers
local function uiCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function mkLabel(parent, text, baseSize, bold)
	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1
	lb.Text = text
	lb.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lb.TextSize = FS(baseSize)
	lb.TextColor3 = THEME.Text
	lb.TextWrapped = true
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.Parent = parent
	return lb
end

local function mkButton(parent, text, baseSize)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = FS(baseSize)
	b.TextColor3 = THEME.Text
	b.TextWrapped = true
	b.BackgroundColor3 = THEME.Button
	b.Parent = parent
	return b
end

--// GUI root
local gui = Instance.new("ScreenGui")
gui.Name = "lprxsw_TheForge_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

--// Stop/Cleanup
local function stopScript()
	if not scriptRunning then return end
	scriptRunning = false

	if _G.FarmLoop ~= nil then _G.FarmLoop = false end
	if _G.Settings then _G.Settings.AutoFarm = false end
	Settings.AutoFarm = false

	disconnectAll(tabConnections)
	disconnectAll(globalConnections)

	gui:Destroy()
	print("[✓] Script stopped and cleaned up completely!")
end

--// Main frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(MAIN_W, MAIN_H)
MainFrame.Position = UDim2.new(0.5, -MAIN_W/2, 0.5, -MAIN_H/2)
MainFrame.BackgroundColor3 = THEME.MainBg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = gui
uiCorner(MainFrame, 10)

local Stroke = Instance.new("UIStroke")
Stroke.Color = THEME.Accent
Stroke.Thickness = 2
Stroke.Parent = MainFrame

--// Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = THEME.TitleBg
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleLabel = mkLabel(TitleBar, "lprxsw-The Forge", 20, true)
TitleLabel.Size = UDim2.new(1, -260, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)

local MinimizeBtn = mkButton(TitleBar, "−", 18)
MinimizeBtn.Size = UDim2.fromOffset(90, TITLE_H)
MinimizeBtn.Position = UDim2.new(1, -180, 0, 0)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
uiCorner(MinimizeBtn, 8)

local CloseBtn = mkButton(TitleBar, "×", 22)
CloseBtn.Size = UDim2.fromOffset(90, TITLE_H)
CloseBtn.Position = UDim2.new(1, -90, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
uiCorner(CloseBtn, 8)

-- Hover effects
local function hover(btn, normal, over)
	track(globalConnections, btn.MouseEnter:Connect(function()
		if not scriptRunning then return end
		btn.BackgroundColor3 = over
	end))
	track(globalConnections, btn.MouseLeave:Connect(function()
		if not scriptRunning then return end
		btn.BackgroundColor3 = normal
	end))
end
hover(MinimizeBtn, Color3.fromRGB(50, 20, 20), THEME.ButtonHover)
hover(CloseBtn, Color3.fromRGB(150, 20, 20), Color3.fromRGB(200, 30, 30))

--// Panels
local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(0, TAB_W, 1, -TITLE_H)
TabFrame.Position = UDim2.new(0, 0, 0, TITLE_H)
TabFrame.BackgroundColor3 = THEME.PanelBg
TabFrame.BorderSizePixel = 0
TabFrame.Parent = MainFrame

local TabPad = Instance.new("UIPadding")
TabPad.PaddingTop = UDim.new(0, 14)
TabPad.PaddingLeft = UDim.new(0, 12)
TabPad.PaddingRight = UDim.new(0, 12)
TabPad.Parent = TabFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 12)
TabLayout.Parent = TabFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -TAB_W, 1, -TITLE_H)
ContentFrame.Position = UDim2.new(0, TAB_W, 0, TITLE_H)
ContentFrame.BackgroundColor3 = THEME.ContentBg
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Size = UDim2.new(1, -10, 1, -10)
ContentScroll.Position = UDim2.new(0, 5, 0, 5)
ContentScroll.BackgroundTransparency = 1
ContentScroll.ScrollBarThickness = 10
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ContentScroll.Parent = ContentFrame

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingTop = UDim.new(0, 14)
ContentPadding.PaddingBottom = UDim.new(0, 14)
ContentPadding.PaddingLeft = UDim.new(0, 14)
ContentPadding.PaddingRight = UDim.new(0, 14)
ContentPadding.Parent = ContentScroll

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.FillDirection = Enum.FillDirection.Vertical
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 16)
ContentLayout.Parent = ContentScroll

--// Minimize/Restore
local function applyMinimizeState()
	if minimized then
		TabFrame.Visible = false
		ContentFrame.Visible = false
		MainFrame:TweenSize(UDim2.fromOffset(380, TITLE_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
		MinimizeBtn.Text = "□"
	else
		MainFrame:TweenSize(UDim2.fromOffset(MAIN_W, MAIN_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.22, true)
		MinimizeBtn.Text = "−"
		task.delay(0.22, function()
			if scriptRunning and not minimized then
				TabFrame.Visible = true
				ContentFrame.Visible = true
			end
		end)
	end
end

local function toggleMinimize()
	if not scriptRunning then return end
	minimized = not minimized
	applyMinimizeState()
end

track(globalConnections, CloseBtn.Activated:Connect(stopScript))
track(globalConnections, MinimizeBtn.Activated:Connect(toggleMinimize))
track(globalConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not scriptRunning then return end
	if input.KeyCode == Enum.KeyCode.L then
		toggleMinimize()
	end
end))

--// DRAG (FIX): manual title-only drag, region diperkecil (no UIDragDetector)
do
	-- Lebar area drag (hanya sisi kiri TitleBar)
	local DRAG_W = 420 -- kecilkan lagi kalau mau area drag lebih sempit

	local DragHandle = Instance.new("TextButton")
	DragHandle.Name = "DragHandle"
	DragHandle.BackgroundTransparency = 1
	DragHandle.Text = ""
	DragHandle.AutoButtonColor = false
	DragHandle.Size = UDim2.new(0, DRAG_W, 1, 0)
	DragHandle.Position = UDim2.new(0, 0, 0, 0)
	DragHandle.ZIndex = 50
	DragHandle.Parent = TitleBar

	MinimizeBtn.ZIndex = 100
	CloseBtn.ZIndex = 100
	TitleLabel.ZIndex = 60

	MainFrame.Active = true
	TitleBar.Active = true
	DragHandle.Active = true

	local dragging = false
	local dragStartPos = nil
	local frameStartPos = nil
	local dragInput = nil

	local function updateDrag(input)
		if not dragging or not dragStartPos or not frameStartPos then return end
		local delta = input.Position - dragStartPos
		MainFrame.Position = UDim2.new(
			frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X,
			frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y
		)
	end

	track(globalConnections, DragHandle.InputBegan:Connect(function(input)
		if not scriptRunning then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStartPos = input.Position
			frameStartPos = MainFrame.Position
		end
	end))

	track(globalConnections, UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateDrag(input)
		end
	end))

	track(globalConnections, UserInputService.InputEnded:Connect(function(input)
		if input == dragInput then
			dragging = false
			dragInput = nil
		end
	end))
end

--// Content builder utils
local function clearContent()
	disconnectAll(tabConnections)
	for _, child in ipairs(ContentScroll:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end
		child:Destroy()
	end
	ContentScroll.CanvasPosition = Vector2.new(0, 0)
end

local function createTabButton(text)
	local btn = mkButton(TabFrame, text, 14)
	btn.Size = UDim2.new(1, 0, 0, 110)
	btn.BackgroundColor3 = THEME.Button
	uiCorner(btn, 10)
	return btn
end

local selectedTabButton = nil
local function setTabSelected(btn)
	if selectedTabButton and selectedTabButton.Parent then
		selectedTabButton.BackgroundColor3 = THEME.Button
	end
	selectedTabButton = btn
	btn.BackgroundColor3 = THEME.ButtonActive
end

local function createCheckboxRow(parent, text, initial, onChanged)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 100)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local box = Instance.new("TextButton")
	box.Size = UDim2.fromOffset(50, 50)
	box.Position = UDim2.new(0, 12, 0.5, -25)
	box.Text = ""
	box.AutoButtonColor = false
	box.BackgroundColor3 = initial and THEME.BoxOn or THEME.BoxOff
	box.Parent = row
	uiCorner(box, 10)

	local lb = mkLabel(row, text, 14, true)
	lb.Size = UDim2.new(1, -90, 1, 0)
	lb.Position = UDim2.new(0, 80, 0, 0)

	local state = initial
	local function repaint()
		box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
	end

	track(tabConnections, box.Activated:Connect(function()
		if not scriptRunning then return end
		state = not state
		repaint()
		onChanged(state)
	end))

	return row
end

local function createSlider(parent, title, minV, maxV, initial, onChanged)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 170)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local label = mkLabel(holder, title .. ": " .. tostring(initial), 14, false)
	label.Size = UDim2.new(1, 0, 0, 70)
	label.Position = UDim2.new(0, 10, 0, 0)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -20, 0, 18)
	bar.Position = UDim2.new(0, 10, 0, 92)
	bar.BackgroundColor3 = THEME.TitleBg
	bar.BorderSizePixel = 0
	bar.Parent = holder
	bar.Active = true -- bantu agar input slider konsisten
	uiCorner(bar, 9)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(32, 46)
	knob.BackgroundColor3 = THEME.Accent
	knob.BorderSizePixel = 0
	knob.Parent = bar
	uiCorner(knob, 12)

	local value = math.clamp(initial, minV, maxV)

	local function setValueFromRel(rel)
		rel = math.clamp(rel, 0, 1)
		value = math.floor((minV + (maxV - minV) * rel) + 0.5)
		local rel2 = (value - minV) / (maxV - minV)
		knob.Position = UDim2.new(rel2, -16, 0.5, -23)
		label.Text = title .. ": " .. tostring(value)
		onChanged(value)
	end

	setValueFromRel((value - minV) / (maxV - minV))

	local dragging = false
	local dragConnChanged, dragConnEnded = nil, nil

	local function stopDrag()
		dragging = false
		if dragConnChanged then dragConnChanged:Disconnect() end
		if dragConnEnded then dragConnEnded:Disconnect() end
		dragConnChanged, dragConnEnded = nil, nil
	end

	local function startDrag(startInput)
		dragging = true

		local function updateByX(x)
			local rel = (x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
			setValueFromRel(rel)
		end

		updateByX(startInput.Position.X)

		dragConnChanged = UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				updateByX(input.Position.X)
			end
		end)

		dragConnEnded = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				stopDrag()
			end
		end)

		table.insert(tabConnections, dragConnChanged)
		table.insert(tabConnections, dragConnEnded)
	end

	track(tabConnections, bar.InputBegan:Connect(function(input)
		if not scriptRunning then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDrag(input)
		end
	end))

	return holder
end

local function createCollapsibleSection(title, items, settingsTable, settingsKey)
	ensureBranch(Settings, settingsKey)
	ensureBranch(_G.Settings, settingsKey)

	local section = Instance.new("Frame")
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundTransparency = 1
	section.Parent = ContentScroll

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = section

	local header = mkButton(section, "► " .. title, 14)
	header.Size = UDim2.new(1, 0, 0, 110)
	header.BackgroundColor3 = THEME.Header
	uiCorner(header, 10)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, 0, 0, 0)
	content.BackgroundColor3 = THEME.Holder
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.Parent = section
	uiCorner(content, 10)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.Parent = content

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 10)
	contentLayout.Parent = content

	for _, itemNameAny in ipairs(items) do
		local itemName = tostring(itemNameAny)

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 86)
		row.BackgroundTransparency = 1
		row.Parent = content

		local box = Instance.new("TextButton")
		box.Size = UDim2.fromOffset(50, 50)
		box.Position = UDim2.new(0, 14, 0.5, -25)
		box.Text = ""
		box.AutoButtonColor = false
		box.Parent = row
		uiCorner(box, 10)

		local label = mkLabel(row, itemName, 16, false)
		label.Size = UDim2.new(1, -110, 1, 0)
		label.Position = UDim2.new(0, 88, 0, 0)
		label.TextColor3 = THEME.Text

		local state = settingsTable[itemName] and true or false
		local function repaint()
			box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
		end
		repaint()

		track(tabConnections, box.Activated:Connect(function()
			if not scriptRunning then return end
			state = not state
			repaint()
			settingsTable[itemName] = state
			_G.Settings[settingsKey][itemName] = state
		end))
	end

	local expanded = false

	local function getExpandedHeight()
		RunService.Heartbeat:Wait()
		local h = contentLayout.AbsoluteContentSize.Y
		local padH = 28
		return h + padH
	end

	local function setExpanded(on)
		expanded = on
		header.Text = (expanded and "▼ " or "► ") .. title
		local goalH = expanded and getExpandedHeight() or 0
		TweenService:Create(
			content,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(1, 0, 0, goalH) }
		):Play()
	end

	track(tabConnections, header.Activated:Connect(function()
		if not scriptRunning then return end
		setExpanded(not expanded)
	end))
end

--// Tabs
local function buildAutoTab()
	clearContent()

	createCheckboxRow(ContentScroll, "Enable Auto Mining", Settings.AutoFarm == true, function(v)
		Settings.AutoFarm = v
		_G.Settings.AutoFarm = v
	end)

	createCollapsibleSection(("Zones (%d)"):format(#DATA.Zones), DATA.Zones, Settings.Zones, "Zones")
	createCollapsibleSection(("Rocks (%d)"):format(#DATA.Rocks), DATA.Rocks, Settings.Rocks, "Rocks")
	createCollapsibleSection(("Ores (%d)"):format(#DATA.Ores), DATA.Ores, Settings.Ores, "Ores")
end

local function buildSettingTab()
	clearContent()

	createSlider(ContentScroll, "Tween Speed", 25, 80, Settings.TweenSpeed or 40, function(v)
		Settings.TweenSpeed = v
		_G.Settings.TweenSpeed = v
	end)

	createSlider(ContentScroll, "Y Offset", -10, 10, Settings.YOffset or 2, function(v)
		Settings.YOffset = v
		_G.Settings.YOffset = v
	end)
end

--// Tab buttons
local autoBtn = createTabButton("Auto Mining")
local settingBtn = createTabButton("Settings")

track(globalConnections, autoBtn.Activated:Connect(function()
	if not scriptRunning then return end
	if minimized then toggleMinimize() end
	setTabSelected(autoBtn)
	buildAutoTab()
end))

track(globalConnections, settingBtn.Activated:Connect(function()
	if not scriptRunning then return end
	if minimized then toggleMinimize() end
	setTabSelected(settingBtn)
	buildSettingTab()
end))

-- Default
setTabSelected(autoBtn)
buildAutoTab()

print("[✓] GUI Loaded Successfully!")
print("[✓] Press L to minimize/restore")
print("[✓] Click × to close and stop script")
