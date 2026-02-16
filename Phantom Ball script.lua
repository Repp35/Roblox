-- Blade Ball Auto Parry + Spam (PC Version)
-- HOLD F to spam parry (releases when you let go)
-- Auto parry always active with cooldown protection

if getgenv().__na_aex then 
    return 
end
getgenv().__na_aex = true

if game.GameId ~= 4538598064 then 
    return 
end

local Plrs = game:GetService("Players")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local RSrv = game:GetService("ReplicatedStorage")
local WS = workspace
local UIS = game:GetService("UserInputService")

local Net = require(RSrv.TS.Network.Network).Network
local Def = require(RSrv.TS.Abilities.DeflectAbility).DeflectAbility
local PNotif = RSrv:WaitForChild("PromptNotification")

-- Hook para sempre permitir parry
hookfunction(Def.IsAvailable, function()
    return true
end)

-- Hook para corrigir router IDs
local oSend
oSend = hookfunction(Net.CSendEvent, function(self, router, evt, ...)
    if router == 46848415795802784000000000000000000000000000000000000000000000000000000000000 then
        return oSend(self, router, 29338138590583890000000000000000000000000000000000000000000000000000000000000, ...)
    end
    return oSend(self, router, evt, ...)
end)

local function sendParry()
    if not Net then return end
    Net:CSendEvent(46848415795802784000000000000000000000000000000000000000000000000000000000000, 6846744283873508500000000000000000000000000000000000000000000000000000000000)
end

-- ================== GAME INFO ==================
local gi, br

do
    local ok, mod = pcall(function()
        return require(RSrv:WaitForChild("TS"):WaitForChild("GameInfo"))
    end)
    if ok and mod and mod.GameInfo then
        gi = mod.GameInfo
    end
end

do
    local ok, mod = pcall(function()
        return require(RSrv:WaitForChild("TS"):WaitForChild("BallReplicator"):WaitForChild("BallReplicator"))
    end)
    if ok and mod and mod.BallReplicator then
        br = mod.BallReplicator
    end
end

local lp = Plrs.LocalPlayer

local function getBall()
    if gi and gi.BallModel and gi.BallModel.Parent then
        return gi.BallModel
    end
    return WS:FindFirstChild("GameBall", true) or WS:FindFirstChild("GameBall")
end

local function tgtOn()
    local ch = lp.Character
    if ch and ch:FindFirstChild("Highlight") then
        return true
    end
    local t = WS:GetAttribute("GameBallTarget")
    if t == lp.UserId then
        return true
    end
    if br and br.syncData and br.syncData.HighlightTargetPlayerID == lp.UserId then
        return true
    end
    return false
end

-- ================== SPAM MODE (HOLD F) ==================
local spamOn = false
local spamConn

local function setSpam(v)
    if spamOn == v then
        return
    end
    spamOn = v
    if spamOn then
        if not spamConn and Net then
            spamConn = RS.Stepped:Connect(function()
                sendParry()
            end)
        end
    elseif spamConn then
        spamConn:Disconnect()
        spamConn = nil
    end
end

-- HOLD F para ativar spam, soltar F para desativar
UIS.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F then
        setSpam(true)
    end
end)

UIS.InputEnded:Connect(function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.F then
        setSpam(false)
    end
end)

-- ================== NOTIFICATION ==================
task.spawn(function()
    local playerGui = lp:WaitForChild("PlayerGui")
    
    -- Notificação in-game
    PNotif:Fire("Auto Parry ativado! Segure F para spam 🎯", true)
    
    -- Notificação visual customizada
    local notifGui = Instance.new("ScreenGui")
    notifGui.Name = "ParryNotification"
    notifGui.ResetOnSpawn = false
    notifGui.Parent = playerGui

    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 350, 0, 80)
    notification.Position = UDim2.new(0.5, -175, 0, -90)
    notification.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    notification.BorderSizePixel = 0
    notification.Parent = notifGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = notification

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 200, 120)
    stroke.Thickness = 2
    stroke.Parent = notification

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -20, 0, 30)
    titleText.Position = UDim2.new(0, 10, 0, 8)
    titleText.BackgroundTransparency = 1
    titleText.Text = "⚡ Auto Parry Carregado"
    titleText.TextColor3 = Color3.fromRGB(80, 200, 120)
    titleText.TextSize = 20
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = notification

    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -20, 0, 35)
    infoText.Position = UDim2.new(0, 10, 0, 38)
    infoText.BackgroundTransparency = 1
    infoText.Text = "🎮 Segure F para ativar spam de parry\n✨ Auto parry sempre ativo"
    infoText.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoText.TextSize = 14
    infoText.Font = Enum.Font.Gotham
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.Parent = notification

    -- Animação de entrada
    local slideIn = TS:Create(notification, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
        {Position = UDim2.new(0.5, -175, 0, 20)}
    )
    slideIn:Play()

    -- Esperar 5 segundos e sair
    task.wait(5)
    
    local slideOut = TS:Create(notification, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), 
        {Position = UDim2.new(0.5, -175, 0, -90)}
    )
    slideOut:Play()
    slideOut.Completed:Connect(function()
        notifGui:Destroy()
    end)
end)

-- ================== AUTO PARRY ==================
local hb

local function bind(ch)
    if hb then
        hb:Disconnect()
        hb = nil
    end

    local hrp = ch:WaitForChild("HumanoidRootPart", 9000000000)
    local lastPos, lastT = nil, nil
    local vel = Vector3.zero
    local tau = 0.05
    local minR, maxR = 9, 90
    local cd = 0.3  -- COOLDOWN DE 0.3s
    local lastFire = 0

    hb = RS.Heartbeat:Connect(function(dt)
        -- Se spam mode (F pressionado) estiver ativo, não usa auto parry
        if spamOn then
            return
        end

        if not (ch and ch.Parent and hrp and hrp.Parent) then
            return
        end

        local b = getBall()
        if not (b and b.Parent) then
            return
        end

        local now = tick()
        local bp = b.Position

        -- Calcular velocidade da bola
        local raw
        local okVel, av = pcall(function()
            return b.AssemblyLinearVelocity
        end)

        if okVel and typeof(av) == "Vector3" and av.Magnitude > 0.1 then
            raw = av
            vel = av
        elseif not lastT then
            lastT, lastPos = now, bp
        else
            local dtt = now - lastT
            if dtt > 0 then
                raw = (bp - lastPos) / dtt
                local a = dt / (tau + dt)
                vel = vel + (raw - vel) * a
                lastT, lastPos = now, bp
            end
        end

        local hrpPos = hrp.Position
        local spd = vel.Magnitude

        -- Calcular raio de parry
        local baseWin = 0.32
        local baseOff = 6
        local rad = spd * baseWin + baseOff
        rad = math.clamp(rad, minR, maxR)

        local pre = 8
        local parryRad = rad + pre
        local d = (bp - hrpPos).Magnitude
        local dot = vel:Dot(hrpPos - bp)
        local app = dot > 0
        local tgt = tgtOn()

        local tImp = 1000000
        if spd > 1 then
            tImp = d / spd
        end

        -- Condições para parry
        local can = tgt and app and spd > 5 and d <= parryRad and tImp <= 0.35

        -- COOLDOWN: só dispara se passou 0.3s desde último parry
        if can and now - lastFire >= cd then
            sendParry()
            lastFire = now
        end
    end)

    ch.AncestryChanged:Connect(function(_, p)
        if not p then
            if hb then
                hb:Disconnect()
                hb = nil
            end
        end
    end)
end

lp.CharacterAdded:Connect(bind)
if lp.Character then
    bind(lp.Character)
end