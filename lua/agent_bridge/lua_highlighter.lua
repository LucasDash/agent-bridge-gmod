-- Bounded GLua lexical highlighting. It never changes or executes the text.
if not CLIENT then return end
AgentBridge = AgentBridge or {}
local M = {}
AgentBridge.LuaHighlighter = M

local MAX_BYTES, MAX_LINES = 128 * 1024, 8000
local keywords = {}
for word in ("and break continue do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%S+") do
    keywords[word] = true
end

local function append(tokens, value, kind)
    if value == "" then return end
    local previous = tokens[#tokens]
    if previous and previous.kind == kind and #previous.text < 512 then previous.text = previous.text .. value
    else tokens[#tokens + 1] = {text = value, kind = kind} end
end

local function longOpen(value, offset)
    local equals = value:match("^%[(=*)%[", offset)
    if equals == nil then return nil end
    return "]" .. equals .. "]", #equals + 2
end

local function utf8Width(value, offset)
    local a, b, c, d = value:byte(offset, offset + 3)
    if not a then return nil end
    if a < 128 then return 1 end
    local function continuation(x) return x and x >= 128 and x <= 191 end
    if a >= 194 and a <= 223 and continuation(b) then return 2 end
    if a >= 224 and a <= 239 and continuation(b) and continuation(c)
        and (a ~= 224 or b >= 160) and (a ~= 237 or b <= 159) then return 3 end
    if a >= 240 and a <= 244 and continuation(b) and continuation(c) and continuation(d)
        and (a ~= 240 or b >= 144) and (a ~= 244 or b <= 143) then return 4 end
    return nil
end

local function scanLine(line, state)
    local tokens, pos, length = {}, 1, #line
    while pos <= length do
        if state and state.close then
            local _, last = line:find(state.close, pos, true)
            if not last then append(tokens, line:sub(pos), state.kind) return tokens, state end
            append(tokens, line:sub(pos, last), state.kind)
            pos, state = last + 1, nil
        elseif state and state.quote then
            local start, closed, continuation = pos, false, false
            while pos <= length do
                local c = line:sub(pos, pos)
                if c == "\\" then
                    if pos == length or line:sub(pos + 1):match("^z%s*$") then continuation = true end
                    pos = pos + 2
                elseif c == state.quote then pos = pos + 1 closed = true break
                else pos = pos + 1 end
            end
            append(tokens, line:sub(start, pos - 1), "string")
            if closed or not continuation then state = nil end
        else
            local pair = line:sub(pos, pos + 1)
            local c = line:sub(pos, pos)
            if c:byte() >= 128 then
                local width = utf8Width(line, pos)
                append(tokens, line:sub(pos, pos + width - 1), "plain")
                pos = pos + width
            elseif pair == "--" then
                local close, width = longOpen(line, pos + 2)
                if close then
                    append(tokens, line:sub(pos, pos + 1 + width), "comment")
                    pos, state = pos + 2 + width, {kind = "comment", close = close}
                else append(tokens, line:sub(pos), "comment") break end
            elseif pair == "//" then
                append(tokens, line:sub(pos), "comment") break
            elseif pair == "/*" then
                append(tokens, pair, "comment")
                pos, state = pos + 2, {kind = "comment", close = "*/"}
            elseif c == "[" then
                local close, width = longOpen(line, pos)
                if close then
                    append(tokens, line:sub(pos, pos + width - 1), "string")
                    pos, state = pos + width, {kind = "string", close = close}
                else append(tokens, c, "plain") pos = pos + 1 end
            elseif c == "'" or c == '"' then
                append(tokens, c, "string")
                pos, state = pos + 1, {quote = c}
                if pos > length then state = nil end
            elseif c:match("[%a_]") then
                local word = line:match("^[_%a][_%w]*", pos)
                local kind = keywords[word] and "keyword" or
                    (line:match("^%s*%(", pos + #word) and "function" or "plain")
                append(tokens, word, kind)
                pos = pos + #word
            elseif c:match("%d") then
                local number = line:match("^0[xX][%da-fA-F]+%.?[%da-fA-F]*[pP][%+%-]?%d+", pos) or
                    line:match("^0[xX][%da-fA-F]+", pos) or
                    line:match("^%d+%.?%d*[eE][%+%-]?%d+", pos) or line:match("^%d+%.?%d*", pos)
                append(tokens, number, "number")
                pos = pos + #number
            elseif c:match("%s") then
                local space = line:match("^%s+", pos)
                append(tokens, space, "plain")
                pos = pos + #space
            else
                append(tokens, c, "plain")
                pos = pos + 1
            end
        end
    end
    return tokens, state
end

local function tokenize(text, incremental)
    if type(text) ~= "string" or #text > MAX_BYTES then return nil, "size" end
    -- Control bytes need native layout. Reject invalid UTF-8 so no
    -- multibyte character is split between independently rendered tokens.
    if text:find("%z") or text:find("[\1-\8\11-\31\127]") then return nil, "characters" end
    if text:find("[\128-\255]") then
        local at, validated = 1, 0
        while at <= #text do
            local width = utf8Width(text, at)
            if not width then return nil, "characters" end
            at = at + width
            validated = validated + width
            if incremental and validated >= 4096 then validated = 0 coroutine.yield() end
        end
    end
    local lines, state, from, batchBytes, batchLines = {}, nil, 1, 0, 0
    while true do
        if #lines >= MAX_LINES then return nil, "lines" end
        local newline = text:find("\n", from, true)
        local line = newline and text:sub(from, newline - 1) or text:sub(from)
        if incremental and #line > 2048 then return nil, "line_length" end
        local tokens
        tokens, state = scanLine(line, state)
        lines[#lines + 1] = tokens
        if not newline then break end
        from = newline + 1
        batchBytes, batchLines = batchBytes + #line + 1, batchLines + 1
        if incremental and (batchBytes >= 2048 or batchLines >= 24) then
            batchBytes, batchLines = 0, 0
            coroutine.yield()
        end
    end
    return lines
end

function M.Tokenize(text) return tokenize(text, false) end
function M.Start(text) return coroutine.create(function() return tokenize(text, true) end) end
