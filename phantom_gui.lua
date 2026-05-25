-- Phantom Ball ULTIMATE v3.0 | GUI
-- Carregado automaticamente pelo phantom_logic.lua via loadstring

-- Aguarda a lógica terminar de popular o _G
local timeout = 0
while not _G.PhantomConfig and timeout < 10 do
    task.wait(0.1)
    timeout += 0.1
end
if not _G.PhantomConfig then
    warn("Phantom GUI: lógica não encontrada em _G. Rode phantom_logic.lua primeiro.")
    return
end

local Config    = _G.PhantomConfig
local State     = _G.PhantomState
local saveConfig = _G.PhantomSaveConfig

local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")
local UIS           = game:GetService("UserInputService")
local CoreGui       = game:GetService("CoreGui")
local TweenService  = game:GetService("TweenService")

local function tw(obj, t, props, style, dir)
    return TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
end
local function twPlay(obj, t, props, style, dir)
    tw(obj, t, props, style, dir):Play()
end
local function trackConn(c) State.connections[#State.connections+1] = c end

-- ==================== SCREEN GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PhantomUISystem"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = CoreGui

-- ==================== BOTÃO FLUTUANTE ====================
local floatingButton = Instance.new("TextButton")
floatingButton.Size              = UDim2.new(0, 58, 0, 58)
floatingButton.Position          = Config.BtnX and UDim2.new(0, Config.BtnX, 0, Config.BtnY)
                                   or UDim2.new(1, -68, 0.5, -29)
floatingButton.BackgroundColor3  = Color3.fromRGB(28, 28, 48)
floatingButton.BorderSizePixel   = 0
floatingButton.Text              = "⚡"
floatingButton.TextColor3        = Color3.new(1, 1, 1)
floatingButton.TextSize          = 27
floatingButton.Font              = Enum.Font.GothamBold
floatingButton.Active            = true
floatingButton.ZIndex            = 10
floatingButton.Parent            = screenGui

Instance.new("UICorner", floatingButton).CornerRadius = UDim.new(1, 0)

local floatingStroke = Instance.new("UIStroke")
floatingStroke.Color     = Color3.fromRGB(70, 90, 200)
floatingStroke.Thickness = 2
floatingStroke.Parent    = floatingButton

floatingButton.MouseEnter:Connect(function()
    twPlay(floatingButton, 0.15, {Size = UDim2.new(0, 64, 0, 64), BackgroundColor3 = Color3.fromRGB(40, 40, 70)})
end)
floatingButton.MouseLeave:Connect(function()
    twPlay(floatingButton, 0.15, {Size = UDim2.new(0, 58, 0, 58), BackgroundColor3 = Color3.fromRGB(28, 28, 48)})
end)

-- ==================== PAINEL ====================
local PANEL_W, PANEL_H = 560, 280

local configPanel = Instance.new("Frame")
configPanel.Size                    = UDim2.new(0, PANEL_W, 0, PANEL_H)
configPanel.Position                = Config.PanelX and UDim2.new(0, Config.PanelX, 0, Config.PanelY)
                                      or UDim2.new(0.5, -PANEL_W/2, 0.5, -PANEL_H/2)
configPanel.BackgroundColor3        = Color3.fromRGB(8, 10, 22)
configPanel.BackgroundTransparency  = 0.12
configPanel.BorderSizePixel         = 0
configPanel.Visible                 = false
configPanel.ZIndex                  = 5
configPanel.Parent                  = screenGui

Instance.new("UICorner", configPanel).CornerRadius = UDim.new(0, 16)

local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(8,  12, 34)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 10, 22)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(18,  8, 30)),
})
panelGrad.Rotation = 140
panelGrad.Parent   = configPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = Color3.fromRGB(70, 90, 200)
panelStroke.Thickness = 1.8
panelStroke.Parent    = configPanel

-- RGB animado (bolinha + painel)
task.spawn(function()
    local t = 0
    while screenGui.Parent do
        t = t + 0.022
        local r   = math.floor(60 + 80 * math.sin(t))
        local g   = math.floor(80 + 90 * math.sin(t + 2.09))
        local col = Color3.fromRGB(r, g, 255)
        panelStroke.Color    = col
        floatingStroke.Color = col
        task.wait(0.05)
    end
end)

-- ==================== TITLE BAR ====================
local titleBar = Instance.new("Frame")
titleBar.Size                   = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3       = Color3.fromRGB(18, 18, 38)
titleBar.BackgroundTransparency = 0.2
titleBar.BorderSizePixel        = 0
titleBar.ZIndex                 = 6
titleBar.Parent                 = configPanel

Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local headerGlow = Instance.new("Frame")
headerGlow.Size                 = UDim2.new(1, 0, 0, 1)
headerGlow.Position             = UDim2.new(0, 0, 1, -1)
headerGlow.BackgroundColor3     = Color3.fromRGB(100, 130, 255)
headerGlow.BackgroundTransparency = 0.5
headerGlow.BorderSizePixel      = 0
headerGlow.ZIndex               = 7
headerGlow.Parent               = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size             = UDim2.new(1, -20, 1, 0)
titleLabel.Position         = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text             = "⚡ Phantom UI Config"
titleLabel.TextColor3       = Color3.fromRGB(180, 195, 255)
titleLabel.TextSize         = 20
titleLabel.Font             = Enum.Font.GothamBold
titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
titleLabel.ZIndex           = 6
titleLabel.Parent           = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size            = UDim2.new(0, 30, 0, 30)
closeButton.Position        = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.BorderSizePixel  = 0
closeButton.Text             = "✕"
closeButton.TextColor3       = Color3.new(1, 1, 1)
closeButton.TextSize         = 18
closeButton.Font             = Enum.Font.GothamBold
closeButton.ZIndex           = 6
closeButton.Parent           = titleBar

Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

closeButton.MouseEnter:Connect(function() twPlay(closeButton, 0.15, {BackgroundColor3 = Color3.fromRGB(230, 60, 60)}) end)
closeButton.MouseLeave:Connect(function() twPlay(closeButton, 0.15, {BackgroundColor3 = Color3.fromRGB(200, 50, 50)}) end)

-- ==================== COLUNAS ====================
local colLeft = Instance.new("Frame")
colLeft.Size                = UDim2.new(0, 250, 1, -60)
colLeft.Position            = UDim2.new(0, 10, 0, 55)
colLeft.BackgroundTransparency = 1
colLeft.ZIndex              = 6
colLeft.Parent              = configPanel

local colRight = Instance.new("Frame")
colRight.Size               = UDim2.new(0, 250, 1, -60)
colRight.Position           = UDim2.new(0, 300, 0, 55)
colRight.BackgroundTransparency = 1
colRight.ZIndex             = 6
colRight.Parent             = configPanel

local divider = Instance.new("Frame")
divider.Size                = UDim2.new(0, 1, 1, -70)
divider.Position            = UDim2.new(0, 280, 0, 60)
divider.BackgroundColor3    = Color3.fromRGB(70, 90, 200)
divider.BackgroundTransparency = 0.6
divider.BorderSizePixel     = 0
divider.ZIndex              = 6
divider.Parent              = configPanel

-- ==================== KILL BTN ====================
local killBtn = Instance.new("TextButton")
killBtn.Size            = UDim2.new(0, 160, 0, 34)
killBtn.Position        = UDim2.new(0.5, -80, 1, -44)
killBtn.BackgroundColor3 = Color3.fromRGB(130, 25, 25)
killBtn.BorderSizePixel  = 0
killBtn.Text             = "🛑  Fechar Script"
killBtn.TextColor3       = Color3.fromRGB(255, 195, 195)
killBtn.TextSize         = 14
killBtn.Font             = Enum.Font.GothamBold
killBtn.ZIndex           = 7
killBtn.Parent           = configPanel

Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 9)

local killStroke = Instance.new("UIStroke")
killStroke.Color     = Color3.fromRGB(200, 45, 45)
killStroke.Thickness = 1.2
killStroke.Parent    = killBtn

killBtn.MouseEnter:Connect(function() twPlay(killBtn, 0.18, {BackgroundColor3 = Color3.fromRGB(195, 35, 35), Size = UDim2.new(0, 168, 0, 36)}, Enum.EasingStyle.Quint) end)
killBtn.MouseLeave:Connect(function() twPlay(killBtn, 0.18, {BackgroundColor3 = Color3.fromRGB(130, 25, 25), Size = UDim2.new(0, 160, 0, 34)}, Enum.EasingStyle.Quint) end)

-- ==================== DRAG PAINEL ====================
local panelDragging, panelDragStart, panelStartPos = false, nil, nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        panelDragging  = true
        panelDragStart = input.Position
        panelStartPos  = configPanel.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                panelDragging = false
                Config.PanelX = configPanel.Position.X.Offset
                Config.PanelY = configPanel.Position.Y.Offset
                saveConfig(Config)
            end
        end)
    end
end)

local function updatePanelDrag(input)
    if not panelDragging or not panelDragStart or not panelStartPos then return end
    local delta  = input.Position - panelDragStart
    local vpSize = Workspace.CurrentCamera.ViewportSize
    configPanel.Position = UDim2.new(0,
        math.clamp(panelStartPos.X.Offset + delta.X, 0, vpSize.X - PANEL_W), 0,
        math.clamp(panelStartPos.Y.Offset + delta.Y, 0, vpSize.Y - PANEL_H))
end

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updatePanelDrag(input)
    end
end)
trackConn(UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updatePanelDrag(input)
    end
end))

-- ==================== DRAG BOTÃO FLUTUANTE ====================
local dragging, dragStart, startPos = false, nil, nil

floatingButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = floatingButton.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                Config.BtnX = floatingButton.Position.X.Offset
                Config.BtnY = floatingButton.Position.Y.Offset
                saveConfig(Config)
            end
        end)
    end
end)

local function updateBtnDrag(input)
    if not dragging or not dragStart or not startPos then return end
    local delta  = input.Position - dragStart
    local vpSize = Workspace.CurrentCamera.ViewportSize
    local fSize  = floatingButton.AbsoluteSize
    floatingButton.Position = UDim2.new(0,
        math.clamp(startPos.X.Offset + delta.X, 0, vpSize.X - fSize.X), 0,
        math.clamp(startPos.Y.Offset + delta.Y, 0, vpSize.Y - fSize.Y))
end

floatingButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        updateBtnDrag(input)
    end
end)
trackConn(UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.Touch then updateBtnDrag(input) end
end))

-- ==================== TOGGLE / CPS / PING / KEYBIND ====================
local function createToggle(name, configKey, yPos, parentFrame)
    local frame = Instance.new("Frame")
    frame.Size            = UDim2.new(1, -10, 0, 50)
    frame.Position        = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    frame.BorderSizePixel  = 0
    frame.ZIndex          = 6
    frame.Parent          = parentFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size            = UDim2.new(0.6, 0, 1, 0)
    label.Position        = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text            = name
    label.TextColor3      = Color3.new(1, 1, 1)
    label.TextSize        = 16
    label.Font            = Enum.Font.Gotham
    label.TextXAlignment  = Enum.TextXAlignment.Left
    label.ZIndex          = 6
    label.Parent          = frame

    local toggle = Instance.new("TextButton")
    toggle.Size            = UDim2.new(0, 80, 0, 35)
    toggle.Position        = UDim2.new(1, -90, 0.5, -17.5)
    toggle.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(80, 80, 90)
    toggle.BorderSizePixel  = 0
    toggle.Text            = Config[configKey] and "ON" or "OFF"
    toggle.TextColor3      = Color3.new(1, 1, 1)
    toggle.TextSize        = 14
    toggle.Font            = Enum.Font.GothamBold
    toggle.ZIndex          = 6
    toggle.Parent          = frame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

    toggle.MouseEnter:Connect(function() twPlay(toggle, 0.12, {Size = UDim2.new(0, 84, 0, 37)}) end)
    toggle.MouseLeave:Connect(function() twPlay(toggle, 0.12, {Size = UDim2.new(0, 80, 0, 35)}) end)
    toggle.Activated:Connect(function()
        Config[configKey] = not Config[configKey]
        tw(toggle, 0.2, {BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 200, 110) or Color3.fromRGB(70, 70, 85)}, Enum.EasingStyle.Back):Play()
        toggle.Text = Config[configKey] and "ON" or "OFF"
        saveConfig(Config)
    end)
    return yPos + 60
end

local function createInputRow(labelText, yPos, parentFrame, defaultVal, placeholderText, onDefault, onFocusLost)
    local frame = Instance.new("Frame")
    frame.Size            = UDim2.new(1, -10, 0, 50)
    frame.Position        = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    frame.BorderSizePixel  = 0
    frame.ZIndex          = 6
    frame.Parent          = parentFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size            = UDim2.new(0, 60, 1, 0)
    label.Position        = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text            = labelText
    label.TextColor3      = Color3.new(1, 1, 1)
    label.TextSize        = 16
    label.Font            = Enum.Font.Gotham
    label.TextXAlignment  = Enum.TextXAlignment.Left
    label.ZIndex          = 6
    label.Parent          = frame

    local defaultBtn = Instance.new("TextButton")
    defaultBtn.Size            = UDim2.new(0, 70, 0, 35)
    defaultBtn.Position        = UDim2.new(0, 80, 0.5, -17.5)
    defaultBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    defaultBtn.BorderSizePixel  = 0
    defaultBtn.Text            = "Padrão"
    defaultBtn.TextColor3      = Color3.new(1, 1, 1)
    defaultBtn.TextSize        = 12
    defaultBtn.Font            = Enum.Font.GothamBold
    defaultBtn.ZIndex          = 6
    defaultBtn.Parent          = frame
    Instance.new("UICorner", defaultBtn).CornerRadius = UDim.new(0, 8)

    local customInput = Instance.new("TextBox")
    customInput.Size            = UDim2.new(0, 80, 0, 35)
    customInput.Position        = UDim2.new(1, -90, 0.5, -17.5)
    customInput.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    customInput.BorderSizePixel  = 0
    customInput.Text            = defaultVal or ""
    customInput.PlaceholderText = placeholderText or ""
    customInput.TextColor3      = Color3.new(1, 1, 1)
    customInput.TextSize        = 14
    customInput.Font            = Enum.Font.Gotham
    customInput.ZIndex          = 6
    customInput.Parent          = frame
    Instance.new("UICorner", customInput).CornerRadius = UDim.new(0, 8)

    defaultBtn.Activated:Connect(function() onDefault(defaultBtn, customInput) end)
    customInput.FocusLost:Connect(function() onFocusLost(defaultBtn, customInput) end)

    return yPos + 60
end

local function createCPSSelector(yPos, parentFrame)
    return createInputRow("CPS:", yPos, parentFrame, tostring(Config.CPS), "CPS",
        function(btn, input)
            Config.CustomCPS = false; Config.CPS = 22; input.Text = "22"
            btn.BackgroundColor3 = Color3.fromRGB(0, 180, 100); saveConfig(Config)
        end,
        function(btn, input)
            local v = tonumber(input.Text)
            if v and v > 0 and v <= 1000 then Config.CPS = v; Config.CustomCPS = true; btn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            else input.Text = tostring(Config.CPS) end
            saveConfig(Config)
        end)
end

local function createPingSelector(yPos, parentFrame)
    return createInputRow("Ping:", yPos, parentFrame,
        Config.CustomPing and tostring(Config.PingMS) or "", "ms",
        function(btn, input)
            Config.CustomPing = false; Config.PingMS = 80; input.Text = ""
            tw(btn, 0.2, {BackgroundColor3 = Color3.fromRGB(0, 180, 100)}, Enum.EasingStyle.Back):Play(); saveConfig(Config)
        end,
        function(btn, input)
            local v = tonumber(input.Text)
            if v and v >= 1 and v <= 1000 then Config.PingMS = v; Config.CustomPing = true; tw(btn, 0.2, {BackgroundColor3 = Color3.fromRGB(80, 80, 90)}, Enum.EasingStyle.Back):Play()
            else input.Text = Config.CustomPing and tostring(Config.PingMS) or "" end
            saveConfig(Config)
        end)
end

local function createKeybindSelector(yPos, parentFrame)
    local frame = Instance.new("Frame")
    frame.Size            = UDim2.new(1, -10, 0, 50)
    frame.Position        = UDim2.new(0, 5, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    frame.BorderSizePixel  = 0
    frame.ZIndex          = 6
    frame.Parent          = parentFrame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel")
    label.Size            = UDim2.new(0.5, 0, 1, 0)
    label.Position        = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text            = "Tecla de Atalho:"
    label.TextColor3      = Color3.new(1, 1, 1)
    label.TextSize        = 16
    label.Font            = Enum.Font.Gotham
    label.TextXAlignment  = Enum.TextXAlignment.Left
    label.ZIndex          = 6
    label.Parent          = frame

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size            = UDim2.new(0, 100, 0, 35)
    keybindBtn.Position        = UDim2.new(1, -110, 0.5, -17.5)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    keybindBtn.BorderSizePixel  = 0
    keybindBtn.Text            = Config.Keybind.Name
    keybindBtn.TextColor3      = Color3.new(1, 1, 1)
    keybindBtn.TextSize        = 14
    keybindBtn.Font            = Enum.Font.GothamBold
    keybindBtn.ZIndex          = 6
    keybindBtn.Parent          = frame
    Instance.new("UICorner", keybindBtn).CornerRadius = UDim.new(0, 8)

    keybindBtn.MouseEnter:Connect(function() twPlay(keybindBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(75, 75, 125)}) end)
    keybindBtn.MouseLeave:Connect(function() twPlay(keybindBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(60, 60, 100)}) end)

    local listening = false
    keybindBtn.Activated:Connect(function()
        if listening then return end
        listening = true
        keybindBtn.Text = "..."
        keybindBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Config.Keybind = input.KeyCode
                keybindBtn.Text = input.KeyCode.Name
                tw(keybindBtn, 0.2, {BackgroundColor3 = Color3.fromRGB(60, 60, 100)}, Enum.EasingStyle.Back):Play()
                listening = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)
    return yPos + 60
end

-- ==================== CRIANDO ELEMENTOS ====================
local yL, yR = 5, 5
yL = createToggle("Auto Parry",   "AutoParry",        yL, colLeft)
yL = createToggle("Aura Visual",  "Aura",             yL, colLeft)
yL = createToggle("Comp. de Ping","PingCompensation", yL, colLeft)
yR = createPingSelector(yR, colRight)
yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)

-- ==================== ABRIR / FECHAR PAINEL ====================
local panelOpen = false
local tweenOpen, tweenClose

local function togglePanel()
    panelOpen = not panelOpen
    if tweenOpen  then tweenOpen:Cancel()  end
    if tweenClose then tweenClose:Cancel() end

    if panelOpen then
        configPanel.Visible = true
        configPanel.BackgroundTransparency = 1
        configPanel.Size = UDim2.new(0, PANEL_W * 0.88, 0, PANEL_H * 0.88)
        tweenOpen = tw(configPanel, 0.45,
            { Size = UDim2.new(0, PANEL_W, 0, PANEL_H), BackgroundTransparency = 0.12 },
            Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tweenOpen:Play()
    else
        tweenClose = tw(configPanel, 0.28,
            { Size = UDim2.new(0, PANEL_W * 0.9, 0, PANEL_H * 0.9), BackgroundTransparency = 1 },
            Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tweenClose:Play()
        tweenClose.Completed:Connect(function() configPanel.Visible = false end)
    end
end

floatingButton.Activated:Connect(togglePanel)
closeButton.Activated:Connect(togglePanel)

trackConn(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.Keybind then togglePanel() end
end))

-- ==================== FECHAR SCRIPT ====================
killBtn.Activated:Connect(function()
    State.scriptActive = false
    saveConfig(Config)

    twPlay(configPanel, 0.3, {BackgroundTransparency = 1, Size = UDim2.new(0, PANEL_W * 0.85, 0, PANEL_H * 0.85)}, Enum.EasingStyle.Quint)
    twPlay(floatingButton, 0.3, {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})

    task.wait(0.35)

    for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() State.outer:Destroy() end)
    pcall(function() State.inner:Destroy() end)
    pcall(function() screenGui:Destroy() end)

    print("🛑 Phantom Script encerrado.")
end)

print("✅ Phantom GUI v3.0 carregada!")
print("   • Clique no botão ⚡ para configurar")
print("   • Tecla padrão: " .. Config.Keybind.Name)