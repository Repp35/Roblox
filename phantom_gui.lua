--[[
    Phantom Ball GUI
    Paleta: Azul / Roxo / Rosa
]]

local SCRIPT_VERSION = "9.1"
local SCRIPT_NAME    = "PhantomBallGUI"

-- SERVICOS
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local Camera       = workspace.CurrentCamera

local _wait  = task.wait
local _spawn = task.spawn

print(("[%s v%s] iniciando..."):format(SCRIPT_NAME, SCRIPT_VERSION))

-- AGUARDA CONFIG EXTERNO (max 3s)
local bootTimeout = 0
while not _G.PhantomConfig and bootTimeout < 3 do
    _wait(0.1)
    bootTimeout = bootTimeout + 0.1
end

local old = CoreGui:FindFirstChild("PhantomUISystem")
if old then old:Destroy() end

-- CONFIG
local Config
if _G.PhantomConfig then
    Config = _G.PhantomConfig
    print(("[%s v%s] Config externo detectado."):format(SCRIPT_NAME, SCRIPT_VERSION))
else
    Config = {
        AutoParry        = false,
        AutoClash        = false,
        CPS              = 25,
        CustomCPS        = false,
        Keybind          = Enum.KeyCode.V,
        SpamKeybind      = Enum.KeyCode.X,
        SpamMode         = "Toggle",
        ClashBallVisible = false,
        BtnX             = nil,
        BtnY             = nil,
        ClashBallX       = 14,
        ClashBallY       = nil,
        MiniX            = nil,
        MiniY            = nil,
        PanelX           = nil,
        PanelY           = nil,
    }
    print(("[%s v%s] Modo standalone."):format(SCRIPT_NAME, SCRIPT_VERSION))
end

local State      = _G.PhantomState or { conns = {} }
local saveConfig = _G.PhantomSaveConfig or function() end
if not State.conns then State.conns = State.connections or {} end
_G.PhantomState  = State
_G.PhantomConfig = Config

-- UTIL
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

-- PALETA
local C = {
    bg         = Color3.fromRGB(8, 8, 22),
    header     = Color3.fromRGB(14, 14, 34),
    card       = Color3.fromRGB(20, 20, 44),
    accent     = Color3.fromRGB(99, 102, 241),
    accentPink = Color3.fromRGB(236, 72, 153),
    green      = Color3.fromRGB(34, 197, 94),
    red        = Color3.fromRGB(239, 68, 68),
    redDark    = Color3.fromRGB(153, 27, 27),
    text       = Color3.fromRGB(240, 240, 255),
    subtext    = Color3.fromRGB(140, 140, 200),
    border     = Color3.fromRGB(55, 55, 100),
    btnBlue    = Color3.fromRGB(45, 55, 130),
    btnDark    = Color3.fromRGB(30, 30, 65),
    toggleOn   = Color3.fromRGB(139, 92, 246),
    toggleOff  = Color3.fromRGB(45, 45, 80),
    hold       = Color3.fromRGB(236, 72, 153),
    inputBg    = Color3.fromRGB(16, 16, 38),
}

local GRAD = {
    Color3.fromRGB(56, 189, 248),
    Color3.fromRGB(139, 92, 246),
    Color3.fromRGB(236, 72, 153),
}

local EASE_OUT, EASE_BACK, EASE_SINE =
    Enum.EasingStyle.Quint, Enum.EasingStyle.Back, Enum.EasingStyle.Sine
local DIR_OUT, DIR_IN, DIR_INOUT =
    Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut

-- HELPERS
local function inst(cls, props, parent)
    local o = Instance.new(cls)
    if props then for k, v in pairs(props) do o[k] = v end end
    if parent then o.Parent = parent end
    return o
end

local function corner(obj, r)
    return inst("UICorner", { CornerRadius = UDim.new(0, r) }, obj)
end

local function stroke(obj, col, th)
    return inst("UIStroke", { Color = col, Thickness = th or 1 }, obj)
end

local function attachFlow(s)
    local g = inst("UIGradient", { Rotation = 0 }, s)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   GRAD[1]),
        ColorSequenceKeypoint.new(0.5, GRAD[2]),
        ColorSequenceKeypoint.new(1,   GRAD[3]),
    })
    return g
end

local function twPlay(obj, t, props, style, dir)
    local tween = TweenService:Create(obj, TweenInfo.new(t, style or EASE_OUT, dir or DIR_OUT), props)
    tween:Play()
    return tween
end

local function safeCancel(t) if t then safe(function() t:Cancel() end) end end

-- DRAG
local function makeDraggable(handle, target, onDragEnd)
    local dragInput, dragOffX, dragOffY = nil, 0, 0
    local state, wasDragged, startX, startY = "Idle", false, 0, 0
    local THRESH_SQ = 100

    trackConn(handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if state ~= "Idle" then return end
        state, wasDragged, dragInput = "Pressed", false, input
        local abs = target.AbsolutePosition
        dragOffX, dragOffY = input.Position.X - abs.X, input.Position.Y - abs.Y
        startX, startY = input.Position.X, input.Position.Y
    end))

    trackConn(UIS.InputChanged:Connect(function(input)
        if state == "Idle" or input ~= dragInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local dx, dy = input.Position.X - startX, input.Position.Y - startY
        if state == "Pressed" and (dx * dx + dy * dy) >= THRESH_SQ then
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

-- GRADIENTE ANIMADO COMPARTILHADO
local flowingGradients = {}
local function registerFlow(obj)
    flowingGradients[#flowingGradients + 1] = attachFlow(obj)
end

local function startFlowingLoop(gui)
    _spawn(function()
        local STEP = 0.005
        while gui.Parent do
            for off = 0, 1, STEP do
                if not gui.Parent then return end
                for i = 1, #flowingGradients do
                    local g = flowingGradients[i]
                    if g and g.Parent then g.Offset = Vector2.new(off, 0) end
                end
                _wait(0.03)
            end
        end
    end)
end

-- SCREEN GUI
local screenGui = inst("ScreenGui", {
    Name           = "PhantomUISystem",
    ResetOnSpawn   = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent         = CoreGui,
})
startFlowingLoop(screenGui)

-- BOTAO FLUTUANTE
local BTN_SIZE = 56
local function btnPos()
    local x, y = Config.BtnX, Config.BtnY
    if type(x) == "number" and type(y) == "number" then
        return UDim2.new(0, x, 0, y)
    end
    return UDim2.new(1, -70, 0.5, -28)
end

local floatingButton = inst("TextButton", {
    Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE),
    Position = btnPos(),
    BackgroundColor3 = C.header,
    BackgroundTransparency = 0.1,
    Text = "P",
    TextColor3 = C.text,
    TextSize = 26,
    Font = Enum.Font.GothamBold,
    Active = true,
    ZIndex = 10,
    Parent = screenGui,
})
corner(floatingButton, 999)
registerFlow(stroke(floatingButton, C.accent, 2))

-- BOLINHA AUTO CLASH
local CLASH_SIZE = 64
local OFFSCREEN_X = -CLASH_SIZE - 40

local clashX = Config.ClashBallX or 14
local clashY = Config.ClashBallY or (viewport().Y / 2 - CLASH_SIZE / 2)
Config.ClashBallVisible = Config.ClashBallVisible or false

if clashX + CLASH_SIZE > viewport().X - BTN_SIZE - 10 then
    clashX, Config.ClashBallX = 14, 14
end

local clashBall = inst("TextButton", {
    Name = "PhantomClashBall",
    Size = UDim2.new(0, CLASH_SIZE, 0, CLASH_SIZE),
    Position = UDim2.new(0, OFFSCREEN_X, 0.5, -CLASH_SIZE / 2),
    BackgroundColor3 = C.red,
    Text = "OFF",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    Active = true,
    ZIndex = 8,
    Parent = screenGui,
})
corner(clashBall, 999)
stroke(clashBall, Color3.new(0, 0, 0), 2)

local clashBallOn = _G.PhantomAutoClash or false

local autoClashTrack, autoClashThumb

local function paintClashBall()
    twPlay(clashBall, 0.28, { BackgroundColor3 = clashBallOn and C.green or C.red }, EASE_SINE, DIR_INOUT)
    clashBall.Text     = clashBallOn and "ON" or "OFF"
    clashBall.TextSize = clashBallOn and 18 or 16
end

local function syncAutoClashToggle()
    if not (autoClashTrack and autoClashThumb) then return end
    local v = clashBallOn
    twPlay(autoClashTrack, 0.22, { BackgroundColor3 = v and C.toggleOn or C.toggleOff }, EASE_SINE, DIR_INOUT)
    twPlay(autoClashThumb,  0.32,
        { Position = v and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) },
        EASE_BACK, DIR_OUT)
end

local function setClashBall(v, silent)
    clashBallOn = v
    _G.PhantomAutoClash = v
    Config.AutoClash    = v
    if silent then return end
    paintClashBall()
    twPlay(clashBall, 0.08, { Size = UDim2.new(0, CLASH_SIZE - 6, 0, CLASH_SIZE - 6) }, EASE_SINE, DIR_OUT)
    task.delay(0.08, function()
        twPlay(clashBall, 0.28, { Size = UDim2.new(0, CLASH_SIZE, 0, CLASH_SIZE) }, EASE_BACK, DIR_OUT)
    end)
    safe(saveConfig, Config)
end

clashBall.Text           = clashBallOn and "ON" or "OFF"
clashBall.TextSize       = clashBallOn and 18 or 16
clashBall.BackgroundColor3 = clashBallOn and C.green or C.red

local function showClashBall(v)
    Config.ClashBallVisible = v
    twPlay(clashBall, (v and 0.22) or 0.18,
        { Position = v and UDim2.new(0, clashX, 0, clashY) or UDim2.new(0, OFFSCREEN_X, 0, clashY) },
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

-- MINI GUI SPAM
local MINI_W, MINI_H = 120, 90
local miniX = Config.MiniX or (viewport().X - MINI_W - 14)
local miniY = Config.MiniY or (viewport().Y / 2 - MINI_H / 2)
local MINI_OFF_X = viewport().X + 30

local miniGui = inst("Frame", {
    Name = "PhantomSpamMini",
    Size = UDim2.new(0, MINI_W, 0, MINI_H),
    BackgroundColor3 = C.header,
    BorderSizePixel = 0,
    ZIndex = 15,
    Parent = screenGui,
})
corner(miniGui, 14)

local miniGlow = inst("Frame", {
    Size = UDim2.new(1, 8, 1, 8),
    Position = UDim2.new(0, -4, 0, -4),
    BackgroundColor3 = C.accent,
    BackgroundTransparency = 0.92,
    BorderSizePixel = 0,
    ZIndex = 14,
    Parent = miniGui,
})
corner(miniGlow, 18)
registerFlow(stroke(miniGui, C.accent, 1.5))

local miniTitleBar = inst("Frame", {
    Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = Color3.fromRGB(20, 20, 46),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    ZIndex = 16,
    Parent = miniGui,
})
corner(miniTitleBar, 14)

inst("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Color3.fromRGB(20, 20, 46),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    ZIndex = 16,
    Parent = miniTitleBar,
})

local miniAccent = inst("Frame", {
    Size = UDim2.new(0.5, 0, 0, 2),
    Position = UDim2.new(0.25, 0, 0, 0),
    BackgroundColor3 = C.accentPink,
    BorderSizePixel = 0,
    ZIndex = 17,
    Parent = miniTitleBar,
})
corner(miniAccent, 1)

inst("TextLabel", {
    Size = UDim2.new(1, -8, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = "Spam",
    TextColor3 = C.subtext,
    TextScaled = true,
    Font = Enum.Font.GothamBold,
    ZIndex = 17,
    Parent = miniTitleBar,
})

local spamBtn = inst("TextButton", {
    Size = UDim2.new(1, -16, 0, 48),
    Position = UDim2.new(0, 8, 0, 32),
    BackgroundColor3 = C.red,
    BorderSizePixel = 0,
    Text = "OFF",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    ZIndex = 16,
    Parent = miniGui,
})
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

miniGui.Position = UDim2.new(0, MINI_OFF_X, 0, miniY)

local function showMini(v, visBtn)
    twPlay(miniGui, (v and 0.22) or 0.18,
        { Position = v and UDim2.new(0, miniX, 0, miniY) or UDim2.new(0, MINI_OFF_X, 0, miniY) },
        v and EASE_BACK or EASE_OUT, DIR_OUT)
    if visBtn then
        visBtn.Text = v and "Mini UI: Visivel" or "Mini UI: Oculto"
        twPlay(visBtn, 0.15, { BackgroundColor3 = v and Color3.fromRGB(0, 130, 65) or C.btnDark })
    end
end

makeDraggable(miniTitleBar, miniGui, function()
    miniX, miniY = miniGui.Position.X.Offset, miniGui.Position.Y.Offset
    Config.MiniX, Config.MiniY = miniX, miniY
    safe(saveConfig, Config)
end)

-- PAINEL PRINCIPAL
local PW, PH = 540, 380
local TITLE_H, PAD, GAP, CARD_GAP = 50, 14, 12, 8
local CONTENT_H = PH - TITLE_H - 60
local COL_W = math.floor((PW - PAD * 2 - GAP) / 2)

local function panelPos()
    local x, y = Config.PanelX, Config.PanelY
    if type(x) == "number" and type(y) == "number" then
        return UDim2.new(0, x, 0, y)
    end
    return UDim2.new(0.5, -PW / 2, 0.5, -PH / 2)
end

local configPanel = inst("Frame", {
    Name = "PhantomPanel",
    Size = UDim2.new(0, PW, 0, PH),
    Position = panelPos(),
    BackgroundColor3 = C.bg,
    BackgroundTransparency = 0.08,
    Visible = false,
    ZIndex = 5,
    ClipsDescendants = true,
    Parent = screenGui,
})
corner(configPanel, 16)
stroke(configPanel, C.accent, 1.5)

-- PARTICULAS DE FUNDO
local particleLayer = inst("Frame", {
    Name = "ParticleLayer",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 4,
    ClipsDescendants = true,
    Parent = configPanel,
})

local PARTICLE_COLORS = {
    Color3.fromRGB(85, 90, 140),
    Color3.fromRGB(110, 95, 150),
    Color3.fromRGB(150, 95, 130),
    Color3.fromRGB(95, 130, 165),
}

local function spawnParticle()
    local isFar = math.random() < 0.6
    local size        = isFar and math.random(2, 3) or math.random(4, 6)
    local startTrans  = isFar and 0.5 or 0.2
    local color       = PARTICLE_COLORS[math.random(1, #PARTICLE_COLORS)]

    local dot = inst("Frame", {
        Size = UDim2.new(0, size, 0, size),
        Position = UDim2.new(math.random(), 0, 1, 0),
        BackgroundColor3 = color,
        BackgroundTransparency = startTrans,
        ZIndex = 4,
        Parent = particleLayer,
    })
    corner(dot, 999)

    local dur  = isFar and math.random(5, 9) or math.random(3, 5)
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

-- TITLE BAR
local titleBar = inst("Frame", {
    Size = UDim2.new(1, 0, 0, TITLE_H),
    BackgroundColor3 = C.header,
    ZIndex = 6,
    Parent = configPanel,
})
corner(titleBar, 16)

inst("TextLabel", {
    Size = UDim2.new(1, -120, 1, 0),
    BackgroundTransparency = 1,
    Text = ("Phantom - Config v%s"):format(SCRIPT_VERSION),
    TextColor3 = C.text,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 7,
    Parent = titleBar,
})

local badge = inst("TextLabel", {
    Size = UDim2.new(0, 56, 0, 18),
    Position = UDim2.new(0, 10, 0.5, -9),
    BackgroundColor3 = C.accent,
    BackgroundTransparency = 0.25,
    Text = ("v%s"):format(SCRIPT_VERSION),
    TextColor3 = C.text,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    ZIndex = 7,
    Parent = titleBar,
})
corner(badge, 6)

local closeButton = inst("TextButton", {
    Size = UDim2.new(0, 30, 0, 30),
    Position = UDim2.new(1, -42, 0.5, -15),
    BackgroundColor3 = C.red,
    BackgroundTransparency = 0.3,
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    ZIndex = 7,
    Parent = titleBar,
})
corner(closeButton, 8)
closeButton.MouseEnter:Connect(function() twPlay(closeButton, 0.12, { BackgroundTransparency = 0 }) end)
closeButton.MouseLeave:Connect(function() twPlay(closeButton, 0.12, { BackgroundTransparency = 0.3 }) end)

-- COLUNAS
local colLeft = inst("Frame", {
    Size = UDim2.new(0, COL_W, 0, CONTENT_H),
    Position = UDim2.new(0, PAD, 0, TITLE_H + 12),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = configPanel,
})
local colRight = inst("Frame", {
    Size = UDim2.new(0, COL_W, 0, CONTENT_H),
    Position = UDim2.new(0, PAD + COL_W + GAP, 0, TITLE_H + 12),
    BackgroundTransparency = 1,
    ZIndex = 6,
    Parent = configPanel,
})

-- KILL BUTTON
local killBtn = inst("TextButton", {
    Size = UDim2.new(0, 124, 0, 26),
    Position = UDim2.new(0.5, -62, 1, -52),
    BackgroundColor3 = C.redDark,
    BackgroundTransparency = 0.15,
    Text = "Fechar Script",
    TextColor3 = Color3.fromRGB(255, 200, 200),
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    ZIndex = 7,
    Parent = configPanel,
})
corner(killBtn, 6)

if not UIS.TouchEnabled then
    killBtn.MouseEnter:Connect(function()
        twPlay(killBtn, 0.12, { BackgroundColor3 = Color3.fromRGB(170, 35, 35) })
    end)
    killBtn.MouseLeave:Connect(function()
        twPlay(killBtn, 0.12, { BackgroundColor3 = C.redDark })
    end)
end

-- COMPONENTES REUTILIZAVEIS
local function cardFrame(yPos, h, parent)
    local f = inst("Frame", {
        Size = UDim2.new(1, 0, 0, h),
        Position = UDim2.new(0, 0, 0, yPos),
        BackgroundColor3 = C.card,
        BackgroundTransparency = 0.1,
        ZIndex = 6,
        Parent = parent,
    })
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
    inst("TextLabel", {
        Size = UDim2.new(1, -10, 0, 16),
        Position = UDim2.new(0, 10, 0, 5),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = C.accent,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = parent,
    })
end

local function makeBtn(text, x, y, w, h, parent, bg)
    local b = inst("TextButton", {
        Size = UDim2.new(0, w, 0, h),
        Position = UDim2.new(0, x, 0, y),
        BackgroundColor3 = bg or C.btnBlue,
        BackgroundTransparency = 0.1,
        Text = text,
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        ZIndex = 7,
        Parent = parent,
    })
    corner(b, 8)
    return b
end

local function makeToggle(trackParent, initial)
    local track = inst("Frame", {
        Size = UDim2.new(0, 48, 0, 26),
        Position = UDim2.new(1, -62, 0.5, -13),
        BackgroundColor3 = initial and C.toggleOn or C.toggleOff,
        BackgroundTransparency = 0.1,
        ZIndex = 7,
        Parent = trackParent,
    })
    corner(track, 999)
    local thumb = inst("Frame", {
        Size = UDim2.new(0, 20, 0, 20),
        Position = initial and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 8,
        Parent = track,
    })
    corner(thumb, 999)

    local function setVisual(v)
        twPlay(track, 0.22, { BackgroundColor3 = v and C.toggleOn or C.toggleOff }, EASE_SINE, DIR_INOUT)
        twPlay(thumb, 0.32,
            { Position = v and UDim2.new(0, 25, 0.5, -10) or UDim2.new(0, 3, 0.5, -10) },
            EASE_BACK, DIR_OUT)
        twPlay(thumb, 0.08, { Size = UDim2.new(0, 24, 0, 24) }, EASE_SINE, DIR_OUT)
        task.delay(0.08, function()
            twPlay(thumb, 0.18, { Size = UDim2.new(0, 20, 0, 20) }, EASE_BACK, DIR_OUT)
        end)
    end

    return track, thumb, setVisual
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

local function createToggleCard(labelText, configKey, yPos, parent, onAfter)
    local f = cardFrame(yPos, 52, parent)
    inst("TextLabel", {
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = C.text,
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = f,
    })

    local initial = configKey and Config[configKey] or false
    local state = initial
    local _, _, setVisual = makeToggle(f, initial)

    inst("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 9,
        Parent = f,
    }).Activated:Connect(function()
        state = not state
        if configKey then
            Config[configKey] = state
            safe(saveConfig, Config)
        end
        setVisual(state)
        if onAfter then onAfter(state) end
    end)

    return yPos + 52 + CARD_GAP
end

local function createCPSSelector(yPos, parent)
    local f = cardFrame(yPos, 68, parent)
    cardLabel("CPS Spam", f)

    inst("TextLabel", {
        Size = UDim2.new(0, 36, 0, 30),
        Position = UDim2.new(0, 14, 0, 28),
        BackgroundTransparency = 1,
        Text = "CPS:",
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = f,
    })

    local defBtn = makeBtn("Padrao", 52, 28, 68, 30, f, C.btnBlue)
    defBtn.TextSize = 11

    local inputBox = inst("TextBox", {
        Size = UDim2.new(0, 72, 0, 30),
        Position = UDim2.new(1, -82, 0, 28),
        BackgroundColor3 = C.inputBg,
        BackgroundTransparency = 0.1,
        Text = tostring(Config.CPS or 25),
        PlaceholderText = "CPS",
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        ZIndex = 7,
        Parent = f,
    })
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
            if v ~= Config.CPS then Config.CPS, Config.CustomCPS = v, true end
        else
            inputBox.Text = tostring(Config.CPS or 25)
        end
        safe(saveConfig, Config)
    end)

    return yPos + 68 + CARD_GAP
end

local function createKeybindSelector(yPos, parent)
    local f = cardFrame(yPos, 52, parent)
    inst("TextLabel", {
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = "Tecla de Atalho",
        TextColor3 = C.text,
        TextSize = 14,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = f,
    })

    local kbBtn = makeBtn(Config.Keybind and Config.Keybind.Name or "V", 0, 0, 88, 30, f, C.btnBlue)
    kbBtn.Position = UDim2.new(1, -100, 0.5, -15)
    bindKeyCapture(kbBtn, function(keyCode)
        Config.Keybind = keyCode
        kbBtn.Text = keyCode.Name
        twPlay(kbBtn, 0.18, { BackgroundColor3 = C.btnBlue }, EASE_BACK)
        safe(saveConfig, Config)
    end)
    return yPos + 52 + CARD_GAP
end

local function createSpamCard(yPos, parent)
    local f = cardFrame(yPos, 118, parent)
    cardLabel("Manual Spam", f)

    local visBtn = makeBtn("Mini UI: Oculto", 8, 24, COL_W - 16, 30, f, C.btnDark)
    visBtn.TextSize = 11
    visBtn.Activated:Connect(function()
        showMini(miniGui.Position.X.Offset > viewport().X - 50, visBtn)
    end)

    local halfW = math.floor((COL_W - 32) / 2)
    local kbBtn = makeBtn(Config.SpamKeybind and Config.SpamKeybind.Name or "X", 8, 64, halfW, 32, f, C.btnBlue)
    bindKeyCapture(kbBtn, function(keyCode)
        Config.SpamKeybind = keyCode
        kbBtn.Text = keyCode.Name
        twPlay(kbBtn, 0.18, { BackgroundColor3 = C.btnBlue }, EASE_BACK)
        safe(saveConfig, Config)
    end)

    local function modeColor(mode) return mode == "Hold" and C.hold or C.toggleOn end
    local modeBtn = makeBtn(Config.SpamMode or "Toggle", 8 + halfW + 14, 64, halfW, 32, f, modeColor(Config.SpamMode))
    modeBtn.Activated:Connect(function()
        Config.SpamMode = (Config.SpamMode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = Config.SpamMode
        twPlay(modeBtn, 0.18, { BackgroundColor3 = modeColor(Config.SpamMode) }, EASE_BACK)
        if Config.SpamMode == "Toggle" and _G.PhantomManual then setSpam(false) end
        safe(saveConfig, Config)
    end)

    return yPos + 118 + CARD_GAP
end

-- AUTO CLASH: cria toggle proprio e expoe track/thumb
do
    local yL = 4
    local _track, _thumb
    local function buildAutoClash(y)
        local f = cardFrame(y, 52, colLeft)
        inst("TextLabel", {
            Size = UDim2.new(0.55, 0, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = "Auto Clash",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7,
            Parent = f,
        })
        local track, thumb, setVisual = makeToggle(f, Config.AutoClash)
        _track, _thumb = track, thumb
        inst("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 9,
            Parent = f,
        }).Activated:Connect(function()
            Config.AutoClash = not Config.AutoClash
            setVisual(Config.AutoClash)
            setClashBall(Config.AutoClash, true)
            paintClashBall()
            safe(saveConfig, Config)
        end)
        return y + 52 + CARD_GAP
    end
    yL = createToggleCard("Auto Parry", "AutoParry", yL, colLeft)
    yL = buildAutoClash(yL)
    yL = createToggleCard("Mini Clash UI", "ClashBallVisible", yL, colLeft, function(v)
        if v then
            showClashBall(true)
        else
            if clashBallOn then
                setClashBall(false)
                syncAutoClashToggle()
            end
            showClashBall(false)
        end
    end)
    autoClashTrack, autoClashThumb = _track, _thumb
end

local yR = 4
yR = createCPSSelector(yR, colRight)
yR = createKeybindSelector(yR, colRight)
yR = createSpamCard(yR, colRight)

-- DRAG DO PAINEL / BOTAO
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

-- ABRIR / FECHAR PAINEL
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

-- KEYBINDS GLOBAIS
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
    if not Config.SpamKeybind or input.KeyCode ~= Config.SpamKeybind then return end
    if Config.SpamMode == "Hold" then setSpam(false) end
end))

-- KILL BUTTON
killBtn.Activated:Connect(function()
    safe(saveConfig, Config)

    if _G.__phantomBackend and type(_G.__phantomBackend.shutdown) == "function" then
        safe(_G.__phantomBackend.shutdown)
    end
    if _G.PhantomStop and type(_G.PhantomStop) == "function" then
        safe(_G.PhantomStop)
    end

    if State.conns then
        for _, c in ipairs(State.conns) do safe(function() c:Disconnect() end) end
        State.conns = {}
    end

    _G.PhantomManual    = false
    _G.PhantomAutoClash = false

    _G.__phantomGUI_loaded = nil
    _G.__phantomGUI_src    = nil
    _G.__phantomBackend    = nil
    _G.PhantomDiag         = nil
    _G.PhantomConfig       = nil
    _G.PhantomState        = nil
    _G.PhantomSaveConfig   = nil

    twPlay(configPanel, 0.25,
        { BackgroundTransparency = 1, Size = UDim2.new(0, PW * 0.85, 0, PH * 0.85) }, EASE_OUT)
    twPlay(floatingButton, 0.25,
        { BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.new(0, 0, 0, 0) })
    _wait(0.3)

    safe(function() screenGui:Destroy() end)
    print(("[%s v%s] Encerrado."):format(SCRIPT_NAME, SCRIPT_VERSION))
end)

-- ESTADO INICIAL DO CLASH BALL
if Config.ClashBallVisible then
    clashBall.Position = UDim2.new(0, clashX, 0, clashY)
end

print(("[%s v%s] carregada | tecla: %s"):format(
    SCRIPT_NAME, SCRIPT_VERSION, Config.Keybind and Config.Keybind.Name or "?"))
