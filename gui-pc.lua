-- Phantom Ball GUI PC v1.1

local timeout = 0
while not _G.PhantomConfig and timeout < 10 do
    task.wait(0.1); timeout += 0.1
end
if not _G.PhantomConfig then
    warn("Phantom GUI: lógica não encontrada.")
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

local C = {
    bg      = Color3.fromRGB(10, 11, 24),
    header  = Color3.fromRGB(16, 17, 36),
    card    = Color3.fromRGB(20, 21, 40),
    green   = Color3.fromRGB(40, 210, 110),
    red     = Color3.fromRGB(220, 50, 55),
    text    = Color3.fromRGB(220, 225, 255),
    subtext = Color3.fromRGB(130, 140, 190),
    divider = Color3.fromRGB(35, 38, 70),
    inputBg = Color3.fromRGB(14, 15, 32),
    btnBlue = Color3.fromRGB(45, 55, 115),
    redDark = Color3.fromRGB(140, 28, 28),
    accent  = Color3.fromRGB(90, 110, 255),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PhantomUISystem"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = CoreGui

-- ==================== DRAG ====================
local activeDragTarget = nil

local function makeDraggable(handle, target, onDragEnd)
    local pressing, dragging = false, false
    local dragOffX, dragOffY, startPosX, startPosY = 0, 0, 0, 0

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if activeDragTarget and activeDragTarget ~= target then return end
        if pressing then return end
        pressing = true; dragging = false
        local ap = target.AbsolutePosition
        dragOffX = input.Position.X - ap.X
        dragOffY = input.Position.Y - ap.Y
        startPosX = input.Position.X
        startPosY = input.Position.Y
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging and onDragEnd then onDragEnd() end
                pressing = false; dragging = false; activeDragTarget = nil
            end
        end)
    end)

    trackConn(UIS.InputChanged:Connect(function(input)
        if not pressing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if activeDragTarget and activeDragTarget ~= target then return end
        local d = Vector2.new(input.Position.X - startPosX, input.Position.Y - startPosY)
        if not dragging then
            if d.Magnitude >= 8 then dragging = true; activeDragTarget = target
            else return end
        end
        local vp = Workspace.CurrentCamera.ViewportSize
        local sz = target.AbsoluteSize
        target.Position = UDim2.new(0,
            math.clamp(input.Position.X - dragOffX, 0, vp.X - sz.X), 0,
            math.clamp(input.Position.Y - dragOffY, 0, vp.Y - sz.Y))
    end))

    return function() return dragging end
end

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
local PW, PH = 360, 336

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

task.spawn(function()
    local t = 0
    while screenGui.Parent do
        t = (t + 0.004) % 1
        local col = Color3.fromHSV(t, 0.65, 1)
        panelStroke.Color    = col
        floatingStroke.Color = col
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
titleLabel.Text                   = "⚡  Phantom  ·  PC"
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
closeButton.TextColor3       = Color3.new(1,1,1)
closeButton.TextSize         = 14
closeButton.Font             = Enum.Font.GothamBold
closeButton.ZIndex           = 7
closeButton.Parent           = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 7)
closeButton.MouseEnter:Connect(function() twPlay(closeButton, 0.12, {BackgroundColor3 = Color3.fromRGB(240,65,65)}) end)
closeButton.MouseLeave:Connect(function() twPlay(closeButton, 0.12, {BackgroundColor3 = C.red}) end)

-- ==================== LAYOUT 2 COLUNAS ====================
local CONTENT_Y = TITLE_H + 10
local FOOTER_H  = 48
local PAD       = 12
local CARD_GAP  = 8
local COL_W     = (PW - PAD * 3) / 2

local colL = Instance.new("Frame")
colL.Size                   = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H)
colL.Position               = UDim2.new(0, PAD, 0, CONTENT_Y)
colL.BackgroundTransparency = 1
colL.ZIndex                 = 6
colL.Parent                 = configPanel

local colR = Instance.new("Frame")
colR.Size                   = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H)
colR.Position               = UDim2.new(0, PAD * 2 + COL_W, 0, CONTENT_Y)
colR.BackgroundTransparency = 1
colR.ZIndex                 = 6
colR.Parent                 = configPanel

-- ==================== KILL BTN ====================
local killBtn = Instance.new("TextButton")
killBtn.Size             = UDim2.new(0, 180, 0, 32)
killBtn.Position         = UDim2.new(0.5, -90, 1, -FOOTER_H + 8)
killBtn.BackgroundColor3 = C.redDark
killBtn.BorderSizePixel  = 0
killBtn.Text             = "🛑  Fechar Script"
killBtn.TextColor3       = Color3.fromRGB(255,185,185)
killBtn.TextSize         = 13
killBtn.Font             = Enum.Font.GothamBold
killBtn.ZIndex           = 7
killBtn.Parent           = configPanel
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 9)
Instance.new("UIStroke", killBtn).Color        = C.red
killBtn.MouseEnter:Connect(function() twPlay(killBtn, 0.15, {BackgroundColor3 = Color3.fromRGB(185,35,35)}) end)
killBtn.MouseLeave:Connect(function() twPlay(killBtn, 0.15, {BackgroundColor3 = C.redDark}) end)

-- ==================== HELPERS ====================
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
    l.Size                   = UDim2.new(1, -8, 0, 14)
    l.Position               = UDim2.new(0, 8, 0, 4)
    l.BackgroundTransparency = 1
    l.Text                   = text
    l.TextColor3             = C.subtext
    l.TextSize               = 9
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
    b.TextSize         = 12
    b.Font             = Enum.Font.GothamBold
    b.ZIndex           = 7
    b.Parent           = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    return b
end

local function makeKeybindCard(y, parent, labelText, getCurrentKey, onSet)
    local f = cardFrame(y, 52, parent)
    cardLabel(labelText, f)

    local kbBtn = makeBtn(getCurrentKey(), 0, 0, COL_W - 16, 26, f, C.btnBlue)
    kbBtn.Position  = UDim2.new(0, 8, 1, -34)
    kbBtn.TextSize  = 11

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
                onSet(input.KeyCode)
                kbBtn.Text = input.KeyCode.Name
                twPlay(kbBtn, 0.18, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                listening = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)

    return y + 52 + CARD_GAP
end

-- ==================== COLUNA ESQUERDA ====================
local yL = 0

-- Auto Parry
do
    local f = cardFrame(yL, 52, colL)
    cardLabel("Auto Parry", f)
    local btn = makeBtn(
        Config.AutoParry and "ON" or "OFF",
        8, 0, COL_W - 16, 26, f,
        Config.AutoParry and C.green or C.divider
    )
    btn.Position = UDim2.new(0, 8, 1, -34)
    btn.Activated:Connect(function()
        Config.AutoParry = not Config.AutoParry
        local v = Config.AutoParry
        twPlay(btn, 0.18, {BackgroundColor3 = v and C.green or C.divider}, Enum.EasingStyle.Back)
        btn.Text = v and "ON" or "OFF"
        saveConfig(Config)
    end)
    yL = yL + 52 + CARD_GAP
end

-- CPS
do
    local f = cardFrame(yL, 68, colL)
    cardLabel("CPS Spam", f)

    local inputBox = Instance.new("TextBox")
    inputBox.Size             = UDim2.new(0, COL_W - 60, 0, 26)
    inputBox.Position         = UDim2.new(0, 8, 1, -34)
    inputBox.BackgroundColor3 = C.inputBg
    inputBox.BorderSizePixel  = 0
    inputBox.Text             = tostring(Config.CPS)
    inputBox.PlaceholderText  = "CPS"
    inputBox.TextColor3       = C.text
    inputBox.TextSize         = 13
    inputBox.Font             = Enum.Font.GothamBold
    inputBox.ZIndex           = 7
    inputBox.Parent           = f
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 7)

    local defBtn = makeBtn("↺", COL_W - 44, 0, 36, 26, f, C.btnBlue)
    defBtn.Position  = UDim2.new(1, -44, 1, -34)
    defBtn.TextSize  = 16

    defBtn.Activated:Connect(function()
        Config.CPS = 22; Config.CustomCPS = false
        inputBox.Text = "22"
        twPlay(defBtn, 0.15, {BackgroundColor3 = C.green})
        task.delay(0.5, function() twPlay(defBtn, 0.15, {BackgroundColor3 = C.btnBlue}) end)
        saveConfig(Config)
    end)
    inputBox.FocusLost:Connect(function()
        local v = tonumber(inputBox.Text)
        if v and v > 0 and v <= 1000 then
            Config.CPS = v; Config.CustomCPS = (v ~= 22)
        else inputBox.Text = tostring(Config.CPS) end
        saveConfig(Config)
    end)
    yL = yL + 68 + CARD_GAP
end

-- Tecla Spam
yL = makeKeybindCard(yL, colL, "Tecla do Spam",
    function() return Config.SpamKeybind and Config.SpamKeybind.Name or "X" end,
    function(kc) Config.SpamKeybind = kc end)

-- ==================== COLUNA DIREITA ====================
local yR = 0

-- Tecla de Atalho
yR = makeKeybindCard(yR, colR, "Tecla de Atalho",
    function() return Config.Keybind.Name end,
    function(kc) Config.Keybind = kc end)

-- Tecla de Parry
yR = makeKeybindCard(yR, colR, "Tecla de Parry",
    function() return Config.ParryKeybind and Config.ParryKeybind.Name or "P" end,
    function(kc)
        Config.ParryKeybind = kc
        _G.PhantomParryKeybind = kc
    end)

-- ==================== DRAG ====================
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

-- ==================== TOGGLE PAINEL ====================
local panelOpen  = false
local tweenPanel = nil
local tweenBtn   = nil

local function togglePanel()
    panelOpen = not panelOpen
    if tweenPanel then tweenPanel:Cancel() end
    if tweenBtn   then tweenBtn:Cancel()   end

    if panelOpen then
        floatingButton.Active = false
        tweenBtn = tw(floatingButton, 0.18, {BackgroundTransparency=1, TextTransparency=1, Size=UDim2.new(0,38,0,38)}, Enum.EasingStyle.Quint)
        tweenBtn:Play()
        configPanel.Visible = true
        configPanel.Size    = UDim2.new(0, PW*0.88, 0, PH*0.88)
        configPanel.BackgroundTransparency = 1
        tweenPanel = tw(configPanel, 0.28, {Size=UDim2.new(0,PW,0,PH), BackgroundTransparency=0.06}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tweenPanel:Play()
    else
        tweenBtn = tw(floatingButton, 0.22, {BackgroundTransparency=0, TextTransparency=0, Size=UDim2.new(0,54,0,54)}, Enum.EasingStyle.Back)
        tweenBtn:Play()
        tweenBtn.Completed:Connect(function() floatingButton.Active = true end)
        tweenPanel = tw(configPanel, 0.22, {Size=UDim2.new(0,PW*0.9,0,PH*0.9), BackgroundTransparency=1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tweenPanel:Play()
        local conn
        conn = tweenPanel.Completed:Connect(function()
            configPanel.Visible = false; conn:Disconnect()
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
trackConn(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if not Config.SpamKeybind then return end
    if input.KeyCode ~= Config.SpamKeybind then return end
    _G.PhantomManual = not _G.PhantomManual
end))

-- ==================== FECHAR SCRIPT ====================
killBtn.Activated:Connect(function()
    State.scriptActive = false
    _G.PhantomManual   = false
    saveConfig(Config)
    twPlay(configPanel,    0.25, {BackgroundTransparency=1, Size=UDim2.new(0,PW*0.85,0,PH*0.85)}, Enum.EasingStyle.Quint)
    twPlay(floatingButton, 0.25, {BackgroundTransparency=1, TextTransparency=1, Size=UDim2.new(0,0,0,0)})
    task.wait(0.3)
    for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() screenGui:Destroy() end)
    print("🛑 Phantom Script encerrado.")
end)

print("✅ Phantom GUI PC v1.1 carregada!")
ex           = 6
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

-- ==================== KEYBIND DO PARRY (FALLBACK) ====================
local function createParryKeybindCard(yPos, parent)
    local f = cardFrame(yPos, 48, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.55, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "Tecla de Parry"
    lbl.TextColor3             = C.text
    lbl.TextSize               = 13
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    local kbBtn = makeBtn(
        Config.ParryKeybind and Config.ParryKeybind.Name or "P",
        0, 0, 88, 30, f, C.btnBlue
    )
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
                Config.ParryKeybind = input.KeyCode
                kbBtn.Text          = input.KeyCode.Name
                twPlay(kbBtn, 0.18, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                listening = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)

    return yPos + 48 + CARD_GAP
end
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
        Config.SpamKeybind and Config.SpamKeybind.Name or "X",
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
yR = createParryKeybindCard(yR, colRight)
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