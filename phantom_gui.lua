-- Phantom Ball GUI v5.5
-- Carregado automaticamente pelo phantom_final.lua via loadstring

local timeout = 0
while not _G.PhantomConfig and timeout < 10 do
    task.wait(0.1); timeout += 0.1
end
if not _G.PhantomConfig then
    warn("Phantom GUI: lógica não encontrada. Rode phantom_final.lua primeiro.")
    return
end

local CoreGui = game:GetService("CoreGui")
local existing = CoreGui:FindFirstChild("PhantomUISystem")
if existing then existing:Destroy() end

local Config     = _G.PhantomConfig
local State      = _G.PhantomState
local saveConfig = _G.PhantomSaveConfig

local Workspace    = game:GetService("Workspace")
local UIS          = game:GetService("UserInputService")
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
    toggle  = Color3.fromRGB(50, 100, 200),
    hold    = Color3.fromRGB(160, 80, 10),
}

-- ==================== SCREEN GUI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PhantomUISystem"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = CoreGui

-- ==================== DRAG ====================
local activeDragTarget = nil

local function makeDraggable(handle, target, onDragEnd)
    local dragging  = false
    local pressing  = false
    local dragOffX  = 0
    local dragOffY  = 0
    local startPosX = 0
    local startPosY = 0

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if activeDragTarget and activeDragTarget ~= target then return end
        if pressing then return end

        pressing = true
        dragging = false
        local absPos = target.AbsolutePosition
        dragOffX  = input.Position.X - absPos.X
        dragOffY  = input.Position.Y - absPos.Y
        startPosX = input.Position.X
        startPosY = input.Position.Y

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging and onDragEnd then onDragEnd() end
                pressing         = false
                dragging         = false
                activeDragTarget = nil
            end
        end)
    end)

    local function onMove(input)
        if not pressing then return end
        if activeDragTarget and activeDragTarget ~= target then return end
        local delta = Vector2.new(
            input.Position.X - startPosX,
            input.Position.Y - startPosY
        )
        if not dragging then
            if delta.Magnitude >= 8 then
                dragging         = true
                activeDragTarget = target
            else return end
        end
        local vp  = Workspace.CurrentCamera.ViewportSize
        local tSz = target.AbsoluteSize
        local newX = math.clamp(input.Position.X - dragOffX, 0, vp.X - tSz.X)
        local newY = math.clamp(input.Position.Y - dragOffY, 0, vp.Y - tSz.Y)
        target.Position = UDim2.new(0, newX, 0, newY)
    end

    trackConn(UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then onMove(input) end
    end))

    return function() return dragging end
end

-- ==================== MINI GUI SPAM ====================
-- Sempre visível na tela. showMini() só move ela pra dentro/fora da tela.
local MINI_W = 110
local MINI_H = 80

local miniGui = Instance.new("Frame")
miniGui.Name             = "PhantomSpamMini"
miniGui.Size             = UDim2.new(0, MINI_W, 0, MINI_H)
miniGui.BackgroundColor3 = C.header
miniGui.BorderSizePixel  = 0
miniGui.ZIndex           = 15
miniGui.Parent           = screenGui
Instance.new("UICorner", miniGui).CornerRadius = UDim.new(0, 12)

local miniStroke = Instance.new("UIStroke")
miniStroke.Color     = C.accent
miniStroke.Thickness = 1.5
miniStroke.Parent    = miniGui

local miniTitleBar = Instance.new("Frame")
miniTitleBar.Size             = UDim2.new(1, 0, 0, 22)
miniTitleBar.BackgroundColor3 = Color3.fromRGB(22, 23, 46)
miniTitleBar.BorderSizePixel  = 0
miniTitleBar.ZIndex           = 16
miniTitleBar.Parent           = miniGui
Instance.new("UICorner", miniTitleBar).CornerRadius = UDim.new(0, 12)

-- preenche o gap arredondado do canto inferior da titlebar
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
    spamOn           = v
    _G.PhantomManual = v
    spamBtn.Text     = v and "ON" or "OFF"
    twPlay(spamBtn, 0.18, {BackgroundColor3 = v and C.green or C.red}, Enum.EasingStyle.Back)
end

spamBtn.Activated:Connect(function()
    if activeDragTarget == miniGui then return end
    setSpam(not spamOn)
end)

-- Posição visível: salva quando o usuário arrasta o miniGui
local miniVisibleX = Config.MiniX or (Workspace.CurrentCamera.ViewportSize.X - MINI_W - 10)
local miniVisibleY = Config.MiniY or (Workspace.CurrentCamera.ViewportSize.Y / 2 - MINI_H / 2)

-- Posição oculta: fora da tela pra direita
local function getMiniHiddenX()
    return Workspace.CurrentCamera.ViewportSize.X + 20
end

-- começa fora da tela
miniGui.Position = UDim2.new(0, getMiniHiddenX(), 0, miniVisibleY)

local miniVisible = false

local function showMini(v, visBtn)
    miniVisible = v
    if v then
        -- traz pra posição visível
        twPlay(miniGui, 0.22, {Position = UDim2.new(0, miniVisibleX, 0, miniVisibleY)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    else
        -- manda pra fora da tela
        twPlay(miniGui, 0.18, {Position = UDim2.new(0, getMiniHiddenX(), 0, miniVisibleY)}, Enum.EasingStyle.Quint)
    end
    if visBtn then
        visBtn.Text = v and "Mini UI: Visível" or "Mini UI: Oculto"
        twPlay(visBtn, 0.15, {BackgroundColor3 = v and Color3.fromRGB(0, 130, 65) or C.btnDark})
    end
end

-- drag do miniGui: inline com guard de miniVisible para não interferir quando está fora da tela
do
    local miniDragging  = false
    local miniPressing  = false
    local miniDragOffX  = 0
    local miniDragOffY  = 0
    local miniStartX    = 0
    local miniStartY    = 0

    miniTitleBar.InputBegan:Connect(function(input)
        if not miniVisible then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if activeDragTarget and activeDragTarget ~= miniGui then return end
        if miniPressing then return end

        miniPressing = true
        miniDragging = false
        local absPos = miniGui.AbsolutePosition
        miniDragOffX = input.Position.X - absPos.X
        miniDragOffY = input.Position.Y - absPos.Y
        miniStartX   = input.Position.X
        miniStartY   = input.Position.Y

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if miniDragging then
                    miniVisibleX = miniGui.Position.X.Offset
                    miniVisibleY = miniGui.Position.Y.Offset
                    Config.MiniX = miniVisibleX
                    Config.MiniY = miniVisibleY
                    saveConfig(Config)
                end
                miniPressing     = false
                miniDragging     = false
                activeDragTarget = nil
            end
        end)
    end)

    trackConn(UIS.InputChanged:Connect(function(input)
        if not miniVisible then return end
        if not miniPressing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if activeDragTarget and activeDragTarget ~= miniGui then return end

        local delta = Vector2.new(input.Position.X - miniStartX, input.Position.Y - miniStartY)
        if not miniDragging then
            if delta.Magnitude >= 8 then
                miniDragging     = true
                activeDragTarget = miniGui
            else return end
        end
        local vp   = Workspace.CurrentCamera.ViewportSize
        local tSz  = miniGui.AbsoluteSize
        local newX = math.clamp(input.Position.X - miniDragOffX, 0, vp.X - tSz.X)
        local newY = math.clamp(input.Position.Y - miniDragOffY, 0, vp.Y - tSz.Y)
        miniGui.Position = UDim2.new(0, newX, 0, newY)
    end))
end

-- keybind spam
trackConn(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not Config.SpamKeybind then return end
    if input.KeyCode ~= Config.SpamKeybind then return end
    if Config.SpamMode == "Hold" then setSpam(true)
    else setSpam(not spamOn) end
end))
trackConn(UIS.InputEnded:Connect(function(input, gpe)
    if gpe then return end
    if not Config.SpamKeybind then return end
    if input.KeyCode ~= Config.SpamKeybind then return end
    if Config.SpamMode == "Hold" then setSpam(false) end
end))

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
local PW, PH = 520, 340

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

-- ==================== RGB LOOP ====================
task.spawn(function()
    local t = 0
    while screenGui.Parent do
        t = (t + 0.004) % 1
        local col = Color3.fromHSV(t, 0.65, 1)
        panelStroke.Color    = col
        floatingStroke.Color = col
        miniStroke.Color     = col
        task.wait(0.05)
    end
end)

-- ==================== TITLE BAR ====================
local TITLE_H = 46

local titleBar = Instance.new("Frame")
titleBar.Size             = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = C.header
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 6
titleBar.Parent           = configPanel
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
titleLabel.TextSize               = 17
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
local CONTENT_Y = TITLE_H + 10
local FOOTER_H  = 50
local PAD       = 12
local GAP       = 10
local COL_W     = math.floor((PW - PAD * 2 - GAP) / 2)

local colLeft = Instance.new("Frame")
colLeft.Size                   = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 6)
colLeft.Position               = UDim2.new(0, PAD, 0, CONTENT_Y)
colLeft.BackgroundTransparency = 1
colLeft.ZIndex                 = 6
colLeft.Parent                 = configPanel

local colRight = Instance.new("Frame")
colRight.Size                   = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 6)
colRight.Position               = UDim2.new(0, PAD + COL_W + GAP, 0, CONTENT_Y)
colRight.BackgroundTransparency = 1
colRight.ZIndex                 = 6
colRight.Parent                 = configPanel

local divider = Instance.new("Frame")
divider.Size             = UDim2.new(0, 1, 0, PH - CONTENT_Y - FOOTER_H - 14)
divider.Position         = UDim2.new(0, PAD + COL_W + math.floor(GAP/2), 0, CONTENT_Y + 4)
divider.BackgroundColor3 = C.divider
divider.BorderSizePixel  = 0
divider.ZIndex           = 6
divider.Parent           = configPanel

-- ==================== KILL BTN ====================
local killBtn = Instance.new("TextButton")
killBtn.Size             = UDim2.new(0, 180, 0, 34)
killBtn.Position         = UDim2.new(0.5, -90, 1, -FOOTER_H + 8)
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

if not UIS.TouchEnabled then
    killBtn.MouseEnter:Connect(function() twPlay(killBtn, 0.15, {BackgroundColor3 = Color3.fromRGB(185, 35, 35), Size = UDim2.new(0, 188, 0, 36)}) end)
    killBtn.MouseLeave:Connect(function() twPlay(killBtn, 0.15, {BackgroundColor3 = C.redDark, Size = UDim2.new(0, 180, 0, 34)}) end)
end

-- ==================== HELPERS ====================
local CARD_GAP = 7

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
    l.Size                   = UDim2.new(1, -10, 0, 16)
    l.Position               = UDim2.new(0, 10, 0, 5)
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextColor3             = C.subtext
    l.TextSize               = 10
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

-- ==================== TOGGLE ====================
local function createToggle(labelText, configKey, yPos, parent)
    local f = cardFrame(yPos, 48, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.6, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = labelText
    lbl.TextColor3             = C.text
    lbl.TextSize               = 14
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    local btn = makeBtn(
        Config[configKey] and "ON" or "OFF", 0, 0, 80, 30, f,
        Config[configKey] and C.green or C.divider
    )
    btn.Position = UDim2.new(1, -92, 0.5, -15)

    btn.Activated:Connect(function()
        Config[configKey] = not Config[configKey]
        local v = Config[configKey]
        twPlay(btn, 0.18, {BackgroundColor3 = v and C.green or C.divider}, Enum.EasingStyle.Back)
        btn.Text = v and "ON" or "OFF"
        saveConfig(Config)
    end)

    return yPos + 48 + CARD_GAP
end

-- ==================== CPS SPAM ====================
local function createCPSSelector(yPos, parent)
    local CARD_H = 64
    local ROW_Y  = 26
    local ROW_H  = 28
    local f = cardFrame(yPos, CARD_H, parent)
    cardLabel("CPS Spam", f)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0, 36, 0, ROW_H)
    lbl.Position               = UDim2.new(0, 14, 0, ROW_Y)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "CPS:"
    lbl.TextColor3             = C.text
    lbl.TextSize               = 13
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    local defBtn = makeBtn("Padrão", 52, ROW_Y, 64, ROW_H, f, C.btnBlue)
    defBtn.TextSize = 11

    local inputBox = Instance.new("TextBox")
    inputBox.Size             = UDim2.new(0, 68, 0, ROW_H)
    inputBox.Position         = UDim2.new(1, -78, 0, ROW_Y)
    inputBox.BackgroundColor3 = C.inputBg
    inputBox.BorderSizePixel  = 0
    inputBox.Text             = tostring(Config.CPS)
    inputBox.PlaceholderText  = "CPS"
    inputBox.TextColor3       = C.text
    inputBox.TextSize         = 13
    inputBox.Font             = Enum.Font.GothamBold
    inputBox.ZIndex           = 7
    inputBox.Parent           = f
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)

    defBtn.Activated:Connect(function()
        Config.CustomCPS = false
        Config.CPS       = 24
        inputBox.Text    = "24"
        twPlay(defBtn, 0.15, {BackgroundColor3 = C.green})
        task.delay(0.5, function() twPlay(defBtn, 0.15, {BackgroundColor3 = C.btnBlue}) end)
        saveConfig(Config)
    end)

    inputBox.FocusLost:Connect(function()
        local v = tonumber(inputBox.Text)
        if v and v > 0 and v <= 1000 then
            Config.CPS       = v
            Config.CustomCPS = (v ~= 24)  -- só considera "padrão" se for 24
        else
            inputBox.Text = tostring(Config.CPS)
        end
        saveConfig(Config)
    end)

    return yPos + CARD_H + CARD_GAP
end

-- ==================== KEYBIND DO PAINEL ====================
local function createKeybindSelector(yPos, parent)
    local f = cardFrame(yPos, 48, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.55, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "Tecla de Atalho"
    lbl.TextColor3             = C.text
    lbl.TextSize               = 13
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    local kbBtn = makeBtn(Config.Keybind.Name, 0, 0, 88, 30, f, C.btnBlue)
    kbBtn.Position = UDim2.new(1, -98, 0.5, -15)

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
                kbBtn.Text     = input.KeyCode.Name
                twPlay(kbBtn, 0.18, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                listening = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)

    return yPos + 48 + CARD_GAP
end

-- ==================== CARD SPAM ====================
local function createSpamPCCard(yPos, parent)
    local CARD_H = 106
    local f = cardFrame(yPos, CARD_H, parent)
    cardLabel("Manual Spam", f)

    local visBtn = makeBtn("Mini UI: Oculto", 8, 22, COL_W - 16, 28, f, C.btnDark)
    visBtn.TextSize = 11

    visBtn.Activated:Connect(function()
        showMini(not miniVisible, visBtn)
    end)

    local halfW = math.floor((COL_W - 28) / 2)

    local kbBtn = makeBtn(
        (Config.SpamKeybind and Config.SpamKeybind.Name) or (Config.SpamKeybindName or "F"),
        8, 60, halfW, 30, f, C.btnBlue
    )

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
                kbBtn.Text         = input.KeyCode.Name
                twPlay(kbBtn, 0.18, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                listeningKb = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)

    local function getModeColor(mode)
        return mode == "Hold" and C.hold or C.toggle
    end

    local modeBtn = makeBtn(
        Config.SpamMode or "Toggle",
        8 + halfW + 12, 60, halfW, 30, f,
        getModeColor(Config.SpamMode or "Toggle")
    )

    modeBtn.Activated:Connect(function()
        Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = Config.SpamMode
        twPlay(modeBtn, 0.18, {BackgroundColor3 = getModeColor(Config.SpamMode)}, Enum.EasingStyle.Back)
        if Config.SpamMode == "Toggle" and _G.PhantomManual then setSpam(false) end
        saveConfig(Config)
    end)

    return yPos + CARD_H + CARD_GAP
end

-- ==================== MONTAR COLUNAS ====================
local yL, yR = 4, 4

yL = createToggle("Auto Parry",  "AutoParry", yL, colLeft)
yL = createToggle("Aura Visual", "Aura",      yL, colLeft)

-- Auto Clash (inline pq não usa createToggle — tem estado próprio em _G)
local clashOn = Config.AutoClash or false
_G.PhantomAutoClash = clashOn  -- restaura estado no logic imediatamente
local fClash  = cardFrame(yL, 48, colLeft)
yL = yL + 48 + CARD_GAP  -- incrementa yL corretamente

local clashLbl = Instance.new("TextLabel")
clashLbl.Size                   = UDim2.new(0.6, 0, 1, 0)
clashLbl.Position               = UDim2.new(0, 14, 0, 0)
clashLbl.BackgroundTransparency = 1
clashLbl.Text                   = "Auto Clash"
clashLbl.TextColor3             = C.text
clashLbl.TextSize               = 14
clashLbl.Font                   = Enum.Font.Gotham
clashLbl.TextXAlignment         = Enum.TextXAlignment.Left
clashLbl.ZIndex                 = 7
clashLbl.Parent                 = fClash

local clashBtn = makeBtn(clashOn and "ON" or "OFF", 0, 0, 80, 30, fClash, clashOn and C.green or C.divider)
clashBtn.Position = UDim2.new(1, -92, 0.5, -15)
clashBtn.Activated:Connect(function()
    clashOn             = not clashOn
    _G.PhantomAutoClash = clashOn
    Config.AutoClash    = clashOn
    twPlay(clashBtn, 0.18, {BackgroundColor3 = clashOn and C.green or C.divider}, Enum.EasingStyle.Back)
    clashBtn.Text = clashOn and "ON" or "OFF"
    saveConfig(Config)
end)

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
local panelOpen   = false
local tweenPanel  = nil
local tweenBtn    = nil

local function togglePanel()
    panelOpen = not panelOpen

    -- cancela qualquer tween em andamento antes de iniciar novo
    if tweenPanel then tweenPanel:Cancel() end
    if tweenBtn   then tweenBtn:Cancel()   end

    if panelOpen then
        floatingButton.Active = false
        tweenBtn = tw(floatingButton, 0.18, {BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 38, 0, 38)}, Enum.EasingStyle.Quint)
        tweenBtn:Play()

        configPanel.Visible                = true
        configPanel.Size                   = UDim2.new(0, PW * 0.88, 0, PH * 0.88)
        configPanel.BackgroundTransparency = 1
        tweenPanel = tw(configPanel, 0.28, {Size = UDim2.new(0, PW, 0, PH), BackgroundTransparency = 0.06}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tweenPanel:Play()
    else
        tweenBtn = tw(floatingButton, 0.22, {BackgroundTransparency = 0, TextTransparency = 0, Size = UDim2.new(0, 54, 0, 54)}, Enum.EasingStyle.Back)
        tweenBtn:Play()
        -- Active volta imediatamente, não espera o tween
        tweenBtn.Completed:Connect(function() floatingButton.Active = true end)

        tweenPanel = tw(configPanel, 0.22, {Size = UDim2.new(0, PW * 0.9, 0, PH * 0.9), BackgroundTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tweenPanel:Play()
        local conn
        conn = tweenPanel.Completed:Connect(function()
            configPanel.Visible = false
            conn:Disconnect()
        end)
    end
end

floatingButton.Activated:Connect(function()
    if btnWasDrag() then return end
    togglePanel()
end)

closeButton.Activated:Connect(function()
    if panelOpen then togglePanel() end
end)

trackConn(UIS.InputBegan:Connect(function(input)
    if activeDragTarget then return end
    if input.KeyCode == Config.Keybind then togglePanel() end
end))

-- ==================== FECHAR SCRIPT ====================
killBtn.Activated:Connect(function()
    State.scriptActive  = false
    _G.PhantomManual    = false
    _G.PhantomAutoClash = false
    saveConfig(Config)

    twPlay(configPanel,    0.25, {BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85)}, Enum.EasingStyle.Quint)
    twPlay(floatingButton, 0.25, {BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})

    task.wait(0.3)
    for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() State.outer:Destroy() end)
    pcall(function() State.inner:Destroy() end)
    pcall(function() screenGui:Destroy() end)
    print("🛑 Phantom Script encerrado.")
end)

print("✅ Phantom GUI v5.5 carregada!")
print("   • Botão ⚡ para configurar | tecla: " .. Config.Keybind.Name)