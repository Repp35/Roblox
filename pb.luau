-- ================================================
--   PB | Backend
-- ================================================

local Players,RunService,Replicated,Stats,UIS=game:GetService"Players",game:GetService"RunService",game:GetService"ReplicatedStorage",game:GetService"Stats",game:GetService"UserInputService"
local lp,ws=Players.LocalPlayer,workspace
local now=os.clock

local CLASH_DECAY,CLASH_BALL_RANGE=0.310,18  -- §FIX cold start: bola tem que tá bem perto (era 38, pegava rally normal)
local DEFAULT_CPS,BOOT_MAX_TRIES=25,30
local PING_EMA_ALPHA,PARRY_COOLDOWN,PARRY_MIN_SPEED,PARRY_MIN_RAD=0.5,0.08,5,12
local PARRY_RAD_BASE,PARRY_RAD_RADIAL,TELEPORT_LOCKOUT,FORCED_DIR_TTL=6,8,0.20,0.20
local GRACE_BLOCK_PARRY,CLASH_HOLD=true,0.30

-- ============================================================
--   CONFIG — chaves idênticas às que a GUI escreve
-- ============================================================
local Config={
    AutoParry   = true,
    AutoClash   = true,
    CPS         = DEFAULT_CPS,
    CustomCPS   = false,
    Keybind     = Enum.KeyCode.F9,
    SpamKeybind = Enum.KeyCode.F,
    SpamMode    = "Toggle",
    Aura        = false,
    MiniX       = nil,
    MiniY       = nil,
    PanelX      = nil,
    PanelY      = nil,
    BtnX        = nil,
    BtnY        = nil,
}
local State={scriptActive=true,connections={}}
local S={
    ball=nil,lastTarget=-999,
    clashActive=false,clashActivatedAt=0,clashHoldUntil=0,
    spamDrainUntil=0,spamWasActive=false,spamLastFire=0,spamStartedAt=0,
    clickCount=0,slowFrames=0,lastSlowFrameLog=0,
    guiReady=false,guiPollAcc=0,smoothedPing=0.05,pingTimer=0,
    lastFireAt=0,teleportLockUntil=0,
    -- §v8.6 auto clash por cps de mudança de target (independente do BallSyncData delay)
    targetChangeT={},targetChangeIdx=0,targetCps=0,lastClashReact=0,
    -- §v9.5 janela rolling de CPS (cleanup 1.5s)
    _cpsClWin={},_cpsClWinStart=0,
}

local CLASH_CPS_THRESHOLD=17.0      -- §FIX exigi 17 cps — rally normal não passa disso, clash real sim
local CLASH_CPS_WINDOW=1.0
local CLASH_PANIC_DIST=6            -- §FIX PANIC em range jogável (não preciso estar colado, só perto)
local CLASH_PANIC_BALL_DIST=10      -- §FIX PANIC: bola tem que tá em cima (não do outro lado do mapa)
local CLASH_REACT_COOLDOWN=0.25     -- §v9.1 cooldown mínimo entre reativações (evita liga/desliga rápido)
local CLASH_MAX_BALL_DIST=45        -- hard cap: mesmo com cps alto, não ativa se bola estiver long4
-- §v8.8 desativação adaptativa à velocidade (INVERTIDA):
-- bola RÁPIDA (clash pesado rolando) → se tImp sobe, é pq você FUGIU → corta agressivo.
-- bola DEVAGAR (clash leve/morrendo) → tImp pode ser alto naturalmente → tolera mais.
--   spd >= 65 → 120ms (clash pesado, folga curta)
--   spd 40-65 → 140ms
--   spd 20-40 → 160ms
--   spd < 20  → 200ms (clash leve, tolera rebote lento)
local CLASH_TIMP_OFF=0.150          -- fallback legado (não usado pela lógica nova)
local CLASH_TIMP_OFF_FAST=0.120     -- spd >= 65
local CLASH_TIMP_OFF_MID=0.140      -- spd 40-65
local CLASH_TIMP_OFF_LOW=0.160      -- spd 20-40
local CLASH_TIMP_OFF_VLOW=0.200     -- spd < 20
local CLASH_SPD_FAST,CLASH_SPD_MID,CLASH_SPD_LOW=65,40,20
local CLASH_TIMP_FAR=0.380          -- §v8.7 bola claramente longe: desliga mesmo se Sync atrasado
local CLASH_TIMP_OFF_PANIC=0.250    -- §v8.7 em PANIC, tolerância maior (jogador pode tá recuando rápido)

local Sync={
    Speed=0,RealPosition=Vector3.zero,ForceDirection=false,
    ForcedDirection=Vector3.zero,DirectionInterp=0,
    DeflectDirection=Vector3.zero,Grace=false,Teleported=false,
    TeleportPosition=Vector3.zero,TargetPlayerID=-999,
    lastSyncAt=0,forcedAt=0,
}

local apLocal={ballProcessed=false,forceRelease=nil,syncRealPos=nil,syncAt=0,armed=false,fired=false,lastBallPos=nil,lastBallPosAt=0}

-- ============================================================
--   _G exports — espelho do que a GUI já cria
-- ============================================================
_G.PhantomConfig   = Config
_G.PhantomState    = State
_G.PhantomManual   = false
_G.PhantomAutoClash= true
_G.__lt_lastFire   = 0
_G.__lt_lastTarget = -999
_G.__lt_clashActive= false
_G.__phantomBall   = nil

_G.PhantomSaveConfig = function(c)
    if type(c) ~= "table" then return end
    for k,v in pairs(c) do Config[k] = v end
    _G.PhantomConfig = Config
end
_G.PhantomStop = function()
    State.scriptActive = false
    apDead = true
    if apClearBind then pcall(apClearBind) end
    disconnectAll()
    _G.PhantomManual   = false
    _G.__lt_clashActive= false
    print"[PHANTOM] stop() chamado"
end
_G.PhantomSaveConfigFile = function(path)
    path = path or "phantom_config.json"
    local ok,err = pcall(function() writefile(path, game:GetService"HttpService":JSONEncode(Config)) end)
    if not ok then warn("[PHANTOM] saveConfig falhou: "..tostring(err)) end
    return ok
end
_G.PhantomLoadConfigFile = function(path)
    path = path or "phantom_config.json"
    local ok,contents = pcall(readfile, path)
    if not ok or type(contents) ~= "string" then return false end
    local ok2,http = pcall(game.GetService, game, "HttpService")
    if not ok2 then return false end
    local ok3,dec = pcall(function() return http:JSONDecode(contents) end)
    if ok3 and type(dec) == "table" then _G.PhantomSaveConfig(dec); return true end
    return false
end

-- ============================================================
--   helpers
-- ============================================================
local apBindId,apSimConn,apDead = 0,nil,false
local function apClearBind()
    apBindId = apBindId + 1
    if apSimConn then pcall(apSimConn.Disconnect, apSimConn) end
    apSimConn = nil
end

local function trackConn(c)
    if not (c and c.Disconnect) then return c end
    State.connections = State.connections or {}
    State.connections[#State.connections+1] = c
    return c
end
local function disconnectAll()
    for i = #State.connections, 1, -1 do
        pcall(State.connections[i].Disconnect, State.connections[i])
        State.connections[i] = nil
    end
end
local function refreshCPS()
    local c = tonumber(Config.CPS) or DEFAULT_CPS
    if c < 1 then c = 1 end
    return c
end
local function apTImpCheck(d,s) return s<1 and 1e6 or d/s end
local function apGetEPing()
    local e = S.smoothedPing * 0.5 + 0.016
    if e < 0 then return 0 end
    if e > 0.150 then return 0.150 end
    return e
end
local function apSamplePing()
    local ok,p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
    if ok and type(p)=="number" and p>0 and p<0.5 then
        S.smoothedPing = S.smoothedPing*(1-PING_EMA_ALPHA) + p*PING_EMA_ALPHA
    end
end

local function safeReq(m)
    if not (m and m.Parent and typeof(m)=="Instance") then return nil end
    local ok,isOk = pcall(function() return m:IsA"ModuleScript" end)
    if not (ok and isOk) then return nil end
    local ok2,r = pcall(require, m)
    return ok2 and r or nil
end

local TSFolder = Replicated:FindFirstChild"TS"
local Remotes  = Replicated:FindFirstChild"Remotes"
local GenRemotes = TSFolder and TSFolder:FindFirstChild"GeneratedNetworkRemotes"
local enumFolder = TSFolder and TSFolder:FindFirstChild"Enums"
local abilFolder = TSFolder and TSFolder:FindFirstChild"Abilities"

local abMod = enumFolder and safeReq(enumFolder:FindFirstChild"AbilityID")
local AbilityID = abMod and abMod.AbilityID or {Deflect="Deflect"}
local defMod = abilFolder and safeReq(abilFolder:FindFirstChild"DeflectAbility")
local DeflectAbility = defMod and defMod.DeflectAbility or {}
local BindableManager = TSFolder and safeReq(TSFolder:FindFirstChild"BindableManager")

local gi = (function()
    local m = TSFolder and safeReq(TSFolder:FindFirstChild"GameInfo")
    return m and m.GameInfo
end)()
local br = (function()
    local bf = TSFolder and TSFolder:FindFirstChild"BallReplicator"
    local m  = bf and safeReq(bf:FindFirstChild"BallReplicator")
    return m and m.BallReplicator
end)()

local parryRemote, parryMode, parryInitDone

local function refreshRefs()
    if TSFolder and not TSFolder.Parent then
        TSFolder = Replicated:FindFirstChild"TS"
        GenRemotes = TSFolder and TSFolder:FindFirstChild"GeneratedNetworkRemotes"
        local ef = TSFolder and TSFolder:FindFirstChild"Enums"
        local ab2 = ef and safeReq(ef:FindFirstChild"AbilityID")
        if ab2 and ab2.AbilityID then AbilityID = ab2.AbilityID end
        local af = TSFolder and TSFolder:FindFirstChild"Abilities"
        local d2  = af and safeReq(af:FindFirstChild"DeflectAbility")
        if d2 and d2.DeflectAbility then DeflectAbility = d2.DeflectAbility end
        if not BindableManager then BindableManager = safeReq(TSFolder:FindFirstChild"BindableManager") end
        if not gi then
            local m = safeReq(TSFolder:FindFirstChild"GameInfo")
            if m and m.GameInfo then gi = m.GameInfo end
        end
        if not br then
            local bf = TSFolder:FindFirstChild"BallReplicator"
            local m  = bf and safeReq(bf:FindFirstChild"BallReplicator")
            if m and m.BallReplicator then br = m.BallReplicator end
        end
    end
    if not Remotes or not Remotes.Parent then Remotes = Replicated:FindFirstChild"Remotes" end
    if TSFolder and (not GenRemotes or not GenRemotes.Parent) then
        GenRemotes = TSFolder and TSFolder:FindFirstChild"GeneratedNetworkRemotes"
    end
end

local function validRemote(r)
    if typeof(r) ~= "Instance" then return false end
    if not r.Parent then return false end
    local ok,isOk = pcall(function() return r:IsA"RemoteEvent" end)
    return ok and isOk or false
end

local function getGameGlobal()
    if type(getfenv) ~= "function" or type(DeflectAbility) ~= "table" then return _G, _G end
    for _,fn in ipairs({DeflectAbility.Deflect, DeflectAbility.OnClientCreate, DeflectAbility.OnServerCreate, DeflectAbility.constructor}) do
        if type(fn) == "function" then
            local ok,env = pcall(getfenv, fn)
            if ok and type(env) == "table" then
                local g = rawget(env,"_G")
                return (type(g)=="table" and g or env), env
            end
        end
    end
    return _G, _G
end

local function getGameDid()
    for _,t in ipairs({getGameGlobal()}) do
        local did = type(t)=="table" and rawget(t,"did")
        if validRemote(did) then return did end
    end
    return nil
end
local function setGameDid(r)
    local g,env = getGameGlobal()
    if type(g) == "table" then rawset(g,"did", r) end
    if type(env) == "table" and env ~= g and rawget(env,"_G") == nil then rawset(env,"did", r) end
end
local function getGeneratedRemote(id)
    refreshRefs()
    local r = GenRemotes and GenRemotes:FindFirstChild("RE_"..tostring(id))
    return validRemote(r) and r or nil
end

local function cacheParryRemote(r, mode)
    if not validRemote(r) then return nil end
    parryRemote, parryMode = r, mode
    if mode == "buffer" then setGameDid(r) end
    return parryRemote, parryMode
end

local function resolveParryRemote()
    refreshRefs()
    if validRemote(parryRemote) then return parryRemote, parryMode end
    local did = getGameDid()
    if validRemote(did) then return cacheParryRemote(did, "buffer") end
    if Remotes then
        local r = Remotes:FindFirstChild("pr_"..tostring(lp.UserId))
        if validRemote(r) then return cacheParryRemote(r, "buffer") end
    end
    return cacheParryRemote(getGeneratedRemote(1), "event")
end

local function makeDeflectBuffer(flag)
    if type(buffer) ~= "table" then return nil end
    if type(buffer.fromstring) == "function" then return buffer.fromstring(flag==2 and "\2" or "\1") end
    if type(buffer.create) == "function" and type(buffer.writeu8) == "function" then
        local b = buffer.create(1); buffer.writeu8(b, 0, flag); return b
    end
end

local _spamBuf
do local ok,b = pcall(buffer.fromstring, "\1"); if ok then _spamBuf = b end end
local TouchTapEvent = Replicated:FindFirstChild"TouchTap"

local function ensureParryInitialized()
    if parryInitDone then return true end
    local r,m = resolveParryRemote()
    if not r then return false end
    if m == "event" then parryInitDone = true; return true end
    local p = makeDeflectBuffer(2)
    if not p then return false end
    local ok = pcall(r.FireServer, r, p)
    parryInitDone = ok
    return ok
end

local function fireParry(r, mode, flag)
    if not validRemote(r) then return false end
    if mode == "event" then return pcall(r.FireServer, r) end
    local p = makeDeflectBuffer(flag or 1)
    if not p then return false end
    ensureParryInitialized()
    return pcall(r.FireServer, r, p)
end

local function onParryFired()
    local n = now()
    S.lastFireAt = n
    S.clickCount = (S.clickCount or 0) + 1
    _G.__lt_lastFire = n
end

local function sendParry()
    local r,m = resolveParryRemote()
    if r and fireParry(r, m, 1) then onParryFired(); return true end
    return false
end

local function getSpamGap()
    local cps = tonumber(Config.CPS) or DEFAULT_CPS
    if cps < 1 then cps = 1 end
    return 1/cps
end

local function fireOneClick()
    local r = resolveParryRemote()
    if not (r and r.Parent and _spamBuf) then return end
    pcall(r.FireServer, r, _spamBuf)
    S.clickCount = S.clickCount + 1
    _G.__lt_lastFire = now()
end

local function maybeFireTouchTap()
    if not TouchTapEvent then return end
    if not State.scriptActive then return end
    pcall(TouchTapEvent.Fire, TouchTapEvent)
end

local SPAM_MAX_PER_ITER=50          -- §v9.4 cap alto: em lag momentâneo, scheduler pode atrasar e debt acumula;
                                    -- sem catch-up aqui, CPS escolhido vira CPS real menor. 50 dá margem
                                    -- sem explodir se travar (limite duro de 50 cliques por frame).
local SPAM_MIN_SLEEP=0.001          -- piso do sleep (1ms) — roda no próximo frame, não queima CPU

task.spawn(function()
    local debt,lastTick = 0, now()
    while State.scriptActive do
        local sleepTime = 0.005
        local ok,err = pcall(function()
            -- Spam liga em 2 casos:
            --   1) clash automático ativou (S.clashActive)
            --   2) usuário ligou Manual Spam (GUI ou hotkey F)
            local spamOn = S.clashActive or _G.PhantomManual == true
            local t = now()
            -- §v9.5 limpa janela rolling a cada 1.5s (evita array crescer infinito)
            if (t - S._cpsClWinStart) > 1.5 then
                local newWin, ws = {}, t
                for _, ts in ipairs(S._cpsClWin) do
                    if ts >= ws - 1 then newWin[#newWin+1] = ts end
                end
                S._cpsClWin = newWin
                S._cpsClWinStart = ws
            end
            if not spamOn then
                S.spamWasActive = false
                S.realCps = 0
                debt, lastTick = 0, t
                S._cpsClWin = {}
                S._cpsClWinStart = t
                return
            end
            S.spamWasActive = true
            local gap = getSpamGap()
            local dt  = t - lastTick
            lastTick  = t
            if dt > 1 then dt = 1 end  -- se ficou travado >1s, ignora (evita explosão)
            debt = debt + dt
            -- §v9.5 dispara TODOS os cliques devidos. cap=50 só age em lag extremo.
            -- TouchTapEvent espelha o click 1:1 (mesma cadência do fireOneClick).
            local n = 0
            while debt >= gap and n < SPAM_MAX_PER_ITER do
                fireOneClick()
                maybeFireTouchTap()
                S._cpsClWin[#S._cpsClWin+1] = now()
                debt = debt - gap
                n    = n + 1
            end
            -- CPS real = contagem na janela (últimos 1s) = quanto o server vai receber
            S.realCps = #S._cpsClWin
            -- dorme até o próximo gap, com piso de 1ms pra não busy-loop
            sleepTime = gap - debt
            if sleepTime < SPAM_MIN_SLEEP then sleepTime = SPAM_MIN_SLEEP end
        end)
        if not ok then warn("[PHANTOM] spam loop error: "..tostring(err)); S.spamWasActive = false end
        if S.spamWasActive then task.wait(sleepTime) else task.wait(0.005) end
    end
end)

-- ============================================================
--   Bola
-- ============================================================
local function getBall()
    local cached = _G.__phantomBall
    if cached and cached.Parent then return cached end
    if br and type(br.GetBall) == "function" then
        local ok, b = pcall(function() return br.GetBall() end)
        if ok and b and b.Parent then _G.__phantomBall = b; return b end
    end
    if ws then
        local b = ws:FindFirstChild("Ball") or ws:FindFirstChild("Football")
        if b and b.Parent then _G.__phantomBall = b; return b end
    end
    return nil
end

-- ============================================================
--   §v9 AUTO CLASH — dinâmico, porta do auto-clash-dinamico.lua
-- ============================================================
--   Ativação: cps de mudanças de target >= 17/s OU PANIC.
--   Desativação: tImp > limite adaptativo (spd), tImp > 380ms (far), ou bola > 25 studs.
--   Reativação via BallSync: tImp <= 250ms OU PANIC, com hard cap de 25 studs.
--   Ping-comp: credita spd*oneWayPing studs no cálculo do tImp.
-- ============================================================
local function evaluateClashByCps()
    if _G.PhantomAutoClash == false or Config.AutoClash == false then return end
    if _G.PhantomManual == true then return end
    local hr = lp.Character and lp.Character:FindFirstChild"HumanoidRootPart"
    if not (hr and hr.Parent) then return end

    local t = now()
    local windowStart = t - CLASH_CPS_WINDOW
    local count = 0
    for i = 1, 8 do
        local ts = S.targetChangeT[i]
        if ts and ts >= windowStart then count = count + 1 end
    end
    S.targetCps = count / CLASH_CPS_WINDOW

    local ball = getBall()
    if not (ball and ball.Parent) then return end

    local nearest = math.huge
    for _,p in Players:GetPlayers() do
        if p ~= lp and p.Character then
            local php = p.Character:FindFirstChild"HumanoidRootPart"
            if php and php.Parent then
                local d = (hr.Position - php.Position).Magnitude
                if d < nearest then nearest = d end
            end
        end
    end
    local ballDist = (hr.Position - ball.Position).Magnitude
    -- PANIC relaxado: player colado (≤6) + bola perto (≤10). Não exige target=meu,
    -- porque no frame exato o Sync.TargetPlayerID pode estar com 1-2 frames de delay.
    -- Confiamos no player-colado + bola-perto como sinal suficiente.
    local panic = (nearest <= CLASH_PANIC_DIST and ballDist <= CLASH_PANIC_BALL_DIST)

    -- §v8.7 tImp (time-to-impact): termômetro da desativação.
    -- usa Sync se fresh (<300ms), senão cai pra velocity do ball.
    -- se velocidade quase zero (bola parada/volta inicial) → tImp = ∞ → longe.
    local syncFresh = (t - Sync.lastSyncAt) < 0.3
    local bp = (syncFresh and Sync.RealPosition ~= Vector3.zero) and Sync.RealPosition or ball.Position
    local spd
    if syncFresh and Sync.Speed > 0 then spd = Sync.Speed
    else
        local ok,av = pcall(function() return ball.AssemblyLinearVelocity end)
        spd = (ok and typeof(av) == "Vector3") and av.Magnitude or 0
    end
    local tImp
    if spd < 1 then tImp = math.huge  -- bola parada / recem-spawn: longe por definição
    else
        -- §v9 ping compensation: BallSync chega com delay oneWayPing.
        -- bola real já tá (spd*oneWayPing) studs mais perto que o Sync.RealPosition.
        -- creditamos esse trajeto no tImp pra ativar cedo em server lag.
        local oneWayPing = apGetEPing()
        local rawDist = (hr.Position - bp).Magnitude
        local creditedTravel = math.min(rawDist, spd * oneWayPing)
        tImp = (rawDist - creditedTravel) / spd  -- = rawDist/spd - oneWayPing (clamped >= 0)
    end
    S.lastTImp = tImp

    -- Gating de cold start: se clash ainda não tá ativo, só permite ligar se:
    --  * PANIC (player colado + bola perto), OU
    --  * Target é meu E a bola tá perto (≤ CLASH_BALL_RANGE studs, configurado em 18).
    -- Quando clashActive=true, comportamento normal (mantém até cps cair).
    local targetIsMe  = (Sync.TargetPlayerID == lp.UserId)
    local ballInRange = ballDist <= CLASH_BALL_RANGE
    local coldStartGate = panic or (targetIsMe and ballInRange)

    -- §v9.1 cooldown mínimo entre reativações (evita liga/desliga rápido)
    local canReact = (t - S.lastClashReact) >= CLASH_REACT_COOLDOWN

    if (S.targetCps >= CLASH_CPS_THRESHOLD or panic) and (S.clashActive or coldStartGate) and canReact then
        if not S.clashActive then
            S.clashActive       = true
            S.clashActivatedAt  = t
            S.clashHoldUntil    = t + CLASH_HOLD
            S.lastClashReact    = t
            _G.__lt_clashActive = true
            print(("[PHANTOM] AutoClash ON (cps=%.2f, tImp=%.0fms, panic=%s, targetIsMe=%s, ballDist=%.1f, nearest=%.1f)"):format(S.targetCps, tImp*1000, tostring(panic), tostring(targetIsMe), ballDist, nearest))
        end
    else
        -- §v8.8 desativação adaptativa à velocidade (INVERTIDA).
        -- A ativação continua sendo por targetCps (17+ mudanças/s) ou PANIC.
        -- A desativação olha tImp + spd pra decidir se ainda vale a pena spammar:
        --   spd >= 65 → tImp OFF 120ms (clash pesado rolando; se tImp sobe aqui,
        --             você provavelmente FUGIU — a bola ainda tá num clash pesado
        --             entre outros players, então o AutoParry dá conta sozinho)
        --   spd 40-65 → tImp OFF 140ms
        --   spd 20-40 → tImp OFF 160ms
        --   spd < 20  → tImp OFF 200ms (clash leve/morrendo, tolera rebote lento)
        -- PANIC: tolerância 250ms (jogador pode tá recuando rápido mas ainda é clash).
        -- CLASH_TIMP_FAR (380ms): hard cap, mesmo se tudo falhar.
        if S.clashActive then
            local tImpBase
            if spd >= CLASH_SPD_FAST then
                tImpBase = CLASH_TIMP_OFF_FAST
            elseif spd >= CLASH_SPD_MID then
                tImpBase = CLASH_TIMP_OFF_MID
            elseif spd >= CLASH_SPD_LOW then
                tImpBase = CLASH_TIMP_OFF_LOW
            else
                tImpBase = CLASH_TIMP_OFF_VLOW
            end
            local tImpLimit = panic and CLASH_TIMP_OFF_PANIC or tImpBase
            -- §v9.0 FIX: hard cap de distância na manutenção. Se bola tá > 25 studs (sem PANIC),
            -- desliga imediatamente — clash só vale a pena com bola próxima.
            local tooFarToClash = (ballDist > 25 and not panic)
            if tImp > CLASH_TIMP_FAR or tImp > tImpLimit or tooFarToClash then
                S.clashActive       = false
                _G.__lt_clashActive = false
                S.clashHoldUntil    = 0
                print(("[PHANTOM] AutoClash OFF (spd=%.1f, tImp=%.0fms > %.0fms, panic=%s, cps=%.2f)"):format(spd, tImp*1000, tImpLimit*1000, tostring(panic), S.targetCps))
            end
        end
    end
end

local function nearestOtherPlayerDist(hrp)
    local best = math.huge
    for _,p in Players:GetPlayers() do
        if p ~= lp and p.Character then
            local php = p.Character:FindFirstChild"HumanoidRootPart"
            if php and php.Parent then
                local d = (hrp.Position - php.Position).Magnitude
                if d < best then best = d end
            end
        end
    end
    return best
end

local function clearClash()
    S.clashActive, _G.__lt_clashActive = false, false
    S.clashHoldUntil, S.spamDrainUntil, S.spamStartedAt = 0,0,0
    S.spamWasActive = false
end

local function decayClash()
    if not S.clashActive then return end
    if Config.AutoClash == false or _G.PhantomAutoClash == false then clearClash(); return end
    -- §v8.7 decay agora é só safety net: se passou CLASH_DECAY (310ms) E o holdUntil expirou
    -- E a bola sumiu do workspace, desliga. O critério de tImp já tá no evaluateClashByCps.
    local t = now()
    if (t - S.clashActivatedAt) > CLASH_DECAY and t >= S.clashHoldUntil then
        local ball = getBall()
        if not (ball and ball.Parent) then clearClash() end
    end
end

task.spawn(function() while State.scriptActive do pcall(decayClash); task.wait(0.05) end end)

local function isTargeted(ch)
    if Sync.TargetPlayerID == lp.UserId then return true end
    if S.lastTarget == lp.UserId then return true end
    if ch and ch:FindFirstChild"Highlight" then return true end
    if ws:GetAttribute"GameBallTarget" == lp.UserId then return true end
    local sd = br and br.syncData
    return sd and sd.HighlightTargetPlayerID == lp.UserId or false
end

-- ============================================================
--   Auto Parry (mantido idêntico ao drax original)
-- ============================================================
local function bindParry(ch)
    apClearBind()
    if apDead or not (ch and ch.Parent) then return end
    local myId = apBindId
    local hrp  = ch:FindFirstChild"HumanoidRootPart"
    if not hrp then hrp = ch:WaitForChild("HumanoidRootPart", 1) end
    if myId ~= apBindId or not (hrp and hrp.Parent) then return end

    apLocal.ballProcessed = false
    apLocal.forceRelease   = nil

    local PREFIRE_S       = 0.13
    local PARRY_DEFLECT_R = 8   -- raio base (escala com spd igual antes)
    local PARRY_RAD_FLOOR = 12  -- chão: bola lenta nunca parry com menos de 12 studs
    local PARRY_MIN_SPEED = 5
    local PARRY_PING_COMP = 0.0 -- compensação por VELOCIDADE (não por ping) — bola anda RTT inteiro, server aceita janela de 0.85s

    apSimConn = RunService.Heartbeat:Connect(function(dt)
        if apDead or myId ~= apBindId then return end
        if not (ch.Parent and hrp.Parent) then apClearBind(); return end
        if Config.AutoParry ~= true then return end   -- GUI controla

        local t = now()
        if t < S.teleportLockUntil or Sync.Grace then return end
        if S.clashActive or _G.PhantomManual == true then return end

        local ball = getBall()
        if not (ball and ball.Parent) then return end

        if Sync.TargetPlayerID ~= lp.UserId then apLocal.armed = false; return end
        if not apLocal.armed then apLocal.armed = true end

        local syncFresh = (t - Sync.lastSyncAt) < 0.3
        local bp = (syncFresh and Sync.RealPosition ~= Vector3.zero) and Sync.RealPosition or ball.Position

        local spd
        if syncFresh and Sync.Speed > 0 then spd = Sync.Speed
        else
            local ok,av = pcall(function() return ball.AssemblyLinearVelocity end)
            spd = (ok and typeof(av) == "Vector3") and av.Magnitude or 0
        end
        if spd < PARRY_MIN_SPEED then return end

        -- §FIX compensação de ping (light): projeta bp um pouquinho pra frente no eixo
        -- bola→player pra cobrir o one-way ping. Não projeta RTT inteiro pq isso
        -- faz a bola "puxar demais" e o parry fica adiantado.
        local pingComp   = apGetEPing() * 0.6
        local projectedBp = bp
        if pingComp > 0 and spd > 1 then
            local dirToPlayer = (hrp.Position - bp).Unit
            projectedBp = bp - dirToPlayer * spd * pingComp
        end
        local parryRad = PARRY_DEFLECT_R + spd * PREFIRE_S
        if parryRad < PARRY_RAD_FLOOR then parryRad = PARRY_RAD_FLOOR end
        local dist = (hrp.Position - projectedBp).Magnitude
        local dist = (hrp.Position - bp).Magnitude

        -- §FIX rearm por ciclo de aproximação (light): exige afastamento claro da bola
        -- (radialNew > radialOld + 4) E bola bem longe do parryRad pra garantir que
        -- já saiu da zona. Evita rearm fantasma em bola passando raspando.
        if apLocal.fired and apLocal.lastBallPos and apLocal.lastBallPosAt then
            local dBall   = (bp - apLocal.lastBallPos).Magnitude
            local dBallDt = t - apLocal.lastBallPosAt
            if dBallDt > 0 and dBallDt < 0.1 then
                local ballSpeed = dBall / dBallDt
                if ballSpeed > 5 then
                    local radialOld = (apLocal.lastBallPos - hrp.Position).Magnitude
                    local radialNew = dist
                    if radialNew > radialOld + 4 and dist > parryRad then
                        apLocal.fired = false
                    end
                end
            end
        end
        apLocal.lastBallPos   = bp
        apLocal.lastBallPosAt = t

        if dist > parryRad then return end

        if apLocal.fired then return end

        S.pingTimer = S.pingTimer + dt
        if S.pingTimer >= 0.3 then S.pingTimer = 0; apSamplePing() end

        apLocal.fired = true
        _G.__lt_apFired = true; _G.__lt_apFiredAt = t
        S.lastFireAt = t
        task.defer(sendParry)
    end)
    trackConn(apSimConn)

    trackConn(ch.AncestryChanged:Connect(function(_,p)
        if not p then apLocal.ballProcessed = false; apClearBind() end
    end))
end

-- ============================================================
--   Keybinds — usa Config.SpamKeybind / Config.Keybind / Config.SpamMode
-- ============================================================
local keyConn
local function installKeybinds()
    if keyConn then pcall(keyConn.Disconnect, keyConn); keyConn = nil end
    local panicKey = Config.Keybind
    local spamKey  = Config.SpamKeybind
    local mode     = Config.SpamMode or "Toggle"
    keyConn = UIS.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == panicKey then
            S.clashActive = false
            S.clashActivatedAt, S.spamWasActive, S.spamLastFire, S.spamStartedAt = 0, false, 0, 0
            apLocal.ballProcessed = false
            _G.PhantomManual, _G.__lt_clashActive = false, false
            clearClash()
            print"[PHANTOM] panic reset (keybind)"
        elseif inp.KeyCode == spamKey then
            if mode == "Hold" then
                _G.PhantomManual = true
            else
                _G.PhantomManual = not _G.PhantomManual
                S.spamWasActive, S.spamLastFire, S.spamStartedAt = false, 0, 0
                print(("[PHANTOM] Manual Spam %s"):format(_G.PhantomManual and "ON" or "OFF"))
            end
        end
    end)
    trackConn(keyConn)
    if mode == "Hold" then
        trackConn(UIS.InputEnded:Connect(function(i) if i.KeyCode == spamKey then _G.PhantomManual = false end end))
    end
end

-- ============================================================
--   Sincronização com a GUI (polling a cada 0.5s)
-- ============================================================
local CONFIG_KEYS = {"AutoParry","AutoClash","CPS","CustomCPS","Keybind","SpamKeybind","SpamMode","Aura"}
local function applyConfigFromGUI()
    local c = _G.PhantomConfig
    if type(c) ~= "table" then return false end
    local changed = false
    for _,k in ipairs(CONFIG_KEYS) do
        if c[k] ~= nil and c[k] ~= Config[k] then
            Config[k] = c[k]
            changed = true
        end
    end
    _G.PhantomConfig = Config
    return changed
end

local function pollGUI(dt)
    if S.guiPollAcc == nil then S.guiPollAcc = 0 end
    S.guiPollAcc = S.guiPollAcc + dt
    if S.guiPollAcc < 0.25 then return end
    S.guiPollAcc = 0
    if applyConfigFromGUI() then
        S.guiReady = true
        refreshCPS()
        installKeybinds()
        if not S._guiAnnounced then
            S._guiAnnounced = true
            print"[PHANTOM] GUI detectada, sincronizado"
        end
    end
end

-- loop extra: aplica config mesmo depois de já ter detectado, pra pegar
-- mudanças em tempo real (CPS, toggles, keybinds).
task.spawn(function()
    while State.scriptActive do
        if S.guiReady then applyConfigFromGUI() end
        task.wait(0.25)
    end
end)

local function bindCharacter(ch)
    if not (ch and ch.Parent) then return end
    local hrp = ch:FindFirstChild"HumanoidRootPart" or ch:WaitForChild("HumanoidRootPart", 9e9)
    if not (hrp and hrp.Parent) then return end
    local conn, dead = nil, false
    local function clear() dead = true; if conn then pcall(conn.Disconnect, conn); conn = nil end end
    trackConn(ch.AncestryChanged:Connect(function(_,p) if not p then clear(); apClearBind() end end))
    conn = RunService.Heartbeat:Connect(function(dt)
        if dead or not State.scriptActive then clear(); return end
        if not (ch.Parent and hrp.Parent) then clear(); return end
        pollGUI(dt)
        decayClash()
        evaluateClashByCps()
        local t = now()
        if dt > 0.05 then
            S.slowFrames = S.slowFrames + 1
            if (t - S.lastSlowFrameLog) > 30 then
                S.lastSlowFrameLog = t
                warn(("[PHANTOM] slow frame: dt=%.3f, total slow=%d"):format(dt, S.slowFrames))
            end
        end
    end)
    trackConn(conn)
end

task.spawn(function()
    local tries = 0
    while State.scriptActive do
        tries = tries + 1
        local ok,err = pcall(function()
            refreshRefs()
            if resolveParryRemote() then ensureParryInitialized() end
        end)
        if not ok then warn("[PHANTOM] boot try "..tries.." falhou: "..tostring(err)) end
        if tries >= 3 and tries % 5 == 0 then warn("[PHANTOM] ainda sem remote após "..tries.." tentativas") end
        task.wait(1)
        if tries >= BOOT_MAX_TRIES then break end
    end
end)

local function onChar(ch)
    S.lastTarget = -999
    _G.__lt_lastTarget = -999
    S.clashActive, S.clashActivatedAt, _G.__lt_clashActive = false, 0, false
    apLocal.ballProcessed = false
    apLocal.forceRelease   = nil
    task.defer(function()
        local ok = pcall(bindParry, ch)
        if not ok then task.delay(0.2, function() pcall(bindParry, ch) end) end
    end)
    task.defer(function() pcall(bindCharacter, ch) end)
end
trackConn(lp.CharacterAdded:Connect(onChar))
if lp.Character then task.defer(function() pcall(onChar, lp.Character) end) end

local function bindBall(b) if not b or S.ball == b then return end; S.ball, _G.__phantomBall = b, b end

local existing = ws:FindFirstChild"GameBall"
if existing then bindBall(existing) end
trackConn(ws.ChildAdded:Connect(function(c) if c.Name == "GameBall" then bindBall(c) end end))
trackConn(ws.ChildRemoved:Connect(function(c) if c.Name == "GameBall" then S.ball, _G.__phantomBall = nil, nil end end))

local ballSyncRemote = Remotes and Remotes:FindFirstChild"BallSyncData"
if ballSyncRemote and ballSyncRemote:IsA"RemoteEvent" then
    trackConn(ballSyncRemote.OnClientEvent:Connect(function(data)
        if typeof(data) ~= "table" then return end
        local t = now()

        if type(data.Speed) == "number" then Sync.Speed = data.Speed end
        if typeof(data.RealPosition) == "Vector3" then Sync.RealPosition = data.RealPosition end
        if typeof(data.DeflectDirection) == "Vector3" then Sync.DeflectDirection = data.DeflectDirection end
        if type(data.DirectionInterp) == "number" then Sync.DirectionInterp = data.DirectionInterp end
        if type(data.Grace) == "boolean" then Sync.Grace = data.Grace end

        if type(data.ForceDirection) == "boolean" then
            if data.ForceDirection and not Sync.ForceDirection then Sync.forcedAt = t end
            Sync.ForceDirection = data.ForceDirection
        end
        if typeof(data.ForcedDirection) == "Vector3" then Sync.ForcedDirection = data.ForcedDirection end
        Sync.lastSyncAt = t

        if data.Teleported == true then
            S.teleportLockUntil = t + TELEPORT_LOCKOUT
            apLocal.ballProcessed = false
            apLocal.forceRelease   = nil
            S.clashActive, S.clashActivatedAt = false, 0
            S.spamWasActive, S.spamLastFire, S.spamStartedAt = false, 0, 0
            if typeof(data.TeleportPosition) == "Vector3" then Sync.TeleportPosition = data.TeleportPosition end
            Sync.Teleported = true
            return
        end
        Sync.Teleported = false

        Sync.TargetPlayerID = data.TargetPlayerID
        if data.TargetPlayerID and data.TargetPlayerID ~= S.lastTarget then
            -- §v8.6 push timestamp de mudança de target (ring buffer circular, 8 slots)
            S.targetChangeIdx = (S.targetChangeIdx % 8) + 1
            S.targetChangeT[S.targetChangeIdx] = t
            local prev, targeted = S.lastTarget, data.TargetPlayerID == lp.UserId
            S.lastTarget, _G.__lt_lastTarget = data.TargetPlayerID, data.TargetPlayerID
            if targeted then
                local hr = lp.Character and lp.Character:FindFirstChild"HumanoidRootPart"
                local tImp = math.huge
                if hr and hr.Parent then
                    local b = getBall()
                    if b and b.Parent then
                        local ballDist = (hr.Position - b.Position).Magnitude
                        local curSpd
                        if (t - Sync.lastSyncAt) < 0.3 and Sync.Speed and Sync.Speed > 0 then curSpd = Sync.Speed
                        else
                            local ok2,av = pcall(function() return b.AssemblyLinearVelocity end)
                            curSpd = (ok2 and typeof(av) == "Vector3") and av.Magnitude or 0
                        end
                        if curSpd > 1 then tImp = ballDist / curSpd end
                    end
                end
                apLocal.ballProcessed = (tImp <= 0.25)
                apLocal.forceRelease  = true
                apLocal.fired         = false
                apLocal.armed         = true
            else
                apLocal.ballProcessed = false
                apLocal.forceRelease  = nil
                apLocal.armed         = false
                apLocal.fired         = false
            end

            if (_G.PhantomAutoClash ~= false) and (Config.AutoClash ~= false) and not _G.PhantomManual and targeted and prev ~= lp.UserId and prev ~= -999 then
                local hr = lp.Character and lp.Character:FindFirstChild"HumanoidRootPart"
                if hr and hr.Parent then
                    local okB,b = pcall(getBall)
                    if okB and b and b.Parent then
                        -- §v8.7 reativação por BallSync agora é tImp-driven (igual evaluateClashByCps).
                        -- sem nearestPlayer: distância de player não é critério de clash.
                        local ballDist = (hr.Position - b.Position).Magnitude
                        local curSpd
                        if (t - Sync.lastSyncAt) < 0.3 and Sync.Speed and Sync.Speed > 0 then curSpd = Sync.Speed
                        else
                            local ok2,av = pcall(function() return b.AssemblyLinearVelocity end)
                            curSpd = (ok2 and typeof(av) == "Vector3") and av.Magnitude or 0
                        end
                        local tImpReact
                        if curSpd < 1 then tImpReact = math.huge
                        else
                            -- §v9 ping compensation na reativação via BallSyncData.
                            -- o RealPosition do Sync tem oneWayPing de atraso;
                            -- bola real já tá (curSpd*oneWayPing) studs mais perto.
                            local oneWayPingR = apGetEPing()
                            local credited = math.min(ballDist, curSpd * oneWayPingR)
                            tImpReact = (ballDist - credited) / curSpd
                        end

                        -- PANIC check: player colado + bola perto (não depende de tImp).
                        local nearestReact = math.huge
                        for _,p in Players:GetPlayers() do
                            if p ~= lp and p.Character then
                                local php = p.Character:FindFirstChild"HumanoidRootPart"
                                if php and php.Parent then
                                    local pd = (hr.Position - php.Position).Magnitude
                                    if pd < nearestReact then nearestReact = pd end
                                end
                            end
                        end
                        local panicReact = (nearestReact <= CLASH_PANIC_DIST and ballDist <= CLASH_PANIC_BALL_DIST)

                        -- §v9.0 FIX: hard cap de distância na reativação via BallSync.
                        -- Antes reativava com bola a 60+ studs se tImp curto (spd*ping compensava demais).
                        -- Agora: nunca reativa se bola > 25 studs, mesmo com tImp curto.
                        local tImpReactLimit = CLASH_TIMP_OFF_PANIC  -- 250ms
                        local ballDistReactCap = 25  -- §v9.0 nunca reativa clash com bola > 25 studs
                        if ballDist > ballDistReactCap and not panicReact then
                            -- longe demais, deixa AutoParry lidar
                        elseif panicReact or tImpReact <= tImpReactLimit then
                            local tt = now()
                            if (tt - S.lastClashReact) < CLASH_REACT_COOLDOWN then return end  -- §v9.1 cooldown
                            S.clashActive       = true
                            S.clashActivatedAt  = tt
                            S.lastClashReact    = tt
                            -- não seta clashHoldUntil: desativação por tImp precisa conseguir
                            -- desligar entre rebotes. CLASH_HOLD só vale pro cold start.
                            S.spamDrainUntil = 0
                            S.spamWasActive, S.spamLastFire, S.spamStartedAt = false, 0, 0
                            _G.__lt_clashActive = true
                            print(("[PHANTOM] AutoClash ON (tImp=%.0fms comp, raw=%.0fms, ping=%.0fms, panic=%s, ballDist=%.1f)"):format(tImpReact*1000, (ballDist/curSpd)*1000, apGetEPing()*1000, tostring(panicReact), ballDist))
                        end
                    end
                end
            end
        end
    end))
end

-- ============================================================
--   Carregamento da GUI (você vai trocar o loadstring depois)
-- ============================================================
local PHANTOM_GUI_URL = "https://raw.githubusercontent.com/Repp35/Roblox/refs/heads/main/ph-gui.luau"
local HTTP_ATTEMPTS = {
    {name="game.HttpGet",  ok=type(game)=="table" and type(game.HttpGet)=="function" and type(syn)~="table" and type(request)~="function" and type(http_request)~="function",
     call=function() return game:HttpGet(PHANTOM_GUI_URL) end, wrap=false},
    {name="request",       ok=type(request)=="function",      call=function() return request({Url=PHANTOM_GUI_URL, Method="GET"}) end, wrap=true},
    {name="http_request",  ok=type(http_request)=="function", call=function() return http_request({Url=PHANTOM_GUI_URL, Method="GET"}) end, wrap=true},
    {name="syn.request",   ok=type(syn)=="table" and type(syn.request)=="function",
     call=function() return syn.request({Url=PHANTOM_GUI_URL, Method="GET"}) end, wrap=true},
}

task.defer(function()
    if _G.__phantomGUI_loaded then print"[PHANTOM] GUI já carregada externamente, pulando"; return end
    local guiSrc = rawget(_G, "__phantomGUI_src")
    if type(guiSrc) ~= "string" or #guiSrc == 0 then
        for _,a in ipairs(HTTP_ATTEMPTS) do
            if a.ok then
                local ok2,res = pcall(a.call)
                local body = a.wrap and (ok2 and res and res.Body) or (ok2 and res)
                if type(body) == "string" and #body > 0 then guiSrc = body; break
                else warn("[PHANTOM] "..a.name.." falhou") end
            end
        end
        if not guiSrc then warn"[PHANTOM] Nenhum método HTTP disponível. Backend rodando standalone." end
    end
    if type(guiSrc) ~= "string" or #guiSrc == 0 then warn"[PHANTOM] Source da GUI vazio. Backend rodando standalone."; return end
    if type(loadstring) ~= "function" then warn"[PHANTOM] loadstring indisponível. GUI não carregada."; return end
    local fn,err = loadstring(guiSrc)
    if not fn then warn("[PHANTOM] Falha ao compilar GUI: "..tostring(err)); return end
    _G.__phantomGUI_src = guiSrc
    local ok, runErr = pcall(fn)
    if ok then _G.__phantomGUI_loaded = true; print"[PHANTOM] GUI carregada"
    else warn("[PHANTOM] GUI crashou: "..tostring(runErr)) end
end)

task.defer(function()
    task.wait(0.1)
    pcall(refreshRefs)
    print(("[PHANTOM] Auto Parry + Auto Clash (v9 dinâmico) + Manual Spam carregado. GameId=%s, TS=%s, Remotes=%s"):format(
        tostring(game.GameId), TSFolder and "ok" or "nil", Remotes and "ok" or "nil"
    ))
end)
