-- lprxsw - Old Style GUI (Mobile + PC optimized)
-- NOTE: UI only (no gameplay automation)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========= State (UI only) =========
local UIState = {
	AutoMining = false,
	TweenSpeed = 55, -- 20..80
	YOffset = 3,     -- -7..7
	Zones = {},
	Rocks = {},
	Ores  = {},
	Data = {
		Zones = {"ZoneA","ZoneB","ZoneC"},
		Rocks = {"RockA","RockB","RockC"},
		Ores  = {"OreA","OreB","OreC"},
	}
}

-- If you have your own data table, assign it here:
-- UIState.Data = { Zones = {...}, Rocks = {...}, Ores = {...} }

-- ========= Utils =========
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

local function ensureMap(map, list)
	for _, name in ipairs(list) do
		if map[name] == nil then map[name] = false end
	end
end

ensureMap(UIState.Zones, UIState.Data.Zones)
ensureMap(UIState.Rocks, UIState.Data.Rocks)
ensureMap(UIState.Ores,  UIState.Data.Ores)

-- ========= Theme (old style red/dark) =========
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

-- ========= Connection manager =========
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

-- ========= UI helpers =========
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

local function hover(btn, normal, over)
	track(globalCons, btn.MouseEnter:Connect(function()
		if not running then return end
		btn.BackgroundColor3 = over
	end))
	track(globalCons, btn.MouseLeave:Connect(function()
		if not running then return end
		btn.BackgroundColor3 = normal
	end))
end

-- ========= Root GUI =========
local old = playerGui:FindFirstChild("lprxsw_OldStyle_GUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "lprxsw_OldStyle_GUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- UIScale responsive
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

refreshScale()
track(globalCons, RunService.Heartbeat:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	if gui:GetAttribute("vpX") ~= vp.X or gui:GetAttribute("vpY") ~= vp.Y then
		gui:SetAttribute("vpX", vp.X)
		gui:SetAttribute("vpY", vp.Y)
		refreshScale()
	end
end))

-- Floating restore button (used on minimize/hide)
local FloatBtn = mkButton(gui, "Forge", 16)
FloatBtn.Size = isMobile and UDim2.fromOffset(160, 64) or UDim2.fromOffset(140, 56)
FloatBtn.AnchorPoint = Vector2.new(1, 1)
FloatBtn.Position = UDim2.new(1, -20, 1, -20)
FloatBtn.BackgroundColor3 = THEME.ButtonActive
FloatBtn.Visible = false
FloatBtn.ZIndex = 1000
uiCorner(FloatBtn, 14)
mkStroke(FloatBtn, 2)

-- Main window sizing
local TITLE_H = 120
local TAB_W = isMobile and 280 or 240

local MainFrame = Instance.new("Frame")
MainFrame.BackgroundColor3 = THEME.MainBg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = gui
uiCorner(MainFrame, 10)
mkStroke(MainFrame, 2, THEME.Accent)

if isMobile then
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.Size = UDim2.new(0.96, 0, 0.92, 0)
else
	local MAIN_W, MAIN_H = 980, 680
	MainFrame.Size = UDim2.fromOffset(MAIN_W, MAIN_H)
	MainFrame.Position = UDim2.new(0.5, -MAIN_W/2, 0.5, -MAIN_H/2)
end

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = THEME.TitleBg
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
TitleBar.Active = true

local TitleLabel = mkLabel(TitleBar, "lprxsw - The Forge (UI)", 20, true)
TitleLabel.Size = UDim2.new(1, -360, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.Active = true

-- Buttons: Drag | Minimize | Close(X stop UI)
local BTN_W = (isMobile and 96 or 90)

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

TitleLabel.Size = UDim2.new(1, -(BTN_W * 3 + 70), 1, 0)

hover(DragBtn, DragBtn.BackgroundColor3, THEME.ButtonHover)
hover(MinimizeBtn, MinimizeBtn.BackgroundColor3, THEME.ButtonHover)
hover(CloseBtn, CloseBtn.BackgroundColor3, Color3.fromRGB(200, 30, 30))

-- Panels
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

-- ========= Behavior: Minimize = Hide / Close = Stop UI =========
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
	disconnectAll(tabCons)
	disconnectAll(globalCons)
	if gui and gui.Parent then gui:Destroy() end
end

track(globalCons, CloseBtn.Activated:Connect(function()
	stopUI()
end))

-- Hotkey L = hide/show
track(globalCons, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not running then return end
	if input.KeyCode == Enum.KeyCode.L then
		setHidden(MainFrame.Visible == true)
	end
end))

-- ========= DRAG: ONLY via DragBtn =========
do
	MainFrame.Active = true
	TitleBar.Active = true
	DragBtn.Active = true

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
			dragInput = input
			dragStartPos = input.Position
			frameStartPos = MainFrame.Position
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

-- ========= Content Builders =========
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
		onChanged(state)
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

	local label = mkLabel(holder, title .. ": " .. fmt(value), 14, false)
	label.Size = UDim2.new(1, 0, 0, isMobile and 82 or 70)
	label.Position = UDim2.new(0, 10, 0, 0)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -20, 0, isMobile and 20 or 18)
	bar.Position = UDim2.new(0, 10, 0, isMobile and 110 or 92)
	bar.BackgroundColor3 = THEME.TitleBg
	bar.BorderSizePixel = 0
	bar.Parent = holder
	bar.Active = true
	uiCorner(bar, 10)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(isMobile and 38 or 32, isMobile and 52 or 46)
	knob.BackgroundColor3 = THEME.Accent
	knob.BorderSizePixel = 0
	knob.Parent = bar
	uiCorner(knob, 12)

	local function setValueFromRel(rel)
		rel = clamp(rel, 0, 1)
		local raw = minV + (maxV - minV) * rel
		value = clamp(roundStep(raw, step), minV, maxV)
		local rel2 = (value - minV) / (maxV - minV)
		knob.Position = UDim2.new(rel2, -(knob.Size.X.Offset/2), 0.5, -(knob.Size.Y.Offset/2))
		label.Text = title .. ": " .. fmt(value)
		onChanged(value)
	end

	setValueFromRel((value - minV) / (maxV - minV))

	local dragging = false
	local function updateByX(x)
		local rel = (x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
		setValueFromRel(rel)
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
	uiCorner(header, 10)
	hover(header, THEME.Header, THEME.ButtonHover)

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
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = content

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 10)
	contentLayout.Parent = content

	local controls = Instance.new("Frame")
	controls.Size = UDim2.new(1, 0, 0, isMobile and 58 or 52)
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
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = isMobile and 14 or 10
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	listScroll.Parent = content

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = listScroll

	local rows = {}
	for _, nameAny in ipairs(items) do
		local name = tostring(nameAny)
		if mapTable[name] == nil then mapTable[name] = false end

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, isMobile and 84 or 72)
		row.BackgroundTransparency = 1
		row.Parent = listScroll

		local box = Instance.new("TextButton")
		box.Size = UDim2.fromOffset(isMobile and 62 or 50, isMobile and 62 or 50)
		box.Position = UDim2.new(0, 8, 0.5, -(isMobile and 31 or 25))
		box.Text = ""
		box.AutoButtonColor = false
		box.Parent = row
		uiCorner(box, 10)

		local label = mkLabel(row, name, 16, false)
		label.Size = UDim2.new(1, -110, 1, 0)
		label.Position = UDim2.new(0, isMobile and 104 or 80, 0, 0)

		local state = mapTable[name] == true
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

		rows[#rows+1] = { nameLower = name:lower(), row = row, setState = setState }
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

	track(tabCons, search:GetPropertyChangedSignal("Text"):Connect(applyFilter))
	track(tabCons, btnSelectAll.Activated:Connect(function()
		for _, r in ipairs(rows) do r.setState(true) end
		applyFilter()
	end))
	track(tabCons, btnClearAll.Activated:Connect(function()
		for _, r in ipairs(rows) do r.setState(false) end
		applyFilter()
	end))

	local expanded = false
	local expandedHeight = 14 + 14 + (isMobile and 58 or 52) + (isMobile and 58 or 52) + listHeight + 80
	local function setExpanded(on)
		expanded = on
		header.Text = (expanded and "▼ " or "► ") .. title
		TweenService:Create(content, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, expanded and expandedHeight or 0)
		}):Play()
		if expanded then applyFilter() end
	end

	track(tabCons, header.Activated:Connect(function()
		setExpanded(not expanded)
	end))
end

-- ========= Tabs =========
local miningBtn = createTabButton("Mining")
local settingBtn = createTabButton("Setting")

local function buildMining()
	clearContent()
	createCheckboxRow(ContentScroll, "Auto Mining", UIState.AutoMining, function(v)
		UIState.AutoMining = v
	end)
	createDrawerSection(("Zones (%d)"):format(#UIState.Data.Zones), UIState.Data.Zones, UIState.Zones)
	createDrawerSection(("Rocks (%d)"):format(#UIState.Data.Rocks), UIState.Data.Rocks, UIState.Rocks)
	createDrawerSection(("Ores (%d)"):format(#UIState.Data.Ores), UIState.Data.Ores, UIState.Ores)
end

local function buildSetting()
	clearContent()
	createSlider(ContentScroll, "TweenSpeed", 20, 80, UIState.TweenSpeed, 1, function(v)
		UIState.TweenSpeed = clamp(tonumber(v) or 55, 20, 80)
	end)
	createSlider(ContentScroll, "YOffset", -7, 7, UIState.YOffset, 0.5, function(v)
		v = clamp(tonumber(v) or 3, -7, 7)
		UIState.YOffset = roundStep(v, 0.5)
	end)
end

track(tabCons, miningBtn.Activated:Connect(function()
	setTabSelected(miningBtn)
	buildMining()
end))
track(tabCons, settingBtn.Activated:Connect(function()
	setTabSelected(settingBtn)
	buildSetting()
end))

setTabSelected(miningBtn)
buildMining()

print("[lprxsw] Old style GUI ready. Drag via DRAG button. L = hide/show. X = stop UI.")
