--// Ultimate Dumper (no UI, no deps, executor-friendly)
--// Combina: hierarquia (best-dumper) + threads/timeout/cache/fullname (dumper-pro) + nil scripts

local SETTINGS = {
    threads          = 6,        -- decompiles paralelos
    decompile_delay  = 0.05,     -- yield entre dumps
    timeout          = 6,        -- segundos por decompile
    disable_render   = true,     -- desliga render 3d enquanto roda
    ignore_empty     = true,     -- pula scripts so de comentario
    include_nil      = true,     -- inclui getnilinstances()
    replace_username = true,     -- troca seu user por "LocalPlayer"
    min_size         = 200,      -- tamanho minimo pra nao contar como "vazio"
}

----------------------------------------------------------------
-- Polyfills (caso o executor nao exponha alguma)
----------------------------------------------------------------
local decompile      = decompile      or disassemble
local getnilinstances = getnilinstances or get_nil_instances
local getscripthash  = getscripthash  or get_script_hash
local getscriptclosure = getscriptclosure
local getconstants   = getconstants   or debug.getconstants
local getprotos      = getprotos      or debug.getprotos
local getinfo        = getinfo        or debug.info
local identify       = (identifyexecutor and identifyexecutor()) or "Unknown Executor"
local queueonteleport = queueonteleport or queue_on_teleport
local task_wait      = task.wait
local task_spawn     = task.spawn

----------------------------------------------------------------
-- Sanitizacao
----------------------------------------------------------------
local invalid = {string.char(127), "\\", ":", "*", "?", '"', "<", ">", "|", "\n", "\r", "\t"}
for i=0,32 do table.insert(invalid, string.char(i)) end
for i=128,255 do table.insert(invalid, string.char(i)) end

local function sanitize(str)
    for _, c in next, invalid do
        str = str:gsub(c, "")
    end
    return str
end

local function safe_folder(path)
    if not isfolder(path) then
        local ok, err = pcall(makefolder, path)
        if not ok then return false, err end
    end
    return true
end

----------------------------------------------------------------
-- Pastas
----------------------------------------------------------------
local placeid    = game.PlaceId
local market_ok, market = pcall(function()
    return game:GetService("MarketplaceService"):GetProductInfo(placeid)
end)
local placename = (market_ok and market and market.Name) or "Place"
placename = placename:gsub("[\\/:%*%?\"<>|]", " ")

local ROOT       = "Ultimate Dumper"
local PLACE_DIR  = ROOT .. "/[" .. tostring(placeid) .. "] " .. placename
local SCRIPTS    = PLACE_DIR .. "/scripts"
local NIL_DIR    = PLACE_DIR .. "/nil"
local REMOTES    = PLACE_DIR .. "/remotes"
local META_FILE  = PLACE_DIR .. "/! metadata.txt"
local TIMEOUTS   = PLACE_DIR .. "/! timed out.txt"

safe_folder(ROOT)
safe_folder(PLACE_DIR)
safe_folder(SCRIPTS)
safe_folder(NIL_DIR)
safe_folder(REMOTES)

----------------------------------------------------------------
-- Replace username
----------------------------------------------------------------
local plr = game:GetService("Players").LocalPlayer
local username = plr and plr.Name or ""
local safe_username = username:gsub("[%%%.%[%]%(%)%*%+%-%?]", "%%%0")

----------------------------------------------------------------
-- Helpers de nome
----------------------------------------------------------------
local function short_path(inst, isnil)
    local path = isnil and "[nil] " .. inst:GetFullName() or inst:GetFullName()
    if SETTINGS.replace_username and safe_username ~= "" then
        path = path:gsub(safe_username, "LocalPlayer")
    end
    return sanitize(path)
end

local function dump_path(inst, isnil)
    local sub = isnil and "nil" or "scripts"
    return sub .. "/" .. short_path(inst, isnil)
end

local function build_dirs(rel)
    local parts = rel:split("/")
    local cur = PLACE_DIR
    for i = 1, #parts - 1 do
        cur = cur .. "/" .. parts[i]
        safe_folder(cur)
    end
    return PLACE_DIR .. "/" .. rel
end

----------------------------------------------------------------
-- Fullname "game:GetService(...)..." pro header
----------------------------------------------------------------
local function getfullname(inst)
    local ok, name = pcall(function() return inst:GetFullName() end)
    if not ok or not name then return "<unknown>" end
    if SETTINGS.replace_username and safe_username ~= "" then
        name = name:gsub(safe_username, "LocalPlayer")
    end
    if inst:IsDescendantOf(game) then
        local first, rest = name:match("^([^.]+)%.(.*)$")
        if first and rest then
            return ('game:GetService("%s").%s'):format(first, rest:gsub("%.%[", "["))
        end
    end
    return name
end

----------------------------------------------------------------
-- Coleta
----------------------------------------------------------------
local ignored_ancestors = { CoreGui = true, CorePackages = true, Chat = true }
local ignored_names     = {
    PlayerModule = true, RbxCharacterSounds = true,
    PlayerScriptsLoader = true, ChatScript = true, BubbleChat = true,
}

local function is_ignored(inst)
    if ignored_names[inst.Name] then return true end
    for anc, _ in ignored_ancestors do
        if inst:FindFirstAncestor(anc) then return true end
    end
    return false
end

local scripts, nil_scripts, remote_events = {}, {}, {}

for _, d in next, game:GetDescendants() do
    if d:IsA("LocalScript") or d:IsA("ModuleScript") then
        if not is_ignored(d) then table.insert(scripts, d) end
    elseif d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        table.insert(remote_events, d)
    end
end

if SETTINGS.include_nil and getnilinstances then
    for _, d in next, getnilinstances() do
        if (d:IsA("LocalScript") or d:IsA("ModuleScript")) and not is_ignored(d) then
            table.insert(nil_scripts, d)
        end
    end
end

----------------------------------------------------------------
-- Cache de decompile
----------------------------------------------------------------
local decompile_cache = {}
local timed_out = {}
local dumped, failed, empty_skipped = 0, 0, 0

local function try_decompile(inst)
    if decompile_cache[inst] then
        return decompile_cache[inst]
    end

    local hash_ok, hash = pcall(getscripthash, inst)
    if hash_ok and hash and decompile_cache[hash] then
        decompile_cache[inst] = decompile_cache[hash]
        return decompile_cache[hash]
    end

    local started = os.clock()
    local output

    while true do
        local ok, src = pcall(decompile, inst)
        if ok and type(src) == "string" and #src > 1 and src ~= "-- Failed to decompile script" then
            output = src
            break
        end
        if (os.clock() - started) > SETTINGS.timeout then
            output = nil
            break
        end
        task_wait(0.2)
    end

    if not output then
        if hash_ok and hash then
            decompile_cache[hash] = "-- Decompile timed out / unsupported"
        end
        return nil, true -- timed out
    end

    if hash_ok and hash then
        decompile_cache[hash] = output
    end
    decompile_cache[inst] = output
    return output
end

local function is_empty(src)
    if #src >= SETTINGS.min_size then return false end
    for line in src:gmatch("[^\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        if trimmed ~= "" and trimmed:sub(1,2) ~= "--" then
            return false
        end
    end
    return true
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
                table.insert(timed_out, ("Name: %s\nPath: %s\nClass: %s"):format(
                    inst.Name, inst:GetFullName(), inst.ClassName))
            elseif not src then
                failed += 1
            else
                if SETTINGS.ignore_empty and is_empty(src) then
                    empty_skipped += 1
                else
                    local header = table.concat({
                        "-- Name: "     .. inst.Name,
                        "-- FullName: " .. getfullname(inst),
                        "-- Class: "    .. inst.ClassName,
                        "-- Executor: " .. tostring(identify),
                        "-- Place: "    .. tostring(placeid) .. " - " .. placename,
                        "",
                    }, "\n")

                    local payload = header .. src
                    if writefile and full then
                        writefile(full, payload)
                        dumped += 1
                    end
                end
            end
        end)
        if not ok then
            failed += 1
        end
        active -= 1
    end)
end

----------------------------------------------------------------
-- Remotes (paths de NetworkReach / paths de origem)
----------------------------------------------------------------
local function dump_remotes()
    safe_folder(REMOTES)
    local buf = {}
    for _, r in next, remote_events do
        local path = r:GetFullName()
        if SETTINGS.replace_username and safe_username ~= "" then
            path = path:gsub(safe_username, "LocalPlayer")
        end
        table.insert(buf, ("[%s] %s -> %s"):format(r.ClassName, sanitize(path), r.Name))
    end
    if writefile and #buf > 0 then
        writefile(REMOTES .. "/remotes.txt", table.concat(buf, "\n"))
    end
end

----------------------------------------------------------------
-- Metadata
----------------------------------------------------------------
local function write_meta()
    local lines = {
        "Executor:   " .. tostring(identify),
        "Place:      " .. tostring(placeid),
        "PlaceName:  " .. placename,
        "GameId:     " .. tostring(game.GameId),
        "UserId:     " .. tostring(plr and plr.UserId or "?"),
        "Username:   " .. tostring(plr and plr.Name or "?"),
        "Workspace:  " .. tostring(workspace),
        "",
        ("Script count (normal): %d"):format(#scripts),
        ("Script count (nil):   %d"):format(#nil_scripts),
        ("Remote count:         %d"):format(#remote_events),
        "",
        ("Dumped:     %d"):format(dumped),
        ("Timed out:  %d"):format(failed),
        ("Empty skip: %d"):format(empty_skipped),
    }
    if writefile then
        writefile(META_FILE, table.concat(lines, "\n"))
    end
end

----------------------------------------------------------------
-- Run
----------------------------------------------------------------
local function run()
    local RunService = game:GetService("RunService")
    local render_off = false
    if SETTINGS.disable_render and RunService and RunService.Set3dRenderingEnabled then
        pcall(function()
            RunService:Set3dRenderingEnabled(false)
            render_off = true
        end)
    end

    -- Remotes first (instant)
    dump_remotes()

    -- Scripts
    for _, s in next, scripts do
        write_script(s, false)
    end
    for _, s in next, nil_scripts do
        write_script(s, true)
    end

    -- Wait drain
    while active > 0 do task_wait(0.1) end

    if #timed_out > 0 and writefile then
        writefile(TIMEOUTS, table.concat(timed_out, "\n\n"))
    end

    write_meta()

    if render_off then
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
    end
end

run()
