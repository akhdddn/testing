--// Forge GUI (Gaya Lama + Update Request) - lprxsw
--// PC + Mobile Optimized
--// Requires: ForgeSettings.ApplyToGlobals() sudah jalan -> _G.DATA + _G.Settings tersedia

-- ========= Services =========
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========= Wait Globals =========
local function waitForGlobals(timeoutSec)
	local t0 = os.clock()
	while os.clock() - t0 < (timeoutSec or 10) do
		if _G.DATA and _G.Settings then
			return _G.DATA, _G.Settings
		end
		task.wait(0.1)
	end
	return nil, nil
end

local DATA, Settings = waitForGlobals(10)
if not DATA or not Settings then
	warn("[ForgeGUI lprxsw] _G.DATA / _G.Settings not found (timeout). GUI aborted.")
	return
end

-- Ensure branches exist (GUI compatibility)
local function ensureBranch(root, key)
	root[key] = root[key] or {}
	return root[key]
end
ensureBranch(Settings, "Zones")
ensureBranch(Settings, "Rocks")
ensureBranch(Settings, "Ores")
ensureBranch(_G.Settings, "Zones")
ensureBranch(_G.Settings, "Rocks")
ensureBranch(_G.Settings, "Ores")

-- ========= Platform / Sizing =========
local isTouch = UserInputService.TouchEnabled
local isMobile = isTouch and not UserInputService.KeyboardEnabled
local isSmallScreen = false

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

-- ========= Connection manager =========
local running = true
local globalConnections = {}
local tabConnections = {}

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

-- ========= Settings sync helpers =========
local function setSetting(key, value)
	Settings[key] = value
	_G.Settings[key] = value
end

local function setBranchSetting(branchKey, name, value)
	Settings[branchKey] = Settings[branchKey] or {}
	_G.Settings[branchKey] = _G.Settings[branchKey] or {}
	Settings[branchKey][name] = value
	_G.Settings[branchKey][name] = value
end

local function getSetting(key, fallback)
	local v = Settings[key]
	if v == nil then return fallback end
	return v
end

-- ========= Theme (gaya lama) =========
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
	Stroke = Color3.fromRGB(220, 60, 60),
}

-- ========= UI Helpers =========
local function uiCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function mkStroke(parent, thickness)
	local s = Instance.new("UIStroke")
	s.Color = THEME.Stroke
	s.Thickness = thickness or 2
	s.Parent = parent
	return s
end

local function mkLabel(parent, text, size, bold)
	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1
	lb.Text = text
	lb.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	lb.TextSize = size
	lb.TextColor3 = THEME.Text
	lb.TextWrapped = true
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.Parent = parent
	return lb
end

local function mkButton(parent, text, size)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = size
	b.TextColor3 = THEME.Text
	b.TextWrapped = true
	b.BackgroundColor3 = THEME.Button
	b.Parent = parent
	return b
end

local function hover(btn, normal, over)
	track(globalConnections, btn.MouseEnter:Connect(function()
		if not running then return end
		btn.BackgroundColor3 = over
	end))
	track(globalConnections, btn.MouseLeave:Connect(function()
		if not running then return end
		btn.BackgroundColor3 = normal
	end))
end

-- ========= Root GUI =========
local gui = Instance.new("ScreenGui")
gui.Name = "Forge_GUI_Separated_lprxsw"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- ========= Responsive Scale =========
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui

local function computeScale()
	local cam = workspace.CurrentCamera
	local vps = cam and cam.ViewportSize or Vector2.new(1280, 720)
	isSmallScreen = (vps.X < 900 or vps.Y < 600)

	local sx = vps.X / 1100
	local sy = vps.Y / 760
	local s = math.min(sx, sy)
	if isMobile then s = s * 1.08 end
	return clamp(s, 0.78, 1.15)
end

local function refreshScale()
	if not running then return end
	uiScale.Scale = computeScale()
end

refreshScale()
track(globalConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refreshScale))
track(globalConnections, RunService.Heartbeat:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	if (gui:GetAttribute("LastVPX") ~= v.X) or (gui:GetAttribute("LastVPY") ~= v.Y) then
		gui:SetAttribute("LastVPX", v.X)
		gui:SetAttribute("LastVPY", v.Y)
		refreshScale()
	end
end))

-- ========= Floating Toggle Button (mobile-friendly) =========
local FloatBtn = mkButton(gui, "Forge", isMobile and 18 or 16)
FloatBtn.Size = isMobile and UDim2.fromOffset(140, 56) or UDim2.fromOffset(120, 46)
FloatBtn.AnchorPoint = Vector2.new(1, 1)
FloatBtn.Position = UDim2.new(1, -20, 1, -20)
FloatBtn.BackgroundColor3 = THEME.ButtonActive
FloatBtn.ZIndex = 1000
uiCorner(FloatBtn, 12)
mkStroke(FloatBtn, 2)

-- ========= Main Window =========
local MAIN_W, MAIN_H = 980, 680
local TITLE_H = 92
local TAB_W = 240

if isMobile or isSmallScreen then
	MAIN_W, MAIN_H = 900, 640
	TITLE_H = 92
	TAB_W = 250
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.fromOffset(MAIN_W, MAIN_H)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = THEME.MainBg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
MainFrame.Parent = gui
uiCorner(MainFrame, 12)
mkStroke(MainFrame, 2)

-- ========= Title Bar =========
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = THEME.TitleBg
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleLabel = mkLabel(TitleBar, "Forge UI (lprxsw)", isMobile and 20 or 18, true)
TitleLabel.Size = UDim2.new(1, -240, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)

local MinBtn = mkButton(TitleBar, "−", isMobile and 20 or 18)
MinBtn.Size = UDim2.fromOffset(76, TITLE_H)
MinBtn.Position = UDim2.new(1, -152, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
uiCorner(MinBtn, 10)

local CloseBtn = mkButton(TitleBar, "×", isMobile and 24 or 22)
CloseBtn.Size = UDim2.fromOffset(76, TITLE_H)
CloseBtn.Position = UDim2.new(1, -76, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 20, 20)
uiCorner(CloseBtn, 10)

hover(MinBtn, MinBtn.BackgroundColor3, THEME.ButtonHover)
hover(CloseBtn, CloseBtn.BackgroundColor3, Color3.fromRGB(200, 30, 30))

-- ========= Dragging (mouse + touch) =========
do
	local DRAG_W = 500
	local DragHandle = Instance.new("TextButton")
	DragHandle.BackgroundTransparency = 1
	DragHandle.Text = ""
	DragHandle.AutoButtonColor = false
	DragHandle.Size = UDim2.new(0, DRAG_W, 1, 0)
	DragHandle.Position = UDim2.new(0, 0, 0, 0)
	DragHandle.ZIndex = 50
	DragHandle.Parent = TitleBar

	MinBtn.ZIndex = 100
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
		if not running then return end
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

-- ========= Panels =========
local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(0, TAB_W, 1, -TITLE_H)
TabFrame.Position = UDim2.new(0, 0, 0, TITLE_H)
TabFrame.BackgroundColor3 = THEME.PanelBg
TabFrame.BorderSizePixel = 0
TabFrame.Parent = MainFrame

local TabPad = Instance.new("UIPadding")
TabPad.PaddingTop = UDim.new(0, 12)
TabPad.PaddingLeft = UDim.new(0, 12)
TabPad.PaddingRight = UDim.new(0, 12)
TabPad.Parent = TabFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 10)
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
ContentScroll.ScrollBarThickness = isMobile and 12 or 10
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ContentScroll.Parent = ContentFrame

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingTop = UDim.new(0, 12)
ContentPadding.PaddingBottom = UDim.new(0, 12)
ContentPadding.PaddingLeft = UDim.new(0, 12)
ContentPadding.PaddingRight = UDim.new(0, 12)
ContentPadding.Parent = ContentScroll

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.FillDirection = Enum.FillDirection.Vertical
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 14)
ContentLayout.Parent = ContentScroll

-- ========= Minimize/Restore =========
local minimized = false
local function applyMinimizeState()
	if minimized then
		TabFrame.Visible = false
		ContentFrame.Visible = false
		MainFrame:TweenSize(UDim2.fromOffset(380, TITLE_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
		MinBtn.Text = "□"
	else
		MainFrame:TweenSize(UDim2.fromOffset(MAIN_W, MAIN_H), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.18, true)
		MinBtn.Text = "−"
		task.delay(0.18, function()
			if running and not minimized then
				TabFrame.Visible = true
				ContentFrame.Visible = true
			end
		end)
	end
end

local function toggleWindowVisible()
	if not running then return end
	MainFrame.Visible = not MainFrame.Visible
end

local function toggleMinimize()
	if not running then return end
	minimized = not minimized
	applyMinimizeState()
end

-- Close = hide window (tetap gaya lama, tapi tidak mematikan loop)
local function closeWindow()
	if not running then return end
	if minimized then
		minimized = false
		applyMinimizeState()
	end
	MainFrame.Visible = false
end

track(globalConnections, CloseBtn.Activated:Connect(closeWindow))
track(globalConnections, MinBtn.Activated:Connect(toggleMinimize))
track(globalConnections, FloatBtn.Activated:Connect(function()
	if not running then return end
	toggleWindowVisible()
end))

-- Hotkeys
track(globalConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not running then return end
	if input.KeyCode == Enum.KeyCode.L then
		toggleMinimize()
	end
	-- tetap nyaman untuk PC (gaya lama)
	if input.KeyCode == Enum.KeyCode.RightShift then
		toggleWindowVisible()
	end
end))

-- ========= Content builder =========
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
	local btn = mkButton(TabFrame, text, isMobile and 18 or 14)
	btn.Size = UDim2.new(1, 0, 0, isMobile and 86 or 76)
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

-- Checkbox row (toggle)
local function createCheckboxRow(parent, text, initial, onChanged)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, isMobile and 74 or 62)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local box = Instance.new("TextButton")
	box.Size = UDim2.fromOffset(isMobile and 54 or 44, isMobile and 54 or 44)
	box.Position = UDim2.new(0, 10, 0.5, -(isMobile and 27 or 22))
	box.Text = ""
	box.AutoButtonColor = false
	box.Parent = row
	uiCorner(box, 10)

	local label = mkLabel(row, text, isMobile and 16 or 14, false)
	label.Size = UDim2.new(1, -(isMobile and 70 or 60), 1, 0)
	label.Position = UDim2.new(0, (isMobile and 70 or 60), 0, 0)

	local state = initial and true or false
	local function repaint()
		box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
	end
	repaint()

	track(tabConnections, box.Activated:Connect(function()
		if not running then return end
		state = not state
		repaint()
		onChanged(state)
	end))
end

-- Slider
local function createSlider(parent, label, minV, maxV, initial, step, onChanged)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, isMobile and 92 or 80)
	holder.BackgroundColor3 = THEME.Holder
	holder.BorderSizePixel = 0
	holder.Parent = parent
	uiCorner(holder, 12)
	mkStroke(holder, 1)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = holder

	local title = mkLabel(holder, label, isMobile and 16 or 14, true)
	title.Size = UDim2.new(1, 0, 0, isMobile and 22 or 20)

	local valueLabel = mkLabel(holder, "", isMobile and 16 or 14, false)
	valueLabel.Size = UDim2.new(0, 120, 0, isMobile and 22 or 20)
	valueLabel.Position = UDim2.new(1, -120, 0, 0)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, isMobile and 16 or 14)
	bar.Position = UDim2.new(0, 0, 0, isMobile and 42 or 36)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bar.BorderSizePixel = 0
	bar.Parent = holder
	uiCorner(bar, 10)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = THEME.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	uiCorner(fill, 10)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(isMobile and 26 or 22, isMobile and 26 or 22)
	knob.BackgroundColor3 = THEME.Stroke
	knob.BorderSizePixel = 0
	knob.Parent = bar
	uiCorner(knob, 999)

	local value = clamp(tonumber(initial) or minV, minV, maxV)

	local function snap(v)
		if step and step > 0 then
			return math.floor((v / step) + 0.5) * step
		end
		return v
	end

	local function render()
		value = clamp(snap(value), minV, maxV)
		local a = (value - minV) / (maxV - minV)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -(knob.Size.X.Offset/2), 0.5, -(knob.Size.Y.Offset/2))
		valueLabel.Text = tostring(value)
	end

	local dragging = false
	local function setFromX(x)
		local ax = bar.AbsolutePosition.X
		local aw = bar.AbsoluteSize.X
		local a = clamp((x - ax) / aw, 0, 1)
		value = minV + (maxV - minV) * a
		render()
		onChanged(value)
	end

	track(tabConnections, bar.InputBegan:Connect(function(input)
		if not running then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end))
	track(tabConnections, bar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
	track(tabConnections, UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
		end
	end))

	render()
end

-- Collapsible section dengan Search + Select All + Clear All
local function createCollapsibleSection(titleText, items, branchKey)
	local section = Instance.new("Frame")
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundTransparency = 1
	section.Parent = ContentScroll

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = section

	local header = mkButton(section, "► " .. titleText, isMobile and 18 or 14)
	header.Size = UDim2.new(1, 0, 0, isMobile and 72 or 64)
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
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = content

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = content

	-- Controls row (Select All / Clear All)
	local controls = Instance.new("Frame")
	controls.Size = UDim2.new(1, 0, 0, isMobile and 44 or 38)
	controls.BackgroundTransparency = 1
	controls.Parent = content

	local ctrlLayout = Instance.new("UIListLayout")
	ctrlLayout.FillDirection = Enum.FillDirection.Horizontal
	ctrlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	ctrlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ctrlLayout.Padding = UDim.new(0, 10)
	ctrlLayout.Parent = controls

	local btnSelectAll = mkButton(controls, "Select All", isMobile and 16 or 14)
	btnSelectAll.Size = UDim2.new(0, isMobile and 160 or 130, 1, 0)
	btnSelectAll.BackgroundColor3 = THEME.ButtonActive
	uiCorner(btnSelectAll, 10)
	mkStroke(btnSelectAll, 1)

	local btnClearAll = mkButton(controls, "Clear All", isMobile and 16 or 14)
	btnClearAll.Size = UDim2.new(0, isMobile and 160 or 130, 1, 0)
	btnClearAll.BackgroundColor3 = THEME.Button
	uiCorner(btnClearAll, 10)
	mkStroke(btnClearAll, 1)

	hover(btnSelectAll, btnSelectAll.BackgroundColor3, THEME.ButtonHover)
	hover(btnClearAll, btnClearAll.BackgroundColor3, THEME.ButtonHover)

	-- Search box
	local search = Instance.new("TextBox")
	search.Size = UDim2.new(1, 0, 0, isMobile and 44 or 38)
	search.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	search.BorderSizePixel = 0
	search.PlaceholderText = "Search..."
	search.ClearTextOnFocus = false
	search.Text = ""
	search.TextColor3 = THEME.Text
	search.PlaceholderColor3 = Color3.fromRGB(160, 160, 160)
	search.Font = Enum.Font.Gotham
	search.TextSize = isMobile and 16 or 14
	search.Parent = content
	uiCorner(search, 10)
	mkStroke(search, 1)

	local rows = {} -- {name=lower, row=Frame, itemName=string, box=TextButton, setState=function}
	for _, itemNameAny in ipairs(items) do
		local itemName = tostring(itemNameAny)

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, isMobile and 56 or 48)
		row.BackgroundTransparency = 1
		row.Parent = content

		local box = Instance.new("TextButton")
		box.Size = UDim2.fromOffset(isMobile and 44 or 38, isMobile and 44 or 38)
		box.Position = UDim2.new(0, 6, 0.5, -(isMobile and 22 or 19))
		box.Text = ""
		box.AutoButtonColor = false
		box.Parent = row
		uiCorner(box, 10)

		local label = mkLabel(row, itemName, isMobile and 16 or 14, false)
		label.Size = UDim2.new(1, -(isMobile and 60 or 52), 1, 0)
		label.Position = UDim2.new(0, (isMobile and 60 or 52), 0, 0)

		local state = Settings[branchKey][itemName] and true or false
		local function repaint()
			box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
		end
		local function setState(v)
			state = (v == true)
			repaint()
			setBranchSetting(branchKey, itemName, state)
		end
		repaint()

		track(tabConnections, box.Activated:Connect(function()
			if not running then return end
			setState(not state)
		end))

		rows[#rows + 1] = { name = itemName:lower(), row = row, itemName = itemName, setState = setState }
	end

	local function applyFilter()
		local q = (search.Text or ""):lower()
		if q == "" then
			for _, r in ipairs(rows) do r.row.Visible = true end
			return
		end
		for _, r in ipairs(rows) do
			r.row.Visible = (string.find(r.name, q, 1, true) ~= nil)
		end
	end

	track(tabConnections, search:GetPropertyChangedSignal("Text"):Connect(applyFilter))

	track(tabConnections, btnSelectAll.Activated:Connect(function()
		if not running then return end
		for _, r in ipairs(rows) do
			r.setState(true)
		end
		applyFilter()
	end))

	track(tabConnections, btnClearAll.Activated:Connect(function()
		if not running then return end
		for _, r in ipairs(rows) do
			r.setState(false)
		end
		applyFilter()
	end))

	local expanded = false
	local function getExpandedHeight()
		RunService.Heartbeat:Wait()
		local h = contentLayout.AbsoluteContentSize.Y
		-- extra padding already included in layout; add a small buffer
		return h + (isMobile and 24 or 18)
	end

	local function setExpanded(on)
		expanded = on
		header.Text = (expanded and "▼ " or "► ") .. titleText
		local goalH = expanded and getExpandedHeight() or 0
		TweenService:Create(
			content,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(1, 0, 0, goalH) }
		):Play()
	end

	track(tabConnections, header.Activated:Connect(function()
		if not running then return end
		setExpanded(not expanded)
	end))
end

-- ========= Tabs (sesuai request terbaru) =========
local function buildMiningTab()
	clearContent()

	createCheckboxRow(ContentScroll, "Auto Mining", Settings.AutoFarm == true, function(v)
		setSetting("AutoFarm", v)
	end)

	createCollapsibleSection(("Zones (%d)"):format(#DATA.Zones), DATA.Zones, "Zones")
	createCollapsibleSection(("Rocks (%d)"):format(#DATA.Rocks), DATA.Rocks, "Rocks")
	createCollapsibleSection(("Ores (%d)"):format(#DATA.Ores), DATA.Ores, "Ores")
end

local function buildSettingTab()
	clearContent()

	-- batas sesuai request:
	-- TweenSpeed 20..80
	createSlider(ContentScroll, "TweenSpeed", 20, 80, tonumber(getSetting("TweenSpeed", 55)) or 55, 1, function(v)
		setSetting("TweenSpeed", v)
	end)

	-- YOffset -7..7
	createSlider(ContentScroll, "YOffset", -7, 7, tonumber(getSetting("YOffset", 3)) or 3, 0.5, function(v)
		setSetting("YOffset", v)
	end)

	-- kecil info
	local note = mkLabel(ContentScroll, "Hotkeys: L = Minimize/Restore | RightShift = Show/Hide (PC)\nMobile: tombol Forge (pojok kanan bawah)", isMobile and 16 or 14, false)
	note.Size = UDim2.new(1, 0, 0, 0)
	note.AutomaticSize = Enum.AutomaticSize.Y
end

-- ========= Tab Buttons =========
local miningBtn = createTabButton("Mining")
local settingBtn = createTabButton("Setting")

track(globalConnections, miningBtn.Activated:Connect(function()
	if not running then return end
	if minimized then toggleMinimize() end
	setTabSelected(miningBtn)
	buildMiningTab()
end))

track(globalConnections, settingBtn.Activated:Connect(function()
	if not running then return end
	if minimized then toggleMinimize() end
	setTabSelected(settingBtn)
	buildSettingTab()
end))

-- Default tab
setTabSelected(miningBtn)
buildMiningTab()

-- Start hidden on small mobile screens (optional, gaya lama)
if isMobile and isSmallScreen then
	MainFrame.Visible = false
end

print("[✓] Forge GUI loaded (Old Style + Updated) | lprxsw | L=minimize, RightShift=show/hide")
