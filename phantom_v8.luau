local Players,RunService,Replicated,Stats,UIS=game:GetService"Players",game:GetService"RunService",game:GetService"ReplicatedStorage",game:GetService"Stats",game:GetService"UserInputService"
local lp,ws=Players.LocalPlayer,workspace
local now=os.clock

local CLASH_DECAY,CLASH_PLAYER_DIST,CLASH_BALL_RANGE=0.20,25,38
local DEFAULT_CPS,BOOT_MAX_TRIES=25,30
local PING_EMA_ALPHA,PARRY_COOLDOWN,PARRY_MIN_SPEED,PARRY_MIN_RAD=0.5,0.08,5,12
local PARRY_RAD_BASE,PARRY_RAD_RADIAL,TELEPORT_LOCKOUT,FORCED_DIR_TTL=6,8,0.20,0.20
local GRACE_BLOCK_PARRY,CLASH_HOLD,CLASH_PLAYER_DIST_AP=true,0.30,25

local function apDeflectionWindow(speed)return math.clamp(0.85-(speed-16)/584*0.65,0.20,0.85)end

local Config={AutoParry=true,ManualSpam=false,AutoClash=true,CPS=DEFAULT_CPS,CustomCPS=false,Keybind=Enum.KeyCode.F9,SpamKeybind=Enum.KeyCode.F,SpamMode="Toggle",Aura=false,MiniX=nil,MiniY=nil,PanelX=nil,PanelY=nil,BtnX=nil,BtnY=nil}
local State={scriptActive=true,connections={}}
local S={ball=nil,lastTarget=-999,clashActive=false,clashActivatedAt=0,clashHoldUntil=0,spamDrainUntil=0,spamWasActive=false,spamLastFire=0,spamStartedAt=0,clickCount=0,slowFrames=0,lastSlowFrameLog=0,guiReady=false,guiPollAcc=0,smoothedPing=0.05,pingTimer=0,lastFireAt=0,teleportLockUntil=0,
    -- §v8.6 auto clash por cps de mudança de target (independente do BallSyncData delay)
    targetChangeT={},targetChangeIdx=0,targetCps=0}

local CLASH_CPS_THRESHOLD=4.3
local CLASH_CPS_WINDOW=1.0
local CLASH_PANIC_DIST=6
local CLASH_PANIC_BALL_DIST=15
local CLASH_MAX_BALL_DIST=45  -- hard cap: mesmo com cps alto, não ativa se bola estiver long4

local Sync={Speed=0,RealPosition=Vector3.zero,ForceDirection=false,ForcedDirection=Vector3.zero,DirectionInterp=0,DeflectDirection=Vector3.zero,Grace=false,Teleported=false,TeleportPosition=Vector3.zero,TargetPlayerID=-999,lastSyncAt=0,forcedAt=0}

local apLocal={ballProcessed=false,forceRelease=nil,syncRealPos=nil,syncAt=0,armed=false,fired=false}

_G.PhantomConfig=Config
_G.PhantomState=State
_G.PhantomSaveConfig=function(c)if type(c)=="table"then for k,v in pairs(c)do Config[k]=v end end end
_G.PhantomStop=function()State.scriptActive=false;apDead=true;if apClearBind then pcall(apClearBind)end;disconnectAll();_G.PhantomManual=false;_G.__lt_clashActive=false;print"[PHANTOM] stop() chamado"end
_G.PhantomSaveConfigFile=function(path)path=path or"phantom_config.json";local ok,err=pcall(function()writefile(path,game:GetService"HttpService":JSONEncode(Config))end);if not ok then warn("[PHANTOM] saveConfig falhou: "..tostring(err))end;return ok end
_G.PhantomLoadConfigFile=function(path)path=path or"phantom_config.json";local ok,contents=pcall(readfile,path);if not ok or type(contents)~="string"then return false end;local ok2,decoded=pcall(game.GetService,game,"HttpService");if not ok2 then return false end;local ok3,dec=pcall(function()return decoded:JSONDecode(contents)end);if ok3 and type(dec)=="table"then _G.PhantomSaveConfig(dec);return true end;return false end
_G.PhantomManual=false
_G.PhantomAutoClash=true
_G.__lt_lastFire=0
_G.__lt_lastTarget=-999
_G.__lt_clashActive=false
_G.__phantomBall=nil

local apBindId,apSimConn,apDead=0,nil,false
local function apClearBind()apBindId=apBindId+1;if apSimConn then pcall(apSimConn.Disconnect,apSimConn)end;apSimConn=nil end

local function trackConn(c)if not(c and c.Disconnect)then return c end;State.connections=State.connections or{};State.connections[#State.connections+1]=c;return c end
local function disconnectAll()for i=#State.connections,1,-1 do pcall(State.connections[i].Disconnect,State.connections[i]);State.connections[i]=nil end end
local function refreshCPS()local c=tonumber(Config.CPS)or DEFAULT_CPS;return c<1 and 1 or c end
local function apTImpCheck(d,s)return s<1 and 1e6 or d/s end
local function apGetEPing()local e=S.smoothedPing*0.5+0.016;if e<0 then return 0 end;if e>0.080 then return 0.080 end;return e end
local function apSamplePing()local ok,p=pcall(function()return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end);if ok and type(p)=="number"and p>0 and p<0.5 then S.smoothedPing=S.smoothedPing*(1-PING_EMA_ALPHA)+p*PING_EMA_ALPHA end end

local function safeReq(m)if not(m and m.Parent and m.IsA and m:IsA"ModuleScript")then return nil end;local ok,r=pcall(require,m);return ok and r or nil end

local TSFolder=Replicated:FindFirstChild"TS"
local Remotes=Replicated:FindFirstChild"Remotes"
local GenRemotes=TSFolder and TSFolder:FindFirstChild"GeneratedNetworkRemotes"
local enumFolder=TSFolder and TSFolder:FindFirstChild"Enums"
local abilFolder=TSFolder and TSFolder:FindFirstChild"Abilities"

local abMod=enumFolder and safeReq(enumFolder:FindFirstChild"AbilityID")
local AbilityID=abMod and abMod.AbilityID or{Deflect="Deflect"}
local defMod=abilFolder and safeReq(abilFolder:FindFirstChild"DeflectAbility")
local DeflectAbility=defMod and defMod.DeflectAbility or{}
local BindableManager=TSFolder and safeReq(TSFolder:FindFirstChild"BindableManager")

local gi=(function()local m=TSFolder and safeReq(TSFolder:FindFirstChild"GameInfo");return m and m.GameInfo end)()
local br=(function()local bf=TSFolder and TSFolder:FindFirstChild"BallReplicator";local m=bf and safeReq(bf:FindFirstChild"BallReplicator");return m and m.BallReplicator end)()

local parryRemote,parryMode,parryInitDone

local function refreshRefs()
    if TSFolder and not TSFolder.Parent then
        TSFolder=Replicated:FindFirstChild"TS"
        GenRemotes=TSFolder and TSFolder:FindFirstChild"GeneratedNetworkRemotes"
        local ef=TSFolder and TSFolder:FindFirstChild"Enums"
        local ab2=ef and safeReq(ef:FindFirstChild"AbilityID")
        if ab2 and ab2.AbilityID then AbilityID=ab2.AbilityID end
        local af=TSFolder and TSFolder:FindFirstChild"Abilities"
        local d2=af and safeReq(af:FindFirstChild"DeflectAbility")
        if d2 and d2.DeflectAbility then DeflectAbility=d2.DeflectAbility end
        if not BindableManager then BindableManager=safeReq(TSFolder:FindFirstChild"BindableManager")end
        if not gi then local m=safeReq(TSFolder:FindFirstChild"GameInfo");if m and m.GameInfo then gi=m.GameInfo end end
        if not br then local bf=TSFolder:FindFirstChild"BallReplicator";local m=bf and safeReq(bf:FindFirstChild"BallReplicator");if m and m.BallReplicator then br=m.BallReplicator end end
    end
    if not Remotes or not Remotes.Parent then Remotes=Replicated:FindFirstChild"Remotes"end
    if TSFolder and(not GenRemotes or not GenRemotes.Parent)then GenRemotes=TSFolder and TSFolder:FindFirstChild"GeneratedNetworkRemotes"end
end

local function validRemote(r)return typeof(r)=="Instance"and r.Parent~=nil and r.IsA and r:IsA"RemoteEvent"end

local function getGameGlobal()
    if type(getfenv)~="function"or type(DeflectAbility)~="table"then return _G,_G end
    for _,fn in ipairs({DeflectAbility.Deflect,DeflectAbility.OnClientCreate,DeflectAbility.OnServerCreate,DeflectAbility.constructor})do
        if type(fn)=="function"then
            local ok,env=pcall(getfenv,fn)
            if ok and type(env)=="table"then local g=rawget(env,"_G");return(type(g)=="table"and g or env),env end
        end
    end
    return _G,_G
end

local function getGameDid()for _,t in ipairs({getGameGlobal()})do local did=type(t)=="table"and rawget(t,"did");if validRemote(did)then return did end end;return nil end
local function setGameDid(r)local g,env=getGameGlobal();if type(g)=="table"then rawset(g,"did",r)end;if type(env)=="table"and env~=g and rawget(env,"_G")==nil then rawset(env,"did",r)end end
local function getGeneratedRemote(id)refreshRefs();local r=GenRemotes and GenRemotes:FindFirstChild("RE_"..tostring(id));return validRemote(r)and r or nil end

local function cacheParryRemote(r,mode)if not validRemote(r)then return nil end;parryRemote,parryMode=r,mode;if mode=="buffer"then setGameDid(r)end;return parryRemote,parryMode end

local function resolveParryRemote()
    refreshRefs()
    if validRemote(parryRemote)then return parryRemote,parryMode end
    local did=getGameDid()
    if validRemote(did)then return cacheParryRemote(did,"buffer")end
    if Remotes then local r=Remotes:FindFirstChild("pr_"..tostring(lp.UserId));if validRemote(r)then return cacheParryRemote(r,"buffer")end end
    return cacheParryRemote(getGeneratedRemote(1),"event")
end

local function makeDeflectBuffer(flag)
    if type(buffer)~="table"then return nil end
    if type(buffer.fromstring)=="function"then return buffer.fromstring(flag==2 and"\2"or"\1")end
    if type(buffer.create)=="function"and type(buffer.writeu8)=="function"then local b=buffer.create(1);buffer.writeu8(b,0,flag);return b end
end

local _spamBuf
do local ok,b=pcall(buffer.fromstring,"\1");if ok then _spamBuf=b end end
local TouchTapEvent=Replicated:FindFirstChild"TouchTap"

local function ensureParryInitialized()
    if parryInitDone then return true end
    local r,m=resolveParryRemote()
    if not r then return false end
    if m=="event"then parryInitDone=true;return true end
    local p=makeDeflectBuffer(2)
    if not p then return false end
    local ok=pcall(r.FireServer,r,p);parryInitDone=ok;return ok
end

local function fireParry(r,mode,flag)
    if not validRemote(r)then return false end
    if mode=="event"then return pcall(r.FireServer,r)end
    local p=makeDeflectBuffer(flag or 1)
    if not p then return false end
    ensureParryInitialized()
    return pcall(r.FireServer,r,p)
end

local function onParryFired()local n=now();S.lastFireAt=n;S.clickCount=(S.clickCount or 0)+1;_G.__lt_lastFire=n end

local function sendParry()local r,m=resolveParryRemote();if r and fireParry(r,m,1)then onParryFired();return true end;return false end

-- §v8.5 spam: acumulador de dívida + sleep calculado.
-- Dois objetivos:
--  1. fps baixo: absorve a variação do scheduler no `debt` e dispara catch-up.
--  2. timing regular: em fps alto, dorme o que falta pro próximo gap, evitando
--     o jitter de task.wait(0) que faz o server rate-limitar de forma irregular.
-- Cap MAX_PER_ITER evita explosão se o jogo travar por segundos.
local function getSpamGap()
    local cps=tonumber(Config.CPS)or DEFAULT_CPS
    if cps<1 then cps=1 end
    return 1/cps
end

local function fireOneClick()
    local r=resolveParryRemote()
    if not(r and r.Parent and _spamBuf)then return end
    pcall(r.FireServer,r,_spamBuf)
    S.clickCount=S.clickCount+1
    _G.__lt_lastFire=now()
end

local function maybeFireTouchTap()if not TouchTapEvent then return end;if not State.scriptActive then return end;pcall(TouchTapEvent.Fire,TouchTapEvent)end

local SPAM_MAX_PER_ITER=8  -- cap: cliques por iteração (anti-explosão se travar)
local SPAM_MIN_SLEEP=0.001 -- piso do sleep (1ms) — roda no próximo frame, não queima CPU

task.spawn(function()
    local debt,lastTick=0,now()
    while State.scriptActive do
        local sleepTime=0.005
        local ok,err=pcall(function()
            local spamOn=S.clashActive or _G.PhantomManual==true
            if not spamOn then
                S.spamWasActive=false
                debt,lastTick=0,now()
                return
            end
            S.spamWasActive=true
            local gap=getSpamGap()
            local t=now()
            local dt=t-lastTick
            lastTick=t
            if dt>1 then dt=1 end  -- se ficou travado >1s, ignora (evita explosão)
            debt=debt+dt
            local n=0
            while debt>=gap and n<SPAM_MAX_PER_ITER do
                fireOneClick()
                maybeFireTouchTap()
                debt=debt-gap
                n=n+1
            end
            -- dorme até o próximo gap, com piso de 1ms pra não busy-loop
            sleepTime=gap-debt
            if sleepTime<SPAM_MIN_SLEEP then sleepTime=SPAM_MIN_SLEEP end
        end)
        if not ok then warn("[PHANTOM] spam loop error: "..tostring(err));S.spamWasActive=false end
        if S.spamWasActive then task.wait(sleepTime)
        else task.wait(0.005)end
    end
end)

-- §v8.6 decide ligar/desligar clash por cps de mudanças de target.
-- cps = quantas vezes o TargetPlayerID mudou no último 1s.
-- se cps >= 1.8 → ativa (bola ricocheteando rápido = clash real)
-- se cps <  1.8 → desativa (auto parry dá conta)
-- exceção: bola é minha + player colado (<=6 studs) + bola perto (<=15) = PANIC, ativa sempre.

-- resolve a bola do jogo: usa BallReplicator (variável br) ou cache/fallback no workspace.
-- retorna o BasePart da bola ou nil se não achar.
local function getBall()
    -- 1) cache _G já setado em outro lugar do script
    local cached = _G.__phantomBall
    if cached and cached.Parent then return cached end
    -- 2) BallReplicator module (gi/br já carregados no topo)
    if br and type(br.GetBall) == "function" then
        local ok, b = pcall(function() return br.GetBall() end)
        if ok and b and b.Parent then
            _G.__phantomBall = b
            return b
        end
    end
    -- 3) fallback: procura por nome comum no workspace
    if ws then
        local b = ws:FindFirstChild("Ball") or ws:FindFirstChild("Football")
        if b and b.Parent then
            _G.__phantomBall = b
            return b
        end
    end
    return nil
end

local function evaluateClashByCps()
    if _G.PhantomAutoClash==false or Config.AutoClash==false then return end
    if _G.PhantomManual==true then return end
    local hr=lp.Character and lp.Character:FindFirstChild"HumanoidRootPart"
    if not(hr and hr.Parent)then return end

    -- conta mudanças na janela
    local t=now()
    local windowStart=t-CLASH_CPS_WINDOW
    local count=0
    for i=1,8 do
        local ts=S.targetChangeT[i]
        if ts and ts>=windowStart then count=count+1 end
    end
    S.targetCps=count/CLASH_CPS_WINDOW

    local ball=getBall()
    if not(ball and ball.Parent)then return end

    -- PANIC: bola é minha + player colado + bola perto =救命
    local nearest=math.huge
    for _,p in Players:GetPlayers()do
        if p~=lp and p.Character then
            local php=p.Character:FindFirstChild"HumanoidRootPart"
            if php and php.Parent then
                local d=(hr.Position-php.Position).Magnitude
                if d<nearest then nearest=d end
            end
        end
    end
    local ballDist=(hr.Position-ball.Position).Magnitude
    -- PANIC relaxado: player colado (≤6) + bola perto (≤15). Não exige target=meu,
    -- porque no frame exato o Sync.TargetPlayerID pode estar com 1-2 frames de delay.
    -- Confiamos no player-colado + bola-perto como sinal suficiente.
    local panic=(nearest<=CLASH_PANIC_DIST and ballDist<=CLASH_PANIC_BALL_DIST)

    -- Gating de cold start: se clash ainda não tá ativo, só permite ligar se:
    --  * PANIC (player colado + bola perto), OU
    --  * Target é meu E a bola tá perto (≤ CLASH_BALL_RANGE studs, configurado em 38).
    -- Quando clashActive=true, comportamento normal (mantém até cps cair).
    local targetIsMe = (Sync.TargetPlayerID == lp.UserId)
    local ballInRange = ballDist <= CLASH_BALL_RANGE
    local coldStartGate = panic or (targetIsMe and ballInRange)

    if (S.targetCps>=CLASH_CPS_THRESHOLD or panic) and (S.clashActive or coldStartGate) then
        if not S.clashActive then
            S.clashActive=true
            S.clashActivatedAt=t
            S.clashHoldUntil=t+CLASH_HOLD
            _G.__lt_clashActive=true
            print(("[PHANTOM] AutoClash ON (cps=%.2f, panic=%s, targetIsMe=%s, ballDist=%.1f, nearest=%.1f)"):format(S.targetCps,tostring(panic),tostring(targetIsMe),ballDist,nearest))
        end
    else
        if S.clashActive then
            S.clashActive=false
            _G.__lt_clashActive=false
            S.clashHoldUntil=0
            print(("[PHANTOM] AutoClash OFF (cps=%.2f)"):format(S.targetCps))
        end
    end
end

local function nearestOtherPlayerDist(hrp)
    local best=math.huge
    for _,p in Players:GetPlayers()do
        if p~=lp and p.Character then
            local php=p.Character:FindFirstChild"HumanoidRootPart"
            if php and php.Parent then
                local d=(hrp.Position-php.Position).Magnitude
                if d<best then best=d end
            end
        end
    end
    return best
end

local function clearClash()S.clashActive,_G.__lt_clashActive=false,false;S.clashHoldUntil,S.spamDrainUntil,S.spamStartedAt=0,0,0;S.spamWasActive=false end

local function decayClash()
    if not S.clashActive then return end
    if Config.AutoClash==false or _G.PhantomAutoClash==false then clearClash();return end
    local t=now()
    if(t-S.clashActivatedAt)>CLASH_DECAY and t>=S.clashHoldUntil then clearClash();return end
    local hr=lp.Character and lp.Character:FindFirstChild"HumanoidRootPart"
    if not hr or not hr.Parent then return end
    local nearestPlayer=math.huge
    for _,p in Players:GetPlayers()do
        if p~=lp and p.Character then
            local php=p.Character:FindFirstChild"HumanoidRootPart"
            if php and php.Parent then
                local pd=(hr.Position-php.Position).Magnitude
                if pd<nearestPlayer then nearestPlayer=pd end
            end
        end
    end
    if nearestPlayer>CLASH_PLAYER_DIST_AP and t>=S.clashHoldUntil then clearClash()end
end

task.spawn(function()while State.scriptActive do pcall(decayClash);task.wait(0.05)end end)

local function getBall()local bm=gi and gi.BallModel;if bm and bm.Parent then return bm end;return S.ball or ws:FindFirstChild("GameBall",true)or ws:FindFirstChild"GameBall"end

local function isTargeted(ch)
    if Sync.TargetPlayerID==lp.UserId then return true end
    if S.lastTarget==lp.UserId then return true end
    if ch and ch:FindFirstChild"Highlight"then return true end
    if ws:GetAttribute"GameBallTarget"==lp.UserId then return true end
    local sd=br and br.syncData
    return sd and sd.HighlightTargetPlayerID==lp.UserId or false
end

local function bindParry(ch)
    apClearBind()
    if apDead or not(ch and ch.Parent)then return end
    local myId=apBindId
    local hrp=ch:FindFirstChild"HumanoidRootPart"
    if not hrp then hrp=ch:WaitForChild("HumanoidRootPart",1)end
    if myId~=apBindId or not(hrp and hrp.Parent)then return end

    apLocal.ballProcessed=false
    apLocal.forceRelease=nil

    local PREFIRE_S=0.23
    local PARRY_DEFLECT_R=8
    local PARRY_MIN_SPEED=5

    apSimConn=RunService.Heartbeat:Connect(function(dt)
        if apDead or myId~=apBindId then return end
        if not(ch.Parent and hrp.Parent)then apClearBind();return end
        if Config.AutoParry~=true then return end

        local t=now()

        if t<S.teleportLockUntil or Sync.Grace then return end
        if S.clashActive or _G.PhantomManual==true then return end

        local ball=getBall()
        if not(ball and ball.Parent)then return end

        if Sync.TargetPlayerID~=lp.UserId then apLocal.armed=false;return end
        if not apLocal.armed then apLocal.armed=true end

        local syncFresh=(t-Sync.lastSyncAt)<0.3
        local bp=(syncFresh and Sync.RealPosition~=Vector3.zero)and Sync.RealPosition or ball.Position

        local spd
        if syncFresh and Sync.Speed>0 then spd=Sync.Speed
        else
            local ok,av=pcall(function()return ball.AssemblyLinearVelocity end)
            spd=(ok and typeof(av)=="Vector3")and av.Magnitude or 0
        end
        if spd<PARRY_MIN_SPEED then return end

        local parryRad=PARRY_DEFLECT_R+spd*PREFIRE_S
        local dist=(hrp.Position-bp).Magnitude
        if dist>parryRad then return end

        if apLocal.fired then return end

        S.pingTimer=S.pingTimer+dt
        if S.pingTimer>=1 then S.pingTimer=0;apSamplePing()end

        apLocal.fired=true
        S.lastFireAt=t
        task.defer(sendParry)
    end)
    trackConn(apSimConn)

    trackConn(ch.AncestryChanged:Connect(function(_,p)
        if not p then apLocal.ballProcessed=false;apClearBind()end
    end))
end

local keyConn
local function installKeybinds()
    if keyConn then pcall(keyConn.Disconnect,keyConn);keyConn=nil end
    local panic,spam,mode=Config.Keybind,Config.SpamKeybind,Config.SpamMode or"Toggle"
    keyConn=UIS.InputBegan:Connect(function(inp,gpe)
        if gpe then return end
        if inp.KeyCode==panic then
            S.clashActive=false
            S.clashActivatedAt,S.spamWasActive,S.spamLastFire,S.spamStartedAt=0,false,0,0
            apLocal.ballProcessed=false
            _G.PhantomManual,_G.__lt_clashActive=false,false
            clearClash()
            print"[PHANTOM] panic reset (keybind)"
        elseif inp.KeyCode==spam then
            if mode=="Hold"then _G.PhantomManual=true
            else
                _G.PhantomManual=not _G.PhantomManual
                S.spamWasActive,S.spamLastFire,S.spamStartedAt=false,0,0
                print(("[PHANTOM] Manual Spam %s"):format(_G.PhantomManual and"ON"or"OFF"))
            end
        end
    end)
    trackConn(keyConn)
    if mode=="Hold"then trackConn(UIS.InputEnded:Connect(function(i)if i.KeyCode==spam then _G.PhantomManual=false end end))end
end

local CONFIG_KEYS={"AutoParry","AutoClash","CPS","CustomCPS","Keybind","SpamKeybind","SpamMode"}
local function applyConfigFromGUI()
    local c=_G.PhantomConfig
    if type(c)~="table"then return false end
    for _,k in ipairs(CONFIG_KEYS)do if c[k]~=nil then Config[k]=c[k]end end
    _G.PhantomConfig=Config
    return true
end
local function pollGUI(dt)
    if S.guiReady then return end
    S.guiPollAcc=S.guiPollAcc+dt
    if S.guiPollAcc<0.25 then return end
    S.guiPollAcc=0
    if applyConfigFromGUI()then S.guiReady=true;refreshCPS();installKeybinds();print"[PHANTOM] GUI detectada, sincronizado"end
end

local function bindCharacter(ch)
    if not(ch and ch.Parent)then return end
    local hrp=ch:FindFirstChild"HumanoidRootPart"or ch:WaitForChild("HumanoidRootPart",9e9)
    if not(hrp and hrp.Parent)then return end
    local conn,dead=nil,false
    local function clear()dead=true;if conn then pcall(conn.Disconnect,conn);conn=nil end end
    trackConn(ch.AncestryChanged:Connect(function(_,p)if not p then clear();apClearBind()end end))
    conn=RunService.Heartbeat:Connect(function(dt)
        if dead or not State.scriptActive then clear();return end
        if not(ch.Parent and hrp.Parent)then clear();return end
        pollGUI(dt)
        decayClash()
        evaluateClashByCps()
        local t=now()
        if dt>0.05 then
            S.slowFrames=S.slowFrames+1
            if(t-S.lastSlowFrameLog)>30 then
                S.lastSlowFrameLog=t
                warn(("[PHANTOM] slow frame: dt=%.3f, total slow=%d"):format(dt,S.slowFrames))
            end
        end
    end)
    trackConn(conn)
end

task.spawn(function()
    local tries=0
    while State.scriptActive do
        tries=tries+1
        local ok,err=pcall(function()refreshRefs();if resolveParryRemote()then ensureParryInitialized()end end)
        if not ok then warn("[PHANTOM] boot try "..tries.." falhou: "..tostring(err))end
        if tries>=3 and tries%5==0 then warn("[PHANTOM] ainda sem remote após "..tries.." tentativas")end
        task.wait(1)
        if tries>=BOOT_MAX_TRIES then break end
    end
end)

local function onChar(ch)
    S.lastTarget=-999
    _G.__lt_lastTarget=-999
    S.clashActive,S.clashActivatedAt,_G.__lt_clashActive=false,0,false
    apLocal.ballProcessed=false
    apLocal.forceRelease=nil
    task.defer(function()
        local ok=pcall(bindParry,ch)
        if not ok then task.delay(0.2,function()pcall(bindParry,ch)end)end
    end)
    task.defer(function()pcall(bindCharacter,ch)end)
end
trackConn(lp.CharacterAdded:Connect(onChar))
if lp.Character then task.defer(function()pcall(onChar,lp.Character)end)end

local function bindBall(b)if not b or S.ball==b then return end;S.ball,_G.__phantomBall=b,b end

local existing=ws:FindFirstChild"GameBall"
if existing then bindBall(existing)end
trackConn(ws.ChildAdded:Connect(function(c)if c.Name=="GameBall"then bindBall(c)end end))
trackConn(ws.ChildRemoved:Connect(function(c)if c.Name=="GameBall"then S.ball,_G.__phantomBall=nil,nil end end))

local ballSyncRemote=Remotes and Remotes:FindFirstChild"BallSyncData"
if ballSyncRemote and ballSyncRemote:IsA"RemoteEvent"then
    trackConn(ballSyncRemote.OnClientEvent:Connect(function(data)
        if typeof(data)~="table"then return end
        local t=now()

        if type(data.Speed)=="number"then Sync.Speed=data.Speed end
        if typeof(data.RealPosition)=="Vector3"then Sync.RealPosition=data.RealPosition end
        if typeof(data.DeflectDirection)=="Vector3"then Sync.DeflectDirection=data.DeflectDirection end
        if type(data.DirectionInterp)=="number"then Sync.DirectionInterp=data.DirectionInterp end
        if type(data.Grace)=="boolean"then Sync.Grace=data.Grace end

        if type(data.ForceDirection)=="boolean"then
            if data.ForceDirection and not Sync.ForceDirection then Sync.forcedAt=t end
            Sync.ForceDirection=data.ForceDirection
        end
        if typeof(data.ForcedDirection)=="Vector3"then Sync.ForcedDirection=data.ForcedDirection end
        Sync.lastSyncAt=t

        if data.Teleported==true then
            S.teleportLockUntil=t+TELEPORT_LOCKOUT
            apLocal.ballProcessed=false
            apLocal.forceRelease=nil
            S.clashActive,S.clashActivatedAt=false,0
            S.spamWasActive,S.spamLastFire,S.spamStartedAt=false,0,0
            if typeof(data.TeleportPosition)=="Vector3"then Sync.TeleportPosition=data.TeleportPosition end
            Sync.Teleported=true
            return
        end
        Sync.Teleported=false

        Sync.TargetPlayerID=data.TargetPlayerID
        if data.TargetPlayerID and data.TargetPlayerID~=S.lastTarget then
            -- §v8.6 push timestamp de mudança de target (ring buffer circular, 8 slots)
            S.targetChangeIdx=(S.targetChangeIdx%8)+1
            S.targetChangeT[S.targetChangeIdx]=t
            local prev,targeted=S.lastTarget,data.TargetPlayerID==lp.UserId
            S.lastTarget,_G.__lt_lastTarget=data.TargetPlayerID,data.TargetPlayerID
            if targeted then
                local hr=lp.Character and lp.Character:FindFirstChild"HumanoidRootPart"
                local tImp=math.huge
                if hr and hr.Parent then
                    local b=getBall()
                    if b and b.Parent then
                        local ballDist=(hr.Position-b.Position).Magnitude
                        local curSpd
                        if(t-Sync.lastSyncAt)<0.3 and Sync.Speed and Sync.Speed>0 then curSpd=Sync.Speed
                        else
                            local ok2,av=pcall(function()return b.AssemblyLinearVelocity end)
                            curSpd=(ok2 and typeof(av)=="Vector3")and av.Magnitude or 0
                        end
                        if curSpd>1 then tImp=ballDist/curSpd end
                    end
                end
                apLocal.ballProcessed=(tImp<=0.25)
                apLocal.forceRelease=true
                apLocal.fired=false
                apLocal.armed=true
            else
                apLocal.ballProcessed=false
                apLocal.forceRelease=nil
                apLocal.armed=false
                apLocal.fired=false
            end

            if(_G.PhantomAutoClash~=false)and(Config.AutoClash~=false)and not _G.PhantomManual and targeted and prev~=lp.UserId and prev~=-999 then
                local hr=lp.Character and lp.Character:FindFirstChild"HumanoidRootPart"
                if hr and hr.Parent then
                    local nearestPlayer=math.huge
                    for _,p in Players:GetPlayers()do
                        if p~=lp and p.Character then
                            local php=p.Character:FindFirstChild"HumanoidRootPart"
                            if php and php.Parent then
                                local pd=(hr.Position-php.Position).Magnitude
                                if pd<nearestPlayer then nearestPlayer=pd end
                            end
                        end
                    end
                    local okB,b=pcall(getBall)
                    local ballInRange=false
                    if okB and b and b.Parent then
                        local ballDist=(hr.Position-b.Position).Magnitude
                        if ballDist<=(PARRY_MIN_RAD+PARRY_RAD_BASE+PARRY_RAD_RADIAL)then ballInRange=true end
                    end
                    if nearestPlayer<CLASH_PLAYER_DIST_AP and ballInRange then
                        local tt=now()
                        S.clashActive=true
                        S.clashActivatedAt=tt
                        S.clashHoldUntil=tt+CLASH_HOLD
                        S.spamDrainUntil=0
                        S.spamWasActive,S.spamLastFire,S.spamStartedAt=false,0,0
                        _G.__lt_clashActive=true
                        print(("[PHANTOM] AutoClash ON (player=%.1f, bola no raio)"):format(nearestPlayer))
                    end
                end
            end
        end
    end))
end

task.spawn(function()while State.scriptActive do if S.guiReady then applyConfigFromGUI()end;task.wait(0.5)end end)

local PHANTOM_GUI_URL="https://raw.githubusercontent.com/Repp35/Roblox/refs/heads/main/phantom_gui.lua"
local HTTP_ATTEMPTS={
    {name="game.HttpGet",ok=type(game)=="table"and type(game.HttpGet)=="function"and type(syn)~="table"and type(request)~="function"and type(http_request)~="function",call=function()return game:HttpGet(PHANTOM_GUI_URL)end,wrap=false},
    {name="request",ok=type(request)=="function",call=function()return request({Url=PHANTOM_GUI_URL,Method="GET"})end,wrap=true},
    {name="http_request",ok=type(http_request)=="function",call=function()return http_request({Url=PHANTOM_GUI_URL,Method="GET"})end,wrap=true},
    {name="syn.request",ok=type(syn)=="table"and type(syn.request)=="function",call=function()return syn.request({Url=PHANTOM_GUI_URL,Method="GET"})end,wrap=true},
}

task.defer(function()
    if _G.__phantomGUI_loaded then print"[PHANTOM] GUI já carregada externamente, pulando";return end
    local guiSrc=rawget(_G,"__phantomGUI_src")
    if type(guiSrc)~="string"or #guiSrc==0 then
        for _,a in ipairs(HTTP_ATTEMPTS)do
            if a.ok then
                local ok2,res=pcall(a.call)
                local body=a.wrap and(ok2 and res and res.Body)or(ok2 and res)
                if type(body)=="string"and #body>0 then guiSrc=body;break
                else warn("[PHANTOM] "..a.name.." falhou")end
            end
        end
        if not guiSrc then warn"[PHANTOM] Nenhum método HTTP disponível. Backend rodando standalone."end
    end
    if type(guiSrc)~="string"or #guiSrc==0 then warn"[PHANTOM] Source da GUI vazio. Backend rodando standalone.";return end
    if type(loadstring)~="function"then warn"[PHANTOM] loadstring indisponível. GUI não carregada.";return end
    local fn,err=loadstring(guiSrc)
    if not fn then warn("[PHANTOM] Falha ao compilar GUI: "..tostring(err));return end
    _G.__phantomGUI_src=guiSrc
    local ok,runErr=pcall(fn)
    if ok then _G.__phantomGUI_loaded=true;print"[PHANTOM] GUI carregada"
    else warn("[PHANTOM] GUI crashou: "..tostring(runErr))end
end)

task.defer(function()task.wait(0.1);pcall(refreshRefs);print(("[PHANTOM] Manual Spam + Auto Clash + Auto Parry v8.4 carregado. GameId=%s, TS=%s, Remotes=%s"):format(tostring(game.GameId),TSFolder and"ok"or"nil",Remotes and"ok"or"nil"))end)