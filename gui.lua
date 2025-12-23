-- ============================================
-- GUI SYSTEM - BATIK API & BESI THEME
-- DELTA EXECUTOR COMPATIBLE VERSION
-- ============================================

-- Delta Executor compatible GUI system
local MiningGUI = {
    Enabled = false,
    Minimized = false,
    Dragging = false,
    DragStart = nil,
    DragStartPosition = nil
}

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local AutoMiner = require(script.Parent.AutoMiner) -- Adjust path as needed

-- Delta Executor compatible color system
local COLORS = {
    Black = Color3.fromRGB(30, 30, 30),
    DarkRed = Color3.fromRGB(139, 0, 0),
    Red = Color3.fromRGB(178, 34, 34),
    White = Color3.fromRGB(255, 255, 255),
    Gray = Color3.fromRGB(200, 200, 200),
    DarkGray = Color3.fromRGB(15, 15, 15),
    BrightRed = Color3.fromRGB(255, 69, 0)
}

-- Font fallbacks for Delta
local FONTS = {
    Gotham = Enum.Font.Gotham,
    Arial = Enum.Font.ArialBold
}

-- Create GUI
function MiningGUI:Create()
    -- Main ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "MiningGUIV2"
    self.ScreenGui.ResetOnSpawn = false
    
    -- Main Container
    self.MainFrame = Instance.new("Frame")
    self.MainFrame.Name = "MainFrame"
    self.MainFrame.BackgroundColor3 = COLORS.DarkGray
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.Size = UDim2.new(0, 400, 0, 500)
    self.MainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    self.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    
    -- Simple border effect (Delta compatible)
    local border = Instance.new("Frame")
    border.Name = "Border"
    border.BackgroundColor3 = COLORS.Red
    border.BorderSizePixel = 0
    border.Size = UDim2.new(1, 4, 1, 4)
    border.Position = UDim2.new(0, -2, 0, -2)
    border.ZIndex = 0
    border.Parent = self.MainFrame
    
    local innerBorder = Instance.new("Frame")
    innerBorder.Name = "InnerBorder"
    innerBorder.BackgroundColor3 = COLORS.Black
    innerBorder.BorderSizePixel = 0
    innerBorder.Size = UDim2.new(1, -2, 1, -2)
    innerBorder.Position = UDim2.new(0, 1, 0, 1)
    innerBorder.Parent = self.MainFrame
    
    -- Header
    self.Header = Instance.new("Frame")
    self.Header.Name = "Header"
    self.Header.BackgroundColor3 = COLORS.Black
    self.Header.BorderSizePixel = 0
    self.Header.Size = UDim2.new(1, 0, 0, 35)
    
    -- Header Title
    self.Title = Instance.new("TextLabel")
    self.Title.Name = "Title"
    self.Title.Text = "⚒️ AUTO MINING v9.1"
    self.Title.Font = FONTS.Gotham
    self.Title.TextSize = 16
    self.Title.TextColor3 = COLORS.Red
    self.Title.BackgroundTransparency = 1
    self.Title.Size = UDim2.new(0.6, 0, 1, 0)
    self.Title.Position = UDim2.new(0.02, 0, 0, 0)
    self.Title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Control Buttons
    self.MinimizeBtn = Instance.new("TextButton")
    self.MinimizeBtn.Name = "MinimizeBtn"
    self.MinimizeBtn.Text = "─"
    self.MinimizeBtn.Font = FONTS.Arial
    self.MinimizeBtn.TextSize = 16
    self.MinimizeBtn.TextColor3 = COLORS.White
    self.MinimizeBtn.BackgroundColor3 = COLORS.DarkRed
    self.MinimizeBtn.BorderSizePixel = 0
    self.MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    self.MinimizeBtn.Position = UDim2.new(0.85, 0, 0.5, -12.5)
    self.MinimizeBtn.AnchorPoint = Vector2.new(0, 0.5)
    
    self.CloseBtn = Instance.new("TextButton")
    self.CloseBtn.Name = "CloseBtn"
    self.CloseBtn.Text = "X"
    self.CloseBtn.Font = FONTS.Arial
    self.CloseBtn.TextSize = 14
    self.CloseBtn.TextColor3 = COLORS.White
    self.CloseBtn.BackgroundColor3 = COLORS.Red
    self.CloseBtn.BorderSizePixel = 0
    self.CloseBtn.Size = UDim2.new(0, 25, 0, 25)
    self.CloseBtn.Position = UDim2.new(0.93, 0, 0.5, -12.5)
    self.CloseBtn.AnchorPoint = Vector2.new(0, 0.5)
    
    -- Tab System
    self.TabsContainer = Instance.new("Frame")
    self.TabsContainer.Name = "TabsContainer"
    self.TabsContainer.BackgroundColor3 = COLORS.Black
    self.TabsContainer.BorderSizePixel = 0
    self.TabsContainer.Size = UDim2.new(1, 0, 0, 30)
    self.TabsContainer.Position = UDim2.new(0, 0, 0, 35)
    
    self.AutoMiningTabBtn = Instance.new("TextButton")
    self.AutoMiningTabBtn.Name = "AutoMiningTabBtn"
    self.AutoMiningTabBtn.Text = "🔨 Auto Mining"
    self.AutoMiningTabBtn.Font = FONTS.Gotham
    self.AutoMiningTabBtn.TextSize = 13
    self.AutoMiningTabBtn.TextColor3 = COLORS.White
    self.AutoMiningTabBtn.BackgroundColor3 = COLORS.Red
    self.AutoMiningTabBtn.BorderSizePixel = 0
    self.AutoMiningTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
    self.AutoMiningTabBtn.Position = UDim2.new(0, 0, 0, 0)
    
    self.SettingTabBtn = Instance.new("TextButton")
    self.SettingTabBtn.Name = "SettingTabBtn"
    self.SettingTabBtn.Text = "⚙️ Settings"
    self.SettingTabBtn.Font = FONTS.Gotham
    self.SettingTabBtn.TextSize = 13
    self.SettingTabBtn.TextColor3 = COLORS.Gray
    self.SettingTabBtn.BackgroundColor3 = COLORS.Black
    self.SettingTabBtn.BorderSizePixel = 0
    self.SettingTabBtn.Size = UDim2.new(0.5, 0, 1, 0)
    self.SettingTabBtn.Position = UDim2.new(0.5, 0, 0, 0)
    
    -- Content Area
    self.ContentContainer = Instance.new("Frame")
    self.ContentContainer.Name = "ContentContainer"
    self.ContentContainer.BackgroundTransparency = 1
    self.ContentContainer.Size = UDim2.new(1, 0, 1, -65)
    self.ContentContainer.Position = UDim2.new(0, 0, 0, 65)
    self.ContentContainer.ClipsDescendants = true
    
    -- Create content frames
    self:CreateAutoMiningTab()
    self:CreateSettingsTab()
    
    -- Parent everything
    self.Title.Parent = self.Header
    self.MinimizeBtn.Parent = self.Header
    self.CloseBtn.Parent = self.Header
    self.Header.Parent = self.MainFrame
    
    self.AutoMiningTabBtn.Parent = self.TabsContainer
    self.SettingTabBtn.Parent = self.TabsContainer
    self.TabsContainer.Parent = self.MainFrame
    
    self.ContentContainer.Parent = self.MainFrame
    self.MainFrame.Parent = self.ScreenGui
    self.ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    
    -- Setup functionality
    self:SetupFunctionality()
    
    self.Enabled = true
    print("✅ GUI Created Successfully")
end

function MiningGUI:CreateAutoMiningTab()
    -- Auto Mining Tab
    self.AutoMiningContent = Instance.new("Frame")
    self.AutoMiningContent.Name = "AutoMiningContent"
    self.AutoMiningContent.BackgroundTransparency = 1
    self.AutoMiningContent.Size = UDim2.new(1, 0, 1, 0)
    self.AutoMiningContent.Visible = true
    
    -- On/Off Toggle
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "ToggleFrame"
    toggleFrame.BackgroundColor3 = COLORS.Black
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Size = UDim2.new(1, -20, 0, 50)
    toggleFrame.Position = UDim2.new(0, 10, 0, 10)
    
    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Name = "ToggleLabel"
    toggleLabel.Text = "AUTO MINING"
    toggleLabel.Font = FONTS.Arial
    toggleLabel.TextSize = 14
    toggleLabel.TextColor3 = COLORS.White
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    toggleLabel.Position = UDim2.new(0, 10, 0, 0)
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    self.ToggleBtn = Instance.new("TextButton")
    self.ToggleBtn.Name = "ToggleBtn"
    self.ToggleBtn.Text = "OFF"
    self.ToggleBtn.Font = FONTS.Gotham
    self.ToggleBtn.TextSize = 13
    self.ToggleBtn.TextColor3 = COLORS.White
    self.ToggleBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
    self.ToggleBtn.BorderSizePixel = 0
    self.ToggleBtn.Size = UDim2.new(0, 70, 0, 30)
    self.ToggleBtn.Position = UDim2.new(1, -80, 0.5, -15)
    self.ToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
    
    -- Status display
    self.StatusLabel = Instance.new("TextLabel")
    self.StatusLabel.Name = "StatusLabel"
    self.StatusLabel.Text = "Status: Stopped"
    self.StatusLabel.Font = FONTS.Gotham
    self.StatusLabel.TextSize = 12
    self.StatusLabel.TextColor3 = COLORS.Gray
    self.StatusLabel.BackgroundTransparency = 1
    self.StatusLabel.Size = UDim2.new(1, -20, 0, 20)
    self.StatusLabel.Position = UDim2.new(0, 10, 0, 65)
    self.StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Scroll container for filters
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.Size = UDim2.new(1, -20, 1, -100)
    scrollFrame.Position = UDim2.new(0, 10, 0, 90)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = COLORS.Red
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
    
    -- Create filter sections
    local yOffset = 0
    
    -- Zone Filter
    local zoneFrame = self:CreateFilterSection("Zone Filter", AutoMiner.getDataLists().Zones, "Zones", yOffset)
    zoneFrame.Parent = scrollFrame
    yOffset = yOffset + 60 + (#AutoMiner.getDataLists().Zones * 25)
    
    -- Rock Filter
    local rockFrame = self:CreateFilterSection("Rock Filter", AutoMiner.getDataLists().Rocks, "Rocks", yOffset)
    rockFrame.Parent = scrollFrame
    yOffset = yOffset + 60 + (#AutoMiner.getDataLists().Rocks * 25)
    
    -- Ore Filter
    local oreFrame = self:CreateFilterSection("Ore Filter", AutoMiner.getDataLists().Ores, "Ores", yOffset)
    oreFrame.Parent = scrollFrame
    
    -- Update canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 100)
    
    -- Parent everything
    toggleLabel.Parent = toggleFrame
    self.ToggleBtn.Parent = toggleFrame
    toggleFrame.Parent = self.AutoMiningContent
    self.StatusLabel.Parent = self.AutoMiningContent
    scrollFrame.Parent = self.AutoMiningContent
    self.AutoMiningContent.Parent = self.ContentContainer
end

function MiningGUI:CreateFilterSection(title, items, category, yPosition)
    local section = Instance.new("Frame")
    section.Name = category .. "Section"
    section.BackgroundColor3 = COLORS.Black
    section.BorderSizePixel = 0
    section.Size = UDim2.new(1, 0, 0, 40 + (#items * 25))
    section.Position = UDim2.new(0, 0, 0, yPosition)
    
    -- Section header
    local header = Instance.new("TextButton")
    header.Name = "Header"
    header.Text = "▶ " .. title
    header.Font = FONTS.Gotham
    header.TextSize = 13
    header.TextColor3 = COLORS.White
    header.BackgroundColor3 = COLORS.DarkRed
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, 30)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.PaddingLeft = UDim.new(0, 10)
    
    -- Items container (visible by default for Delta compatibility)
    local itemsFrame = Instance.new("Frame")
    itemsFrame.Name = "Items"
    itemsFrame.BackgroundColor3 = COLORS.DarkGray
    itemsFrame.BorderSizePixel = 0
    itemsFrame.Size = UDim2.new(1, 0, 0, #items * 25)
    itemsFrame.Position = UDim2.new(0, 0, 0, 30)
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = itemsFrame
    
    -- Create checkboxes
    for i, item in ipairs(items) do
        local checkboxFrame = Instance.new("Frame")
        checkboxFrame.Name = item .. "Checkbox"
        checkboxFrame.BackgroundTransparency = 1
        checkboxFrame.Size = UDim2.new(1, -10, 0, 23)
        checkboxFrame.Position = UDim2.new(0, 5, 0, (i-1)*25)
        
        local checkbox = Instance.new("TextButton")
        checkbox.Name = "Checkbox"
        checkbox.Text = ""
        checkbox.BackgroundColor3 = COLORS.Black
        checkbox.BorderSizePixel = 1
        checkbox.BorderColor3 = COLORS.Red
        checkbox.Size = UDim2.new(0, 18, 0, 18)
        checkbox.Position = UDim2.new(0, 5, 0.5, -9)
        checkbox.AnchorPoint = Vector2.new(0, 0.5)
        
        local checkmark = Instance.new("TextLabel")
        checkmark.Name = "Checkmark"
        checkmark.Text = "✓"
        checkmark.Font = FONTS.Arial
        checkmark.TextSize = 14
        checkmark.TextColor3 = COLORS.Red
        checkmark.BackgroundTransparency = 1
        checkmark.Size = UDim2.new(1, 0, 1, 0)
        checkmark.Visible = false
        
        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.Text = item
        label.Font = FONTS.Gotham
        label.TextSize = 12
        label.TextColor3 = COLORS.Gray
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, -30, 1, 0)
        label.Position = UDim2.new(0, 30, 0, 0)
        label.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Checkbox click event
        checkbox.MouseButton1Click:Connect(function()
            local currentState = not checkmark.Visible
            checkmark.Visible = currentState
            
            -- Update filter
            AutoMiner.setFilter(category, item, currentState)
            
            -- Visual feedback
            if currentState then
                checkbox.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
            else
                checkbox.BackgroundColor3 = COLORS.Black
            end
        end)
        
        -- Initialize state
        task.spawn(function()
            local initialState = AutoMiner.getFilter(category, item)
            checkmark.Visible = initialState
            if initialState then
                checkbox.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
            end
        end)
        
        checkboxFrame.Parent = itemsFrame
        checkbox.Parent = checkboxFrame
        checkmark.Parent = checkbox
        label.Parent = checkboxFrame
    end
    
    -- Simple toggle (show/hide)
    header.MouseButton1Click:Connect(function()
        if itemsFrame.Visible then
            itemsFrame.Visible = false
            section.Size = UDim2.new(1, 0, 0, 30)
            header.Text = "▶ " .. title
        else
            itemsFrame.Visible = true
            section.Size = UDim2.new(1, 0, 0, 40 + (#items * 25))
            header.Text = "▼ " .. title
        end
    end)
    
    header.Parent = section
    itemsFrame.Parent = section
    
    return section
end

function MiningGUI:CreateSettingsTab()
    -- Settings Tab
    self.SettingContent = Instance.new("Frame")
    self.SettingContent.Name = "SettingContent"
    self.SettingContent.BackgroundTransparency = 1
    self.SettingContent.Size = UDim2.new(1, 0, 1, 0)
    self.SettingContent.Visible = false
    
    -- Tween Speed Slider
    local tweenFrame = Instance.new("Frame")
    tweenFrame.Name = "TweenFrame"
    tweenFrame.BackgroundColor3 = COLORS.Black
    tweenFrame.BorderSizePixel = 0
    tweenFrame.Size = UDim2.new(1, -20, 0, 60)
    tweenFrame.Position = UDim2.new(0, 10, 0, 20)
    
    self.TweenSpeedLabel = Instance.new("TextLabel")
    self.TweenSpeedLabel.Name = "TweenSpeedLabel"
    self.TweenSpeedLabel.Text = "Tween Speed: 50"
    self.TweenSpeedLabel.Font = FONTS.Gotham
    self.TweenSpeedLabel.TextSize = 14
    self.TweenSpeedLabel.TextColor3 = COLORS.White
    self.TweenSpeedLabel.BackgroundTransparency = 1
    self.TweenSpeedLabel.Size = UDim2.new(1, -10, 0, 20)
    self.TweenSpeedLabel.Position = UDim2.new(0, 5, 0, 5)
    self.TweenSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    self.TweenSpeedSlider = Instance.new("Frame")
    self.TweenSpeedSlider.Name = "TweenSpeedSlider"
    self.TweenSpeedSlider.BackgroundColor3 = COLORS.DarkGray
    self.TweenSpeedSlider.BorderSizePixel = 0
    self.TweenSpeedSlider.Size = UDim2.new(1, -10, 0, 20)
    self.TweenSpeedSlider.Position = UDim2.new(0, 5, 0, 30)
    
    self.TweenSpeedFill = Instance.new("Frame")
    self.TweenSpeedFill.Name = "Fill"
    self.TweenSpeedFill.BackgroundColor3 = COLORS.Red
    self.TweenSpeedFill.BorderSizePixel = 0
    self.TweenSpeedFill.Size = UDim2.new(0.5, 0, 1, 0)
    
    self.TweenSpeedButton = Instance.new("TextButton")
    self.TweenSpeedButton.Name = "Button"
    self.TweenSpeedButton.Text = ""
    self.TweenSpeedButton.BackgroundColor3 = COLORS.White
    self.TweenSpeedButton.BorderSizePixel = 0
    self.TweenSpeedButton.Size = UDim2.new(0, 24, 0, 24)
    self.TweenSpeedButton.Position = UDim2.new(0.5, -12, 0.5, -12)
    self.TweenSpeedButton.AnchorPoint = Vector2.new(0, 0.5)
    
    -- Y Offset Slider
    local yOffsetFrame = Instance.new("Frame")
    yOffsetFrame.Name = "YOffsetFrame"
    yOffsetFrame.BackgroundColor3 = COLORS.Black
    yOffsetFrame.BorderSizePixel = 0
    yOffsetFrame.Size = UDim2.new(1, -20, 0, 60)
    yOffsetFrame.Position = UDim2.new(0, 10, 0, 100)
    
    self.YOffsetLabel = Instance.new("TextLabel")
    self.YOffsetLabel.Name = "YOffsetLabel"
    self.YOffsetLabel.Text = "Y Offset: -6 studs"
    self.YOffsetLabel.Font = FONTS.Gotham
    self.YOffsetLabel.TextSize = 14
    self.YOffsetLabel.TextColor3 = COLORS.White
    self.YOffsetLabel.BackgroundTransparency = 1
    self.YOffsetLabel.Size = UDim2.new(1, -10, 0, 20)
    self.YOffsetLabel.Position = UDim2.new(0, 5, 0, 5)
    self.YOffsetLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    self.YOffsetSlider = Instance.new("Frame")
    self.YOffsetSlider.Name = "YOffsetSlider"
    self.YOffsetSlider.BackgroundColor3 = COLORS.DarkGray
    self.YOffsetSlider.BorderSizePixel = 0
    self.YOffsetSlider.Size = UDim2.new(1, -10, 0, 20)
    self.YOffsetSlider.Position = UDim2.new(0, 5, 0, 30)
    
    self.YOffsetFill = Instance.new("Frame")
    self.YOffsetFill.Name = "Fill"
    self.YOffsetFill.BackgroundColor3 = COLORS.Red
    self.YOffsetFill.BorderSizePixel = 0
    self.YOffsetFill.Size = UDim2.new(0.5, 0, 1, 0)
    
    self.YOffsetButton = Instance.new("TextButton")
    self.YOffsetButton.Name = "Button"
    self.YOffsetButton.Text = ""
    self.YOffsetButton.BackgroundColor3 = COLORS.White
    self.YOffsetButton.BorderSizePixel = 0
    self.YOffsetButton.Size = UDim2.new(0, 24, 0, 24)
    self.YOffsetButton.Position = UDim2.new(0.5, -12, 0.5, -12)
    self.YOffsetButton.AnchorPoint = Vector2.new(0, 0.5)
    
    -- Stats Display
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.BackgroundColor3 = COLORS.Black
    statsFrame.BorderSizePixel = 0
    statsFrame.Size = UDim2.new(1, -20, 0, 150)
    statsFrame.Position = UDim2.new(0, 10, 0, 180)
    
    local statsTitle = Instance.new("TextLabel")
    statsTitle.Name = "StatsTitle"
    statsTitle.Text = "📊 SYSTEM STATS"
    statsTitle.Font = FONTS.Arial
    statsTitle.TextSize = 14
    statsTitle.TextColor3 = COLORS.Red
    statsTitle.BackgroundTransparency = 1
    statsTitle.Size = UDim2.new(1, -10, 0, 25)
    statsTitle.Position = UDim2.new(0, 5, 0, 5)
    statsTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    self.StatsText = Instance.new("TextLabel")
    self.StatsText.Name = "StatsText"
    self.StatsText.Text = "Loading stats..."
    self.StatsText.Font = FONTS.Gotham
    self.StatsText.TextSize = 12
    self.StatsText.TextColor3 = COLORS.Gray
    self.StatsText.BackgroundTransparency = 1
    self.StatsText.Size = UDim2.new(1, -10, 1, -30)
    self.StatsText.Position = UDim2.new(0, 5, 0, 30)
    self.StatsText.TextXAlignment = Enum.TextXAlignment.Left
    self.StatsText.TextYAlignment = Enum.TextYAlignment.Top
    self.StatsText.TextWrapped = true
    
    -- Parent slider elements
    self.TweenSpeedFill.Parent = self.TweenSpeedSlider
    self.TweenSpeedButton.Parent = self.TweenSpeedSlider
    self.TweenSpeedLabel.Parent = tweenFrame
    self.TweenSpeedSlider.Parent = tweenFrame
    tweenFrame.Parent = self.SettingContent
    
    self.YOffsetFill.Parent = self.YOffsetSlider
    self.YOffsetButton.Parent = self.YOffsetSlider
    self.YOffsetLabel.Parent = yOffsetFrame
    self.YOffsetSlider.Parent = yOffsetFrame
    yOffsetFrame.Parent = self.SettingContent
    
    statsTitle.Parent = statsFrame
    self.StatsText.Parent = statsFrame
    statsFrame.Parent = self.SettingContent
    
    self.SettingContent.Parent = self.ContentContainer
    
    -- Setup sliders
    self:SetupSliders()
end

function MiningGUI:SetupSliders()
    -- Tween Speed Slider (20-80)
    self:CreateSlider(
        self.TweenSpeedSlider,
        self.TweenSpeedFill,
        self.TweenSpeedButton,
        self.TweenSpeedLabel,
        20, 80, 50,
        function(value)
            local intValue = math.floor(value)
            self.TweenSpeedLabel.Text = "Tween Speed: " .. intValue
            AutoMiner.setTweenSpeed(intValue)
        end
    )
    
    -- Y Offset Slider (-7 to 7)
    self:CreateSlider(
        self.YOffsetSlider,
        self.YOffsetFill,
        self.YOffsetButton,
        self.YOffsetLabel,
        -7, 7, -6,
        function(value)
            local intValue = math.floor(value)
            self.YOffsetLabel.Text = "Y Offset: " .. intValue .. " studs"
            AutoMiner.setYOffset(intValue)
        end
    )
end

function MiningGUI:CreateSlider(sliderFrame, fillFrame, button, label, minValue, maxValue, currentValue, callback)
    local isDragging = false
    
    local function updateValue(value)
        local normalized = (value - minValue) / (maxValue - minValue)
        normalized = math.clamp(normalized, 0, 1)
        
        fillFrame.Size = UDim2.new(normalized, 0, 1, 0)
        button.Position = UDim2.new(normalized, -12, 0.5, -12)
        
        if callback then
            callback(value)
        end
    end
    
    -- Initialize
    updateValue(currentValue)
    
    -- Mouse events
    button.MouseButton1Down:Connect(function()
        isDragging = true
    end)
    
    sliderFrame.MouseButton1Down:Connect(function(x, y)
        isDragging = true
        local sliderPos = sliderFrame.AbsolutePosition
        local sliderSize = sliderFrame.AbsoluteSize
        local normalized = (x - sliderPos.X) / sliderSize.X
        normalized = math.clamp(normalized, 0, 1)
        local value = minValue + (maxValue - minValue) * normalized
        updateValue(value)
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local sliderPos = sliderFrame.AbsolutePosition
            local sliderSize = sliderFrame.AbsoluteSize
            local normalized = (input.Position.X - sliderPos.X) / sliderSize.X
            normalized = math.clamp(normalized, 0, 1)
            local value = minValue + (maxValue - minValue) * normalized
            updateValue(value)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = false
        end
    end)
end

function MiningGUI:UpdateStatus()
    if not self.Enabled then return end
    
    local stats = AutoMiner.getStats()
    local status = stats.miningActive and "Running" or "Stopped"
    local color = stats.miningActive and COLORS.Red or Color3.fromRGB(100, 0, 0)
    
    self.StatusLabel.Text = "Status: " .. status
    self.ToggleBtn.Text = stats.miningActive and "ON" or "OFF"
    self.ToggleBtn.BackgroundColor3 = color
    
    -- Update stats text
    local statsStr = string.format(
        "Mining: %s\n" ..
        "Current Rock: %s\n" ..
        "Next Rock: %s\n" ..
        "Tween Speed: %d\n" ..
        "Y Offset: %d studs\n" ..
        "Zones: %d\n" ..
        "Rocks: %d\n" ..
        "Filter Active: %s\n" ..
        "Avg Damage: %d",
        tostring(stats.miningActive),
        stats.currentRock,
        stats.nextRock,
        stats.tweenSpeed,
        stats.yOffset,
        stats.zones,
        stats.rocks,
        tostring(stats.filterActive),
        stats.avgDamage or 20
    )
    
    self.StatsText.Text = statsStr
end

function MiningGUI:SetupFunctionality()
    -- Tab switching
    self.AutoMiningTabBtn.MouseButton1Click:Connect(function()
        self.AutoMiningContent.Visible = true
        self.SettingContent.Visible = false
        self.AutoMiningTabBtn.BackgroundColor3 = COLORS.Red
        self.AutoMiningTabBtn.TextColor3 = COLORS.White
        self.SettingTabBtn.BackgroundColor3 = COLORS.Black
        self.SettingTabBtn.TextColor3 = COLORS.Gray
    end)
    
    self.SettingTabBtn.MouseButton1Click:Connect(function()
        self.AutoMiningContent.Visible = false
        self.SettingContent.Visible = true
        self.SettingTabBtn.BackgroundColor3 = COLORS.Red
        self.SettingTabBtn.TextColor3 = COLORS.White
        self.AutoMiningTabBtn.BackgroundColor3 = COLORS.Black
        self.AutoMiningTabBtn.TextColor3 = COLORS.Gray
    end)
    
    -- Toggle mining
    self.ToggleBtn.MouseButton1Click:Connect(function()
        if AutoMiner.isActive() then
            AutoMiner.stop()
        else
            AutoMiner.start()
        end
        self:UpdateStatus()
    end)
    
    -- Minimize
    local originalHeight = self.MainFrame.Size.Y.Offset
    self.MinimizeBtn.MouseButton1Click:Connect(function()
        self.Minimized = not self.Minimized
        
        if self.Minimized then
            self.MainFrame.Size = UDim2.new(0, 400, 0, 35)
            self.ContentContainer.Visible = false
            self.TabsContainer.Visible = false
            self.MinimizeBtn.Text = "□"
        else
            self.MainFrame.Size = UDim2.new(0, 400, 0, originalHeight)
            self.ContentContainer.Visible = true
            self.TabsContainer.Visible = true
            self.MinimizeBtn.Text = "─"
        end
    end)
    
    -- Close
    self.CloseBtn.MouseButton1Click:Connect(function()
        if AutoMiner.isActive() then
            AutoMiner.stop()
        end
        
        -- Cleanup
        if self.ScreenGui then
            self.ScreenGui:Destroy()
        end
        
        self.Enabled = false
        
        -- Restore character
        local character = localPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.PlatformStand = false
            end
        end
        
        print("GUI Closed - All systems stopped")
    end)
    
    -- Dragging
    self.Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Dragging = true
            self.DragStart = input.Position
            self.DragStartPosition = self.MainFrame.Position
        end
    end)
    
    self.Header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and self.Dragging then
            local delta = input.Position - self.DragStart
            self.MainFrame.Position = UDim2.new(
                self.DragStartPosition.X.Scale,
                self.DragStartPosition.X.Offset + delta.X,
                self.DragStartPosition.Y.Scale,
                self.DragStartPosition.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.Dragging = false
        end
    end)
    
    -- Keybind for minimize (L key)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.L then
            self.MinimizeBtn:Activate()
        end
    end)
    
    -- Prevent sliders from dragging GUI
    local function preventSliderDrag(frame)
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self.Dragging = false
            end
        end)
    end
    
    preventSliderDrag(self.TweenSpeedSlider)
    preventSliderDrag(self.YOffsetSlider)
    
    -- Update loop
    spawn(function()
        while self.Enabled do
            self:UpdateStatus()
            wait(0.5)
        end
    end)
end

-- Public API
function MiningGUI:Show()
    if not self.ScreenGui then
        self:Create()
    else
        self.ScreenGui.Enabled = true
        self.Enabled = true
    end
end

function MiningGUI:Hide()
    if self.ScreenGui then
        self.ScreenGui.Enabled = false
        self.Enabled = false
    end
end

function MiningGUI:Toggle()
    if not self.ScreenGui or not self.ScreenGui.Enabled then
        self:Show()
    else
        self:Hide()
    end
end

-- Auto-create on load
task.wait(1)
MiningGUI:Create()

return MiningGUI
