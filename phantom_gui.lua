-- Phantom Ball GUI v5.1
-- Carregado automaticamente pelo phantom_final.lua via loadstring

local timeout = 0
while not _G.PhantomConfig and timeout < 10 do
    task.wait(0.1); timeout += 0.1
end
if not _G.PhantomConfig then
    warn("Phantom GUI: lógica não encontrada. Rode phantom_final.lua primeiro.")
    return
end

local Config     = _G.PhantomConfig
local State      = _G.PhantomState
local saveConfig = _G.PhantomSaveConfig

local Workspace    = game:GetService("Workspace")
local UIS          = game:GetService("UserInputService")
local CoreGui      = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local function tw(obj, t, props, style, dir)
    return TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
end
local function twPlay(obj, t, props, style, dir) tw(obj, t, props, style, dir):Play() end
local function trackConn(c) State.connections[#State.connections + 1] = c end

-- ==================== CORES ====================
local C = {
    bg      = Color3.fromRGB(10, 11, 24),
    header  = Color3.fromRGB(16, 17, 36),
    card    = Color3.fromRGB(20, 21, 40),
    accent  = Color3.fromRGB(90, 110, 255),
    green   = Color3.fromRGB(40, 210, 110),
    red     = Color3.fromRGB(220, 50, 55),
    redDark = Color3.fromRGB(140, 28, 28),
    text    = Color3.fromRGB(220, 225, 255),
    subtext = Color3.fromRGB(130, 140, 190),
    divider = Color3.fromRGB(35, 38, 70),
    inputBg = Color3.fromRGB(14, 15, 32),
    btnBlue = Color3.fromRGB(45, 55, 115),
    btnDark = Color3.fromRGB(30, 32, 60),
}

-- ==================== SCREEN GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PhantomUISystem"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = CoreGui

-- ==================== DRAG ====================
local DRAG_THRESHOLD = 5

local function makeDraggable(handle, target, onDragEnd)
    local dragging, didDrag, dragStart, startPos = false, false, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging  = false
        didDrag   = false
        dragStart = input.Position
        startPos  = target.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging and onDragEnd then onDragEnd() end
                dragging = false
                task.defer(function() didDrag = false end)
            end
        end)
    end)

    local function onMove(input)
        if not dragStart then return end
        local delta = input.Position - dragStart
        if not dragging then
            if delta.Magnitude >= DRAG_THRESHOLD then dragging = true; didDrag = true
            else return end
        end
        local vp  = Workspace.CurrentCamera.ViewportSize
        local tSz = target.AbsoluteSize
        target.Position = UDim2.new(0,
            math.clamp(startPos.X.Offset + delta.X, 0, vp.X - tSz.X), 0,
            math.clamp(startPos.Y.Offset + delta.Y, 0, vp.Y - tSz.Y))
    end

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then onMove(input) end
    end)
    trackConn(UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then onMove(input) end
    end))

    return function() return didDrag end
end

-- ==================== MINI GUI SPAM (flutuante, sempre na tela) ====================
local miniGui = Instance.new("Frame")
miniGui.Name             = "PhantomSpamMini"
miniGui.Size             = UDim2.new(0, 110, 0, 80)
miniGui.Position         = UDim2.new(1, -120, 0.5, -40)
miniGui.BackgroundColor3 = C.header
miniGui.BorderSizePixel  = 0
miniGui.Visible          = false   -- começa oculta, painel mostra/oculta
miniGui.ZIndex           = 15
miniGui.Parent           = screenGui
Instance.new("UICorner", miniGui).CornerRadius = UDim.new(0, 12)

local miniStroke = Instance.new("UIStroke")
miniStroke.Color     = C.accent
miniStroke.Thickness = 1.5
miniStroke.Parent    = miniGui

-- RGB animado só na mini
task.spawn(function()
    local t = 0
    while miniStroke.Parent do
        t += 0.025
        miniStroke.Color = Color3.fromRGB(
            math.floor(55 + 75 * math.sin(t)),
            math.floor(80 + 85 * math.sin(t + 2.1)),
            255
        )
        task.wait(0.05)
    end
end)

local miniTitleBar = Instance.new("Frame")
miniTitleBar.Size             = UDim2.new(1, 0, 0, 22)
miniTitleBar.BackgroundColor3 = Color3.fromRGB(22, 23, 46)
miniTitleBar.BorderSizePixel  = 0
miniTitleBar.ZIndex           = 16
miniTitleBar.Parent           = miniGui
Instance.new("UICorner", miniTitleBar).CornerRadius = UDim.new(0, 12)

-- cobre cantos inferiores do titleBar
local miniTFill = Instance.new("Frame")
miniTFill.Size             = UDim2.new(1, 0, 0, 10)
miniTFill.Position         = UDim2.new(0, 0, 1, -10)
miniTFill.BackgroundColor3 = Color3.fromRGB(22, 23, 46)
miniTFill.BorderSizePixel  = 0
miniTFill.ZIndex           = 16
miniTFill.Parent           = miniTitleBar

local miniTitle = Instance.new("TextLabel")
miniTitle.Size                   = UDim2.new(1, -8, 1, 0)
miniTitle.Position               = UDim2.new(0, 8, 0, 0)
miniTitle.BackgroundTransparency = 1
miniTitle.Text                   = "Spam"
miniTitle.TextColor3             = C.subtext
miniTitle.TextScaled             = true
miniTitle.Font                   = Enum.Font.GothamBold
miniTitle.ZIndex                 = 16
miniTitle.Parent                 = miniTitleBar

-- botão ON/OFF do spam
local spamBtn = Instance.new("TextButton")
spamBtn.Size             = UDim2.new(1, -16, 0, 44)
spamBtn.Position         = UDim2.new(0, 8, 0, 28)
spamBtn.BackgroundColor3 = C.red
spamBtn.BorderSizePixel  = 0
spamBtn.Text             = "OFF"
spamBtn.TextColor3       = Color3.new(1, 1, 1)
spamBtn.TextScaled       = true
spamBtn.Font             = Enum.Font.GothamBold
spamBtn.ZIndex           = 16
spamBtn.Parent           = miniGui
Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0, 9)

local spamOn = false
local function setSpam(v)
    spamOn              = v
    _G.PhantomManual    = v
    spamBtn.Text        = v and "ON" or "OFF"
    tw(spamBtn, 0.18, {BackgroundColor3 = v and C.green or C.red}, Enum.EasingStyle.Back):Play()
end

spamBtn.Activated:Connect(function() setSpam(not spamOn) end)

-- keybind: InputBegan/Ended para Hold e Toggle
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

-- ==================== BOTÃO FLUTUANTE ====================
local floatingButton = Instance.new("TextButton")
floatingButton.Size             = UDim2.new(0, 54, 0, 54)
floatingButton.Position         = Config.BtnX and UDim2.new(0, Config.BtnX, 0, Config.BtnY) or UDim2.new(1, -64, 0.5, -27)
floatingButton.BackgroundColor3 = C.header
floatingButton.BorderSizePixel  = 0
floatingButton.Text             = "⚡"
floatingButton.TextColor3       = C.text
floatingButton.TextSize         = 26
floatingButton.Font             = Enum.Font.GothamBold
floatingButton.Active           = true
floatingButton.ZIndex           = 10
floatingButton.Parent           = screenGui
Instance.new("UICorner", floatingButton).CornerRadius = UDim.new(1, 0)

local floatingStroke = Instance.new("UIStroke")
floatingStroke.Color     = C.accent
floatingStroke.Thickness = 2
floatingStroke.Parent    = floatingButton

-- ==================== PAINEL ====================
local PW, PH = 520, 380

local configPanel = Instance.new("Frame")
configPanel.Name                   = "PhantomPanel"
configPanel.Size                   = UDim2.new(0, PW, 0, PH)
configPanel.Position               = Config.PanelX and UDim2.new(0, Config.PanelX, 0, Config.PanelY) or UDim2.new(0.5, -PW/2, 0.5, -PH/2)
configPanel.BackgroundColor3       = C.bg
configPanel.BackgroundTransparency = 0.06
configPanel.BorderSizePixel        = 0
configPanel.Visible                = false
configPanel.ZIndex                 = 5
configPanel.Parent                 = screenGui
Instance.new("UICorner", configPanel).CornerRadius = UDim.new(0, 14)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = C.accent
panelStroke.Thickness = 1.6
panelStroke.Parent    = configPanel

-- RGB animado painel + botão flutuante
task.spawn(function()
    local t = 0
    while screenGui.Parent do
        t += 0.02
        local col = Color3.fromRGB(
            math.floor(55 + 75 * math.sin(t)),
            math.floor(80 + 85 * math.sin(t + 2.09)),
            255
        )
        panelStroke.Color    = col
        floatingStroke.Color = col
        task.wait(0.05)
    end
end)

-- ==================== TITLE BAR ====================
local TITLE_H = 48

local titleBar = Instance.new("Frame")
titleBar.Size                   = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3       = C.header
titleBar.BorderSizePixel        = 0
titleBar.ZIndex                 = 6
titleBar.Parent                 = configPanel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleBarFill = Instance.new("Frame")
titleBarFill.Size             = UDim2.new(1, 0, 0, 14)
titleBarFill.Position         = UDim2.new(0, 0, 1, -14)
titleBarFill.BackgroundColor3 = C.header
titleBarFill.BorderSizePixel  = 0
titleBarFill.ZIndex           = 6
titleBarFill.Parent           = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size                   = UDim2.new(1, -60, 1, 0)
titleLabel.Position               = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "⚡  Phantom  ·  Config"
titleLabel.TextColor3             = C.text
titleLabel.TextSize               = 18
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.ZIndex                 = 7
titleLabel.Parent                 = titleBar

local headerLine = Instance.new("Frame")
headerLine.Size             = UDim2.new(1, -24, 0, 1)
headerLine.Position         = UDim2.new(0, 12, 1, 0)
headerLine.BackgroundColor3 = C.divider
headerLine.BorderSizePixel  = 0
headerLine.ZIndex           = 6
headerLine.Parent           = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size             = UDim2.new(0, 28, 0, 28)
closeButton.Position         = UDim2.new(1, -38, 0.5, -14)
closeButton.BackgroundColor3 = C.red
closeButton.BorderSizePixel  = 0
closeButton.Text             = "✕"
closeButton.TextColor3       = Color3.new(1, 1, 1)
closeButton.TextSize         = 14
closeButton.Font             = Enum.Font.GothamBold
closeButton.ZIndex           = 7
closeButton.Parent           = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 7)

closeButton.MouseEnter:Connect(function() twPlay(closeButton, 0.12, {BackgroundColor3 = Color3.fromRGB(240, 65, 65)}) end)
closeButton.MouseLeave:Connect(function() twPlay(closeButton, 0.12, {BackgroundColor3 = C.red}) end)

-- ==================== LAYOUT ====================
local CONTENT_Y = TITLE_H + 12
local FOOTER_H  = 52
local PAD       = 14
local GAP       = 10
local COL_W     = math.floor((PW - PAD * 2 - GAP) / 2)

local colLeft = Instance.new("Frame")
colLeft.Size                   = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 8)
colLeft.Position               = UDim2.new(0, PAD, 0, CONTENT_Y)
colLeft.BackgroundTransparency = 1
colLeft.ZIndex                 = 6
colLeft.Parent                 = configPanel

local colRight = Instance.new("Frame")
colRight.Size                   = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 8)
colRight.Position               = UDim2.new(0, PAD + COL_W + GAP, 0, CONTENT_Y)
colRight.BackgroundTransparency = 1
colRight.ZIndex                 = 6
colRight.Parent                 = configPanel

local divider = Instance.new("Frame")
divider.Size             = UDim2.new(0, 1, 0, PH - CONTENT_Y - FOOTER_H - 16)
divider.Position         = UDim2.new(0, PAD + COL_W + math.floor(GAP / 2), 0, CONTENT_Y + 4)
divider.BackgroundColor3 = C.divider
divider.BorderSizePixel  = 0
divider.ZIndex           = 6
divider.Parent           = configPanel

-- ==================== KILL BTN ====================
local killBtn = Instance.new("TextButton")
killBtn.Size             = UDim2.new(0, 180, 0, 34)
killBtn.Position         = UDim2.new(0.5, -90, 1, -FOOTER_H + 10)
killBtn.BackgroundColor3 = C.redDark
killBtn.BorderSizePixel  = 0
killBtn.Text             = "🛑  Fechar Script"
killBtn.TextColor3       = Color3.fromRGB(255, 185, 185)
killBtn.TextSize         = 14
killBtn.Font             = Enum.Font.GothamBold
killBtn.ZIndex           = 7
killBtn.Parent           = configPanel
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 9)
Instance.new("UIStroke", killBtn).Color        = C.red

killBtn.MouseEnter:Connect(function() twPlay(killBtn, 0.15, {BackgroundColor3 = Color3.fromRGB(185, 35, 35), Size = UDim2.new(0, 188, 0, 36)}) end)
killBtn.MouseLeave:Connect(function() twPlay(killBtn, 0.15, {BackgroundColor3 = C.redDark, Size = UDim2.new(0, 180, 0, 34)}) end)

-- ==================== HELPERS ====================
local CARD_GAP = 8

local function cardFrame(yPos, h, parent)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, h)
    f.Position         = UDim2.new(0, 0, 0, yPos)
    f.BackgroundColor3 = C.card
    f.BorderSizePixel  = 0
    f.ZIndex           = 6
    f.Parent           = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    return f
end

local function cardLabel(text, parent)
    local l = Instance.new("TextLabel")
    l.Size                   = UDim2.new(1, -10, 0, 18)
    l.Position               = UDim2.new(0, 10, 0, 5)
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextColor3             = C.subtext
    l.TextSize               = 11
    l.Font                   = Enum.Font.GothamBold
    l.TextXAlignment         = Enum.TextXAlignment.Left
    l.ZIndex                 = 7
    l.Parent                 = parent
end

local function makeBtn(text, x, y, w, h, parent, bg)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, w, 0, h)
    b.Position         = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = bg or C.btnBlue
    b.BorderSizePixel  = 0
    b.Text             = text
    b.TextColor3       = C.text
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamBold
    b.ZIndex           = 7
    b.Parent           = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

-- ==================== TOGGLE (Auto Parry / Aura / Auto Clash) ====================
local function createToggle(labelText, configKey, yPos, parent, onToggle)
    local f = cardFrame(yPos, 50, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.6, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = C.text
    lbl.TextSize               = 15
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    -- estado inicial: configKey pode ser string (Config) ou boolean direto
    local function getVal()
        if configKey then return Config[configKey] else return false end
    end

    local btn = makeBtn(getVal() and "ON" or "OFF", 0, 0, 82, 32, f, getVal() and C.green or C.divider)
    btn.Position = UDim2.new(1, -94, 0.5, -16)

    btn.Activated:Connect(function()
        local v
        if configKey then
            Config[configKey] = not Config[configKey]
            v = Config[configKey]
            saveConfig(Config)
        else
            v = onToggle and onToggle()
        end
        tw(btn, 0.18, {BackgroundColor3 = v and C.green or C.divider}, Enum.EasingStyle.Back):Play()
        btn.Text = v and "ON" or "OFF"
    end)

    return yPos + 50 + CARD_GAP, btn
end

-- ==================== CPS ====================
local function createCPSSelector(yPos, parent)
    local f = cardFrame(yPos, 50, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0, 36, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "CPS:"
    lbl.TextColor3             = C.text
    lbl.TextSize               = 14
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    local defBtn = makeBtn("Padrão", 52, 0, 72, 32, f, C.btnBlue)
    defBtn.Position  = UDim2.new(0, 52, 0.5, -16)
    defBtn.TextSize  = 12

    local inputBox = Instance.new("TextBox")
    inputBox.Size             = UDim2.new(0, 72, 0, 32)
    inputBox.Position         = UDim2.new(1, -82, 0.5, -16)
    inputBox.BackgroundColor3 = C.inputBg
    inputBox.BorderSizePixel  = 0
    inputBox.Text             = tostring(Config.CPS)
    inputBox.PlaceholderText  = "CPS"
    inputBox.TextColor3       = C.text
    inputBox.TextSize         = 14
    inputBox.Font             = Enum.Font.GothamBold
    inputBox.ZIndex           = 7
    inputBox.Parent           = f
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)

    defBtn.Activated:Connect(function()
        Config.CustomCPS = false; Config.CPS = 22
        inputBox.Text = "22"
        twPlay(defBtn, 0.15, {BackgroundColor3 = C.green})
        task.delay(0.5, function() twPlay(defBtn, 0.15, {BackgroundColor3 = C.btnBlue}) end)
        saveConfig(Config)
    end)

    inputBox.FocusLost:Connect(function()
        local v = tonumber(inputBox.Text)
        if v and v > 0 and v <= 1000 then Config.CPS = v; Config.CustomCPS = true
        else inputBox.Text = tostring(Config.CPS) end
        saveConfig(Config)
    end)

    return yPos + 50 + CARD_GAP
end

-- ==================== KEYBIND DO PAINEL ====================
local function createKeybindSelector(yPos, parent)
    local f = cardFrame(yPos, 50, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.55, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "Tecla de Atalho"
    lbl.TextColor3             = C.text
    lbl.TextSize               = 14
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    local kbBtn = makeBtn(Config.Keybind.Name, 0, 0, 90, 32, f, C.btnBlue)
    kbBtn.Position = UDim2.new(1, -100, 0.5, -16)

    local listening = false
    kbBtn.Activated:Connect(function()
        if listening then return end
        listening = true
        kbBtn.Text = "..."
        twPlay(kbBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(80, 85, 160)})
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Config.Keybind = input.KeyCode
                kbBtn.Text = input.KeyCode.Name
                twPlay(kbBtn, 0.18, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                listening = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)

    return yPos + 50 + CARD_GAP
end

-- ==================== CARD SPAM PC ====================
-- Apenas mostra/oculta a mini GUI + configura keybind + modo
local function createSpamPCCard(yPos, parent)
    local CARD_H = 110
    local f = cardFrame(yPos, CARD_H, parent)
    cardLabel("Manual Spam", f)

    -- linha 1: mostrar/ocultar mini GUI
    local visBtn = makeBtn("Mini UI: Oculto", 8, 24, COL_W - 16, 30, f, C.btnDark)
    visBtn.TextSize = 12

    visBtn.Activated:Connect(function()
        miniGui.Visible = not miniGui.Visible
        visBtn.Text = miniGui.Visible and "Mini UI: Visível" or "Mini UI: Oculto"
        twPlay(visBtn, 0.15, {BackgroundColor3 = miniGui.Visible and Color3.fromRGB(0, 130, 65) or C.btnDark})
    end)

    -- linha 2: keybind + modo
    local kbBtn = makeBtn(Config.SpamKeybind and Config.SpamKeybind.Name or "X", 8, 64, math.floor((COL_W - 24) / 2), 30, f, C.btnBlue)

    local listeningKb = false
    kbBtn.Activated:Connect(function()
        if listeningKb then return end
        listeningKb = true
        kbBtn.Text = "..."
        twPlay(kbBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(80, 85, 160)})
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Config.SpamKeybind = input.KeyCode
                kbBtn.Text = input.KeyCode.Name
                twPlay(kbBtn, 0.18, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                listeningKb = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)

    local halfW = math.floor((COL_W - 24) / 2)
    local modeBtn = makeBtn(Config.SpamMode or "Toggle", 8 + halfW + 8, 64, halfW, 30, f, Color3.fromRGB(50, 55, 110))

    modeBtn.Activated:Connect(function()
        Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = Config.SpamMode
        -- se era Hold e spam tava ativo, desliga
        if Config.SpamMode == "Toggle" and _G.PhantomManual then
            -- mantém, usuário que desliga
        end
        saveConfig(Config)
    end)

    return yPos + CARD_H + CARD_GAP
end

-- ==================== MONTAR COLUNAS ====================
local yL, yR = 4, 4

-- Coluna esquerda: Auto Parry, Aura Visual, Auto Clash
yL = createToggle("Auto Parry",  "AutoParry", yL, colLeft)
yL = createToggle("Aura Visual", "Aura",      yL, colLeft)

-- Auto Clash: sem configKey, usa _G diretamente
local clashOn = false
local f3 = cardFrame(yL, 50, colLeft)
local clashLbl = Instance.new("TextLabel")
clashLbl.Size                   = UDim2.new(0.6, 0, 1, 0)
clashLbl.Position               = UDim2.new(0, 14, 0, 0)
clashLbl.BackgroundTransparency = 1
clashLbl.Text                   = "Auto Clash"
clashLbl.TextColor3             = C.text
clashLbl.TextSize               = 15
clashLbl.Font                   = Enum.Font.Gotham
clashLbl.TextXAlignment         = Enum.TextXAlignment.Left
clashLbl.ZIndex                 = 7
clashLbl.Parent                 = f3

local clashBtn = makeBtn("OFF", 0, 0, 82, 32, f3, C.divider)
clashBtn.Position = UDim2.new(1, -94, 0.5, -16)
clashBtn.Activated:Connect(function()
    clashOn             = not clashOn
    _G.PhantomAutoClash = clashOn
    tw(clashBtn, 0.18, {BackgroundColor3 = clashOn and C.green or C.divider}, Enum.EasingStyle.Back):Play()
    clashBtn.Text = clashOn and "ON" or "OFF"
end)

-- Coluna direita: CPS, Tecla de Atalho, Spam PC
yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)
yR = createSpamPCCard(yR, colRight)

-- ==================== DRAG PAINEL / BOTÃO ====================
makeDraggable(titleBar, configPanel, function()
    Config.PanelX = configPanel.Position.X.Offset
    Config.PanelY = configPanel.Position.Y.Offset
    saveConfig(Config)
end)

local btnWasDrag = makeDraggable(floatingButton, floatingButton, function()
    Config.BtnX = floatingButton.Position.X.Offset
    Config.BtnY = floatingButton.Position.Y.Offset
    saveConfig(Config)
end)

-- ==================== ABRIR / FECHAR PAINEL ====================
local panelOpen = false
local tweenOpen, tweenClose

local function togglePanel()
    panelOpen = not panelOpen
    if tweenOpen  then tweenOpen:Cancel()  end
    if tweenClose then tweenClose:Cancel() end

    if panelOpen then
        configPanel.Visible = true
        configPanel.Size    = UDim2.new(0, PW * 0.88, 0, PH * 0.88)
        configPanel.BackgroundTransparency = 1
        tweenOpen = tw(configPanel, 0.4,
            {Size = UDim2.new(0, PW, 0, PH), BackgroundTransparency = 0.06},
            Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tweenOpen:Play()
    else
        tweenClose = tw(configPanel, 0.25,
            {Size = UDim2.new(0, PW * 0.9, 0, PH * 0.9), BackgroundTransparency = 1},
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

    twPlay(configPanel,    0.28, {BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85)}, Enum.EasingStyle.Quint)
    twPlay(floatingButton, 0.28, {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})

    task.wait(0.35)
    for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() State.outer:Destroy() end)
    pcall(function() State.inner:Destroy() end)
    pcall(function() screenGui:Destroy() end)
    print("🛑 Phantom Script encerrado.")
end)

print("✅ Phantom GUI v5.1 carregada!")
print("   • Botão ⚡ para configurar | tecla: " .. Config.Keybind.Name)
