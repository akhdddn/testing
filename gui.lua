--// Forge GUI (PC + Mobile Optimized) - Compatible with separated ForgeSettings + ForgeCore
--// LocalScript (StarterPlayerScripts)
--// Requires: ForgeBootstrap already ran and populated _G.DATA + _G.Settings

-- ========= Services =========
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========= Wait Globals =========
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
	warn("[ForgeGUI] _G.DATA / _G.Settings not found (timeout). GUI aborted.")
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
local isGamepad = UserInputService.GamepadEnabled
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

-- ========= Theme =========
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
gui.Name = "Forge_GUI_Separated"
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

	-- Base scale from viewport (kept conservative)
	local sx = vps.X / 1100
	local sy = vps.Y / 760
	local s = math.min(sx, sy)

	-- Mobile: slightly larger UI elements
	if isMobile then
		s = s * 1.08
	end

	return clamp(s, 0.78, 1.15)
end

local function refreshScale()
	if not running then return end
	uiScale.Scale = computeScale()
end

refreshScale()
track(globalConnections, RunService.RenderStepped:Connect(function()
	-- lightweight: only adjust if viewport changed
	-- (RenderStepped used to avoid extra camera events across experiences)
end))
track(globalConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refreshScale))
track(globalConnections, RunService.Heartbeat:Connect(function()
	-- update scale if size changed
	local cam = workspace.CurrentCamera
	if not cam then return end
	local v = cam.ViewportSize
	-- very cheap check
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
	-- slightly smaller base window; UIScale will still apply
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

local TitleLabel = mkLabel(TitleBar, "Forge UI (Separated Core)", isMobile and 20 or 18, true)
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

-- Close behavior: stop farm + stop loop (same “feel” as GUI lama)
local function stopEverything()
	if not running then return end
	running = false

	if _G.FarmLoop ~= nil then _G.FarmLoop = false end
	if _G.Settings then _G.Settings.AutoFarm = false end
	Settings.AutoFarm = false

	disconnectAll(tabConnections)
	disconnectAll(globalConnections)

	gui:Destroy()
end

track(globalConnections, CloseBtn.Activated:Connect(stopEverything))
track(globalConnections, MinBtn.Activated:Connect(toggleMinimize))
track(globalConnections, FloatBtn.Activated:Connect(function()
	if not running then return end
	toggleWindowVisible()
end))

-- PC hotkeys
track(globalConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not running then return end

	-- L : minimize (match GUI lama)
	if input.KeyCode == Enum.KeyCode.L then
		toggleMinimize()
	end
	-- RightShift : show/hide window (PC convenience)
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
	box.BackgroundColor3 = initial and THEME.BoxOn or THEME.BoxOff
	box.Parent = row
	uiCorner(box, 10)

	local lb = mkLabel(row, text, isMobile and 18 or 14, true)
	lb.Size = UDim2.new(1, -(isMobile and 86 or 74), 1, 0)
	lb.Position = UDim2.new(0, (isMobile and 74 or 62), 0, 0)

	local state = initial and true or false
	local function repaint()
		box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
	end

	track(tabConnections, box.Activated:Connect(function()
		if not running then return end
		state = not state
		repaint()
		onChanged(state)
	end))

	return row
end

-- Slider supports float steps (via step parameter)
local function createSlider(parent, title, minV, maxV, initial, step, onChanged)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, isMobile and 118 or 104)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local label = mkLabel(holder, "", isMobile and 16 or 14, false)
	label.Size = UDim2.new(1, 0, 0, isMobile and 40 or 36)
	label.Position = UDim2.new(0, 10, 0, 0)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -20, 0, isMobile and 20 or 18)
	bar.Position = UDim2.new(0, 10, 0, isMobile and 64 or 58)
	bar.BackgroundColor3 = THEME.TitleBg
	bar.BorderSizePixel = 0
	bar.Parent = holder
	bar.Active = true
	uiCorner(bar, 9)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(isMobile and 36 or 32, isMobile and 54 or 46)
	knob.BackgroundColor3 = THEME.Accent
	knob.BorderSizePixel = 0
	knob.Parent = bar
	uiCorner(knob, 12)

	step = step or 1
	local value = math.clamp(initial, minV, maxV)

	local function roundToStep(v)
		local q = (v - minV) / step
		q = math.floor(q + 0.5)
		return minV + (q * step)
	end

	local function fmt(v)
		-- nice formatting for floats
		if math.abs(v - math.floor(v)) < 1e-6 then
			return tostring(math.floor(v))
		end
		return string.format("%.2f", v)
	end

	local function setValueFromRel(rel)
		rel = math.clamp(rel, 0, 1)
		local raw = minV + (maxV - minV) * rel
		value = roundToStep(raw)
		value = math.clamp(value, minV, maxV)

		local rel2 = (value - minV) / (maxV - minV)
		knob.Position = UDim2.new(rel2, -(isMobile and 18 or 16), 0.5, -(isMobile and 27 or 23))

		label.Text = title .. ": " .. fmt(value)
		onChanged(value)
	end

	-- init
	setValueFromRel((value - minV) / (maxV - minV))

	local dragging = false
	local dragConnChanged, dragConnEnded

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
		if not running then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDrag(input)
		end
	end))

	return holder
end

-- Collapsible list with search filter (mobile-friendly)
local function createCollapsibleSection(title, items, branchKey)
	ensureBranch(Settings, branchKey)
	ensureBranch(_G.Settings, branchKey)

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

	local header = mkButton(section, "► " .. title, isMobile and 18 or 14)
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

	local rows = {} -- {name=string, row=Frame}
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
		label.Size = UDim2.new(1, -(isMobile and 70 or 62), 1, 0)
		label.Position = UDim2.new(0, (isMobile and 60 or 52), 0, 0)

		local state = Settings[branchKey][itemName] and true or false
		local function repaint()
			box.BackgroundColor3 = state and THEME.BoxOn or THEME.BoxOff
		end
		repaint()

		track(tabConnections, box.Activated:Connect(function()
			if not running then return end
			state = not state
			repaint()
			setBranchSetting(branchKey, itemName, state)
		end))

		rows[#rows + 1] = { name = itemName:lower(), row = row }
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

	local expanded = false
	local function getExpandedHeight()
		RunService.Heartbeat:Wait()
		local h = contentLayout.AbsoluteContentSize.Y
		-- pad + search box space roughly
		return h + (isMobile and 70 or 60)
	end

	local function setExpanded(on)
		expanded = on
		header.Text = (expanded and "▼ " or "► ") .. title
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

-- ========= Tabs =========
local function buildAutoTab()
	clearContent()

	createCheckboxRow(ContentScroll, "Enable Auto Mining", Settings.AutoFarm == true, function(v)
		setSetting("AutoFarm", v)
	end)

	createCheckboxRow(ContentScroll, "Respect LastHitPlayer (skip owned rocks)", Settings.RespectLastHitPlayer == true, function(v)
		setSetting("RespectLastHitPlayer", v)
	end)

	createCollapsibleSection(("Zones (%d)"):format(#DATA.Zones), DATA.Zones, "Zones")
	createCollapsibleSection(("Rocks (%d)"):format(#DATA.Rocks), DATA.Rocks, "Rocks")
	createCollapsibleSection(("Ores (%d)"):format(#DATA.Ores), DATA.Ores, "Ores")
end

local function buildSettingsTab()
	clearContent()

	-- Movement / Mining
	createSlider(ContentScroll, "Tween Speed", 10, 120, tonumber(getSetting("TweenSpeed", 55)) or 55, 1, function(v)
		setSetting("TweenSpeed", v)
	end)

	createSlider(ContentScroll, "Y Offset", -10, 10, tonumber(getSetting("YOffset", 3)) or 3, 1, function(v)
		setSetting("YOffset", v)
	end)

	createSlider(ContentScroll, "Scan Interval", 0.05, 0.50, tonumber(getSetting("ScanInterval", 0.12)) or 0.12, 0.01, function(v)
		setSetting("ScanInterval", v)
	end)

	createSlider(ContentScroll, "Hit Interval", 0.05, 0.40, tonumber(getSetting("HitInterval", 0.12)) or 0.12, 0.01, function(v)
		setSetting("HitInterval", v)
	end)

	-- Ore reveal logic
	createSlider(ContentScroll, "Ore Reveal Threshold (%)", 0, 100, tonumber(getSetting("OreRevealThreshold", 50)) or 50, 1, function(v)
		setSetting("OreRevealThreshold", v)
	end)

	createCheckboxRow(ContentScroll, "Allow Unknown Ore Above Reveal", Settings.AllowUnknownOreAboveReveal == true, function(v)
		setSetting("AllowUnknownOreAboveReveal", v)
	end)

	createCheckboxRow(ContentScroll, "Require Ore Match When Selected", Settings.RequireOreMatchWhenSelected == true, function(v)
		setSetting("RequireOreMatchWhenSelected", v)
	end)

	-- Lock & Facing
	createCheckboxRow(ContentScroll, "Lock To Target", Settings.LockToTarget == true, function(v)
		setSetting("LockToTarget", v)
	end)

	createCheckboxRow(ContentScroll, "Face Target While Mining", Settings.FaceTargetWhileMining == true, function(v)
		setSetting("FaceTargetWhileMining", v)
	end)

	createSlider(ContentScroll, "Lock Smooth Alpha", 0.05, 1.00, tonumber(getSetting("LockSmoothAlpha", 0.35)) or 0.35, 0.05, function(v)
		setSetting("LockSmoothAlpha", v)
	end)

	createCheckboxRow(ContentScroll, "Keep Noclip While Locked", Settings.KeepNoclipWhileLocked == true, function(v)
		setSetting("KeepNoclipWhileLocked", v)
	end)

	-- Camera
	createCheckboxRow(ContentScroll, "Camera Stabilize", Settings.CameraStabilize == true, function(v)
		setSetting("CameraStabilize", v)
	end)

	createSlider(ContentScroll, "Camera Smooth Alpha", 0.05, 1.00, tonumber(getSetting("CameraSmoothAlpha", 1)) or 1, 0.05, function(v)
		setSetting("CameraSmoothAlpha", v)
	end)

	-- Stop button (explicit)
	local stopBtn = mkButton(ContentScroll, isMobile and "STOP (Disable AutoFarm + Loop)" or "STOP (Disable AutoFarm + Loop)", isMobile and 18 or 14)
	stopBtn.Size = UDim2.new(1, 0, 0, isMobile and 68 or 56)
	stopBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
	uiCorner(stopBtn, 12)
	mkStroke(stopBtn, 2)

	track(tabConnections, stopBtn.Activated:Connect(function()
		if not running then return end
		_G.FarmLoop = false
		setSetting("AutoFarm", false)
	end))
end

local function buildAboutTab()
	clearContent()

	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = THEME.Holder
	box.BorderSizePixel = 0
	box.Parent = ContentScroll
	uiCorner(box, 12)
	mkStroke(box, 1)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = box

	local t = mkLabel(box,
		("Hotkeys:\n- RightShift: Show/Hide window\n- L: Minimize/Restore\n\nMobile:\n- Tap floating 'Forge' button to show/hide\n\nNotes:\n- GUI reads/writes _G.Settings so it stays compatible with separated core.\n- Long lists have Search.\n"):gsub("\n", "\n"),
		isMobile and 16 or 14,
		false
	)
	t.Size = UDim2.new(1, 0, 0, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
end

-- ========= Tab Buttons =========
local autoBtn = createTabButton("Auto")
local settingsBtn = createTabButton("Settings")
local aboutBtn = createTabButton("About")

track(globalConnections, autoBtn.Activated:Connect(function()
	if not running then return end
	if minimized then toggleMinimize() end
	setTabSelected(autoBtn)
	buildAutoTab()
end))

track(globalConnections, settingsBtn.Activated:Connect(function()
	if not running then return end
	if minimized then toggleMinimize() end
	setTabSelected(settingsBtn)
	buildSettingsTab()
end))

track(globalConnections, aboutBtn.Activated:Connect(function()
	if not running then return end
	if minimized then toggleMinimize() end
	setTabSelected(aboutBtn)
	buildAboutTab()
end))

-- Default tab
setTabSelected(autoBtn)
buildAutoTab()

-- Start hidden on small mobile screens (optional)
if isMobile and isSmallScreen then
	MainFrame.Visible = false
end

print("[✓] Forge GUI loaded (Separated-compatible). RightShift=Show/Hide, L=Minimize.")
