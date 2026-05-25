-- Phantom Ball GUI v4.0
-- Carregado automaticamente pelo phantom_final.lua via loadstring

local timeout = 0
while not _G.PhantomConfig and timeout < 10 do
    task.wait(0.1); timeout += 0.1
end
if not _G.PhantomConfig then
    warn("Phantom GUI: lógica não encontrada em _G. Rode phantom_final.lua primeiro.")
    return
end

local Config     = _G.PhantomConfig
local State      = _G.PhantomState
local saveConfig = _G.PhantomSaveConfig

local Players      = game:GetService("Players")
local Workspace    = game:GetService("Workspace")
local UIS          = game:GetService("UserInputService")
local CoreGui      = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local function tw(obj, t, props, style, dir)
    return TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
end
local function twPlay(obj, t, props, style, dir) tw(obj, t, props, style, dir):Play() end
local function trackConn(c) State.connections[#State.connections + 1] = c end

-- ==================== SCREEN GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PhantomUISystem"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = CoreGui

-- ==================== BOTÃO FLUTUANTE ====================
local floatingButton = Instance.new("TextButton")
floatingButton.Size             = UDim2.new(0, 58, 0, 58)
floatingButton.Position         = Config.BtnX and UDim2.new(0, Config.BtnX, 0, Config.BtnY) or UDim2.new(1, -68, 0.5, -29)
floatingButton.BackgroundColor3 = Color3.fromRGB(28, 28, 48)
floatingButton.BorderSizePixel  = 0
floatingButton.Text             = "⚡"
floatingButton.TextColor3       = Color3.new(1, 1, 1)
floatingButton.TextSize         = 27
floatingButton.Font             = Enum.Font.GothamBold
floatingButton.Active           = true
floatingButton.ZIndex           = 10
floatingButton.Parent           = screenGui
Instance.new("UICorner", floatingButton).CornerRadius = UDim.new(1, 0)

local floatingStroke = Instance.new("UIStroke")
floatingStroke.Color     = Color3.fromRGB(70, 90, 200)
floatingStroke.Thickness = 2
floatingStroke.Parent    = floatingButton

floatingButton.MouseEnter:Connect(function() twPlay(floatingButton, 0.15, {Size = UDim2.new(0, 64, 0, 64), BackgroundColor3 = Color3.fromRGB(40, 40, 70)}) end)
floatingButton.MouseLeave:Connect(function() twPlay(floatingButton, 0.15, {Size = UDim2.new(0, 58, 0, 58), BackgroundColor3 = Color3.fromRGB(28, 28, 48)}) end)

-- ==================== PAINEL ====================
local PANEL_W, PANEL_H = 560, 360

local configPanel = Instance.new("Frame")
configPanel.Size                   = UDim2.new(0, PANEL_W, 0, PANEL_H)
configPanel.Position               = Config.PanelX and UDim2.new(0, Config.PanelX, 0, Config.PanelY) or UDim2.new(0.5, -PANEL_W/2, 0.5, -PANEL_H/2)
configPanel.BackgroundColor3       = Color3.fromRGB(8, 10, 22)
configPanel.BackgroundTransparency = 0.12
configPanel.BorderSizePixel        = 0
configPanel.Visible                = false
configPanel.ZIndex                 = 5
configPanel.Parent                 = screenGui
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

-- RGB animado
task.spawn(function()
    local t = 0
    while screenGui.Parent do
        t = t + 0.022
        local col = Color3.fromRGB(
            math.floor(60 + 80 * math.sin(t)),
            math.floor(80 + 90 * math.sin(t + 2.09)),
            255
        )
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
headerGlow.Size                   = UDim2.new(1, 0, 0, 1)
headerGlow.Position               = UDim2.new(0, 0, 1, -1)
headerGlow.BackgroundColor3       = Color3.fromRGB(100, 130, 255)
headerGlow.BackgroundTransparency = 0.5
headerGlow.BorderSizePixel        = 0
headerGlow.ZIndex                 = 7
headerGlow.Parent                 = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, -20, 1, 0)
titleLabel.Position               = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "⚡ Phantom UI Config"
titleLabel.TextColor3             = Color3.fromRGB(180, 195, 255)
titleLabel.TextSize               = 20
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.ZIndex                 = 6
titleLabel.Parent                 = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size             = UDim2.new(0, 30, 0, 30)
closeButton.Position         = UDim2.new(1, -40, 0, 10)
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
colLeft.Size                  = UDim2.new(0, 250, 1, -60)
colLeft.Position              = UDim2.new(0, 10, 0, 55)
colLeft.BackgroundTransparency = 1
colLeft.ZIndex                = 6
colLeft.Parent                = configPanel

local colRight = Instance.new("Frame")
colRight.Size                  = UDim2.new(0, 250, 1, -60)
colRight.Position              = UDim2.new(0, 300, 0, 55)
colRight.BackgroundTransparency = 1
colRight.ZIndex                = 6
colRight.Parent                = configPanel

local divider = Instance.new("Frame")
divider.Size                  = UDim2.new(0, 1, 1, -70)
divider.Position              = UDim2.new(0, 280, 0, 60)
divider.BackgroundColor3      = Color3.fromRGB(70, 90, 200)
divider.BackgroundTransparency = 0.6
divider.BorderSizePixel       = 0
divider.ZIndex                = 6
divider.Parent                = configPanel

-- ==================== KILL BTN ====================
local killBtn = Instance.new("TextButton")
killBtn.Size             = UDim2.new(0, 160, 0, 34)
killBtn.Position         = UDim2.new(0.5, -80, 1, -42)
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

-- ==================== DRAG INTELIGENTE (threshold 5px) ====================
local DRAG_THRESHOLD = 5

local function makeDraggable(handle, target, onDragEnd)
    local dragging  = false
    local didDrag   = false
    local dragStart = nil
    local startPos  = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging  = false
        didDrag   = false
        dragStart = input.Position
        startPos  = target.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging and onDragEnd then
                    onDragEnd()
                end
                dragging = false
                task.defer(function() didDrag = false end)
            end
        end)
    end)

    local function onMove(input)
        if not dragStart then return end
        local delta = input.Position - dragStart
        if not dragging then
            if delta.Magnitude >= DRAG_THRESHOLD then
                dragging = true
                didDrag  = true
            else
                return
            end
        end
        local vpSize = Workspace.CurrentCamera.ViewportSize
        local tSize  = target.AbsoluteSize
        target.Position = UDim2.new(0,
            math.clamp(startPos.X.Offset + delta.X, 0, vpSize.X - tSize.X), 0,
            math.clamp(startPos.Y.Offset + delta.Y, 0, vpSize.Y - tSize.Y))
    end

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            onMove(input)
        end
    end)
    trackConn(UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            onMove(input)
        end
    end))

    -- retorna função para checar se o último InputEnded foi drag (útil pra suprimir clique)
    return function() return didDrag end
end

-- Drag do painel
makeDraggable(titleBar, configPanel, function()
    Config.PanelX = configPanel.Position.X.Offset
    Config.PanelY = configPanel.Position.Y.Offset
    saveConfig(Config)
end)

-- Drag do botão flutuante
local btnWasDrag = makeDraggable(floatingButton, floatingButton, function()
    Config.BtnX = floatingButton.Position.X.Offset
    Config.BtnY = floatingButton.Position.Y.Offset
    saveConfig(Config)
end)

-- ==================== HELPERS DE CARD ====================
local function cardFrame(yPos, h, parent)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, -10, 0, h)
    f.Position         = UDim2.new(0, 5, 0, yPos)
    f.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
    f.BorderSizePixel  = 0
    f.ZIndex           = 6
    f.Parent           = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    return f
end

local function cardLabel(text, parent)
    local l = Instance.new("TextLabel")
    l.Size                   = UDim2.new(1, -10, 0, 20)
    l.Position               = UDim2.new(0, 8, 0, 6)
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextColor3             = Color3.fromRGB(140, 155, 220)
    l.TextSize               = 12
    l.Font                   = Enum.Font.GothamBold
    l.TextXAlignment         = Enum.TextXAlignment.Left
    l.ZIndex                 = 6
    l.Parent                 = parent
end

local function smallBtn(text, x, y, w, h, parent)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, w, 0, h)
    b.Position         = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 75)
    b.BorderSizePixel  = 0
    b.Text             = text
    b.TextColor3       = Color3.new(1, 1, 1)
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamBold
    b.ZIndex           = 6
    b.Parent           = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

-- ==================== TOGGLE HELPER ====================
local function createToggle(name, configKey, yPos, parentFrame)
    local f = cardFrame(yPos, 50, parentFrame)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.6, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 15, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = name
    lbl.TextColor3             = Color3.new(1, 1, 1)
    lbl.TextSize               = 16
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 6
    lbl.Parent                 = f

    local toggle = Instance.new("TextButton")
    toggle.Size             = UDim2.new(0, 80, 0, 35)
    toggle.Position         = UDim2.new(1, -90, 0.5, -17.5)
    toggle.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(80, 80, 90)
    toggle.BorderSizePixel  = 0
    toggle.Text             = Config[configKey] and "ON" or "OFF"
    toggle.TextColor3       = Color3.new(1, 1, 1)
    toggle.TextSize         = 14
    toggle.Font             = Enum.Font.GothamBold
    toggle.ZIndex           = 6
    toggle.Parent           = f
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

-- ==================== CPS + KEYBIND (col esquerda, painel) ====================
local function createInputRow(labelText, yPos, parentFrame, defaultVal, placeholderText, onDefault, onFocusLost)
    local f = cardFrame(yPos, 50, parentFrame)

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(0, 60, 1, 0)
    label.Position               = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text                   = labelText
    label.TextColor3             = Color3.new(1, 1, 1)
    label.TextSize               = 16
    label.Font                   = Enum.Font.Gotham
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.ZIndex                 = 6
    label.Parent                 = f

    local defaultBtn = Instance.new("TextButton")
    defaultBtn.Size             = UDim2.new(0, 70, 0, 35)
    defaultBtn.Position         = UDim2.new(0, 80, 0.5, -17.5)
    defaultBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    defaultBtn.BorderSizePixel  = 0
    defaultBtn.Text             = "Padrão"
    defaultBtn.TextColor3       = Color3.new(1, 1, 1)
    defaultBtn.TextSize         = 12
    defaultBtn.Font             = Enum.Font.GothamBold
    defaultBtn.ZIndex           = 6
    defaultBtn.Parent           = f
    Instance.new("UICorner", defaultBtn).CornerRadius = UDim.new(0, 8)

    local customInput = Instance.new("TextBox")
    customInput.Size             = UDim2.new(0, 80, 0, 35)
    customInput.Position         = UDim2.new(1, -90, 0.5, -17.5)
    customInput.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
    customInput.BorderSizePixel  = 0
    customInput.Text             = defaultVal or ""
    customInput.PlaceholderText  = placeholderText or ""
    customInput.TextColor3       = Color3.new(1, 1, 1)
    customInput.TextSize         = 14
    customInput.Font             = Enum.Font.Gotham
    customInput.ZIndex           = 6
    customInput.Parent           = f
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

local function createKeybindSelector(yPos, parentFrame)
    local f = cardFrame(yPos, 50, parentFrame)

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(0.5, 0, 1, 0)
    label.Position               = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text                   = "Tecla de Atalho:"
    label.TextColor3             = Color3.new(1, 1, 1)
    label.TextSize               = 16
    label.Font                   = Enum.Font.Gotham
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.ZIndex                 = 6
    label.Parent                 = f

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size             = UDim2.new(0, 100, 0, 35)
    keybindBtn.Position         = UDim2.new(1, -110, 0.5, -17.5)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
    keybindBtn.BorderSizePixel  = 0
    keybindBtn.Text             = Config.Keybind.Name
    keybindBtn.TextColor3       = Color3.new(1, 1, 1)
    keybindBtn.TextSize         = 14
    keybindBtn.Font             = Enum.Font.GothamBold
    keybindBtn.ZIndex           = 6
    keybindBtn.Parent           = f
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

-- ==================== MINI GUI (spam ON/OFF arrastável) ====================
local miniGui = Instance.new("Frame")
miniGui.Name             = "PhantomSpamMini"
miniGui.Size             = UDim2.new(0, 120, 0, 95)
miniGui.Position         = UDim2.new(1, -130, 0.5, -47)
miniGui.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
miniGui.BorderSizePixel  = 0
miniGui.Visible          = false
miniGui.ZIndex           = 15
miniGui.Parent           = screenGui
Instance.new("UICorner", miniGui).CornerRadius = UDim.new(0, 14)

local miniStroke = Instance.new("UIStroke")
miniStroke.Color     = Color3.fromRGB(70, 90, 200)
miniStroke.Thickness = 1.5
miniStroke.Parent    = miniGui

task.spawn(function()
    local t = 0
    while miniStroke.Parent do
        t = t + 0.025
        miniStroke.Color = Color3.fromRGB(
            math.floor(70 + 70 * math.sin(t)),
            math.floor(90 + 80 * math.sin(t + 2.1)),
            255
        )
        task.wait(0.05)
    end
end)

local miniTitleBar = Instance.new("Frame")
miniTitleBar.Size             = UDim2.new(1, 0, 0, 24)
miniTitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
miniTitleBar.BorderSizePixel  = 0
miniTitleBar.ZIndex           = 16
miniTitleBar.Parent           = miniGui
Instance.new("UICorner", miniTitleBar).CornerRadius = UDim.new(0, 14)

local miniTitle = Instance.new("TextLabel")
miniTitle.Size                   = UDim2.new(1, -6, 1, 0)
miniTitle.Position               = UDim2.new(0, 6, 0, 0)
miniTitle.BackgroundTransparency = 1
miniTitle.Text                   = "Spam"
miniTitle.TextColor3             = Color3.fromRGB(180, 195, 255)
miniTitle.TextScaled             = true
miniTitle.Font                   = Enum.Font.GothamBold
miniTitle.ZIndex                 = 16
miniTitle.Parent                 = miniTitleBar

local spamBtn = Instance.new("TextButton")
spamBtn.Size             = UDim2.new(0.85, 0, 0, 52)
spamBtn.Position         = UDim2.new(0.075, 0, 0, 30)
spamBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
spamBtn.BorderSizePixel  = 0
spamBtn.Text             = "OFF"
spamBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
spamBtn.TextScaled       = true
spamBtn.Font             = Enum.Font.GothamBold
spamBtn.ZIndex           = 16
spamBtn.Parent           = miniGui
Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0, 10)

local spamOn = false
local function setSpam(v)
    spamOn = v
    _G.PhantomManual         = v
    spamBtn.Text             = v and "ON" or "OFF"
    spamBtn.BackgroundColor3 = v and Color3.fromRGB(50, 220, 50) or Color3.fromRGB(220, 50, 50)
end

spamBtn.Activated:Connect(function() setSpam(not spamOn) end)

-- keybind hold/toggle via UIS
trackConn(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not Config.SpamKeybind then return end
    if input.KeyCode ~= Config.SpamKeybind then return end
    if Config.SpamMode == "Hold" then
        setSpam(true)
    else
        setSpam(not spamOn)
    end
end))
trackConn(UIS.InputEnded:Connect(function(input)
    if not Config.SpamKeybind then return end
    if input.KeyCode ~= Config.SpamKeybind then return end
    if Config.SpamMode == "Hold" then setSpam(false) end
end))

-- drag da mini GUI
makeDraggable(miniTitleBar, miniGui, nil)

-- ==================== CARD — SPAM CONFIG ====================
local function createSpamConfigCard(yPos, parentFrame)
    local f = cardFrame(yPos, 120, parentFrame)
    cardLabel("Spam Config", f)

    -- show/hide mini GUI
    local visBtn = smallBtn("Spam: Oculto", 8, 28, 230, 34, f)
    visBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)

    visBtn.Activated:Connect(function()
        miniGui.Visible          = not miniGui.Visible
        visBtn.Text              = miniGui.Visible and "Spam: Visível" or "Spam: Oculto"
        visBtn.BackgroundColor3  = miniGui.Visible and Color3.fromRGB(0, 150, 80) or Color3.fromRGB(80, 80, 90)
    end)

    -- modo Hold/Toggle
    local modeBtn = smallBtn(Config.SpamMode or "Toggle", 8, 70, 110, 34, f)
    modeBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 100)

    modeBtn.Activated:Connect(function()
        Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = Config.SpamMode
        if Config.SpamMode == "Hold" and spamOn then setSpam(false) end
        saveConfig(Config)
    end)

    -- keybind
    local kbBtn = smallBtn(Config.SpamKeybind and Config.SpamKeybind.Name or "X", 126, 70, 112, 34, f)
    kbBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 110)

    local listeningKb = false
    kbBtn.Activated:Connect(function()
        if listeningKb then return end
        listeningKb = true
        kbBtn.Text             = "..."
        kbBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 160)
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Config.SpamKeybind     = input.KeyCode
                kbBtn.Text             = input.KeyCode.Name
                kbBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 110)
                listeningKb = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)

    return yPos + 130
end

-- ==================== CARD — AUTO CLASH ====================
local function createAutoClashCard(yPos, parentFrame)
    local f = cardFrame(yPos, 60, parentFrame)
    cardLabel("Auto Clash", f)

    local clashOn = false
    local btn = smallBtn("OFF", 8, 28, 230, 26, f)
    btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

    btn.Activated:Connect(function()
        clashOn = not clashOn
        _G.PhantomAutoClash  = clashOn
        btn.Text             = clashOn and "ON" or "OFF"
        btn.BackgroundColor3 = clashOn and Color3.fromRGB(50, 220, 50) or Color3.fromRGB(200, 50, 50)
    end)

    return yPos + 70
end

-- ==================== CRIANDO ELEMENTOS ====================
local yL, yR = 5, 5
-- Coluna esquerda: Auto Parry + Aura
yL = createToggle("Auto Parry",  "AutoParry", yL, colLeft)
yL = createToggle("Aura Visual", "Aura",      yL, colLeft)

-- Coluna direita: CPS + Keybind painel + Spam Config + Auto Clash
yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)
yR = createSpamConfigCard(yR, colRight)
yR = createAutoClashCard(yR, colRight)

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

floatingButton.Activated:Connect(function()
    if btnWasDrag and btnWasDrag() then return end
    togglePanel()
end)
closeButton.Activated:Connect(togglePanel)

trackConn(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.Keybind then togglePanel() end
end))

-- ==================== FECHAR SCRIPT ====================
killBtn.Activated:Connect(function()
    State.scriptActive  = false
    _G.PhantomManual    = false
    _G.PhantomAutoClash = false
    saveConfig(Config)

    twPlay(configPanel,    0.3, {BackgroundTransparency = 1, Size = UDim2.new(0, PANEL_W * 0.85, 0, PANEL_H * 0.85)}, Enum.EasingStyle.Quint)
    twPlay(floatingButton, 0.3, {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})

    task.wait(0.35)
    for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() State.outer:Destroy() end)
    pcall(function() State.inner:Destroy() end)
    pcall(function() screenGui:Destroy() end)
    print("🛑 Phantom Script encerrado.")
end)

print("✅ Phantom GUI v4.0 carregada!")
print("   • Botão ⚡ para configurar | tecla padrão: " .. Config.Keybind.Name)
