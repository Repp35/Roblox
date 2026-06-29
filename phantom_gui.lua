--[[
    Phantom Ball GUI
    Paleta: Azul / Roxo / Rosa
]]

local SCRIPT_VERSION = "9.0"
local SCRIPT_NAME    = "Phantom Ball GUI"

-- SESSAO: BOOT
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local Camera       = workspace.CurrentCamera

local _wait = task.wait
local _spawn = task.spawn

print(("[%s v%s] iniciando..."):format(SCRIPT_NAME, SCRIPT_VERSION))

-- Espera ate 3s pelo phantom_logic; se nao vier, segue sozinho com config padrao.
local bootTimeout = 0
while not _G.PhantomConfig and bootTimeout < 3 do
    _wait(0.1)
    bootTimeout = bootTimeout + 0.1
end

local old = CoreGui:FindFirstChild("PhantomUISystem")
if old then old:Destroy() end

-- SESSAO: STATE / CONFIG (STANDALONE)
local Config
if _G.PhantomConfig then
    Config = _G.PhantomConfig
    print(("[%s v%s] Config externo detectado, integrando."):format(SCRIPT_NAME, SCRIPT_VERSION))
else
    Config = {
        AutoParry         = false,
        AutoClash         = false,
        CPS               = 25, -- DEFAULT_CPS (consistente com funcional.lua)
        CustomCPS         = false,
        Keybind           = Enum.KeyCode.V,
        SpamKeybind       = Enum.KeyCode.X,
        SpamMode          = "Toggle",
        ClashBallVisible  = false,
        BtnX              = nil,
        BtnY              = nil,
        ClashBallX        = 14,
        ClashBallY        = nil,
        MiniX             = nil,
        MiniY             = nil,
        PanelX            = nil,
        PanelY            = nil,
    }
    print(("[%s v%s] Rodando em modo standalone (sem phantom_logic)."):format(SCRIPT_NAME, SCRIPT_VERSION))
end

local State      = _G.PhantomState or { conns = {} }
local saveConfig = _G.PhantomSaveConfig or function() end
if not State.conns then State.conns = State.connections or {} end
_G.PhantomState  = State
_G.PhantomConfig = Config

local function trackConn(c)
    State.conns[#State.conns + 1] = c
    return c
end

local function safe(fn, ...)
    return pcall(fn, ...)
end

local function safeDisconnect(c)
    if c then safe(function() c:Disconnect() end) end
end

local function viewport()
    return Camera.ViewportSize
end

-- SESSAO: PALETA / UTIL
local C = {
    bg          = Color3.fromRGB(8, 8, 22),
    header      = Color3.fromRGB(14, 14, 34),
    card        = Color3.fromRGB(20, 20, 44),
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
    inputBg     = Color3.fromRGB(16, 16, 38),
}

local GRAD = {
    Color3.fromRGB(56, 189, 248),
    Color3.fromRGB(139, 92, 246),
    Color3.fromRGB(236, 72, 153),
}

local EASE_OUT, EASE_BACK, EASE_SINE = Enum.EasingStyle.Quint, Enum.EasingStyle.Back, Enum.EasingStyle.Sine
local DIR_OUT, DIR_IN, DIR_INOUT = Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut

local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(obj, r)  return inst("UICorner",   { CornerRadius = UDim.new(0, r) }, obj) end
local function stroke(obj, col, th) return inst("UIStroke", { Color = col, Thickness = th or 1 }, obj) end

local function gradient(obj, colors, rotation)
    local g = inst("UIGradient", { Rotation = rotation or 0 }, obj)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   colors[1]),
        ColorSequenceKeypoint.new(0.5, colors[2]),
        ColorSequenceKeypoint.new(1,   colors[3]),
    })
    return g
end

local function twPlay(obj, t, props, style, dir)
    local tween = TweenService:Create(obj, TweenInfo.new(t, style or EASE_OUT, dir or DIR_OUT), props)
    tween:Play()
    return tween
end

local function safeCancel(tween)
    if tween then safe(function() tween:Cancel() end) end
end

-- SESSAO: DRAG
local function makeDraggable(handle, target, onDragEnd)
    local state, dragInput, dragOffX, dragOffY = "Idle", nil, 0, 0
    local wasDragged, startX, startY = false, 0, 0
    local THRESH_SQ = 100  -- 10px²

    trackConn(handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if state ~= "Idle" then return end
        state = "Pressed"
        wasDragged = false
        local abs = target.AbsolutePosition
        dragOffX, dragOffY = input.Position.X - abs.X, input.Position.Y - abs.Y
        startX, startY = input.Position.X, input.Position.Y
        dragInput = input
    end))

    trackConn(UIS.InputChanged:Connect(function(input)
        if state == "Idle" or input ~= dragInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local dx = input.Position.X - startX
        local dy = input.Position.Y - startY

        if state == "Pressed" then
            if (dx * dx + dy * dy) < THRESH_SQ then return end
            state, wasDragged = "Dragging", true
        end

        if state == "Dragging" then
            local vp, sz = viewport(), target.AbsoluteSize
            target.Position = UDim2.new(
                0, math.clamp(input.Position.X - dragOffX, 0, vp.X - sz.X),
                0, math.clamp(input.Position.Y - dragOffY, 0, vp.Y - sz.Y)
            )
        end
    end))

    trackConn(UIS.InputEnded:Connect(function(input)
        if input ~= dragInput or state == "Idle" then return end
        state, dragInput = "Idle", nil
        if wasDragged and onDragEnd then safe(onDragEnd) end
        wasDragged = false
    end))

    return function() return state == "Dragging" end
end

-- ============================================================
-- SESSAO: SCREEN GUI + GRADIENTE ANIMADO
-- ============================================================
local screenGui = inst("ScreenGui", {
    Name           = "PhantomUISystem",
    ResetOnSpawn   = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent         = CoreGui,
})

local flowingGradients = {}
local function attachFlowingGradient(s)
    local g = inst("UIGradient", { Rotation = 0 }, s)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   GRAD[1]),
        ColorSequenceKeypoint.new(0.5, GRAD[2]),
        ColorSequenceKeypoint.new(1,   GRAD[3]),
    })
    flowingGradients[#flowingGradients + 1] = g
    return g
end

_spawn(function()
    local STEP = 0.005
    while screenGui.Parent do
        for off = 0, 1, STEP do
            if not screenGui.Parent then return end
            for i = 1, #flowingGradients do
                local g = flowingGradients[i]
                if g and g.Parent then g.Offset = Vector2.new(off, 0) end
            end
            _wait(0.03)
        end
    end
end)

-- ============================================================
-- SESSAO: BOTAO FLUTUANTE (P)
-- ============================================================
local BTN_SIZE = 56
local floatingButton = inst("TextButton", { Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE), Position = Config.BtnX and UDim2.new(0, Config.BtnX, 0, Config.BtnY) or UDim2.new(1, -70, 0.5, -28), BackgroundColor3 = C.header, BackgroundTransparency = 0.1, Text = "P", TextColor3 = C.text, TextSize = 26, Font = Enum.Font.GothamBold, Active = true, ZIndex = 10, Parent = screenGui, })
corner(floatingButton, 999)

attachFlowingGradient(stroke(floatingButton, C.accent, 2))

-- SESSAO: BOLINHA AUTO CLASH
local CLASH_SIZE = 64
local clashX = Config.ClashBallX or 14
local clashY = Config.ClashBallY or (viewport().Y / 2 - CLASH_SIZE / 2)
Config.ClashBallVisible = Config.ClashBallVisible or false

if clashX + CLASH_SIZE > viewport().X - BTN_SIZE - 10 then
    clashX = 14
    Config.ClashBallX = 14
end

local clashBall = inst("TextButton", { Name = "PhantomClashBall", Size = UDim2.new(0, CLASH_SIZE, 0, CLASH_SIZE), Position = UDim2.new(0, -CLASH_SIZE - 40, 0.5, -CLASH_SIZE / 2), BackgroundColor3 = C.red, Text = "OFF", TextColor3 = Color3.new(1, 1, 1), TextSize = 16, Font = Enum.Font.GothamBold, Active = true, ZIndex = 8, Parent = screenGui, })
corner(clashBall, 999)
stroke(clashBall, Color3.fromRGB(20, 20, 30), 2)
stroke(clashBall, Color3.new(0, 0, 0), 2)

local clashBallOn = _G.PhantomAutoClash or false

local autoClashTrack, autoClashThumb = nil, nil
local function syncAutoClashToggle()
    if not (autoClashTrack and autoClashThumb) then return end
    local v = clashBallOn
    twPlay(autoClashTrack, 0.22, { BackgroundColor3 = v and C.toggleOn or C.toggleOff }, EASE_SINE, DIR_INOUT)
    twPlay(autoClashThumb,  0.32, { Position = v and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) }, EASE_BACK, DIR_OUT)
end

local function paintClashBall()
    twPlay(clashBall, 0.28, { BackgroundColor3 = clashBallOn and C.green or C.red }, EASE_SINE, DIR_INOUT)
    clashBall.Text = clashBallOn and "ON" or "OFF"
    clashBall.TextSize = clashBallOn and 18 or 16
end

local function setClashBall(v, silent)
    clashBallOn = v
    _G.PhantomAutoClash = v
    Config.AutoClash = v
    if not silent then
        paintClashBall()
        twPlay(clashBall, 0.08, { Size = UDim2.new(0, CLASH_SIZE - 6, 0, CLASH_SIZE - 6) }, EASE_SINE, DIR_OUT)
        task.delay(0.08, function()
            twPlay(clashBall, 0.28, { Size = UDim2.new(0, CLASH_SIZE, 0, CLASH_SIZE) }, EASE_BACK, DIR_OUT)
        end)
    end
    safe(saveConfig, Config)
end

clashBall.Text = clashBallOn and "ON" or "OFF"
clashBall.TextSize = clashBallOn and 18 or 16
clashBall.BackgroundColor3 = clashBallOn and C.green or C.red

local function showClashBall(v)
    Config.ClashBallVisible = v
    twPlay(clashBall, (v and 0.22) or 0.18,
        { Position = v and UDim2.new(0, clashX, 0, clashY) or UDim2.new(0, -CLASH_SIZE - 40, 0, clashY) },
        v and EASE_BACK or EASE_OUT, DIR_OUT)
end

makeDraggable(clashBall, clashBall, function()
    clashX, clashY = clashBall.Position.X.Offset, clashBall.Position.Y.Offset
    Config.ClashBallX, Config.ClashBallY = clashX, clashY
    safe(saveConfig, Config)
end)

clashBall.Activated:Connect(function()
    setClashBall(not clashBallOn)
    syncAutoClashToggle()
end)

-- SESSAO: MINI GUI SPAM
local MINI_W, MINI_H = 120, 90
local miniX = Config.MiniX or (viewport().X - MINI_W - 14)
local miniY = Config.MiniY or (viewport().Y / 2 - MINI_H / 2)

local miniGui = inst("Frame", { Name = "PhantomSpamMini", Size = UDim2.new(0, MINI_W, 0, MINI_H), Position = UDim2.new(0, viewport().X + 30, 0, miniY), BackgroundColor3 = C.header, BackgroundTransparency = 0.1, ZIndex = 15, Parent = screenGui, })
corner(miniGui, 14)

inst("Frame", { Size = UDim2.new(1, 8, 1, 8), Position = UDim2.new(0, -4, 0, -4), BackgroundColor3 = C.accent, BackgroundTransparency = 0.92, ZIndex = 14, Parent = miniGui, })
corner(miniGui, 18)
attachFlowingGradient(stroke(miniGui, C.accent, 1.5))

local miniTitleBar = inst("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(20, 20, 46), BackgroundTransparency = 0.05, ZIndex = 16, Parent = miniGui, })
corner(miniTitleBar, 14)

inst("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = Color3.fromRGB(20, 20, 46), BackgroundTransparency = 0.05, ZIndex = 16, Parent = miniTitleBar, })

local miniAccent = inst("Frame", { Size = UDim2.new(0.5, 0, 0, 2), Position = UDim2.new(0.25, 0, 0, 0), BackgroundColor3 = C.accentPink, ZIndex = 17, Parent = miniTitleBar, })
corner(miniAccent, 999)

inst("TextLabel", { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = "Spam", TextColor3 = C.subtext, TextScaled = true, Font = Enum.Font.GothamBold, ZIndex = 17, Parent = miniTitleBar, })

local spamBtn = inst("TextButton", { Size = UDim2.new(1, -16, 0, 48), Position = UDim2.new(0, 8, 0, 32), BackgroundColor3 = C.red, BackgroundTransparency = 0.1, Text = "OFF", TextColor3 = Color3.new(1, 1, 1), TextSize = 24, Font = Enum.Font.GothamBold, ZIndex = 16, Parent = miniGui, })
corner(spamBtn, 10)

local spamOn = false
local function setSpam(v)
    spamOn = v
    _G.PhantomManual = v
    spamBtn.Text = v and "ON" or "OFF"
    twPlay(spamBtn, 0.25, { BackgroundColor3 = v and C.green or C.red }, EASE_SINE, DIR_INOUT)
    twPlay(spamBtn, 0.08, { Size = UDim2.new(1, -22, 0, 44) }, EASE_SINE, DIR_OUT)
    task.delay(0.08, function()
        twPlay(spamBtn, 0.28, { Size = UDim2.new(1, -16, 0, 48) }, EASE_BACK, DIR_OUT)
    end)
end

spamBtn.Activated:Connect(function() setSpam(not spamOn) end)

makeDraggable(miniTitleBar, miniGui, function()
    miniX, miniY = miniGui.Position.X.Offset, miniGui.Position.Y.Offset
    Config.MiniX, Config.MiniY = miniX, miniY
    safe(saveConfig, Config)
end)

local function showMini(v, visBtn)
    twPlay(miniGui, (v and 0.22) or 0.18,
        { Position = v and UDim2.new(0, miniX, 0, miniY) or UDim2.new(0, viewport().X + 30, 0, miniY) },
        v and EASE_BACK or EASE_OUT, DIR_OUT)
    if visBtn then
        visBtn.Text = v and "Mini UI: Visivel" or "Mini UI: Oculto"
        twPlay(visBtn, 0.15, { BackgroundColor3 = v and Color3.fromRGB(0, 130, 65) or C.btnDark })
    end
end

-- SESSAO: PAINEL PRINCIPAL
local PW, PH = 540, 380
local TITLE_H, PAD, GAP, CARD_GAP = 50, 14, 12, 8
local CONTENT_H = PH - TITLE_H - 60
local COL_W = math.floor((PW - PAD * 2 - GAP) / 2)

local configPanel = inst("Frame", { Name = "PhantomPanel", Size = UDim2.new(0, PW, 0, PH), Position = Config.PanelX and UDim2.new(0, Config.PanelX, 0, Config.PanelY) or UDim2.new(0.5, -PW / 2, 0.5, -PH / 2), BackgroundColor3 = C.bg, BackgroundTransparency = 0.08, Visible = false, ZIndex = 5, ClipsDescendants = true, Parent = screenGui, })
corner(configPanel, 16)
stroke(configPanel, C.accent, 1.5) -- stroke estatico, sem gradiente animado

-- ============================================================
-- SESSAO: PARTICULAS DE FUNDO (subindo, com leve perspectiva)
-- ============================================================
local particleLayer = inst("Frame", {
    Name = "ParticleLayer",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 4,
    ClipsDescendants = true,
    Parent = configPanel,
})

-- cores desaturadas (misturadas com o fundo escuro)
local PARTICLE_COLORS = {
    Color3.fromRGB(85, 90, 140),   -- indigo desaturado
    Color3.fromRGB(110, 95, 150),  -- roxo desaturado
    Color3.fromRGB(150, 95, 130),  -- rosa desaturado
    Color3.fromRGB(95, 130, 165),  -- ciano desaturado
}

local function spawnParticle()
    local isFar = math.random() < 0.6
    local size = isFar and math.random(2, 3) or math.random(4, 6)
    local startTrans = isFar and 0.5 or 0.2

    local dot = inst("Frame", {
        Size = UDim2.new(0, size, 0, size),
        Position = UDim2.new(math.random(), 0, 1, 0),
        BackgroundColor3 = PARTICLE_COLORS[math.random(1, #PARTICLE_COLORS)],
        BackgroundTransparency = startTrans,
        ZIndex = 4,
        Parent = particleLayer,
    })
    corner(dot, 999)

    local dur = isFar and math.random(5, 9) or math.random(3, 5)
    local endX = math.clamp(dot.Position.X.Scale + (math.random() - 0.5) * 0.15, 0, 1)

    twPlay(dot, 0.6, { BackgroundTransparency = math.max(startTrans - 0.1, 0.05) }, EASE_SINE, DIR_OUT)
    twPlay(dot, dur, { Position = UDim2.new(endX, 0, -0.1, 0), BackgroundTransparency = 1 }, EASE_SINE, DIR_INOUT)

    task.delay(dur + 0.2, function()
        if dot.Parent then dot:Destroy() end
    end)
end

_spawn(function()
    while true do
        _wait(math.random() * 0.6 + 0.15)
        if configPanel.Visible then spawnParticle() end
    end
end)

-- title bar
local titleBar = inst("Frame", { Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundColor3 = C.header, ZIndex = 6, Parent = configPanel, })
corner(titleBar, 16)

inst("TextLabel", { Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Text = ("Phantom - Config v%s"):format(SCRIPT_VERSION), TextColor3 = C.text, TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, Parent = titleBar, })

do
    local badge = inst("TextLabel", { Size = UDim2.new(0, 56, 0, 18), Position = UDim2.new(0, 10, 0.5, -9), BackgroundColor3 = C.accent, BackgroundTransparency = 0.25, Text = ("v%s"):format(SCRIPT_VERSION), TextColor3 = C.text, TextSize = 10, Font = Enum.Font.GothamBold, ZIndex = 7, Parent = titleBar, })
    corner(badge, 6)
end

local closeButton = inst("TextButton", { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -42, 0.5, -15), BackgroundColor3 = C.red, BackgroundTransparency = 0.3, Text = "X", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = Enum.Font.GothamBold, ZIndex = 7, Parent = titleBar, })
corner(closeButton, 8)
closeButton.MouseEnter:Connect(function() twPlay(closeButton, 0.12, { BackgroundTransparency = 0 }) end)
closeButton.MouseLeave:Connect(function() twPlay(closeButton, 0.12, { BackgroundTransparency = 0.3 }) end)

-- colunas
local colLeft  = inst("Frame", { Size = UDim2.new(0, COL_W, 0, CONTENT_H), Position = UDim2.new(0, PAD, 0, TITLE_H + 12), BackgroundTransparency = 1, ZIndex = 6, Parent = configPanel })
local colRight = inst("Frame", { Size = UDim2.new(0, COL_W, 0, CONTENT_H), Position = UDim2.new(0, PAD + COL_W + GAP, 0, TITLE_H + 12), BackgroundTransparency = 1, ZIndex = 6, Parent = configPanel })

-- kill button (sem stroke, mais discreto, sem efeito de resize no hover)
local killBtn = inst("TextButton", { Size = UDim2.new(0, 124, 0, 26), Position = UDim2.new(0.5, -62, 1, -52), BackgroundColor3 = C.redDark, BackgroundTransparency = 0.15, Text = "Fechar Script", TextColor3 = Color3.fromRGB(255, 200, 200), TextSize = 11, Font = Enum.Font.GothamBold, ZIndex = 7, Parent = configPanel, })
corner(killBtn, 6)

if not UIS.TouchEnabled then
    killBtn.MouseEnter:Connect(function()
        twPlay(killBtn, 0.12, { BackgroundColor3 = Color3.fromRGB(170, 35, 35) })
    end)
    killBtn.MouseLeave:Connect(function()
        twPlay(killBtn, 0.12, { BackgroundColor3 = C.redDark })
    end)
end

-- SESSAO: FAIXA DE STATUS (info do funcional + versao)
local DIAG_H = 18
local diagBar = inst("Frame", { Size = UDim2.new(1, -PAD * 2, 0, DIAG_H), Position = UDim2.new(0, PAD, 1, -52 - DIAG_H - 4), BackgroundColor3 = C.card, BackgroundTransparency = 0.4, ZIndex = 7, Parent = configPanel, })
corner(diagBar, 6)
stroke(diagBar, C.border, 1)

local diagLabel = inst("TextLabel", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = ("%s v%s | aguardando funcional..."):format(SCRIPT_NAME, SCRIPT_VERSION), TextColor3 = C.subtext, TextSize = 10, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = diagBar, })

local function refreshDiag()
    local d = _G.PhantomDiag
    if type(d) ~= "table" then
        diagLabel.Text = ("%s v%s | funcional nao detectado").format(SCRIPT_NAME, SCRIPT_VERSION)
        return
    end
    local ver   = tostring(d.version or "?")
    local name  = tostring(d.scriptName or "funcional")
    local rem   = d.parryRemote and d.parryRemote:match("[^%.]+$") or (d.remotesOk and "?" or "nil")
    local ball  = d.ballOk and "ok" or "nil"
    local ping  = d.ping and (("%.0fms"):format((d.ping or 0) * 1000)) or "?"
    local place = d.placeName or ("#" .. tostring(d.placeId or "?"))
    local res   = d.resilience and ("res+" .. tostring(d.resStack or 0)) or "no-res"
    diagLabel.Text = (("%s v%s + %s v%s | %s | rmt=%s | ball=%s | ping=%s | %s"):format(
        SCRIPT_NAME, SCRIPT_VERSION, name, ver, place, rem, ball, ping, res))
end

_spawn(function()
    while screenGui.Parent do
        if configPanel.Visible then pcall(refreshDiag) end
        _wait(0.4)
    end
end)

-- SESSAO: COMPONENTES
local function cardFrame(yPos, h, parent)
    local f = inst("Frame", { Size = UDim2.new(1, 0, 0, h), Position = UDim2.new(0, 0, 0, yPos), BackgroundColor3 = C.card, BackgroundTransparency = 0.1, ZIndex = 6, Parent = parent, })
    corner(f, 12)
    local s = stroke(f, C.border, 1)
    f.MouseEnter:Connect(function()
        twPlay(s, 0.22, { Color = C.accent }, EASE_SINE, DIR_INOUT)
        twPlay(f, 0.22, { BackgroundColor3 = Color3.fromRGB(24, 24, 50) }, EASE_SINE, DIR_INOUT)
    end)
    f.MouseLeave:Connect(function()
        twPlay(s, 0.25, { Color = C.border }, EASE_SINE, DIR_INOUT)
        twPlay(f, 0.25, { BackgroundColor3 = C.card }, EASE_SINE, DIR_INOUT)
    end)
    return f
end

local function cardLabel(text, parent)
    inst("TextLabel", { Size = UDim2.new(1, -10, 0, 16), Position = UDim2.new(0, 10, 0, 5), BackgroundTransparency = 1, Text = text, TextColor3 = C.accent, TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = parent, })
end

local function makeBtn(text, x, y, w, h, parent, bg)
    local b = inst("TextButton", { Size = UDim2.new(0, w, 0, h), Position = UDim2.new(0, x, 0, y), BackgroundColor3 = bg or C.btnBlue, BackgroundTransparency = 0.1, Text = text, TextColor3 = C.text, TextSize = 13, Font = Enum.Font.GothamBold, ZIndex = 7, Parent = parent, })
    corner(b, 8)
    return b
end

local function bindKeyCapture(btn, onPicked)
    local listening = false
    btn.Activated:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "..."
        twPlay(btn, 0.1, { BackgroundColor3 = Color3.fromRGB(80, 85, 160) })
        local conn
        conn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            safe(onPicked, input.KeyCode)
            listening = false
            safeDisconnect(conn)
        end)
    end)
end

local function createToggle(labelText, configKey, yPos, parent)
    local f = cardFrame(yPos, 52, parent)
    inst("TextLabel", { Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Text = labelText, TextColor3 = C.text, TextSize = 14, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = f, })

    local track = inst("Frame", { Size = UDim2.new(0, 48, 0, 26), Position = UDim2.new(1, -62, 0.5, -13), BackgroundColor3 = Config[configKey] and C.toggleOn or C.toggleOff, BackgroundTransparency = 0.1, ZIndex = 7, Parent = f, })
    corner(track, 999)
    local thumb = inst("Frame", { Size = UDim2.new(0, 20, 0, 20), Position = Config[configKey] and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8, Parent = track, })
    corner(thumb, 999)

    inst("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 9, Parent = f, }).Activated:Connect(function()
        Config[configKey] = not Config[configKey]
        local v = Config[configKey]

        if configKey == "AutoClash" then
            setClashBall(v, true)
            paintClashBall()
        end

        twPlay(track, 0.22, { BackgroundColor3 = v and C.toggleOn or C.toggleOff }, EASE_SINE, DIR_INOUT)
        twPlay(thumb,  0.32, { Position = v and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) }, EASE_BACK, DIR_OUT)
        twPlay(thumb, 0.08, { Size = UDim2.new(0, 24, 0, 24) }, EASE_SINE, DIR_OUT)
        task.delay(0.08, function()
            twPlay(thumb, 0.18, { Size = UDim2.new(0, 20, 0, 20) }, EASE_BACK, DIR_OUT)
        end)
        safe(saveConfig, Config)
    end)

    if configKey == "AutoClash" then
        autoClashTrack, autoClashThumb = track, thumb
    end
    return yPos + 52 + CARD_GAP
end

local function createCPSSelector(yPos, parent)
    local ROW_Y, ROW_H = 28, 30
    local f = cardFrame(yPos, 68, parent)
    cardLabel("CPS Spam", f)

    inst("TextLabel", { Size = UDim2.new(0, 36, 0, ROW_H), Position = UDim2.new(0, 14, 0, ROW_Y), BackgroundTransparency = 1, Text = "CPS:", TextColor3 = C.text, TextSize = 13, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = f, })

    local defBtn = makeBtn("Padrao", 52, ROW_Y, 68, ROW_H, f, C.btnBlue)
    defBtn.TextSize = 11

    local inputBox = inst("TextBox", { Size = UDim2.new(0, 72, 0, ROW_H), Position = UDim2.new(1, -82, 0, ROW_Y), BackgroundColor3 = C.inputBg, BackgroundTransparency = 0.1, Text = tostring(Config.CPS or 25), PlaceholderText = "CPS", TextColor3 = C.text, TextSize = 13, Font = Enum.Font.GothamBold, ZIndex = 7, Parent = f, })
    corner(inputBox, 8)
    local inputStroke = stroke(inputBox, C.border, 1)
    inputBox.Focused:Connect(function() twPlay(inputStroke, 0.15, { Color = C.accent }) end)
    inputBox.FocusLost:Connect(function() twPlay(inputStroke, 0.15, { Color = C.border }) end)

    defBtn.Activated:Connect(function()
        Config.CustomCPS = false
        Config.CPS = 25
        inputBox.Text = "25"
        twPlay(defBtn, 0.15, { BackgroundColor3 = C.green })
        task.delay(0.5, function() twPlay(defBtn, 0.15, { BackgroundColor3 = C.btnBlue }) end)
        safe(saveConfig, Config)
    end)

    inputBox.FocusLost:Connect(function()
        local v = tonumber(inputBox.Text)
        if v and v > 0 and v <= 10000 then
            if v ~= Config.CPS then
                Config.CPS = v
                Config.CustomCPS = true
            end
        else
            inputBox.Text = tostring(Config.CPS or 25)
        end
        safe(saveConfig, Config)
    end)

    return yPos + 68 + CARD_GAP
end

local function createKeybindSelector(yPos, parent)
    local f = cardFrame(yPos, 52, parent)
    inst("TextLabel", { Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Text = "Tecla de Atalho", TextColor3 = C.text, TextSize = 14, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = f, })

    local kbBtn = makeBtn(Config.Keybind and Config.Keybind.Name or "V", 0, 0, 88, 30, f, C.btnBlue)
    kbBtn.Position = UDim2.new(1, -100, 0.5, -15)
    kbBtn.Font = Enum.Font.GothamBold
    bindKeyCapture(kbBtn, function(keyCode)
        Config.Keybind = keyCode
        kbBtn.Text = keyCode.Name
        twPlay(kbBtn, 0.18, { BackgroundColor3 = C.btnBlue }, EASE_BACK)
        safe(saveConfig, Config)
    end)
    return yPos + 52 + CARD_GAP
end

local function createSpamPCCard(yPos, parent)
    local f = cardFrame(yPos, 118, parent)
    cardLabel("Manual Spam", f)

    local visBtn = makeBtn("Mini UI: Oculto", 8, 24, COL_W - 16, 30, f, C.btnDark)
    visBtn.TextSize = 11
    visBtn.Activated:Connect(function() showMini(miniGui.Position.X.Offset > viewport().X - 50, visBtn) end)

    local halfW = math.floor((COL_W - 32) / 2)
    local kbBtn = makeBtn(Config.SpamKeybind and Config.SpamKeybind.Name or "X", 8, 64, halfW, 32, f, C.btnBlue)
    bindKeyCapture(kbBtn, function(keyCode)
        Config.SpamKeybind = keyCode
        kbBtn.Text = keyCode.Name
        twPlay(kbBtn, 0.18, { BackgroundColor3 = C.btnBlue }, EASE_BACK)
        safe(saveConfig, Config)
    end)

    local function getModeColor(mode) return mode == "Hold" and C.hold or C.toggleOn end
    local modeBtn = makeBtn(Config.SpamMode or "Toggle", 8 + halfW + 14, 64, halfW, 32, f, getModeColor(Config.SpamMode or "Toggle"))
    modeBtn.Activated:Connect(function()
        Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = Config.SpamMode
        twPlay(modeBtn, 0.18, { BackgroundColor3 = getModeColor(Config.SpamMode) }, EASE_BACK)
        if Config.SpamMode == "Toggle" and _G.PhantomManual then setSpam(false) end
        safe(saveConfig, Config)
    end)

    return yPos + 118 + CARD_GAP
end

local function createMiniClashToggle(yPos, parent)
    local f = cardFrame(yPos, 52, parent)
    inst("TextLabel", { Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Text = "Mini Clash UI", TextColor3 = C.text, TextSize = 14, Font = Enum.Font.GothamSemibold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = f, })

    local on = Config.ClashBallVisible or false
    local track = inst("Frame", { Size = UDim2.new(0, 48, 0, 26), Position = UDim2.new(1, -62, 0.5, -13), BackgroundColor3 = on and C.toggleOn or C.toggleOff, BackgroundTransparency = 0.1, ZIndex = 7, Parent = f, })
    corner(track, 999)
    local thumb = inst("Frame", { Size = UDim2.new(0, 20, 0, 20), Position = on and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 8, Parent = track, })
    corner(thumb, 999)

    inst("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 9, Parent = f, }).Activated:Connect(function()
        on = not on
        Config.ClashBallVisible = on
        if on then
            showClashBall(true)
        else
            if clashBallOn then
                setClashBall(false)
                syncAutoClashToggle()
            end
            showClashBall(false)
        end
        twPlay(track, 0.22, { BackgroundColor3 = on and C.toggleOn or C.toggleOff }, EASE_SINE, DIR_INOUT)
        twPlay(thumb, 0.32, { Position = on and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) }, EASE_BACK, DIR_OUT)
        twPlay(thumb, 0.08, { Size = UDim2.new(0, 24, 0, 24) }, EASE_SINE, DIR_OUT)
        task.delay(0.08, function()
            twPlay(thumb, 0.18, { Size = UDim2.new(0, 20, 0, 20) }, EASE_BACK, DIR_OUT)
        end)
        safe(saveConfig, Config)
    end)

    return yPos + 52 + CARD_GAP
end

-- SESSAO: MONTAR COLUNAS
local yL, yR = 4, 4
yL = createToggle("Auto Parry", "AutoParry", yL, colLeft)
yL = createToggle("Auto Clash", "AutoClash", yL, colLeft)
yL = createMiniClashToggle(yL, colLeft)

yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)
yR = createSpamPCCard(yR, colRight)

-- SESSAO: DRAG PAINEL / BOTAO
makeDraggable(titleBar, configPanel, function()
    Config.PanelX = configPanel.Position.X.Offset
    Config.PanelY = configPanel.Position.Y.Offset
    safe(saveConfig, Config)
end)

local btnIsDragging = makeDraggable(floatingButton, floatingButton, function()
    Config.BtnX = floatingButton.Position.X.Offset
    Config.BtnY = floatingButton.Position.Y.Offset
    safe(saveConfig, Config)
end)

-- SESSAO: ABRIR / FECHAR PAINEL
local panelOpen, panelTween, btnTween = false, nil, nil

local function togglePanel()
    panelOpen = not panelOpen
    safeCancel(panelTween)
    safeCancel(btnTween)

    if panelOpen then
        configPanel.Visible = true
        configPanel.BackgroundTransparency = 1
        configPanel.Size = UDim2.new(0, PW * 0.88, 0, PH * 0.88)
        panelTween = twPlay(configPanel, 0.28,
            { Size = UDim2.new(0, PW, 0, PH), BackgroundTransparency = 0 },
            EASE_BACK, DIR_OUT)
        btnTween = twPlay(floatingButton, 0.2,
            { BackgroundTransparency = 0.6, Size = UDim2.new(0, 44, 0, 44) },
            EASE_OUT, DIR_IN)
    else
        panelTween = twPlay(configPanel, 0.22,
            { Size = UDim2.new(0, PW * 0.9, 0, PH * 0.9), BackgroundTransparency = 1 },
            EASE_OUT, DIR_IN)
        btnTween = twPlay(floatingButton, 0.22,
            { BackgroundTransparency = 0.1, Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE) },
            EASE_BACK, DIR_OUT)
        local conn
        conn = panelTween.Completed:Connect(function()
            if not panelOpen then
                configPanel.Visible = false
                configPanel.Size = UDim2.new(0, PW, 0, PH)
                configPanel.BackgroundTransparency = 0
            end
            safeDisconnect(conn)
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

-- SESSAO: KEYBINDS GLOBAIS
trackConn(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if Config.Keybind and input.KeyCode == Config.Keybind then
        togglePanel()
        return
    end
    if Config.SpamKeybind and input.KeyCode == Config.SpamKeybind then
        if Config.SpamMode == "Hold" then
            setSpam(true)
        else
            setSpam(not spamOn)
        end
    end
end))

trackConn(UIS.InputEnded:Connect(function(input)
    if not Config.SpamKeybind then return end
    if input.KeyCode ~= Config.SpamKeybind then return end
    if Config.SpamMode == "Hold" then setSpam(false) end
end))

-- SESSAO: KILL BUTTON
killBtn.Activated:Connect(function()
    -- 1) salva config final ANTES de qualquer animacao/cleanup
    --    garante que CPS, AutoClash, AutoParry, keybinds, posicoes etc. persistem
    safe(saveConfig, Config)

    -- 2) pede pro funcional encerrar (se ele tiver shutdown)
    if _G.__phantomBackend and type(_G.__phantomBackend.shutdown) == "function" then
        safe(_G.__phantomBackend.shutdown)
    end
    if _G.PhantomStop and type(_G.PhantomStop) == "function" then
        safe(_G.PhantomStop)
    end

    -- 3) desconecta tudo que essa GUI registrou
    if State.conns then
        for _, c in ipairs(State.conns) do safe(function() c:Disconnect() end) end
        State.conns = {}
    end

    -- 4) flipa flags globais
    _G.PhantomManual     = false
    _G.PhantomAutoClash  = false

    -- 5) CRITICO: limpa refs do _G para a proxima execucao nao herdar estado zumbi
    --    (sem isso o funcional acha que a GUI ja carregou e nao recarrega)
    _G.__phantomGUI_loaded = nil
    _G.__phantomGUI_src    = nil
    _G.__phantomBackend    = nil
    _G.PhantomDiag         = nil
    _G.PhantomConfig       = nil
    _G.PhantomState        = nil
    _G.PhantomSaveConfig   = nil

    -- 6) animacao de saida
    twPlay(configPanel, 0.25,
        { BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85) }, EASE_OUT)
    twPlay(floatingButton, 0.25,
        { BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 0, 0, 0) })
    _wait(0.3)

    safe(function() screenGui:Destroy() end)
    print(("[%s v%s] Encerrado."):format(SCRIPT_NAME, SCRIPT_VERSION))
end)

-- ============================================================
-- SESSAO: EFEITOS (DESATIVADOS)
-- ============================================================
-- scanline + particulas removidos: poluiam o visual do painel.

if Config.ClashBallVisible then
    clashBall.Position = UDim2.new(0, clashX, 0, clashY)
end

print(("[%s v%s] carregada | tecla: %s"):format(SCRIPT_NAME, SCRIPT_VERSION, Config.Keybind and Config.Keybind.Name or "?"))