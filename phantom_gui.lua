-- Phantom Ball GUI v9.0 PREMIUM
-- Paleta: Azul / Roxo / Rosa
-- Carregado automaticamente pelo phantom_logic_v8.lua via loadstring

print("[PhantomGUI] Iniciando carregamento v9.0 Premium...")

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

-- Helpers de tween seguros
local function tw(obj, t, props, style, dir)
        return TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
end

local function twPlay(obj, t, props, style, dir)
        local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
        tween:Play()
        return tween
end

local function trackConn(c)
        State.connections[#State.connections + 1] = c
end

-- ==========================================
-- PALETA NEXUS PREMIUM
-- ==========================================
local C = {
        bg = Color3.fromRGB(8, 8, 22),
        bgDeep = Color3.fromRGB(4, 4, 14),
        header = Color3.fromRGB(14, 14, 34),
        headerTop = Color3.fromRGB(22, 16, 48),
        headerBottom = Color3.fromRGB(8, 8, 28),
        card = Color3.fromRGB(20, 20, 44),
        cardHover = Color3.fromRGB(28, 24, 60),
        cardActive = Color3.fromRGB(34, 28, 72),
        panel = Color3.fromRGB(26, 26, 52),
        inputBg = Color3.fromRGB(12, 12, 32),
        inputBgFocus = Color3.fromRGB(18, 16, 46),
        accent = Color3.fromRGB(99, 102, 241),
        accentGlow = Color3.fromRGB(139, 92, 246),
        accentPink = Color3.fromRGB(236, 72, 153),
        accentPinkSoft = Color3.fromRGB(244, 114, 182),
        accentCyan = Color3.fromRGB(56, 189, 248),
        accentBlue = Color3.fromRGB(59, 130, 246),
        green = Color3.fromRGB(34, 197, 94),
        greenGlow = Color3.fromRGB(74, 222, 128),
        red = Color3.fromRGB(239, 68, 68),
        redDark = Color3.fromRGB(153, 27, 27),
        text = Color3.fromRGB(240, 240, 255),
        subtext = Color3.fromRGB(160, 160, 210),
        subtextDim = Color3.fromRGB(110, 110, 160),
        divider = Color3.fromRGB(45, 45, 85),
        border = Color3.fromRGB(55, 55, 100),
        borderHover = Color3.fromRGB(99, 102, 241),
        btnBlue = Color3.fromRGB(45, 55, 130),
        btnBlueHover = Color3.fromRGB(65, 75, 170),
        btnDark = Color3.fromRGB(30, 30, 65),
        btnDarkHover = Color3.fromRGB(42, 42, 88),
        toggleOn = Color3.fromRGB(139, 92, 246),
        toggleOnGlow = Color3.fromRGB(167, 139, 250),
        toggleOff = Color3.fromRGB(45, 45, 80),
        toggleOffGlow = Color3.fromRGB(70, 70, 110),
        hold = Color3.fromRGB(236, 72, 153),
        holdGlow = Color3.fromRGB(244, 114, 182),
        white = Color3.fromRGB(255, 255, 255),
}

-- Helper para criar gradientes
local function makeGradient(parent, colors, rotation)
        local g = Instance.new("UIGradient", parent)
        g.Color = ColorSequence.new(colors)
        g.Rotation = rotation or 0
        return g
end

local function corner(o, r)
        local c = Instance.new("UICorner", o)
        c.CornerRadius = UDim.new(0, r or 8)
        return c
end

local function stroke(o, color, thickness)
        local s = Instance.new("UIStroke", o)
        s.Color = color or C.border
        s.Thickness = thickness or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        return s
end

print("[PhantomGUI] Cores definidas. Criando ScreenGui...")

-- ==========================================
-- SCREEN GUI
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PhantomUISystem"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = CoreGui

print("[PhantomGUI] ScreenGui criado.")

-- ==========================================
-- DRAG SYSTEM v3 - CORRIGIDO
-- ==========================================
local function makeDraggable(handle, target, onDragEnd)
        local state = "Idle"
        local dragOffX = 0
        local dragOffY = 0
        local startPosX = 0
        local startPosY = 0
        local dragInput = nil
        local wasDragged = false

        local function setState(s) state = s end
        local function isDragging() return state == "Dragging" end

        local inputBeganConn = handle.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserUserInputType and input.UserInputType ~= Enum.UserInputType.Touch then
                end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                end
                if state ~= "Idle" then return end

                setState("Pressed")
                wasDragged = false
                local absPos = target.AbsolutePosition
                dragOffX = input.Position.X - absPos.X
                dragOffY = input.Position.Y - absPos.Y
                startPosX = input.Position.X
                startPosY = input.Position.Y
                dragInput = input
        end)

        local inputChangedConn = UIS.InputChanged:Connect(function(input)
                if state == "Idle" then return end
                if input ~= dragInput then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                        and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                end

                local deltaX = input.Position.X - startPosX
                local deltaY = input.Position.Y - startPosY
                local delta = Vector2.new(deltaX, deltaY)

                if state == "Pressed" then
                        if delta.Magnitude >= 8 then
                                setState("Dragging")
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
                if input ~= dragInput then return end
                if state == "Idle" then return end

                setState("Idle")
                dragInput = nil
                if wasDragged and onDragEnd then
                        onDragEnd()
                end
                wasDragged = false
        end)

        trackConn(inputBeganConn)
        trackConn(inputChangedConn)
        trackConn(inputEndedConn)

        return isDragging
end

print("[PhantomGUI] Drag system v3 criado.")

-- ==========================================
-- MINI GUI SPAM - PREMIUM
-- ==========================================
local MINI_W = 140
local MINI_H = 96

local miniGui = Instance.new("Frame")
miniGui.Name = "PhantomSpamMini"
miniGui.Size = UDim2.new(0, MINI_W, 0, MINI_H)
miniGui.BackgroundColor3 = C.header
miniGui.BackgroundTransparency = 0.05
miniGui.BorderSizePixel = 0
miniGui.ZIndex = 15
miniGui.Parent = screenGui
corner(miniGui, 16)

-- gradiente do header do mini
makeGradient(miniGui, {
        ColorSequenceKeypoint.new(0, C.headerTop),
        ColorSequenceKeypoint.new(0.5, C.header),
        ColorSequenceKeypoint.new(1, C.headerBottom),
}, 90)

-- glow externo
local miniGlow = Instance.new("Frame", miniGui)
miniGlow.Size = UDim2.new(1, 14, 1, 14)
miniGlow.Position = UDim2.new(0, -7, 0, -7)
miniGlow.BackgroundColor3 = C.accent
miniGlow.BackgroundTransparency = 0.94
miniGlow.BorderSizePixel = 0
miniGlow.ZIndex = 14
corner(miniGlow, 22)

local miniStroke = stroke(miniGui, C.accent, 1.5)

-- linha neon no topo
local miniTopLine = Instance.new("Frame", miniGui)
miniTopLine.Size = UDim2.new(1, -20, 0, 1.5)
miniTopLine.Position = UDim2.new(0, 10, 0, 0)
miniTopLine.BackgroundColor3 = C.accentPink
miniTopLine.BorderSizePixel = 0
miniTopLine.ZIndex = 18
corner(miniTopLine, 1)
makeGradient(miniTopLine, {
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(0.5, C.accentPink),
        ColorSequenceKeypoint.new(1, C.accentCyan),
})

-- title bar
local miniTitleBar = Instance.new("Frame")
miniTitleBar.Size = UDim2.new(1, 0, 0, 28)
miniTitleBar.BackgroundTransparency = 1
miniTitleBar.BorderSizePixel = 0
miniTitleBar.ZIndex = 17
miniTitleBar.Parent = miniGui

local miniTitle = Instance.new("TextLabel")
miniTitle.Size = UDim2.new(1, -16, 1, 0)
miniTitle.Position = UDim2.new(0, 12, 0, 0)
miniTitle.BackgroundTransparency = 1
miniTitle.Text = "◆ SPAM"
miniTitle.TextColor3 = C.subtext
miniTitle.TextSize = 11
miniTitle.Font = Enum.Font.GothamBold
miniTitle.TextXAlignment = Enum.TextXAlignment.Left
miniTitle.ZIndex = 18
miniTitle.Parent = miniTitleBar

-- status dot pulsante
local miniStatus = Instance.new("Frame", miniTitleBar)
miniStatus.Size = UDim2.new(0, 6, 0, 6)
miniStatus.Position = UDim2.new(1, -16, 0.5, -3)
miniStatus.BackgroundColor3 = C.red
miniStatus.BorderSizePixel = 0
miniStatus.ZIndex = 19
corner(miniStatus, 1)
local miniStatusGlow = Instance.new("Frame", miniStatus)
miniStatusGlow.Size = UDim2.new(1, 6, 1, 6)
miniStatusGlow.Position = UDim2.new(0, -3, 0, -3)
miniStatusGlow.BackgroundColor3 = C.red
miniStatusGlow.BackgroundTransparency = 0.6
miniStatusGlow.BorderSizePixel = 0
miniStatusGlow.ZIndex = 18
corner(miniStatusGlow, 1)

-- botão de spam premium
local spamBtn = Instance.new("TextButton")
spamBtn.Size = UDim2.new(1, -16, 0, 50)
spamBtn.Position = UDim2.new(0, 8, 0, 36)
spamBtn.BackgroundColor3 = C.red
spamBtn.BorderSizePixel = 0
spamBtn.Text = "OFF"
spamBtn.TextColor3 = C.white
spamBtn.TextSize = 20
spamBtn.Font = Enum.Font.GothamBlack
spamBtn.ZIndex = 18
spamBtn.Parent = miniGui
corner(spamBtn, 12)

makeGradient(spamBtn, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 40, 70)),
}, 90)

local spamBtnStroke = stroke(spamBtn, Color3.fromRGB(255, 100, 120), 1)
spamBtnStroke.Transparency = 0.4

local spamBtnGlow = Instance.new("Frame", spamBtn)
spamBtnGlow.Size = UDim2.new(1, 10, 1, 10)
spamBtnGlow.Position = UDim2.new(0, -5, 0, -5)
spamBtnGlow.BackgroundColor3 = C.red
spamBtnGlow.BackgroundTransparency = 0.85
spamBtnGlow.BorderSizePixel = 0
spamBtnGlow.ZIndex = 16
corner(spamBtnGlow, 16)

-- shimmer
local shimmer = Instance.new("Frame", spamBtn)
shimmer.Size = UDim2.new(0.4, 0, 1, 0)
shimmer.Position = UDim2.new(-0.4, 0, 0, 0)
shimmer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
shimmer.BackgroundTransparency = 0.92
shimmer.BorderSizePixel = 0
shimmer.ZIndex = 19

local spamOn = false
local function setSpam(v)
        spamOn = v
        _G.PhantomManual = v

        -- animação do botão
        if v then
                spamBtn.Text = "ON"
                twPlay(spamBtn, 0.25, {Size = UDim2.new(1, -16, 0, 50)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        else
                spamBtn.Text = "OFF"
                twPlay(spamBtn, 0.2, {Size = UDim2.new(1, -16, 0, 50)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end

        task.spawn(function()
                -- squash
                twPlay(spamBtn, 0.08, {Size = UDim2.new(1, -20, 0, 46)})
                task.wait(0.08)
                twPlay(spamBtn, 0.18, {Size = UDim2.new(1, -16, 0, 52)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                task.wait(0.18)
                twPlay(spamBtn, 0.12, {Size = UDim2.new(1, -16, 0, 50)})
        end)

        -- troca de gradiente
        if v then
                twPlay(spamBtn, 0.2, {})
                local newGrad = makeGradient(spamBtn, {
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 90, 255)),
                        ColorSequenceKeypoint.new(0.5, C.accentGlow),
                        ColorSequenceKeypoint.new(1, C.accentPink),
                }, 90)
                spamBtnStroke.Color = C.accentPink
                spamBtnGlow.BackgroundColor3 = C.accentPink
                miniStatus.BackgroundColor3 = C.green
                miniStatusGlow.BackgroundColor3 = C.green
        else
                local newGrad = makeGradient(spamBtn, {
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 110)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 40, 70)),
                }, 90)
                spamBtnStroke.Color = Color3.fromRGB(255, 100, 120)
                spamBtnGlow.BackgroundColor3 = C.red
                miniStatus.BackgroundColor3 = C.red
                miniStatusGlow.BackgroundColor3 = C.red
        end
end

spamBtn.Activated:Connect(function()
        setSpam(not spamOn)
end)

-- hover do botão spam
if not UIS.TouchEnabled then
        spamBtn.MouseEnter:Connect(function()
                twPlay(spamBtn, 0.18, {Size = UDim2.new(1, -12, 0, 52)})
                twPlay(spamBtnGlow, 0.18, {BackgroundTransparency = 0.7})
        end)
        spamBtn.MouseLeave:Connect(function()
                twPlay(spamBtn, 0.18, {Size = UDim2.new(1, -16, 0, 50)})
                twPlay(spamBtnGlow, 0.18, {BackgroundTransparency = 0.85})
        end)
end

-- posição
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
                twPlay(miniGui, 0.3, {Position = UDim2.new(0, miniVisibleX, 0, miniVisibleY)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        else
                twPlay(miniGui, 0.22, {Position = UDim2.new(0, getMiniHiddenX(), 0, miniVisibleY)}, Enum.EasingStyle.Quint)
        end
        if visBtn then
                visBtn.Text = v and "▼ Mini UI: Visivel" or "▶ Mini UI: Oculto"
                twPlay(visBtn, 0.15, {BackgroundColor3 = v and Color3.fromRGB(0, 130, 65) or C.btnDark})
        end
end

makeDraggable(miniTitleBar, miniGui, function()
        miniVisibleX = miniGui.Position.X.Offset
        miniVisibleY = miniGui.Position.Y.Offset
        Config.MiniX = miniVisibleX
        Config.MiniY = miniVisibleY
        saveConfig(Config)
end)

-- Keybind spam
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

-- pulse do status dot
task.spawn(function()
        while screenGui and screenGui.Parent do
                twPlay(miniStatusGlow, 0.7, {BackgroundTransparency = 0.3}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(0.7)
                twPlay(miniStatusGlow, 0.7, {BackgroundTransparency = 0.6}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(0.7)
        end
end)

print("[PhantomGUI] Mini GUI premium criado.")

-- ==========================================
-- BOTAO FLUTUANTE PREMIUM
-- ==========================================
local floatingButton = Instance.new("TextButton")
floatingButton.Size = UDim2.new(0, 60, 0, 60)
floatingButton.Position = Config.BtnX and UDim2.new(0, Config.BtnX, 0, Config.BtnY) or UDim2.new(1, -76, 0.5, -30)
floatingButton.BackgroundColor3 = C.header
floatingButton.BorderSizePixel = 0
floatingButton.Text = "P"
floatingButton.TextColor3 = C.white
floatingButton.TextSize = 28
floatingButton.Font = Enum.Font.GothamBlack
floatingButton.Active = true
floatingButton.ZIndex = 10
floatingButton.Parent = screenGui
corner(floatingButton, 30)

makeGradient(floatingButton, {
        ColorSequenceKeypoint.new(0, C.accentGlow),
        ColorSequenceKeypoint.new(0.5, C.accent),
        ColorSequenceKeypoint.new(1, C.accentPink),
}, 135)

-- glow
local floatGlow = Instance.new("Frame", floatingButton)
floatGlow.Size = UDim2.new(1, 16, 1, 16)
floatGlow.Position = UDim2.new(0, -8, 0, -8)
floatGlow.BackgroundColor3 = C.accent
floatGlow.BackgroundTransparency = 0.88
floatGlow.BorderSizePixel = 0
floatGlow.ZIndex = 9
corner(floatGlow, 1)

local floatingStroke = stroke(floatingButton, C.accent, 2)
floatingStroke.Transparency = 0.3

-- sombra interna
local floatInner = Instance.new("Frame", floatingButton)
floatInner.Size = UDim2.new(1, -6, 1, -6)
floatInner.Position = UDim2.new(0, 3, 0, 3)
floatInner.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
floatInner.BackgroundTransparency = 0.6
floatInner.BorderSizePixel = 0
floatInner.ZIndex = 10
corner(floatInner, 30)

-- pulse do glow
task.spawn(function()
        while screenGui and screenGui.Parent do
                twPlay(floatGlow, 0.9, {BackgroundTransparency = 0.7, Size = UDim2.new(1, 22, 1, 22)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(0.9)
                twPlay(floatGlow, 0.9, {BackgroundTransparency = 0.92, Size = UDim2.new(1, 16, 1, 16)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(0.9)
        end
end)

-- hover do botão flutuante
if not UIS.TouchEnabled then
        floatingButton.MouseEnter:Connect(function()
                twPlay(floatingButton, 0.2, {Size = UDim2.new(0, 66, 0, 66)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                twPlay(floatGlow, 0.2, {BackgroundTransparency = 0.6})
        end)
        floatingButton.MouseLeave:Connect(function()
                twPlay(floatingButton, 0.2, {Size = UDim2.new(0, 60, 0, 60)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                twPlay(floatGlow, 0.2, {BackgroundTransparency = 0.88})
        end)
end

print("[PhantomGUI] Botao flutuante premium criado.")

-- ==========================================
-- PAINEL PRINCIPAL
-- ==========================================
local PW, PH = 560, 380

local configPanel = Instance.new("Frame")
configPanel.Name = "PhantomPanel"
configPanel.Size = UDim2.new(0, PW, 0, PH)
configPanel.Position = Config.PanelX and UDim2.new(0, Config.PanelX, 0, Config.PanelY) or UDim2.new(0.5, -PW / 2, 0.5, -PH / 2)
configPanel.BackgroundColor3 = C.bg
configPanel.BorderSizePixel = 0
configPanel.Visible = false
configPanel.ZIndex = 5
configPanel.ClipsDescendants = true
configPanel.Parent = screenGui
corner(configPanel, 18)

-- gradiente do fundo
makeGradient(configPanel, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 10, 32)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 8, 22)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 8, 30)),
}, 90)

-- stroke principal
local panelStroke = stroke(configPanel, C.accent, 1.5)
panelStroke.Transparency = 0.4

-- glow externo
local panelGlow = Instance.new("Frame", screenGui)
panelGlow.Name = "PanelGlow"
panelGlow.Size = UDim2.new(0, PW + 24, 0, PH + 24)
panelGlow.Position = configPanel.Position + UDim2.new(0, -12, 0, -12)
panelGlow.BackgroundColor3 = C.accent
panelGlow.BackgroundTransparency = 0.95
panelGlow.BorderSizePixel = 0
panelGlow.ZIndex = 4
panelGlow.Visible = false
corner(panelGlow, 26)

-- sombra
local shadowFrame = Instance.new("Frame")
shadowFrame.Name = "Shadow"
shadowFrame.Size = UDim2.new(1, 18, 1, 18)
shadowFrame.Position = UDim2.new(0, -9, 0, -9)
shadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadowFrame.BackgroundTransparency = 0.55
shadowFrame.BorderSizePixel = 0
shadowFrame.ZIndex = 3
shadowFrame.Visible = false
shadowFrame.Parent = screenGui
corner(shadowFrame, 24)

print("[PhantomGUI] Painel principal criado.")

-- ==========================================
-- RGB LOOP
-- ==========================================
task.spawn(function()
        local t = 0
        while screenGui and screenGui.Parent do
                t = (t + 0.004) % 1
                local hue = 0.70 + (math.sin(t * math.pi * 2) * 0.12)
                local col = Color3.fromHSV(hue, 0.7, 1)
                panelStroke.Color = col
                floatingStroke.Color = col
                miniStroke.Color = col
                if panelGlow and panelGlow.Parent then
                        panelGlow.BackgroundColor3 = col
                end
                task.wait(0.05)
        end
end)

-- ==========================================
-- TITLE BAR
-- ==========================================
local TITLE_H = 56

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = C.header
titleBar.BackgroundTransparency = 0
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 6
titleBar.Parent = configPanel
corner(titleBar, 18)

-- gradiente do header
makeGradient(titleBar, {
        ColorSequenceKeypoint.new(0, C.headerTop),
        ColorSequenceKeypoint.new(0.5, C.header),
        ColorSequenceKeypoint.new(1, C.headerBottom),
}, 90)

-- fill do bottom do header (pra não ficar transparente)
local titleBarFill = Instance.new("Frame")
titleBarFill.Size = UDim2.new(1, 0, 0, 18)
titleBarFill.Position = UDim2.new(0, 0, 1, -18)
titleBarFill.BackgroundColor3 = C.header
titleBarFill.BackgroundTransparency = 0
titleBarFill.BorderSizePixel = 0
titleBarFill.ZIndex = 6
titleBarFill.Parent = titleBar
makeGradient(titleBarFill, {
        ColorSequenceKeypoint.new(0, C.headerBottom),
        ColorSequenceKeypoint.new(1, C.bg),
}, 90)

-- logo box
local logoBox = Instance.new("Frame", titleBar)
logoBox.Size = UDim2.new(0, 32, 0, 32)
logoBox.Position = UDim2.new(0, 14, 0.5, -16)
logoBox.BackgroundColor3 = C.accent
logoBox.BorderSizePixel = 0
logoBox.ZIndex = 7
corner(logoBox, 10)
makeGradient(logoBox, {
        ColorSequenceKeypoint.new(0, C.accentGlow),
        ColorSequenceKeypoint.new(0.5, C.accent),
        ColorSequenceKeypoint.new(1, C.accentPink),
}, 135)

local logoText = Instance.new("TextLabel", logoBox)
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.BackgroundTransparency = 1
logoText.Text = "P"
logoText.TextColor3 = C.white
logoText.TextSize = 18
logoText.Font = Enum.Font.GothamBlack
logoText.ZIndex = 8

-- glow do logo
local logoGlow = Instance.new("Frame", logoBox)
logoGlow.Size = UDim2.new(1, 8, 1, 8)
logoGlow.Position = UDim2.new(0, -4, 0, -4)
logoGlow.BackgroundColor3 = C.accent
logoGlow.BackgroundTransparency = 0.85
logoGlow.BorderSizePixel = 0
logoGlow.ZIndex = 6
corner(logoGlow, 14)

-- pulse do logo
task.spawn(function()
        while screenGui and screenGui.Parent do
                twPlay(logoGlow, 1.2, {BackgroundTransparency = 0.7}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(1.2)
                twPlay(logoGlow, 1.2, {BackgroundTransparency = 0.9}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                task.wait(1.2)
        end
end)

-- textos do título
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -160, 0, 22)
titleLabel.Position = UDim2.new(0, 56, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Phantom Ball"
titleLabel.TextColor3 = C.text
titleLabel.TextSize = 17
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 7
titleLabel.Parent = titleBar

-- badge "v9.0"
local versionBadge = Instance.new("Frame", titleBar)
versionBadge.Size = UDim2.new(0, 46, 0, 16)
versionBadge.Position = UDim2.new(0, 152, 0, 11)
versionBadge.BackgroundColor3 = C.accentPink
versionBadge.BackgroundTransparency = 0.7
versionBadge.BorderSizePixel = 0
versionBadge.ZIndex = 7
corner(versionBadge, 4)
local versionText = Instance.new("TextLabel", versionBadge)
versionText.Size = UDim2.new(1, 0, 1, 0)
versionText.BackgroundTransparency = 1
versionText.Text = "v9.0"
versionText.TextColor3 = C.white
versionText.TextSize = 9
versionText.Font = Enum.Font.GothamBlack
versionText.ZIndex = 8

local subLabel = Instance.new("TextLabel", titleBar)
subLabel.Size = UDim2.new(0, 200, 0, 14)
subLabel.Position = UDim2.new(0, 56, 0, 30)
subLabel.BackgroundTransparency = 1
subLabel.Text = "◆ Premium Edition"
subLabel.TextColor3 = C.subtext
subLabel.TextSize = 10
subLabel.Font = Enum.Font.GothamSemibold
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.ZIndex = 7

-- linha decorativa
local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, -28, 0, 1)
headerLine.Position = UDim2.new(0, 14, 1, -1)
headerLine.BackgroundColor3 = C.accent
headerLine.BorderSizePixel = 0
headerLine.ZIndex = 7
headerLine.Parent = titleBar
makeGradient(headerLine, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.3, C.accent),
        ColorSequenceKeypoint.new(0.5, C.accentPink),
        ColorSequenceKeypoint.new(0.7, C.accentCyan),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})

-- close button premium
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.Position = UDim2.new(1, -44, 0.5, -16)
closeButton.BackgroundColor3 = C.red
closeButton.BackgroundTransparency = 0.4
closeButton.BorderSizePixel = 0
closeButton.Text = "✕"
closeButton.TextColor3 = C.white
closeButton.TextSize = 16
closeButton.Font = Enum.Font.GothamBold
closeButton.ZIndex = 7
closeButton.Parent = titleBar
corner(closeButton, 10)
local closeStroke = stroke(closeButton, C.red, 1)
closeStroke.Transparency = 0.5

closeButton.MouseEnter:Connect(function()
        twPlay(closeButton, 0.12, {BackgroundTransparency = 0, Size = UDim2.new(0, 36, 0, 36)}, Enum.EasingStyle.Back)
        twPlay(closeStroke, 0.12, {Transparency = 0})
        twPlay(closeButton, 0.12, {Position = UDim2.new(1, -46, 0.5, -18)})
end)
closeButton.MouseLeave:Connect(function()
        twPlay(closeButton, 0.15, {BackgroundTransparency = 0.4, Size = UDim2.new(0, 32, 0, 32)}, Enum.EasingStyle.Back)
        twPlay(closeStroke, 0.12, {Transparency = 0.5})
        twPlay(closeButton, 0.12, {Position = UDim2.new(1, -44, 0.5, -16)})
end)

print("[PhantomGUI] Title bar premium criado.")

-- ==========================================
-- LAYOUT
-- ==========================================
local CONTENT_Y = TITLE_H + 14
local FOOTER_H = 50
local PAD = 16
local GAP = 14
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

local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 1, 0, PH - CONTENT_Y - FOOTER_H - 16)
divider.Position = UDim2.new(0, PAD + COL_W + math.floor(GAP / 2), 0, CONTENT_Y + 6)
divider.BackgroundColor3 = C.divider
divider.BorderSizePixel = 0
divider.ZIndex = 6
divider.Parent = configPanel
makeGradient(divider, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.3, C.accent),
        ColorSequenceKeypoint.new(0.7, C.accentPink),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
}, 90)

print("[PhantomGUI] Layout criado.")

-- ==========================================
-- FOOTER
-- ==========================================
-- linha do footer
local footerLine = Instance.new("Frame")
footerLine.Size = UDim2.new(1, -28, 0, 1)
footerLine.Position = UDim2.new(0, 14, 1, -FOOTER_H)
footerLine.BackgroundColor3 = C.divider
footerLine.BorderSizePixel = 0
footerLine.ZIndex = 6
footerLine.Parent = configPanel
makeGradient(footerLine, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, C.accent),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0, 150, 0, 32)
killBtn.Position = UDim2.new(0.5, -75, 1, -41)
killBtn.BackgroundColor3 = C.redDark
killBtn.BorderSizePixel = 0
killBtn.Text = "✕  FECHAR SCRIPT"
killBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
killBtn.TextSize = 11
killBtn.Font = Enum.Font.GothamBold
killBtn.ZIndex = 7
killBtn.Parent = configPanel
corner(killBtn, 10)
local killStroke = stroke(killBtn, C.red, 1)
killStroke.Transparency = 0.4

if not UIS.TouchEnabled then
        killBtn.MouseEnter:Connect(function()
                twPlay(killBtn, 0.15, {BackgroundColor3 = Color3.fromRGB(200, 40, 40), Size = UDim2.new(0, 154, 0, 34)})
                killBtn.Position = UDim2.new(0.5, -77, 1, -42)
                twPlay(killStroke, 0.15, {Transparency = 0, Color = Color3.fromRGB(255, 100, 100)})
        end)
        killBtn.MouseLeave:Connect(function()
                twPlay(killBtn, 0.15, {BackgroundColor3 = C.redDark, Size = UDim2.new(0, 150, 0, 32)})
                killBtn.Position = UDim2.new(0.5, -75, 1, -41)
                twPlay(killStroke, 0.15, {Transparency = 0.4, Color = C.red})
        end)
end

-- ==========================================
-- HELPERS DE COMPONENTES
-- ==========================================
local CARD_GAP = 10

local function cardFrame(yPos, h, parent)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 0, h)
        f.Position = UDim2.new(0, 0, 0, yPos)
        f.BackgroundColor3 = C.card
        f.BackgroundTransparency = 0.05
        f.BorderSizePixel = 0
        f.ZIndex = 6
        f.Parent = parent
        corner(f, 14)

        local s = stroke(f, C.border, 1)
        s.Transparency = 0.3

        -- barra lateral colorida
        local sideBar = Instance.new("Frame", f)
        sideBar.Size = UDim2.new(0, 3, 1, -16)
        sideBar.Position = UDim2.new(0, 8, 0, 8)
        sideBar.BackgroundColor3 = C.accent
        sideBar.BorderSizePixel = 0
        sideBar.ZIndex = 7
        corner(sideBar, 2)
        makeGradient(sideBar, {
                ColorSequenceKeypoint.new(0, C.accent),
                ColorSequenceKeypoint.new(0.5, C.accentPink),
                ColorSequenceKeypoint.new(1, C.accentCyan),
}, 90)

        f.MouseEnter:Connect(function()
                twPlay(s, 0.18, {Color = C.accent, Transparency = 0})
                twPlay(f, 0.18, {BackgroundColor3 = C.cardHover, BackgroundTransparency = 0})
        end)
        f.MouseLeave:Connect(function()
                twPlay(s, 0.18, {Color = C.border, Transparency = 0.3})
                twPlay(f, 0.18, {BackgroundColor3 = C.card, BackgroundTransparency = 0.05})
        end)

        return f
end

local function cardLabel(text, parent, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -28, 0, 16)
        l.Position = UDim2.new(0, 18, 0, 6)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or C.accent
        l.TextSize = 10
        l.Font = Enum.Font.GothamBlack
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTransparency = 0.1
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
        b.TextSize = 12
        b.Font = Enum.Font.GothamBold
        b.ZIndex = 7
        b.AutoButtonColor = false
        b.Parent = parent
        corner(b, 10)
        local s = stroke(b, C.border, 1)
        s.Transparency = 0.5

        if not UIS.TouchEnabled then
                b.MouseEnter:Connect(function()
                        twPlay(b, 0.15, {BackgroundColor3 = C.btnBlueHover})
                        twPlay(s, 0.15, {Color = C.accent, Transparency = 0})
                end)
                b.MouseLeave:Connect(function()
                        twPlay(b, 0.15, {BackgroundColor3 = bg or C.btnBlue})
                        twPlay(s, 0.15, {Color = C.border, Transparency = 0.5})
                end)
        end

        -- efeito de clique
        b.Activated:Connect(function()
                task.spawn(function()
                        twPlay(b, 0.06, {Size = UDim2.new(0, w - 2, 0, h - 2)})
                        twPlay(b, 0.06, {Position = UDim2.new(0, x + 1, 0, y + 1)})
                        task.wait(0.06)
                        twPlay(b, 0.12, {Size = UDim2.new(0, w, 0, h)}, Enum.EasingStyle.Back)
                        twPlay(b, 0.12, {Position = UDim2.new(0, x, 0, y)})
                end)
        end)

        return b
end

print("[PhantomGUI] Helpers criados.")

-- ==========================================
-- TOGGLE PADRÃO (bolinha)
-- ==========================================
local function createToggle(labelText, configKey, yPos, parent, onChange)
        local f = cardFrame(yPos, 54, parent)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, 0, 1, 0)
        lbl.Position = UDim2.new(0, 18, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = C.text
        lbl.TextSize = 14
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 7
        lbl.Parent = f

        local track = Instance.new("Frame", f)
        track.Size = UDim2.new(0, 52, 0, 28)
        track.Position = UDim2.new(1, -68, 0.5, -14)
        track.BackgroundColor3 = Config[configKey] and C.toggleOn or C.toggleOff
        track.BorderSizePixel = 0
        track.ZIndex = 7
        corner(track, 14)

        local trackGrad = makeGradient(track, Config[configKey] and {
                ColorSequenceKeypoint.new(0, C.accentGlow),
                ColorSequenceKeypoint.new(1, C.accentPink),
        } or {
                ColorSequenceKeypoint.new(0, C.toggleOff),
                ColorSequenceKeypoint.new(1, C.toggleOffGlow),
        }, 90)

        -- glow do track quando on
        local trackGlow = Instance.new("Frame", track)
        trackGlow.Size = UDim2.new(1, 8, 1, 8)
        trackGlow.Position = UDim2.new(0, -4, 0, -4)
        trackGlow.BackgroundColor3 = Config[configKey] and C.accentPink or C.toggleOff
        trackGlow.BackgroundTransparency = Config[configKey] and 0.7 or 0.95
        trackGlow.BorderSizePixel = 0
        trackGlow.ZIndex = 6
        corner(trackGlow, 18)

        local thumb = Instance.new("Frame", track)
        thumb.Size = UDim2.new(0, 22, 0, 22)
        thumb.Position = Config[configKey] and UDim2.new(0, 27, 0.5, -11) or UDim2.new(0, 3, 0.5, -11)
        thumb.BackgroundColor3 = C.white
        thumb.BorderSizePixel = 0
        thumb.ZIndex = 8
        corner(thumb, 11)
        -- sombra no thumb
        local thumbShadow = Instance.new("Frame", thumb)
        thumbShadow.Size = UDim2.new(1, 0, 1, 0)
        thumbShadow.Position = UDim2.new(0, 0, 0, 2)
        thumbShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        thumbShadow.BackgroundTransparency = 0.6
        thumbShadow.BorderSizePixel = 0
        thumbShadow.ZIndex = 7
        corner(thumbShadow, 11)

        local hitbox = Instance.new("TextButton", f)
        hitbox.Size = UDim2.new(1, 0, 1, 0)
        hitbox.BackgroundTransparency = 1
        hitbox.Text = ""
        hitbox.ZIndex = 9

        hitbox.Activated:Connect(function()
                Config[configKey] = not Config[configKey]
                local v = Config[configKey]

                twPlay(track, 0.28, {BackgroundColor3 = v and C.toggleOn or C.toggleOff}, Enum.EasingStyle.Quint)
                twPlay(thumb, 0.28, {Position = v and UDim2.new(0, 27, 0.5, -11) or UDim2.new(0, 3, 0.5, -11)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

                -- troca gradiente do track
                task.spawn(function()
                        task.wait(0.05)
                        if v then
                                makeGradient(track, {
                                        ColorSequenceKeypoint.new(0, C.accentGlow),
                                        ColorSequenceKeypoint.new(1, C.accentPink),
                                }, 90)
                                twPlay(trackGlow, 0.25, {BackgroundColor3 = C.accentPink, BackgroundTransparency = 0.7})
                        else
                                makeGradient(track, {
                                        ColorSequenceKeypoint.new(0, C.toggleOff),
                                        ColorSequenceKeypoint.new(1, C.toggleOffGlow),
                                }, 90)
                                twPlay(trackGlow, 0.25, {BackgroundColor3 = C.toggleOff, BackgroundTransparency = 0.95})
                        end
                end)

                if onChange then onChange(v) end
                saveConfig(Config)
        end)

        return yPos + 54 + CARD_GAP
end

-- ==========================================
-- TOGGLE PREMIUM COM TEXTO OFF/ON DENTRO
-- ==========================================
local function createLabeledToggle(labelText, configKey, yPos, parent, onChange)
        local f = cardFrame(yPos, 54, parent)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.Position = UDim2.new(0, 18, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = C.text
        lbl.TextSize = 14
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 7
        lbl.Parent = f

        -- toggle tamanho padrão (texto OFF/ON grande DENTRO)
        local track = Instance.new("Frame", f)
        track.Size = UDim2.new(0, 62, 0, 30)
        track.Position = UDim2.new(1, -78, 0.5, -15)
        track.BackgroundColor3 = Config[configKey] and C.toggleOn or C.toggleOff
        track.BorderSizePixel = 0
        track.ZIndex = 7
        corner(track, 15)

        local trackGrad = makeGradient(track, Config[configKey] and {
                ColorSequenceKeypoint.new(0, C.accentGlow),
                ColorSequenceKeypoint.new(0.5, C.accent),
                ColorSequenceKeypoint.new(1, C.accentPink),
        } or {
                ColorSequenceKeypoint.new(0, C.toggleOff),
                ColorSequenceKeypoint.new(1, C.toggleOffGlow),
        }, 90)

        -- glow
        local trackGlow = Instance.new("Frame", track)
        trackGlow.Size = UDim2.new(1, 8, 1, 8)
        trackGlow.Position = UDim2.new(0, -4, 0, -4)
        trackGlow.BackgroundColor3 = Config[configKey] and C.accentPink or C.toggleOff
        trackGlow.BackgroundTransparency = Config[configKey] and 0.65 or 0.95
        trackGlow.BorderSizePixel = 0
        trackGlow.ZIndex = 6
        corner(trackGlow, 19)

        -- texto OFF/ON GRANDE dentro do track
        local stateText = Instance.new("TextLabel", track)
        stateText.Size = UDim2.new(1, 0, 1, 0)
        stateText.BackgroundTransparency = 1
        stateText.Text = Config[configKey] and "ON" or "OFF"
        stateText.TextColor3 = C.white
        stateText.TextSize = 13
        stateText.Font = Enum.Font.GothamBlack
        stateText.ZIndex = 9
        stateText.TextTransparency = 0
        -- alinhamento muda dependendo do estado pra dar espaço pro thumb
        stateText.TextXAlignment = Config[configKey] and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
        local textPad = Instance.new("UIPadding", stateText)
        textPad.PaddingLeft = UDim.new(0, 6)
        textPad.PaddingRight = UDim.new(0, 6)

        -- thumb (cobre o texto do lado oposto visualmente)
        local thumb = Instance.new("Frame", track)
        thumb.Size = UDim2.new(0, 24, 0, 24)
        thumb.Position = Config[configKey] and UDim2.new(0, 35, 0.5, -12) or UDim2.new(0, 3, 0.5, -12)
        thumb.BackgroundColor3 = C.white
        thumb.BorderSizePixel = 0
        thumb.ZIndex = 10
        corner(thumb, 12)
        local thumbShadow = Instance.new("Frame", thumb)
        thumbShadow.Size = UDim2.new(1, 0, 1, 0)
        thumbShadow.Position = UDim2.new(0, 0, 0, 2)
        thumbShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        thumbShadow.BackgroundTransparency = 0.55
        thumbShadow.BorderSizePixel = 0
        thumbShadow.ZIndex = 9
        corner(thumbShadow, 12)

        local hitbox = Instance.new("TextButton", f)
        hitbox.Size = UDim2.new(1, 0, 1, 0)
        hitbox.BackgroundTransparency = 1
        hitbox.Text = ""
        hitbox.ZIndex = 11

        hitbox.Activated:Connect(function()
                Config[configKey] = not Config[configKey]
                local v = Config[configKey]

                -- animação do thumb
                twPlay(thumb, 0.32, {Position = v and UDim2.new(0, 35, 0.5, -12) or UDim2.new(0, 3, 0.5, -12)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                twPlay(track, 0.28, {BackgroundColor3 = v and C.toggleOn or C.toggleOff}, Enum.EasingStyle.Quint)

                -- squash no thumb
                task.spawn(function()
                        twPlay(thumb, 0.06, {Size = UDim2.new(0, 22, 0, 22)})
                        task.wait(0.06)
                        twPlay(thumb, 0.16, {Size = UDim2.new(0, 26, 0, 26)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                        task.wait(0.16)
                        twPlay(thumb, 0.1, {Size = UDim2.new(0, 24, 0, 24)})
                end)

                -- troca texto + alinhamento + cor
                task.spawn(function()
                        task.wait(0.08)
                        stateText.Text = v and "ON" or "OFF"
                        stateText.TextXAlignment = v and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
                        stateText.TextColor3 = C.white
                        -- flash de cor
                        stateText.TextColor3 = v and Color3.fromRGB(180, 255, 200) or Color3.fromRGB(255, 180, 180)
                        twPlay(stateText, 0.3, {TextColor3 = C.white, TextTransparency = 0.1}, Enum.EasingStyle.Quad)
                        -- dot
                        twPlay(thumbDot, 0.25, {BackgroundColor3 = v and C.accentPink or C.subtextDim})
                end)

                -- troca gradiente
                task.spawn(function()
                        task.wait(0.05)
                        if v then
                                makeGradient(track, {
                                        ColorSequenceKeypoint.new(0, C.accentGlow),
                                        ColorSequenceKeypoint.new(0.5, C.accent),
                                        ColorSequenceKeypoint.new(1, C.accentPink),
                                }, 90)
                                twPlay(trackGlow, 0.25, {BackgroundColor3 = C.accentPink, BackgroundTransparency = 0.65})
                        else
                                makeGradient(track, {
                                        ColorSequenceKeypoint.new(0, C.toggleOff),
                                        ColorSequenceKeypoint.new(1, C.toggleOffGlow),
                                }, 90)
                                twPlay(trackGlow, 0.25, {BackgroundColor3 = C.toggleOff, BackgroundTransparency = 0.95})
                        end
                end)

                if onChange then onChange(v) end
                saveConfig(Config)
        end)

        return yPos + 54 + CARD_GAP
end

-- ==========================================
-- CPS SPAM
-- ==========================================
local function createCPSSelector(yPos, parent)
        local CARD_H = 72
        local ROW_Y = 30
        local ROW_H = 32
        local f = cardFrame(yPos, CARD_H, parent)
        cardLabel("CPS SPAM", f)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 40, 0, ROW_H)
        lbl.Position = UDim2.new(0, 18, 0, ROW_Y)
        lbl.BackgroundTransparency = 1
        lbl.Text = "CPS:"
        lbl.TextColor3 = C.text
        lbl.TextSize = 13
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 7
        lbl.Parent = f

        local defBtn = makeBtn("PADRÃO", 60, ROW_Y, 76, ROW_H, f, C.btnBlue)
        defBtn.TextSize = 10

        local inputBox = Instance.new("TextBox")
        inputBox.Size = UDim2.new(0, 78, 0, ROW_H)
        inputBox.Position = UDim2.new(1, -90, 0, ROW_Y)
        inputBox.BackgroundColor3 = C.inputBg
        inputBox.BorderSizePixel = 0
        inputBox.Text = tostring(Config.CPS)
        inputBox.PlaceholderText = "CPS"
        inputBox.PlaceholderColor3 = C.subtextDim
        inputBox.TextColor3 = C.text
        inputBox.TextSize = 14
        inputBox.Font = Enum.Font.GothamBlack
        inputBox.ZIndex = 7
        inputBox.Parent = f
        corner(inputBox, 10)
        local inputStroke = stroke(inputBox, C.border, 1)
        inputStroke.Transparency = 0.4

        -- gradiente sutil no input
        makeGradient(inputBox, {
                ColorSequenceKeypoint.new(0, C.inputBg),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 16, 48)),
        }, 90)

        inputBox.Focused:Connect(function()
                twPlay(inputStroke, 0.15, {Color = C.accentPink, Transparency = 0})
                twPlay(inputBox, 0.15, {BackgroundColor3 = C.inputBgFocus})
        end)
        inputBox.FocusLost:Connect(function()
                twPlay(inputStroke, 0.15, {Color = C.border, Transparency = 0.4})
                twPlay(inputBox, 0.15, {BackgroundColor3 = C.inputBg})
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
-- KEYBIND SELECTOR
-- ==========================================
local function createKeybindSelector(yPos, parent)
        local f = cardFrame(yPos, 54, parent)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.Position = UDim2.new(0, 18, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Tecla Painel"
        lbl.TextColor3 = C.text
        lbl.TextSize = 14
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 7
        lbl.Parent = f

        local kbBtn = makeBtn(Config.Keybind.Name, 0, 0, 96, 32, f, C.btnBlue)
        kbBtn.Position = UDim2.new(1, -112, 0.5, -16)
        kbBtn.TextSize = 13
        kbBtn.Font = Enum.Font.GothamBlack

        local listening = false
        kbBtn.Activated:Connect(function()
                if listening then return end
                listening = true
                kbBtn.Text = "..."
                twPlay(kbBtn, 0.15, {BackgroundColor3 = C.accentPink})
                local conn
                conn = UIS.InputBegan:Connect(function(input, gpe)
                        if gpe then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                                Config.Keybind = input.KeyCode
                                kbBtn.Text = input.KeyCode.Name
                                twPlay(kbBtn, 0.2, {BackgroundColor3 = C.btnBlue}, Enum.EasingStyle.Back)
                                listening = false
                                conn:Disconnect()
                                saveConfig(Config)
                        end
                end)
        end)

        return yPos + 54 + CARD_GAP
end

-- ==========================================
-- CARD SPAM MANUAL - PREMIUM
-- ==========================================
local function createSpamPCCard(yPos, parent)
        local CARD_H = 132
        local f = cardFrame(yPos, CARD_H, parent)
        cardLabel("MANUAL SPAM", f, C.accentPink)

        -- linha 1: toggle ON/OFF grande + botão de visibilidade
        local visBtn = makeBtn("▶ MINI UI: OCULTO", 18, 26, COL_W - 36, 30, f, C.btnDark)
        visBtn.TextSize = 10
        visBtn.Font = Enum.Font.GothamBlack

        visBtn.Activated:Connect(function()
                showMini(not miniVisible, visBtn)
        end)

        -- toggle premium com OFF/ON (tamanho padrão, só texto grande)
        local track = Instance.new("Frame", f)
        track.Size = UDim2.new(0, 72, 0, 32)
        track.Position = UDim2.new(0.5, -36, 0, 64)
        track.BackgroundColor3 = (Config.SpamOn or false) and C.toggleOn or C.toggleOff
        track.BorderSizePixel = 0
        track.ZIndex = 8
        corner(track, 16)

        makeGradient(track, (Config.SpamOn or false) and {
                ColorSequenceKeypoint.new(0, C.accentGlow),
                ColorSequenceKeypoint.new(0.5, C.accent),
                ColorSequenceKeypoint.new(1, C.accentPink),
        } or {
                ColorSequenceKeypoint.new(0, C.toggleOff),
                ColorSequenceKeypoint.new(1, C.toggleOffGlow),
        }, 90)

        local trackGlow = Instance.new("Frame", track)
        trackGlow.Size = UDim2.new(1, 10, 1, 10)
        trackGlow.Position = UDim2.new(0, -5, 0, -5)
        trackGlow.BackgroundColor3 = (Config.SpamOn or false) and C.accentPink or C.toggleOff
        trackGlow.BackgroundTransparency = (Config.SpamOn or false) and 0.6 or 0.95
        trackGlow.BorderSizePixel = 0
        trackGlow.ZIndex = 7
        corner(trackGlow, 22)

        local trackStroke = stroke(track, C.accent, 1.5)
        trackStroke.Transparency = 0.5

        -- texto ON/OFF GRANDE
        local stateText = Instance.new("TextLabel", track)
        stateText.Size = UDim2.new(1, 0, 1, 0)
        stateText.BackgroundTransparency = 1
        stateText.Text = (Config.SpamOn or false) and "ON" or "OFF"
        stateText.TextColor3 = C.white
        stateText.TextSize = 14
        stateText.Font = Enum.Font.GothamBlack
        stateText.ZIndex = 10
        stateText.TextTransparency = 0
        stateText.TextXAlignment = (Config.SpamOn or false) and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
        local textPad = Instance.new("UIPadding", stateText)
        textPad.PaddingLeft = UDim.new(0, 7)
        textPad.PaddingRight = UDim.new(0, 7)

        local thumb = Instance.new("Frame", track)
        thumb.Size = UDim2.new(0, 26, 0, 26)
        thumb.Position = (Config.SpamOn or false) and UDim2.new(0, 43, 0.5, -13) or UDim2.new(0, 3, 0.5, -13)
        thumb.BackgroundColor3 = C.white
        thumb.BorderSizePixel = 0
        thumb.ZIndex = 11
        corner(thumb, 13)
        local thumbShadow = Instance.new("Frame", thumb)
        thumbShadow.Size = UDim2.new(1, 0, 1, 0)
        thumbShadow.Position = UDim2.new(0, 0, 0, 2)
        thumbShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        thumbShadow.BackgroundTransparency = 0.5
        thumbShadow.BorderSizePixel = 0
        thumbShadow.ZIndex = 10
        corner(thumbShadow, 13)

        local toggleHit = Instance.new("TextButton", track)
        toggleHit.Size = UDim2.new(1, 0, 1, 0)
        toggleHit.BackgroundTransparency = 1
        toggleHit.Text = ""
        toggleHit.ZIndex = 13

        local function refreshToggle(v)
                twPlay(thumb, 0.32, {Position = v and UDim2.new(0, 43, 0.5, -13) or UDim2.new(0, 3, 0.5, -13)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                twPlay(track, 0.28, {BackgroundColor3 = v and C.toggleOn or C.toggleOff}, Enum.EasingStyle.Quint)
                task.spawn(function()
                        twPlay(thumb, 0.06, {Size = UDim2.new(0, 24, 0, 24)})
                        task.wait(0.06)
                        twPlay(thumb, 0.16, {Size = UDim2.new(0, 28, 0, 28)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                        task.wait(0.16)
                        twPlay(thumb, 0.1, {Size = UDim2.new(0, 26, 0, 26)})
                end)
                task.spawn(function()
                        task.wait(0.08)
                        stateText.Text = v and "ON" or "OFF"
                        stateText.TextXAlignment = v and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
                        stateText.TextColor3 = v and Color3.fromRGB(180, 255, 200) or Color3.fromRGB(255, 180, 180)
                        twPlay(stateText, 0.3, {TextColor3 = C.white}, Enum.EasingStyle.Quad)
                        twPlay(thumbDot, 0.25, {BackgroundColor3 = v and C.accentPink or C.subtextDim})
                end)
                task.spawn(function()
                        task.wait(0.05)
                        if v then
                                makeGradient(track, {
                                        ColorSequenceKeypoint.new(0, C.accentGlow),
                                        ColorSequenceKeypoint.new(0.5, C.accent),
                                        ColorSequenceKeypoint.new(1, C.accentPink),
                                }, 90)
                                twPlay(trackGlow, 0.25, {BackgroundColor3 = C.accentPink, BackgroundTransparency = 0.6})
                                twPlay(trackStroke, 0.25, {Color = C.accentPink, Transparency = 0.2})
                        else
                                makeGradient(track, {
                                        ColorSequenceKeypoint.new(0, C.toggleOff),
                                        ColorSequenceKeypoint.new(1, C.toggleOffGlow),
                                }, 90)
                                twPlay(trackGlow, 0.25, {BackgroundColor3 = C.toggleOff, BackgroundTransparency = 0.95})
                                twPlay(trackStroke, 0.25, {Color = C.accent, Transparency = 0.5})
                        end
                end)
        end

        toggleHit.Activated:Connect(function()
                local v = not (Config.SpamOn or false)
                Config.SpamOn = v
                if v then
                        setSpam(true)
                else
                        setSpam(false)
                end
                refreshToggle(v)
                saveConfig(Config)
        end)

        -- linha 2: keybind + mode
        local halfW = math.floor((COL_W - 36 - 8) / 2)

        local kbBtn = makeBtn(
                Config.SpamKeybind and Config.SpamKeybind.Name or "X",
                18, 110, halfW, 0, f, C.btnBlue
        )
        kbBtn.Size = UDim2.new(0, halfW, 0, 0)
        kbBtn.Position = UDim2.new(0, 18, 0, 110)
        -- força tamanho inicial
        task.defer(function()
                kbBtn.Size = UDim2.new(0, halfW, 0, 16)
        end)
        kbBtn.TextSize = 11
        kbBtn.Font = Enum.Font.GothamBlack
        kbBtn.Text = "KEY: " .. (Config.SpamKeybind and Config.SpamKeybind.Name or "X")

        local listeningKb = false
        kbBtn.Activated:Connect(function()
                if listeningKb then return end
                listeningKb = true
                kbBtn.Text = "..."
                twPlay(kbBtn, 0.15, {BackgroundColor3 = C.accentPink})
                local conn
                conn = UIS.InputBegan:Connect(function(input, gpe)
                        if gpe then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                                Config.SpamKeybind = input.KeyCode
                                kbBtn.Text = "KEY: " .. input.KeyCode.Name
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
                "MODE: " .. (Config.SpamMode or "Toggle"),
                18 + halfW + 8, 110, halfW, 16, f,
                getModeColor(Config.SpamMode or "Toggle")
        )
        task.defer(function()
                modeBtn.Size = UDim2.new(0, halfW, 0, 16)
        end)
        modeBtn.TextSize = 10
        modeBtn.Font = Enum.Font.GothamBlack

        modeBtn.Activated:Connect(function()
                Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
                modeBtn.Text = "MODE: " .. Config.SpamMode
                twPlay(modeBtn, 0.2, {BackgroundColor3 = getModeColor(Config.SpamMode)}, Enum.EasingStyle.Back)
                if Config.SpamMode == "Toggle" and _G.PhantomManual then
                        setSpam(false)
                        Config.SpamOn = false
                        refreshToggle(false)
                end
                saveConfig(Config)
        end)

        return yPos + CARD_H + CARD_GAP
end

print("[PhantomGUI] Componentes criados.")

-- ==========================================
-- MONTAR COLUNAS
-- ==========================================
local yL, yR = 4, 4

yL = createLabeledToggle("Auto Parry", "AutoParry", yL, colLeft)

-- Auto Clash (toggle padrão)
yL = createToggle("Auto Clash", "AutoClash", yL, colLeft)

yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)
yR = createSpamPCCard(yR, colRight)

print("[PhantomGUI] Colunas montadas.")

-- ==========================================
-- DRAG PAINEL / BOTAO
-- ==========================================
makeDraggable(titleBar, configPanel, function()
        Config.PanelX = configPanel.Position.X.Offset
        Config.PanelY = configPanel.Position.Y.Offset
        saveConfig(Config)
end)

local btnIsDragging = makeDraggable(floatingButton, floatingButton, function()
        Config.BtnX = floatingButton.Position.X.Offset
        Config.BtnY = floatingButton.Position.Y.Offset
        saveConfig(Config)
end)

-- ==========================================
-- ABRIR / FECHAR PAINEL
-- ==========================================
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
                -- posição central
                configPanel.Visible = true
                panelGlow.Visible = true
                shadowFrame.Visible = true
                configPanel.BackgroundTransparency = 1
                configPanel.Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85)

                panelTween = twPlay(configPanel, 0.35,
                        {Size = UDim2.new(0, PW, 0, PH), BackgroundTransparency = 0},
                        Enum.EasingStyle.Back, Enum.EasingDirection.Out)

                -- glow + sombra seguem
                panelGlow.Size = UDim2.new(0, PW * 0.85 + 24, 0, PH * 0.85 + 24)
                panelGlow.Position = configPanel.Position + UDim2.new(0, -12, 0, -12)
                shadowFrame.Size = UDim2.new(0, PW * 0.85 + 18, 0, PH * 0.85 + 18)
                shadowFrame.Position = configPanel.Position + UDim2.new(0, -9, 0, -9)

                twPlay(panelGlow, 0.35, {
                        Size = UDim2.new(0, PW + 24, 0, PH + 24),
                        BackgroundTransparency = 0.92,
                }, Enum.EasingStyle.Quint)
                twPlay(shadowFrame, 0.35, {
                        Size = UDim2.new(0, PW + 18, 0, PH + 18),
                        BackgroundTransparency = 0.5,
                }, Enum.EasingStyle.Quint)

                -- botão flutuante: encolhe
                btnTween = twPlay(floatingButton, 0.25,
                        {BackgroundTransparency = 0.6, Size = UDim2.new(0, 46, 0, 46)},
                        Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        else
                -- fechando
                panelTween = twPlay(configPanel, 0.25,
                        {Size = UDim2.new(0, PW * 0.9, 0, PH * 0.9), BackgroundTransparency = 1},
                        Enum.EasingStyle.Quint, Enum.EasingDirection.In)

                twPlay(panelGlow, 0.25, {
                        BackgroundTransparency = 1,
                }, Enum.EasingStyle.Quint)

                twPlay(shadowFrame, 0.25, {
                        BackgroundTransparency = 1,
                }, Enum.EasingStyle.Quint)

                btnTween = twPlay(floatingButton, 0.28,
                        {BackgroundTransparency = 0.1, Size = UDim2.new(0, 60, 0, 60)},
                        Enum.EasingStyle.Back, Enum.EasingDirection.Out)

                closeConn = panelTween.Completed:Connect(function()
                        if not panelOpen then
                                configPanel.Visible = false
                                panelGlow.Visible = false
                                shadowFrame.Visible = false
                                configPanel.Size = UDim2.new(0, PW, 0, PH)
                                configPanel.BackgroundTransparency = 0
                                configPanel.Position = UDim2.new(0.5, -PW / 2, 0.5, -PH / 2)
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
        if panelOpen then
                togglePanel()
        end
end)

trackConn(UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Config.Keybind then
                togglePanel()
        end
end))

print("[PhantomGUI] Sistema abrir/fechar configurado.")

-- ==========================================
-- FECHAR SCRIPT
-- ==========================================
killBtn.Activated:Connect(function()
        State.scriptActive = false
        _G.PhantomManual = false
        _G.PhantomAutoClash = false
        saveConfig(Config)

        -- efeito de "shutdown"
        twPlay(configPanel, 0.3, {BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85)}, Enum.EasingStyle.Quint)
        twPlay(panelGlow, 0.3, {BackgroundTransparency = 1})
        twPlay(shadowFrame, 0.3, {BackgroundTransparency = 1})
        twPlay(floatingButton, 0.3, {BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})
        twPlay(miniGui, 0.3, {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)})

        task.wait(0.4)
        for _, c in ipairs(State.connections) do
                pcall(function() c:Disconnect() end)
        end
        pcall(function() State.outer:Destroy() end)
        pcall(function() State.inner:Destroy() end)
        pcall(function() screenGui:Destroy() end)
        print("[PhantomGUI] Script encerrado.")
end)

-- ==========================================
-- SCAN LINE - PREMIUM
-- ==========================================
local scanLine = Instance.new("Frame", configPanel)
scanLine.Size = UDim2.new(1, 0, 0, 2)
scanLine.Position = UDim2.new(0, 0, 0, 0)
scanLine.BackgroundColor3 = C.accent
scanLine.BackgroundTransparency = 0.7
scanLine.BorderSizePixel = 0
scanLine.ZIndex = 2

makeGradient(scanLine, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.3, C.accent),
        ColorSequenceKeypoint.new(0.5, C.accentPink),
        ColorSequenceKeypoint.new(0.7, C.accentCyan),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})

task.spawn(function()
        while true do
                if not configPanel.Parent then break end
                twPlay(scanLine, 3, {Position = UDim2.new(0, 0, 1, -2)}, Enum.EasingStyle.Linear)
                task.wait(3)
                scanLine.Position = UDim2.new(0, 0, 0, 0)
                task.wait(0.15)
        end
end)

-- ==========================================
-- PARTÍCULAS PREMIUM
-- ==========================================
local particleContainer = Instance.new("Frame", configPanel)
particleContainer.Size = UDim2.new(1, 0, 1, 0)
particleContainer.BackgroundTransparency = 1
particleContainer.ZIndex = 1
particleContainer.ClipsDescendants = true

local function spawnParticle()
        local dot = Instance.new("Frame", particleContainer)
        local size = math.random(2, 5)
        dot.Size = UDim2.new(0, size, 0, size)
        dot.Position = UDim2.new(math.random() * 0.98, 0, 1, 0)
        local colors = {C.accent, C.accentGlow, C.accentPink, C.accentCyan}
        dot.BackgroundColor3 = colors[math.random(1, #colors)]
        dot.BackgroundTransparency = 0.4
        dot.BorderSizePixel = 0
        dot.ZIndex = 1
        corner(dot, 1)

        -- glow da partícula
        local pGlow = Instance.new("Frame", dot)
        pGlow.Size = UDim2.new(1, 6, 1, 6)
        pGlow.Position = UDim2.new(0, -3, 0, -3)
        pGlow.BackgroundColor3 = dot.BackgroundColor3
        pGlow.BackgroundTransparency = 0.7
        pGlow.BorderSizePixel = 0
        pGlow.ZIndex = 1
        corner(pGlow, 1)

        local dur = math.random(4, 8)
        local drift = (math.random() - 0.5) * 0.15
        twPlay(dot, dur, {
                Position = UDim2.new(math.clamp(dot.Position.X.Scale + drift, 0, 1), 0, -0.1, 0),
                BackgroundTransparency = 1,
        }, Enum.EasingStyle.Linear)
        twPlay(pGlow, dur, {BackgroundTransparency = 1}, Enum.EasingStyle.Linear)

        task.delay(dur, function()
                pcall(function() dot:Destroy() end)
        end)
end

task.spawn(function()
        while true do
                task.wait(math.random() * 0.5 + 0.15)
                if configPanel.Visible then
                        spawnParticle()
                end
        end
end)

-- ==========================================
-- VINHETA NAS BORDAS
-- ==========================================
local vignette = Instance.new("Frame", configPanel)
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignette.BackgroundTransparency = 0.85
vignette.BorderSizePixel = 0
vignette.ZIndex = 1
local vGrad = makeGradient(vignette, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
})
vGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.15, 0),
        NumberSequenceKeypoint.new(0.85, 0),
        NumberSequenceKeypoint.new(1, 0.7),
})

print("[PhantomGUI] Efeitos visuais configurados.")
print("[PhantomGUI] GUI v9.0 Premium carregada com sucesso!")
print("[PhantomGUI] Botao P para configurar | tecla: " .. Config.Keybind.Name)
