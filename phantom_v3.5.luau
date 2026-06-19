-- ================================================
--   Phantom Ball v3.5 | by ppzudo (fixed)
-- ================================================

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Stats             = game:GetService("Stats")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ==================== EXECUTOR COMPAT ====================
local task = task or {}
if not task.wait then
    task.wait = function(n) return wait(n or (1/30)) end
end
if not task.spawn then
    task.spawn = function(f, ...)
        local args = {...}
        local co = coroutine.wrap(function() f(table.unpack(args)) end)
        co()
    end
end
if not task.defer then task.defer = task.spawn end

local safeTick = (function()
    local ok = pcall(tick)
    if ok then return tick end
    return os.clock
end)()
local _tick = safeTick

local function getVelocity(part)
    if not part then return Vector3.zero end
    local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
    if ok and v then return v end
    local ok2, v2 = pcall(function() return part.Velocity end)
    if ok2 and v2 then return v2 end
    return Vector3.zero
end

-- ==================== CONFIG ====================
local Config = {
    AutoParry   = true,
    ManualSpam  = false,
    MiniSpam    = false,
    AutoClash   = true,
    CPS         = 500,
    ClashDecay  = 0.35,
    MinDistance = 38,
    UseTouchTap = true,
}

-- ==================== STATE ====================
local Cache = {
    Character = nil,
    RootPart  = nil,
    Ball      = nil,
}

local BallSync = {
    TargetID         = -999,
    PreviousTargetID = -999,
    RealPosition     = Vector3.new(),
    Speed            = 0,
    Locked           = false,
    Teleported       = false,
}

local ClashState = {
    Active             = false,
    LastActivationTime = 0,
}

local smoothedPing    = 0.05
local ballProcessed   = false
local lastProcessReset = 0
local spamAcc         = 0  -- DECLARADO: usado em setupCharacter e no handler do F

-- ==================== REMOTES (método v7) ====================
local TS_Folder      = ReplicatedStorage:WaitForChild("TS", 5)
local NetRemotes     = TS_Folder and TS_Folder:FindFirstChild("GeneratedNetworkRemotes")
local Remotes_folder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 10)
local touchTap       = ReplicatedStorage:FindFirstChild("TouchTap")

local function validRemote(remote)
    return typeof(remote) == "Instance" and remote.Parent ~= nil and remote:IsA("RemoteEvent")
end

local function refreshRefs()
    if not (TS_Folder and TS_Folder.Parent) then
        TS_Folder = ReplicatedStorage:FindFirstChild("TS")
    end
    if not (Remotes_folder and Remotes_folder.Parent) then
        Remotes_folder = ReplicatedStorage:FindFirstChild("Remotes")
    end
    if TS_Folder and not (NetRemotes and NetRemotes.Parent) then
        NetRemotes = TS_Folder:FindFirstChild("GeneratedNetworkRemotes")
    end
end

-- módulos do jogo
local function safeReq(mod)
    if typeof(mod) ~= "Instance" or not mod.Parent or not mod:IsA("ModuleScript") then return nil end
    if type(require) ~= "function" then return nil end
    local ok, res = pcall(require, mod)
    return ok and res or nil
end

local bmMod     = TS_Folder and safeReq(TS_Folder:FindFirstChild("BindableManager"))
local BM        = bmMod and bmMod.BindableManager or nil
local enumFolder= TS_Folder and TS_Folder:FindFirstChild("Enums")
local abMod     = enumFolder and safeReq(enumFolder:FindFirstChild("AbilityID"))
local AbilityID = abMod and abMod.AbilityID or { Deflect = "Deflect" }
local abilFolder= TS_Folder and TS_Folder:FindFirstChild("Abilities")
local defMod    = abilFolder and safeReq(abilFolder:FindFirstChild("DeflectAbility"))
local Def       = defMod and defMod.DeflectAbility or {}

local gameEnv2 = nil
local gameG2   = nil

local function getGameGlobal2()
    if type(gameG2) == "table" then return gameG2, gameEnv2 end
    if type(getfenv) == "function" then
        local fns = {}
        if type(Def) == "table" then
            fns[#fns+1] = Def.Deflect
            fns[#fns+1] = Def.OnClientCreate
            fns[#fns+1] = Def.OnServerCreate
            fns[#fns+1] = Def.constructor
        end
        for i = 1, #fns do
            local fn = fns[i]
            if type(fn) == "function" then
                local ok, env = pcall(getfenv, fn)
                if ok and type(env) == "table" then
                    gameEnv2 = env
                    local g = rawget(env, "_G")
                    gameG2 = type(g) == "table" and g or env
                    return gameG2, gameEnv2
                end
            end
        end
    end
    gameEnv2 = type(_G) == "table" and _G or {}
    gameG2   = gameEnv2
    return gameG2, gameEnv2
end

local function getGameDid2()
    local g, env = getGameGlobal2()
    local did = type(g) == "table" and rawget(g, "did") or nil
    if validRemote(did) then return did end
    did = type(env) == "table" and rawget(env, "did") or nil
    if validRemote(did) then return did end
    return nil
end

local function setGameDid2(remote)
    local g, env = getGameGlobal2()
    if type(g)   == "table" then rawset(g,   "did", remote) end
    if type(env) == "table" and env ~= g then rawset(env, "did", remote) end
end

local parryRemote2       = nil
local parryMode2         = nil
local parryRemoteLocked2 = false
local probingRemote2     = false
local _parryRemoteCached = nil

local HINT_INDEX = Config.RemoteIndex or 16

local function cacheParryRemote2(remote, mode, locked)
    if not validRemote(remote) then return nil end
    parryRemote2       = remote
    _parryRemoteCached = remote
    parryMode2         = mode
    if locked ~= nil then parryRemoteLocked2 = locked and true or false end
    if mode == "buffer" then setGameDid2(remote) end
    print("[PHANTOM LOG] Remote salvo: nome=" .. tostring(remote.Name) .. " | modo=" .. tostring(mode) .. " | locked=" .. tostring(locked))
    return parryRemote2, parryMode2
end

local cooldownFrame2 = nil
local function getCooldownFrame2()
    if cooldownFrame2 and cooldownFrame2.Parent then return cooldownFrame2 end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local ok, frame = pcall(function()
        local iface   = pg:WaitForChild("Interface", 1)
        local hud     = iface:WaitForChild("HUD", 1)
        local bottom  = hud:WaitForChild("Bottom", 1)
        local deflect = bottom:WaitForChild("Deflect", 1)
        local btn     = deflect:WaitForChild("Button", 1)
        local clip    = btn:WaitForChild("CooldownClipping", 1)
        return clip:WaitForChild("Cooldown", 1)
    end)
    if ok and frame then cooldownFrame2 = frame end
    return cooldownFrame2
end

local function sameSize(a, b)
    return a and b
        and a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset
        and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end

local function makeDeflectBuffer2(flag)
    if type(buffer) == "table" and type(buffer.fromstring) == "function" then
        local ok, v = pcall(buffer.fromstring, flag == 2 and "\2" or "\1")
        if ok and v then return v end
    end
    if type(buffer) == "table" and type(buffer.create) == "function" and type(buffer.writeu8) == "function" then
        local ok, p = pcall(buffer.create, 1)
        if ok and p then
            pcall(buffer.writeu8, p, 0, flag)
            return p
        end
    end
    if type(buffer) == "function" then
        local ok, p = pcall(buffer, 1)
        if ok and p then return p end
    end
    return nil
end

local function getDeflectAbility2()
    if not BM or not AbilityID or AbilityID.Deflect == nil then return nil end
    local okFn, fn = pcall(function() return BM:GetFunction("AbilityManager::GetAbility") end)
    if not okFn or not fn then return nil end
    local ok, ability = pcall(function() return fn:Invoke(AbilityID.Deflect) end)
    return ok and type(ability) == "table" and ability or nil
end

local function resolveParryRemote2()
    refreshRefs()

    if parryRemoteLocked2 then
        return (validRemote(parryRemote2) and parryRemote2 or nil), parryMode2
    end

    if validRemote(parryRemote2) then return parryRemote2, parryMode2 end

    local did = getGameDid2()
    if validRemote(did) then return cacheParryRemote2(did, "buffer") end

    if Remotes_folder then
        local reqDef = Remotes_folder:FindFirstChild("ReqDef")
        if validRemote(reqDef) then return cacheParryRemote2(reqDef, "buffer") end
    end

    if Remotes_folder then
        local nspaf = Remotes_folder:FindFirstChild("NS_PaF")
        if validRemote(nspaf) then return cacheParryRemote2(nspaf, "buffer") end
    end

    local byUID = Remotes_folder and Remotes_folder:FindFirstChild("pr_" .. tostring(LocalPlayer.UserId))
    if validRemote(byUID) then return cacheParryRemote2(byUID, "buffer") end

    do
        local ok, v = pcall(function() return rawget(_G, "did") end)
        if ok and validRemote(v) then return cacheParryRemote2(v, "buffer") end
    end

    for _, key in ipairs({"deflectRemote", "parryRemote", "deflect_remote", "remote", "RE"}) do
        local ok, v = pcall(function() return rawget(_G, key) end)
        if ok and validRemote(v) then return cacheParryRemote2(v, "buffer") end
    end

    local ability = getDeflectAbility2()
    if ability then
        local adid = rawget(ability, "did")
        if validRemote(adid) then return cacheParryRemote2(adid, "buffer") end
        for _, k in ipairs({"remote", "_remote", "_did", "event"}) do
            local v = rawget(ability, k)
            if validRemote(v) then return cacheParryRemote2(v, "buffer") end
        end
    end

    if NetRemotes then
        local fb = NetRemotes:FindFirstChild("RE_4.6848415795802784e+76")
        if validRemote(fb) then
            print("⚠️ Phantom: usando fallback fixo RE_4.68")
            return cacheParryRemote2(fb, "buffer", false)
        end
        for _, v in ipairs(NetRemotes:GetChildren()) do
            if v:IsA("RemoteEvent") then
                print("⚠️ Phantom: usando RE genérico de GeneratedNetworkRemotes: " .. v.Name)
                return cacheParryRemote2(v, "buffer", false)
            end
        end
    end

    return nil
end

local function probeNamedRemoteEvents2()
    refreshRefs()
    if probingRemote2 or not Remotes_folder then return nil end
    probingRemote2 = true
    local cf = getCooldownFrame2()
    local children = Remotes_folder:GetChildren()

    local order = {}
    local seen  = {}
    for _, name in ipairs({"ReqDef", "NS_PaF"}) do
        local v = Remotes_folder:FindFirstChild(name)
        if v and v:IsA("RemoteEvent") then
            order[#order+1] = v
            seen[v] = true
        end
    end
    local hint = children[HINT_INDEX]
    if hint and hint:IsA("RemoteEvent") and hint.Name == "RemoteEvent" and not seen[hint] then
        order[#order+1] = hint
        seen[hint] = true
    end
    for _, v in ipairs(children) do
        if not seen[v] and v:IsA("RemoteEvent") and v.Name == "RemoteEvent" then
            order[#order+1] = v
            seen[v] = true
        end
    end

    if not cf then
        probingRemote2 = false
        return nil
    end

    local baseline = cf.Size
    for i, v in ipairs(order) do
        local p2 = makeDeflectBuffer2(2)
        if p2 then pcall(function() v:FireServer(p2) end) end
        task.wait(0.03)
        local p1 = makeDeflectBuffer2(1)
        if p1 then pcall(function() v:FireServer(p1) end) end
        task.wait(0.08)
        if not sameSize(cf.Size, baseline) then
            probingRemote2 = false
            local allChildren = Remotes_folder:GetChildren()
            for idx, child in ipairs(allChildren) do
                if child == v then
                    HINT_INDEX = idx
                    print("[PHANTOM LOG] Remote encontrado via probe: idx=" .. idx .. " | " .. tostring(v:GetFullName()))
                    break
                end
            end
            return cacheParryRemote2(v, "buffer", true)
        end
    end
    probingRemote2 = false
    warn("⚠️ Phantom: probe não encontrou remote via cooldown frame")
    return resolveParryRemote2()
end

local function getParryRemote()
    if _parryRemoteCached and _parryRemoteCached.Parent then
        return _parryRemoteCached
    end
    local did = getGameDid2()
    if did then
        _parryRemoteCached = did
        return _parryRemoteCached
    end
    local r = resolveParryRemote2()
    if r then return r end
    if not probingRemote2 then
        task.spawn(probeNamedRemoteEvents2)
    end
    return nil
end

-- buffer pré-cacheado com fallbacks de executor
local _bufParry
do
    local ok, v = pcall(function() return buffer.fromstring("\1") end)
    if ok and v then
        _bufParry = v
    else
        local ok2, p = pcall(function()
            local b = buffer.create(1)
            buffer.writeu8(b, 0, 1)
            return b
        end)
        _bufParry = ok2 and p or nil
    end
end

local function sendParryInit()
    local r = getParryRemote()
    if not r then return end
    local payload = makeDeflectBuffer2(2)
    if payload then pcall(function() r:FireServer(payload) end) end
end

-- ==================== FIRE PARRY ====================
local function fireWithFallback(remote, bufPayload)
    if not validRemote(remote) then return false end
    if bufPayload then
        local ok = pcall(function() remote:FireServer(bufPayload) end)
        if ok then return true end
    end
    local ok1 = pcall(function() remote:FireServer("\x01") end)
    if ok1 then return true end
    local ok2 = pcall(function() remote:FireServer("\1") end)
    if ok2 then return true end
    local ok3 = pcall(function() remote:FireServer(1) end)
    if ok3 then return true end
    pcall(function() remote:FireServer() end)
    return true
end

local function fireParryNormal()
    local r = getParryRemote()
    if r then
        fireWithFallback(r, _bufParry)
        return
    end
    local ability = getDeflectAbility2()
    if ability then
        for _, k in ipairs({"did", "remote", "_remote", "_did", "event"}) do
            local v = rawget(ability, k)
            if validRemote(v) then
                cacheParryRemote2(v, "buffer")
                fireWithFallback(v, _bufParry)
                return
            end
        end
    end
end

local function fireTouchTap()
    if Config.UseTouchTap and touchTap then
        pcall(function() touchTap:Fire() end)
    end
end

-- ==================== SPAM ====================
local function getSpamGap()
    local cps = tonumber(Config.CPS) or 500
    if cps < 1 then cps = 1 end
    return 1 / cps
end

local spamWasActive = false

local function fireOneClick()
    local r = getParryRemote()
    if not (r and r.Parent and _bufParry) then return end
    pcall(function() r:FireServer(_bufParry) end)
end

local function maybeFireTouchTap()
    if not touchTap then return end
    pcall(function() touchTap:Fire() end)
end

task.spawn(function()
    while true do
        local ok, err = pcall(function()
            local spamOn = Config.ManualSpam or ClashState.Active
            if not spamOn then
                spamWasActive = false
                return
            end
            spamWasActive = true
            local gap = getSpamGap()
            fireOneClick()
            maybeFireTouchTap()
            if gap < 0.001 then gap = 0.001 end
            task.wait(gap)
        end)
        if not ok then
            warn("[PHANTOM] spam loop error: " .. tostring(err))
            spamWasActive = false
        end
        if not spamWasActive then task.wait(0.005) end
    end
end)

-- ==================== CHARACTER ====================
local function setupCharacter(char)
    Cache.Character    = char
    Cache.RootPart     = char:WaitForChild("HumanoidRootPart", 10)
    ballProcessed      = false
    spamAcc            = 0
    spamWasActive      = false
    _parryRemoteCached = nil
    gameG2             = nil
    gameEnv2           = nil
end

LocalPlayer.CharacterAdded:Connect(setupCharacter)
if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end

-- ==================== BALL SYNC ====================
local ballSyncRemote = ReplicatedStorage:WaitForChild("Remotes", 5)
ballSyncRemote = ballSyncRemote and ballSyncRemote:FindFirstChild("BallSyncData")

if ballSyncRemote then
    ballSyncRemote.OnClientEvent:Connect(function(data)
        if typeof(data) ~= "table" then return end

        if typeof(data.Speed) == "number" then
            BallSync.Speed = data.Speed
        end

        if type(data.Locked) == "boolean" then
            BallSync.Locked = data.Locked
            if data.Locked then ballProcessed = true end
        end

        if data.Teleported == true then
            BallSync.Teleported = true
        else
            BallSync.Teleported = false
        end

        if data.TargetPlayerID then
            local newTarget = data.TargetPlayerID
            if newTarget ~= BallSync.TargetID then
                BallSync.PreviousTargetID = BallSync.TargetID
                BallSync.TargetID         = newTarget
                ballProcessed             = false

                if Config.AutoClash
                    and not Config.ManualSpam
                    and newTarget == LocalPlayer.UserId
                    and BallSync.PreviousTargetID ~= LocalPlayer.UserId
                    and BallSync.PreviousTargetID ~= -999
                    and Cache.RootPart
                then
                    local b = Cache.Ball or Workspace:FindFirstChild("GameBall")
                    if b and b.Parent then
                        local dist = (Cache.RootPart.Position - b.Position).Magnitude
                        if dist < Config.MinDistance then
                            ClashState.Active             = true
                            ClashState.LastActivationTime = _tick()
                        end
                    end
                end
            end
        end
    end)
end

Cache.Ball = Workspace:FindFirstChild("GameBall")
Workspace.ChildAdded:Connect(function(c)
    if c.Name == "GameBall" then Cache.Ball = c end
end)
Workspace.ChildRemoved:Connect(function(c)
    if c.Name == "GameBall" then Cache.Ball = nil end
end)

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name         = "PhantomGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 10

local ok = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ok or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Tamanhos
local OPEN_W, OPEN_H = 300, 320
local BUBBLE_SIZE    = 56

-- Frame principal (já nasce aberto)
local MainFrame = Instance.new("Frame")
MainFrame.Name             = "MainFrame"
MainFrame.Size             = UDim2.new(0, OPEN_W, 0, OPEN_H)
MainFrame.Position         = UDim2.new(0.5, -OPEN_W/2, 0.5, -OPEN_H/2)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
MainFrame.BorderSizePixel  = 0
MainFrame.Active           = true
MainFrame.Draggable        = false
MainFrame.Parent           = ScreenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent       = MainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color     = Color3.fromRGB(190, 25, 25)
mainStroke.Thickness = 1.5
mainStroke.Parent    = MainFrame

-- Ícone da bolinha (sempre existe, só aparece quando fechado)
local BubbleIcon = Instance.new("TextLabel")
BubbleIcon.Size                   = UDim2.new(1, 0, 1, 0)
BubbleIcon.BackgroundTransparency = 1
BubbleIcon.Text                   = "P"
BubbleIcon.TextColor3             = Color3.new(1, 1, 1)
BubbleIcon.TextScaled             = true
BubbleIcon.Font                   = Enum.Font.GothamBold
BubbleIcon.Visible                = false
BubbleIcon.Parent                 = MainFrame

-- Header arrastável
local Header = Instance.new("Frame")
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, 48)
Header.BackgroundColor3 = Color3.fromRGB(190, 25, 25)
Header.BorderSizePixel  = 0
Header.Active           = true
Header.Parent           = MainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent       = Header

local headerBottom = Instance.new("Frame")
headerBottom.Size             = UDim2.new(1, 0, 0, 12)
headerBottom.Position         = UDim2.new(0, 0, 1, -12)
headerBottom.BackgroundColor3 = Color3.fromRGB(190, 25, 25)
headerBottom.BorderSizePixel  = 0
headerBottom.Parent           = Header

local TitleIcon = Instance.new("TextLabel")
TitleIcon.Size                  = UDim2.new(0, 30, 1, 0)
TitleIcon.Position              = UDim2.new(0, 10, 0, 0)
TitleIcon.BackgroundTransparency = 1
TitleIcon.Text                  = "⚡"
TitleIcon.TextScaled            = true
TitleIcon.Font                  = Enum.Font.GothamBold
TitleIcon.Parent                = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size                  = UDim2.new(1, -90, 1, 0)
TitleLabel.Position              = UDim2.new(0, 44, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text                  = "PHANTOM  v3.5"
TitleLabel.TextColor3            = Color3.new(1, 1, 1)
TitleLabel.TextScaled            = true
TitleLabel.Font                  = Enum.Font.GothamBold
TitleLabel.TextXAlignment        = Enum.TextXAlignment.Left
TitleLabel.Parent                = Header

-- Botao X (fecha -> vira bolinha)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size             = UDim2.new(0, 26, 0, 26)
CloseBtn.Position         = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.new(0, 0, 0)
CloseBtn.BackgroundTransparency = 0.4
CloseBtn.BorderSizePixel  = 0
CloseBtn.Text             = "X"
CloseBtn.TextColor3       = Color3.new(1, 1, 1)
CloseBtn.TextScaled       = true
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.ZIndex           = 5
CloseBtn.Parent           = Header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent       = CloseBtn

-- Área de conteúdo (criada ANTES das funções open/close que referenciam Content)
local Content = Instance.new("Frame")
Content.Name                    = "Content"
Content.Size                    = UDim2.new(1, 0, 1, -48)
Content.Position                = UDim2.new(0, 0, 0, 48)
Content.BackgroundTransparency  = 1
Content.Visible                 = true
Content.Parent                  = MainFrame

-- ==================== BOLINHA / ABRIR-FECHAR ====================
local isOpen = true
local lastX, lastY  -- posicao antes de virar bolinha

local function openMain()
    if isOpen then return end
    isOpen = true
    local vp = Workspace.CurrentCamera.ViewportSize
    local x = lastX or math.floor(vp.X/2 - OPEN_W/2)
    local y = lastY or math.floor(vp.Y/2 - OPEN_H/2)
    if vp.X < OPEN_W then x = 0 end
    if vp.Y < OPEN_H then y = 0 end
    x = math.clamp(x, 0, math.max(0, vp.X - OPEN_W))
    y = math.clamp(y, 0, math.max(0, vp.Y - OPEN_H))
    MainFrame.Position = UDim2.new(0, x, 0, y)
    Header.Visible     = true
    Content.Visible    = true
    CloseBtn.Visible   = true
    BubbleIcon.Visible = false
    pcall(function()
        -- bolinha -> painel: tween principal do tamanho
        TweenService:Create(MainFrame,
            TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, OPEN_W, 0, OPEN_H)}
        ):Play()
        -- cor de fundo "esmaece" pra tom mais escuro
        TweenService:Create(MainFrame,
            TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(12, 12, 18)}
        ):Play()
        -- canto vai de circular pra arredondado
        TweenService:Create(mainCorner,
            TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {CornerRadius = UDim.new(0, 12)}
        ):Play()
        -- stroke engrossa de volta
        TweenService:Create(mainStroke,
            TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {Thickness = 1.5}
        ):Play()
    end)
end

local function closeMain()
    if not isOpen then return end
    isOpen = false
    lastX = MainFrame.Position.X.Offset
    lastY = MainFrame.Position.Y.Offset
    Header.Visible     = false
    Content.Visible    = false
    CloseBtn.Visible   = false
    BubbleIcon.Visible = true
    pcall(function()
        -- painel -> bolinha: tween principal
        TweenService:Create(MainFrame,
            TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {Size = UDim2.new(0, BUBBLE_SIZE, 0, BUBBLE_SIZE)}
        ):Play()
        -- cor vai pra um tom mais "vivo" (bolinha mais brilhante)
        TweenService:Create(MainFrame,
            TweenInfo.new(0.38, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            {BackgroundColor3 = Color3.fromRGB(28, 12, 12)}
        ):Play()
        -- canto vai pra círculo
        TweenService:Create(mainCorner,
            TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            {CornerRadius = UDim.new(1, 0)}
        ):Play()
        -- stroke afina enquanto encolhe
        TweenService:Create(mainStroke,
            TweenInfo.new(0.38, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            {Thickness = 2}
        ):Play()
    end)
end

-- X fecha
CloseBtn.MouseButton1Click:Connect(function()
    if isOpen then closeMain() end
end)

-- F8 esconde/mostra (bolinha) | F toggle spam
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F8 then
        if isOpen then closeMain() else openMain() end
    elseif input.KeyCode == Enum.KeyCode.F then
        Config.ManualSpam = not Config.ManualSpam
        spamAcc       = 0
        spamWasActive = false
    end
end)

-- Drag unificado: header (aberto) OU frame inteiro (fechado como bolinha)
do
    local dragging   = false
    local dragStart  = nil
    local frameStart = nil
    local dragMoved  = false

    local function startDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging   = true
        dragMoved  = false
        dragStart  = input.Position
        frameStart = Vector2.new(MainFrame.Position.X.Offset, MainFrame.Position.Y.Offset)
    end

    local function updateDrag(input)
        if not dragging or not dragStart or not frameStart then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        if delta.Magnitude > 4 then dragMoved = true end
        -- sem clamp: bolinha e frame podem sair da tela de propósito
        local nx = frameStart.X + delta.X
        local ny = frameStart.Y + delta.Y
        MainFrame.Position = UDim2.new(0, nx, 0, ny)
    end

    local function endDrag(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            -- se for bolinha e não moveu, abre
            if not isOpen and not dragMoved then
                openMain()
            end
            dragging  = false
            dragStart = nil
        end
    end

    -- Header drag (aberto)
    Header.InputBegan:Connect(startDrag)
    -- Frame drag (bolinha)
    MainFrame.InputBegan:Connect(function(input)
        -- se for bolinha, header não recebe o evento; tratar aqui
        if not isOpen then
            startDrag(input)
        end
    end)

    UserInputService.InputChanged:Connect(updateDrag)
    UserInputService.InputEnded:Connect(endDrag)
end

local ListLayout = Instance.new("UIListLayout")
ListLayout.SortOrder           = Enum.SortOrder.LayoutOrder
ListLayout.Padding             = UDim.new(0, 8)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ListLayout.Parent              = Content

local Padding = Instance.new("UIPadding")
Padding.PaddingTop    = UDim.new(0, 12)
Padding.PaddingLeft   = UDim.new(0, 12)
Padding.PaddingRight  = UDim.new(0, 12)
Padding.PaddingBottom = UDim.new(0, 10)
Padding.Parent        = Content

local function AddToggle(name, default, order, callback)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.Parent           = Content

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 8)
    rowCorner.Parent       = row

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color     = Color3.fromRGB(45, 45, 60)
    rowStroke.Thickness = 1
    rowStroke.Parent    = row

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -110, 1, 0)
    lbl.Position            = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = name
    lbl.TextColor3          = Color3.fromRGB(210, 210, 225)
    lbl.TextScaled          = true
    lbl.Font                = Enum.Font.Gotham
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.Parent              = row

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 80, 0, 30)
    btn.Position         = UDim2.new(1, -92, 0.5, -15)
    btn.BackgroundColor3 = default and Color3.fromRGB(0, 185, 75) or Color3.fromRGB(55, 55, 68)
    btn.Text             = default and "ON" or "OFF"
    btn.TextColor3       = Color3.new(1, 1, 1)
    btn.TextScaled       = true
    btn.Font             = Enum.Font.GothamBold
    btn.BorderSizePixel  = 0
    btn.Parent           = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent       = btn

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        local targetColor = state and Color3.fromRGB(0, 185, 75) or Color3.fromRGB(55, 55, 68)
        pcall(function()
            -- pulse: encolhe rapidinho e volta ao tamanho normal
            TweenService:Create(btn,
                TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 70, 0, 26)}
            ):Play()
            task.delay(0.10, function()
                if btn.Parent then
                    TweenService:Create(btn,
                        TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        {Size = UDim2.new(0, 80, 0, 30)}
                    ):Play()
                end
            end)
            -- cor desliza (nao troca instantaneo)
            TweenService:Create(btn,
                TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {BackgroundColor3 = targetColor}
            ):Play()
        end)
        btn.Text = state and "ON" or "OFF"
        callback(state)
    end)

    return btn
end

AddToggle("Auto Parry", Config.AutoParry, 1, function(v) Config.AutoParry = v end)
AddToggle("Mini Spam",  Config.MiniSpam,  3, function(v)
    Config.MiniSpam = v
    local g = game:GetService("CoreGui"):FindFirstChild("PhantomSpamToggleGui")
    if g then g.Enabled = v end
end)
AddToggle("Auto Clash", Config.AutoClash, 4, function(v) Config.AutoClash = v end)

-- Campo de CPS (editavel)
local cpsRow = Instance.new("Frame")
cpsRow.Size             = UDim2.new(1, 0, 0, 44)
cpsRow.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
cpsRow.BorderSizePixel  = 0
cpsRow.LayoutOrder      = 2
cpsRow.Parent           = Content
local cpsRowCorner = Instance.new("UICorner")
cpsRowCorner.CornerRadius = UDim.new(0, 8)
cpsRowCorner.Parent       = cpsRow
local cpsRowStroke = Instance.new("UIStroke")
cpsRowStroke.Color     = Color3.fromRGB(45, 45, 60)
cpsRowStroke.Thickness = 1
cpsRowStroke.Parent    = cpsRow

local cpsLbl = Instance.new("TextLabel")
cpsLbl.Size                = UDim2.new(0.5, -14, 1, 0)
cpsLbl.Position            = UDim2.new(0, 14, 0, 0)
cpsLbl.BackgroundTransparency = 1
cpsLbl.Text                = "CPS (Spam)"
cpsLbl.TextColor3          = Color3.fromRGB(210, 210, 225)
cpsLbl.TextScaled          = true
cpsLbl.Font                = Enum.Font.Gotham
cpsLbl.TextXAlignment      = Enum.TextXAlignment.Left
cpsLbl.Parent              = cpsRow

local cpsBox = Instance.new("TextBox")
cpsBox.Size             = UDim2.new(0, 80, 0, 30)
cpsBox.Position         = UDim2.new(1, -92, 0.5, -15)
cpsBox.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
cpsBox.BorderSizePixel  = 0
cpsBox.Text             = tostring(Config.CPS)
cpsBox.TextColor3       = Color3.new(1, 1, 1)
cpsBox.TextScaled       = true
cpsBox.Font             = Enum.Font.GothamBold
cpsBox.ClearTextOnFocus = false
cpsBox.Parent           = cpsRow
local cpsBoxCorner = Instance.new("UICorner")
cpsBoxCorner.CornerRadius = UDim.new(0, 6)
cpsBoxCorner.Parent       = cpsBox

cpsBox.FocusLost:Connect(function()
    local n = tonumber(cpsBox.Text)
    local flashColor, restoreDelay
    if n and n >= 1 and n <= 2000 then
        Config.CPS = math.floor(n)
        cpsBox.Text = tostring(Config.CPS)
        flashColor = Color3.fromRGB(0, 185, 75)
        restoreDelay = 0.55
    else
        cpsBox.Text = tostring(Config.CPS)
        flashColor = Color3.fromRGB(185, 50, 50)
        restoreDelay = 0.55
    end
    pcall(function()
        TweenService:Create(cpsBox,
            TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {BackgroundColor3 = flashColor}
        ):Play()
    end)
    task.delay(restoreDelay, function()
        if not cpsBox.Parent then return end
        pcall(function()
            TweenService:Create(cpsBox,
                TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
                {BackgroundColor3 = Color3.fromRGB(55, 55, 68)}
            ):Play()
        end)
    end)
end)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size               = UDim2.new(1, 0, 0, 24)
StatusLabel.BackgroundTransparency = 1
StatusLabel.TextColor3         = Color3.fromRGB(130, 130, 150)
StatusLabel.Text               = "Aguardando bola..."
StatusLabel.TextScaled         = true
StatusLabel.Font               = Enum.Font.Gotham
StatusLabel.LayoutOrder        = 5
StatusLabel.Parent             = Content

-- ==================== MAIN LOOP ====================
RunService.Heartbeat:Connect(function(dt)
    if not Cache.RootPart then return end

    local now     = _tick()
    local b       = Cache.Ball or Workspace:FindFirstChild("GameBall")
    local ballPos = (b and b.Parent) and b.Position or Vector3.new()
    local distance = (Cache.RootPart.Position - ballPos).Magnitude

    if ClashState.Active then
        if (_tick() - ClashState.LastActivationTime) > Config.ClashDecay
        or distance > Config.MinDistance * 1.6 then
            ClashState.Active = false
        end
    end

    if ClashState.Active then
        StatusLabel.Text       = "⚔️ Auto Clash ativo"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 0)
    elseif Config.AutoParry and BallSync.TargetID == LocalPlayer.UserId then
        StatusLabel.Text       = string.format("🎯 Parry | %.0fms | dist %.1f", smoothedPing * 1000, distance)
        StatusLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
    else
        StatusLabel.Text       = "Aguardando bola..."
        StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end

    if Config.AutoParry and not Config.ManualSpam and not ClashState.Active
    and BallSync.TargetID == LocalPlayer.UserId and not BallSync.Teleported then
        local ok2, raw = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        if ok2 and type(raw) == "number" and raw > 0 then
            smoothedPing = smoothedPing * 0.85 + raw * 0.15
        end

        local speed      = math.max(BallSync.Speed, 1)
        local timeToReach = distance / speed
        local threshold  = math.clamp(0.115 + smoothedPing * 1.1 + 0.04, 0.06, 0.5)

        if timeToReach <= threshold and not ballProcessed then
            fireParryNormal()
            ballProcessed    = true
            lastProcessReset = now
        end
    end

    if ballProcessed and (now - lastProcessReset) > 0.45 then
        ballProcessed = false
    end
end)

-- ==================== BOOT ====================
task.defer(function()
    sendParryInit()
    local r = getParryRemote()
    if r then
        print("[PHANTOM LOG] Boot: remote carregado | ref=" .. tostring(r:GetFullName()))
        task.spawn(function()
            local cf = getCooldownFrame2()
            if not cf then return end
            local baseline = cf.Size
            local p2 = makeDeflectBuffer2(2)
            local p1 = makeDeflectBuffer2(1)
            if not (p2 and p1) then return end
            pcall(function() r:FireServer(p2) end)
            task.wait(0.03)
            pcall(function() r:FireServer(p1) end)
            task.wait(0.1)
            if sameSize(cf.Size, baseline) then
                _parryRemoteCached = nil
                print("[PHANTOM LOG] Boot: remote salvo não respondeu, iniciando probe...")
                probeNamedRemoteEvents2()
            else
                print("[PHANTOM LOG] Boot: remote confirmado ✅")
            end
        end)
    else
        print("[PHANTOM LOG] Boot: nenhum remote, iniciando probe...")
        probeNamedRemoteEvents2()
    end
end)

print("[Phantom v3.5] Carregado! | CPS: " .. Config.CPS)

-- ================== MINI SPAM GUI (estilo Delta v3) ==================
task.spawn(function()
    local CoreGui = game:GetService("CoreGui")
    local UIS     = game:GetService("UserInputService")
    local WS      = game:GetService("Workspace")

    local math_clamp = math.clamp

    local spamOn     = Config.ManualSpam == true
    local toggleBtn  = nil

    local function updateMiniGUI()
        if not toggleBtn or not toggleBtn.Parent then return end
        local targetColor = spamOn
            and Color3.fromRGB(50, 220, 50)
            or  Color3.fromRGB(220, 50, 50)
        pcall(function()
            -- pulse: encolhe e volta
            TweenService:Create(toggleBtn,
                TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.80, 0, 0, 46)}
            ):Play()
            task.delay(0.10, function()
                if toggleBtn and toggleBtn.Parent then
                    TweenService:Create(toggleBtn,
                        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                        {Size = UDim2.new(0.85, 0, 0, 52)}
                    ):Play()
                end
            end)
            -- cor desliza
            TweenService:Create(toggleBtn,
                TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {BackgroundColor3 = targetColor}
            ):Play()
            -- texto: fade out -> troca -> fade in
            TweenService:Create(toggleBtn,
                TweenInfo.new(0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {TextTransparency = 1}
            ):Play()
        end)
        task.delay(0.10, function()
            if not (toggleBtn and toggleBtn.Parent) then return end
            toggleBtn.Text = spamOn and "ON" or "OFF"
            pcall(function()
                TweenService:Create(toggleBtn,
                    TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                    {TextTransparency = 0}
                ):Play()
            end)
        end)
    end

    local function setSpam(v)
        if spamOn == v then return end
        spamOn = v
        Config.ManualSpam = v
        if v then
            ClashState.Active = false
        end
        updateMiniGUI()
    end

    -- X e F togglam (F8 já tava no handler principal)
    UIS.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == Enum.KeyCode.X or inp.KeyCode == Enum.KeyCode.F then
            setSpam(not spamOn)
        end
    end)

    local old = CoreGui:FindFirstChild("PhantomSpamToggleGui")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "PhantomSpamToggleGui"
    screenGui.ResetOnSpawn   = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder   = 11
    screenGui.Enabled        = Config.MiniSpam == true
    screenGui.Parent         = CoreGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Size             = UDim2.new(0, 120, 0, 95)
    mainFrame.Position         = UDim2.new(1, -130, 0.5, -47)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
    mainFrame.BorderSizePixel  = 0
    mainFrame.BackgroundTransparency = 1  -- começa invisível, faz fade-in
    mainFrame.Parent           = screenGui
    local mainFrameCorner = Instance.new("UICorner", mainFrame)
    mainFrameCorner.CornerRadius = UDim.new(0, 14)

    -- posição de descanso (nunca muda, sempre volta pra cá)
    local restPos = mainFrame.Position

    local stroke     = Instance.new("UIStroke")
    stroke.Color        = Color3.fromRGB(190, 25, 25)
    stroke.Thickness    = 1.5
    stroke.Transparency = 1  -- combina com fundo transparente inicial
    stroke.Parent       = mainFrame

    local titleBar = Instance.new("Frame")
    titleBar.Size             = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(190, 25, 25)
    titleBar.BorderSizePixel  = 0
    titleBar.Parent           = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size                   = UDim2.new(1, -6, 1, 0)
    titleLabel.Position               = UDim2.new(0, 6, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text                   = "PHANTOM"
    titleLabel.TextColor3             = Color3.new(1, 1, 1)
    titleLabel.TextScaled             = true
    titleLabel.Font                   = Enum.Font.GothamBold
    titleLabel.Parent                 = titleBar

    toggleBtn = Instance.new("TextButton")
    toggleBtn.Size             = UDim2.new(0.85, 0, 0, 52)
    toggleBtn.Position         = UDim2.new(0.075, 0, 0, 30)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    toggleBtn.BorderSizePixel  = 0
    toggleBtn.Text             = "OFF"
    toggleBtn.TextColor3       = Color3.new(1, 1, 1)
    toggleBtn.TextScaled       = true
    toggleBtn.Font             = Enum.Font.GothamBold
    toggleBtn.Parent           = mainFrame
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)

    -- drag pelo frame inteiro (toggle absorve clique)
    local dragging, dragStart, startPos = false, nil, nil
    local function updateDrag(input)
        if not dragStart or not startPos then return end
        local delta  = input.Position - dragStart
        local vpSize = WS.CurrentCamera.ViewportSize
        local fSize  = mainFrame.AbsoluteSize
        -- mini spam: FICA preso na tela (não pode sair)
        local nx = math_clamp(startPos.X.Offset + delta.X, 0, math.max(0, vpSize.X - fSize.X))
        local ny = math_clamp(startPos.Y.Offset + delta.Y, 0, math.max(0, vpSize.Y - fSize.Y))
        mainFrame.Position = UDim2.new(0, nx, 0, ny)
    end

    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging  = true
        dragStart = input.Position
        startPos  = mainFrame.Position
    end)

    mainFrame.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch
        ) then updateDrag(input) end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = false
            dragStart = nil
            startPos  = nil
        end
    end)

    toggleBtn.Activated:Connect(function() setSpam(not spamOn) end)
    updateMiniGUI()

    -- animação de entrada: "espreme" pra dentro, depois relaxa
    local function playEntrance()
        if not mainFrame.Parent then return end
        pcall(function()
            -- fade in do fundo
            TweenService:Create(mainFrame,
                TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {BackgroundTransparency = 0}
            ):Play()
            -- fade in do stroke junto
            TweenService:Create(stroke,
                TweenInfo.new(0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {Transparency = 0}
            ):Play()
            -- fade in do header
            TweenService:Create(titleBar,
                TweenInfo.new(0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {BackgroundTransparency = 0}
            ):Play()
            TweenService:Create(titleLabel,
                TweenInfo.new(0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {TextTransparency = 0}
            ):Play()
            -- "salto" pra dentro: começa fora, vem com overshoot
            -- sempre pra restPos (não pra mainFrame.Position, que pode ter sido arrastado)
            local startX = restPos.X.Offset - 60
            local startY = restPos.Y.Offset - 30
            mainFrame.Position = UDim2.new(0, startX, 0, startY)
            TweenService:Create(mainFrame,
                TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Position = restPos}
            ):Play()
            -- botão aparece com delay (cascata)
            task.delay(0.18, function()
                if not (toggleBtn and toggleBtn.Parent) then return end
                pcall(function()
                    toggleBtn.BackgroundTransparency = 1
                    toggleBtn.TextTransparency = 1
                    TweenService:Create(toggleBtn,
                        TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                        {BackgroundTransparency = 0}
                    ):Play()
                    TweenService:Create(toggleBtn,
                        TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                        {TextTransparency = 0}
                    ):Play()
                end)
            end)
        end)
    end

    playEntrance()

    -- observa Config.MiniSpam: se ligar, aparece com animação; se desligar, sai
    task.spawn(function()
        local last = Config.MiniSpam == true
        while mainFrame and mainFrame.Parent do
            local cur = Config.MiniSpam == true
            if cur ~= last then
                if cur then
                    pcall(function()
                        TweenService:Create(mainFrame,
                            TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                            {BackgroundTransparency = 0}
                        ):Play()
                        TweenService:Create(stroke,
                            TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                            {Transparency = 0}
                        ):Play()
                        -- "salta" de volta pra restPos (não pra mainFrame.Position)
                        TweenService:Create(mainFrame,
                            TweenInfo.new(0.40, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                            {Position = restPos}
                        ):Play()
                    end)
                else
                    pcall(function()
                        -- slide pra fora (direita + fade), e DEPOIS volta pra restPos invisível
                        TweenService:Create(mainFrame,
                            TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                            {Position = UDim2.new(restPos.X.Scale, restPos.X.Offset + 40, restPos.Y.Scale, restPos.Y.Offset)}
                        ):Play()
                        TweenService:Create(mainFrame,
                            TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                            {BackgroundTransparency = 1}
                        ):Play()
                        TweenService:Create(stroke,
                            TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
                            {Transparency = 1}
                        ):Play()
                    end)
                    -- depois do slide, volta pra restPos invisível
                    -- (pra próxima vez que ligar, a entrada não começar do lugar errado)
                    task.delay(0.32, function()
                        if not (mainFrame and mainFrame.Parent) then return end
                        if Config.MiniSpam == true then return end -- pode ter religado rápido
                        mainFrame.Position = restPos
                    end)
                end
                last = cur
            end
            task.wait(0.1)
        end
    end)
end)
