-- Standalone client editor for resolved GMod Lua sources. Saves DATA drafts only.
if not CLIENT then return end
AgentBridge = AgentBridge or {}
local Editor = {}
AgentBridge.SourceEditor = Editor

local MAX_BYTES = 256 * 1024
local DRAFT_DIR = "agent_bridge/drafts"
local serial = 0

local function validatePath(path)
    if not isstring(path) or #path == 0 or #path > 1024
        or path:sub(1, 1) == "/" or path:find("\\", 1, true) or path:find(":", 1, true)
        or path:find("//", 1, true) or path:find("[%c]")
        or not path:lower():match("%.lua$") then return false end
    for part in path:gmatch("[^/]+") do
        if part == "." or part == ".." then return false end
    end
    return true
end

local function readSource(path)
    if not validatePath(path) then return nil, "Invalid Lua source path." end
    local handle = file.Open(path, "rb", "LUA")
    if not handle then return nil, "The resolved LUA source is not readable." end
    local size = handle:Size()
    if not isnumber(size) or size < 0 or size > MAX_BYTES then
        handle:Close()
        return nil, "Source exceeds the 256 KiB limit or has an invalid size."
    end
    local data = size == 0 and "" or handle:Read(size)
    handle:Close()
    if not isstring(data) or #data ~= size then return nil, "Could not read the complete source." end
    if data:find("\0", 1, true) then return nil, "The source contains binary data." end
    return data
end

local function saveDraft(path, text)
    if not validatePath(path) then return nil, "Invalid Lua source path." end
    if not isstring(text) or #text > MAX_BYTES then return nil, "Draft exceeds the 256 KiB limit." end
    if text:find("\0", 1, true) then return nil, "The draft contains binary data." end
    file.CreateDir("agent_bridge")
    file.CreateDir(DRAFT_DIR)
    if not file.IsDir(DRAFT_DIR, "DATA") then return nil, "Could not create the drafts folder." end
    local basename = (path:match("([^/]+)$") or "source"):lower():gsub("[^%w_%-]", "_"):sub(1, 48)
    for _ = 1, 32 do
        serial = serial + 1
        local name = basename .. "_" .. os.time() .. "_" .. util.CRC(path .. ":" .. tostring(SysTime()) .. ":" .. serial)
        local destination = DRAFT_DIR .. "/" .. name .. ".lua.txt"
        -- GMod file.Write has no exclusive-create mode. The unique name and
        -- immediate existence check avoid ordinary collisions; they are not
        -- an atomic guard against another process creating this path.
        if not file.Exists(destination, "DATA") then
            if file.Write(destination, text) ~= true then return nil, "Could not write the draft." end
            return destination
        end
    end
    return nil, "Could not find an unused draft name."
end

function Editor.NormalizeSource(source)
    if not isstring(source) then return nil, "Invalid source text." end
    local hadCRLF = source:find("\r\n", 1, true) ~= nil
    local normalized = source:gsub("\r\n", "\n")
    local withoutCRLF = source:gsub("\r\n", "")
    if normalized:find("\r", 1, true) or (hadCRLF and withoutCRLF:find("\n", 1, true)) then
        return nil, "Mixed or unsupported line endings; use another editor for this source."
    end
    return normalized, hadCRLF and "CRLF" or "LF"
end

function Editor.EncodeDraft(text, style)
    if not isstring(text) or text:find("\r", 1, true) or (style ~= "LF" and style ~= "CRLF") then
        return nil, "Invalid draft text or line-ending style."
    end
    if style == "CRLF" then return (text:gsub("\n", "\r\n")) end
    return text
end

function Editor.ConfigureInput(input, text)
    input:SetMultiline(true)
    input:SetMaximumCharCount(MAX_BYTES)
    input:SetAllowNonAsciiCharacters(true)
    input:SetVerticalScrollbarEnabled(true)
    input:SetText(text)
    if input:GetValue() ~= text then return false, "This source cannot be represented faithfully by the native editor." end
    return true
end

Editor.ReadSource = readSource
Editor.SaveDraft = saveDraft
