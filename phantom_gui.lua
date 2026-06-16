-- Phantom Ball GUI v9.0
-- Refactor: glow leak fix, z-index cleanup, layered shell pattern
-- Paleta: Azul / Roxo / Rosa

print("[PhantomGUI] Iniciando carregamento v9.0...")

local timeout = 0
while not _G.PhantomConfig and timeout < 10 do
        task.wait(0.1)
        timeout = timeout + 0.1
end

if not _G.PhantomConfig then
        warn("[PhantomGUI] ERRO: _G.PhantomConfig nao encontrada. Rode phantom_logic_v8.lua primeiro.")
        return
end

print("[PhantomGUI] Config encontrada, prosseguindo...")

local CoreGui = game:GetService("CoreGui")
local existing = CoreGui:FindFirstChild("PhantomUISystem")
if existing then
        existing:Destroy()
end

local Config = _G.PhantomConfig
local State = _G.PhantomState
local saveConfig = _G.PhantomSaveConfig

local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- ============================================================
-- HELPERS
-- ============================================================
local function tw(obj, t, props, style, dir)
        return TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
end

local function twPlay(obj, t, props, style, dir)
        local tween = tw(obj, t, props, style, dir)
        tween:Play()
        return tween
end

local function trackConn(c)
        State.connections[#State.connections + 1] = c
end

-- Camadas ZIndex (sempre respeitar pra evitar vazamento de glow)
local LAYER = {
        bg        = 1,  -- fundo / partículas
        shadow    = 2,  -- sombra externa (NUNCA dentro de ClipsDescendants)
        content   = 3,  -- cards, header, footer
        contentFx = 4,  -- hover state, scan line
        interactive = 5, -- botões / inputs
        modal     = 6,  -- tooltips / overlays
}

-- Helper: cria um "shell" (Frame com UICorner) e dentro poe o elemento principal
-- Isso garante que o UICorner do shell clipe TUDO dentro, incluindo glows.
local function shell(parent, size, pos, radius, bg, bgTransparency, zindex)
        local s = Instance.new("Frame")
        s.Size = size
        s.Position = pos or UDim2.new()
        s.BackgroundColor3 = bg or Color3.new(0, 0, 0)
        s.BackgroundTransparency = bgTransparency or 0
        s.BorderSizePixel = 0
        s.ZIndex = zindex or LAYER.content
        s.ClipsDescendants = true
        s.Parent = parent
        Instance.new("UICorner", s).CornerRadius = UDim.new(0, radius or 12)
        return s
end

local function addStroke(parent, color, thickness)
        local s = Instance.new("UIStroke")
        s.Color = color
        s.Thickness = thickness or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
end

local function addGradient(parent, colorSeq, rotation)
        local g = Instance.new("UIGradient")
        g.Color = colorSeq
        g.Rotation = rotation or 0
        g.Parent = parent
        return g
end

-- ============================================================
-- PALETA
-- ============================================================
local C = {
        bg          = Color3.fromRGB(8, 8, 22),
        bgDeep      = Color3.fromRGB(5, 5, 16),
        header      = Color3.fromRGB(14, 14, 34),
        card        = Color3.fromRGB(20, 20, 44),
        cardHover   = Color3.fromRGB(26, 26, 56),
        panel       = Color3.fromRGB(26, 26, 52),
        inputBg     = Color3.fromRGB(12, 12, 30),
        accent      = Color3.fromRGB(99, 102, 241),
        accentGlow  = Color3.fromRGB(139, 92, 246),
        accentPink  = Color3.fromRGB(236, 72, 153),
        accentCyan  = Color3.fromRGB(56, 189, 248),
        green       = Color3.fromRGB(34, 197, 94),
        red         = Color3.fromRGB(239, 68, 68),
        redDark     = Color3.fromRGB(153, 27, 27),
        text        = Color3.fromRGB(240, 240, 255),
        subtext     = Color3.fromRGB(140, 140, 200),
        divider     = Color3.fromRGB(45, 45, 85),
        border      = Color3.fromRGB(55, 55, 100),
        btnBlue     = Color3.fromRGB(45, 55, 130),
        btnDark     = Color3.fromRGB(30, 30, 65),
        toggleOn    = Color3.fromRGB(139, 92, 246),
        toggleOff   = Color3.fromRGB(45, 45, 80),
        hold        = Color3.fromRGB(236, 72, 153),
}

-- ============================================================
-- SCREEN GUI
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PhantomUISystem"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

-- ============================================================
-- DRAG SYSTEM v3
-- ============================================================
local function makeDraggable(handle, target, onDragEnd)
        local state = "Idle"
        local dragOffX, dragOffY = 0, 0
        local startPosX, startPosY = 0, 0
        local dragInput = nil
        local wasDragged = false

        local inputBeganConn = handle.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                end
                if state ~= "Idle" then return end
                state = "Pressed"
                wasDragged = false
                local absPos = target.AbsolutePosition
                dragOffX = input.Position.X - absPos.X
                dragOffY = input.Position.Y - absPos.Y
                startPosX = input.Position.X
                startPosY = input.Position.Y
                dragInput = input
        end)

        local inputChangedConn = UIS.InputChanged:Connect(function(input)
                if state == "Idle" or input ~= dragInput then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                        and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                end
                local deltaX = input.Position.X - startPosX
                local deltaY = input.Position.Y - startPosY
                if state == "Pressed" then
                        if Vector2.new(deltaX, deltaY).Magnitude >= 10 then
                                state = "Dragging"
                                wasDragged = true
                        else
                                return
                        end
                end
                if state == "Dragging" then
                        local vp = Workspace.CurrentCamera.ViewportSize
                        local tSz = target.AbsoluteSize
                        local newX = math.clamp(input.Position.X - dragOffX, 0, vp.X - tSz.X)
                        local newY = math.clamp(input.Position.Y - dragOffY, 0, vp.Y - tSz.Y)
                        target.Position = UDim2.new(0, newX, 0, newY)
                end
        end)

        local inputEndedConn = UIS.InputEnded:Connect(function(input)
                if input ~= dragInput or state == "Idle" then return end
                state = "Idle"
                dragInput = nil
                if wasDragged and onDragEnd then onDragEnd() end
                wasDragged = false
        end)

        trackConn(inputBeganConn)
        trackConn(inputChangedConn)
        trackConn(inputEndedConn)

        return function() return state == "Dragging" end
end

-- ============================================================
-- GLOW HELPER (interno, fica sempre DENTRO de um ClipsDescendants shell)
-- ============================================================
local function addInnerGlow(parent, color, intensity, size)
        -- O glow é um frame centralizado dentro do parent.
        -- O parent TEM ClipsDescendants = true (via shell), então o glow é clipado ao raio.
        local glow = Instance.new("Frame")
        glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.fromScale(0.5, 0.5)
        glow.Size = UDim2.new(1, size or 12, 1, size or 12)
        glow.BackgroundColor3 = color
        glow.BackgroundTransparency = 1 - (intensity or 0.08)
        glow.BorderSizePixel = 0
        glow.ZIndex = parent.ZIndex -- fica na mesma camada do shell, atrás do conteúdo se possível
        glow.Parent = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, (parent:FindFirstChildWhichIsA("UICorner") and parent:FindFirstChildWhichIsA("UICorner").CornerRadius.Offset) or 12)
        corner.Parent = glow
        return glow
end

-- ============================================================
-- MINI GUI (Spam floating)
-- ============================================================
local MINI_W, MINI_H = 140, 100

-- Shell externo: faz o clipping pra evitar glow leak
local miniShell = Instance.new("Frame")
miniShell.Name = "PhantomSpamMini"
miniShell.Size = UDim2.new(0, MINI_W, 0, MINI_H)
miniShell.BackgroundColor3 = C.bgDeep
miniShell.BackgroundTransparency = 0.0
miniShell.BorderSizePixel = 0
miniShell.ZIndex = LAYER.content
miniShell.ClipsDescendants = true
miniShell.Parent = screenGui
Instance.new("UICorner", miniShell).CornerRadius = UDim.new(0, 14)

-- Glow interno (FICA DENTRO do shell, clipado)
local miniGlow = addInnerGlow(miniShell, C.accentGlow, 0.08, 8)

-- Conteúdo do mini (header bar + body)
local miniContent = Instance.new("Frame")
miniContent.Size = UDim2.new(1, 0, 1, 0)
miniContent.BackgroundTransparency = 1
miniContent.ZIndex = LAYER.content + 1
miniContent.Parent = miniShell

local miniStroke = addStroke(miniShell, C.accent, 1.5)

-- Title bar
local TITLE_H_MINI = 28
local miniTitleBar = Instance.new("Frame")
miniTitleBar.Size = UDim2.new(1, 0, 0, TITLE_H_MINI)
miniTitleBar.BackgroundColor3 = C.header
miniTitleBar.BackgroundTransparency = 0
miniTitleBar.BorderSizePixel = 0
miniTitleBar.ZIndex = LAYER.interactive
miniTitleBar.Parent = miniContent
Instance.new("UICorner", miniTitleBar).CornerRadius = UDim.new(0, 14)

-- Preenche o canto quadrado embaixo do header
local miniTitleFill = Instance.new("Frame")
miniTitleFill.Size = UDim2.new(1, 0, 0, 14)
miniTitleFill.Position = UDim2.new(0, 0, 1, -14)
miniTitleFill.BackgroundColor3 = C.header
miniTitleFill.BorderSizePixel = 0
miniTitleFill.ZIndex = LAYER.interactive
miniTitleFill.Parent = miniTitleBar

-- Accent line
local miniAccent = Instance.new("Frame")
miniAccent.Size = UDim2.new(0.5, 0, 0, 2)
miniAccent.Position = UDim2.new(0.25, 0, 1, -2)
miniAccent.BackgroundColor3 = C.accentPink
miniAccent.BorderSizePixel = 0
miniAccent.ZIndex = LAYER.interactive + 1
miniAccent.Parent = miniTitleBar
Instance.new("UICorner", miniAccent).CornerRadius = UDim.new(1, 0)

local miniTitle = Instance.new("TextLabel")
miniTitle.Size = UDim2.new(1, -16, 1, 0)
miniTitle.Position = UDim2.new(0, 12, 0, 0)
miniTitle.BackgroundTransparency = 1
miniTitle.Text = "◆ Spam"
miniTitle.TextColor3 = C.subtext
miniTitle.TextScaled = true
miniTitle.Font = Enum.Font.GothamBold
miniTitle.ZIndex = LAYER.interactive + 1
miniTitle.Parent = miniTitleBar

-- Spam button
local spamBtn = Instance.new("TextButton")
spamBtn.Size = UDim2.new(1, -20, 0, 52)
spamBtn.Position = UDim2.new(0, 10, 0, 36)
spamBtn.BackgroundColor3 = C.red
spamBtn.BackgroundTransparency = 0
spamBtn.BorderSizePixel = 0
spamBtn.Text = "OFF"
spamBtn.TextColor3 = Color3.new(1, 1, 1)
spamBtn.TextSize = 18
spamBtn.Font = Enum.Font.GothamBold
spamBtn.AutoButtonColor = false
spamBtn.ZIndex = LAYER.interactive
spamBtn.Parent = miniContent
Instance.new("UICorner", spamBtn).CornerRadius = UDim.new(0, 10)
addStroke(spamBtn, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.7

local spamOn = false
local function setSpam(v)
        spamOn = v
        _G.PhantomManual = v
        spamBtn.Text = v and "ON" or "OFF"
        twPlay(spamBtn, 0.2, {
                BackgroundColor3 = v and C.green or C.red,
                Size = UDim2.new(1, v and -16 or -20, 0, v and 54 or 52),
        }, Enum.EasingStyle.Back)
end

spamBtn.Activated:Connect(function()
        setSpam(not spamOn)
end)

spamBtn.MouseEnter:Connect(function()
        twPlay(spamBtn, 0.15, {BackgroundTransparency = 0.15})
end)
spamBtn.MouseLeave:Connect(function()
        twPlay(spamBtn, 0.15, {BackgroundTransparency = 0})
end)

-- Initial position
local miniVisibleX = Config.MiniX or (Workspace.CurrentCamera.ViewportSize.X - MINI_W - 14)
local miniVisibleY = Config.MiniY or (Workspace.CurrentCamera.ViewportSize.Y / 2 - MINI_H / 2)

local function getMiniHiddenX()
        return Workspace.CurrentCamera.ViewportSize.X + 30
end

miniShell.Position = UDim2.new(0, getMiniHiddenX(), 0, miniVisibleY)

local miniVisible = false
local function showMini(v, visBtn)
        miniVisible = v
        if v then
                twPlay(miniShell, 0.28, {Position = UDim2.new(0, miniVisibleX, 0, miniVisibleY)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        else
                twPlay(miniShell, 0.22, {Position = UDim2.new(0, getMiniHiddenX(), 0, miniVisibleY)}, Enum.EasingStyle.Quint)
        end
        if visBtn then
                visBtn.Text = v and "Mini UI: Visivel" or "Mini UI: Oculto"
                twPlay(visBtn, 0.15, {BackgroundColor3 = v and Color3.fromRGB(0, 130, 65) or C.btnDark})
        end
end

makeDraggable(miniTitleBar, miniShell, function()
        miniVisibleX = miniShell.Position.X.Offset
        miniVisibleY = miniShell.Position.Y.Offset
        Config.MiniX = miniVisibleX
        Config.MiniY = miniVisibleY
        saveConfig(Config)
end)

trackConn(UIS.InputBegan:Connect(function(input, gpe)
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
        if Config.SpamMode == "Hold" then
                setSpam(false)
        end
end))

-- ============================================================
-- FLOATING BUTTON (P)
-- ============================================================
local BTN_SIZE = 56

-- Shell com clip
local floatShell = Instance.new("Frame")
floatShell.Name = "FloatShell"
floatShell.Size = UDim2.new(0, BTN_SIZE + 8, 0, BTN_SIZE + 8)
floatShell.Position = Config.BtnX and UDim2.new(0, Config.BtnX - 4, 0, Config.BtnY - 4) or UDim2.new(1, -70, 0.5, -32)
floatShell.BackgroundTransparency = 1
floatShell.BorderSizePixel = 0
floatShell.ZIndex = LAYER.shadow
floatShell.ClipsDescendants = true
floatShell.Parent = screenGui
Instance.new("UICorner", floatShell).CornerRadius = UDim.new(1, 0)

-- Glow interno (pulsa)
local floatGlow = addInnerGlow(floatShell, C.accentGlow, 0.1, 6)

-- Botão em si (dentro do shell)
local floatingButton = Instance.new("TextButton")
floatingButton.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
floatingButton.Position = UDim2.new(0, 4, 0, 4)
floatingButton.BackgroundColor3 = C.header
floatingButton.BackgroundTransparency = 0
floatingButton.BorderSizePixel = 0
floatingButton.Text = "P"
floatingButton.TextColor3 = C.text
floatingButton.TextSize = 28
floatingButton.Font = Enum.Font.GothamBold
floatingButton.AutoButtonColor = false
floatingButton.Active = true
floatingButton.ZIndex = LAYER.interactive
floatingButton.Parent = floatShell
Instance.new("UICorner", floatingButton).CornerRadius = UDim.new(1, 0)

addGradient(floatingButton, ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(0.5, C.accentGlow),
        ColorSequenceKeypoint.new(1, C.accentPink),
}), 45).Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(0.5, 0.0),
        NumberSequenceKeypoint.new(1, 0.7),
})
floatingButton.BackgroundColor3 = C.bgDeep

local floatingStroke = addStroke(floatingButton, C.accent, 2)

-- Pulso do botão
task.spawn(function()
        while screenGui.Parent do
                twPlay(floatGlow, 0.9, {BackgroundTransparency = 0.85}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(0.9)
                twPlay(floatGlow, 0.9, {BackgroundTransparency = 0.92}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(0.9)
        end
end)

-- ============================================================
-- PAINEL PRINCIPAL
-- ============================================================
local PW, PH = 560, 380

-- Shadow externa: NÃO é filho do panel (senão ClipsDescendants come)
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(0, PW + 24, 0, PH + 24)
shadow.Position = UDim2.new(0, -12, 0, -12)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.4
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
shadow.SliceScale = 0.18
shadow.ZIndex = LAYER.shadow
shadow.Parent = screenGui

-- Panel shell
local configPanel = Instance.new("Frame")
configPanel.Name = "PhantomPanel"
configPanel.Size = UDim2.new(0, PW, 0, PH)
configPanel.Position = Config.PanelX and UDim2.new(0, Config.PanelX, 0, Config.PanelY) or UDim2.new(0.5, -PW / 2, 0.5, -PH / 2)
configPanel.BackgroundColor3 = C.bg
configPanel.BackgroundTransparency = 0
configPanel.BorderSizePixel = 0
configPanel.Visible = false
configPanel.ZIndex = LAYER.content
configPanel.ClipsDescendants = true
configPanel.Parent = screenGui
Instance.new("UICorner", configPanel).CornerRadius = UDim.new(0, 18)

-- Shadow SÊNIOR: outro abaixo, esse sim visualmente ok
-- (ImageLabel vs Frame preto sólido – ImageLabel com slice fica melhor)
local panelStroke = addStroke(configPanel, C.accent, 2)

-- Glow interno do panel
local panelGlow = addInnerGlow(configPanel, C.accent, 0.04, 16)

-- Bg gradient
local panelBgGrad = addGradient(configPanel, ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.bg),
        ColorSequenceKeypoint.new(1, C.bgDeep),
}), 90)

-- Faz o shadow seguir o panel
task.spawn(function()
        while screenGui.Parent do
                if configPanel.Visible then
                        shadow.Position = UDim2.new(
                                configPanel.Position.X.Scale,
                                configPanel.Position.X.Offset - 12,
                                configPanel.Position.Y.Scale,
                                configPanel.Position.Y.Offset - 12
                        )
                        shadow.Size = configPanel.Size + UDim2.new(0, 24, 0, 24)
                end
                task.wait(0.1)
        end
end)

-- ============================================================
-- RGB LOOP (stroke dos elementos)
-- ============================================================
task.spawn(function()
        local t = 0
        while screenGui.Parent do
                t = (t + 0.004) % 1
                local hue = 0.62 + (math.sin(t * math.pi * 2) * 0.18)
                local col = Color3.fromHSV(hue, 0.7, 1)
                panelStroke.Color = col
                floatingStroke.Color = col
                miniStroke.Color = col
                task.wait(0.05)
        end
end)

-- ============================================================
-- TITLE BAR (dentro do panel, mas o panel já tem ClipsDescendants)
-- ============================================================
local TITLE_H = 54

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = C.header
titleBar.BackgroundTransparency = 0
titleBar.BorderSizePixel = 0
titleBar.ZIndex = LAYER.content + 1
titleBar.Parent = configPanel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 18)

-- Preenche o canto quadrado inferior
local titleBarFill = Instance.new("Frame")
titleBarFill.Size = UDim2.new(1, 0, 0, 18)
titleBarFill.Position = UDim2.new(0, 0, 1, -18)
titleBarFill.BackgroundColor3 = C.header
titleBarFill.BorderSizePixel = 0
titleBarFill.ZIndex = LAYER.content + 1
titleBarFill.Parent = titleBar

-- Gradient no header
addGradient(titleBar, ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.header),
        ColorSequenceKeypoint.new(1, C.bg),
}), 90)

-- Logo dot
local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.new(0, 10, 0, 10)
logoDot.Position = UDim2.new(0, 18, 0.5, -5)
logoDot.BackgroundColor3 = C.accentPink
logoDot.BorderSizePixel = 0
logoDot.ZIndex = LAYER.content + 2
logoDot.Parent = titleBar
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)

-- Logo dot glow
addInnerGlow(titleBar, C.accentPink, 0.15, 4)

-- Accent line gradient
local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(0, 70, 0, 3)
accentLine.Position = UDim2.new(0, 18, 0, 0)
accentLine.BackgroundColor3 = C.accent
accentLine.BorderSizePixel = 0
accentLine.ZIndex = LAYER.content + 2
accentLine.Parent = titleBar
Instance.new("UICorner", accentLine).CornerRadius = UDim.new(0, 2)
addGradient(accentLine, ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(0.5, C.accentGlow),
        ColorSequenceKeypoint.new(1, C.accentPink),
}))

-- Title text
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -120, 1, 0)
titleLabel.Position = UDim2.new(0, 36, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Phantom"
titleLabel.TextColor3 = C.text
titleLabel.TextSize = 17
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = LAYER.content + 2
titleLabel.Parent = titleBar

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(0, 200, 0, 14)
subLabel.Position = UDim2.new(0, 36, 0.5, 4)
subLabel.BackgroundTransparency = 1
subLabel.Text = "Config v9.0"
subLabel.TextColor3 = C.subtext
subLabel.TextSize = 10
subLabel.Font = Enum.Font.GothamMedium
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.ZIndex = LAYER.content + 2
subLabel.Parent = titleBar

-- Version badge (cantinho direito)
local versionBadge = Instance.new("Frame")
versionBadge.Size = UDim2.new(0, 56, 0, 22)
versionBadge.Position = UDim2.new(1, -110, 0.5, -11)
versionBadge.BackgroundColor3 = C.bgDeep
versionBadge.BorderSizePixel = 0
versionBadge.ZIndex = LAYER.content + 2
versionBadge.Parent = titleBar
Instance.new("UICorner", versionBadge).CornerRadius = UDim.new(0, 6)
addStroke(versionBadge, C.accent, 1)

local versionText = Instance.new("TextLabel")
versionText.Size = UDim2.new(1, 0, 1, 0)
versionText.BackgroundTransparency = 1
versionText.Text = "v9.0"
versionText.TextColor3 = C.accent
versionText.TextSize = 11
versionText.Font = Enum.Font.GothamBold
versionText.ZIndex = LAYER.content + 3
versionText.Parent = versionBadge

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.Position = UDim2.new(1, -42, 0.5, -16)
closeButton.BackgroundColor3 = C.red
closeButton.BackgroundTransparency = 0.3
closeButton.BorderSizePixel = 0
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextSize = 14
closeButton.Font = Enum.Font.GothamBold
closeButton.AutoButtonColor = false
closeButton.ZIndex = LAYER.content + 2
closeButton.Parent = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)
addStroke(closeButton, C.red, 1)

closeButton.MouseEnter:Connect(function()
        twPlay(closeButton, 0.15, {BackgroundTransparency = 0, Rotation = 90})
end)
closeButton.MouseLeave:Connect(function()
        twPlay(closeButton, 0.15, {BackgroundTransparency = 0.3, Rotation = 0})
end)

-- Header bottom divider
local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, -28, 0, 1)
headerLine.Position = UDim2.new(0, 14, 1, -1)
headerLine.BackgroundColor3 = C.divider
headerLine.BorderSizePixel = 0
headerLine.ZIndex = LAYER.content + 1
headerLine.Parent = titleBar
addGradient(headerLine, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, C.accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
}))

-- ============================================================
-- LAYOUT
-- ============================================================
local CONTENT_Y = TITLE_H + 12
local FOOTER_H = 50
local PAD = 14
local GAP = 12
local COL_W = math.floor((PW - PAD * 2 - GAP) / 2)

local colLeft = Instance.new("Frame")
colLeft.Size = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 8)
colLeft.Position = UDim2.new(0, PAD, 0, CONTENT_Y)
colLeft.BackgroundTransparency = 1
colLeft.ZIndex = LAYER.content + 1
colLeft.ClipsDescendants = true
colLeft.Parent = configPanel

local colRight = Instance.new("Frame")
colRight.Size = UDim2.new(0, COL_W, 0, PH - CONTENT_Y - FOOTER_H - 8)
colRight.Position = UDim2.new(0, PAD + COL_W + GAP, 0, CONTENT_Y)
colRight.BackgroundTransparency = 1
colRight.ZIndex = LAYER.content + 1
colRight.ClipsDescendants = true
colRight.Parent = configPanel

local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 1, 1, -16)
divider.Position = UDim2.new(0, PAD + COL_W + math.floor(GAP / 2) - 0.5, 0, CONTENT_Y + 8)
divider.BackgroundColor3 = C.divider
divider.BorderSizePixel = 0
divider.ZIndex = LAYER.content + 1
divider.Parent = configPanel
addGradient(divider, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, C.accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
}), 90)

-- ============================================================
-- FOOTER + KILL BUTTON
-- ============================================================
local footer = Instance.new("Frame")
footer.Size = UDim2.new(1, 0, 0, FOOTER_H)
footer.Position = UDim2.new(0, 0, 1, -FOOTER_H)
footer.BackgroundColor3 = C.header
footer.BackgroundTransparency = 0
footer.BorderSizePixel = 0
footer.ZIndex = LAYER.content + 1
footer.Parent = configPanel
addGradient(footer, ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.bg),
        ColorSequenceKeypoint.new(1, C.header),
}), 270)

-- Top line do footer
local footerLine = Instance.new("Frame")
footerLine.Size = UDim2.new(1, -28, 0, 1)
footerLine.Position = UDim2.new(0, 14, 0, 0)
footerLine.BackgroundColor3 = C.divider
footerLine.BorderSizePixel = 0
footerLine.ZIndex = LAYER.content + 2
footerLine.Parent = footer
addGradient(footerLine, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, C.accentPink),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
}))

-- Kill button (footer)
local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0, 150, 0, 30)
killBtn.Position = UDim2.new(0.5, -75, 1, -20)
killBtn.AnchorPoint = Vector2.new(0, 0)
killBtn.BackgroundColor3 = C.redDark
killBtn.BackgroundTransparency = 0
killBtn.BorderSizePixel = 0
killBtn.Text = "✕  Fechar Script"
killBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
killBtn.TextSize = 12
killBtn.Font = Enum.Font.GothamBold
killBtn.AutoButtonColor = false
killBtn.ZIndex = LAYER.interactive
killBtn.Parent = footer
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 8)
local killStroke = addStroke(killBtn, C.red, 1.2)

-- Status indicator (footer left)
local statusWrap = Instance.new("Frame")
statusWrap.Size = UDim2.new(0, 100, 0, 16)
statusWrap.Position = UDim2.new(0, 14, 1, -22)
statusWrap.BackgroundTransparency = 1
statusWrap.ZIndex = LAYER.content + 2
statusWrap.Parent = footer

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 0, 0.5, -4)
statusDot.BackgroundColor3 = C.green
statusDot.BorderSizePixel = 0
statusDot.ZIndex = LAYER.content + 3
statusDot.Parent = statusWrap
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, -16, 1, 0)
statusText.Position = UDim2.new(0, 14, 0, 0)
statusText.BackgroundTransparency = 1
statusText.Text = "Ativo"
statusText.TextColor3 = C.subtext
statusText.TextSize = 10
statusText.Font = Enum.Font.GothamMedium
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.ZIndex = LAYER.content + 3
statusText.Parent = statusWrap

-- Hover do kill
killBtn.MouseEnter:Connect(function()
        twPlay(killBtn, 0.18, {BackgroundColor3 = Color3.fromRGB(200, 40, 40), Size = UDim2.new(0, 156, 0, 32)}, Enum.EasingStyle.Back)
        twPlay(killStroke, 0.18, {Color = Color3.fromRGB(255, 100, 100), Thickness = 1.5})
end)
killBtn.MouseLeave:Connect(function()
        twPlay(killBtn, 0.18, {BackgroundColor3 = C.redDark, Size = UDim2.new(0, 150, 0, 30)}, Enum.EasingStyle.Back)
        twPlay(killStroke, 0.18, {Color = C.red, Thickness = 1.2})
end)

-- Pulso do status dot
task.spawn(function()
        while screenGui.Parent do
                twPlay(statusDot, 1.2, {BackgroundTransparency = 0.4}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(1.2)
                twPlay(statusDot, 1.2, {BackgroundTransparency = 0}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(1.2)
        end
end)

-- ============================================================
-- HELPERS
-- ============================================================
local CARD_GAP = 8
local CARD_RADIUS = 12

local function cardFrame(yPos, h, parent)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, h)
        f.Position = UDim2.new(0, 0, 0, yPos)
        f.BackgroundColor3 = C.card
        f.BackgroundTransparency = 0
        f.BorderSizePixel = 0
        f.ZIndex = LAYER.content + 2
        f.ClipsDescendants = true
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, CARD_RADIUS)
        local stroke = addStroke(f, C.border, 1)

        -- Subtle inner gradient
        addGradient(f, ColorSequence.new({
                ColorSequenceKeypoint.new(0, C.card),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 16, 36)),
        }), 90)

        f.MouseEnter:Connect(function()
                twPlay(stroke, 0.18, {Color = C.accent, Thickness = 1.5})
                twPlay(f, 0.18, {BackgroundColor3 = C.cardHover})
        end)
        f.MouseLeave:Connect(function()
                twPlay(stroke, 0.18, {Color = C.border, Thickness = 1})
                twPlay(f, 0.18, {BackgroundColor3 = C.card})
        end)
        return f
end

local function cardLabel(text, parent, accentColor)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -20, 0, 14)
        l.Position = UDim2.new(0, 12, 0, 8)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = accentColor or C.accent
        l.TextSize = 10
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTransparency = 0.1
        l.ZIndex = LAYER.content + 3
        l.Parent = parent
end

local function makeBtn(text, x, y, w, h, parent, bg, fg)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, w, 0, h)
        b.Position = UDim2.new(0, x, 0, y)
        b.BackgroundColor3 = bg or C.btnBlue
        b.BackgroundTransparency = 0
        b.BorderSizePixel = 0
        b.Text = text
        b.TextColor3 = fg or C.text
        b.TextSize = 13
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.ZIndex = LAYER.interactive
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        local s = addStroke(b, Color3.fromRGB(255, 255, 255), 1)
        s.Transparency = 0.85

        b.MouseEnter:Connect(function()
                twPlay(b, 0.15, {BackgroundTransparency = 0.15, Size = UDim2.new(0, w + 2, 0, h + 2)})
                twPlay(s, 0.15, {Transparency = 0.6, Color = C.accent})
        end)
        b.MouseLeave:Connect(function()
                twPlay(b, 0.15, {BackgroundTransparency = 0, Size = UDim2.new(0, w, 0, h)})
                twPlay(s, 0.15, {Transparency = 0.85, Color = Color3.fromRGB(255, 255, 255)})
        end)
        return b
end

-- ============================================================
-- TOGGLE
-- ============================================================
local function createToggle(labelText, configKey, yPos, parent)
        local f = cardFrame(yPos, 52, parent)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = C.text
        lbl.TextSize = 14
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = LAYER.content + 3
        lbl.Parent = f

        -- Track
        local track = Instance.new("Frame")
        track.Size = UDim2.new(0, 50, 0, 28)
        track.Position = UDim2.new(1, -64, 0.5, -14)
        track.BackgroundColor3 = Config[configKey] and C.toggleOn or C.toggleOff
        track.BackgroundTransparency = 0
        track.BorderSizePixel = 0
        track.ZIndex = LAYER.interactive
        track.ClipsDescendants = true
        track.Parent = f
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
        addStroke(track, C.accent, 1).Transparency = 0.7

        -- Track glow quando ON
        local trackGlow = addInnerGlow(track, C.accentGlow, 0.18, 4)
        trackGlow.BackgroundTransparency = Config[configKey] and 0.82 or 1

        -- Thumb
        local thumb = Instance.new("Frame")
        thumb.Size = UDim2.new(0, 22, 0, 22)
        thumb.Position = Config[configKey] and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11)
        thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        thumb.BorderSizePixel = 0
        thumb.ZIndex = LAYER.interactive + 1
        thumb.Parent = track
        Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
        -- Shadow no thumb
        addStroke(thumb, Color3.fromRGB(0, 0, 0), 1).Transparency = 0.6

        -- Hitbox invisível cobrindo o card inteiro
        local hitbox = Instance.new("TextButton")
        hitbox.Size = UDim2.new(1, 0, 1, 0)
        hitbox.BackgroundTransparency = 1
        hitbox.Text = ""
        hitbox.ZIndex = LAYER.modal
        hitbox.Parent = f

        hitbox.Activated:Connect(function()
                Config[configKey] = not Config[configKey]
                local v = Config[configKey]
                twPlay(track, 0.28, {BackgroundColor3 = v and C.toggleOn or C.toggleOff}, Enum.EasingStyle.Quint)
                twPlay(thumb, 0.28, {
                        Position = v and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11),
                }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                twPlay(trackGlow, 0.28, {BackgroundTransparency = v and 0.82 or 1}, Enum.EasingStyle.Quint)
                saveConfig(Config)
        end)
        return yPos + 52 + CARD_GAP
end

-- ============================================================
-- CPS SPAM
-- ============================================================
local function createCPSSelector(yPos, parent)
        local CARD_H = 76
        local ROW_Y = 30
        local ROW_H = 32
        local f = cardFrame(yPos, CARD_H, parent)
        cardLabel("CPS SPAM", f)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 50, 0, ROW_H)
        lbl.Position = UDim2.new(0, 12, 0, ROW_Y)
        lbl.BackgroundTransparency = 1
        lbl.Text = "CPS:"
        lbl.TextColor3 = C.subtext
        lbl.TextSize = 12
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = LAYER.content + 3
        lbl.Parent = f

        local defBtn = makeBtn("Padrão", 56, ROW_Y, 72, ROW_H, f, C.btnBlue)
        defBtn.TextSize = 11

        local inputBox = Instance.new("TextBox")
        inputBox.Size = UDim2.new(0, 76, 0, ROW_H)
        inputBox.Position = UDim2.new(1, -88, 0, ROW_Y)
        inputBox.BackgroundColor3 = C.inputBg
        inputBox.BackgroundTransparency = 0
        inputBox.BorderSizePixel = 0
        inputBox.Text = tostring(Config.CPS)
        inputBox.PlaceholderText = "1-1000"
        inputBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 110)
        inputBox.TextColor3 = C.text
        inputBox.TextSize = 14
        inputBox.Font = Enum.Font.GothamBold
        inputBox.ClearTextOnFocus = false
        inputBox.ZIndex = LAYER.interactive
        inputBox.Parent = f
        Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)
        local inputStroke = addStroke(inputBox, C.border, 1)

        inputBox.Focused:Connect(function()
                twPlay(inputStroke, 0.18, {Color = C.accent, Thickness = 1.5})
                twPlay(inputBox, 0.18, {BackgroundColor3 = C.bgDeep})
        end)
        inputBox.FocusLost:Connect(function()
                twPlay(inputStroke, 0.18, {Color = C.border, Thickness = 1})
                twPlay(inputBox, 0.18, {BackgroundColor3 = C.inputBg})
        end)

        defBtn.Activated:Connect(function()
                Config.CustomCPS = false
                Config.CPS = 22
                inputBox.Text = "22"
                twPlay(defBtn, 0.18, {BackgroundColor3 = C.green})
                task.delay(0.5, function()
                        twPlay(defBtn, 0.18, {BackgroundColor3 = C.btnBlue})
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

-- ============================================================
-- KEYBIND SELECTOR
-- ============================================================
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
        lbl.ZIndex = LAYER.content + 3
        lbl.Parent = f

        local kbBtn = makeBtn("[" .. Config.Keybind.Name .. "]", 0, 0, 100, 32, f, C.btnBlue)
        kbBtn.Position = UDim2.new(1, -114, 0.5, -16)
        kbBtn.Font = Enum.Font.GothamBold
        kbBtn.TextSize = 13

        local listening = false
        kbBtn.Activated:Connect(function()
                if listening then return end
                listening = true
                kbBtn.Text = "[ ... ]"
                twPlay(kbBtn, 0.12, {BackgroundColor3 = C.accent})
                local conn
                conn = UIS.InputBegan:Connect(function(input, gpe)
                        if gpe then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                                Config.Keybind = input.KeyCode
                                kbBtn.Text = "[" .. input.KeyCode.Name .. "]"
                                twPlay(kbBtn, 0.2, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                                listening = false
                                conn:Disconnect()
                                saveConfig(Config)
                        end
                end)
        end)

        return yPos + 52 + CARD_GAP
end

-- ============================================================
-- SPAM PC CARD
-- ============================================================
local function createSpamPCCard(yPos, parent)
        local CARD_H = 124
        local f = cardFrame(yPos, CARD_H, parent)
        cardLabel("MANUAL SPAM", f, C.accentPink)

        local visBtn = makeBtn("Mini UI: Oculto", 10, 26, COL_W - 20, 30, f, C.btnDark)
        visBtn.TextSize = 11

        visBtn.Activated:Connect(function()
                showMini(not miniVisible, visBtn)
        end)

        local halfW = math.floor((COL_W - 36) / 2)

        local kbBtn = makeBtn(
                Config.SpamKeybind and ("[" .. Config.SpamKeybind.Name .. "]") or "[X]",
                10, 68, halfW, 32, f, C.btnBlue
        )
        kbBtn.TextSize = 13

        local listeningKb = false
        kbBtn.Activated:Connect(function()
                if listeningKb then return end
                listeningKb = true
                kbBtn.Text = "[ ... ]"
                twPlay(kbBtn, 0.12, {BackgroundColor3 = C.accent})
                local conn
                conn = UIS.InputBegan:Connect(function(input, gpe)
                        if gpe then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                                Config.SpamKeybind = input.KeyCode
                                kbBtn.Text = "[" .. input.KeyCode.Name .. "]"
                                twPlay(kbBtn, 0.2, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
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
                10 + halfW + 16, 68, halfW, 32, f,
                getModeColor(Config.SpamMode or "Toggle")
        )
        modeBtn.TextSize = 12

        modeBtn.Activated:Connect(function()
                Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
                modeBtn.Text = Config.SpamMode
                twPlay(modeBtn, 0.2, {BackgroundColor3 = getModeColor(Config.SpamMode)}, Enum.EasingStyle.Back)
                if Config.SpamMode == "Toggle" and _G.PhantomManual then
                        setSpam(false)
                end
                saveConfig(Config)
        end)

        return yPos + CARD_H + CARD_GAP
end

-- ============================================================
-- MONTAR COLUNAS
-- ============================================================
local yL, yR = 4, 4

yL = createToggle("Auto Parry", "AutoParry", yL, colLeft)
yL = createToggle("Aura Visual", "Aura", yL, colLeft)
yL = createToggle("Auto Clash", "AutoClash", yL, colLeft)

yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)
yR = createSpamPCCard(yR, colRight)

-- ============================================================
-- DRAG PANEL / FLOATING
-- ============================================================
makeDraggable(titleBar, configPanel, function()
        Config.PanelX = configPanel.Position.X.Offset
        Config.PanelY = configPanel.Position.Y.Offset
        saveConfig(Config)
end)

local btnIsDragging = makeDraggable(floatingButton, floatShell, function()
        Config.BtnX = floatShell.Position.X.Offset + 4
        Config.BtnY = floatShell.Position.Y.Offset + 4
        saveConfig(Config)
end)

-- ============================================================
-- TOGGLE PANEL
-- ============================================================
local panelOpen = false
local panelTween = nil
local btnTween = nil
local closeConn = nil

local function togglePanel()
        panelOpen = not panelOpen
        if panelTween then pcall(function() panelTween:Cancel() end) end
        if btnTween then pcall(function() btnTween:Cancel() end) end
        if closeConn then pcall(function() closeConn:Disconnect() end) closeConn = nil end

        if panelOpen then
                configPanel.Visible = true
                configPanel.BackgroundTransparency = 1
                configPanel.Size = UDim2.new(0, PW * 0.88, 0, PH * 0.88)
                shadow.Visible = true
                shadow.ImageTransparency = 1

                panelTween = twPlay(configPanel, 0.32,
                        {Size = UDim2.new(0, PW, 0, PH), BackgroundTransparency = 0},
                        Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                twPlay(shadow, 0.32, {ImageTransparency = 0.4}, Enum.EasingStyle.Quint)

                btnTween = twPlay(floatingButton, 0.22,
                        {BackgroundTransparency = 0.6, Size = UDim2.new(0, 44, 0, 44)},
                        Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        else
                panelTween = twPlay(configPanel, 0.24,
                        {Size = UDim2.new(0, PW * 0.9, 0, PH * 0.9), BackgroundTransparency = 1},
                        Enum.EasingStyle.Quint, Enum.EasingDirection.In)
                twPlay(shadow, 0.24, {ImageTransparency = 1}, Enum.EasingStyle.Quint)

                btnTween = twPlay(floatingButton, 0.24,
                        {BackgroundTransparency = 0, Size = UDim2.new(0, 56, 0, 56)},
                        Enum.EasingStyle.Back, Enum.EasingDirection.Out)

                closeConn = panelTween.Completed:Connect(function()
                        if not panelOpen then
                                configPanel.Visible = false
                                configPanel.Size = UDim2.new(0, PW, 0, PH)
                                configPanel.BackgroundTransparency = 0
                                shadow.Visible = false
                        end
                        if closeConn then pcall(function() closeConn:Disconnect() end) closeConn = nil end
                end)
        end
end

floatingButton.Activated:Connect(function()
        if btnIsDragging() then return end
        togglePanel()
end)

closeButton.Activated:Connect(function()
        if panelOpen then togglePanel() end
end)

trackConn(UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Config.Keybind then
                togglePanel()
        end
end))

-- ============================================================
-- KILL
-- ============================================================
killBtn.Activated:Connect(function()
        State.scriptActive = false
        _G.PhantomManual = false
        _G.PhantomAutoClash = false
        saveConfig(Config)

        twPlay(configPanel, 0.28, {BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85)}, Enum.EasingStyle.Quint)
        twPlay(floatingButton, 0.28, {BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})
        twPlay(shadow, 0.28, {ImageTransparency = 1})

        task.wait(0.35)
        for _, c in ipairs(State.connections) do
                pcall(function() c:Disconnect() end)
        end
        pcall(function() State.outer:Destroy() end)
        pcall(function() State.inner:Destroy() end)
        pcall(function() screenGui:Destroy() end)
        print("[PhantomGUI] Script encerrado.")
end)

-- ============================================================
-- SCAN LINE (dentro do panel, atrás de tudo, clipada)
-- ============================================================
local scanLine = Instance.new("Frame")
scanLine.Size = UDim2.new(1, 0, 0, 2)
scanLine.Position = UDim2.new(0, 0, 0, TITLE_H)
scanLine.BackgroundColor3 = C.accent
scanLine.BackgroundTransparency = 0.7
scanLine.BorderSizePixel = 0
scanLine.ZIndex = LAYER.bg
scanLine.Parent = configPanel
addGradient(scanLine, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, C.accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
}))

task.spawn(function()
        while true do
                if not configPanel.Parent or not configPanel.Visible then
                        task.wait(0.3); continue
                end
                scanLine.Position = UDim2.new(0, 0, 0, TITLE_H)
                twPlay(scanLine, 3, {Position = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 0.9}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(3)
        end
end)

-- ============================================================
-- PARTICLES (dentro do panel, clipadas)
-- ============================================================
local particleContainer = Instance.new("Frame")
particleContainer.Size = UDim2.new(1, 0, 1, 0)
particleContainer.BackgroundTransparency = 1
particleContainer.ZIndex = LAYER.bg
particleContainer.ClipsDescendants = true
particleContainer.Parent = configPanel

local function spawnParticle()
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, math.random(2, 4), 0, math.random(2, 4))
        dot.Position = UDim2.new(math.random(), 0, 1, 0)
        local colors = {C.accent, C.accentGlow, C.accentPink, C.accentCyan}
        dot.BackgroundColor3 = colors[math.random(1, #colors)]
        dot.BackgroundTransparency = 0.4
        dot.BorderSizePixel = 0
        dot.ZIndex = LAYER.bg
        dot.Parent = particleContainer
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        local dur = math.random(4, 8)
        twPlay(dot, dur, {
                Position = UDim2.new(dot.Position.X.Scale + (math.random() - 0.5) * 0.15, 0, -0.05, 0),
                BackgroundTransparency = 1,
        }, Enum.EasingStyle.Linear)
        task.delay(dur, function()
                if dot.Parent then dot:Destroy() end
        end)
end

task.spawn(function()
        while true do
                task.wait(math.random() * 0.8 + 0.3)
                if configPanel.Visible then
                        spawnParticle()
                end
        end
end)

print("[PhantomGUI] Efeitos visuais configurados.")
print("[PhantomGUI] GUI v9.0 carregada com sucesso!")
print("[PhantomGUI] Botao P para configurar | tecla: " .. Config.Keybind.Name)
