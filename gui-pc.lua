-- Phantom Ball GUI v5.5 (PC Only)
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

-- ==================== PANEL PRINCIPAL ====================
local PW, PH = 520, 360
local configPanel = Instance.new("Frame")
configPanel.Name             = "ConfigPanel"
configPanel.Size             = UDim2.new(0, PW, 0, PH)
configPanel.Position         = UDim2.new(0.5, -PW/2, 0.5, -PH/2)
configPanel.BackgroundColor3 = C.bg
configPanel.BorderSizePixel  = 0
configPanel.Visible          = false
configPanel.Parent           = screenGui
Instance.new("UICorner", configPanel).CornerRadius = UDim.new(0, 16)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = C.accent
panelStroke.Thickness = 1.5
panelStroke.Parent    = configPanel

-- ==================== TÍTULO ====================
local titleBar = Instance.new("Frame")
titleBar.Name             = "TitleBar"
titleBar.Size             = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = C.header
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 5
titleBar.Parent           = configPanel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local fillTBar = Instance.new("Frame")
fillTBar.Size             = UDim2.new(1, 0, 0, 10)
fillTBar.Position         = UDim2.new(0, 0, 1, -10)
fillTBar.BackgroundColor3 = C.header
fillTBar.BorderSizePixel  = 0
fillTBar.ZIndex           = 5
fillTBar.Parent           = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size                   = UDim2.new(1, -16, 1, 0)
titleText.Position               = UDim2.new(0, 8, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text                   = "⚡ Phantom Ball"
titleText.TextColor3             = C.text
titleText.TextSize               = 18
titleText.Font                   = Enum.Font.GothamBold
titleText.TextXAlignment         = Enum.TextXAlignment.Left
titleText.ZIndex                 = 5
titleText.Parent                 = titleBar

-- ==================== CLOSE BUTTON ====================
local closeButton = Instance.new("TextButton")
closeButton.Size             = UDim2.new(0, 32, 0, 32)
closeButton.Position         = UDim2.new(1, -40, 0, 9)
closeButton.BackgroundColor3 = C.divider
closeButton.BorderSizePixel  = 0
closeButton.Text             = "✕"
closeButton.TextColor3       = C.red
closeButton.TextSize         = 18
closeButton.Font             = Enum.Font.GothamBold
closeButton.ZIndex           = 6
closeButton.Parent           = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

-- ==================== KILL BUTTON ====================
local killBtn = Instance.new("TextButton")
killBtn.Size             = UDim2.new(0, 32, 0, 32)
killBtn.Position         = UDim2.new(1, -80, 0, 9)
killBtn.BackgroundColor3 = C.redDark
killBtn.BorderSizePixel  = 0
killBtn.Text             = "■"
killBtn.TextColor3       = C.red
killBtn.TextSize         = 16
killBtn.Font             = Enum.Font.GothamBold
killBtn.ZIndex           = 6
killBtn.Parent           = titleBar
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 8)

-- ==================== CONTEÚDO ====================
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                   = "Content"
scrollFrame.Size                   = UDim2.new(1, -16, 1, -70)
scrollFrame.Position               = UDim2.new(0, 8, 0, 58)
scrollFrame.BackgroundColor3       = C.bg
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel        = 0
scrollFrame.ScrollBarThickness     = 8
scrollFrame.TopImage               = "rbxasset://textures/Ui/Corner3x3.png"
scrollFrame.BottomImage            = "rbxasset://textures/Ui/Corner3x3.png"
scrollFrame.ZIndex                 = 4
scrollFrame.Parent                 = configPanel

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding    = UDim.new(0, 12)
uiListLayout.FillDirection = Enum.FillDirection.Vertical
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scrollFrame

scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 12)
trackConn(uiListLayout.Changed:Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y + 12)
end))

-- ==================== FUNÇÕES PARA CARDS ====================
local function makeBtn(text, x, y, w, h, parent, color)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, w, 0, h)
    btn.Position         = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3 = color or C.btnDark
    btn.BorderSizePixel  = 0
    btn.Text             = text
    btn.TextColor3       = Color3.new(1, 1, 1)
    btn.TextScaled       = true
    btn.Font             = Enum.Font.GothamBold
    btn.ZIndex           = 4
    btn.Parent           = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local function cardFrame(parent, minHeight)
    minHeight = minHeight or 48
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, minHeight)
    f.BackgroundColor3 = C.card
    f.BorderSizePixel  = 0
    f.LayoutOrder       = (parent:FindFirstChild("UIListLayout") and #parent:GetChildren() or 0)
    f.ZIndex           = 3
    f.Parent           = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    return f
end

local function cardLabel(text, parent)
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -16, 0, 24)
    lbl.Position               = UDim2.new(0, 8, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = text
    lbl.TextColor3             = C.text
    lbl.TextSize               = 16
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 4
    lbl.Parent                 = parent
end

-- ==================== AUTO PARRY ====================
local function createToggle(name, configKey, parent, minHeight)
    minHeight = minHeight or 48
    local f = cardFrame(parent, minHeight)
    cardLabel(name, f)

    local toggleBtn = makeBtn(Config[configKey] and "ON" or "OFF", 0, 0, 80, 30, f, Config[configKey] and C.green or C.divider)
    toggleBtn.Position = UDim2.new(1, -92, 0.5, -15)

    toggleBtn.Activated:Connect(function()
        Config[configKey] = not Config[configKey]
        toggleBtn.Text = Config[configKey] and "ON" or "OFF"
        twPlay(toggleBtn, 0.18, {BackgroundColor3 = Config[configKey] and C.green or C.divider}, Enum.EasingStyle.Back)
        saveConfig(Config)
    end)

    return f
end

createToggle("Auto Parry", "AutoParry", scrollFrame)

-- ==================== PARRY KEYBIND SELECTOR ====================
local function createParryKeybindSelector(parent)
    local f = cardFrame(parent, 48)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.6, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "Parry Keybind"
    lbl.TextColor3             = C.text
    lbl.TextSize               = 14
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.ZIndex                 = 7
    lbl.Parent                 = f

    local kbBtn = makeBtn(Config.ParryKeybind.Name, 0, 0, 88, 30, f, C.btnBlue)
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
                kbBtn.Text     = input.KeyCode.Name
                twPlay(kbBtn, 0.18, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                listening = false
                conn:Disconnect()
                saveConfig(Config)
            end
        end)
    end)
end

createParryKeybindSelector(scrollFrame)

-- ==================== CPS SELECTOR ====================
local function createCPSSelector(parent)
    local f = cardFrame(parent, 80)
    cardLabel("CPS (Spam)", f)

    local cpsList = {5, 8, 12, 15, 18, 20, 24}
    local btnW = math.floor((520 - 30) / 7)

    for i, cps in ipairs(cpsList) do
        local selected = Config.CPS == cps
        local btn = makeBtn(tostring(cps), (i-1) * (btnW + 2) + 8, 32, btnW, 32, f, selected and C.accent or C.btnDark)
        
        btn.Activated:Connect(function()
            Config.CPS = cps
            saveConfig(Config)
            
            for _, b in ipairs(f:GetChildren()) do
                if b:IsA("TextButton") and b ~= btn and b.Parent == f then
                    twPlay(b, 0.12, {BackgroundColor3 = C.btnDark}, Enum.EasingStyle.Back)
                end
            end
            twPlay(btn, 0.12, {BackgroundColor3 = C.accent}, Enum.EasingStyle.Back)
        end)
    end
end

createCPSSelector(scrollFrame)

-- ==================== SPAM MANUAL ====================
local function createSpamCard(parent)
    local f = cardFrame(parent, 106)
    cardLabel("Manual Spam", f)

    local halfW = math.floor((520 - 32) / 2)

    local kbBtn = makeBtn(
        Config.SpamKeybind and Config.SpamKeybind.Name or "X",
        8, 32, halfW - 6, 30, f, C.btnBlue
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
        8 + halfW + 6, 32, halfW - 6, 30, f,
        getModeColor(Config.SpamMode or "Toggle")
    )

    modeBtn.Activated:Connect(function()
        Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = Config.SpamMode
        twPlay(modeBtn, 0.18, {BackgroundColor3 = getModeColor(Config.SpamMode)}, Enum.EasingStyle.Back)
        saveConfig(Config)
    end)

    -- Status label
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size                   = UDim2.new(1, -16, 0, 24)
    statusLbl.Position               = UDim2.new(0, 8, 0, 68)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text                   = "Status: OFF"
    statusLbl.TextColor3             = C.subtext
    statusLbl.TextSize               = 12
    statusLbl.Font                   = Enum.Font.Gotham
    statusLbl.TextXAlignment         = Enum.TextXAlignment.Left
    statusLbl.ZIndex                 = 4
    statusLbl.Parent                 = f

    trackConn(RunService.Heartbeat:Connect(function()
        local txt = _G.PhantomManual and "Status: ON" or "Status: OFF"
        local col = _G.PhantomManual and C.green or C.subtext
        if statusLbl.Text ~= txt then
            statusLbl.Text = txt
            statusLbl.TextColor3 = col
        end
    end))
end

createSpamCard(scrollFrame)

-- ==================== DRAG PAINEL / BOTÃO ====================
makeDraggable(titleBar, configPanel, function()
    Config.PanelX = configPanel.Position.X.Offset
    Config.PanelY = configPanel.Position.Y.Offset
    saveConfig(Config)
end)

-- ==================== FLOATING BUTTON ====================
local floatingButton = Instance.new("TextButton")
floatingButton.Name             = "FloatingBtn"
floatingButton.Size             = UDim2.new(0, 54, 0, 54)
floatingButton.Position         = UDim2.new(0, Config.BtnX or 30, 0, Config.BtnY or 30)
floatingButton.BackgroundColor3 = C.accent
floatingButton.BorderSizePixel  = 0
floatingButton.Text             = "⚡"
floatingButton.TextColor3       = Color3.new(1, 1, 1)
floatingButton.TextSize         = 24
floatingButton.Font             = Enum.Font.GothamBold
floatingButton.ZIndex           = 10
floatingButton.Parent           = screenGui
Instance.new("UICorner", floatingButton).CornerRadius = UDim.new(0, 16)

local btnWasDrag = makeDraggable(floatingButton, floatingButton, function()
    Config.BtnX = floatingButton.Position.X.Offset
    Config.BtnY = floatingButton.Position.Y.Offset
    saveConfig(Config)
end)

-- ==================== ABRIR / FECHAR PAINEL ====================
local panelOpen   = false
local tweenPanel  = nil
local tweenBtn    = nil
local RunService  = game:GetService("RunService")

local function togglePanel()
    panelOpen = not panelOpen

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
    saveConfig(Config)

    twPlay(configPanel,    0.25, {BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85)}, Enum.EasingStyle.Quint)
    twPlay(floatingButton, 0.25, {BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})

    task.wait(0.3)
    for _, c in ipairs(State.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() screenGui:Destroy() end)
    print("🛑 Phantom Script encerrado.")
end)

print("✅ Phantom GUI v5.5 (PC) carregada!")
print("   • Botão ⚡ para configurar | tecla: " .. Config.Keybind.Name)
