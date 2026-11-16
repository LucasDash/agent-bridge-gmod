-- Bounded observations only: player names and identifiers are untrusted data.
if not SERVER then return end

AgentBridge = AgentBridge or {}
local A = AgentBridge
local previous = A.PlayerActivity
local activity = {
    version = 1,
    epoch = previous and previous.epoch or (game.GetMap() .. ":" .. os.time() .. ":" .. math.floor(SysTime() * 1000)),
    sequence = previous and previous.sequence or 0,
    entries = {},
    capacity = 64,
}
if previous then
    for _, entry in ipairs(previous.entries or {}) do
        activity.entries[#activity.entries + 1] = table.Copy(entry)
    end
end
while #activity.entries > activity.capacity do table.remove(activity.entries, 1) end
A.PlayerActivity = activity

local function identity(ply)
    return {
        name = A.Text(ply:Nick(), 96),
        steamid64 = A.Text(ply:SteamID64(), 32),
        userID = ply:UserID(),
        entity = ply:EntIndex(),
        creationID = ply:GetCreationID(),
        bot = ply:IsBot(),
    }
end

local function capture(kind, ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    activity.sequence = activity.sequence + 1
    local entry = identity(ply)
    entry.kind = kind
    entry.sequence = activity.sequence
    entry.time = os.time()
    activity.entries[#activity.entries + 1] = entry
    while #activity.entries > activity.capacity do table.remove(activity.entries, 1) end
end

local joined = function(ply) capture("initial_spawn", ply) end
local left = function(ply) capture("disconnected", ply) end
local joinHook = "AgentBridge.PlayerActivity.InitialSpawn"
local leaveHook = "AgentBridge.PlayerActivity.Disconnected"

function activity.Start()
    hook.Add("PlayerInitialSpawn", joinHook, joined)
    hook.Add("PlayerDisconnected", leaveHook, left)
end

function activity.Stop()
    local hooks = hook.GetTable()
    if hooks.PlayerInitialSpawn and hooks.PlayerInitialSpawn[joinHook] == joined then
        hook.Remove("PlayerInitialSpawn", joinHook)
    end
    if hooks.PlayerDisconnected and hooks.PlayerDisconnected[leaveHook] == left then
        hook.Remove("PlayerDisconnected", leaveHook)
    end
end

function activity.Status()
    local hooks = hook.GetTable()
    return {version = activity.version, epoch = activity.epoch, latest = activity.sequence,
        retained = #activity.entries, capacity = activity.capacity,
        active = hooks.PlayerInitialSpawn and hooks.PlayerInitialSpawn[joinHook] == joined
            and hooks.PlayerDisconnected and hooks.PlayerDisconnected[leaveHook] == left or false}
end

function activity.Read(args)
    args = args or {}
    local after = args.after == nil and 0 or args.after
    local limit = args.limit == nil and 4 or args.limit
    assert(isnumber(after) and after == math.floor(after) and after >= 0
        and after <= 9007199254740991, "Invalid activity cursor")
    assert(isnumber(limit) and limit == math.floor(limit) and limit >= 1 and limit <= 4, "Invalid page limit")
    assert(args.epoch == nil or (isstring(args.epoch) and #args.epoch > 0 and #args.epoch <= 128), "Invalid epoch")
    assert(after == 0 or args.epoch ~= nil, "Epoch required with nonzero cursor")
    assert(args.include_players == nil or isbool(args.include_players), "Invalid player list option")

    local result = {version = activity.version, epoch = activity.epoch, latest = activity.sequence, entries = {}}
    if args.epoch and args.epoch ~= activity.epoch then
        result.epochChanged = true
    elseif after > activity.sequence then
        result.cursorAhead = true
    else
        local oldest = activity.entries[1] and activity.entries[1].sequence or activity.sequence + 1
        result.droppedBefore = after < oldest - 1 and oldest - 1 or nil
        for _, entry in ipairs(activity.entries) do
            if entry.sequence > after then
                result.entries[#result.entries + 1] = table.Copy(entry)
                if #result.entries >= limit then break end
            end
        end
    end

    if args.include_players then
        result.players = {}
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsPlayer() then
                count = count + 1
                if count <= 8 then result.players[#result.players + 1] = identity(ply) end
            end
        end
        result.playerCount = count
        result.playersTruncated = count > 8
    end
    return result
end

activity.Start()
