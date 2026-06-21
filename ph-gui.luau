-- ================================================
--   PB | GUI
-- ================================================

local Players = game:GetService("Players")
local WS      = game:GetService("Workspace")
local UIS     = game:GetService("UserInputService")
local TS      = game:GetService("TweenService")
local CG      = game:GetService("CoreGui")
local LP      = Players.LocalPlayer

-- helpers
local function corner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r)
    return c
end
local function stroke(parent, color, thick)
    local s = Instance.new("UIStroke", parent)
    s.Color = color
    s.Thickness = thick
    return s
end
local function tween(obj, t, props)
    pcall(function() TS:Create(obj, t, props):Play() end)
end
local TI  = TweenInfo.new
local RGB = Color3.fromRGB

-- ============================================================
--   CONFIG (espelho da do backend — chaves idênticas)
-- ============================================================
local Config = {
    AutoParry   = true,
    AutoClash   = true,
    CPS         = 25,
    CustomCPS   = false,
    Keybind     = Enum.KeyCode.F9,
    SpamKeybind = Enum.KeyCode.F,
    SpamMode    = "Toggle",
}

-- Estado local-only da GUI
local ManualSpam = false
local MiniSpam   = false

-- expõe pro backend
_G.PhantomConfig    = Config
_G.PhantomManual    = ManualSpam
_G.PhantomAutoClash = true
_G.__phantomGUI_loaded = false

local function pushConfig()
    _G.PhantomConfig    = Config
    _G.PhantomManual    = ManualSpam
    _G.PhantomAutoClash = (Config.AutoClash == true)
end

-- root
local gui = Instance.new("ScreenGui")
gui.Name = "PhantomGUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = CG
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

-- sizes
local OPEN_W, OPEN_H, BUBBLE = 300, 340, 56

-- main frame
local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.fromOffset(OPEN_W, OPEN_H)
main.Position = UDim2.fromScale(.5, .5) - UDim2.fromOffset(OPEN_W/2, OPEN_H/2)
main.BackgroundColor3 = RGB(12, 12, 18)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
local mainCorner = corner(main, 12)
local mainStroke = stroke(main, RGB(190, 25, 25), 1.5)

-- bubble icon
local bubbleIcon = Instance.new("TextLabel")
bubbleIcon.Size = UDim2.new(1, 0, 1, 0)
bubbleIcon.BackgroundTransparency = 1
bubbleIcon.Text = "P"
bubbleIcon.TextColor3 = Color3.new(1,1,1)
bubbleIcon.TextScaled = true
bubbleIcon.Font = Enum.Font.GothamBold
bubbleIcon.Visible = false
bubbleIcon.Parent = main

-- header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = RGB(190, 25, 25)
header.BorderSizePixel = 0
header.Active = true
header.Parent = main
corner(header, 12)

local headerFill = Instance.new("Frame")
headerFill.Size = UDim2.new(1, 0, 0, 12)
headerFill.Position = UDim2.new(0, 0, 1, -12)
headerFill.BackgroundColor3 = RGB(190, 25, 25)
headerFill.BorderSizePixel = 0
headerFill.Parent = header

local titleIcon = Instance.new("TextLabel")
titleIcon.Size = UDim2.fromOffset(30, 48)
titleIcon.Position = UDim2.fromOffset(10, 0)
titleIcon.BackgroundTransparency = 1
titleIcon.Text = "⚡"
titleIcon.TextScaled = true
titleIcon.Font = Enum.Font.GothamBold
titleIcon.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.fromOffset(44, 0)
title.BackgroundTransparency = 1
title.Text = "PHANTOM  v3.5"
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -34, .5, -13)
closeBtn.BackgroundColor3 = Color3.new(0,0,0)
closeBtn.BackgroundTransparency = .4
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 5
closeBtn.Parent = header
corner(closeBtn, 6)

-- content
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, -48)
content.Position = UDim2.fromOffset(0, 48)
content.BackgroundTransparency = 1
content.Parent = main

local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 8)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent = content

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 10)
pad.Parent = content

-- ==================== open / close ====================
local isOpen, lastX, lastY = true, 0, 0

-- mantem o frame dentro da viewport (corrige resize / troca de camera)
local function clampToViewport(x, y, w, h)
    local vp = WS.CurrentCamera and WS.CurrentCamera.ViewportSize
    if not vp or vp.X <= 0 or vp.Y <= 0 then
        return UDim2.fromOffset(0, 0)
    end
    local maxX = math.max(0, vp.X - w)
    local maxY = math.max(0, vp.Y - h)
    return UDim2.fromOffset(math.clamp(x, 0, maxX), math.clamp(y, 0, maxY))
end

local function currentSize()
    -- enquanto aberto usa o tamanho aberto, senao usa a bolha
    return isOpen and OPEN_W or BUBBLE, isOpen and OPEN_H or BUBBLE
end

local function keepInside()
    -- roda em qualquer momento pra puxar o frame de volta se a viewport encolheu
    local w, h = currentSize()
    local p = main.Position
    local x, y = p.X.Offset, p.Y.Offset
    local clamped = clampToViewport(x, y, w, h)
    if clamped ~= p then
        main.Position = clamped
        lastX, lastY = clamped.X.Offset, clamped.Y.Offset
    end
end

local function openMain()
    if isOpen then return end
    isOpen = true
    local w, h = OPEN_W, OPEN_H
    -- usa o tamanho-alvo pro clamp pra evitar teleport pro canto
    local pos = clampToViewport(lastX, lastY, w, h)
    main.Position = pos
    lastX, lastY = pos.X.Offset, pos.Y.Offset
    header.Visible = true
    content.Visible = true
    closeBtn.Visible = true
    bubbleIcon.Visible = false
    tween(main,  TI(.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(OPEN_W, OPEN_H), BackgroundColor3 = RGB(12, 12, 18)})
    tween(mainCorner, TI(.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CornerRadius = UDim.new(0, 12)})
    tween(mainStroke, TI(.42, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out), {Thickness = 1.5})
end

local function closeMain()
    if not isOpen then return end
    isOpen = false
    -- snapshot da posicao real (ja clampada) pra reabrir no mesmo lugar
    lastX, lastY = main.Position.X.Offset, main.Position.Y.Offset
    header.Visible = false
    content.Visible = false
    closeBtn.Visible = false
    bubbleIcon.Visible = true
    tween(main,  TI(.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.fromOffset(BUBBLE, BUBBLE), BackgroundColor3 = RGB(28, 12, 12)})
    tween(mainCorner, TI(.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {CornerRadius = UDim.new(1, 0)})
    tween(mainStroke, TI(.38, Enum.EasingStyle.Sine,  Enum.EasingDirection.In), {Thickness = 2})
end

-- monitora resize da viewport / troca de camera e corrige na hora
WS.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    task.defer(keepInside)
end)

closeBtn.MouseButton1Click:Connect(function()
    if isOpen then closeMain() end
end)

-- ==================== drag ====================
do
    local dragging, dragStart, frameStart, dragMoved = false, nil, nil, false
    local function start(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging, dragMoved = true, false
        dragStart = input.Position
        frameStart = Vector2.new(main.Position.X.Offset, main.Position.Y.Offset)
    end
    local function move(input)
        if not dragging or not dragStart then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragStart
        if d.Magnitude > 4 then dragMoved = true end
        local w, h = currentSize()
        main.Position = clampToViewport(frameStart.X + d.X, frameStart.Y + d.Y, w, h)
    end
    local function stop(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if not isOpen and not dragMoved then openMain() end
            dragging, dragStart = false, nil
        end
    end
    header.InputBegan:Connect(start)
    main.InputBegan:Connect(function(i) if not isOpen then start(i) end end)
    UIS.InputChanged:Connect(move)
    UIS.InputEnded:Connect(stop)
end

-- ==================== toggle builder ====================
local ON, OFF = RGB(0, 185, 75), RGB(55, 55, 68)
local function addToggle(name, default, order, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = RGB(22, 22, 30)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = content
    corner(row, 8); stroke(row, RGB(45, 45, 60), 1)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -110, 1, 0)
    lbl.Position = UDim2.fromOffset(14, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = RGB(210, 210, 225)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(80, 30)
    btn.Position = UDim2.new(1, -92, .5, -15)
    btn.BackgroundColor3 = default and ON or OFF
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = row
    corner(btn, 6)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        tween(btn, TI(.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(70, 26)})
        task.delay(.10, function()
            if btn.Parent then
                tween(btn, TI(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(80, 30)})
            end
        end)
        tween(btn, TI(.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = state and ON or OFF})
        btn.Text = state and "ON" or "OFF"
        cb(state)
        pushConfig()
    end)
end

addToggle("Auto Parry",  Config.AutoParry, 1, function(v) Config.AutoParry = v end)
addToggle("Manual Spam", ManualSpam,     2, function(v) ManualSpam     = v end)
addToggle("Mini Spam",   MiniSpam,       3, function(v) MiniSpam       = v end)
addToggle("Auto Clash",  Config.AutoClash, 4, function(v) Config.AutoClash = v end)

-- ==================== CPS field ====================
local cpsRow = Instance.new("Frame")
cpsRow.Size = UDim2.new(1, 0, 0, 44)
cpsRow.BackgroundColor3 = RGB(22, 22, 30)
cpsRow.BorderSizePixel = 0
cpsRow.LayoutOrder = 6
cpsRow.Parent = content
corner(cpsRow, 8); stroke(cpsRow, RGB(45, 45, 60), 1)

local cpsLbl = Instance.new("TextLabel")
cpsLbl.Size = UDim2.new(.5, -14, 1, 0)
cpsLbl.Position = UDim2.fromOffset(14, 0)
cpsLbl.BackgroundTransparency = 1
cpsLbl.Text = "CPS (Spam)"
cpsLbl.TextColor3 = RGB(210, 210, 225)
cpsLbl.TextScaled = true
cpsLbl.Font = Enum.Font.Gotham
cpsLbl.TextXAlignment = Enum.TextXAlignment.Left
cpsLbl.Parent = cpsRow

local cpsBox = Instance.new("TextBox")
cpsBox.Size = UDim2.fromOffset(80, 30)
cpsBox.Position = UDim2.new(1, -92, .5, -15)
cpsBox.BackgroundColor3 = RGB(55, 55, 68)
cpsBox.BorderSizePixel = 0
cpsBox.Text = tostring(Config.CPS)
cpsBox.TextColor3 = Color3.new(1,1,1)
cpsBox.TextScaled = true
cpsBox.Font = Enum.Font.GothamBold
cpsBox.ClearTextOnFocus = false
cpsBox.Parent = cpsRow
corner(cpsBox, 6)

cpsBox.FocusLost:Connect(function()
    local n = tonumber(cpsBox.Text)
    local ok = n and n >= 1 and n <= 2000
    if ok then
        Config.CPS = math.floor(n)
        Config.CustomCPS = true
    end
    cpsBox.Text = tostring(Config.CPS)
    local flash = ok and RGB(0, 185, 75) or RGB(185, 50, 50)
    tween(cpsBox, TI(.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = flash})
    task.delay(.55, function()
        if cpsBox.Parent then
            tween(cpsBox, TI(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundColor3 = RGB(55, 55, 68)})
        end
    end)
    pushConfig()
end)

-- status label
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 24)
status.BackgroundTransparency = 1
status.TextColor3 = RGB(130, 130, 150)
status.Text = "Aguardando bola..."
status.TextScaled = true
status.Font = Enum.Font.Gotham
status.LayoutOrder = 7
status.Parent = content

-- ==================== hotkeys ====================
UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.F8 then
        if isOpen then closeMain() else openMain() end
    elseif i.KeyCode == Config.SpamKeybind then
        ManualSpam = not ManualSpam
        _G.PhantomManual = ManualSpam
    end
end)

-- ==================== mini spam gui (delta-style) ====================
task.spawn(function()
    local spamOn = ManualSpam
    local toggleBtn

    local function paint()
        if not (toggleBtn and toggleBtn.Parent) then return end
        local color = spamOn and RGB(50, 220, 50) or RGB(220, 50, 50)
        tween(toggleBtn, TI(.10, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out), {Size = UDim2.new(.80, 0, 0, 46)})
        task.delay(.10, function()
            if toggleBtn and toggleBtn.Parent then
                tween(toggleBtn, TI(.22, Enum.EasingStyle.Back,  Enum.EasingDirection.Out), {Size = UDim2.new(.85, 0, 0, 52)})
            end
        end)
        tween(toggleBtn, TI(.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = color})
        tween(toggleBtn, TI(.10, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out), {TextTransparency = 1})
        task.delay(.10, function()
            if not (toggleBtn and toggleBtn.Parent) then return end
            toggleBtn.Text = spamOn and "ON" or "OFF"
            tween(toggleBtn, TI(.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
        end)
    end

    local function setSpam(v)
        if spamOn == v then return end
        spamOn = v
        ManualSpam = v
        _G.PhantomManual = v
        pushConfig()
        paint()
    end

    UIS.InputBegan:Connect(function(i, g)
        if g then return end
        if i.KeyCode == Enum.KeyCode.X or i.KeyCode == Enum.KeyCode.F then
            setSpam(not spamOn)
        end
    end)

    local old = CG:FindFirstChild("PhantomSpamToggleGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "PhantomSpamToggleGui"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 11
    sg.Enabled = true
    sg.Parent = CG

    local mf = Instance.new("Frame")
    mf.Size = UDim2.fromOffset(120, 95)
    mf.Position = UDim2.new(1, -130, .5, -47)
    mf.BackgroundColor3 = RGB(18, 18, 30)
    mf.BorderSizePixel = 0
    mf.BackgroundTransparency = 1
    mf.Visible = MiniSpam
    mf.Parent = sg
    corner(mf, 14)

    local restPos = mf.Position
    local s = stroke(mf, RGB(190, 25, 25), 1.5)
    s.Transparency = 1

    local tb = Instance.new("Frame")
    tb.Size = UDim2.new(1, 0, 0, 24)
    tb.BackgroundColor3 = RGB(190, 25, 25)
    tb.BorderSizePixel = 0
    tb.Parent = mf
    corner(tb, 14)

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -6, 1, 0)
    tl.Position = UDim2.fromOffset(6, 0)
    tl.BackgroundTransparency = 1
    tl.Text = "PHANTOM"
    tl.TextColor3 = Color3.new(1,1,1)
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.Parent = tb

    toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(.85, 0, 0, 52)
    toggleBtn.Position = UDim2.new(.075, 0, 0, 30)
    toggleBtn.BackgroundColor3 = RGB(220, 50, 50)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "OFF"
    toggleBtn.TextColor3 = Color3.new(1,1,1)
    toggleBtn.TextScaled = true
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Parent = mf
    corner(toggleBtn, 10)

    -- drag
    local dragging, dragStart, startPos = false, nil, nil
    local function update(input)
        if not (dragStart and startPos) then return end
        local d = input.Position - dragStart
        local vp = WS.CurrentCamera.ViewportSize
        local sz = mf.AbsoluteSize
        mf.Position = UDim2.fromOffset(
            math.clamp(startPos.X.Offset + d.X, 0, math.max(0, vp.X - sz.X)),
            math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, vp.Y - sz.Y))
        )
    end
    mf.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging, dragStart, startPos = true, i.Position, mf.Position
    end)
    mf.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then update(i) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = false, nil, nil
        end
    end)

    toggleBtn.Activated:Connect(function() setSpam(not spamOn) end)
    paint()

    pcall(function()
        tween(mf, TI(.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        tween(s,  TI(.30, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out), {Transparency = 0})
        tween(tb, TI(.30, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out), {BackgroundTransparency = 0})
        tween(tl, TI(.30, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out), {TextTransparency = 0})
        mf.Position = UDim2.fromOffset(restPos.X.Offset - 60, restPos.Y.Offset - 30)
        tween(mf, TI(.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = restPos})
        task.delay(.18, function()
            if not (toggleBtn and toggleBtn.Parent) then return end
            toggleBtn.BackgroundTransparency = 1
            toggleBtn.TextTransparency = 1
            tween(toggleBtn, TI(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
            tween(toggleBtn, TI(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
        end)
    end)

    -- reage ao MiniSpam
    task.spawn(function()
        local last = MiniSpam
        while mf and mf.Parent do
            local cur = MiniSpam
            if cur ~= last then
                if cur then
                    mf.Visible = true
                    tween(mf, TI(.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
                    tween(s,  TI(.25, Enum.EasingStyle.Sine,  Enum.EasingDirection.Out), {Transparency = 0})
                    tween(mf, TI(.40, Enum.EasingStyle.Back,  Enum.EasingDirection.Out), {Position = restPos})
                else
                    tween(mf, TI(.30, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                        Position = UDim2.new(restPos.X.Scale, restPos.X.Offset + 40, restPos.Y.Scale, restPos.Y.Offset),
                        BackgroundTransparency = 1,
                    })
                    tween(s, TI(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 1})
                    task.delay(.32, function()
                        if mf and mf.Parent and not MiniSpam then
                            mf.Position = restPos
                            mf.Visible = false
                        end
                    end)
                end
                last = cur
            end
            task.wait(.1)
        end
    end)
end)

-- empurra config inicial
pushConfig()

-- exports
return {
    GetConfig      = function() return Config end,
    GetStatusLabel = function() return status end,
    GetMainFrame   = function() return main end,
    SetStatus      = function(text, color)
        if status and status.Parent then
            status.Text = text
            if color then status.TextColor3 = color end
        end
    end,
    Open  = openMain,
    Close = closeMain,
    Push  = pushConfig,
}
