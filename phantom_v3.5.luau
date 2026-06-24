-- PHANTOM — V9

-- ═══════════════════ SERVICES ═══════════════════
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Replicated = game:GetService("ReplicatedStorage")
local Stats      = game:GetService("Stats")
local UIS        = game:GetService("UserInputService")
local lp, ws     = Players.LocalPlayer, workspace
local now        = os.clock


-- ═══════════════════ TUNING ═══════════════════
local CLASH = {
    DECAY              = 0.310,
    HOLD               = 0.30,
    REACT_CD           = 0.120,
    BALL_RANGE         = 18,
    BALL_HARD_CAP      = 22,
    MAX_BALL_DIST      = 45,
    PANIC_DIST         = 6,
    PANIC_BALL         = 10,
    CPS_THRESH         = 10,
    CPS_WIN            = 1.0,
    MIN_DANGER         = 80,        -- dangerScore mínimo pra ativar (spd / tImp)
    TIMP_FAR           = 0.190,
    SPD_FAST           = 65,
    SPD_MID            = 40,
    SPD_LOW            = 20,
    OFF_PANIC          = 0.200,
    OFF_FAST           = 0.090,
    OFF_MID            = 0.110,
    OFF_LOW            = 0.130,
    OFF_VLOW           = 0.160,
    COLD_TIMP_CAP      = 0.180,
    REENTRY_DIST       = 22,
    FAST_BALL_SPD      = 200,
    FAST_BALL_CPS      = 0,
    FAST_BALL_TIMP_CAP = 0.100,
    PREEMPT_DIST       = 22,
    PREEMPT_TIMP_CAP   = 0.120,
    PING_CREDIT_F      = 0.5,
    PING_FLOOR         = 0.040,
    PING_REF           = 0.060,
    PING_MAX_SCALE     = 1.0,
    COLD_PING_SCALE    = 0.4,
    FAST_PING_SCALE    = 0.5,
    PREEMPT_PING_SCALE = 0.4,
}
local PARRY = {
    CD           = 0.08,
    MIN_SPD      = 3,
    DEFLECT_R    = 8,
    RAD_FLOOR    = 14,
    PING_F       = 0.6,
    PING_RAD_GAIN = 0,
    PING_RAD_CAP = 18,
    PING_FLOOR   = 0.030,
}
local PING_EMA, PING_MAX, PING_SAMPLE = 0.5, 0.150, 1.5
local TELEPORT_LOCK, FORCED_DIR_TTL    = 0.20, 0.20
local SYNC_FRESH_T                     = 1.0
local BALL_PROC_TIMP, RING_BUF         = 0.25, 8
local REARM   = { DIST = 4, DT_MAX = 0.1, MIN_SPD = 5 }
local SPAM    = { MAX_PER_ITER = 50, WIN = 1.5, DT_CAP = 1 }
local DEFAULT_CPS, BOOT_MAX_TRIES = 25, 30


-- ═══════════════════ CONFIG / STATE ═══════════════════
local Config = {
    AutoParry    = true,
    ManualSpam   = false,
    AutoClash    = true,
    CPS          = DEFAULT_CPS,
    CustomCPS    = false,
    Keybind      = Enum.KeyCode.F9,
    SpamKeybind  = Enum.KeyCode.F,
    SpamMode     = "Toggle",
}
local State = { active = true, conns = {} }
local __STATE_OK = true
local function _stateGuard()
    if type(State) ~= "table" or type(State.conns) ~= "table" then
        __STATE_OK = false
        State = { active = true, conns = {} }
    end
    if __STATE_OK and State.active == nil then State.active = true end
end
_stateGuard()

local S = {
    ball              = nil,
    lastTarget        = -999,
    clashOn           = false,
    clashAt           = 0,
    clashHoldUntil    = 0,
    lastClashReact    = 0,
    smoothPing        = 0.05,
    pingTimer         = 0,
    lastFireAt        = 0,
    teleportLockUntil = 0,
    targetRing        = {},
    targetRingIdx     = 0,
    targetCps         = 0,
    dangerEma         = 0,
    realCps           = 0,
    clickCount        = 0,
}
local Sync = {
    Speed        = 0,
    RealPos      = Vector3.zero,
    ForceDir     = false,
    ForcedDir    = Vector3.zero,
    DeflectDir   = Vector3.zero,
    Grace        = false,
    Teleported   = false,
    Target       = -999,
    lastSyncAt   = 0,
    forcedAt     = 0,
}
local AP = {
    armed         = false,
    fired         = false,
    firedAt       = 0,
    lastBallPos   = nil,
    lastBallPosAt = 0,
}
local AP_LOCAL = {
    ballProcessed = false,
    forceRelease  = nil,
    armed         = false,
    fired         = false,
}

local parryR, parryMode, parryInit = nil, nil, false
local parryPath = nil
local PARRY_PROBE_INTERVAL = 3.0
local _ballCache, _ballCacheAt = nil, 0
local SPAM_BUF

_G.PhantomConfig = Config
_G.PhantomState  = State
_G.PhantomManual = false
_G.PhantomAutoClash = true
_G.PhantomSaveConfig = function(c)
    if type(c) == "table" then
        for k, v in pairs(c) do
            Config[k] = v
        end
    end
end
_G.PhantomStop = function()
    _stateGuard()
    State.active = false
    disconnectAll()
    _G.PhantomManual = false
    print("[PHANTOM] stop()")
end


-- ═══════════════════ UTILS ═══════════════════
local function track(c)
    _stateGuard()
    if not __STATE_OK then return c end
    if c and c.Disconnect then
        State.conns[#State.conns + 1] = c
    end
    return c
end

local function disconnectAll()
    _stateGuard()
    if not __STATE_OK then return end
    for i = #State.conns, 1, -1 do
        pcall(State.conns[i].Disconnect, State.conns[i])
        State.conns[i] = nil
    end
end

local function cps()
    local c = tonumber(Config.CPS) or DEFAULT_CPS
    return c < 1 and 1 or c
end


-- ═══════════════════ RESET TOTAL ═══════════════════
local function resetAllState()
    parryR, parryMode, parryInit = nil, nil, false
    parryPath = nil

    S.ball              = nil
    S.lastTarget        = -999
    S.clashOn           = false
    S.clashAt           = 0
    S.clashHoldUntil    = 0
    S.lastClashReact    = 0
    S.lastFireAt        = 0
    S.teleportLockUntil = 0
    S.targetRing        = {}
    S.targetRingIdx     = 0
    S.targetCps         = 0
    S.dangerEma         = 0
    S.realCps           = 0
    S.clickCount        = 0

    Sync.Speed      = 0
    Sync.RealPos    = Vector3.zero
    Sync.ForceDir   = false
    Sync.ForcedDir  = Vector3.zero
    Sync.DeflectDir = Vector3.zero
    Sync.Grace      = false
    Sync.Teleported = false
    Sync.Target     = -999
    Sync.lastSyncAt = 0
    Sync.forcedAt   = 0

    AP.armed         = false
    AP.fired         = false
    AP.firedAt       = 0
    AP.lastBallPos   = nil
    AP.lastBallPosAt = 0

    AP_LOCAL.ballProcessed = false
    AP_LOCAL.forceRelease  = nil
    AP_LOCAL.armed         = false
    AP_LOCAL.fired         = false

    _G.PhantomManual        = false
    _G.__lt_clashActive     = false
    _G.__lt_lastTarget      = -999
    _G.__lt_ballProcessed   = false
    _G.__phantomBall        = nil
    _ballCache, _ballCacheAt = nil, 0
end


-- ═══════════════════ PING ═══════════════════
local PING_BOOT_FALLBACK = 0.060
local function getPing()
    local p = S.smoothPing
    if p <= 0 then p = PING_BOOT_FALLBACK end
    local oneWay = p * 0.5
    if oneWay < 0         then return 0         end
    if oneWay > PING_MAX  then return PING_MAX  end
    return oneWay
end

local function samplePing()
    local ok, p = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    if ok and type(p) == "number" and p > 0 and p < 0.5 then
        S.smoothPing = S.smoothPing * (1 - PING_EMA) + p * PING_EMA
    end
end


-- ═══════════════════ MODULES / REFS ═══════════════════
local TSFolder, Remotes = Replicated:FindFirstChild("TS"), Replicated:FindFirstChild("Remotes")
local GenRemotes = TSFolder and TSFolder:FindFirstChild("GeneratedNetworkRemotes")
local enumFolder = TSFolder and TSFolder:FindFirstChild("Enums")
local abilFolder = TSFolder and TSFolder:FindFirstChild("Abilities")
local TouchTap   = Replicated:FindFirstChild("TouchTap")

local function safeReq(m)
    if not (m and m:IsA("ModuleScript")) then return nil end
    local ok, r = pcall(require, m)
    return ok and r or nil
end

local AbilityID   = (enumFolder and safeReq(enumFolder:FindFirstChild("AbilityID"))    or {}).AbilityID   or { Deflect = "Deflect" }
local Deflect     = (abilFolder and safeReq(abilFolder:FindFirstChild("DeflectAbility")) or {}).DeflectAbility or {}
local BindableMgr = TSFolder and safeReq(TSFolder:FindFirstChild("BindableManager"))
local GameInfo    = (TSFolder and safeReq(TSFolder:FindFirstChild("GameInfo"))         or {}).GameInfo
local BR          = (TSFolder and safeReq(TSFolder:FindFirstChild("BallReplicator"):FindFirstChild("BallReplicator")) or {}).BallReplicator

local function refreshRefs()
    if TSFolder and not TSFolder.Parent then
        TSFolder    = Replicated:FindFirstChild("TS")
        GenRemotes  = TSFolder and TSFolder:FindFirstChild("GeneratedNetworkRemotes")
    end
    if not Remotes or not Remotes.Parent then
        Remotes = Replicated:FindFirstChild("Remotes")
    end
end


-- ═══════════════════ PARRY REMOTE ═══════════════════
local cooldownFrame = nil
local function getCooldownFrame()
    if cooldownFrame and cooldownFrame.Parent then return cooldownFrame end
    local ok, frame = pcall(function()
        return lp:FindFirstChild("PlayerGui"):WaitForChild("Interface", 1):WaitForChild("HUD", 1)
            :WaitForChild("Bottom", 1):WaitForChild("Deflect", 1):WaitForChild("Button", 1)
            :WaitForChild("CooldownClipping", 1):WaitForChild("Cooldown", 1)
    end)
    if ok and frame then cooldownFrame = frame end
    return cooldownFrame
end

local function validRemote(r)
    return typeof(r) == "Instance" and r.Parent ~= nil and r:IsA("RemoteEvent")
end

local function getGlobal()
    if type(getfenv) ~= "function" or type(Deflect) ~= "table" then return _G, _G end
    for _, fn in ipairs({ Deflect.Deflect, Deflect.OnClientCreate, Deflect.constructor }) do
        if type(fn) == "function" then
            local ok, env = pcall(getfenv, fn)
            if ok and type(env) == "table" then
                local g = rawget(env, "_G")
                return (type(g) == "table" and g or env), env
            end
        end
    end
    return _G, _G
end

local function setGlobal(k, v)
    local g, env = getGlobal()
    if type(g) == "table"    then rawset(g,   k, v) end
    if type(env) == "table" and env ~= g then rawset(env, k, v) end
end

local function cacheRemote(r, mode)
    if not validRemote(r) then return nil end
    parryR, parryMode = r, mode
    parryPath = {
        folder   = r.Parent,
        name     = r.Name,
        fullName = r:GetFullName(),
    }
    if mode == "buffer" then setGlobal("did", r) end
    return r, mode
end

local function resolveRemote()
    refreshRefs()
    if parryR and (not parryR.Parent or not parryR:IsA("RemoteEvent")) then
        parryR, parryMode, parryInit = nil, nil, false
        parryPath = nil
    end
    if validRemote(parryR) then return parryR, parryMode end

    local g, _ = getGlobal()
    local did  = type(g) == "table" and rawget(g, "did")
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

local function revalidateParryRemote()
    if not (parryR and parryPath) then return end
    if not validRemote(parryR) then
        warn("[PHANTOM] remote invalidado (Parent=nil), re-resolvendo...")
        parryR, parryMode, parryInit, parryPath = nil, nil, false, nil
        local r, m = resolveRemote()
        if r then initParry() end
        return
    end
    local currentFull = parryR:GetFullName()
    if currentFull ~= parryPath.fullName then
        warn(("[PHANTOM] remote path mudou (%s → %s), re-resolvendo..."):format(
            parryPath.fullName, currentFull))
        parryR, parryMode, parryInit, parryPath = nil, nil, false, nil
        local r, m = resolveRemote()
        if r then initParry() end
    end
end

task.spawn(function()
    while State.active do
        task.wait(PARRY_PROBE_INTERVAL)
        pcall(revalidateParryRemote)
    end
end)

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

local SPAM_BUF = (function()
    local ok, b = pcall(buffer.fromstring, "\1")
    return ok and b or nil
end)()

local function probeNamedRemoteEvents()
    refreshRefs()
    if not Remotes then return nil end
    local cd       = getCooldownFrame()
    local pInit    = makeBuf(2)
    local pFire    = makeBuf(1)
    if not (cd and pInit and pFire) then return nil end

    local baseline  = cd.Size
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

local function sendParry()
    local r, m = parryR, parryMode
    if not validRemote(r) then r, m = resolveRemote() end
    if r and fireParry(r, m, 1) then
        S.lastFireAt = now()
        return true
    end
    return false
end


-- ═══════════════════ BALL / PLAYERS ═══════════════════
local BALL_CACHE_TTL = 0.5
local function getBall()
    local t = now()
    if _ballCache and _ballCache.Parent and (t - _ballCacheAt) < BALL_CACHE_TTL then
        return _ballCache
    end

    local cached = _G.__phantomBall
    if cached and cached.Parent then
        _ballCache, _ballCacheAt = cached, t
        return cached
    end

    if GameInfo and typeof(GameInfo) == "table" then
        local bm = GameInfo.BallModel
        if typeof(bm) == "Instance" and bm.Parent ~= nil then
            _ballCache, _ballCacheAt = bm, t
            _G.__phantomBall = bm
            return bm
        end
    end

    if ws then
        local b = ws:FindFirstChild("GameBall", true)
        if b and b.Parent then
            _ballCache, _ballCacheAt = b, t
            _G.__phantomBall = b
            return b
        end
    end

    _ballCache, _ballCacheAt = nil, t
    return nil
end

local function nearestPlayer(hrp)
    local best = math.huge
    for _, p in Players:GetPlayers() do
        if p ~= lp and p.Character then
            local php = p.Character:FindFirstChild("HumanoidRootPart")
            if php and php.Parent then
                local d = (hrp.Position - php.Position).Magnitude
                if d < best then best = d end
            end
        end
    end
    return best
end

local function nearestPlayerAlive(hrp)
    local bestD, bestAlive = math.huge, false
    for _, p in Players:GetPlayers() do
        if p ~= lp and p.Character then
            local php = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local alive = hum and hum.Parent and hum.Health and hum.Health > 0
            if php and php.Parent and alive then
                local d = (hrp.Position - php.Position).Magnitude
                if d < bestD then bestD, bestAlive = d, true end
            end
        end
    end
    return bestD, bestAlive
end


-- ═══════════════════ TImp (time-to-impact) ═══════════════════
local function ballSpeed(ball, t)
    if (t - Sync.lastSyncAt) < SYNC_FRESH_T and Sync.Speed > 0 then return Sync.Speed end
    local ok, av     = pcall(function() return ball.AssemblyLinearVelocity end)
    local localSpd   = (ok and typeof(av) == "Vector3") and av.Magnitude or 0
    if localSpd < 1 and Sync.Speed > 0 and (t - Sync.lastSyncAt) < 2.0 then return Sync.Speed end
    return localSpd
end

local function ballPos(ball, t)
    if (t - Sync.lastSyncAt) < SYNC_FRESH_T and Sync.RealPos ~= Vector3.zero then
        return Sync.RealPos
    end
    if Sync.RealPos ~= Vector3.zero and Sync.Speed > 0 and (t - Sync.lastSyncAt) < 2.0 then
        local dt = t - Sync.lastSyncAt
        local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
        if ok and typeof(av) == "Vector3" and av.Magnitude > 1 then
            return Sync.RealPos + av * dt
        end
    end
    return ball.Position
end

local _liveTImpCache = { tImp = math.huge, bp = Vector3.zero, spd = 0, at = 0 }
local LIVE_TIMP_TTL  = 0.05

local function pingOneWay()
    local p = getPing()
    if p < CLASH.PING_FLOOR then p = CLASH.PING_FLOOR end
    return p
end

local function pingScale()
    local p = pingOneWay()
    local s = (p - CLASH.PING_REF) / CLASH.PING_REF
    if s < 0                       then s = 0                       end
    if s > CLASH.PING_MAX_SCALE    then s = CLASH.PING_MAX_SCALE    end
    return s
end

local function pingCredit(raw, spd)
    if spd < 1 then return 0 end
    local oneWay = pingOneWay() * CLASH.PING_CREDIT_F
    return math.min(raw, spd * oneWay)
end

local function tImpCompensated(raw, spd)
    if spd < 1 then return math.huge end
    local credit = pingCredit(raw, spd)
    local tImp   = (raw - credit) / spd
    if tImp < 0 then tImp = 0 end
    return tImp
end

local function pingAdjustedCap(base, scaleAmt)
    local s = pingScale()
    return base * (1 - scaleAmt * s)
end

local function liveTImp()
    local n = now()
    if (n - _liveTImpCache.at) < LIVE_TIMP_TTL then return _liveTImpCache end
    local hr   = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local ball = _G.__phantomBall or S.ball
    if hr and hr.Parent and ball and ball.Parent then
        local bp  = ball.Position
        local spd = 0
        local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
        if ok and typeof(av) == "Vector3" then spd = av.Magnitude end
        if spd < 1 then
            _liveTImpCache = { tImp = math.huge, bp = bp, spd = spd, at = n }
            return _liveTImpCache
        end
        local raw  = (hr.Position - bp).Magnitude
        local tImp = tImpCompensated(raw, spd)
        _liveTImpCache = { tImp = tImp, bp = bp, spd = spd, at = n }
    end
    return _liveTImpCache
end

local function computeTImp(hrp, ball, t)
    local bp  = ballPos(ball, t)
    local spd = ballSpeed(ball, t)
    if spd < 1 then return math.huge, bp, spd end
    local raw = (hrp.Position - bp).Magnitude
    return tImpCompensated(raw, spd), bp, spd
end


-- ═══════════════════ CLASH STATE ═══════════════════
local function clearClash()
    S.clashOn = false
    S.clashHoldUntil = 0
end

local function isTargeted()
    return Sync.Target == lp.UserId
        or S.lastTarget == lp.UserId
        or ws:GetAttribute("GameBallTarget") == lp.UserId
end

local function evaluateClash()
    if Config.AutoClash == false or _G.PhantomManual then return end
    local hr = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not (hr and hr.Parent) then return end

    local t        = now()
    local winStart = t - CLASH.CPS_WIN
    local cnt      = 0
    for _, ts in pairs(S.targetRing) do
        if ts and ts >= winStart then cnt = cnt + 1 end
    end
    S.targetCps = cnt / CLASH.CPS_WIN

    local ball = getBall()
    if not (ball and ball.Parent) then return end

    local nearest, nearestAlive = nearestPlayerAlive(hr)
    local bDist                  = (hr.Position - ball.Position).Magnitude
    local panic                  = nearestAlive
        and (nearest <= CLASH.PANIC_DIST and bDist <= CLASH.PANIC_BALL)

    local live = liveTImp()
    local tImp = live.tImp
    local spd  = live.spd
    if spd < 1 then
        local ti, _, s2 = computeTImp(hr, ball, t)
        tImp, spd = ti, s2
    end
    local ballInRange = bDist <= CLASH.BALL_RANGE

    local targetIsMe  = isTargeted()
    local coldCapAdj  = pingAdjustedCap(CLASH.COLD_TIMP_CAP, CLASH.COLD_PING_SCALE)

    local danger   = (spd >= 1 and tImp > 0) and (spd / tImp) or 0
    S.dangerEma    = S.dangerEma * 0.85 + danger * 0.15
    local dangerOK = panic or S.dangerEma >= CLASH.MIN_DANGER

    local coldGate = (panic or (targetIsMe and bDist <= CLASH.REENTRY_DIST and tImp <= coldCapAdj))
        and dangerOK

    local tooFarToClash = (bDist > CLASH.BALL_HARD_CAP and not panic)
    local ballPassed    = false
    if spd >= 1 and bDist > 0.5 then
        local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
        if ok and typeof(av) == "Vector3" then
            local toMe = (hr.Position - ball.Position) / bDist
            ballPassed = av.Unit:Dot(toMe) < 0
        end
    end

    if S.clashOn then
        local base = spd >= CLASH.SPD_FAST and CLASH.OFF_FAST
                 or spd >= CLASH.SPD_MID  and CLASH.OFF_MID
                 or spd >= CLASH.SPD_LOW  and CLASH.OFF_LOW
                 or CLASH.OFF_VLOW
        local limit = panic and CLASH.OFF_PANIC or base
        if tImp > CLASH.TIMP_FAR or tImp > limit or tooFarToClash or ballPassed then
            clearClash()
            return
        end
        return
    end

    local cpsThresh = (spd >= CLASH.FAST_BALL_SPD) and CLASH.FAST_BALL_CPS or CLASH.CPS_THRESH
    local tImpCap   = (spd >= CLASH.FAST_BALL_SPD)
        and pingAdjustedCap(CLASH.FAST_BALL_TIMP_CAP, CLASH.FAST_PING_SCALE)
        or coldCapAdj
    if (S.targetCps >= cpsThresh or panic)
        and (S.clashOn or coldGate)
        and dangerOK
        and (t - S.lastClashReact) >= CLASH.REACT_CD
    then
        if not S.clashOn and not panic and tImp > tImpCap then return end
        if not S.clashOn then
            S.clashOn        = true
            S.clashAt        = t
            S.clashHoldUntil = t + CLASH.HOLD
            S.lastClashReact = t
        end
    end
end


-- ═══════════════════ AUTO-PARRY BIND ═══════════════════
local apBind, apDead = 0, false
local function clearBind() apBind = apBind + 1 end

local function apDeflectionWindow(speed)
    return math.clamp(0.85 - (speed - 16) / 584 * 0.65, 0.20, 0.85)
end

local function bindParry(ch)
    clearBind()
    if apDead or not (ch and ch.Parent) then return end
    local id  = apBind
    local hrp = ch:FindFirstChild("HumanoidRootPart") or ch:WaitForChild("HumanoidRootPart", 1)
    if id ~= apBind or not (hrp and hrp.Parent) then return end
    AP.fired = false
    AP.armed = false

    track(RunService.Heartbeat:Connect(function(dt)
        if apDead or id ~= apBind or not (ch.Parent and hrp.Parent) then return end
        if Config.AutoParry ~= true then return end
        local t = now()

        if t < S.teleportLockUntil or Sync.Grace then return end
        if S.clashOn or _G.PhantomManual then return end

        local ball = getBall()
        if not (ball and ball.Parent) then return end

        if Sync.Target ~= lp.UserId then
            AP.armed = false
            return
        end

        local syncFresh = (t - Sync.lastSyncAt) < 0.3
        local bp = (syncFresh and Sync.RealPos ~= Vector3.zero)
            and Sync.RealPos or ball.Position

        local spd
        if syncFresh and Sync.Speed > 0 then
            spd = Sync.Speed
        else
            local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
            spd = (ok and typeof(av) == "Vector3") and av.Magnitude or 0
        end
        if spd < PARRY.MIN_SPD then return end

        local parryRad  = PARRY.DEFLECT_R + spd * 0.13
        local oneWay    = pingOneWay()
        local pingBoost = oneWay * spd * PARRY.PING_F
        if pingBoost > PARRY.PING_RAD_CAP then pingBoost = PARRY.PING_RAD_CAP end
        parryRad = parryRad + pingBoost
        if parryRad < PARRY.RAD_FLOOR then parryRad = PARRY.RAD_FLOOR end

        local dist = (hrp.Position - bp).Magnitude
        if dist > parryRad then return end

        if AP.fired     then return end
        if AP.firedAt > Sync.lastSyncAt then return end

        S.pingTimer = S.pingTimer + dt
        if S.pingTimer >= PING_SAMPLE then
            S.pingTimer = 0
            samplePing()
        end

        AP.fired      = true
        AP.firedAt    = t
        S.lastFireAt  = t
        sendParry()
    end))

    track(ch.AncestryChanged:Connect(function(_, p)
        if not p then clearBind() end
    end))
end


-- ═══════════════════ KEYBINDS ═══════════════════
local keyConn
local function installKeys()
    if keyConn then
        pcall(keyConn.Disconnect, keyConn)
        keyConn = nil
    end
    local panic, spam, mode = Config.Keybind, Config.SpamKeybind, Config.SpamMode or "Toggle"
    keyConn = UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == panic then
            clearClash()
            AP.fired = false
            _G.PhantomManual = false
        elseif i.KeyCode == spam then
            if mode == "Hold" then
                _G.PhantomManual = true
            else
                _G.PhantomManual = not _G.PhantomManual
            end
        end
    end)
    track(keyConn)
    if mode == "Hold" then
        track(UIS.InputEnded:Connect(function(i)
            if i.KeyCode == spam then _G.PhantomManual = false end
        end))
    end
end


-- ═══════════════════ GUI POLLING ═══════════════════
local CONFIG_KEYS = { "AutoParry", "AutoClash", "CPS", "CustomCPS", "Keybind", "SpamKeybind", "SpamMode" }
local guiReady, guiPollAcc = false, 0
local function applyConfig()
    local c = _G.PhantomConfig
    if type(c) ~= "table" then return end
    for _, k in ipairs(CONFIG_KEYS) do
        if c[k] ~= nil then Config[k] = c[k] end
    end
end

local function pollGUI(dt)
    if guiReady then return end
    guiPollAcc = guiPollAcc + dt
    if guiPollAcc < 0.25 then return end
    guiPollAcc = 0
    applyConfig()
    guiReady  = true
    installKeys()
end


-- ═══════════════════ SPAM STATE ═══════════════════
local _spamDebt, _spamLastTick  = 0, now()
local _spamClickWin             = {}
local _spamWinStart, _spamClickIdx = now(), 0
local _spamWasActive = false

local function _spamShouldRun()
    return S.clashOn or _G.PhantomManual == true
end

local function tickSpam(dt)
    if not _spamShouldRun() then
        if _spamWasActive then
            S.realCps = 0
            _spamDebt, _spamLastTick = 0, now()
            _spamClickWin, _spamWinStart, _spamClickIdx = {}, now(), 0
            _spamWasActive = false
        end
        return
    end
    _spamWasActive = true

    local t = now()
    if (t - _spamWinStart) > SPAM.WIN then
        local fresh = {}
        for _, ts in ipairs(_spamClickWin) do
            if ts >= t - 1 then fresh[#fresh + 1] = ts end
        end
        _spamClickWin  = fresh
        _spamWinStart  = t
    end
    if dt > SPAM.DT_CAP then dt = SPAM.DT_CAP end
    _spamDebt = _spamDebt + dt
    local n = 0
    while _spamDebt >= (1 / cps()) and n < SPAM.MAX_PER_ITER do
        if not _spamShouldRun() then
            _spamDebt = 0
            break
        end
        _spamClickIdx = _spamClickIdx + 1
        if parryR and parryR.Parent and SPAM_BUF then
            pcall(parryR.FireServer, parryR, SPAM_BUF)
        end

        _spamClickWin[#_spamClickWin + 1] = now()
        S.clickCount = S.clickCount + 1
        _spamDebt = _spamDebt - (1 / cps())
        n = n + 1
    end
    S.realCps = #_spamClickWin
end


-- ═══════════════════ CHARACTER LOOP ═══════════════════
local function bindChar(ch)
    if not (ch and ch.Parent) then return end
    local hrp = ch:WaitForChild("HumanoidRootPart", 9e9)
    if not (hrp and hrp.Parent) then return end
    local dead = false
    track(ch.AncestryChanged:Connect(function(_, p)
        if not p then dead = true end
    end))

    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum then
        track(hum.Died:Connect(function()
            resetAllState()
            print("[PHANTOM] reset em morte (Humanoid.Died)")
        end))
    end

    track(RunService.Heartbeat:Connect(function(dt)
        if dead or not State.active then return end
        if not (ch.Parent and hrp.Parent) then dead = true; return end
        pollGUI(dt)
        evaluateClash()
        tickSpam(dt)
    end))
end

local function onChar(ch)
    resetAllState()
    print("[PHANTOM] reset em respawn (CharacterAdded)")
    task.defer(function() pcall(bindParry, ch) end)
    task.defer(function() pcall(bindChar,  ch) end)
end
track(lp.CharacterAdded:Connect(onChar))
if lp.Character then task.defer(function() pcall(onChar, lp.Character) end) end


-- ═══════════════════ BALL SYNC ═══════════════════
local function ringPush(t)
    S.targetRingIdx = (S.targetRingIdx % RING_BUF) + 1
    S.targetRing[S.targetRingIdx] = t
end

local ballSync = Remotes and Remotes:FindFirstChild("BallSyncData")
if ballSync and ballSync:IsA("RemoteEvent") then
    track(ballSync.OnClientEvent:Connect(function(d)
        if typeof(d) ~= "table" then return end
        local t = now()

        if type(d.Speed) == "number"             then Sync.Speed      = d.Speed      end
        if typeof(d.RealPosition) == "Vector3"   then Sync.RealPos    = d.RealPosition end
        if typeof(d.DeflectDirection) == "Vector3" then Sync.DeflectDir = d.DeflectDirection end
        if type(d.Grace) == "boolean"            then Sync.Grace      = d.Grace      end
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
        if newTarget ~= S.lastTarget and newTarget == lp.UserId then
            Sync.Grace = false
        end
        if newTarget == S.lastTarget then
            Sync.Target = newTarget
            return
        end
        local prev = S.lastTarget
        S.lastTarget = newTarget
        Sync.Target  = newTarget
        ringPush(t)
        AP.armed     = (newTarget == lp.UserId)
        AP.fired     = false

        local targeted = (newTarget == lp.UserId)
        if targeted and Config.AutoClash ~= false and not _G.PhantomManual
            and prev ~= lp.UserId and prev ~= -999
        then
            local hr   = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            local ball = getBall()
            if hr and hr.Parent and ball and ball.Parent then
                local bDist = (hr.Position - ball.Position).Magnitude
                local spd   = ballSpeed(ball, t)
                local tImpR = (spd > 1) and tImpCompensated(bDist, spd) or math.huge
                local panic = (nearestPlayer(hr) <= CLASH.PANIC_DIST and bDist <= CLASH.PANIC_BALL)

                local ballDistReactCap = CLASH.BALL_HARD_CAP

                local offPanicAdj = pingAdjustedCap(CLASH.OFF_PANIC, CLASH.FAST_PING_SCALE)
                if (bDist <= ballDistReactCap or panic) and (panic or tImpR <= offPanicAdj) then
                    if (t - S.lastClashReact) >= CLASH.REACT_CD then
                        S.clashOn        = true
                        S.clashAt        = t
                        S.clashHoldUntil = panic and (t + CLASH.HOLD) or 0
                        S.lastClashReact = t
                    end
                end
            end
        end

        AP.armed = targeted
        if targeted then
            local hr        = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            local ball      = getBall()
            local processed = false
            if hr and hr.Parent and ball and ball.Parent then
                local bDist = (hr.Position - ball.Position).Magnitude
                local spd   = ballSpeed(ball, t)
                if spd > 1 then processed = (bDist / spd) <= BALL_PROC_TIMP end
            end
            _G.__lt_ballProcessed = processed
        end
    end))
end


-- ═══════════════════ BALL WATCHER ═══════════════════
local gameFolder   = ws:WaitForChild("Game", 30)
local ballWatcher  = gameFolder and gameFolder:FindFirstChild("Ball")
if ballWatcher then
    track(ballWatcher.ChildAdded:Connect(function(c)
        if c.Name == "GameBall" and c:IsA("BasePart") then
            S.ball              = c
            _G.__phantomBall    = c
            _ballCache          = c
            _ballCacheAt        = now()
        end
    end))
    track(ballWatcher.ChildRemoved:Connect(function(c)
        if c.Name == "GameBall" and c == _G.__phantomBall then
            S.ball              = nil
            _G.__phantomBall    = nil
            _ballCache          = nil
            _ballCacheAt        = now()
        end
    end))
    local existing = ballWatcher:FindFirstChild("GameBall")
    if existing and existing:IsA("BasePart") then
        S.ball              = existing
        _G.__phantomBall    = existing
        _ballCache          = existing
        _ballCacheAt        = now()
    end
end

task.spawn(function()
    if ballWatcher then return end
    while State.active do
        if not (_ballCache and _ballCache.Parent) then
            _ballCache, _ballCacheAt = nil, 0
            getBall()
        end
        task.wait(2)
    end
end)


-- ═══════════════════ BOOT RETRY ═══════════════════
task.spawn(function()
    for _ = 1, 3 do task.defer(samplePing); task.wait(0.2) end
    local tries = 0
    while State.active do
        tries = tries + 1
        local ok, err = pcall(function()
            refreshRefs()
            local r, m = resolveRemote()
            if not r then
                -- UPGRADE #3: probe por cooldown frame como fallback
                r, m = probeNamedRemoteEvents()
            end
            if r then initParry() end
        end)
        if not ok then warn("[PHANTOM] boot " .. tries .. ": " .. tostring(err)) end
        if tries >= BOOT_MAX_TRIES then break end
        task.wait(1)
    end
end)


-- ═══════════════════ GUI LOADER ═══════════════════
local GUI_CHOICE = "repp35"

local GUI_URLS = {
    drax   = "https://raw.githubusercontent.com/Repp35/Roblox/refs/heads/main/ph-gui.luau",
    repp35 = "https://raw.githubusercontent.com/Repp35/Roblox/refs/heads/main/phantom_gui.lua",
}
local function pickUrls()
    local mode = GUI_CHOICE
    if mode == "drax"   then return { GUI_URLS.drax   } end
    if mode == "repp35" then return { GUI_URLS.repp35 } end
    warn(("[PHANTOM] GUI_CHOICE=%q invalido, usando drax"):format(tostring(mode)))
    return { GUI_URLS.drax }
end

local HTTP_TRIES = {
    { n = "request",      ok = type(request)        == "function", call = function(u) return request({ Url = u, Method = "GET" }) end,         w = true  },
    { n = "http_request", ok = type(http_request)   == "function", call = function(u) return http_request({ Url = u, Method = "GET" }) end,    w = true  },
    { n = "syn.request",  ok = type(syn)            == "table"
                         and type(syn.request)      == "function", call = function(u) return syn.request({ Url = u, Method = "GET" }) end,     w = true  },
    { n = "game.HttpGet", ok = type(game.HttpGet)   == "function", call = function(u) return game:HttpGet(u) end,                            w = false },
}

task.defer(function()
    if _G.__phantomGUI_loaded then return end
    local src = rawget(_G, "__phantomGUI_src")
    if type(src) ~= "string" or #src == 0 then
        for _, url in ipairs(pickUrls()) do
            local got = false
            for _, a in ipairs(HTTP_TRIES) do
                if a.ok then
                    local ok, res = pcall(a.call, url)
                    local body    = a.w and (ok and res and res.Body) or (ok and res)
                    if type(body) == "string" and #body > 0 then
                        src = body
                        print(("[PHANTOM] GUI source OK via %s (%s)"):format(a.n, url))
                        got = true
                        break
                    end
                end
            end
            if got then break end
        end
    end
    if type(src) ~= "string" or #src == 0 then warn("[PHANTOM] sem GUI (nenhuma URL respondeu), backend standalone"); return end
    if type(loadstring) ~= "function" then warn("[PHANTOM] loadstring ausente"); return end
    local fn, err = loadstring(src)
    if not fn then warn("[PHANTOM] GUI compile: " .. tostring(err)); return end
    _G.__phantomGUI_src = src
    local ok, runErr = pcall(fn)
    if ok then
        _G.__phantomGUI_loaded = true
        print("[PHANTOM] GUI ok")
    else
        warn("[PHANTOM] GUI run: " .. tostring(runErr))
    end
end)

task.defer(function()
    task.wait(0.1)
    pcall(refreshRefs)
    print(("[PHANTOM] v9.0 | GameId=%s | TS=%s | Remotes=%s | Ball=%s"):format(
        tostring(game.GameId),
        TSFolder and "ok" or "nil",
        Remotes  and "ok" or "nil",
        tostring(getBall() ~= nil)
    ))
end)


-- ═══════════════════ CONFIG HOT-RELOAD POLL ═══════════════════
task.spawn(function()
    while State.active do
        if guiReady then applyConfig() end
        task.wait(0.5)
    end
end)
