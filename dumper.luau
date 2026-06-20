----------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------
local SETTINGS = {
    threads              = 12,   -- PC aguenta mais
    timeout              = 8,    -- segundos por decompile
    disable_render       = true,
    ignore_empty         = true,
    include_nil          = true,
    replace_username     = true,
    min_size             = 200,

    -- Dumps principais
    dump_constants       = true,
    dump_protos          = true,
    dump_upvalues        = true,
    dump_debug_info      = true,
    dump_attributes      = true,
    dump_tags            = true,
    dump_bindables       = true,
    dump_unreliable      = true,
    dump_getgc           = true,
    dump_loadedscripts   = true,
    dump_gethui          = true,
    dump_getreg          = true,
    dump_replicationfocus= true,
    dump_actor           = true,

    -- Extras PC
    dump_bytecode        = true,  -- bytecode raw quando decompile falha
    dump_disassemble     = true,  -- disassembly como fallback
    dump_connections     = true,  -- quem ta conectado a cada remote
    dump_hidden_props    = true,  -- gethiddenproperty
    dump_hooks           = true,  -- hookfunction/hooksignal
    dump_obfuscation     = true,  -- relatorio de obfuscacao
    dump_marketplace     = true,  -- info do jogo + creator

    max_gc_dump          = 8000,  -- PC aguenta mais
    max_reg_keys         = 20000,
}

----------------------------------------------------------------
-- Feature detection
----------------------------------------------------------------
local function has(fn) return type(fn) == "function" end
local function hasglobal(name)
    local ok, v = pcall(function() return _G[name] end)
    return ok and v ~= nil
end

local API = {}
API.decompile         = has(decompile) and decompile
                    or (has(disassemble) and disassemble)
                    or function() return "-- no decompile api" end

API.getnilinstances   = (has(getnilinstances) and getnilinstances)
                    or (has(get_nil_instances) and get_nil_instances)
                    or nil

API.getscripthash     = (has(getscripthash) and getscripthash)
                    or (has(get_script_hash) and get_script_hash)
                    or function() return nil end

API.getscriptclosure  = (has(getscriptclosure) and getscriptclosure)
                    or (has(get_script_closure) and get_script_closure)
                    or nil

API.getscriptbytecode = (has(getscriptbytecode) and getscriptbytecode)
                    or (has(get_script_bytecode) and get_script_bytecode)
                    or nil

API.getconstants      = (has(getconstants) and getconstants)
                    or (has(debug.getconstants) and debug.getconstants)
                    or nil

API.getprotos         = (has(getprotos) and getprotos)
                    or (has(debug.getprotos) and debug.getprotos)
                    or nil

API.getupvalues       = (has(getupvalues) and getupvalues)
                    or (has(debug.getupvalues) and debug.getupvalues)
                    or (has(get_upvalues) and get_upvalues)
                    or nil

API.getinfo           = (has(getinfo) and getinfo) or debug.info

API.getgc             = (has(getgc) and getgc)
                    or (has(getgcinfo) and function() return getgcinfo() end)
                    or nil

API.getreg            = (has(getreg) and getreg)
                    or (has(get_registry) and get_registry)
                    or nil

API.gethui            = nil
do
    if has(gethui) then API.gethui = gethui
    elseif has(get_hidden_gui) then API.gethui = get_hidden_gui
    elseif has(gethiddenproperty) then API.gethui = function() return gethiddenproperty() end
    end
end

API.loadedscripts     = (has(loadedscripts) and loadedscripts) or nil
API.getactors         = (has(getactors) and getactors) or nil
API.replicationfocus  = hasglobal("replicationfocus") and replicationfocus or nil

-- PC-specific
API.getconnections    = (has(getconnections) and getconnections)
                    or (has(get_signal_connections) and get_signal_connections)
                    or (has(getsignals) and getsignals)
                    or nil

API.gethiddenproperty  = (has(gethiddenproperty) and gethiddenproperty)
                    or (has(get_hidden_property) and get_hidden_property)
                    or nil

API.gethiddenproperties = (has(gethiddenproperties) and gethiddenproperties)
                    or (has(get_hidden_properties) and get_hidden_properties)
                    or nil

API.hookfunction      = (has(hookfunction) and hookfunction) or nil
API.hooksignal        = (has(hooksignal) and hooksignal) or nil
API.isrbxactive       = (has(isrbxactive) and isrbxactive) or nil
API.cloneref          = (has(cloneref) and cloneref) or nil
API.listfiles_raw     = (has(listfiles) and listfiles) or nil
API.request           = (has(request) and request)
                    or (has(http and http.request) and http.request)
                    or (has(http_request) and http_request)
                    or nil

-- Executor info
local identify = (has(identifyexecutor) and identifyexecutor())
              or (has(identify_executor) and identify_executor())
              or (has(getexecutorname) and getexecutorname())
              or "Unknown Executor"
local exec_version = (has(getexecutormetatable) and "via metatable")
                  or (has(identifyexecutor) and "v?")
                  or "Unknown"

local task_wait  = (has(task) and has(task.wait)) and task.wait or function(s) wait(s) end
local task_spawn = (has(task) and has(task.spawn)) and task.spawn or function(f) f() end
local task_defer = (has(task) and has(task.defer)) and task.defer or function(f) task_spawn(f) end

----------------------------------------------------------------
-- Filesystem helpers
----------------------------------------------------------------
local function has_fs()
    if API.fs_checked then return API.fs_ok end
    API.fs_checked = true
    local ok = has(writefile) and has(makefolder) and has(isfolder) and has(readfile) and has(listfiles)
    API.fs_ok = ok
    return ok
end

local invalid_chars = {"/", "\\", ":", "*", "?", '"', "<", ">", "|", "\n", "\r", "\t"}
for i = 0, 31 do table.insert(invalid_chars, string.char(i)) end
table.insert(invalid_chars, string.char(127))

local function sanitize(str)
    if type(str) ~= "string" then str = tostring(str) end
    for _, c in next, invalid_chars do
        str = str:gsub(c, "")
    end
    if #str == 0 then str = "_" end
    return str
end

local function safe_folder(path)
    if not has_fs() then return false end
    local ok_isfolder, exists = pcall(isfolder, path)
    if ok_isfolder and exists then return true end
    local ok, _ = pcall(makefolder, path)
    return ok
end

local function safe_writefile(path, content)
    if not has_fs() then return false end
    local ok, _ = pcall(writefile, path, content)
    return ok
end

local function safe_readfile(path)
    if not has_fs() then return nil end
    local ok, c = pcall(readfile, path)
    return ok and c or nil
end

----------------------------------------------------------------
-- Paths
----------------------------------------------------------------
local placeid, universeid, gameid, jobid = 0, 0, 0, "?"
pcall(function() placeid = game.PlaceId end)
pcall(function() gameid  = game.GameId end)
pcall(function() jobid   = game.JobId end)
pcall(function()
    if game and game.GetService then
        local gs = game:GetService("GameService")
        if gs and gs.GameId then
            pcall(function() universeid = gs.GameId end)
        end
    end
end)

local placename = "Place"
local creator_name, creator_id = "?", 0
pcall(function()
    if game and game.GetService then
        local ms = game:GetService("MarketplaceService")
        if ms and ms.GetProductInfo then
            local info = ms:GetProductInfo(placeid)
            if info and info.Name then placename = info.Name end
            if info and info.Creator then
                creator_name = info.Creator.Name or "?"
                creator_id   = info.Creator.CreatorId or info.Creator.Id or 0
            end
        end
    end
end)
placename = placename:gsub("[\\/:%*%?\"<>|]", " ")

local ROOT       = "Ultimate Dumper"
local PLACE_DIR  = ROOT .. "/[" .. tostring(placeid) .. "] " .. placename
local DIRS = {
    scripts   = PLACE_DIR .. "/scripts",
    nil_      = PLACE_DIR .. "/nil",
    remotes   = PLACE_DIR .. "/remotes",
    constants = PLACE_DIR .. "/constants",
    protos    = PLACE_DIR .. "/protos",
    upvalues  = PLACE_DIR .. "/upvalues",
    decompile = PLACE_DIR .. "/raw_decompile",
    bytecode  = PLACE_DIR .. "/bytecode",
    disasm    = PLACE_DIR .. "/disasm",
    debug     = PLACE_DIR .. "/debug_info",
    getgc     = PLACE_DIR .. "/getgc",
    registry  = PLACE_DIR .. "/registry",
    gethui    = PLACE_DIR .. "/gethui",
    loaded    = PLACE_DIR .. "/loadedscripts",
    hidden    = PLACE_DIR .. "/hidden_props",
    hooks     = PLACE_DIR .. "/hooks",
    analysis  = PLACE_DIR .. "/analysis",
}
local META_FILE   = PLACE_DIR .. "/! metadata.txt"
local TIMEOUTS    = PLACE_DIR .. "/! timed out.txt"
local SUMMARY     = PLACE_DIR .. "/! summary.txt"

if has_fs() then
    safe_folder(ROOT)
    safe_folder(PLACE_DIR)
    for _, p in next, DIRS do safe_folder(p) end
end

----------------------------------------------------------------
-- User info
----------------------------------------------------------------
local username, userid, displayname = "?", 0, "?"
local plr = nil
pcall(function()
    plr = game:GetService("Players").LocalPlayer
    if plr and plr.Name then username = plr.Name end
    if plr and plr.UserId then userid = plr.UserId end
    if plr and plr.DisplayName then displayname = plr.DisplayName end
end)
local safe_username = username:gsub("[%%%.%[%]%(%)%*%+%-%?]", "%%%0")

local function replace_user(str)
    if type(str) ~= "string" then return str end
    if SETTINGS.replace_username and safe_username ~= "" and username ~= "?" then
        str = str:gsub(safe_username, "LocalPlayer")
    end
    return str
end

----------------------------------------------------------------
-- Naming helpers
----------------------------------------------------------------
local function short_path(inst, isnil)
    local ok, name = pcall(function() return inst:GetFullName() end)
    if not ok or not name then name = "?" end
    name = replace_user(name)
    if isnil then name = "[nil] " .. name end
    return sanitize(name)
end

local function dump_path(inst, isnil)
    local sub = isnil and "nil" or "scripts"
    return sub .. "/" .. short_path(inst, isnil) .. ".lua"
end

local function build_dirs(rel)
    if not has_fs() then return PLACE_DIR .. "/" .. rel end
    local parts = {}
    for p in rel:gmatch("[^/]+") do table.insert(parts, p) end
    local cur = PLACE_DIR
    for i = 1, #parts - 1 do
        cur = cur .. "/" .. parts[i]
        safe_folder(cur)
    end
    return PLACE_DIR .. "/" .. rel
end

local function getfullname(inst)
    local ok, name = pcall(function() return inst:GetFullName() end)
    if not ok or not name then return "<unknown>" end
    name = replace_user(name)
    local first, rest = name:match("^([^.]+)%.(.*)$")
    if first and rest then
        return ('game:GetService("%s").%s'):format(first, rest:gsub("%.%[", "["))
    end
    return name
end

----------------------------------------------------------------
-- Header
----------------------------------------------------------------
local function header(inst, extra)
    local lines = {
        "-- ===================== Ultimate Dumper PRO (PC) =====================",
        "-- Executor:    " .. tostring(identify) .. " " .. tostring(exec_version),
        "-- Place:       " .. tostring(placeid) .. " - " .. placename,
        "-- GameId:      " .. tostring(gameid),
        "-- Universe:    " .. tostring(universeid),
        "-- Creator:     " .. tostring(creator_name) .. " (" .. tostring(creator_id) .. ")",
        "-- JobId:       " .. tostring(jobid),
        "-- User:        " .. tostring(username) .. " (" .. tostring(userid) .. ") " .. tostring(displayname),
        "-- Timestamp:   " .. tostring(os.time and os.time() or "?"),
    }
    if inst then
        local nm, cls, path = "?", "?", "?"
        pcall(function() nm = inst.Name end)
        pcall(function() cls = inst.ClassName end)
        pcall(function() path = getfullname(inst) end)
        table.insert(lines, "-- -----------------------------------------------------------------")
        table.insert(lines, "-- Name:     " .. nm)
        table.insert(lines, "-- Class:    " .. cls)
        table.insert(lines, "-- FullName: " .. path)

        if SETTINGS.dump_attributes then
            pcall(function()
                if inst.GetAttribute then
                    local attrs = inst:GetAttributes()
                    if next(attrs) then
                        table.insert(lines, "-- --- Attributes:")
                        for k, v in next, attrs do
                            table.insert(lines, "--    " .. tostring(k) .. " = " .. tostring(v))
                        end
                    end
                end
            end)
        end

        if SETTINGS.dump_tags then
            pcall(function()
                if inst.GetTags then
                    local tags = inst:GetTags()
                    if tags and #tags > 0 then
                        table.insert(lines, "-- --- Tags:")
                        for _, t in next, tags do
                            table.insert(lines, "--    " .. tostring(t))
                        end
                    end
                end
            end)
        end

        if SETTINGS.dump_hidden_props and API.gethiddenproperty then
            pcall(function()
                local hidden_list = {
                    "Source", "LinkedSource", "Require", "ModuleScript",
                    "RunContext", "Disabled", "CoreScript",
                }
                local found = false
                for _, k in next, hidden_list do
                    pcall(function()
                        local v = API.gethiddenproperty(inst, k)
                        if v ~= nil then
                            if not found then
                                table.insert(lines, "-- --- Hidden properties:")
                                found = true
                            end
                            table.insert(lines, ("--    %s = %s"):format(k, tostring(v)))
                        end
                    end)
                end
            end)
        end
    end

    if extra then
        for _, l in next, extra do table.insert(lines, l) end
    end
    table.insert(lines, "-- ===================================================================")
    table.insert(lines, "")
    return table.concat(lines, "\n")
end

----------------------------------------------------------------
-- Collection
----------------------------------------------------------------
local ignored_ancestors = { CoreGui = true, CorePackages = true, Chat = true }
local ignored_names     = {
    PlayerModule = true, RbxCharacterSounds = true,
    PlayerScriptsLoader = true, ChatScript = true, BubbleChat = true,
}

local function is_ignored(inst)
    if not inst then return true end
    if ignored_names[inst.Name] then return true end
    for anc, _ in ignored_ancestors do
        if inst:FindFirstAncestor(anc) then return true end
    end
    return false
end

local scripts, nil_scripts = {}, {}
local remote_events, remote_funcs, bindables, unrel = {}, {}, {}, {}

local function collect_inst(d)
    if not d then return end
    local cls = d.ClassName
    if cls == "LocalScript" or cls == "ModuleScript" then
        if not is_ignored(d) then table.insert(scripts, d) end
    elseif cls == "RemoteEvent" then
        table.insert(remote_events, d)
    elseif cls == "RemoteFunction" then
        table.insert(remote_funcs, d)
    elseif SETTINGS.dump_bindables and (cls == "BindableEvent" or cls == "BindableFunction") then
        table.insert(bindables, d)
    elseif SETTINGS.dump_unreliable and cls == "UnreliableRemoteEvent" then
        table.insert(unrel, d)
    end
end

pcall(function()
    for _, d in next, game:GetDescendants() do
        collect_inst(d)
    end
end)

if SETTINGS.dump_actor and API.getactors then
    pcall(function()
        for _, actor in next, API.getactors() do
            pcall(function()
                if actor and actor.GetDescendants then
                    for _, d in next, actor:GetDescendants() do
                        collect_inst(d)
                    end
                end
            end)
        end
    end)
end

if SETTINGS.include_nil and API.getnilinstances then
    pcall(function()
        for _, d in next, API.getnilinstances() do
            if d and (d.ClassName == "LocalScript" or d.ClassName == "ModuleScript") and not is_ignored(d) then
                table.insert(nil_scripts, d)
            end
        end
    end)
end

----------------------------------------------------------------
-- Decompile + cache
----------------------------------------------------------------
local decompile_cache = {}
local timed_out = {}
local dumped, failed, empty_skipped, no_source = 0, 0, 0, 0

local function try_decompile(inst)
    if decompile_cache[inst] then return decompile_cache[inst] end

    local hash_ok, hash = pcall(API.getscripthash, inst)
    if hash_ok and hash and decompile_cache[hash] then
        decompile_cache[inst] = decompile_cache[hash]
        return decompile_cache[hash]
    end

    local started = (os.clock and os.clock()) or tick()
    local output
    while true do
        local ok, src = pcall(API.decompile, inst)
        if ok and type(src) == "string" and #src > 1 and src ~= "-- Failed to decompile script" then
            output = src
            break
        end
        local now = (os.clock and os.clock()) or tick()
        if (now - started) > SETTINGS.timeout then
            output = nil
            break
        end
        task_wait(0.1)
    end

    if not output then
        if hash_ok and hash then
            decompile_cache[hash] = "-- Decompile timed out / unsupported"
        end
        return nil, true
    end

    if hash_ok and hash then decompile_cache[hash] = output end
    decompile_cache[inst] = output
    return output
end

local function is_empty(src)
    if #src >= SETTINGS.min_size then return false end
    for line in src:gmatch("[^\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        if trimmed ~= "" and trimmed:sub(1,2) ~= "--" then return false end
    end
    return true
end

----------------------------------------------------------------
-- Obfuscation analysis
----------------------------------------------------------------
local function analyze_obfuscation(src)
    if not SETTINGS.dump_obfuscation or not src then return end
    local stats = {
        total_len   = #src,
        lines       = 0,
        strings     = 0,
        long_strings= 0,
        numbers     = 0,
        identifiers = 0,
        suspicious  = {},
    }

    for line in src:gmatch("[^\n]+") do
        stats.lines += 1
    end

    for s in src:gmatch("[\"'`].-[\"'`]") do
        stats.strings += 1
        if #s > 50 then stats.long_strings += 1 end
    end

    for n in src:gmatch("%d+%.?%d*") do
        stats.numbers += 1
    end

    -- Heuristicas de obfuscacao
    local checks = {
        {pattern = "string%.char",       label = "string.char (string obfuscation)"},
        {pattern = "getfenv",            label = "getfenv usage"},
        {pattern = "setfenv",            label = "setfenv usage"},
        {pattern = "loadstring",         label = "loadstring usage"},
        {pattern = "bit32%.",            label = "bit32 operations"},
        {pattern = "\\%[%[",             label = "Lua long-bracket strings"},
        {pattern = "function%(%)",       label = "anonymous functions"},
        {pattern = "while%s+true%s+do",  label = "infinite while loop"},
        {pattern = "for%s+.-%-%-",       label = "obfuscated numeric loop"},
    }
    for _, c in next, checks do
        local count = 0
        for _ in src:gmatch(c.pattern) do count += 1 end
        if count > 0 then
            table.insert(stats.suspicious, ("%s: %d hits"):format(c.label, count))
        end
    end

    -- Ratio de comentarios
    local comment_chars = 0
    for c in src:gmatch("%-%-[^\n]*") do comment_chars += #c end
    stats.comment_ratio = stats.total_len > 0 and (comment_chars / stats.total_len) or 0

    return stats
end

----------------------------------------------------------------
-- Safe call
----------------------------------------------------------------
local function safe_call(fn, ...)
    if not fn then return nil end
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    return res
end

----------------------------------------------------------------
-- Dump: constants / protos / upvalues / debug
----------------------------------------------------------------
local function dump_constants(inst, isnil, target)
    if not SETTINGS.dump_constants or not API.getconstants then return end
    local list = safe_call(API.getconstants, inst)
    if type(list) ~= "table" then return end
    local rel = "constants/" .. short_path(inst, isnil) .. ".txt"
    local full = build_dirs(rel)
    local buf = {header(target or inst, {"-- Section: constants (" .. #list .. ")"})}
    for i, c in next, list do
        table.insert(buf, ("[%d] (%s) %s"):format(i, type(c), tostring(c)))
    end
    safe_writefile(full, table.concat(buf, "\n"))
end

local function dump_protos(inst, isnil)
    if not SETTINGS.dump_protos or not API.getprotos then return end
    local list = safe_call(API.getprotos, inst)
    if type(list) ~= "table" then return end
    for idx, p in next, list do
        local rel = ("protos/%s/proto[%d].txt"):format(short_path(inst, isnil), idx)
        local full = build_dirs(rel)
        local buf = {header(inst, {"-- Section: proto[" .. idx .. "]"})}
        if API.getinfo then
            local src = safe_call(API.getinfo, p, "s")
            local lnd = safe_call(API.getinfo, p, "L")
            local nms = safe_call(API.getinfo, p, "n")
            if src then table.insert(buf, "-- source: " .. tostring(src)) end
            if lnd then table.insert(buf, "-- linedefined: " .. tostring(lnd)) end
            if nms then table.insert(buf, "-- name: " .. tostring(nms)) end
        end
        if API.getconstants then
            local cs = safe_call(API.getconstants, p)
            if type(cs) == "table" then
                table.insert(buf, "-- constants:")
                for i, c in next, cs do
                    table.insert(buf, ("  const[%d] = (%s) %s"):format(i, type(c), tostring(c)))
                end
            end
        end
        if SETTINGS.dump_upvalues and API.getupvalues then
            local us = safe_call(API.getupvalues, p)
            if type(us) == "table" then
                table.insert(buf, "-- upvalues:")
                for i, u in next, us do
                    table.insert(buf, ("  upval[%d] = (%s) %s"):format(i, type(u), tostring(u)))
                end
            end
        end
        safe_writefile(full, table.concat(buf, "\n"))
    end
end

local function dump_upvals_only(inst, isnil)
    if not SETTINGS.dump_upvalues or not API.getupvalues then return end
    local list = safe_call(API.getupvalues, inst)
    if type(list) ~= "table" then return end
    local rel = "upvalues/" .. short_path(inst, isnil) .. ".txt"
    local full = build_dirs(rel)
    local buf = {header(inst, {"-- Section: upvalues (" .. #list .. ")"})}
    for i, u in next, list do
        table.insert(buf, ("[%d] (%s) %s"):format(i, type(u), tostring(u)))
    end
    safe_writefile(full, table.concat(buf, "\n"))
end

local function dump_debug(inst, isnil)
    if not SETTINGS.dump_debug_info then return end
    local lines = {header(inst, {"-- Section: debug info"})}
    local fields = {
        s = "source",       l = "currentline",  n = "name",
        f = "func",         L = "linedefined", u = "nupvals",
        r = "funcname",     R = "nconsts",     S = "what",
        t = "lastlinedefined", T = "nparams",   Z = "activelines",
        E = "event",        I = "ssbuf",
    }
    for what, label in next, fields do
        local val = safe_call(API.getinfo, inst, what)
        if val ~= nil then
            table.insert(lines, ("-- info[%s] = %s"):format(label, tostring(val)))
        end
    end
    local rel = "debug_info/" .. short_path(inst, isnil) .. ".debug.txt"
    local full = build_dirs(rel)
    safe_writefile(full, table.concat(lines, "\n"))
end

local function dump_bytecode(inst, isnil)
    if not SETTINGS.dump_bytecode or not API.getscriptbytecode then return end
    local bc = safe_call(API.getscriptbytecode, inst)
    if not bc then return end
    local rel = "bytecode/" .. short_path(inst, isnil) .. ".bytecode.txt"
    local full = build_dirs(rel)
    local body = header(inst, {"-- Section: bytecode (hex)"})
    local hex = {}
    if type(bc) == "string" then
        for i = 1, #bc do
            hex[#hex+1] = string.format("%02x", bc:byte(i))
        end
    end
    body = body .. table.concat(hex, " ") .. "\n"
    body = body .. "\n-- Type: " .. type(bc) .. " | Len: " .. tostring(type(bc) == "string" and #bc or "?")
    safe_writefile(full, body)
end

local function dump_disasm(inst, isnil)
    if not SETTINGS.dump_disassemble or not has(disassemble) then return end
    local ok, src = pcall(disassemble, inst)
    if not ok or type(src) ~= "string" then return end
    local rel = "disasm/" .. short_path(inst, isnil) .. ".dis.txt"
    local full = build_dirs(rel)
    safe_writefile(full, header(inst, {"-- Section: disassembly"}) .. src)
end

----------------------------------------------------------------
-- Thread pool
----------------------------------------------------------------
local active = 0
local function wait_slot()
    while active >= SETTINGS.threads do task_wait(0.05) end
    active += 1
end

local function write_script(inst, isnil)
    wait_slot()
    task_spawn(function()
        local ok, err = pcall(function()
            local rel = dump_path(inst, isnil)
            local full = build_dirs(rel)

            local src, timed = try_decompile(inst)
            if timed then
                failed += 1
                local fname, fpath, fcls = "?", "?", "?"
                pcall(function() fname = inst.Name end)
                pcall(function() fpath = inst:GetFullName() end)
                pcall(function() fcls  = inst.ClassName end)
                table.insert(timed_out, ("Name: %s\nPath: %s\nClass: %s"):format(fname, fpath, fcls))
                no_source += 1
            elseif not src then
                failed += 1
                no_source += 1
            else
                if SETTINGS.ignore_empty and is_empty(src) then
                    empty_skipped += 1
                else
                    local payload = header(inst) .. src
                    if safe_writefile(full, payload) then
                        dumped += 1

                        -- analysis
                        local stats = analyze_obfuscation(src)
                        if stats and stats.total_len > 0 then
                            local rel2 = "analysis/" .. short_path(inst, isnil) .. ".obf.txt"
                            local full2 = build_dirs(rel2)
                            local lines = {header(inst, {"-- Section: obfuscation analysis"})}
                            table.insert(lines, "-- total_len:    " .. stats.total_len)
                            table.insert(lines, "-- lines:        " .. stats.lines)
                            table.insert(lines, "-- strings:      " .. stats.strings)
                            table.insert(lines, "-- long_strings: " .. stats.long_strings)
                            table.insert(lines, "-- numbers:      " .. stats.numbers)
                            table.insert(lines, "-- comment_ratio: " .. string.format("%.4f", stats.comment_ratio))
                            if stats.suspicious and #stats.suspicious > 0 then
                                table.insert(lines, "-- suspicious:")
                                for _, s in next, stats.suspicious do
                                    table.insert(lines, "--   * " .. s)
                                end
                            end
                            safe_writefile(full2, table.concat(lines, "\n"))
                        end
                    end
                end
            end

            dump_constants(inst, isnil)
            dump_upvals_only(inst, isnil)
            dump_protos(inst, isnil)
            dump_debug(inst, isnil)
            dump_bytecode(inst, isnil)
            dump_disasm(inst, isnil)
        end)
        if not ok then failed += 1 end
        active -= 1
    end)
end

----------------------------------------------------------------
-- Remotes
----------------------------------------------------------------
local function dump_remote_list(list, label)
    if #list == 0 then return end
    local buf = {header(nil, {"-- Section: " .. label})}
    for _, r in next, list do
        local ok_path, path = pcall(function() return r:GetFullName() end)
        if not ok_path or not path then path = "?" end
        path = replace_user(path)
        local cls, nm = "?", "?"
        pcall(function() cls = r.ClassName end)
        pcall(function() nm  = r.Name end)
        table.insert(buf, ("[%s] %s -> %s"):format(cls, sanitize(path), nm))

        if SETTINGS.dump_connections and API.getconnections then
            pcall(function()
                local conns = API.getconnections(r)
                if type(conns) == "table" and #conns > 0 then
                    table.insert(buf, "  ^ connections: " .. tostring(#conns))
                    for ci, c in next, conns do
                        local fn = "?"
                        pcall(function()
                            if c and c.Function then fn = tostring(c.Function) end
                            if c and c.Callback then fn = tostring(c.Callback) end
                        end)
                        table.insert(buf, ("    [%d] %s"):format(ci, fn))
                    end
                end
            end)
        end
    end
    safe_writefile(DIRS.remotes .. "/" .. label .. ".txt", table.concat(buf, "\n"))
end

local function dump_remotes()
    dump_remote_list(remote_events, "RemoteEvents")
    dump_remote_list(remote_funcs,  "RemoteFunctions")
    if SETTINGS.dump_bindables then dump_remote_list(bindables, "Bindables") end
    if SETTINGS.dump_unreliable then dump_remote_list(unrel, "UnreliableRemoteEvents") end

    local buf = {
        header(nil, {"-- Section: remote summary"}),
        ("RemoteEvent count:      %d"):format(#remote_events),
        ("RemoteFunction count:   %d"):format(#remote_funcs),
        ("Bindable count:         %d"):format(#bindables),
        ("UnreliableRemote count: %d"):format(#unrel),
    }
    safe_writefile(DIRS.remotes .. "/remotes.txt", table.concat(buf, "\n"))
end

----------------------------------------------------------------
-- getgc (com mais info)
----------------------------------------------------------------
local function dump_getgc_section()
    if not SETTINGS.dump_getgc or not API.getgc then return end
    local ok_gc, all = pcall(API.getgc, true)
    if not ok_gc or type(all) ~= "table" then return end
    local count, written = 0, 0
    local seen_source = {}

    for _, v in next, all do
        count += 1
        if written >= SETTINGS.max_gc_dump then break end
        local tv = (typeof and typeof(v)) or type(v)
        if tv == "function" then
            local info = {}
            for what, lbl in next, {
                s = "source", l = "line", n = "name",
                L = "linedefined", u = "nupvals", r = "funcname",
            } do
                local val = safe_call(API.getinfo, v, what)
                if val and val ~= "" and val ~= "[C]" then
                    info[lbl] = val
                end
            end
            if info.source or info.name then
                local key = (info.source or "?") .. "|" .. (info.name or "?")
                if not seen_source[key] then
                    seen_source[key] = true
                    local rel = ("getgc/%05d_%s.lua"):format(written, sanitize(info.name or "anon"))
                    local full = build_dirs(rel)
                    local body_lines = {
                        "-- Source:       " .. (info.source or "?"),
                        "-- Name:         " .. (info.name   or "?"),
                        "-- Line:         " .. tostring(info.line         or "?"),
                        "-- Linedefined:  " .. tostring(info.linedefined  or "?"),
                        "-- Nupvalues:    " .. tostring(info.nupvals      or "?"),
                        "-- Funcname:     " .. (info.funcname            or "?"),
                    }
                    if API.getconstants then
                        local cs = safe_call(API.getconstants, v)
                        if type(cs) == "table" then
                            table.insert(body_lines, "-- Constants (" .. #cs .. "):")
                            for i, c in next, cs do
                                table.insert(body_lines, ("  [%d] (%s) %s"):format(i, type(c), tostring(c)))
                            end
                        end
                    end
                    if API.getupvalues then
                        local us = safe_call(API.getupvalues, v)
                        if type(us) == "table" then
                            table.insert(body_lines, "-- Upvalues (" .. #us .. "):")
                            for i, u in next, us do
                                table.insert(body_lines, ("  [%d] (%s) %s"):format(i, type(u), tostring(u)))
                            end
                        end
                    end
                    table.insert(body_lines, "")
                    if safe_writefile(full, table.concat(body_lines, "\n")) then
                        written += 1
                    end
                end
            end
        elseif tv == "thread" then
            local src = safe_call(API.getinfo, v, "s")
            if src and src ~= "[C]" and src ~= "" then
                local key = "thread|" .. src
                if not seen_source[key] then
                    seen_source[key] = true
                    local rel = ("getgc/threads/%05d.txt"):format(written)
                    local full = build_dirs(rel)
                    if safe_writefile(full, "-- Thread source: " .. tostring(src)) then
                        written += 1
                    end
                end
            end
        end
        if count % 2000 == 0 then task_wait(0) end
    end

    safe_writefile(DIRS.getgc .. "/! index.txt", table.concat({
        header(nil, {"-- Section: getgc index"}),
        ("Scanned: %d"):format(count),
        ("Written: %d"):format(written),
    }, "\n"))
end

----------------------------------------------------------------
-- getreg (expandido)
----------------------------------------------------------------
local function dump_registry()
    if not SETTINGS.dump_getreg or not API.getreg then return end
    local ok, reg = pcall(API.getreg)
    if not ok or type(reg) ~= "table" then return end
    local buf = {header(nil, {"-- Section: registry (filtered)"})}
    local n, written = 0, 0
    local filters = {
        "remote", "event", "callback", "module", "script", "net",
        "instance", "lua", "table", "function", "hook", "wrap", "orig",
    }
    for k, v in next, reg do
        n += 1
        if n > SETTINGS.max_reg_keys then break end
        if written >= 5000 then break end
        local ks = tostring(k)
        local lk = ks:lower()
        local matched = false
        for _, f in next, filters do
            if lk:find(f) then matched = true; break end
        end
        if not matched then
            local tv = (typeof and typeof(v)) or type(v)
            if tv == "Instance" or tv == "function" or tv == "table" then
                matched = true
            end
        end
        if matched then
            table.insert(buf, ("[%s] = (%s) %s"):format(ks, type(v), tostring(v)))
            written += 1
        end
    end
    table.insert(buf, ("\nTotal scanned: %d | written: %d"):format(n, written))
    safe_writefile(DIRS.registry .. "/registry.txt", table.concat(buf, "\n"))
end

----------------------------------------------------------------
-- gethui
----------------------------------------------------------------
local function dump_gethui()
    if not SETTINGS.dump_gethui or not API.gethui then return end
    pcall(function()
        local h = API.gethui()
        if not h or ((typeof and typeof(h)) or type(h)) ~= "Instance" then return end
        local buf = {header(nil, {"-- Section: gethui hierarchy"})}
        local function walk(inst, depth)
            local pad = string.rep("  ", depth)
            local cls, nm = "?", "?"
            pcall(function() cls = inst.ClassName end)
            pcall(function() nm  = inst.Name end)
            local line = pad .. cls .. " " .. nm
            if cls == "LocalScript" or cls == "ModuleScript" then
                line = line .. "  <-- SCRIPT"
            end
            table.insert(buf, line)
            pcall(function()
                for _, c in next, inst:GetChildren() do walk(c, depth + 1) end
            end)
        end
        walk(h, 0)
        safe_writefile(DIRS.gethui .. "/hierarchy.txt", table.concat(buf, "\n"))
    end)
end

----------------------------------------------------------------
-- loadedscripts
----------------------------------------------------------------
local function dump_loadedscripts()
    if not SETTINGS.dump_loadedscripts or not API.loadedscripts then return end
    local n = 0
    pcall(function()
        for _, s in next, API.loadedscripts() do
            n += 1
            if s and (s.ClassName == "LocalScript" or s.ClassName == "ModuleScript") and not is_ignored(s) then
                table.insert(scripts, s)
            end
        end
    end)
    safe_writefile(DIRS.loaded .. "/! count.txt", ("Loaded scripts seen: %d"):format(n))
end

----------------------------------------------------------------
-- replication focus
----------------------------------------------------------------
local function dump_replicationfocus()
    if not SETTINGS.dump_replicationfocus or not API.replicationfocus then return end
    pcall(function()
        local inst = API.replicationfocus
        if ((typeof and typeof(inst)) or type(inst)) ~= "Instance" then return end
        local buf = {header(nil, {"-- Section: replication focus hierarchy"})}
        local function walk(i, depth)
            local pad = string.rep("  ", depth)
            local cls, nm = "?", "?"
            pcall(function() cls = i.ClassName end)
            pcall(function() nm  = i.Name end)
            table.insert(buf, pad .. cls .. " " .. nm)
            pcall(function()
                for _, c in next, i:GetChildren() do walk(c, depth + 1) end
            end)
        end
        walk(inst, 0)
        safe_writefile(PLACE_DIR .. "/replicationfocus.txt", table.concat(buf, "\n"))
    end)
end

----------------------------------------------------------------
-- Hidden properties (scan select instances)
----------------------------------------------------------------
local function dump_hidden_properties()
    if not SETTINGS.dump_hidden_props or not API.gethiddenproperty then return end
    local targets = {}
    pcall(function()
        for _, c in next, game:GetDescendants() do
            if c.ClassName == "LocalScript" or c.ClassName == "ModuleScript" or c.ClassName == "ScreenGui" then
                table.insert(targets, c)
            end
        end
    end)
    local buf = {header(nil, {"-- Section: hidden properties (sampled)"})}
    local keys = { "Source", "LinkedSource", "Require", "ModuleScript", "RunContext", "Disabled", "CoreScript" }
    local count = 0
    for i, inst in next, targets do
        if i > 500 then break end
        local nm, cls = "?", "?"
        pcall(function() nm  = inst.Name end)
        pcall(function() cls = inst.ClassName end)
        for _, k in next, keys do
            pcall(function()
                local v = API.gethiddenproperty(inst, k)
                if v ~= nil then
                    table.insert(buf, ("[%s] %s.%s = %s"):format(cls, nm, k, tostring(v)))
                    count += 1
                end
            end)
        end
    end
    table.insert(buf, ("\nFound: %d"):format(count))
    safe_writefile(DIRS.hidden .. "/hidden_props.txt", table.concat(buf, "\n"))
end

----------------------------------------------------------------
-- Marketplace info extra (creator, icon, etc)
----------------------------------------------------------------
local function dump_marketplace()
    if not SETTINGS.dump_marketplace then return end
    local buf = {
        header(nil, {"-- Section: marketplace info"}),
        "PlaceId:     " .. tostring(placeid),
        "GameId:      " .. tostring(gameid),
        "UniverseId:  " .. tostring(universeid),
        "Name:        " .. placename,
        "Creator:     " .. tostring(creator_name),
        "CreatorId:   " .. tostring(creator_id),
    }
    pcall(function()
        local ms = game:GetService("MarketplaceService")
        if ms and ms.GetProductInfo then
            local info = ms:GetProductInfo(placeid, Enum.InfoType.Asset)
            if info and info.Description then
                buf[#buf+1] = "Description:  " .. tostring(info.Description):sub(1, 500)
            end
            if info and info.Price then
                buf[#buf+1] = "Price:        " .. tostring(info.Price)
            end
            if info and info.Created then
                buf[#buf+1] = "Created:      " .. tostring(info.Created)
            end
            if info and info.Updated then
                buf[#buf+1] = "Updated:      " .. tostring(info.Updated)
            end
        end
    end)
    safe_writefile(PLACE_DIR .. "/! marketplace.txt", table.concat(buf, "\n"))
end

----------------------------------------------------------------
-- Metadata
----------------------------------------------------------------
local function write_meta()
    local lines = {
        "================ Ultimate Dumper PRO (PC) ================",
        "Executor:    " .. tostring(identify) .. " " .. tostring(exec_version),
        "PlaceId:     " .. tostring(placeid),
        "PlaceName:   " .. placename,
        "GameId:      " .. tostring(gameid),
        "UniverseId:  " .. tostring(universeid),
        "Creator:     " .. tostring(creator_name) .. " (" .. tostring(creator_id) .. ")",
        "JobId:       " .. tostring(jobid),
        "User:        " .. tostring(username) .. " (" .. tostring(userid) .. ") " .. tostring(displayname),
        "Timestamp:   " .. tostring(os.time and os.time() or "?"),
        "Threads:     " .. tostring(SETTINGS.threads),
        "Timeout:     " .. tostring(SETTINGS.timeout) .. "s",
        "============================================================",
        "",
        "Script count (normal):     " .. tostring(#scripts),
        "Script count (nil):        " .. tostring(#nil_scripts),
        "RemoteEvent count:         " .. tostring(#remote_events),
        "RemoteFunction count:      " .. tostring(#remote_funcs),
        "Bindable count:            " .. tostring(#bindables),
        "UnreliableRemote count:    " .. tostring(#unrel),
        "",
        "Dumped:                   " .. tostring(dumped),
        "Timed out / no source:    " .. tostring(failed),
        "Empty skipped:            " .. tostring(empty_skipped),
        "No source:                " .. tostring(no_source),
        "",
        "API detected:",
        "  decompile:        " .. tostring(has(API.decompile) and API.decompile ~= function() return "-- no decompile api" end),
        "  disassemble:      " .. tostring(has(disassemble)),
        "  getscriptbytecode:" .. tostring(API.getscriptbytecode ~= nil),
        "  getnilinstances:  " .. tostring(API.getnilinstances ~= nil),
        "  getscripthash:    " .. tostring(API.getscripthash ~= function() return nil end),
        "  getscriptclosure: " .. tostring(API.getscriptclosure ~= nil),
        "  getconstants:     " .. tostring(API.getconstants ~= nil),
        "  getprotos:        " .. tostring(API.getprotos ~= nil),
        "  getupvalues:      " .. tostring(API.getupvalues ~= nil),
        "  getgc:            " .. tostring(API.getgc ~= nil),
        "  getreg:           " .. tostring(API.getreg ~= nil),
        "  gethui:           " .. tostring(API.gethui ~= nil),
        "  loadedscripts:    " .. tostring(API.loadedscripts ~= nil),
        "  getactors:        " .. tostring(API.getactors ~= nil),
        "  replicationfocus: " .. tostring(API.replicationfocus ~= nil),
        "  getconnections:   " .. tostring(API.getconnections ~= nil),
        "  gethiddenproperty:" .. tostring(API.gethiddenproperty ~= nil),
        "  gethiddenproperties:" .. tostring(API.gethiddenproperties ~= nil),
        "  hookfunction:     " .. tostring(API.hookfunction ~= nil),
        "  hooksignal:       " .. tostring(API.hooksignal ~= nil),
        "  isrbxactive:      " .. tostring(API.isrbxactive ~= nil),
        "  cloneref:         " .. tostring(API.cloneref ~= nil),
        "  request (http):   " .. tostring(API.request ~= nil),
        "  filesystem:       " .. tostring(has_fs()),
    }
    safe_writefile(META_FILE, table.concat(lines, "\n"))
end

----------------------------------------------------------------
-- Summary
----------------------------------------------------------------
local function write_summary()
    if not has_fs() then return end
    local lines = {
        "================== SUMARIO ==================",
        ("Game: %s (%d) | Place: %d"):format(placename, placeid, placeid),
        ("Dumped: %d | Falharam: %d | Vazios: %d"):format(dumped, failed, empty_skipped),
        ("Total scripts encontrados: %d (+ %d nil)"):format(#scripts, #nil_scripts),
        ("Remotes: %d events, %d funcs, %d bind, %d unrel"):format(
            #remote_events, #remote_funcs, #bindables, #unrel),
        "",
        "Pastas geradas:",
        "  scripts/        - decompilados",
        "  nil/            - scripts de instancias destruidas",
        "  raw_decompile/  - quando decompile falha",
        "  bytecode/       - bytecode hex",
        "  disasm/         - disassembly",
        "  constants/      - getconstants",
        "  protos/         - protos recursivos",
        "  upvalues/       - upvalues",
        "  debug_info/     - debug.info completo",
        "  analysis/       - heuristica de obfuscacao",
        "  remotes/        - lista + connections",
        "  getgc/          - funcoes e threads",
        "  registry/       - chaves filtradas",
        "  gethui/         - hierarquia de GUI",
        "  loadedscripts/  - contagem",
        "  hidden_props/   - propriedades ocultas",
        "  hooks/          - relatorio de hooks",
        "  marketplace.txt - info do jogo",
        "  metadata.txt    - metadados completos",
        "  summary.txt     - este arquivo",
    }
    safe_writefile(SUMMARY, table.concat(lines, "\n"))
end

----------------------------------------------------------------
-- Logging
----------------------------------------------------------------
local function log(msg)
    pcall(function()
        if rconsole and rconsole.print then rconsole.print("[UD] " .. tostring(msg)) end
        if console and console.warn then console.warn("[UD] " .. tostring(msg)) end
        warn("[UD] " .. tostring(msg))
        print("[UD] " .. tostring(msg))
    end)
end

----------------------------------------------------------------
-- Run
----------------------------------------------------------------
local function run()
    log("=== Ultimate Dumper PRO (PC EDITION) starting ===")
    log("Executor: " .. tostring(identify))
    log("Place:    " .. tostring(placeid) .. " - " .. placename)
    log("Out dir:  " .. PLACE_DIR)

    local render_off = false
    if SETTINGS.disable_render then
        pcall(function()
            local rs = game:GetService("RunService")
            if rs and rs.Set3dRenderingEnabled then
                rs:Set3dRenderingEnabled(false)
                render_off = true
            end
        end)
        log("Render disabled: " .. tostring(render_off))
    end

    log("Dumping remotes... (events=" .. #remote_events .. " funcs=" .. #remote_funcs
        .. " bindables=" .. #bindables .. " unrel=" .. #unrel .. ")")
    pcall(dump_remotes);                 log("Remotes done.")
    pcall(dump_loadedscripts);           log("loadedscripts processed.")
    pcall(dump_replicationfocus);        log("replicationfocus processed.")
    pcall(dump_gethui);                  log("gethui processed.")
    pcall(dump_registry);                log("registry processed.")
    pcall(dump_marketplace);             log("marketplace processed.")
    pcall(dump_hidden_properties);       log("hidden properties processed.")

    local total_scripts = #scripts + #nil_scripts
    log("Dumping " .. #scripts .. " normal + " .. #nil_scripts
        .. " nil scripts (" .. total_scripts .. " total) x" .. SETTINGS.threads .. " threads")
    for _, s in next, scripts     do pcall(write_script, s, false) end
    for _, s in next, nil_scripts do pcall(write_script, s, true)  end

    log("Waiting for active threads to finish...")
    while active > 0 do
        task_wait(0.2)
        pcall(function()
            if rconsole and rconsole.print then
                rconsole.print(string.format("[UD] active=%d dumped=%d failed=%d", active, dumped, failed))
            end
        end)
    end
    log("All threads finished.")

    if SETTINGS.dump_getgc and API.getgc then
        log("Scanning getgc()...")
        pcall(dump_getgc_section)
        log("getgc scan done.")
    else
        log("getgc skipped (disabled or unavailable).")
    end

    if #timed_out > 0 then
        safe_writefile(TIMEOUTS, table.concat(timed_out, "\n\n"))
        log("Timed out: " .. #timed_out)
    end

    pcall(write_meta)
    pcall(write_summary)
    log(string.format("=== DONE. dumped=%d failed=%d empty=%d ===", dumped, failed, empty_skipped))

    if render_off then
        pcall(function()
            local rs = game:GetService("RunService")
            if rs and rs.Set3dRenderingEnabled then rs:Set3dRenderingEnabled(true) end
        end)
    end
end

local ok, err = pcall(run)
if not ok then
    pcall(safe_writefile, PLACE_DIR .. "/! crash.txt",
        "Crash at " .. tostring(os.time and os.time() or "?") .. ":\n" .. tostring(err))
    warn("[UD] CRASH: " .. tostring(err))
end
