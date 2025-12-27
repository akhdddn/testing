-- ForgeUI_Compat.lua (LocalScript)
-- Compatible with:
-- 1) Old UI-only script behavior (fallback)
-- 2) ReplicatedStorage/ForgeSettings + ReplicatedStorage/ForgeCore split system

-- ========= SERVICES =========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========= FIND MODULES (SAFE) =========
local function findFirstDescendantByName(root, name)
	local inst = root:FindFirstChild(name)
	if inst then return inst end
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local ForgeSettingsMS = findFirstDescendantByName(ReplicatedStorage, "ForgeSettings")
local ForgeCoreMS = findFirstDescendantByName(ReplicatedStorage, "ForgeCore")

-- ========= RESOLVE SETTINGS/DATA =========
local Settings, DATA
local usingModules = false

if ForgeSettingsMS and ForgeSettingsMS:IsA("ModuleScript") then
	local ok, mod = pcall(require, ForgeSettingsMS)
	if ok and type(mod) == "table" and type(mod.ApplyToGlobals) == "function" then
		local s, d = mod.ApplyToGlobals()
		if type(s) == "table" and type(d) == "table" then
			Settings, DATA = s, d
			usingModules = true
		end
	end
end

-- UI-only fallback (still compatible with old UI intent)
if not Settings then
	_G.Settings = _G.Settings or {}
	Settings = _G.Settings

	Settings.AutoFarm = (Settings.AutoFarm ~= nil) and Settings.AutoFarm or false
	Settings.TweenSpeed = tonumber(Settings.TweenSpeed) or 55
	Settings.YOffset = tonumber(Settings.YOffset) or 3

	Settings.Zones = Settings.Zones or {}
	Settings.Rocks = Settings.Rocks or {}
	Settings.Ores  = Settings.Ores  or {}

	DATA = _G.DATA or {
		Zones = {"ZoneA","ZoneB","ZoneC"},
		Rocks = {"RockA","RockB","RockC"},
		Ores  = {"OreA","OreB","OreC"},
	}
	_G.DATA = DATA
end

-- Ensure map tables contain keys for DATA lists (important even with modules if someone edits DATA)
local function ensureMap(map, list)
	if type(map) ~= "table" then return end
	if type(list) ~= "table" then return end
	for _, name in ipairs(list) do
		if map[name] == nil then map[name] = false end
	end
end

ensureMap(Settings.Zones, DATA.Zones)
ensureMap(Settings.Rocks, DATA.Rocks)
ensureMap(Settings.Ores,  DATA.Ores)

-- ========= OPTIONAL: START CORE ON DEMAND =========
local coreStarted = false
local function ensureCoreStarted()
	if coreStarted then return end
	if not (ForgeCoreMS and ForgeCoreMS:IsA("ModuleScript")) then
		coreStarted = true -- mark to avoid re-tries spam
		return
	end

	local ok, core = pcall(require, ForgeCoreMS)
	if ok and type(core) == "table" and type(core.Start) == "function" then
		coreStarted = true
		task.spawn(function()
			pcall(function()
				core.Start(Settings, DATA)
			end)
		end)
	else
		coreStarted = true
	end
end

-- ========= UI FLAGS =========
local isMobile = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled)

local function clamp(x,a,b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function roundStep(x, step)
	step = step or 1
	return math.floor((x / step) + 0.5) * step
end

-- ========= THEME =========
local WHITE = Color3.fromRGB(255,255,255)
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

	InputBg = Color3.fromRGB(18, 18, 18),
}

local FONT_MULT = isMobile and 2.2 or 2
local function FS(n) return math.floor(n * FONT_MULT + 0.5) end

-- ========= CONNECTION MANAGER =========
local running = true
local globalCons = {}
local tabCons = {}

local function track(scope, conn)
	table.insert(scope, conn)
	return conn
end

local function disconnectAll(scope)
	for _, c in ipairs(scope) do
		if c and c.Connected then c:Disconnect() end
	end
	table.clear(scope)
end

-- ========= UI HELPERS =========
local function uiCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function mkStroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.Accent
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

local function mkLabel(parent, text, baseSize, bold)
	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1
	lb.Text = text or ""
	lb.TextColor3 = THEME.Text
	lb.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lb.TextSize = FS(baseSize or 14)
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.TextYAlignment = Enum.TextYAlignment.Center
	lb.TextWrapped = true
	lb.Parent = parent
	return lb
end

local function mkButton(parent, text, baseSize)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = text or ""
	b.TextColor3 = THEME.Text
	b.Font = Enum.Font.GothamBold
	b.TextSize = FS(baseSize or 14)
	b.BackgroundColor3 = THEME.Button
	b.BorderSizePixel = 0
	b.Parent = parent
	return b
end

local function hover(btn, normal, over)
	track(globalCons, btn.MouseEnter:Connect(function()
		if running then btn.BackgroundColor3 = over end
	end))
	track(globalCons, btn.MouseLeave:Connect(function()
		if running then btn.BackgroundColor3 = normal end
	end))
end

-- ========= DESTROY PREVIOUS GUI =========
local GUI_NAME = "ForgeUI_Compat"
local old = playerGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

-- ========= BUILD GUI ROOT =========
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Responsive UIScale (event-based)
local UIScale = Instance.new("UIScale")
UIScale.Parent = gui

local function computeScale()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280,720)
	local sx = v.X / 1100
	local sy = v.Y / 760
	local s = math.min(sx, sy)
	if isMobile then s = s * 1.08 end
	return clamp(s, 0.78, 1.18)
end

local function refreshScale()
	if not running then return end
	UIScale.Scale = computeScale()
end

do
	local camConn = nil
	local function bindCamera(cam)
		if camConn then camConn:Disconnect() camConn = nil end
		refreshScale()
		if not cam then return end
		camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if running then refreshScale() end
		end)
		track(globalCons, camConn)
	end
	bindCamera(workspace.CurrentCamera)
	track(globalCons, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindCamera(workspace.CurrentCamera)
	end))
end

-- Floating restore button
local FloatBtn = mkButton(gui, "Forge", 16)
FloatBtn.Size = isMobile and UDim2.fromOffset(160, 64) or UDim2.fromOffset(140, 56)
FloatBtn.AnchorPoint = Vector2.new(1, 1)
FloatBtn.Position = UDim2.new(1, -20, 1, -20)
FloatBtn.BackgroundColor3 = THEME.ButtonActive
FloatBtn.Visible = false
FloatBtn.ZIndex = 1000
uiCorner(FloatBtn, 14)
mkStroke(FloatBtn, 2)

-- Main window
local TITLE_H = 120
local TAB_W = isMobile and 280 or 240
local BTN_W = (isMobile and 96 or 90)

local MainFrame = Instance.new("Frame")
MainFrame.BackgroundColor3 = THEME.MainBg
MainFrame.BorderSizePixel = 0
MainFrame.Size = isMobile and UDim2.fromOffset(980, 1180) or UDim2.fromOffset(980, 740)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Parent = gui
uiCorner(MainFrame, 18)
mkStroke(MainFrame, 2)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = THEME.TitleBg
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
TitleBar.Active = true
uiCorner(TitleBar, 18)
mkStroke(TitleBar, 1, THEME.Accent)

local titleText = usingModules and "The Forge (Core+Settings)" or "The Forge (UI Only)"
local TitleLabel = mkLabel(TitleBar, ("Forge UI - %s"):format(titleText), 18, true)
TitleLabel.Size = UDim2.new(1, -(BTN_W * 3 + 70), 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.Active = true

local DragBtn = mkButton(TitleBar, "DRAG", 16)
DragBtn.Size = UDim2.fromOffset(BTN_W, TITLE_H)
DragBtn.Position = UDim2.new(1, -(BTN_W * 3), 0, 0)
DragBtn.BackgroundColor3 = Color3.fromRGB(35, 20, 20)
uiCorner(DragBtn, 8)

local MinimizeBtn = mkButton(TitleBar, "−", 18)
MinimizeBtn.Size = UDim2.fromOffset(BTN_W, TITLE_H)
MinimizeBtn.Position = UDim2.new(1, -(BTN_W * 2), 0, 0)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
uiCorner(MinimizeBtn, 8)

local CloseBtn = mkButton(TitleBar, "×", 22)
CloseBtn.Size = UDim2.fromOffset(BTN_W, TITLE_H)
CloseBtn.Position = UDim2.new(1, -(BTN_W * 1), 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
uiCorner(CloseBtn, 8)

hover(DragBtn, DragBtn.BackgroundColor3, THEME.ButtonHover)
hover(MinimizeBtn, MinimizeBtn.BackgroundColor3, THEME.ButtonHover)
hover(CloseBtn, CloseBtn.BackgroundColor3, THEME.ButtonHover)

-- Body split
local Body = Instance.new("Frame")
Body.BackgroundTransparency = 1
Body.Size = UDim2.new(1, 0, 1, -TITLE_H)
Body.Position = UDim2.new(0, 0, 0, TITLE_H)
Body.Parent = MainFrame

local TabFrame = Instance.new("Frame")
TabFrame.BackgroundColor3 = THEME.PanelBg
TabFrame.BorderSizePixel = 0
TabFrame.Size = UDim2.new(0, TAB_W, 1, 0)
TabFrame.Parent = Body
uiCorner(TabFrame, 16)
mkStroke(TabFrame, 1, THEME.Accent)

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
ContentFrame.BackgroundColor3 = THEME.ContentBg
ContentFrame.BorderSizePixel = 0
ContentFrame.Size = UDim2.new(1, -TAB_W, 1, 0)
ContentFrame.Position = UDim2.new(0, TAB_W, 0, 0)
ContentFrame.Parent = Body
uiCorner(ContentFrame, 16)
mkStroke(ContentFrame, 1, THEME.Accent)

local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.BackgroundTransparency = 1
ContentScroll.BorderSizePixel = 0
ContentScroll.Size = UDim2.new(1, 0, 1, 0)
ContentScroll.ScrollBarThickness = isMobile and 14 or 10
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

-- ========= MINIMIZE / CLOSE / HOTKEY =========
local function setHidden(hidden)
	MainFrame.Visible = not hidden
	FloatBtn.Visible = hidden
end

track(globalCons, MinimizeBtn.Activated:Connect(function()
	if not running then return end
	setHidden(MainFrame.Visible == true)
end))

track(globalCons, FloatBtn.Activated:Connect(function()
	if not running then return end
	setHidden(false)
end))

local function stopUI()
	if not running then return end
	running = false

	-- Safety: turn off AutoFarm (core loop will idle)
	if type(Settings) == "table" then
		Settings.AutoFarm = false
	end

	disconnectAll(tabCons)
	disconnectAll(globalCons)
	if gui and gui.Parent then gui:Destroy() end
end

track(globalCons, CloseBtn.Activated:Connect(stopUI))

track(globalCons, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not running then return end
	if input.KeyCode == Enum.KeyCode.L then
		setHidden(MainFrame.Visible == true)
	end
end))

-- ========= DRAG via DRAG button only =========
do
	MainFrame.Active = true
	TitleBar.Active = true

	local dragging = false
	local dragStartPos, frameStartPos, dragInput

	local function updateDrag(input)
		if not dragging then return end
		local delta = input.Position - dragStartPos
		MainFrame.Position = UDim2.new(
			frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X,
			frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y
		)
	end

	track(globalCons, DragBtn.InputBegan:Connect(function(input)
		if not running then return end
		if UserInputService:GetFocusedTextBox() then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStartPos = input.Position
			frameStartPos = MainFrame.Position
			dragInput = input
		end
	end))

	track(globalCons, UserInputService.InputChanged:Connect(function(input)
		if not running then return end
		if input == dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateDrag(input)
		end
	end))

	track(globalCons, UserInputService.InputEnded:Connect(function(input)
		if input == dragInput then
			dragging = false
			dragInput = nil
		end
	end))
end

-- ========= CONTENT BUILDERS =========
local function clearContent()
	disconnectAll(tabCons)
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
	btn.Size = UDim2.new(1, 0, 0, isMobile and 130 or 110)
	btn.BackgroundColor3 = THEME.Button
	uiCorner(btn, 10)
	hover(btn, THEME.Button, THEME.ButtonHover)
	return btn
end

local selectedTabBtn
local function setTabSelected(btn)
	if selectedTabBtn and selectedTabBtn.Parent then
		selectedTabBtn.BackgroundColor3 = THEME.Button
	end
	selectedTabBtn = btn
	btn.BackgroundColor3 = THEME.ButtonActive
end

local function createCheckboxRow(parent, text, initial, onChanged)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, isMobile and 110 or 100)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local box = Instance.new("TextButton")
	box.Size = UDim2.fromOffset(isMobile and 58 or 50, isMobile and 58 or 50)
	box.Position = UDim2.new(0, 12, 0.5, -(isMobile and 29 or 25))
	box.Text = ""
	box.AutoButtonColor = false
	box.BackgroundColor3 = initial and THEME.BoxOn or THEME.BoxOff
	box.Parent = row
	uiCorner(box, 10)

	local lb = mkLabel(row, text, 14, true)
	lb.Size = UDim2.new(1, -110, 1, 0)
	lb.Position = UDim2.new(0, isMobile and 92 or 80, 0, 0)

	local state = initial and true or false
	local function repaint()
		box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
	end

	track(tabCons, box.Activated:Connect(function()
		if not running then return end
		state = not state
		repaint()
		if onChanged then onChanged(state) end
	end))
end

local function createSlider(parent, title, minV, maxV, initial, step, onChanged)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, isMobile and 190 or 170)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	step = step or 1
	local value = clamp(tonumber(initial) or minV, minV, maxV)
	value = clamp(roundStep(value, step), minV, maxV)

	local function fmt(v)
		if step < 1 then return string.format("%.1f", v) end
		return tostring(math.floor(v + 0.5))
	end

	local titleLb = mkLabel(holder, title .. ":", 14, true)
	titleLb.Size = UDim2.new(1, 0, 0, isMobile and 46 or 40)
	titleLb.Position = UDim2.new(0, 0, 0, 0)

	local valueLb = mkLabel(holder, fmt(value), 14, true)
	valueLb.TextXAlignment = Enum.TextXAlignment.Right
	valueLb.Size = UDim2.new(1, 0, 0, isMobile and 46 or 40)
	valueLb.Position = UDim2.new(0, 0, 0, 0)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, isMobile and 52 or 44)
	bar.Position = UDim2.new(0, 0, 0, isMobile and 64 or 56)
	bar.BackgroundColor3 = THEME.Holder
	bar.BorderSizePixel = 0
	bar.Parent = holder
	uiCorner(bar, 12)
	mkStroke(bar, 1, THEME.Accent)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((value - minV) / (maxV - minV), 0, 1, 0)
	fill.BackgroundColor3 = THEME.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	uiCorner(fill, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(isMobile and 52 or 44, isMobile and 52 or 44)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new((value - minV) / (maxV - minV), 0, 0.5, 0)
	knob.BackgroundColor3 = THEME.ButtonActive
	knob.BorderSizePixel = 0
	knob.Parent = bar
	uiCorner(knob, 18)
	mkStroke(knob, 2, THEME.Accent)

	local function setValue(v)
		v = clamp(roundStep(v, step), minV, maxV)
		value = v
		valueLb.Text = fmt(value)

		local a = (value - minV) / (maxV - minV)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)

		if onChanged then onChanged(value) end
	end

	local dragging = false
	local function updateByX(x)
		local absPos = bar.AbsolutePosition.X
		local absSize = bar.AbsoluteSize.X
		local a = clamp((x - absPos) / absSize, 0, 1)
		local v = minV + (maxV - minV) * a
		setValue(v)
	end

	track(tabCons, bar.InputBegan:Connect(function(input)
		if not running then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateByX(input.Position.X)
		end
	end))

	track(tabCons, bar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	track(tabCons, UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			updateByX(input.Position.X)
		end
	end))
end

local function createDrawerSection(title, items, mapTable)
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
	header.Size = UDim2.new(1, 0, 0, isMobile and 120 or 110)
	header.BackgroundColor3 = THEME.Header
	uiCorner(header, 12)
	mkStroke(header, 1, THEME.Accent)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, 0, 0, 0)
	content.ClipsDescendants = true
	content.BackgroundTransparency = 1
	content.Parent = section

	local innerPad = Instance.new("UIPadding")
	innerPad.PaddingTop = UDim.new(0, 14)
	innerPad.PaddingLeft = UDim.new(0, 14)
	innerPad.PaddingRight = UDim.new(0, 14)
	innerPad.PaddingBottom = UDim.new(0, 14)
	innerPad.Parent = content

	local innerLayout = Instance.new("UIListLayout")
	innerLayout.FillDirection = Enum.FillDirection.Vertical
	innerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	innerLayout.Padding = UDim.new(0, 12)
	innerLayout.Parent = content

	local controls = Instance.new("Frame")
	controls.Size = UDim2.new(1, 0, 0, isMobile and 64 or 56)
	controls.BackgroundTransparency = 1
	controls.Parent = content

	local ctrlLayout = Instance.new("UIListLayout")
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ctrlLayout.Padding = UDim.new(0, 12)
	ctrlLayout.Parent = controls

	local btnSelectAll = mkButton(controls, "Select All", 14)
	btnSelectAll.Size = UDim2.new(0, isMobile and 260 or 220, 1, 0)
	btnSelectAll.BackgroundColor3 = THEME.ButtonActive
	uiCorner(btnSelectAll, 10)
	mkStroke(btnSelectAll, 1, THEME.Accent)

	local btnClearAll = mkButton(controls, "Clear All", 14)
	btnClearAll.Size = UDim2.new(0, isMobile and 260 or 220, 1, 0)
	btnClearAll.BackgroundColor3 = THEME.Button
	uiCorner(btnClearAll, 10)
	mkStroke(btnClearAll, 1, THEME.Accent)

	local search = Instance.new("TextBox")
	search.Size = UDim2.new(1, 0, 0, isMobile and 58 or 52)
	search.BackgroundColor3 = THEME.InputBg
	search.BorderSizePixel = 0
	search.PlaceholderText = "Search..."
	search.ClearTextOnFocus = false
	search.Text = ""
	search.TextColor3 = THEME.Text
	search.PlaceholderColor3 = Color3.fromRGB(160, 160, 160)
	search.Font = Enum.Font.Gotham
	search.TextSize = FS(14)
	search.Parent = content
	uiCorner(search, 10)
	mkStroke(search, 1, THEME.Accent)

	local listHeight = isMobile and 520 or 360

	local listScroll = Instance.new("ScrollingFrame")
	listScroll.Size = UDim2.new(1, 0, 0, listHeight)
	listScroll.BackgroundColor3 = THEME.Holder
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = isMobile and 12 or 9
	listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	listScroll.Parent = content
	uiCorner(listScroll, 12)
	mkStroke(listScroll, 1, THEME.Accent)

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 12)
	listPad.PaddingBottom = UDim.new(0, 12)
	listPad.PaddingLeft = UDim.new(0, 12)
	listPad.PaddingRight = UDim.new(0, 12)
	listPad.Parent = listScroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = listScroll

	local rows = {}
	for _, name in ipairs(items) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, isMobile and 100 or 90)
		row.BackgroundTransparency = 1
		row.Parent = listScroll

		local box = Instance.new("TextButton")
		box.Size = UDim2.fromOffset(isMobile and 52 or 46, isMobile and 52 or 46)
		box.Position = UDim2.new(0, 0, 0.5, -(isMobile and 26 or 23))
		box.Text = ""
		box.AutoButtonColor = false
		box.BackgroundColor3 = THEME.BoxOff
		box.Parent = row
		uiCorner(box, 10)

		local lb = mkLabel(row, name, 14, true)
		lb.Size = UDim2.new(1, -70, 1, 0)
		lb.Position = UDim2.new(0, isMobile and 70 or 62, 0, 0)

		local nameLower = name:lower()
		local state = (mapTable[name] == true)

		local function repaint()
			box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
		end

		local function setState(v)
			state = (v == true)
			mapTable[name] = state
			repaint()
		end

		repaint()

		track(tabCons, box.Activated:Connect(function()
			if not running then return end
			setState(not state)
		end))

		rows[#rows+1] = { nameLower = nameLower, row = row, setState = setState }
	end

	local function applyFilter()
		local q = (search.Text or ""):lower()
		if q == "" then
			for _, r in ipairs(rows) do r.row.Visible = true end
		else
			for _, r in ipairs(rows) do
				r.row.Visible = (string.find(r.nameLower, q, 1, true) ~= nil)
			end
		end
	end

	-- debounce filter
	local token = 0
	local function applyFilterDebounced()
		token += 1
		local my = token
		task.delay(0.08, function()
			if not running or my ~= token then return end
			applyFilter()
		end)
	end
	track(tabCons, search:GetPropertyChangedSignal("Text"):Connect(applyFilterDebounced))

	track(tabCons, btnSelectAll.Activated:Connect(function()
		for _, r in ipairs(rows) do r.setState(true) end
		applyFilter()
	end))
	track(tabCons, btnClearAll.Activated:Connect(function()
		for _, r in ipairs(rows) do r.setState(false) end
		applyFilter()
	end))

	-- expand/collapse (cancel tween if spam-click)
	local expanded = false
	local expandedHeight = 14 + 14 + (isMobile and 58 or 52) + (isMobile and 58 or 52) + listHeight + 80
	local activeTween = nil

	local function setExpanded(on)
		expanded = on
		header.Text = (expanded and "▼ " or "► ") .. title

		if activeTween then
			activeTween:Cancel()
			activeTween = nil
		end

		activeTween = TweenService:Create(content, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, expanded and expandedHeight or 0)
		})
		activeTween:Play()

		if expanded then applyFilter() end
	end

	track(tabCons, header.Activated:Connect(function()
		setExpanded(not expanded)
	end))
end

-- ========= TABS =========
local miningBtn = createTabButton("Mining")
local settingBtn = createTabButton("Setting")

local function buildMining()
	clearContent()

	createCheckboxRow(ContentScroll, "Auto Farm", Settings.AutoFarm == true, function(v)
		Settings.AutoFarm = (v == true)
		if Settings.AutoFarm then
			-- start core only if available; harmless if absent
			ensureCoreStarted()
		end
	end)

	createDrawerSection("Zones", DATA.Zones, Settings.Zones)
	createDrawerSection("Rocks", DATA.Rocks, Settings.Rocks)
	createDrawerSection("Ores",  DATA.Ores,  Settings.Ores)
end

local function buildSetting()
	clearContent()

	createSlider(ContentScroll, "TweenSpeed", 20, 80, Settings.TweenSpeed or 55, 1, function(v)
		Settings.TweenSpeed = v
	end)

	createSlider(ContentScroll, "YOffset", -7, 7, Settings.YOffset or 3, 0.5, function(v)
		Settings.YOffset = v
	end)

	-- Info panel (optional, small)
	local info = Instance.new("Frame")
	info.Size = UDim2.new(1, 0, 0, isMobile and 120 or 100)
	info.BackgroundColor3 = THEME.Holder
	info.BorderSizePixel = 0
	info.Parent = ContentScroll
	uiCorner(info, 12)
	mkStroke(info, 1, THEME.Accent)

	local msg = usingModules
		and "Mode: Core+Settings (ReplicatedStorage)\nHotkey: L | Minimize: − | Close: ×"
		or "Mode: UI-only fallback (modules not found)\nHotkey: L | Minimize: − | Close: ×"

	local lb = mkLabel(info, msg, 13, true)
	lb.Size = UDim2.new(1, -24, 1, -24)
	lb.Position = UDim2.new(0, 12, 0, 12)
end

-- Tab events must be GLOBAL (so they don't die after clearContent)
track(globalCons, miningBtn.Activated:Connect(function()
	setTabSelected(miningBtn)
	buildMining()
end))
track(globalCons, settingBtn.Activated:Connect(function()
	setTabSelected(settingBtn)
	buildSetting()
end))

setTabSelected(miningBtn)
buildMining()

print(("[ForgeUI] Ready. Modules=%s | Press L to toggle."):format(tostring(usingModules)))
