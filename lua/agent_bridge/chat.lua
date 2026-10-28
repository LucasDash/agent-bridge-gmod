-- Player chat is attributed context, never executable code or authority.
if not SERVER then return end

AgentBridge = AgentBridge or {}
local previous = AgentBridge.Chat
local legacy = AgentBridge.MigrateLegacyChat == true and CodexFeedbackBridge or nil
local state = previous or legacy
local hookName = "AgentBridge.Chat"
local chat = {
    version = 1,
    epoch = state and state.epoch or (game.GetMap() .. ":" .. os.time() .. ":" .. math.floor(SysTime() * 1000)),
    sequence = state and state.sequence or 0,
    entries = {},
    lastByPlayer = {},
    capacity = 64,
    maxBytes = 512,
    migratedLegacy = previous and previous.migratedLegacy or legacy ~= nil,
}

-- Copy retained data so stopping/reloading a former provider cannot mutate it.
if state then
    for _, entry in ipairs(state.entries or {}) do
        local copy = table.Copy(entry)
        if legacy and legacy.version == 1 then copy.kind = copy.kind or "direct" end
        chat.entries[#chat.entries + 1] = copy
    end
    for key, value in pairs(state.lastByPlayer or {}) do chat.lastByPlayer[key] = value end
end
while #chat.entries > chat.capacity do table.remove(chat.entries, 1) end
AgentBridge.Chat = chat

function chat.Capture(ply, text, teamOnly)
    if not IsValid(ply) or not ply:IsPlayer() or not isstring(text) then return end
    local addressed = text:match("^%s*![Aa][Gg][Ee][Nn][Tt]%s+(.+)$")
        or text:match("^%s*![Cc][Oo][Dd][Ee][Xx]%s+(.+)$")
    local normalized = string.Trim(text)
    local tag = normalized:lower()
    local bareTag = tag == "!agent" or tag == "!codex"
    local kind = (addressed or bareTag) and "direct" or "ambient"
    local body = (bareTag and normalized or addressed or text):gsub("[%c]", " ")
    body = string.Trim(body)
    if body == "" or #body > chat.maxBytes then return end

    local id = ply:SteamID64() or "unknown"
    local now = CurTime()
    for key, last in pairs(chat.lastByPlayer) do
        if now - last > 10 then chat.lastByPlayer[key] = nil end
    end
    local rateKey = id .. ":" .. kind
    if chat.lastByPlayer[rateKey] and now - chat.lastByPlayer[rateKey] < 0.5 then return end
    if not chat.lastByPlayer[rateKey] and table.Count(chat.lastByPlayer) >= 128 then return end
    chat.lastByPlayer[rateKey] = now

    chat.sequence = chat.sequence + 1
    local name = ply:Nick():gsub("[%c]", " ")
    if #name > 96 then name = "[long player name]" end
    chat.entries[#chat.entries + 1] = {
        sequence = chat.sequence,
        kind = kind,
        player = name,
        steamid64 = id,
        listenHost = ply:IsListenServerHost(),
        admin = ply:IsAdmin(),
        teamOnly = teamOnly == true,
        time = os.time(),
        text = body,
    }
    while #chat.entries > chat.capacity do table.remove(chat.entries, 1) end
    -- A nil return leaves ordinary chat and other PlayerSay hooks intact.
end

function chat.Read(after, limit)
    after = math.max(0, math.floor(tonumber(after) or 0))
    limit = math.Clamp(math.floor(tonumber(limit) or 2), 1, 2)
    local result = {version = chat.version, epoch = chat.epoch, latest = chat.sequence, entries = {}}
    local oldest = chat.entries[1] and chat.entries[1].sequence or chat.sequence + 1
    result.droppedBefore = after < oldest - 1 and oldest - 1 or nil
    for _, entry in ipairs(chat.entries) do
        if entry.sequence > after then
            result.entries[#result.entries + 1] = table.Copy(entry)
            if #result.entries >= limit then break end
        end
    end
    return result
end

local callback = function(ply, text, teamOnly)
    chat.Capture(ply, text, teamOnly)
end

function chat.Start()
    hook.Add("PlayerSay", hookName, callback)
end

function chat.Stop()
    local handlers = hook.GetTable().PlayerSay
    if handlers and handlers[hookName] == callback then hook.Remove("PlayerSay", hookName) end
end

function chat.Status()
    local handlers = hook.GetTable().PlayerSay
    return {version = chat.version, epoch = chat.epoch, latest = chat.sequence,
        retained = #chat.entries, capacity = chat.capacity,
        active = handlers and handlers[hookName] == callback or false,
        migratedLegacy = chat.migratedLegacy}
end

chat.Start()
