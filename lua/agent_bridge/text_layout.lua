-- Visual rows for GMod's native multiline TextEntry, for monospace ASCII.
-- The caller calibrates capacity against an actual TextEntry and checks the
-- resulting row count before allowing this layout to cover native text.
if not CLIENT then return end
AgentBridge = AgentBridge or {}
local M = {}
AgentBridge.TextLayout = M
local MAX_VISUAL_ROWS = 8000

local function build(logicalRows, capacity, incremental, extended)
    if type(logicalRows) ~= "table" or type(capacity) ~= "number" or capacity < 4 or capacity % 1 ~= 0 then
        return nil, "capacity"
    end
    local result, batch = {}, 0
    -- Native TextEntry ignores one leading newline visually. Keep the source
    -- unchanged, and number the first displayed row with its logical line.
    local firstLine = 1
    if #logicalRows > 1 then
        local empty = true
        for _, token in ipairs(logicalRows[1]) do if token.text ~= "" then empty = false break end end
        if empty then firstLine = 2 end
    end
    for lineNumber = firstLine, #logicalRows do
        local tokens = logicalRows[lineNumber]
        local parts = {}
        for _, token in ipairs(tokens) do
            if token.text:find("[\r\n]") or (not extended and token.text:find("[\128-\255]")) then return nil, "characters" end
            parts[#parts + 1] = token.text
        end
        local line = table.concat(parts)
        local rowStart, cursor, column = 1, 1, 0
        local wordStart, inWord, justWrapped, wordAtStart = 1, false, true, true
        local tokenIndex, tokenOffset, consumed, continuation = 1, 1, 0, false

        local function emit(endByte)
            if #result >= MAX_VISUAL_ROWS then return false end
            local row = {line = lineNumber, continuation = continuation, tokens = {}}
            while consumed < endByte do
                local token = tokens[tokenIndex]
                if not token then return false end
                local count = math.min(#token.text - tokenOffset + 1, endByte - consumed)
                if count > 0 then
                    row.tokens[#row.tokens + 1] = {kind = token.kind,
                        text = token.text:sub(tokenOffset, tokenOffset + count - 1)}
                    tokenOffset, consumed = tokenOffset + count, consumed + count
                end
                if tokenOffset > #token.text then tokenIndex, tokenOffset = tokenIndex + 1, 1 end
            end
            result[#result + 1] = row
            continuation = true
            return true
        end

        while cursor <= #line do
            local ch = line:sub(cursor, cursor)
            local byte = ch:byte()
            local charBytes = byte < 128 and 1 or (byte >= 194 and byte <= 223 and 2 or (byte >= 224 and byte <= 239 and 3 or 4))
            if cursor + charBytes - 1 > #line then return nil, "characters" end
            local whitespace = ch == " " or ch == "\t"
            if whitespace then inWord = false
            elseif not inWord then wordStart, wordAtStart, inWord = cursor, justWrapped, true end
            if ch ~= "\t" then justWrapped = false end
            if column >= capacity and ch ~= "\t" then
                local split = cursor
                if not whitespace and not wordAtStart then split, cursor = wordStart, wordStart end
                if split <= rowStart or not emit(split - 1) then return nil, "layout" end
                rowStart, column, inWord, justWrapped = split, 1, false, true
            elseif ch ~= "\t" then
                column = column + 1
            end
            local nextByte = line:byte(cursor)
            local advance = nextByte < 128 and 1 or (nextByte >= 194 and nextByte <= 223 and 2 or (nextByte >= 224 and nextByte <= 239 and 3 or 4))
            cursor = cursor + advance
            batch = batch + 1
            if incremental and batch >= 2048 then batch = 0 coroutine.yield() end
        end
        if not emit(#line) then return nil, "layout" end
        batch = batch + 1
        if incremental and batch >= 2048 then batch = 0 coroutine.yield() end
    end
    return result
end

function M.Build(rows, capacity, extended) return build(rows, capacity, false, extended) end
function M.Start(rows, capacity, extended) return coroutine.create(function() return build(rows, capacity, true, extended) end) end
