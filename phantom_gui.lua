-- Phantom Ball GUI v6.0 - Redesign Nexus Style
-- Paleta: Azul / Roxo / Rosa
-- Carregado automaticamente pelo phantom_final.lua via loadstring

print("[PhantomGUI] Iniciando carregamento v6.0...")

local timeout = 0
while not _G.PhantomConfig and timeout < 10 do
    task.wait(0.1)
    timeout = timeout + 0.1
end

if not _G.PhantomConfig then
    warn("[PhantomGUI] ERRO: _G.PhantomConfig nao encontrada. Rode phantom_final.lua primeiro.")
    return
end

print("[PhantomGUI] Config encontrada, prosseguindo...")

local CoreGui = game:GetService("CoreGui")
local existing = CoreGui:FindFirstChild("PhantomUISystem")
if existing then
    print("[PhantomGUI] GUI anterior encontrada, destruindo...")
    existing:Destroy()
end

local Config = _G.PhantomConfig
local State = _G.PhantomState
local saveConfig = _G.PhantomSaveConfig

local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

print("[PhantomGUI] Servicos carregados. Criando GUI...")

local function tw(obj, t, props, style, dir)
    return TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
end

local function twPlay(obj, t, props, style, dir)
    tw(obj, t, props, style, dir):Play()
end

local function trackConn(c)
    State.connections[#State.connections + 1] = c
end

-- ==========================================
--         PALETA NEXUS - AZUL/ROXO/ROSA
-- ==========================================
local C = {
    bg = Color3.fromRGB(8, 8, 22),
    header = Color3.fromRGB(14, 14, 34),
    card = Color3.fromRGB(20, 20, 44),
    panel = Color3.fromRGB(26, 26, 52),
    inputBg = Color3.fromRGB(16, 16, 38),
    accent = Color3.fromRGB(99, 102, 241),
    accentGlow = Color3.fromRGB(139, 92, 246),
    accentPink = Color3.fromRGB(236, 72, 153),
    accentCyan = Color3.fromRGB(56, 189, 248),
    green = Color3.fromRGB(34, 197, 94),
    red = Color3.fromRGB(239, 68, 68),
    redDark = Color3.fromRGB(153, 27, 27),
    text = Color3.fromRGB(240, 240, 255),
    subtext = Color3.fromRGB(140, 140, 200),
    divider = Color3.fromRGB(45, 45, 85),
    border = Color3.fromRGB(55, 55, 100),
    btnBlue = Color3.fromRGB(45, 55, 130),
    btnDark = Color3.fromRGB(30, 30, 65),
    toggleOn = Color3.fromRGB(139, 92, 246),
    toggleOff = Color3.fromRGB(45, 45, 80),
    hold = Color3.fromRGB(236, 72, 153),
}

print("[PhantomGUI] Cores definidas. Criando ScreenGui...")

-- ==========================================
--         SCREEN GUI
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PhantomUISystem"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = CoreGui

print("[PhantomGUI] ScreenGui criado.")

-- ==========================================
--         DRAG SYSTEM
-- ==========================================
local activeDragTarget = nil

local function makeDraggable(handle, target, onDragEnd)
    local dragging = false
    local pressing = false
    local dragOffX = 0
    local dragOffY = 0
    local startPosX = 0
    local startPosY = 0

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if activeDragTarget and activeDragTarget ~= target then
            return
        end
        if pressing then
            return
        end

        pressing = true
        dragging = false
        local absPos = target.AbsolutePosition
        dragOffX = input.Position.X - absPos.X
        dragOffY = input.Position.Y - absPos.Y
        startPosX = input.Position.X
        startPosY = input.Position.Y

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                if dragging and onDragEnd then
                    onDragEnd()
                end
                pressing = false
                dragging = false
                activeDragTarget = nil
            end
        end)
    end)

    local function onMove(input)
        if not pressing then
            return
        end
        if activeDragTarget and activeDragTarget ~= target then
            return
        end
        local delta = Vector2.new(
            input.Position.X - startPosX,
            input.Position.Y - startPosY
        )
        if not dragging then
            if delta.Magnitude >= 8 then
                dragging = true
                activeDragTarget = target
            else
                return
            end
        end
        local vp = Workspace.CurrentCamera.ViewportSize
        local tSz = target.AbsoluteSize
        local newX = math.clamp(input.Position.X - dragOffX, 0, vp.X - tSz.X)
        local newY = math.clamp(input.Position.Y - dragOffY, 0, vp.Y - tSz.Y)
        target.Position = UDim2.new(0, newX, 0, newY)
    end

    trackConn(UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            onMove(input)
        end
    end))

    return function()
        return dragging
    end
end

print("[PhantomGUI] Drag system criado.")

-- ==========================================
--         MINI GUI SPAM
-- ==========================================
local MINI_W = 120
local MINI_H = 90

local miniGui = Instance.new("Frame")
miniGui.Name = "PhantomSpamMini"
miniGui.Size = UDim2.new(0, MINI_W, 0, MINI_H)
miniGui.BackgroundColor3 = C.header
miniGui.BorderSizePixel = 0
miniGui.ZIndex = 15
miniGui.Parent = screenGui
Instance.new("UICorner", miniGui).CornerRadius = UDim.new(0, 14)

local miniGlow = Instance.new("Frame", miniGui)
miniGlow.Size = UDim2.new(1, 8, 1, 8)
miniGlow.Position = UDim2.new(0, -4, 0, -4)
miniGlow.BackgroundColor3 = C.accent
miniGlow.BackgroundTransparency = 0.92
miniGlow.BorderSizePixel = 0
miniGlow.ZIndex = 14
Instance.new("UICorner", miniGlow).CornerRadius = UDim.new(0, 18)

local miniStroke = Instance.new("UIStroke")
miniStroke.Color = C.accent
miniStroke.Thickness = 1.5
miniStroke.Parent = miniGui

local miniTitleBar = Instance.new("Frame")
miniTitleBar.Size = UDim2.new(1, 0, 0, 26)
miniTitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 46)
miniTitleBar.BorderSizePixel = 0
miniTitleBar.ZIndex = 16
miniTitleBar.Parent = miniGui
Instance.new("UICorner", miniTitleBar).CornerRadius = UDim.new(0, 14)

local miniTFill = Instance.new("Frame")
miniTFill.Size = UDim2.new(1, 0, 0, 12)
miniTFill.Position = UDim2.new(0, 0, 1, -12)
miniTFill.BackgroundColor3 = Color3.fromRGB(20, 20, 46)
miniTFill.BorderSizePixel = 0
miniTFill.ZIndex = 16
miniTFill.Parent = miniTitleBar

local miniAccent = Instance.new("Frame", miniTitleBar)
miniAccent.Size = UDim2.new(0.5, 0, 0, 2)
miniAccent.Position = UDim2.new(0.25, 0, 0, 0)
miniAccent.BackgroundColor3 = C.accentPink
miniAccent.BorderSizePixel = 0
miniAccent.ZIndex = 17
Instance.new("UICorner", miniAccent).CornerRadius = UDim.new(1, 0)

local miniTitle = Instance.new("TextLabel")
miniTitle.Size = UDim2.new(1, -8, 1, 0)
miniTitle.Position = UDim2.new(0, 8, 0, 0)
miniTitle.BackgroundTransparency = 1
miniTitle.Text = "Spam"
miniTitle.TextColor3 = C.subtext
miniTitle.TextScaled = true
miniTitle.Font = Enum.Font.GothamBold
miniTitle.ZIndex = 17
miniTitle.Parent = miniTitleBar

local spamBtn = Instance.new("TextButton")
spamBtn.Size = UDim2.new(1, -16, 0, 48)
spamBtn.Position = UDim2.new(0, 8, 0, 32)
spamBtn.BackgroundColor3 = C.red
spamBtn.BorderSizePixel = 0
spamBtn.Text = "OFF"
spamBtn.TextColor3 = Color3.new(1, 1, 1)
spamBtn.TextSize = 14
spamBtn.Font = Enum.Font.GothamBold
spamBtn.ZIndex = 16
spamBtn.Parent = miniGui
Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0, 10)

local spamBtnGlow = Instance.new("Frame", spamBtn)
spamBtnGlow.Size = UDim2.new(1, 6, 1, 6)
spamBtnGlow.Position = UDim2.new(0, -3, 0, -3)
spamBtnGlow.BackgroundColor3 = C.red
spamBtnGlow.BackgroundTransparency = 0.85
spamBtnGlow.BorderSizePixel = 0
spamBtnGlow.ZIndex = 15
Instance.new("UICorner", spamBtnGlow).CornerRadius = UDim.new(0, 12)

local spamOn = false
local function setSpam(v)
    spamOn = v
    _G.PhantomManual = v
    spamBtn.Text = v and "ON" or "OFF"
    twPlay(spamBtn, 0.18, {BackgroundColor3 = v and C.green or C.red}, Enum.EasingStyle.Back)
    twPlay(spamBtnGlow, 0.18, {BackgroundColor3 = v and C.green or C.red}, Enum.EasingStyle.Back)
end

spamBtn.Activated:Connect(function()
    if activeDragTarget == miniGui then
        return
    end
    setSpam(not spamOn)
end)

local miniVisibleX = Config.MiniX or (Workspace.CurrentCamera.ViewportSize.X - MINI_W - 14)
local miniVisibleY = Config.MiniY or (Workspace.CurrentCamera.ViewportSize.Y / 2 - MINI_H / 2)

local function getMiniHiddenX()
    return Workspace.CurrentCamera.ViewportSize.X + 30
end

miniGui.Position = UDim2.new(0, getMiniHiddenX(), 0, miniVisibleY)

local miniVisible = false

local function showMini(v, visBtn)
    miniVisible = v
    if v then
        twPlay(miniGui, 0.22, {Position = UDim2.new(0, miniVisibleX, 0, miniVisibleY)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    else
        twPlay(miniGui, 0.18, {Position = UDim2.new(0, getMiniHiddenX(), 0, miniVisibleY)}, Enum.EasingStyle.Quint)
    end
    if visBtn then
        visBtn.Text = v and "Mini UI: Visivel" or "Mini UI: Oculto"
        twPlay(visBtn, 0.15, {BackgroundColor3 = v and Color3.fromRGB(0, 130, 65) or C.btnDark})
    end
end

-- Drag do miniGui
local miniDragging = false
local miniPressing = false
local miniDragOffX = 0
local miniDragOffY = 0
local miniStartX = 0
local miniStartY = 0

miniTitleBar.InputBegan:Connect(function(input)
    if not miniVisible then
        return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if activeDragTarget and activeDragTarget ~= miniGui then
        return
    end
    if miniPressing then
        return
    end

    miniPressing = true
    miniDragging = false
    local absPos = miniGui.AbsolutePosition
    miniDragOffX = input.Position.X - absPos.X
    miniDragOffY = input.Position.Y - absPos.Y
    miniStartX = input.Position.X
    miniStartY = input.Position.Y

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            if miniDragging then
                miniVisibleX = miniGui.Position.X.Offset
                miniVisibleY = miniGui.Position.Y.Offset
                Config.MiniX = miniVisibleX
                Config.MiniY = miniVisibleY
                saveConfig(Config)
            end
            miniPressing = false
            miniDragging = false
            activeDragTarget = nil
        end
    end)
end)

trackConn(UIS.InputChanged:Connect(function(input)
    if not miniVisible then
        return
    end
    if not miniPressing then
        return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if activeDragTarget and activeDragTarget ~= miniGui then
        return
    end

    local delta = Vector2.new(input.Position.X - miniStartX, input.Position.Y - miniStartY)
    if not miniDragging then
        if delta.Magnitude >= 8 then
            miniDragging = true
            activeDragTarget = miniGui
        else
            return
        end
    end
    local vp = Workspace.CurrentCamera.ViewportSize
    local tSz = miniGui.AbsoluteSize
    local newX = math.clamp(input.Position.X - miniDragOffX, 0, vp.X - tSz.X)
    local newY = math.clamp(input.Position.Y - miniDragOffY, 0, vp.Y - tSz.Y)
    miniGui.Position = UDim2.new(0, newX, 0, newY)
end))

-- Keybind spam
trackConn(UIS.InputBegan:Connect(function(input, gpe)
    if not Config.SpamKeybind then
        return
    end
    if input.KeyCode ~= Config.SpamKeybind then
        return
    end
    if Config.SpamMode == "Hold" then
        setSpam(true)
    else
        setSpam(not spamOn)
    end
end))

trackConn(UIS.InputEnded:Connect(function(input)
    if not Config.SpamKeybind then
        return
    end
    if input.KeyCode ~= Config.SpamKeybind then
        return
    end
    if Config.SpamMode == "Hold" then
        setSpam(false)
    end
end))

print("[PhantomGUI] Mini GUI criado.")

-- ==========================================
--         BOTAO FLUTUANTE
-- ==========================================
local floatingButton = Instance.new("TextButton")
floatingButton.Size = UDim2.new(0, 56, 0, 56)
floatingButton.Position = Config.BtnX and UDim2.new(0, Config.BtnX, 0, Config.BtnY) or UDim2.new(1, -70, 0.5, -28)
floatingButton.BackgroundColor3 = C.header
floatingButton.BorderSizePixel = 0
floatingButton.Text = "P"
floatingButton.TextColor3 = C.text
floatingButton.TextSize = 26
floatingButton.Font = Enum.Font.GothamBold
floatingButton.Active = true
floatingButton.ZIndex = 10
floatingButton.Parent = screenGui
Instance.new("UICorner", floatingButton).CornerRadius = UDim.new(1, 0)

local floatGlow = Instance.new("Frame", floatingButton)
floatGlow.Size = UDim2.new(1, 10, 1, 10)
floatGlow.Position = UDim2.new(0, -5, 0, -5)
floatGlow.BackgroundColor3 = C.accent
floatGlow.BackgroundTransparency = 0.9
floatGlow.BorderSizePixel = 0
floatGlow.ZIndex = 9
Instance.new("UICorner", floatGlow).CornerRadius = UDim.new(1, 0)

local floatingStroke = Instance.new("UIStroke")
floatingStroke.Color = C.accent
floatingStroke.Thickness = 2
floatingStroke.Parent = floatingButton

-- Animacao de pulso do botao flutuante
task.spawn(function()
    while screenGui.Parent do
        twPlay(floatGlow, 0.8, {BackgroundTransparency = 0.75}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(0.8)
        twPlay(floatGlow, 0.8, {BackgroundTransparency = 0.92}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        task.wait(0.8)
    end
end)

print("[PhantomGUI] Botao flutuante criado.")

-- ==========================================
--         PAINEL PRINCIPAL
-- ==========================================
local PW, PH = 540, 360

local configPanel = Instance.new("Frame")
configPanel.Name = "PhantomPanel"
configPanel.Size = UDim2.new(0, PW, 0, PH)
configPanel.Position = Config.PanelX and UDim2.new(0, Config.PanelX, 0, Config.PanelY) or UDim2.new(0.5, -PW / 2, 0.5, -PH / 2)
configPanel.BackgroundColor3 = C.bg
configPanel.BackgroundTransparency = 0.04
configPanel.BorderSizePixel = 0
configPanel.Visible = false
configPanel.ZIndex = 5
configPanel.Parent = screenGui
Instance.new("UICorner", configPanel).CornerRadius = UDim.new(0, 16)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = C.accent
panelStroke.Thickness = 1.8
panelStroke.Parent = configPanel

-- Background gradient sutil
local panelGrad = Instance.new("UIGradient", configPanel)
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.accentCyan),
    ColorSequenceKeypoint.new(0.4, C.accent),
    ColorSequenceKeypoint.new(0.7, C.accentGlow),
    ColorSequenceKeypoint.new(1, C.bg),
})
panelGrad.Rotation = 135
panelGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.88),
    NumberSequenceKeypoint.new(0.3, 0.94),
    NumberSequenceKeypoint.new(0.6, 0.97),
    NumberSequenceKeypoint.new(1, 1),
})

print("[PhantomGUI] Painel principal criado.")

-- ==========================================
--         RGB LOOP (azul -> roxo -> rosa)
-- ==========================================
task.spawn(function()
    local t = 0
    while screenGui.Parent do
        t = (t + 0.004) % 1
        local hue = 0.60 + (math.sin(t * math.pi * 2) * 0.15)
        local col = Color3.fromHSV(hue, 0.75, 1)
        panelStroke.Color = col
        floatingStroke.Color = col
        miniStroke.Color = col
        task.wait(0.05)
    end
end)

-- ==========================================
--         TITLE BAR
-- ==========================================
local TITLE_H = 50

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = C.header
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 6
titleBar.Parent = configPanel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleBarFill = Instance.new("Frame")
titleBarFill.Size = UDim2.new(1, 0, 0, 16)
titleBarFill.Position = UDim2.new(0, 0, 1, -16)
titleBarFill.BackgroundColor3 = C.header
titleBarFill.BorderSizePixel = 0
titleBarFill.ZIndex = 6
titleBarFill.Parent = titleBar

-- Logo dot
local logoDot = Instance.new("Frame", titleBar)
logoDot.Size = UDim2.new(0, 10, 0, 10)
logoDot.Position = UDim2.new(0, 16, 0.5, -5)
logoDot.BackgroundColor3 = C.accentPink
logoDot.BorderSizePixel = 0
logoDot.ZIndex = 7
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)

-- Accent line no topo
local accentLine = Instance.new("Frame", titleBar)
accentLine.Size = UDim2.new(0, 60, 0, 3)
accentLine.Position = UDim2.new(0, 16, 0, 0)
accentLine.BackgroundColor3 = C.accent
accentLine.BorderSizePixel = 0
accentLine.ZIndex = 7
Instance.new("UICorner", accentLine).CornerRadius = UDim.new(0, 2)

local accentLineGrad = Instance.new("UIGradient", accentLine)
accentLineGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.accent),
    ColorSequenceKeypoint.new(0.5, C.accentGlow),
    ColorSequenceKeypoint.new(1, C.accentPink),
})

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 34, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Phantom  -  Config"
titleLabel.TextColor3 = C.text
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 7
titleLabel.Parent = titleBar

-- Subtitle
local subLabel = Instance.new("TextLabel", titleBar)
subLabel.Size = UDim2.new(0, 200, 0, 14)
subLabel.Position = UDim2.new(0, 34, 0.5, 6)
subLabel.BackgroundTransparency = 1
subLabel.Text = "v6.0  -  Professional"
subLabel.TextColor3 = C.subtext
subLabel.TextSize = 10
subLabel.Font = Enum.Font.Gotham
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.ZIndex = 7

local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, -28, 0, 1)
headerLine.Position = UDim2.new(0, 14, 1, 0)
headerLine.BackgroundColor3 = C.divider
headerLine.BorderSizePixel = 0
headerLine.ZIndex = 6
headerLine.Parent = titleBar

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -42, 0.5, -15)
closeButton.BackgroundColor3 = C.red
closeButton.BackgroundTransparency = 0.3
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 14
closeButton.Font = Enum.Font.GothamBold
closeButton.ZIndex = 7
closeButton.Parent = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

closeButton.MouseEnter:Connect(function()
    twPlay(closeButton, 0.12, {BackgroundTransparency = 0})
end)
closeButton.MouseLeave:Connect(function()
    twPlay(closeButton, 0.12, {BackgroundTransparency = 0.3})
end)

print("[PhantomGUI] Title bar criado.")

-- ==========================================
--         LAYOUT
-- ==========================================
local CONTENT_Y = TITLE_H + 12
local FOOTER_H = 54
local PAD = 14
local GAP = 12
local COL_W = math.floor((PW - PAD * 2 - GAP) / 2)

local colLeft = Instance.new("Frame")
colLeft.Size = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 8)
colLeft.Position = UDim2.new(0, PAD, 0, CONTENT_Y)
colLeft.BackgroundTransparency = 1
colLeft.ZIndex = 6
colLeft.Parent = configPanel

local colRight = Instance.new("Frame")
colRight.Size = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 8)
colRight.Position = UDim2.new(0, PAD + COL_W + GAP, 0, CONTENT_Y)
colRight.BackgroundTransparency = 1
colRight.ZIndex = 6
colRight.Parent = configPanel

-- Divider vertical com gradiente
local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 1, 0, PH - CONTENT_Y - FOOTER_H - 16)
divider.Position = UDim2.new(0, PAD + COL_W + math.floor(GAP / 2), 0, CONTENT_Y + 6)
divider.BackgroundColor3 = C.divider
divider.BorderSizePixel = 0
divider.ZIndex = 6
divider.Parent = configPanel

local divGrad = Instance.new("UIGradient", divider)
divGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, C.accent),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})
divGrad.Rotation = 90

print("[PhantomGUI] Layout criado.")

-- ==========================================
--         KILL BUTTON (footer)
-- ==========================================
local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0, 200, 0, 36)
killBtn.Position = UDim2.new(0.5, -100, 1, -FOOTER_H + 10)
killBtn.BackgroundColor3 = C.redDark
killBtn.BorderSizePixel = 0
killBtn.Text = "Fechar Script"
killBtn.TextColor3 = Color3.fromRGB(255, 185, 185)
killBtn.TextSize = 13
killBtn.Font = Enum.Font.GothamBold
killBtn.ZIndex = 7
killBtn.Parent = configPanel
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 10)

local killStroke = Instance.new("UIStroke", killBtn)
killStroke.Color = C.red
killStroke.Thickness = 1.5

if not UIS.TouchEnabled then
    killBtn.MouseEnter:Connect(function()
        twPlay(killBtn, 0.15, {BackgroundColor3 = Color3.fromRGB(185, 35, 35), Size = UDim2.new(0, 208, 0, 38)})
        killBtn.Position = UDim2.new(0.5, -104, 1, -FOOTER_H + 9)
    end)
    killBtn.MouseLeave:Connect(function()
        twPlay(killBtn, 0.15, {BackgroundColor3 = C.redDark, Size = UDim2.new(0, 200, 0, 36)})
        killBtn.Position = UDim2.new(0.5, -100, 1, -FOOTER_H + 10)
    end)
end

-- ==========================================
--         HELPERS (cards estilo Nexus)
-- ==========================================
local CARD_GAP = 8

local function cardFrame(yPos, h, parent)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, h)
    f.Position = UDim2.new(0, 0, 0, yPos)
    f.BackgroundColor3 = C.card
    f.BorderSizePixel = 0
    f.ZIndex = 6
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", f)
    stroke.Color = C.border
    stroke.Thickness = 1

    f.MouseEnter:Connect(function()
        twPlay(stroke, 0.15, {Color = C.accent})
        twPlay(f, 0.15, {BackgroundColor3 = Color3.fromRGB(24, 24, 50)})
    end)
    f.MouseLeave:Connect(function()
        twPlay(stroke, 0.15, {Color = C.border})
        twPlay(f, 0.15, {BackgroundColor3 = C.card})
    end)

    return f
end

local function cardLabel(text, parent)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -10, 0, 16)
    l.Position = UDim2.new(0, 10, 0, 5)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = C.accent
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 7
    l.Parent = parent
end

local function makeBtn(text, x, y, w, h, parent, bg)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, h)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = bg or C.btnBlue
    b.BorderSizePixel = 0
    b.Text = text
    b.TextColor3 = C.text
    b.TextSize = 13
    b.Font = Enum.Font.GothamBold
    b.ZIndex = 7
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

print("[PhantomGUI] Helpers criados.")

-- ==========================================
--         TOGGLE (estilo Nexus)
-- ==========================================
local function createToggle(labelText, configKey, yPos, parent)
    local f = cardFrame(yPos, 52, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = C.text
    lbl.TextSize = 14
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7
    lbl.Parent = f

    local track = Instance.new("Frame", f)
    track.Size = UDim2.new(0, 48, 0, 26)
    track.Position = UDim2.new(1, -62, 0.5, -13)
    track.BackgroundColor3 = Config[configKey] and C.toggleOn or C.toggleOff
    track.BorderSizePixel = 0
    track.ZIndex = 7
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 20, 0, 20)
    thumb.Position = Config[configKey] and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.ZIndex = 8
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local hitbox = Instance.new("TextButton", f)
    hitbox.Size = UDim2.new(1, 0, 1, 0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.ZIndex = 9

    hitbox.Activated:Connect(function()
        Config[configKey] = not Config[configKey]
        local v = Config[configKey]

        twPlay(track, 0.25, {BackgroundColor3 = v and C.toggleOn or C.toggleOff})
        twPlay(thumb, 0.25, {Position = v and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        saveConfig(Config)
    end)

    return yPos + 52 + CARD_GAP
end

-- ==========================================
--         CPS SPAM
-- ==========================================
local function createCPSSelector(yPos, parent)
    local CARD_H = 68
    local ROW_Y = 28
    local ROW_H = 30
    local f = cardFrame(yPos, CARD_H, parent)
    cardLabel("CPS Spam", f)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 36, 0, ROW_H)
    lbl.Position = UDim2.new(0, 14, 0, ROW_Y)
    lbl.BackgroundTransparency = 1
    lbl.Text = "CPS:"
    lbl.TextColor3 = C.text
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7
    lbl.Parent = f

    local defBtn = makeBtn("Padrao", 52, ROW_Y, 68, ROW_H, f, C.btnBlue)
    defBtn.TextSize = 11

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0, 72, 0, ROW_H)
    inputBox.Position = UDim2.new(1, -82, 0, ROW_Y)
    inputBox.BackgroundColor3 = C.inputBg
    inputBox.BorderSizePixel = 0
    inputBox.Text = tostring(Config.CPS)
    inputBox.PlaceholderText = "CPS"
    inputBox.TextColor3 = C.text
    inputBox.TextSize = 13
    inputBox.Font = Enum.Font.GothamBold
    inputBox.ZIndex = 7
    inputBox.Parent = f
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)
    local inputStroke = Instance.new("UIStroke", inputBox)
    inputStroke.Color = C.border
    inputStroke.Thickness = 1

    inputBox.Focused:Connect(function()
        twPlay(inputStroke, 0.15, {Color = C.accent})
    end)
    inputBox.FocusLost:Connect(function()
        twPlay(inputStroke, 0.15, {Color = C.border})
    end)

    defBtn.Activated:Connect(function()
        Config.CustomCPS = false
        Config.CPS = 22
        inputBox.Text = "22"
        twPlay(defBtn, 0.15, {BackgroundColor3 = C.green})
        task.delay(0.5, function()
            twPlay(defBtn, 0.15, {BackgroundColor3 = C.btnBlue})
        end)
        saveConfig(Config)
    end)

    inputBox.FocusLost:Connect(function()
        local v = tonumber(inputBox.Text)
        if v and v > 0 and v <= 1000 then
            if v ~= Config.CPS then
                Config.CPS = v
                Config.CustomCPS = true
            end
        else
            inputBox.Text = tostring(Config.CPS)
        end
        saveConfig(Config)
    end)

    return yPos + CARD_H + CARD_GAP
end

-- ==========================================
--         KEYBIND SELECTOR
-- ==========================================
local function createKeybindSelector(yPos, parent)
    local f = cardFrame(yPos, 52, parent)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Tecla de Atalho"
    lbl.TextColor3 = C.text
    lbl.TextSize = 14
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 7
    lbl.Parent = f

    local kbBtn = makeBtn(Config.Keybind.Name, 0, 0, 88, 30, f, C.btnBlue)
    kbBtn.Position = UDim2.new(1, -100, 0.5, -15)
    kbBtn.Font = Enum.Font.GothamBold

    local listening = false
    kbBtn.Activated:Connect(function()
        if listening then
            return
        end
        listening = true
        kbBtn.Text = "..."
        twPlay(kbBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(80, 85, 160)})
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then
                return
            end
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

    return yPos + 52 + CARD_GAP
end

-- ==========================================
--         CARD SPAM
-- ==========================================
local function createSpamPCCard(yPos, parent)
    local CARD_H = 118
    local f = cardFrame(yPos, CARD_H, parent)
    cardLabel("Manual Spam", f)

    local visBtn = makeBtn("Mini UI: Oculto", 8, 24, COL_W - 16, 30, f, C.btnDark)
    visBtn.TextSize = 11

    visBtn.Activated:Connect(function()
        showMini(not miniVisible, visBtn)
    end)

    local halfW = math.floor((COL_W - 32) / 2)

    local kbBtn = makeBtn(
        Config.SpamKeybind and Config.SpamKeybind.Name or "X",
        8, 64, halfW, 32, f, C.btnBlue
    )

    local listeningKb = false
    kbBtn.Activated:Connect(function()
        if listeningKb then
            return
        end
        listeningKb = true
        kbBtn.Text = "..."
        twPlay(kbBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(80, 85, 160)})
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then
                return
            end
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

    local function getModeColor(mode)
        return mode == "Hold" and C.hold or C.toggleOn
    end

    local modeBtn = makeBtn(
        Config.SpamMode or "Toggle",
        8 + halfW + 14, 64, halfW, 32, f,
        getModeColor(Config.SpamMode or "Toggle")
    )

    modeBtn.Activated:Connect(function()
        Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = Config.SpamMode
        twPlay(modeBtn, 0.18, {BackgroundColor3 = getModeColor(Config.SpamMode)}, Enum.EasingStyle.Back)
        if Config.SpamMode == "Toggle" and _G.PhantomManual then
            setSpam(false)
        end
        saveConfig(Config)
    end)

    return yPos + CARD_H + CARD_GAP
end

print("[PhantomGUI] Componentes criados.")

-- ==========================================
--         MONTAR COLUNAS
-- ==========================================
local yL, yR = 4, 4

yL = createToggle("Auto Parry", "AutoParry", yL, colLeft)
yL = createToggle("Aura Visual", "Aura", yL, colLeft)

-- Auto Clash
local clashOn = Config.AutoClash or false
_G.PhantomAutoClash = clashOn
local fClash = cardFrame(yL, 52, colLeft)
yL = yL + 52 + CARD_GAP

local clashLbl = Instance.new("TextLabel")
clashLbl.Size = UDim2.new(0.55, 0, 1, 0)
clashLbl.Position = UDim2.new(0, 14, 0, 0)
clashLbl.BackgroundTransparency = 1
clashLbl.Text = "Auto Clash"
clashLbl.TextColor3 = C.text
clashLbl.TextSize = 14
clashLbl.Font = Enum.Font.GothamSemibold
clashLbl.TextXAlignment = Enum.TextXAlignment.Left
clashLbl.ZIndex = 7
clashLbl.Parent = fClash

local clashTrack = Instance.new("Frame", fClash)
clashTrack.Size = UDim2.new(0, 48, 0, 26)
clashTrack.Position = UDim2.new(1, -62, 0.5, -13)
clashTrack.BackgroundColor3 = clashOn and C.toggleOn or C.toggleOff
clashTrack.BorderSizePixel = 0
clashTrack.ZIndex = 7
Instance.new("UICorner", clashTrack).CornerRadius = UDim.new(1, 0)

local clashThumb = Instance.new("Frame", clashTrack)
clashThumb.Size = UDim2.new(0, 20, 0, 20)
clashThumb.Position = clashOn and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
clashThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
clashThumb.BorderSizePixel = 0
clashThumb.ZIndex = 8
Instance.new("UICorner", clashThumb).CornerRadius = UDim.new(1, 0)

local clashHitbox = Instance.new("TextButton", fClash)
clashHitbox.Size = UDim2.new(1, 0, 1, 0)
clashHitbox.BackgroundTransparency = 1
clashHitbox.Text = ""
clashHitbox.ZIndex = 9

clashHitbox.Activated:Connect(function()
    clashOn = not clashOn
    _G.PhantomAutoClash = clashOn
    Config.AutoClash = clashOn
    twPlay(clashTrack, 0.25, {BackgroundColor3 = clashOn and C.toggleOn or C.toggleOff})
    twPlay(clashThumb, 0.25, {Position = clashOn and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    saveConfig(Config)
end)

yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)
yR = createSpamPCCard(yR, colRight)

print("[PhantomGUI] Colunas montadas.")

-- ==========================================
--         DRAG PAINEL / BOTAO
-- ==========================================
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

-- ==========================================
--         ABRIR / FECHAR PAINEL
-- ==========================================
local panelOpen = false
local tweenPanel = nil
local tweenBtn = nil

local function togglePanel()
    panelOpen = not panelOpen

    if tweenPanel then
        tweenPanel:Cancel()
    end
    if tweenBtn then
        tweenBtn:Cancel()
    end

    if panelOpen then
        floatingButton.Active = false
        tweenBtn = tw(floatingButton, 0.18, {BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 40, 0, 40)}, Enum.EasingStyle.Quint)
        tweenBtn:Play()

        configPanel.Visible = true
        configPanel.Size = UDim2.new(0, PW * 0.88, 0, PH * 0.88)
        configPanel.BackgroundTransparency = 1
        tweenPanel = tw(configPanel, 0.28, {Size = UDim2.new(0, PW, 0, PH), BackgroundTransparency = 0.04}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tweenPanel:Play()
    else
        tweenBtn = tw(floatingButton, 0.22, {BackgroundTransparency = 0, TextTransparency = 0, Size = UDim2.new(0, 56, 0, 56)}, Enum.EasingStyle.Back)
        tweenBtn:Play()
        tweenBtn.Completed:Connect(function()
            floatingButton.Active = true
        end)

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
    if btnWasDrag() then
        return
    end
    togglePanel()
end)

closeButton.Activated:Connect(function()
    if panelOpen then
        togglePanel()
    end
end)

trackConn(UIS.InputBegan:Connect(function(input)
    if activeDragTarget then
        return
    end
    if input.KeyCode == Config.Keybind then
        togglePanel()
    end
end))

print("[PhantomGUI] Sistema abrir/fechar configurado.")

-- ==========================================
--         FECHAR SCRIPT
-- ==========================================
killBtn.Activated:Connect(function()
    State.scriptActive = false
    _G.PhantomManual = false
    _G.PhantomAutoClash = false
    saveConfig(Config)

    twPlay(configPanel, 0.25, {BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85)}, Enum.EasingStyle.Quint)
    twPlay(floatingButton, 0.25, {BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})

    task.wait(0.3)
    for _, c in ipairs(State.connections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    pcall(function()
        State.outer:Destroy()
    end)
    pcall(function()
        State.inner:Destroy()
    end)
    pcall(function()
        screenGui:Destroy()
    end)
    print("[PhantomGUI] Script encerrado.")
end)

-- ==========================================
--         SCAN LINE (efeito Nexus)
-- ==========================================
local scanLine = Instance.new("Frame", configPanel)
scanLine.Size = UDim2.new(1, 0, 0, 2)
scanLine.Position = UDim2.new(0, 0, 0, 0)
scanLine.BackgroundColor3 = C.accent
scanLine.BackgroundTransparency = 0.85
scanLine.BorderSizePixel = 0
scanLine.ZIndex = 1

local scanGrad = Instance.new("UIGradient", scanLine)
scanGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, C.accent),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})

task.spawn(function()
    while true do
        if not configPanel.Parent then
            break
        end
        twPlay(scanLine, 2.5, {Position = UDim2.new(0, 0, 1, 0)}, Enum.EasingStyle.Linear)
        task.wait(2.5)
        scanLine.Position = UDim2.new(0, 0, 0, 0)
        task.wait(0.1)
    end
end)

-- ==========================================
--         PARTICLES (efeito Nexus)
-- ==========================================
local particleContainer = Instance.new("Frame", configPanel)
particleContainer.Size = UDim2.new(1, 0, 1, 0)
particleContainer.BackgroundTransparency = 1
particleContainer.ZIndex = 0
particleContainer.ClipsDescendants = true

local function spawnParticle()
    local dot = Instance.new("Frame", particleContainer)
    dot.Size = UDim2.new(0, math.random(2, 5), 0, math.random(2, 5))
    dot.Position = UDim2.new(math.random(), 0, 1, 0)
    local colors = {C.accent, C.accentGlow, C.accentPink, C.accentCyan}
    dot.BackgroundColor3 = colors[math.random(1, #colors)]
    dot.BackgroundTransparency = 0.5
    dot.BorderSizePixel = 0
    dot.ZIndex = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local dur = math.random(3, 7)
    twPlay(dot, dur, {Position = UDim2.new(dot.Position.X.Scale, 0, -0.1, 0), BackgroundTransparency = 1}, Enum.EasingStyle.Linear)
    task.delay(dur, function()
        if dot.Parent then
            dot:Destroy()
        end
    end)
end

task.spawn(function()
    while true do
        task.wait(math.random() * 0.8 + 0.2)
        if configPanel.Visible then
            spawnParticle()
        end
    end
end)

print("[PhantomGUI] Efeitos visuais configurados.")
print("[PhantomGUI] GUI v6.0 carregada com sucesso!")
print("[PhantomGUI] Botao P para configurar | tecla: " .. Config.Keybind.Name)
