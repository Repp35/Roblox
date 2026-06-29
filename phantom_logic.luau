--[[
    Phantom Ball logic
]]

local SCRIPT_VERSION = "10.0"
local SCRIPT_NAME    = "Phantom Ball logic"

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Replicated = game:GetService("ReplicatedStorage")
local Stats      = game:GetService("Stats")
local UIS        = game:GetService("UserInputService")

local lp, ws = Players.LocalPlayer, workspace
local now    = os.clock
local INF    = math.huge
local V3     = Vector3.zero

local C = {
    DECAY = 0.310, HOLD = 0.20, REACT_CD = 0.120,
    BALL_RANGE = 18, BALL_HARD_CAP = 22, MAX_BALL_DIST = 45,
    PANIC_DIST = 6, PANIC_BALL = 10,
    CLOSE_HOLD_DIST = 5,
    MIN_TARGET_HITS = 18, CPS_WIN = 1.0, MIN_DANGER = 50,
    TIMP_FAR = 0.220,
    SPD_FAST = 65, SPD_MID = 40, SPD_LOW = 20,
    OFF_PANIC = 0.090, OFF_FAST = 0.050, OFF_MID = 0.060,
    OFF_LOW = 0.070, OFF_VLOW = 0.090,
    COLD_TIMP_CAP = 0.210, MIN_HOLD = 0.050,
    CLOSE_HOLD_MS = 0.180, CLOSE_HOLD_DIST_MAX = 8,
    TIMP_RISE_FLOOR = 0.008, TIMP_RISE_N_OF_M = 3,
    REARM_HYST_FACTOR = 0.7, REARM_HYST_WIN = 0.250, REARM_COOLDOWN = 0.100,
    REENTRY_DIST = 22,
    FAST_BALL_SPD = 400, FAST_BALL_TIMP_CAP = 0.060,
    PREEMPT_DIST = 22, PREEMPT_TIMP_CAP = 0.120,
    PING_CREDIT_F = 0.5, PING_FLOOR = 0.040,
    PING_REF = 0.060, PING_MAX_SCALE = 1.0,
    COLD_PING_SCALE = 0.4, FAST_PING_SCALE = 0.5,
    DANGER_INSTANT = 120,
}

local P = {
    CD = 0.08, FIRE_LOCK = 0.080, MIN_SPD = 3,
    DEFLECT_R = 8, RAD_FLOOR = 14,
    PING_F = 0.6, PING_RAD_CAP = 18, PING_FLOOR = 0.030,
    RES_BASE = 8.5, RES_PER_PARRY = 0.225, RES_CAP = 32,
    RES_HITBOX_PROX = 60, RES_HITBOX_OWN_WINDOW = 0.30,
}

local PING_EMA, PING_MAX, PING_SAMPLE = 0.5, 0.150, 1.5
local TELEPORT_LOCK, SYNC_FRESH_T, RING_BUF = 0.20, 1.0, 8
local BALL_CACHE_TTL, LIVE_TIMP_TTL = 0.5, 0.05
local PING_BOOT_FALLBACK, PARRY_PROBE_INTERVAL = 0.060, 3.0
local DEFAULT_CPS = 25

local Config = {
    AutoParry = true, ManualSpam = false, AutoClash = true,
    CPS = DEFAULT_CPS, CustomCPS = false,
    Keybind = Enum.KeyCode.F9, SpamKeybind = Enum.KeyCode.F, SpamMode = "Toggle",
}
local State = { active = true, conns = {} }

local S = {
    ball = nil, lastTarget = -999,
    clashOn = false, clashAt = 0, clashHoldUntil = 0, lastClashOff = 0,
    lastClashReact = 0,
    smoothPing = 0.05, pingTimer = 0, lastFireAt = 0,
    teleportLockUntil = 0,
    targetRing    = table.create(RING_BUF, 0),
    targetRingIdx = 0,
    targetCps = 0,
    dangerEma = 0,
    lastTImp = 0, lastTImpAt = 0, tImpRising = false,
    tImpRiseHist = {0, 0, 0},
}

local Sync = {
    Speed = 0, RealPos = V3,
    ForceDir = false, ForcedDir = V3, DeflectDir = V3,
    Grace = false, Teleported = false,
    Target = -999, lastSyncAt = 0, forcedAt = 0,
}

local AP = { armed = false, fired = false, firedAt = 0 }
local parryR, parryMode, parryInit = nil, nil, false
local _ball, _ballAt = nil, 0

local RES = {
    owned = false, stack = 0, lastHitboxAt = 0,
    lastFireBallRef = nil, lastFireBallAt = 0,
}

local function checkResilienceInRoot(root)
    if not root then return false end
    for _, c in ipairs(root:GetChildren()) do
        local n = c.Name
        if n == "Resilience" or n == "ResilienceAbility" then return true end
    end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ValueBase") and type(d.Value) == "string" and d.Value == "Resilience" then
            return true
        end
    end
    return false
end

local function refreshResilience()
    local v = checkResilienceInRoot(lp:FindFirstChild("Backpack"))
           or checkResilienceInRoot(lp.Character)
    local prev = RES.owned
    RES.owned = v
    if prev and not v then
        RES.stack = 0
        RES.lastFireBallRef, RES.lastFireBallAt = nil, 0
    end
end

local function serverDeflectDistance()
    if not RES.owned then return P.RES_BASE end
    local bonus = math.min(RES.stack * P.RES_PER_PARRY, P.RES_CAP - P.RES_BASE)
    return P.RES_BASE + bonus
end

_G.PhantomConfig = Config
_G.PhantomState  = State
_G.PhantomManual = false
_G.PhantomAutoClash = true
_G.PhantomSaveConfig = function(c)
    if type(c) == "table" then
        for k, v in pairs(c) do Config[k] = v end
    end
end
_G.PhantomStop = function()
    State.active = false
    for i = #State.conns, 1, -1 do
        pcall(State.conns[i].Disconnect, State.conns[i])
        State.conns[i] = nil
    end
    _G.PhantomManual = false
    _G.__phantomGUI_loaded = nil
    _G.__phantomGUI_src    = nil
    _G.PhantomDiag        = nil
end

local function track(c)
    if c and c.Disconnect then State.conns[#State.conns + 1] = c end
    return c
end

local function cps()
    local c = tonumber(Config.CPS) or DEFAULT_CPS
    return c < 1 and 1 or c
end

local function resetAllState()
    parryR, parryMode, parryInit = nil, nil, false

    S.ball, S.lastTarget = nil, -999
    S.clashOn, S.clashAt, S.clashHoldUntil, S.lastClashOff = false, 0, 0, 0
    S.lastClashReact, S.lastFireAt, S.teleportLockUntil = 0, 0, 0
    for i = 1, RING_BUF do S.targetRing[i] = 0 end
    S.targetRingIdx = 0
    S.targetCps = 0
    S.dangerEma = 0
    S.lastTImp, S.lastTImpAt, S.tImpRising = 0, 0, false
    S.tImpRiseHist[1] = 0; S.tImpRiseHist[2] = 0; S.tImpRiseHist[3] = 0

    Sync.Speed, Sync.RealPos = 0, V3
    Sync.ForceDir, Sync.ForcedDir, Sync.DeflectDir = false, V3, V3
    Sync.Grace, Sync.Teleported = false, false
    Sync.Target, Sync.lastSyncAt, Sync.forcedAt = -999, 0, 0

    AP.armed, AP.fired, AP.firedAt = false, false, 0

    _G.PhantomManual = false
    _ball, _ballAt = nil, 0

    RES.stack, RES.lastHitboxAt = 0, 0
    RES.lastFireBallRef, RES.lastFireBallAt = nil, 0
end

local function getPing()
    local p = S.smoothPing
    if p <= 0 then p = PING_BOOT_FALLBACK end
    return math.clamp(p * 0.5, 0, PING_MAX)
end

local function samplePing()
    local ok, p = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    if ok and type(p) == "number" and p > 0 and p < 0.5 then
        S.smoothPing = S.smoothPing * (1 - PING_EMA) + p * PING_EMA
    end
end

local TSFolder   = Replicated:FindFirstChild("TS")
local Remotes    = Replicated:FindFirstChild("Remotes")
local GenRemotes = TSFolder and TSFolder:FindFirstChild("GeneratedNetworkRemotes")
local abilFolder = TSFolder and TSFolder:FindFirstChild("Abilities")
local GameInfo   = TSFolder and (function()
    local m = TSFolder:FindFirstChild("GameInfo")
    if m and m:IsA("ModuleScript") then
        local ok, r = pcall(require, m)
        return ok and r or nil
    end
end)() or nil

local function safeReq(m)
    if not (m and m:IsA("ModuleScript")) then return nil end
    local ok, r = pcall(require, m)
    return ok and r or nil
end

local Deflect = (abilFolder and safeReq(abilFolder:FindFirstChild("DeflectAbility")) or {}).DeflectAbility or {}

local function refreshRefs()
    if not (TSFolder and TSFolder.Parent) then
        TSFolder = Replicated:FindFirstChild("TS")
        GenRemotes = TSFolder and TSFolder:FindFirstChild("GeneratedNetworkRemotes")
        abilFolder = TSFolder and TSFolder:FindFirstChild("Abilities")
        if abilFolder then
            Deflect = (safeReq(abilFolder:FindFirstChild("DeflectAbility")) or {}).DeflectAbility or {}
        end
    end
    if not (Remotes and Remotes.Parent) then
        Remotes = Replicated:FindFirstChild("Remotes")
    end
end

local function validRemote(r)
    return typeof(r) == "Instance" and r.Parent ~= nil and r:IsA("RemoteEvent")
end

local function getGlobal()
    if type(getfenv) ~= "function" or type(Deflect) ~= "table" then return _G end
    for _, fn in ipairs({ Deflect.Deflect, Deflect.OnClientCreate, Deflect.constructor }) do
        if type(fn) == "function" then
            local ok, env = pcall(getfenv, fn)
            if ok and type(env) == "table" then
                local g = rawget(env, "_G")
                return (type(g) == "table" and g or env)
            end
        end
    end
    return _G
end

local function setGlobal(k, v)
    local g = getGlobal()
    if type(g) == "table" then rawset(g, k, v) end
end

local function cacheRemote(r, mode)
    if not validRemote(r) then return nil end
    if r.Name == "RE_1" then mode = "event" end
    parryR, parryMode = r, mode
    if mode == "buffer" then setGlobal("did", r) end
    return r, mode
end

local function resolveRemote()
    refreshRefs()
    if parryR and (not parryR.Parent or not parryR:IsA("RemoteEvent")) then
        parryR, parryMode, parryInit = nil, nil, false
    end
    if validRemote(parryR) then return parryR, parryMode end

    local did = rawget(getGlobal(), "did")
    if validRemote(did) then return cacheRemote(did, "buffer") end

    if Remotes then
        local r = Remotes:FindFirstChild("pr_" .. tostring(lp.UserId))
        if validRemote(r) then return cacheRemote(r, "buffer") end
    end
    if GenRemotes then
        local r = GenRemotes:FindFirstChild("RE_1")
        if validRemote(r) then return cacheRemote(r, "event") end
    end
    return nil
end

local cooldownFrame = nil

local function getCooldownFrame()
    if cooldownFrame and cooldownFrame.Parent then return cooldownFrame end
    cooldownFrame = nil
    local gui = lp:FindFirstChild("PlayerGui")
    if not gui then return nil end
    return gui:FindFirstChild("Interface.HUD.Bottom.Deflect.Button.CooldownClipping.Cooldown", true)
end

local function probeNamedRemoteEvents()
    if not Remotes then return nil end
    local cd = getCooldownFrame()
    local pInit, pFire = makeBuf(2), makeBuf(1)
    if not (cd and pInit and pFire) then return nil end

    local baseline = cd.Size
    local candidates = {}
    local direct = Remotes:FindFirstChild("pr_" .. tostring(lp.UserId))
    if typeof(direct) == "Instance" and type(direct.FireServer) == "function" then
        candidates[1] = direct
    end
    for _, r in Remotes:GetChildren() do
        if r.Name == "RemoteEvent" and typeof(r) == "Instance"
            and type(r.FireServer) == "function" then
            candidates[#candidates + 1] = r
        end
    end

    for _, r in ipairs(candidates) do
        if r and r.Parent then
            pcall(r.FireServer, r, pInit); task.wait(0.03)
            pcall(r.FireServer, r, pFire); task.wait(0.08)
            local s = cd.Size
            if not (s.X.Scale == baseline.X.Scale and s.X.Offset == baseline.X.Offset
                and s.Y.Scale == baseline.Y.Scale and s.Y.Offset == baseline.Y.Offset) then
                cacheRemote(r, "buffer")
                parryInit = true
                return parryR, parryMode
            end
        end
    end
    return nil
end

local function makeBuf(flag)
    if type(buffer) ~= "table" then return nil end
    if type(buffer.fromstring) == "function" then
        return buffer.fromstring(flag == 2 and "\2" or "\1")
    end
    if type(buffer.create) == "function" and type(buffer.writeu8) == "function" then
        local b = buffer.create(1)
        buffer.writeu8(b, 0, flag)
        return b
    end
end

local function initParry()
    if parryInit then return true end
    local r, m = resolveRemote()
    if not r then return false end
    if m == "event" then parryInit = true; return true end
    local p = makeBuf(2)
    if not p then return false end
    parryInit = pcall(r.FireServer, r, p)
    return parryInit
end

local function fireParry(r, m, flag)
    if not validRemote(r) then return false end
    if m == "event" then return pcall(r.FireServer, r) end
    local p = makeBuf(flag or 1)
    if not p then return false end
    initParry()
    return pcall(r.FireServer, r, p)
end

local _apResolveCache, _spamResolveCache, _spamCooldownUntil = 0, 0, 0

local function sendParry()
    local r, m = parryR, parryMode
    local t = now()
    if (not validRemote(r)) or (t - _apResolveCache) > 3.0 then
        r, m = resolveRemote()
        _apResolveCache = t
    end
    if r and fireParry(r, m, 1) then
        S.lastFireAt = t
        local ball = getBall()
        if ball then
            RES.lastFireBallRef = ball
            RES.lastFireBallAt = t
        end
        return true
    end
    return false
end

local function sendSpam()
    local t = now()
    if t < _spamCooldownUntil then return false end
    local r, m = parryR, parryMode
    if (not (r and r.Parent and r:IsA("RemoteEvent"))) or (t - _spamResolveCache) > 3.0 then
        r, m = resolveRemote()
        _spamResolveCache = t
    end
    if r and fireParry(r, m, 1) then
        S.lastFireAt = t
        local ball = getBall()
        if ball then
            RES.lastFireBallRef = ball
            RES.lastFireBallAt = t
        end
        return true
    end
    _spamCooldownUntil = t + 0.25
    parryR, parryMode, parryInit = nil, nil, false
    return false
end

local function getBall()
    local t = now()
    if _ball and _ball.Parent and (t - _ballAt) < BALL_CACHE_TTL then
        return _ball
    end
    if GameInfo and typeof(GameInfo) == "table" then
        local bm = GameInfo.BallModel
        if typeof(bm) == "Instance" and bm.Parent ~= nil then
            _ball, _ballAt = bm, t
            return bm
        end
    end
    if ws then
        local b = ws:FindFirstChild("GameBall", true)
        if b and b.Parent then
            _ball, _ballAt = b, t
            return b
        end
    end
    _ball, _ballAt = nil, t
    return nil
end

local _nearestCache = { d = 1e9, alive = false, at = 0, hrp = nil }

local function nearestPlayerAlive(hrp)
    local t = now()
    if (t - _nearestCache.at) < 0.1 and hrp == _nearestCache.hrp then
        return _nearestCache.d, _nearestCache.alive
    end
    local bestD, bestAlive = INF, false
    local hrpPos = hrp.Position
    for _, p in Players:GetPlayers() do
        if p ~= lp then
            local ch = p.Character
            if ch then
                local php = ch:FindFirstChild("HumanoidRootPart")
                local hum = ch:FindFirstChildOfClass("Humanoid")
                if php and php.Parent and hum and hum.Parent and hum.Health > 0 then
                    local d = (hrpPos - php.Position).Magnitude
                    if d < bestD then bestD, bestAlive = d, true end
                end
            end
        end
    end
    _nearestCache.d, _nearestCache.alive = bestD, bestAlive
    _nearestCache.at, _nearestCache.hrp = t, hrp
    return bestD, bestAlive
end

local function ballSpeed(ball, t)
    if (t - Sync.lastSyncAt) < SYNC_FRESH_T and Sync.Speed > 0 then return Sync.Speed end
    local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
    local localSpd = (ok and typeof(av) == "Vector3") and av.Magnitude or 0
    if localSpd < 1 and Sync.Speed > 0 and (t - Sync.lastSyncAt) < 2.0 then return Sync.Speed end
    return localSpd
end

local function ballPos(ball, t)
    if (t - Sync.lastSyncAt) < SYNC_FRESH_T and Sync.RealPos ~= V3 then
        return Sync.RealPos
    end
    if Sync.RealPos ~= V3 and Sync.Speed > 0 and (t - Sync.lastSyncAt) < 2.0 then
        local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
        if ok and typeof(av) == "Vector3" and av.Magnitude > 1 then
            return Sync.RealPos + av * (t - Sync.lastSyncAt)
        end
    end
    return ball.Position
end

local function pingOneWay() return math.max(getPing(), C.PING_FLOOR) end

local function pingScale()
    return math.clamp((pingOneWay() - C.PING_REF) / C.PING_REF, 0, C.PING_MAX_SCALE)
end

local function tImpCompensated(raw, spd)
    if spd < 1 then return INF end
    return math.max((raw - math.min(raw, spd * pingOneWay() * C.PING_CREDIT_F)) / spd, 0)
end

local function pingAdjustedCap(base, scaleAmt)
    return base * (1 - scaleAmt * pingScale())
end

local _liveTImpCache = { tImp = INF, spd = 0, at = 0 }

local function liveTImp()
    local n = now()
    if (n - _liveTImpCache.at) < LIVE_TIMP_TTL then return _liveTImpCache end
    local hr = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local ball = getBall()
    if hr and hr.Parent and ball and ball.Parent then
        local spd = 0
        local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
        if ok and typeof(av) == "Vector3" then spd = av.Magnitude end
        if spd < 1 then
            _liveTImpCache.tImp, _liveTImpCache.spd, _liveTImpCache.at = INF, spd, n
            return _liveTImpCache
        end
        _liveTImpCache.tImp = tImpCompensated((hr.Position - ball.Position).Magnitude, spd)
        _liveTImpCache.spd, _liveTImpCache.at = spd, n
    end
    return _liveTImpCache
end

local function isTargeted()
    return Sync.Target == lp.UserId
        or S.lastTarget == lp.UserId
        or ws:GetAttribute("GameBallTarget") == lp.UserId
end

local function updateTargetCps(t)
    local winStart = t - C.CPS_WIN
    local cnt = 0
    for i = 1, RING_BUF do
        if S.targetRing[i] >= winStart then cnt = cnt + 1 end
    end
    S.targetCps = cnt / C.CPS_WIN
end

local function ringPush(t)
    S.targetRingIdx = (S.targetRingIdx % RING_BUF) + 1
    S.targetRing[S.targetRingIdx] = t
end

local _ctxCache = { t = 0, valid = false }
local _ctxBuf = {}

local function clashSnapshot()
    local t = now()
    if _ctxCache.valid and (t - _ctxCache.t) < 0.016 then return _ctxBuf end

    local hr = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not (hr and hr.Parent) then
        _ctxCache.valid = false
        return nil
    end
    updateTargetCps(t)

    local ball = getBall()
    if not (ball and ball.Parent) then
        _ctxCache.valid = false
        return nil
    end

    local nearest, nearestAlive = nearestPlayerAlive(hr)
    local hrpPos = hr.Position
    local ballPosV = ball.Position
    local bDist = (hrpPos - ballPosV).Magnitude
    local panic = nearestAlive
        and (nearest <= C.PANIC_DIST and bDist <= C.PANIC_BALL)

    local live = liveTImp()
    local tImp, spd = live.tImp, live.spd
    if spd < 1 then
        local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
        spd = (ok and typeof(av) == "Vector3") and av.Magnitude or 0
        if spd > 1 then
            tImp = tImpCompensated(bDist, spd)
        end
    end

    _ctxBuf.t = t
    _ctxBuf.hr = hr
    _ctxBuf.hrpPos = hrpPos
    _ctxBuf.ball = ball
    _ctxBuf.ballPos = ballPosV
    _ctxBuf.nearest = nearest
    _ctxBuf.nearestAlive = nearestAlive
    _ctxBuf.bDist = bDist
    _ctxBuf.panic = panic
    _ctxBuf.tImp = tImp
    _ctxBuf.spd = spd

    _ctxCache.t, _ctxCache.valid = t, true
    return _ctxBuf
end

local function offLimitFor(spd, panic)
    if panic then return C.OFF_PANIC end
    if spd >= C.SPD_FAST then return C.OFF_FAST end
    if spd >= C.SPD_MID  then return C.OFF_MID  end
    if spd >= C.SPD_LOW  then return C.OFF_LOW  end
    return C.OFF_VLOW
end

local function shouldActivateClash()
    if S.clashOn then return false end
    local ctx = clashSnapshot()
    if not ctx then return false end
    local t, bDist, panic, tImp, spd = ctx.t, ctx.bDist, ctx.panic, ctx.tImp, ctx.spd

    if (t - S.lastClashOff) < C.REARM_COOLDOWN then return false end
    if (t - S.lastClashReact) < C.REACT_CD then return false end

    local danger = (spd >= 1 and tImp > 0) and (spd / tImp) or 0
    S.dangerEma = S.dangerEma * 0.70 + danger * 0.30

    local targetIsMe = isTargeted()
    local coldCapAdj = pingAdjustedCap(C.COLD_TIMP_CAP, C.COLD_PING_SCALE)

    local trigInstant = (spd >= C.FAST_BALL_SPD * 0.5)
        and (tImp > 0 and tImp <= coldCapAdj * 0.9)
        and targetIsMe
    local trigDanger   = S.dangerEma >= C.MIN_DANGER
    local trigTargeted = targetIsMe and tImp <= coldCapAdj
    local trigPanic    = panic

    if not (trigInstant or trigDanger or trigTargeted or trigPanic) then return false end

    local dangerOK = panic or trigInstant or S.dangerEma >= C.MIN_DANGER
    if not dangerOK then return false end

    local coldGate = (panic
        or (targetIsMe and bDist <= C.REENTRY_DIST and tImp <= coldCapAdj))
        and dangerOK
    if not coldGate then return false end

    local recentTargets = 0
    for i = 1, RING_BUF do
        if S.targetRing[i] >= t - C.CPS_WIN then recentTargets = recentTargets + 1 end
    end
    if not panic and recentTargets < C.MIN_TARGET_HITS then return false end

    local baseCap = (spd >= C.FAST_BALL_SPD)
        and pingAdjustedCap(C.FAST_BALL_TIMP_CAP, C.FAST_PING_SCALE)
        or coldCapAdj

    local inHystWin = (t - S.lastClashOff) < C.REARM_HYST_WIN
    local tImpCap   = (panic or not (S.lastClashOff > 0 and inHystWin))
        and baseCap
        or baseCap * C.REARM_HYST_FACTOR

    if not panic and tImp > tImpCap then return false end
    return true
end

local function shouldDeactivateClash()
    if not S.clashOn then return false end
    local t = now()
    if (t - S.clashAt) < C.MIN_HOLD then return false end

    local ctx = clashSnapshot()
    if not ctx then return false end
    local hr, ball, bDist, panic, tImp, spd = ctx.hr, ctx.ball, ctx.bDist, ctx.panic, ctx.tImp, ctx.spd

    local rising = false
    if S.lastTImpAt > 0 then
        local dt = t - S.lastTImpAt
        if dt > 0 then
            local dTImp = tImp - S.lastTImp
            S.tImpRiseHist[1] = S.tImpRiseHist[2]
            S.tImpRiseHist[2] = S.tImpRiseHist[3]
            S.tImpRiseHist[3] = (dTImp > C.TIMP_RISE_FLOOR) and 1 or 0
            local cnt = S.tImpRiseHist[1] + S.tImpRiseHist[2] + S.tImpRiseHist[3]
            S.tImpRising = (cnt >= C.TIMP_RISE_N_OF_M)
            rising = S.tImpRising
        end
    end
    S.lastTImp, S.lastTImpAt = tImp, t

    local targetIsMe = isTargeted()
    if not targetIsMe and not panic then return true end
    if bDist > C.BALL_HARD_CAP + 5 and not panic then return true end

    if not panic and bDist <= C.CLOSE_HOLD_DIST_MAX then
        if (t - S.clashAt) < C.CLOSE_HOLD_MS then return false end
    end

    if tImp > 0.150 then return true end
    if tImp > C.TIMP_FAR then return true end

    local limit = offLimitFor(spd, panic)
    if rising and tImp > limit then return true end
    if rising and bDist > C.BALL_HARD_CAP and not panic then return true end

    if rising and spd >= 1 and bDist > C.CLOSE_HOLD_DIST then
        local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
        if ok and typeof(av) == "Vector3" then
            local toMe = (ctx.hrpPos - ctx.ballPos) / bDist
            if av.Unit:Dot(toMe) < 0 then return true end
        end
    end
    return false
end

local function clearClash()
    S.clashOn = false
    S.clashHoldUntil = 0
    S.lastClashOff = now()
end

local function evaluateClash()
    if Config.AutoClash == false or _G.PhantomManual then
        if S.clashOn then clearClash() end
        return
    end
    if S.clashOn then
        if shouldDeactivateClash() then clearClash() end
        return
    end
    if shouldActivateClash() then
        local t = now()
        S.clashOn, S.clashAt = true, t
        S.clashHoldUntil = t + C.HOLD
        S.lastClashReact = t
        S.lastClashOff = 0
        S.lastTImp, S.lastTImpAt, S.tImpRising = 0, 0, false
        S.tImpRiseHist[1] = 0; S.tImpRiseHist[2] = 0; S.tImpRiseHist[3] = 0
    end
end

local apBind, apDead = 0, false
local function bindParry(ch)
    apBind = apBind + 1
    if apDead or not (ch and ch.Parent) then return end
    local id = apBind
    local hrp = ch:FindFirstChild("HumanoidRootPart") or ch:WaitForChild("HumanoidRootPart", 1)
    if id ~= apBind or not (hrp and hrp.Parent) then return end
    AP.fired, AP.armed = false, false

    track(RunService.Heartbeat:Connect(function(dt)
        if apDead or id ~= apBind or not (ch.Parent and hrp.Parent) then return end
        if Config.AutoParry ~= true then return end
        local t = now()

        if t < S.teleportLockUntil or Sync.Grace then return end
        if S.clashOn or _G.PhantomManual then return end

        local ball = getBall()
        if not (ball and ball.Parent) then return end
        if Sync.Target ~= lp.UserId then AP.armed = false; return end

        local syncFresh = (t - Sync.lastSyncAt) < 0.3
        local bp = (syncFresh and Sync.RealPos ~= V3) and Sync.RealPos or ball.Position

        local spd
        if syncFresh and Sync.Speed > 0 then
            spd = Sync.Speed
        else
            local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
            spd = (ok and typeof(av) == "Vector3") and av.Magnitude or 0
        end
        if spd < P.MIN_SPD then return end

        local parryRad = serverDeflectDistance() + spd * 0.13
        local pingBoost = pingOneWay() * spd * P.PING_F
        if pingBoost > P.PING_RAD_CAP then pingBoost = P.PING_RAD_CAP end
        parryRad = parryRad + pingBoost
        if spd < 25 and parryRad < 15 then parryRad = 15 end
        if parryRad < P.RAD_FLOOR then parryRad = P.RAD_FLOOR end

        local hrpPos = hrp.Position
        local dx, dy, dz = hrpPos.X - bp.X, hrpPos.Y - bp.Y, hrpPos.Z - bp.Z
        if (dx*dx + dy*dy + dz*dz) > parryRad * parryRad then return end

        if AP.fired then return end
        if AP.firedAt > Sync.lastSyncAt then return end
        if (t - AP.firedAt) < P.FIRE_LOCK then return end

        S.pingTimer = S.pingTimer + dt
        if S.pingTimer >= PING_SAMPLE then
            S.pingTimer = 0
            samplePing()
        end

        AP.fired, AP.firedAt, S.lastFireAt = true, t, t
        sendParry()
    end))

    track(ch.AncestryChanged:Connect(function(_, p)
        if not p then apBind = apBind + 1 end
    end))
end

local keyConn, keyHoldConn = nil, nil

local function installKeys()
    if keyConn then pcall(keyConn.Disconnect, keyConn); keyConn = nil end
    if keyHoldConn then pcall(keyHoldConn.Disconnect, keyHoldConn); keyHoldConn = nil end

    local panic, spam, mode = Config.Keybind, Config.SpamKeybind, Config.SpamMode or "Toggle"
    keyConn = UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == panic then
            clearClash()
            AP.fired = false
            _G.PhantomManual = false
        elseif i.KeyCode == spam then
            _G.PhantomManual = (mode == "Hold") or not _G.PhantomManual
        end
    end)
    track(keyConn)
    if mode == "Hold" then
        keyHoldConn = UIS.InputEnded:Connect(function(i)
            if i.KeyCode == spam then _G.PhantomManual = false end
        end)
        track(keyHoldConn)
    end
end

local CONFIG_KEYS = { "AutoParry", "AutoClash", "CPS", "CustomCPS", "Keybind", "SpamKeybind", "SpamMode" }
local guiReady = false
local _pollAcc = 0

local function applyConfig()
    local c = _G.PhantomConfig
    if type(c) ~= "table" then return end
    for _, k in ipairs(CONFIG_KEYS) do
        if c[k] ~= nil then Config[k] = c[k] end
    end
end

local function pollGUI(dt)
    applyConfig()
    if not guiReady then
        _pollAcc = _pollAcc + dt
        if _pollAcc >= 0.1 then
            _pollAcc, guiReady = 0, true
            installKeys()
        end
    end
end

installKeys()

local _spamRing = table.create(64, 0)
local _spamRingHead, _spamRingCount = 0, 0
local _spamDebt, _spamWinStart, _spamClickIdx, _spamWasActive = 0, now(), 0, false

local function _spamShouldRun()
    return S.clashOn or _G.PhantomManual == true
end

local function _spamRingPush(ts)
    _spamRingHead = (_spamRingHead % 64) + 1
    _spamRing[_spamRingHead] = ts
    if _spamRingCount < 64 then _spamRingCount = _spamRingCount + 1 end
end

local function tickSpam(dt)
    if not _spamShouldRun() then
        if _spamWasActive then
            _spamDebt = 0
            _spamRingHead, _spamRingCount = 0, 0
            _spamWinStart = now()
            _spamWasActive = false
        end
        return
    end
    _spamWasActive = true

    local t = now()
    if (t - _spamWinStart) > 1.5 then _spamWinStart = t end
    if dt > 1 then dt = 1 end
    _spamDebt = _spamDebt + dt
    local n = 0
    local cpsLocal = cps()
    while _spamDebt >= (1 / cpsLocal) and n < 3 do
        if not _spamShouldRun() then _spamDebt = 0; break end
        _spamClickIdx = _spamClickIdx + 1
        if sendSpam() then
            _spamRingPush(now())
        else
            _spamDebt = 0
            break
        end
        _spamDebt = _spamDebt - (1 / cpsLocal)
        n = n + 1
    end
end

local function bindChar(ch)
    if not (ch and ch.Parent) then return end
    local hrp = ch:WaitForChild("HumanoidRootPart", 9e9)
    if not (hrp and hrp.Parent) then return end
    local dead = false

    track(ch.AncestryChanged:Connect(function(_, p)
        if not p then
            dead = true
            resetAllState()
        end
    end))

    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then
        track(hum.Died:Connect(function()
            resetAllState()
        end))
    end

    track(RunService.Heartbeat:Connect(function(dt)
        if dead or not State.active then return end
        if not (ch.Parent and hrp.Parent) then dead = true; return end
        pollGUI(dt)
        evaluateClash()
        _ctxCache.valid = false
        tickSpam(dt)
    end))
end

local _resBackpackConn, _resCharConn = nil, nil

local function onChar(ch)
    resetAllState()

    if _resBackpackConn then pcall(_resBackpackConn.Disconnect, _resBackpackConn); _resBackpackConn = nil end
    if _resCharConn     then pcall(_resCharConn.Disconnect, _resCharConn);     _resCharConn = nil end

    local function bump() task.defer(refreshResilience) end

    local bp = lp:FindFirstChild("Backpack")
    if bp then
        _resBackpackConn = bp.ChildAdded:Connect(bump)
        track(_resBackpackConn)
    end
    if lp.Character then
        _resCharConn = lp.Character.ChildAdded:Connect(bump)
        track(_resCharConn)
        track(lp.Character.ChildRemoved:Connect(bump))
    end

    task.delay(0.5, function() pcall(refreshResilience) end)
    task.defer(function() pcall(bindParry, ch) end)
    task.defer(function() pcall(bindChar,  ch) end)
end

track(lp.CharacterAdded:Connect(onChar))
if lp.Character then task.defer(function() pcall(onChar, lp.Character) end) end

local ballSync = Remotes and Remotes:FindFirstChild("BallSyncData")
if ballSync and ballSync:IsA("RemoteEvent") then
    track(ballSync.OnClientEvent:Connect(function(d)
        if typeof(d) ~= "table" then return end
        local t = now()
        if type(d.Speed) == "number" then Sync.Speed = d.Speed end
        if typeof(d.RealPosition) == "Vector3" then Sync.RealPos = d.RealPosition end
        if typeof(d.DeflectDirection) == "Vector3" then Sync.DeflectDir = d.DeflectDirection end
        if type(d.Grace) == "boolean" then Sync.Grace = d.Grace end
        if type(d.ForceDirection) == "boolean" then
            if d.ForceDirection and not Sync.ForceDir then Sync.forcedAt = t end
            Sync.ForceDir = d.ForceDirection
        end
        if typeof(d.ForcedDirection) == "Vector3" then Sync.ForcedDir = d.ForcedDirection end
        Sync.lastSyncAt = t

        if d.Teleported == true then
            S.teleportLockUntil = t + TELEPORT_LOCK
            AP.fired = false
            clearClash()
            if typeof(d.TeleportPosition) == "Vector3" then Sync.TeleportPosition = d.TeleportPosition end
            Sync.Teleported = true
            return
        end
        Sync.Teleported = false

        local newTarget = d.TargetPlayerID
        if newTarget == S.lastTarget then Sync.Target = newTarget; return end
        if newTarget ~= S.lastTarget and newTarget == lp.UserId then Sync.Grace = false end
        local prev = S.lastTarget
        S.lastTarget, Sync.Target = newTarget, newTarget
        ringPush(t)
        AP.armed = (newTarget == lp.UserId)
        AP.fired = false

        if newTarget ~= lp.UserId or Config.AutoClash == false or _G.PhantomManual
            or prev == lp.UserId or prev == -999
        then return end

        local hr   = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local ball = getBall()
        if not (hr and hr.Parent and ball and ball.Parent) then return end
        local bDist = (hr.Position - ball.Position).Magnitude
        local spd   = ballSpeed(ball, t)
        local tImpR = (spd > 1) and tImpCompensated(bDist, spd) or INF
        local near  = nearestPlayerAlive(hr)
        local panic = (near <= C.PANIC_DIST and bDist <= C.PANIC_BALL)
        local offPanicAdj = pingAdjustedCap(C.OFF_PANIC, C.FAST_PING_SCALE)

        if (bDist <= C.BALL_HARD_CAP or panic) and (panic or tImpR <= offPanicAdj)
            and (t - S.lastClashReact) >= C.REACT_CD
        then
            S.clashOn = true
            S.clashAt = t
            S.clashHoldUntil = panic and (t + C.HOLD) or 0
            S.lastClashReact = t
        end
    end))
end

local gameFolder  = ws:WaitForChild("Game", 30)
local ballWatcher = gameFolder and gameFolder:FindFirstChild("Ball")

local function setBall(b) _ball, _ballAt = b, now() end
local function clearBallRef(b) if b == _ball then _ball, _ballAt = nil, now() end end

if ballWatcher then
    track(ballWatcher.ChildAdded:Connect(function(c)
        if c.Name == "GameBall" and c:IsA("BasePart") then setBall(c) end
    end))
    track(ballWatcher.ChildRemoved:Connect(clearBallRef))
    local existing = ballWatcher:FindFirstChild("GameBall")
    if existing and existing:IsA("BasePart") then setBall(existing) end
end

local function revalidateParryRemote()
    if not (parryR and parryR:IsA("RemoteEvent") and parryR.Parent) then
        parryR, parryMode, parryInit = nil, nil, false
        if resolveRemote() then initParry() end
    end
end

local GUI_URL = "https://raw.githubusercontent.com/Repp35/Roblox/refs/heads/main/phantom_gui.lua"

task.spawn(function()
    local root = gameFolder or ws
    track(root.DescendantAdded:Connect(function(d)
        if not State.active or d.Name ~= "HitboxGrow" or not RES.owned then return end
        local t = now()
        if (t - RES.lastFireBallAt) > P.RES_HITBOX_OWN_WINDOW then return end
        if not (RES.lastFireBallRef and RES.lastFireBallRef.Parent) then return end
        if (t - RES.lastHitboxAt) < 0.4 then return end
        local dp = d.Position
        if typeof(dp) ~= "Vector3" then return end
        if (RES.lastFireBallRef.Position - dp).Magnitude > P.RES_HITBOX_PROX then return end
        RES.lastHitboxAt, RES.stack = t, RES.stack + 1
        local maxStack = math.floor((P.RES_CAP - P.RES_BASE) / P.RES_PER_PARRY)
        if RES.stack > maxStack then RES.stack = maxStack end
    end))
end)

task.spawn(function()
    for _ = 1, 3 do task.defer(samplePing); task.wait(0.2) end
    for tries = 1, 30 do
        pcall(function()
            refreshRefs()
            if resolveRemote() or probeNamedRemoteEvents() then initParry() end
        end)
        task.wait(1)
    end
end)

task.spawn(function()
    while State.active do
        pcall(revalidateParryRemote)
        task.wait(PARRY_PROBE_INTERVAL)
    end
end)

task.spawn(function()
    while State.active do
        if guiReady then applyConfig() end
        if not (_ball and _ball.Parent) then _ball, _ballAt = nil, 0; getBall() end
        task.wait(0.5)
    end
end)

task.defer(function()
    if _G.__phantomGUI_loaded then return end
    local src = rawget(_G, "__phantomGUI_src")
    if type(src) ~= "string" or #src == 0 then
        local ok, body = pcall(function()
            if type(request) == "function" then
                local r = request({ Url = GUI_URL, Method = "GET" })
                return r and r.Body
            end
            return type(game.HttpGet) == "function" and game:HttpGet(GUI_URL)
        end)
        if ok and type(body) == "string" and #body > 0 then src = body end
    end
    if type(src) ~= "string" or #src == 0 or type(loadstring) ~= "function" then return end
    local fn = loadstring(src)
    if not fn then return end
    _G.__phantomGUI_src = src
    if pcall(fn) then _G.__phantomGUI_loaded = true end
end)

task.defer(function()
    task.wait(0.1); pcall(refreshRefs); pcall(refreshResilience)
    print(("[%s v%s] iniciando... | GameId=%s | Place=%s | TS=%s | Remotes=%s | Ball=%s | Resilience=%s"):format(
        SCRIPT_NAME, SCRIPT_VERSION,
        tostring(game.GameId), tostring(game.PlaceId),
        TSFolder and "ok" or "nil", Remotes and "ok" or "nil",
        tostring(getBall() ~= nil), tostring(RES.owned)))
end)

local _diagLast = 0
local function pushDiagnostics()
    local t = now()
    if (t - _diagLast) < 0.5 then return end
    _diagLast = t
    _G.PhantomDiag = {
        version       = SCRIPT_VERSION,
        scriptName    = SCRIPT_NAME,
        gameId        = game.GameId,
        placeId       = game.PlaceId,
        placeName     = (game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "unknown"),
        tsOk          = TSFolder ~= nil,
        remotesOk     = Remotes ~= nil,
        parryRemote   = (parryR and parryR:GetFullName()) or nil,
        parryMode     = parryMode or nil,
        ballOk        = getBall() ~= nil,
        ballPath      = (function()
            local b = getBall()
            return b and b:GetFullName() or nil
        end)(),
        resilience    = RES.owned,
        resStack      = RES.stack,
        syncOk        = (now() - Sync.lastSyncAt) < 5,
        lastSyncAt    = Sync.lastSyncAt,
        ping          = S.smoothPing,
        cps           = Config.CPS,
        autoParry     = Config.AutoParry == true,
        autoClash     = Config.AutoClash == true,
        keybind       = Config.Keybind and Config.Keybind.Name or nil,
        spamKeybind   = Config.SpamKeybind and Config.SpamKeybind.Name or nil,
        spamMode      = Config.SpamMode or "Toggle",
        manualSpam    = _G.PhantomManual == true,
        updatedAt     = t,
    }
end

task.spawn(function()
    while State.active do
        pcall(pushDiagnostics)
        task.wait(0.5)
    end
end)
