-- Forge GUI Mini (Full)
-- Tabs:
--  1) Mining: AutoMining toggle + drawers (Zone/Rock/Ore) with SelectAll/Clear/Search
--  2) Setting: TweenSpeed slider + YOffset slider
-- Drag:
--  - Drag window by header area or title text. Does NOT interfere with buttons/textboxes.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local M = {}

-- ========= STYLE (ubah di sini kalau mau mirip GUI lamamu) =========
local STYLE = {
	MainBg = Color3.fromRGB(20, 20, 20),
	CardBg = Color3.fromRGB(35, 35, 35),
	CardBg2 = Color3.fromRGB(28, 28, 28),
	ButtonBg = Color3.fromRGB(45, 45, 45),
	ButtonBg2 = Color3.fromRGB(55, 55, 55),
	Stroke = Color3.fromRGB(70, 70, 70),
	Text = Color3.fromRGB(235, 235, 235),
	Text2 = Color3.fromRGB(240, 240, 240),
	Placeholder = Color3.fromRGB(160, 160, 160),

	ToggleOn = Color3.fromRGB(35, 120, 60),
	ToggleOff = Color3.fromRGB(120, 40, 40),

	Fill = Color3.fromRGB(120, 120, 120),
	Knob = Color3.fromRGB(220, 220, 220),

	CornerMain = 14,
	Corner = 10,
	CornerBtn = 8,
}

-- ========= UTILS =========
local function waitForGlobals(timeoutSec)
	local t0 = os.clock()
	while os.clock() - t0 < (timeoutSec or 10) do
		if type(_G.Settings) == "table" and type(_G.DATA) == "table" then
			return _G.Settings, _G.DATA
		end
		task.wait(0.1)
	end
	return nil, nil
end

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function round(x, step)
	step = step or 1
	return math.floor((x / step) + 0.5) * step
end

local function ensureTables(S, D)
	S.Zones = S.Zones or {}
	S.Rocks = S.Rocks or {}
	S.Ores  = S.Ores  or {}
	D.DATA = D.DATA or D
	return S, D
end

local function addCorner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end

local function addPadding(inst, l, r, t, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingRight = UDim.new(0, r or 0)
	p.PaddingTop = UDim.new(0, t or 0)
	p.PaddingBottom = UDim.new(0, b or 0)
	p.Parent = inst
	return p
end

local function makeText(parent, txt, size, bold)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Text = txt
	t.TextSize = size or 14
	t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextColor3 = STYLE.Text
	t.Parent = parent
	return t
end

local function makeButton(parent, txt, height)
	local b = Instance.new("TextButton")
	b.Text = txt
	b.AutoButtonColor = true
	b.BackgroundColor3 = STYLE.ButtonBg
	b.TextColor3 = STYLE.Text2
	b.Font = Enum.Font.Gotham
	b.TextSize = 14
	b.Size = UDim2.new(1, 0, 0, height or 32)
	b.Parent = parent
	addCorner(b, STYLE.CornerBtn)
	addPadding(b, 10, 10, 0, 0)
	return b
end

local function makeSmallButton(parent, txt, w, h)
	local b = Instance.new("TextButton")
	b.Text = txt
	b.AutoButtonColor = true
	b.BackgroundColor3 = STYLE.ButtonBg2
	b.TextColor3 = STYLE.Text2
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.Size = UDim2.new(0, w or 70, 0, h or 26)
	b.Parent = parent
	addCorner(b, STYLE.CornerBtn)
	addPadding(b, 8, 8, 0, 0)
	return b
end

local function makeCard(parent, height)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = STYLE.CardBg
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, height or 32)
	f.Parent = parent
	addCorner(f, STYLE.Corner)
	addPadding(f, 10, 10, 8, 8)
	return f
end

local function autoCanvas(scroll, layout)
	local function update()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	update()
end

-- ========= COMPONENTS =========
local function createToggleRow(parent, label, getValue, setValue)
	local row = makeCard(parent, 44)

	local left = Instance.new("TextLabel")
	left.BackgroundTransparency = 1
	left.Text = label
	left.TextSize = 14
	left.Font = Enum.Font.GothamBold
	left.TextXAlignment = Enum.TextXAlignment.Left
	left.TextColor3 = STYLE.Text
	left.Size = UDim2.new(1, -120, 1, 0)
	left.Parent = row

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0, 100, 0, 28)
	toggle.Position = UDim2.new(1, -100, 0.5, -14)
	toggle.Font = Enum.Font.GothamBold
	toggle.TextSize = 14
	toggle.BorderSizePixel = 0
	toggle.Parent = row
	addCorner(toggle, STYLE.CornerBtn)

	local function refresh()
		local v = getValue() and true or false
		if v then
			toggle.BackgroundColor3 = STYLE.ToggleOn
			toggle.Text = "ON"
		else
			toggle.BackgroundColor3 = STYLE.ToggleOff
			toggle.Text = "OFF"
		end
	end

	toggle.MouseButton1Click:Connect(function()
		setValue(not getValue())
		refresh()
	end)

	refresh()
	return row
end

-- Drawer: expand/collapse + SelectAll/Clear + Search + list
local function createDrawer(parent, title, items, mapTable)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 40)
	holder.Parent = parent

	local holderLayout = Instance.new("UIListLayout")
	holderLayout.Padding = UDim.new(0, 8)
	holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
	holderLayout.Parent = holder

	-- Header row
	local headerRow = Instance.new("Frame")
	headerRow.BackgroundTransparency = 1
	headerRow.Size = UDim2.new(1, 0, 0, 36)
	headerRow.Parent = holder

	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 8)
	headerLayout.Parent = headerRow

	local titleBtn = makeButton(headerRow, "▸  " .. title, 36)
	titleBtn.TextXAlignment = Enum.TextXAlignment.Left
	titleBtn.Size = UDim2.new(1, -160, 0, 36)

	local allBtn = makeSmallButton(headerRow, "Select All", 76, 26)
	local noneBtn = makeSmallButton(headerRow, "Clear", 64, 26)

	-- Body
	local body = Instance.new("Frame")
	body.BackgroundColor3 = STYLE.CardBg2
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, 0, 0, 290)
	body.Visible = false
	body.Parent = holder
	addCorner(body, STYLE.Corner)
	addPadding(body, 8, 8, 8, 8)

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 8)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	-- Search
	local searchRow = Instance.new("Frame")
	searchRow.BackgroundTransparency = 1
	searchRow.Size = UDim2.new(1, 0, 0, 30)
	searchRow.Parent = body

	local searchBox = Instance.new("TextBox")
	searchBox.ClearTextOnFocus = false
	searchBox.PlaceholderText = "Search..."
	searchBox.Text = ""
	searchBox.TextSize = 14
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextColor3 = STYLE.Text2
	searchBox.PlaceholderColor3 = STYLE.Placeholder
	searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	searchBox.BorderSizePixel = 0
	searchBox.Size = UDim2.new(1, 0, 1, 0)
	searchBox.Parent = searchRow
	addCorner(searchBox, STYLE.CornerBtn)
	addPadding(searchBox, 10, 10, 0, 0)

	-- List
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -46)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ScrollBarThickness = 6
	scroll.Parent = body

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	autoCanvas(scroll, list)

	local itemButtons = {} -- name -> button

	local function setItemText(btn, name)
		local checked = (mapTable[name] == true)
		btn.Text = (checked and "✅  " or "⬜  ") .. name
	end

	for _, name in ipairs(items) do
		if mapTable[name] == nil then mapTable[name] = false end
		local b = makeButton(scroll, "", 30)
		b.TextXAlignment = Enum.TextXAlignment.Left
		setItemText(b, name)
		itemButtons[name] = b

		b.MouseButton1Click:Connect(function()
			mapTable[name] = not mapTable[name]
			setItemText(b, name)
		end)
	end

	local function applyFilter()
		local q = (searchBox.Text or ""):lower()
		for name, btn in pairs(itemButtons) do
			btn.Visible = (q == "") or (name:lower():find(q, 1, true) ~= nil)
		end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	allBtn.MouseButton1Click:Connect(function()
		for name, btn in pairs(itemButtons) do
			mapTable[name] = true
			setItemText(btn, name)
		end
		applyFilter()
	end)

	noneBtn.MouseButton1Click:Connect(function()
		for name, btn in pairs(itemButtons) do
			mapTable[name] = false
			setItemText(btn, name)
		end
		applyFilter()
	end)

	local expanded = false
	local function setExpanded(v)
		expanded = v and true or false
		body.Visible = expanded
		titleBtn.Text = (expanded and "▾  " or "▸  ") .. title
		if expanded then applyFilter() end
	end

	titleBtn.MouseButton1Click:Connect(function()
		setExpanded(not expanded)
	end)

	setExpanded(false)
	return holder
end

local function createSlider(parent, label, minVal, maxVal, step, getValue, setValue)
	local row = makeCard(parent, 60)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = label
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = STYLE.Text
	title.Size = UDim2.new(1, -60, 0, 18)
	title.Parent = row

	local valueLbl = Instance.new("TextLabel")
	valueLbl.BackgroundTransparency = 1
	valueLbl.Text = ""
	valueLbl.TextSize = 14
	valueLbl.Font = Enum.Font.Gotham
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.TextColor3 = STYLE.Text
	valueLbl.Size = UDim2.new(0, 60, 0, 18)
	valueLbl.Position = UDim2.new(1, -60, 0, 0)
	valueLbl.Parent = row

	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, 10)
	bar.Position = UDim2.new(0, 0, 0, 32)
	bar.Parent = row
	addCorner(bar, 6)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = STYLE.Fill
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = bar
	addCorner(fill, 6)

	local knob = Instance.new("Frame")
	knob.BackgroundColor3 = STYLE.Knob
	knob.BorderSizePixel = 0
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.Position = UDim2.new(0, -7, 0.5, -7)
	knob.Parent = bar
	addCorner(knob, 999)

	local dragging = false

	local function setFromAlpha(a)
		a = clamp(a, 0, 1)
		local v = minVal + (maxVal - minVal) * a
		v = round(v, step)
		v = clamp(v, minVal, maxVal)
		setValue(v)
	end

	local function refresh()
		local v = tonumber(getValue()) or minVal
		v = clamp(v, minVal, maxVal)
		local a = (v - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, -7, 0.5, -7)
		valueLbl.Text = tostring(v)
	end

	local function updateFromInput(x)
		local absPos = bar.AbsolutePosition.X
		local absSize = bar.AbsoluteSize.X
		local a = (x - absPos) / absSize
		setFromAlpha(a)
		refresh()
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input.Position.X)
		end
	end)

	bar.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			updateFromInput(input.Position.X)
		end
	end)

	refresh()
	return row
end

-- ========= MAIN =========
function M.Start(S, D)
	if _G.__ForgeGUIMiniLoaded then return end
	_G.__ForgeGUIMiniLoaded = true

	S = S or _G.Settings
	D = D or _G.DATA
	if type(S) ~= "table" or type(D) ~= "table" then
		S, D = waitForGlobals(12)
	end
	if type(S) ~= "table" or type(D) ~= "table" then
		warn("[ForgeGUI Mini] _G.Settings/_G.DATA not found.")
		return
	end

	S, D = ensureTables(S, D)
	local DATA = (D.DATA or D)

	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")

	local old = pg:FindFirstChild("Forge_GUI_Mini")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Forge_GUI_Mini"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = pg

	local main = Instance.new("Frame")
	main.Size = UDim2.new(0, 420, 0, 520)
	main.Position = UDim2.new(0, 20, 0.5, -260)
	main.BackgroundColor3 = STYLE.MainBg
	main.BorderSizePixel = 0
	main.Parent = gui
	addCorner(main, STYLE.CornerMain)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = STYLE.Stroke
	stroke.Parent = main

	addPadding(main, 12, 12, 12, 12)

	-- Header
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 36)
	header.Parent = main

	-- IMPORTANT: enable input on header for drag
	header.Active = true

	local title = makeText(header, "Forge", 18, true)
	title.Size = UDim2.new(1, -120, 1, 0)
	title.Active = true -- allow title to receive InputBegan too

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(0, 210, 1, 0)
	tabs.Position = UDim2.new(1, -210, 0, 0)
	tabs.Parent = header

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tabsLayout.Padding = UDim.new(0, 8)
	tabsLayout.Parent = tabs

	local btnMining = makeButton(tabs, "Mining", 30)
	btnMining.Size = UDim2.new(0, 95, 0, 30)
	local btnSetting = makeButton(tabs, "Setting", 30)
	btnSetting.Size = UDim2.new(0, 95, 0, 30)

	-- Content wrapper
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 1, -44)
	content.Position = UDim2.new(0, 0, 0, 44)
	content.Parent = main

	local miningFrame = Instance.new("Frame")
	miningFrame.BackgroundTransparency = 1
	miningFrame.Size = UDim2.new(1, 0, 1, 0)
	miningFrame.Parent = content

	local settingFrame = Instance.new("Frame")
	settingFrame.BackgroundTransparency = 1
	settingFrame.Size = UDim2.new(1, 0, 1, 0)
	settingFrame.Visible = false
	settingFrame.Parent = content

	local function showTab(which)
		if which == "Mining" then
			miningFrame.Visible = true
			settingFrame.Visible = false
			btnMining.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			btnSetting.BackgroundColor3 = STYLE.ButtonBg
		else
			miningFrame.Visible = false
			settingFrame.Visible = true
			btnMining.BackgroundColor3 = STYLE.ButtonBg
			btnSetting.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		end
	end

	btnMining.MouseButton1Click:Connect(function() showTab("Mining") end)
	btnSetting.MouseButton1Click:Connect(function() showTab("Setting") end)
	showTab("Mining")

	-- Mining scroll
	local miningScroll = Instance.new("ScrollingFrame")
	miningScroll.BackgroundTransparency = 1
	miningScroll.BorderSizePixel = 0
	miningScroll.Size = UDim2.new(1, 0, 1, 0)
	miningScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	miningScroll.ScrollBarThickness = 6
	miningScroll.Parent = miningFrame

	local miningList = Instance.new("UIListLayout")
	miningList.Padding = UDim.new(0, 10)
	miningList.SortOrder = Enum.SortOrder.LayoutOrder
	miningList.Parent = miningScroll
	autoCanvas(miningScroll, miningList)

	createToggleRow(miningScroll, "Auto Mining", function()
		return S.AutoFarm == true
	end, function(v)
		S.AutoFarm = (v == true)
	end)

	createDrawer(miningScroll, "Filter Zone", DATA.Zones or {}, S.Zones)
	createDrawer(miningScroll, "Filter Rock", DATA.Rocks or {}, S.Rocks)
	createDrawer(miningScroll, "Filter Ore",  DATA.Ores  or {}, S.Ores)

	-- Setting scroll
	local settingScroll = Instance.new("ScrollingFrame")
	settingScroll.BackgroundTransparency = 1
	settingScroll.BorderSizePixel = 0
	settingScroll.Size = UDim2.new(1, 0, 1, 0)
	settingScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	settingScroll.ScrollBarThickness = 6
	settingScroll.Parent = settingFrame

	local settingList = Instance.new("UIListLayout")
	settingList.Padding = UDim.new(0, 10)
	settingList.SortOrder = Enum.SortOrder.LayoutOrder
	settingList.Parent = settingScroll
	autoCanvas(settingScroll, settingList)

	createSlider(settingScroll, "TweenSpeed", 5, 200, 1,
		function() return S.TweenSpeed or 55 end,
		function(v) S.TweenSpeed = v end
	)

	createSlider(settingScroll, "YOffset", -10, 30, 0.5,
		function() return S.YOffset or 3 end,
		function(v) S.YOffset = v end
	)

	-- ========= DRAG WINDOW (works reliably) =========
	local dragging = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil

	local function isInteractive(inst)
		return inst and (inst:IsA("TextButton") or inst:IsA("ImageButton") or inst:IsA("TextBox"))
	end

	local function canStartDrag(target)
		if UserInputService:GetFocusedTextBox() then return false end
		if not target then return true end
		if isInteractive(target) then return false end
		if tabs and target:IsDescendantOf(tabs) then return false end
		return true
	end

	local function beginDrag(input)
		if not canStartDrag(input.Target) then return end
		dragging = true
		dragInput = input
		dragStart = input.Position
		startPos = main.Position
	end

	local function endDrag(input)
		if input == dragInput then
			dragging = false
			dragInput = nil
		end
	end

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)

	header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			endDrag(input)
		end
	end)

	-- klik teks "Forge" juga bisa drag
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)

	title.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			endDrag(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input ~= dragInput then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	print("[✓] Forge GUI Mini loaded (drag + drawers tools).")
end

-- Auto-run
task.spawn(function()
	M.Start(_G.Settings, _G.DATA)
end)

return M
