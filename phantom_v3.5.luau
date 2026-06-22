-- PHANTOM — Manual Spam + Auto Clash + Auto Parry (DYNAMIC v8.6-clean)

-- SERVICES
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Replicated = game:GetService("ReplicatedStorage")
local Stats      = game:GetService("Stats")
local UIS        = game:GetService("UserInputService")
local lp, ws    = Players.LocalPlayer, workspace
local now        = os.clock

-- TUNING
local CLASH = {
    DECAY=0.310, HOLD=0.30, REACT_CD=0.180,
    BALL_RANGE=18, BALL_HARD_CAP=22, MAX_BALL_DIST=45,
    PANIC_DIST=6, PANIC_BALL=10,
    -- §FIX cps threshold alto (17) — rally normal não passa disso, clash real sim.
    -- era 8, pegava rally normal como clash e o spam ficava ligado em hora errada.
    CPS_THRESH=17, CPS_WIN=1.0,
    TIMP_FAR=0.330,
    SPD_FAST=65, SPD_MID=40, SPD_LOW=20,
    OFF_PANIC=0.180, OFF_FAST=0.060, OFF_MID=0.100, OFF_LOW=0.130, OFF_VLOW=0.160,
    -- gate de cold-start extra: bloqueia ativação se tImp > este valor sem PANIC.
    -- era 0.140 (OFF_MID) — filtrava clashes lentos legítimos. Aumentado pra 0.180.
    COLD_TIMP_CAP=0.180,
    -- §FIX FAST BALL: quando a bola tá rápida (spd >= 200), o CPS_THRESH cai
    -- pra 0 — bola rápida com tImp curto já É prova de clash real. Em smash
    -- (spd 400-600) o BallSync manda target novo 1×, CPS fica em ~1.0 por
    -- quase 1s esperando encher, mas a bola passa em 30ms. Threshold dinâmico
    -- resolve isso: rally lento (spd 60-100) ainda exige CPS>=17, smash não.
    FAST_BALL_SPD=200,
    FAST_BALL_CPS=0,
    FAST_BALL_TIMP_CAP=0.100,
}
local PARRY = { CD=0.08, MIN_SPD=5, DEFLECT_R=8, RAD_FLOOR=12, PING_F=1.0, PING_RAD_GAIN=0.08 }
local PING_EMA, PING_MAX, PING_SAMPLE = 0.5, 0.150, 1.5
local TELEPORT_LOCK, FORCED_DIR_TTL = 0.20, 0.20
local SYNC_FRESH_T = 0.3
local BALL_PROC_TIMP, RING_BUF = 0.25, 8
local REARM = { DIST=4, DT_MAX=0.1, MIN_SPD=5 }
local SPAM = { MAX_PER_ITER=50, WIN=1.5, DT_CAP=1 }
local DEFAULT_CPS, BOOT_MAX_TRIES = 25, 30

-- CONFIG / STATE
local Config = {
    AutoParry=true, ManualSpam=false, AutoClash=true,
    CPS=DEFAULT_CPS, CustomCPS=false,
    Keybind=Enum.KeyCode.F9, SpamKeybind=Enum.KeyCode.F, SpamMode="Toggle",
}
local State = { active=true, conns={} }
local __STATE_OK = true
local function _stateGuard()
    if type(State) ~= "table" or type(State.conns) ~= "table" then
        __STATE_OK = false
        State = { active=true, conns={} }
    end
    if __STATE_OK and State.active == nil then State.active = true end
end
_stateGuard()
local S = {
    ball=nil, lastTarget=-999,
    clashOn=false, clashAt=0, clashHoldUntil=0, lastClashReact=0,
    smoothPing=0.05, pingTimer=0, lastFireAt=0, teleportLockUntil=0,
    targetRing={}, targetRingIdx=0, targetCps=0,
    realCps=0, clickCount=0,
}
local Sync = {
    Speed=0, RealPos=Vector3.zero, ForceDir=false, ForcedDir=Vector3.zero,
    DeflectDir=Vector3.zero, Grace=false, Teleported=false,
    Target=-999, lastSyncAt=0, forcedAt=0,
}
local AP = { armed=false, fired=false, firedAt=0, lastBallPos=nil, lastBallPosAt=0 }

_G.PhantomConfig = Config
_G.PhantomState = State
_G.PhantomManual = false
_G.PhantomAutoClash = true
_G.PhantomSaveConfig = function(c)
    if type(c) == "table" then for k,v in pairs(c) do Config[k]=v end end
end
_G.PhantomStop = function()
    _stateGuard()
    State.active = false
    disconnectAll()
    _G.PhantomManual = false
    print("[PHANTOM] stop()")
end

-- UTILS
local function track(c)
    _stateGuard()
    if not __STATE_OK then return c end
    if c and c.Disconnect then State.conns[#State.conns+1] = c end
    return c
end
local function disconnectAll()
    _stateGuard()
    if not __STATE_OK then return end
    for i=#State.conns,1,-1 do
        pcall(State.conns[i].Disconnect, State.conns[i])
        State.conns[i] = nil
    end
end
local function cps()
    local c = tonumber(Config.CPS) or DEFAULT_CPS
    return c < 1 and 1 or c
end

-- PING
-- one-way ping = RTT / 2. Sem aditivo fantasma.
-- Boot fallback: se smoothPing nunca foi sampleado, assume 60ms one-way (RTT 120ms)
-- pra não sub-compensar logo de cara.
local PING_BOOT_FALLBACK = 0.060
local function getPing()
    local p = S.smoothPing
    if p <= 0 then p = PING_BOOT_FALLBACK end
    local oneWay = p * 0.5
    if oneWay < 0 then return 0 end
    if oneWay > PING_MAX then return PING_MAX end
    return oneWay
end
local function samplePing()
    local ok, p = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    if ok and type(p)=="number" and p>0 and p<0.5 then
        S.smoothPing = S.smoothPing * (1-PING_EMA) + p * PING_EMA
    end
end

-- MODULES / REFS
local TSFolder, Remotes = Replicated:FindFirstChild("TS"), Replicated:FindFirstChild("Remotes")
local GenRemotes = TSFolder and TSFolder:FindFirstChild("GeneratedNetworkRemotes")
local enumFolder = TSFolder and TSFolder:FindFirstChild("Enums")
local abilFolder = TSFolder and TSFolder:FindFirstChild("Abilities")
local TouchTap = Replicated:FindFirstChild("TouchTap")

local function safeReq(m)
    if not (m and m:IsA("ModuleScript")) then return nil end
    local ok, r = pcall(require, m); return ok and r or nil
end
local AbilityID   = (enumFolder and safeReq(enumFolder:FindFirstChild("AbilityID")) or {}).AbilityID or {Deflect="Deflect"}
local Deflect     = (abilFolder and safeReq(abilFolder:FindFirstChild("DeflectAbility")) or {}).DeflectAbility or {}
local BindableMgr = TSFolder and safeReq(TSFolder:FindFirstChild("BindableManager"))
local GameInfo    = (TSFolder and safeReq(TSFolder:FindFirstChild("GameInfo")) or {}).GameInfo
local BR          = (TSFolder and safeReq(TSFolder:FindFirstChild("BallReplicator"):FindFirstChild("BallReplicator")) or {}).BallReplicator

local function refreshRefs()
    if TSFolder and not TSFolder.Parent then
        TSFolder = Replicated:FindFirstChild("TS")
        GenRemotes = TSFolder and TSFolder:FindFirstChild("GeneratedNetworkRemotes")
    end
    if not Remotes or not Remotes.Parent then Remotes = Replicated:FindFirstChild("Remotes") end
end

-- PARRY REMOTE
local function validRemote(r)
    return typeof(r) == "Instance" and r.Parent ~= nil and r:IsA("RemoteEvent")
end
local function getGlobal()
    if type(getfenv) ~= "function" or type(Deflect) ~= "table" then return _G, _G end
    for _, fn in ipairs({Deflect.Deflect, Deflect.OnClientCreate, Deflect.constructor}) do
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
    if type(g) == "table" then rawset(g, k, v) end
    if type(env) == "table" and env ~= g then rawset(env, k, v) end
end

local parryR, parryMode, parryInit = nil, nil, false
local function cacheRemote(r, mode)
    if not validRemote(r) then return nil end
    parryR, parryMode = r, mode
    if mode == "buffer" then setGlobal("did", r) end
    return r, mode
end
local function resolveRemote()
    refreshRefs()
    if validRemote(parryR) then return parryR, parryMode end
    local g, _ = getGlobal()
    local did = type(g) == "table" and rawget(g, "did")
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

local function makeBuf(flag)
    if type(buffer) ~= "table" then return nil end
    if type(buffer.fromstring) == "function" then
        return buffer.fromstring(flag == 2 and "\2" or "\1")
    end
    if type(buffer.create) == "function" and type(buffer.writeu8) == "function" then
        local b = buffer.create(1); buffer.writeu8(b, 0, flag); return b
    end
end
local SPAM_BUF = (function()
    local ok, b = pcall(buffer.fromstring, "\1")
    return ok and b or nil
end)()

local function initParry()
    if parryInit then return true end
    local r, m = resolveRemote()
    if not r then return false end
    if m == "event" then parryInit = true; return true end
    local p = makeBuf(2)
    if not p then return false end
    parryInit = pcall(r.FireServer, r, p); return parryInit
end
local function fireParry(r, m, flag)
    if not validRemote(r) then return false end
    if m == "event" then return pcall(r.FireServer, r) end
    local p = makeBuf(flag or 1); if not p then return false end
    initParry(); return pcall(r.FireServer, r, p)
end
local function sendParry()
    local r, m = parryR, parryMode
    if not validRemote(r) then r, m = resolveRemote() end
    if r and fireParry(r, m, 1) then S.lastFireAt = now(); return true end
    return false
end

-- BALL / PLAYERS
local _ballCache, _ballCacheAt = nil, 0
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

-- TImp (time-to-impact)
local function ballSpeed(ball, t)
    if (t - Sync.lastSyncAt) < SYNC_FRESH_T and Sync.Speed > 0 then return Sync.Speed end
    local ok, av = pcall(function() return ball.AssemblyLinearVelocity end)
    return (ok and typeof(av) == "Vector3") and av.Magnitude or 0
end
local function ballPos(ball, t)
    if (t - Sync.lastSyncAt) < SYNC_FRESH_T and Sync.RealPos ~= Vector3.zero then
        return Sync.RealPos
    end
    return ball.Position
end
local function computeTImp(hrp, ball, t)
    local bp = ballPos(ball, t)
    local spd = ballSpeed(ball, t)
    if spd < 1 then return math.huge, bp, spd end
    local ping = getPing()
    local raw = (hrp.Position - bp).Magnitude
    -- credited = distância que a bola andou durante o one-way ping
    -- limita por raw: a bola não pode ter passado de você (senão credited > raw e TImp < 0)
    local credited = math.min(raw, spd * ping)
    -- clamp pra não devolver TImp negativo (faria o clash travar ligado)
    local tImp = (raw - credited) / spd
    if tImp < 0 then tImp = 0 end
    return tImp, bp, spd
end

-- CLASH STATE
local function clearClash()
    S.clashOn = false; S.clashHoldUntil = 0
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

    local t = now()
    local winStart = t - CLASH.CPS_WIN
    local cnt = 0
    for _, ts in pairs(S.targetRing) do if ts and ts >= winStart then cnt = cnt + 1 end end
    S.targetCps = cnt / CLASH.CPS_WIN

    local ball = getBall()
    if not (ball and ball.Parent) then return end

    local nearest = nearestPlayer(hr)
    local bDist = (hr.Position - ball.Position).Magnitude
    local panic = (nearest <= CLASH.PANIC_DIST and bDist <= CLASH.PANIC_BALL)
    local tImp, _, spd = computeTImp(hr, ball, t)
    local ballInRange = bDist <= CLASH.BALL_RANGE

    -- §FIX REENTRY (erro de design real):
    -- coldGate original exigia bDist <= BALL_RANGE (18) quando você é target.
    -- Em rally contínuo onde você se afasta e volta: o BallSync só faz
    -- ringPush 1× (target novo = você), CPS fica em ~1.0, gate de CPS 17
    -- nunca passa. Aí o clash só liga quando bDist cruza 18 — mas a bola
    -- pode estar em smash a 30+ studs vindo rápido, e em 1-2 frames você
    -- tá dentro do range sem ter ativado clash = morre.
    -- FIX: coldGate exige targetIsMe + bola com tImp curto (tá vindo pra
    -- você). Não importa se bDist é 5 ou 25 studs — se tá chegando rápido,
    -- é clash. O COLD_TIMP_CAP (0.180) lá embaixo bloqueia ativação com
    -- bola que tá voltando devagar (rally normal).
    local targetIsMe = isTargeted()
    local coldGate = panic or (targetIsMe and tImp <= CLASH.COLD_TIMP_CAP)

    -- §FIX hard cap de distância na manutenção (igual PB v9.0):
    -- mesmo com cps alto, não mantém clash ativo se bola > 25 studs sem PANIC.
    -- Isso é o que faz o teste demorar pra desligar: liga por cps e só sai
    -- quando tImp sobe. Agora sai também por distância dura.
    local tooFarToClash = (bDist > CLASH.BALL_HARD_CAP and not panic)
    -- §FIX FAST KILL: se bola tá muito perto (independente de tImp), desliga.
    -- tImp usa Sync.RealPos que pode estar velho (até 0.3s). Se bola já tá
    -- em cima, a real tImp é ~0 e o clash deveria ter desligado, mas o tImp
    -- velho ainda mostra 100ms. Esse gate mata o delay do sync velho.
    local tooCloseToClash = bDist < 6

    -- §FIX desativação RODA PRIMEIRO: se bola já tá longe ou tImp já estourou,
    -- desliga antes de tentar reativar. Evita o loop "liga → desliga no próximo frame"
    -- que segura o spam ligado por 1-2 frames a mais que o necessário.
    if S.clashOn then
        local base = spd >= CLASH.SPD_FAST and CLASH.OFF_FAST
                 or spd >= CLASH.SPD_MID and CLASH.OFF_MID
                 or spd >= CLASH.SPD_LOW and CLASH.OFF_LOW
                 or CLASH.OFF_VLOW
        local limit = panic and CLASH.OFF_PANIC or base
        if tImp > CLASH.TIMP_FAR or tImp > limit or tooFarToClash or tooCloseToClash then
            clearClash()
            -- §FIX: depois de desligar, NÃO reativa no mesmo evaluate. Espera o
            -- próximo heartbeat. Isso garante desativação instantânea.
            return
        end
    end

    -- §FIX ativação: cold start exige targetIsMe (não só isTargeted cacheado).
    -- E exige que tImp não esteja já estourado (filtra cps de rally normal que
    -- momentaneamente bate 17+ mas bola tá longe / voltando).
    -- §FIX FAST BALL: threshold de CPS dinâmico por velocidade.
    -- Bola lenta (rally normal): CPS>=17 obrigatório, tImp<=180ms.
    -- Bola rápida (smash spd>=200): CPS>=0 (targetIsMe + tImp basta).
    -- Sem isso, smash demora 1s esperando CPS encher e morre.
    local cpsThresh = (spd >= CLASH.FAST_BALL_SPD) and CLASH.FAST_BALL_CPS or CLASH.CPS_THRESH
    local tImpCap   = (spd >= CLASH.FAST_BALL_SPD) and CLASH.FAST_BALL_TIMP_CAP or CLASH.COLD_TIMP_CAP
    if (S.targetCps >= cpsThresh or panic)
        and (S.clashOn or coldGate)
        and (t - S.lastClashReact) >= CLASH.REACT_CD
    then
        -- §FIX cold start extra: se NÃO é PANIC e tImp > tImpCap,
        -- a bola não tá vindo pra mim em velocidade de clash. Espera.
        if not S.clashOn and not panic and tImp > tImpCap then return end
        -- §FIX REENTRY: removido gate bDist > BALL_RANGE. Agora coldGate já
        -- cobre isso via tImp. Se tImp <= tImpCap a bola tá chegando, ativa
        -- mesmo de longe — isso é o que evita a morte no rally.
        if not S.clashOn then
            S.clashOn = true; S.clashAt = t; S.clashHoldUntil = t + CLASH.HOLD
            S.lastClashReact = t
        end
    end
end

-- AUTO-PARRY BIND
local apBind, apDead = 0, false
local function clearBind() apBind = apBind + 1 end

local function bindParry(ch)
    clearBind()
    if apDead or not (ch and ch.Parent) then return end
    local id = apBind
    local hrp = ch:FindFirstChild("HumanoidRootPart") or ch:WaitForChild("HumanoidRootPart", 1)
    if id ~= apBind or not (hrp and hrp.Parent) then return end
    AP.fired = false

    track(RunService.Heartbeat:Connect(function(dt)
        if apDead or id ~= apBind or not (ch.Parent and hrp.Parent) then return end
        if Config.AutoParry ~= true then return end
        local t = now()
        if t < S.teleportLockUntil or Sync.Grace then return end
        if S.clashOn or _G.PhantomManual then
            local b = _G.__phantomBall
            if b and b.Parent then AP.lastBallPos = b.Position; AP.lastBallPosAt = t end
            return
        end
        local ball = getBall()
        if not (ball and ball.Parent) then return end
        if not isTargeted() then AP.armed = false; return end
        AP.armed = true

        -- rearm se AP.fired ficou preso em true (server rejeitou) há mais de 0.4s
        if AP.fired and AP.firedAt > 0 and (t - AP.firedAt) > 0.4 then
            AP.fired = false
        end

        local bp = ballPos(ball, t)
        local spd = ballSpeed(ball, t)
        if spd < PARRY.MIN_SPD then return end

        local ping = getPing() * PARRY.PING_F
        if ping > 0 and spd > 1 then
            local dir = (hrp.Position - bp).Unit
            local compensation = spd * ping
            -- limita compensation: se passaria de você, trava em rawDist - 1
            -- (evita bp virar "atrás de você" e dist dar menor que a real)
            local rawDist = (hrp.Position - bp).Magnitude
            if compensation > rawDist - 1 then compensation = math.max(0, rawDist - 1) end
            bp = bp - dir * compensation
        end
        -- raio escala com velocidade E com ping (ping alto = bola menos previsível = raio maior)
        local pingSec = getPing()
        local rad = PARRY.DEFLECT_R + spd * 0.13 + pingSec * PARRY.PING_RAD_GAIN * 1000
        if rad < PARRY.RAD_FLOOR then rad = PARRY.RAD_FLOOR end
        local dist = (hrp.Position - bp).Magnitude

        if AP.fired and AP.lastBallPos and AP.lastBallPosAt then
            local dB = (bp - AP.lastBallPos).Magnitude
            local dT = t - AP.lastBallPosAt
            if dT > 0 and dT < REARM.DT_MAX then
                local bs = dB / dT
                if bs > REARM.MIN_SPD then
                    local rOld = (AP.lastBallPos - hrp.Position).Magnitude
                    if dist > rOld + REARM.DIST and dist > rad then AP.fired = false end
                end
            end
        end
        AP.lastBallPos, AP.lastBallPosAt = bp, t

        if dist > rad or AP.fired then return end
        S.pingTimer = S.pingTimer + dt
        if S.pingTimer >= PING_SAMPLE then S.pingTimer = 0; samplePing() end
        AP.fired = true; AP.firedAt = t; S.lastFireAt = t
        task.defer(sendParry)
    end))

    track(ch.AncestryChanged:Connect(function(_, p) if not p then clearBind() end end))
end

-- KEYBINDS
local keyConn
local function installKeys()
    if keyConn then pcall(keyConn.Disconnect, keyConn); keyConn = nil end
    local panic, spam, mode = Config.Keybind, Config.SpamKeybind, Config.SpamMode or "Toggle"
    keyConn = UIS.InputBegan:Connect(function(i, gpe)
        if gpe then return end
        if i.KeyCode == panic then
            clearClash(); AP.fired = false; _G.PhantomManual = false
        elseif i.KeyCode == spam then
            if mode == "Hold" then _G.PhantomManual = true
            else _G.PhantomManual = not _G.PhantomManual end
        end
    end)
    track(keyConn)
    if mode == "Hold" then
        track(UIS.InputEnded:Connect(function(i)
            if i.KeyCode == spam then _G.PhantomManual = false end
        end))
    end
end

-- GUI POLLING
local CONFIG_KEYS = {"AutoParry","AutoClash","CPS","CustomCPS","Keybind","SpamKeybind","SpamMode"}
local guiReady, guiPollAcc = false, 0
local function applyConfig()
    local c = _G.PhantomConfig
    if type(c) ~= "table" then return end
    for _, k in ipairs(CONFIG_KEYS) do if c[k] ~= nil then Config[k] = c[k] end end
end
local function pollGUI(dt)
    if guiReady then return end
    guiPollAcc = guiPollAcc + dt
    if guiPollAcc < 0.25 then return end
    guiPollAcc = 0
    applyConfig()
    guiReady = true; installKeys()
end

-- SPAM STATE (consumido pelo Heartbeat do bindChar — mesma precisão, zero lag de toggle)
-- MOVIDO PRA CIMA DE bindChar: o script principal yielda no WaitForChild("Game")
-- e o task.defer(onChar) roda durante esse yield — se tickSpam ainda não existir,
-- o Heartbeat chama nil (attempt to call a nil value, ex line 465).
local _spamDebt, _spamLastTick = 0, now()
local _spamClickWin, _spamWinStart, _spamClickIdx = {}, now(), 0
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
        for _, ts in ipairs(_spamClickWin) do if ts >= t - 1 then fresh[#fresh+1] = ts end end
        _spamClickWin = fresh; _spamWinStart = t
    end
    if dt > SPAM.DT_CAP then dt = SPAM.DT_CAP end
    _spamDebt = _spamDebt + dt
    local n = 0
    -- §FIX INSTANT STOP: re-checa _spamShouldRun() DENTRO do loop.
    -- Se o clash desligar no meio do burst (entre dois clicks), os clicks
    -- já programados são cortados. Sem isso, num spam de 25 CPS (40ms entre
    -- clicks) e frame de ~16ms, dá até 2 clicks fantasmas depois de clearClash.
    -- Quem seta _spamDebt = 0 no próximo frame (camada de cima) também ajuda,
    -- mas ESTE check garante corte no MESMO tick.
    while _spamDebt >= (1 / cps()) and n < SPAM.MAX_PER_ITER do
        if not _spamShouldRun() then
            _spamDebt = 0
            break
        end
        _spamClickIdx = _spamClickIdx + 1
        if _spamClickIdx % 2 == 1 and parryR and parryR.Parent and SPAM_BUF then
            pcall(parryR.FireServer, parryR, SPAM_BUF)
        elseif TouchTap then
            pcall(TouchTap.Fire, TouchTap)
        end
        _spamClickWin[#_spamClickWin+1] = now()
        S.clickCount = S.clickCount + 1
        _spamDebt = _spamDebt - (1 / cps())
        n = n + 1
    end
    S.realCps = #_spamClickWin
end

-- CHARACTER LOOP (Heartbeat único: gui + clash + spam)
local function bindChar(ch)
    if not (ch and ch.Parent) then return end
    local hrp = ch:WaitForChild("HumanoidRootPart", 9e9)
    if not (hrp and hrp.Parent) then return end
    local dead = false
    track(ch.AncestryChanged:Connect(function(_, p) if not p then dead = true end end))
    track(RunService.Heartbeat:Connect(function(dt)
        if dead or not State.active then return end
        if not (ch.Parent and hrp.Parent) then dead = true; return end
        pollGUI(dt)
        evaluateClash()
        tickSpam(dt)
    end))
end

local function onChar(ch)
    S.lastTarget = -999
    clearClash(); AP.fired = false
    task.defer(function() pcall(bindParry, ch) end)
    task.defer(function() pcall(bindChar, ch) end)
end
track(lp.CharacterAdded:Connect(onChar))
if lp.Character then task.defer(function() pcall(onChar, lp.Character) end) end

-- BALL SYNC
local function ringPush(t)
    S.targetRingIdx = (S.targetRingIdx % RING_BUF) + 1
    S.targetRing[S.targetRingIdx] = t
end

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
            AP.fired = false; clearClash()
            if typeof(d.TeleportPosition) == "Vector3" then Sync.TeleportPosition = d.TeleportPosition end
            Sync.Teleported = true; return
        end
        Sync.Teleported = false

        local newTarget = d.TargetPlayerID
        -- ao virar target novo, o server não manda Grace=true nesta rajada
        -- (Grace só vale quando bola tá longe). Limpa pra evitar lixo de rajada anterior.
        if newTarget ~= S.lastTarget and newTarget == lp.UserId then
            Sync.Grace = false
        end
        if newTarget == S.lastTarget then
            Sync.Target = newTarget; return
        end
        local prev = S.lastTarget
        S.lastTarget = newTarget; Sync.Target = newTarget
        ringPush(t)

        -- BallSync-driven reactivation
        local targeted = (newTarget == lp.UserId)
        if targeted and Config.AutoClash ~= false and not _G.PhantomManual
            and prev ~= lp.UserId and prev ~= -999
        then
            local hr = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            local ball = getBall()
            if hr and hr.Parent and ball and ball.Parent then
                local bDist = (hr.Position - ball.Position).Magnitude
                local spd = ballSpeed(ball, t)
                local tImpR = math.huge
                if spd > 1 then
                    local ping = getPing()
                    local credited = math.min(bDist, spd * ping)
                    tImpR = (bDist - credited) / spd
                    if tImpR < 0 then tImpR = 0 end
                end
                local panic = (nearestPlayer(hr) <= CLASH.PANIC_DIST and bDist <= CLASH.PANIC_BALL)
                -- §FIX hard cap de distância igual PB: nunca reativa clash com bola > 25 studs,
                -- exceto PANIC. Evita reativação por ping compensado demais.
                if (bDist <= CLASH.BALL_HARD_CAP or panic) and (panic or tImpR <= CLASH.OFF_PANIC) then
                    if (t - S.lastClashReact) >= CLASH.REACT_CD then
                        S.clashOn = true; S.clashAt = t; S.clashHoldUntil = 0
                        S.lastClashReact = t
                        -- §FIX desliga qualquer decay pendente pra não conflitar
                        S.clashHoldUntil = panic and (t + CLASH.HOLD) or 0
                    end
                end
            end
        end

        AP.armed = targeted; AP.fired = false
        if targeted then
            local hr = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            local ball = getBall()
            local processed = false
            if hr and hr.Parent and ball and ball.Parent then
                local bDist = (hr.Position - ball.Position).Magnitude
                local spd = ballSpeed(ball, t)
                if spd > 1 then processed = (bDist / spd) <= BALL_PROC_TIMP end
            end
            _G.__lt_ballProcessed = processed
        end
    end))
end

-- BALL WATCHER
-- Vigia GameBall pra invalidar cache se a bola morrer/spawnar.
-- Só escuta em workspace.Game.Ball (Folder) — evita ~95% dos callbacks do DescendantAdded.
local gameFolder = ws:WaitForChild("Game", 30)
local ballWatcher = gameFolder and gameFolder:FindFirstChild("Ball")
if ballWatcher then
    track(ballWatcher.ChildAdded:Connect(function(c)
        if c.Name == "GameBall" and c:IsA("BasePart") then
            S.ball = c
            _G.__phantomBall = c
            _ballCache, _ballCacheAt = c, now()
        end
    end))
    track(ballWatcher.ChildRemoved:Connect(function(c)
        if c.Name == "GameBall" and c == _G.__phantomBall then
            S.ball = nil
            _G.__phantomBall = nil
            _ballCache, _ballCacheAt = nil, now()
        end
    end))
    local existing = ballWatcher:FindFirstChild("GameBall")
    if existing and existing:IsA("BasePart") then
        S.ball = existing
        _G.__phantomBall = existing
        _ballCache, _ballCacheAt = existing, now()
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

-- SPAM STATE foi movido para antes de bindChar (acima). Ver nota sobre WaitForChild yield.

-- BOOT RETRY
task.spawn(function()
    local tries = 0
    while State.active do
        tries = tries + 1
        local ok, err = pcall(function()
            refreshRefs()
            if resolveRemote() then initParry() end
        end)
        if not ok then warn("[PHANTOM] boot " .. tries .. ": " .. tostring(err)) end
        if tries >= BOOT_MAX_TRIES then break end
        task.wait(1)
    end
end)

-- GUI CHOICE: "drax" ou "repp35"
local GUI_CHOICE = "drax"

local GUI_URLS = {
    drax   = "https://raw.githubusercontent.com/Repp35/Roblox/refs/heads/main/ph-gui.luau",
    repp35 = "https://raw.githubusercontent.com/Repp35/Roblox/refs/heads/main/phantom_gui.lua",
}
local function pickUrls()
    local mode = GUI_CHOICE
    if mode == "drax"   then return { GUI_URLS.drax } end
    if mode == "repp35" then return { GUI_URLS.repp35 } end
    warn(("[PHANTOM] GUI_CHOICE=%q invalido, usando drax"):format(tostring(mode)))
    return { GUI_URLS.drax }
end
local HTTP_TRIES = {
    {n="request",      ok=type(request)=="function",      call=function(u) return request({Url=u, Method="GET"}) end, w=true},
    {n="http_request", ok=type(http_request)=="function", call=function(u) return http_request({Url=u, Method="GET"}) end, w=true},
    {n="syn.request",  ok=type(syn)=="table" and type(syn.request)=="function", call=function(u) return syn.request({Url=u, Method="GET"}) end, w=true},
    {n="game.HttpGet", ok=type(game.HttpGet)=="function", call=function(u) return game:HttpGet(u) end, w=false},
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
                    local body = a.w and (ok and res and res.Body) or (ok and res)
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
    if ok then _G.__phantomGUI_loaded = true; print("[PHANTOM] GUI ok")
    else warn("[PHANTOM] GUI run: " .. tostring(runErr)) end
end)

task.defer(function()
    task.wait(0.1)
    pcall(refreshRefs)
    print(("[PHANTOM] v8.6-clean | GameId=%s | TS=%s | Remotes=%s | Ball=%s"):format(
        tostring(game.GameId), TSFolder and "ok" or "nil", Remotes and "ok" or "nil",
        tostring(getBall() ~= nil)
    ))
end)

-- hot-reload config poll
task.spawn(function()
    while State.active do
        if guiReady then applyConfig() end
        task.wait(0.5)
    end
end)
