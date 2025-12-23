--// THE FORGE - Manual Instance GUI (Template, safe callbacks)
--// Theme: black + red, batik fire/iron vibe (image tinted)
--// Controls: Tabs, drawers + checkboxes, sliders, drag, minimize (L), close

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- =========================================================
--  CONFIG / INTEGRATION POINTS (bind these from your own code)
-- =========================================================
local Callbacks = {
	OnAutoMiningChanged = function(on) end,               -- (boolean)
	OnFilterChanged = function(category, name, value) end, -- category: "Zones"/"Rocks"/"Ores"
	OnTweenSpeedChanged = function(v) end,               -- number 20..80
	OnYOffsetChanged = function(v) end,                  -- number -7..7
	OnClose = function()
		-- e.g. stop systems, restore character state, disconnect loops, etc.
	end
}

-- Optional: if you are building this for your OWN experience/tool system, you can set these:
-- Callbacks.OnAutoMiningChanged = function(on) YourSystem:SetEnabled(on) end

-- =========================================================
--  THEME
-- =========================================================
local C_BLACK = Color3.fromRGB(10, 10, 10)
local C_BLACK2 = Color3.fromRGB(18, 18, 18)
local C_RED = Color3.fromRGB(200, 0, 0)
local C_RED2 = Color3.fromRGB(120, 0, 0)
local C_TEXT = Color3.fromRGB(255, 235, 235)

local BATIK_IMAGE_ID = "rbxassetid://0" -- TODO: replace with your batik image asset id

-- =========================================================
--  HELPERS
-- =========================================================
local function mk(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	return inst
end

local function addCorner(parent, r)
	mk("UICorner", {CornerRadius = UDim.new(0, r or 10), Parent = parent})
end

local function addStroke(parent, thickness, color, transparency)
	mk("UIStroke", {
		Thickness = thickness or 1,
		Color = color or C_RED,
		Transparency = transparency or 0,
		Parent = parent
	})
end

local function addPadding(parent, p)
	mk("UIPadding", {
		PaddingTop = UDim.new(0, p),
		PaddingBottom = UDim.new(0, p),
		PaddingLeft = UDim.new(0, p),
		PaddingRight = UDim.new(0, p),
		Parent = parent
	})
end

local function addList(parent, pad)
	local layout = mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, pad or 8),
		Parent = parent
	})
	return layout
end

local function setTextStyle(lbl)
	lbl.Font = Enum.Font.Gotham
	lbl.TextColor3 = C_TEXT
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1
end

local function clamp(n, a, b)
	return math.max(a, math.min(b, n))
end

local function round(n)
	if n >= 0 then return math.floor(n + 0.5) end
	return math.ceil(n - 0.5)
end

-- =========================================================
--  BUILD UI
-- =========================================================
-- Clean old
local old = PG:FindFirstChild("TheForgeUI")
if old then old:Destroy() end

local ScreenGui = mk("ScreenGui", {
	Name = "TheForgeUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PG
})

local Main = mk("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(640, 420),
	Position = UDim2.new(0.5, -320, 0.5, -210),
	BackgroundColor3 = C_BLACK,
	BorderSizePixel = 0,
	Parent = ScreenGui
})
addCorner(Main, 14)
addStroke(Main, 2, C_RED, 0.15)

-- Batik background layer (tinted red)
local Batik = mk("ImageLabel", {
	Name = "Batik",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Image = BATIK_IMAGE_ID,
	ImageColor3 = C_RED,
	ImageTransparency = 0.75,
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.fromOffset(180, 180),
	Parent = Main
})
addCorner(Batik, 14)

-- Dark overlay (iron feel)
local Overlay = mk("Frame", {
	Name = "Overlay",
	BackgroundColor3 = C_BLACK,
	BackgroundTransparency = 0.15,
	Size = UDim2.fromScale(1, 1),
	BorderSizePixel = 0,
	Parent = Main
})
addCorner(Overlay, 14)

-- TopBar (drag handle)
local TopBar = mk("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = C_BLACK2,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Parent = Main
})
addCorner(TopBar, 14)
addStroke(TopBar, 1, C_RED2, 0.2)

local Title = mk("TextLabel", {
	Name = "Title",
	Text = "THE FORGE  |  Api & Besi",
	Size = UDim2.new(1, -160, 1, 0),
	Position = UDim2.fromOffset(14, 0),
	Parent = TopBar
})
setTextStyle(Title)
Title.TextSize = 15

local Hint = mk("TextLabel", {
	Name = "Hint",
	Text = "Minimize: [L]",
	Size = UDim2.fromOffset(120, 44),
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -84, 0, 0),
	Parent = TopBar
})
setTextStyle(Hint)
Hint.TextXAlignment = Enum.TextXAlignment.Right
Hint.TextTransparency = 0.15
Hint.TextSize = 12

local BtnMin = mk("TextButton", {
	Name = "MinimizeBtn",
	Text = "_",
	Size = UDim2.fromOffset(36, 28),
	Position = UDim2.new(1, -76, 0, 8),
	BackgroundColor3 = C_BLACK,
	BorderSizePixel = 0,
	Parent = TopBar,
	AutoButtonColor = false
})
addCorner(BtnMin, 8)
addStroke(BtnMin, 1, C_RED2, 0.25)

local BtnClose = mk("TextButton", {
	Name = "CloseBtn",
	Text = "X",
	Size = UDim2.fromOffset(36, 28),
	Position = UDim2.new(1, -36, 0, 8),
	BackgroundColor3 = C_RED2,
	BorderSizePixel = 0,
	Parent = TopBar,
	AutoButtonColor = false
})
addCorner(BtnClose, 8)
addStroke(BtnClose, 1, C_RED, 0.2)

local Body = mk("Frame", {
	Name = "Body",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -16, 1, -60),
	Position = UDim2.fromOffset(8, 52),
	Parent = Main
})

-- Left tab bar
local TabsBar = mk("Frame", {
	Name = "TabsBar",
	BackgroundColor3 = C_BLACK2,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(160, 1),
	Parent = Body
})
TabsBar.Size = UDim2.new(0, 160, 1, 0)
addCorner(TabsBar, 12)
addStroke(TabsBar, 1, C_RED2, 0.25)
addPadding(TabsBar, 10)
addList(TabsBar, 10)

local function makeTabButton(text)
	local b = mk("TextButton", {
		Text = text,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C_BLACK,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Parent = TabsBar
	})
	addCorner(b, 10)
	addStroke(b, 1, C_RED2, 0.35)
	local t = mk("TextLabel", {Text = text, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(12, 0), Parent = b})
	setTextStyle(t)
	t.TextSize = 14
	return b
end

local TabBtnAuto = makeTabButton("Auto Mining")
local TabBtnSettings = makeTabButton("Setting")

-- Right content area
local Content = mk("Frame", {
	Name = "Content",
	BackgroundColor3 = C_BLACK2,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Size = UDim2.new(1, -170, 1, 0),
	Position = UDim2.fromOffset(170, 0),
	Parent = Body
})
addCorner(Content, 12)
addStroke(Content, 1, C_RED2, 0.25)

local AutoTab = mk("Frame", {Name="AutoTab", BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Parent=Content})
local SetTab  = mk("Frame", {Name="SetTab",  BackgroundTransparency=1, Size=UDim2.fromScale(1,1), Parent=Content})
SetTab.Visible = false

-- Tab button state
local function setActiveTab(which)
	AutoTab.Visible = (which == "auto")
	SetTab.Visible = (which == "set")

	TabBtnAuto.BackgroundColor3 = (which == "auto") and C_RED2 or C_BLACK
	TabBtnSettings.BackgroundColor3 = (which == "set") and C_RED2 or C_BLACK
end
setActiveTab("auto")

TabBtnAuto.MouseButton1Click:Connect(function() setActiveTab("auto") end)
TabBtnSettings.MouseButton1Click:Connect(function() setActiveTab("set") end)

-- =========================================================
--  DRAGGING (TopBar only)
-- =========================================================
do
	local dragging = false
	local dragStart, startPos
	local dragInput

	local function update(input)
		local delta = input.Position - dragStart
		Main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end

	TopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	TopBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)
end

-- =========================================================
--  MINIMIZE / CLOSE
-- =========================================================
local minimized = false
local fullSize = Main.Size
local function applyMinimize(state)
	minimized = state
	if minimized then
		Body.Visible = false
		Main.Size = UDim2.fromOffset(fullSize.X.Offset, 44)
	else
		Body.Visible = true
		Main.Size = fullSize
	end
end

BtnMin.MouseButton1Click:Connect(function()
	applyMinimize(not minimized)
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.L then
		applyMinimize(not minimized)
	end
end)

local function doClose()
	pcall(function() Callbacks.OnClose() end)
	ScreenGui:Destroy()
end

BtnClose.MouseButton1Click:Connect(doClose)

-- =========================================================
--  AUTO MINING TAB CONTENT
-- =========================================================
addPadding(AutoTab, 12)
addList(AutoTab, 10)

local function headerLabel(parent, text)
	local lbl = mk("TextLabel", {Text = text, Size = UDim2.new(1, 0, 0, 22), Parent = parent})
	setTextStyle(lbl)
	lbl.TextSize = 15
	return lbl
end

headerLabel(AutoTab, "Control")

local ToggleRow = mk("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,44), Parent=AutoTab})
local ToggleBtn = mk("TextButton", {
	Text = "",
	Size = UDim2.fromOffset(64, 28),
	Position = UDim2.fromOffset(0, 8),
	BackgroundColor3 = C_BLACK,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Parent = ToggleRow
})
addCorner(ToggleBtn, 14)
addStroke(ToggleBtn, 1, C_RED2, 0.15)

local ToggleKnob = mk("Frame", {
	Size = UDim2.fromOffset(24, 24),
	Position = UDim2.fromOffset(2, 2),
	BackgroundColor3 = C_RED2,
	BorderSizePixel = 0,
	Parent = ToggleBtn
})
addCorner(ToggleKnob, 12)

local ToggleText = mk("TextLabel", {
	Text = "Auto Mining: OFF",
	Size = UDim2.new(1, -80, 1, 0),
	Position = UDim2.fromOffset(80, 0),
	Parent = ToggleRow
})
setTextStyle(ToggleText)
ToggleText.TextSize = 14

local autoOn = false
local function setToggle(v)
	autoOn = v and true or false
	ToggleText.Text = autoOn and "Auto Mining: ON" or "Auto Mining: OFF"

	local goal = autoOn and UDim2.fromOffset(38, 2) or UDim2.fromOffset(2, 2)
	local color = autoOn and C_RED or C_RED2

	TweenService:Create(ToggleKnob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = goal, BackgroundColor3 = color}):Play()
	TweenService:Create(ToggleBtn, TweenInfo.new(0.15), {BackgroundColor3 = autoOn and C_RED2 or C_BLACK}):Play()

	pcall(function() Callbacks.OnAutoMiningChanged(autoOn) end)
end

ToggleBtn.MouseButton1Click:Connect(function()
	setToggle(not autoOn)
end)

-- Drawer builder
local function createDrawer(parent, title, items, category)
	local wrap = mk("Frame", {BackgroundColor3=C_BLACK2, BackgroundTransparency=0.18, BorderSizePixel=0, Size=UDim2.new(1,0,0,48), Parent=parent})
	addCorner(wrap, 12)
	addStroke(wrap, 1, C_RED2, 0.25)

	local head = mk("TextButton", {Text="", BackgroundTransparency=1, Size=UDim2.new(1,0,0,42), Parent=wrap, AutoButtonColor=false})
	local ttl = mk("TextLabel", {Text=title, Size=UDim2.new(1,-60,1,0), Position=UDim2.fromOffset(12,0), Parent=head})
	setTextStyle(ttl)
	ttl.TextSize = 14

	local arrow = mk("TextLabel", {Text="v", Size=UDim2.fromOffset(24,24), AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-12,0.5,0), Parent=head})
	setTextStyle(arrow)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	arrow.TextSize = 16

	local listFrame = mk("ScrollingFrame", {
		Visible = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -16, 0, 160),
		Position = UDim2.fromOffset(8, 44),
		CanvasSize = UDim2.new(0,0,0,0),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C_RED2,
		Parent = wrap
	})
	addList(listFrame, 6)
	addPadding(listFrame, 2)

	local opened = false
	local function recalcCanvas()
		task.defer(function()
			local ui = listFrame:FindFirstChildOfClass("UIListLayout")
			if ui then
				listFrame.CanvasSize = UDim2.new(0,0,0, ui.AbsoluteContentSize.Y + 6)
			end
		end)
	end

	local state = {} -- name -> bool

	for _, name in ipairs(items) do
		state[name] = false

		local item = mk("TextButton", {
			Text = "",
			BackgroundColor3 = C_BLACK,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 32),
			Parent = listFrame
		})
		addCorner(item, 10)
		addStroke(item, 1, C_RED2, 0.35)

		local box = mk("Frame", {Size=UDim2.fromOffset(18,18), Position=UDim2.fromOffset(10,7), BackgroundColor3=C_BLACK2, BorderSizePixel=0, Parent=item})
		addCorner(box, 5)
		addStroke(box, 1, C_RED2, 0.2)

		local tick = mk("Frame", {Size=UDim2.fromOffset(10,10), Position=UDim2.fromOffset(4,4), BackgroundColor3=C_RED, BorderSizePixel=0, Visible=false, Parent=box})
		addCorner(tick, 3)

		local txt = mk("TextLabel", {Text=name, Size=UDim2.new(1, -40, 1, 0), Position=UDim2.fromOffset(36,0), Parent=item})
		setTextStyle(txt)
		txt.TextSize = 13

		item.MouseButton1Click:Connect(function()
			state[name] = not state[name]
			tick.Visible = state[name]
			pcall(function() Callbacks.OnFilterChanged(category, name, state[name]) end)
		end)
	end

	recalcCanvas()

	local function setOpen(v)
		opened = v and true or false
		listFrame.Visible = opened
		arrow.Text = opened and "^" or "v"
		wrap.Size = opened and UDim2.new(1,0,0, 44 + 160 + 6) or UDim2.new(1,0,0,48)
	end

	head.MouseButton1Click:Connect(function()
		setOpen(not opened)
	end)

	return {
		SetOpen = setOpen,
		State = state,
		ClearAll = function()
			for k in pairs(state) do state[k] = false end
			for _, child in ipairs(listFrame:GetChildren()) do
				if child:IsA("TextButton") then
					local box = child:FindFirstChildWhichIsA("Frame")
					if box then
						local tick = box:FindFirstChildWhichIsA("Frame")
						if tick then tick.Visible = false end
					end
				end
			end
		end
	}
end

-- Items placeholder (provide your own lists from server/game config)
-- For legal use in your own experience, populate these arrays with your actual zones/rocks/ores.
local Zones = { "ZoneA", "ZoneB", "ZoneC" }
local Rocks = { "RockA", "RockB", "RockC" }
local Ores  = { "OreA", "OreB", "OreC" }

headerLabel(AutoTab, "Filters (Laci)")
local DrawerZones = createDrawer(AutoTab, "Laci Zone", Zones, "Zones")
local DrawerRocks = createDrawer(AutoTab, "Laci Rock", Rocks, "Rocks")
local DrawerOres  = createDrawer(AutoTab, "Laci Ore",  Ores,  "Ores")

-- =========================================================
--  SETTINGS TAB CONTENT (Sliders)
-- =========================================================
addPadding(SetTab, 12)
addList(SetTab, 12)

headerLabel(SetTab, "Movement Settings")

local function createSlider(parent, title, minV, maxV, defaultV, onChanged)
	local wrap = mk("Frame", {BackgroundColor3=C_BLACK2, BackgroundTransparency=0.18, BorderSizePixel=0, Size=UDim2.new(1,0,0,70), Parent=parent})
	addCorner(wrap, 12)
	addStroke(wrap, 1, C_RED2, 0.25)
	addPadding(wrap, 12)

	local lbl = mk("TextLabel", {Text=title, Size=UDim2.new(1,0,0,18), Parent=wrap})
	setTextStyle(lbl)
	lbl.TextSize = 14

	local valLbl = mk("TextLabel", {Text=tostring(defaultV), Size=UDim2.fromOffset(80,18), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Parent=wrap})
	setTextStyle(valLbl)
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.TextTransparency = 0.1

	local bar = mk("Frame", {BackgroundColor3=C_BLACK, BorderSizePixel=0, Size=UDim2.new(1,0,0,10), Position=UDim2.fromOffset(0, 34), Parent=wrap})
	addCorner(bar, 8)
	addStroke(bar, 1, C_RED2, 0.35)

	local fill = mk("Frame", {BackgroundColor3=C_RED2, BorderSizePixel=0, Size=UDim2.new(0,0,1,0), Parent=bar})
	addCorner(fill, 8)

	local knob = mk("Frame", {BackgroundColor3=C_RED, BorderSizePixel=0, Size=UDim2.fromOffset(18,18), Parent=bar})
	addCorner(knob, 9)
	knob.Position = UDim2.new(0, -9, 0.5, -9)

	local dragging = false
	local current = defaultV

	local function setValue(v)
		current = clamp(v, minV, maxV)
		valLbl.Text = tostring(current)

		local alpha = (current - minV) / (maxV - minV)
		local px = math.floor(alpha * bar.AbsoluteSize.X)
		fill.Size = UDim2.new(0, px, 1, 0)
		knob.Position = UDim2.new(0, px - 9, 0.5, -9)

		if onChanged then pcall(onChanged, current) end
	end

	local function valueFromX(x)
		local rel = clamp(x - bar.AbsolutePosition.X, 0, bar.AbsoluteSize.X)
		local alpha = rel / bar.AbsoluteSize.X
		local v = minV + alpha * (maxV - minV)
		return round(v)
	end

	local function beginDrag(input)
		dragging = true
		setValue(valueFromX(input.Position.X))
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)

	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			setValue(valueFromX(input.Position.X))
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	-- init after render
	task.defer(function() setValue(defaultV) end)

	return { SetValue = setValue, GetValue = function() return current end }
end

local TweenSpeedSlider = createSlider(SetTab, "Tween Speed (20 - 80)", 20, 80, 50, function(v)
	Callbacks.OnTweenSpeedChanged(v)
end)

local YOffsetSlider = createSlider(SetTab, "Y Offset (-7 - 7)", -7, 7, -6, function(v)
	Callbacks.OnYOffsetChanged(v)
end)

-- =========================================================
--  CLOSE SHOULD STOP & CLEAR (template behavior)
-- =========================================================
local function stopAndClear()
	pcall(function() Callbacks.OnAutoMiningChanged(false) end)
	pcall(function()
		-- Clear UI checks (and call filter false if desired)
		DrawerZones.ClearAll()
		DrawerRocks.ClearAll()
		DrawerOres.ClearAll()
	end)
	pcall(function() Callbacks.OnClose() end)
end

BtnClose.MouseButton1Click:Connect(function()
	stopAndClear()
	ScreenGui:Destroy()
end)

-- =========================================================
--  EXPORT (optional)
-- =========================================================
return {
	Gui = ScreenGui,
	SetCallbacks = function(newCbs)
		for k,v in pairs(newCbs) do
			if Callbacks[k] ~= nil and type(v) == "function" then
				Callbacks[k] = v
			end
		end
	end,
	SetAutoMining = function(on) setToggle(on) end,
	SetTweenSpeed = function(v) TweenSpeedSlider.SetValue(v) end,
	SetYOffset = function(v) YOffsetSlider.SetValue(v) end
}
