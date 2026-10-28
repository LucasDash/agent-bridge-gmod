-- Client observations for external development agents. No camera or actor changes.
if not CLIENT then return end
AgentBridge = AgentBridge or {}
local B = AgentBridge

local function number(value, fallback, minimum, maximum)
    if value == nil then value = fallback end
    assert(isnumber(value) and value == value and value >= minimum and value <= maximum,
        "Number outside permitted range")
    return value
end

function B.InspectScene(args)
    args = args or {}
    assert(istable(args), "Arguments must be a table")
    local radius = number(args.radius, 512, 1, 2048)
    local limit = number(args.limit, 8, 1, 8)
    assert(limit == math.floor(limit), "Limit must be an integer")
    local p = LocalPlayer()
    assert(IsValid(p), "Local player unavailable")
    local eye, aim, rows = p:EyePos(), p:GetAimVector(), {}
    for _, e in ipairs(ents.FindInSphere(p:GetPos(), radius)) do
        local model = IsValid(e) and e:GetModel() or nil
        if IsValid(e) and e ~= p and e:GetClass() ~= "viewmodel" and e:GetParent() ~= p and isstring(model) and model ~= "" then
            local delta = e:WorldSpaceCenter() - eye
            rows[#rows + 1] = {
                id = e:EntIndex(), class = B.Text(e:GetClass(), 96),
                model = B.Text(model, 160),
                distance = math.Round(delta:Length(), 1),
                alignment = math.Round(delta:GetNormalized():Dot(aim), 3),
                parent = IsValid(e:GetParent()) and e:GetParent():EntIndex() or nil,
                dormant = e:IsDormant()
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.distance == b.distance then return a.id < b.id end
        return a.distance < b.distance
    end)
    local total = #rows
    while #rows > limit do table.remove(rows) end
    local result = {map = game.GetMap(), realm = "client", total = total, entities = rows}
    while #rows > 0 and #util.TableToJSON(result) > 3500 do
        table.remove(rows)
        result.truncated = true
    end
    return result
end

function B.CaptureStatus()
    if not B.Capture then
        return {available = file.Exists("agent_bridge/capture.lua", "LUA"), loaded = false, active = false}
    end
    local status = B.Capture.Status()
    status.loaded = true
    return status
end

function B.StartCapture(args)
    if not B.Capture then include("agent_bridge/capture.lua") end
    return B.Capture.Start(args)
end

function B.StopCapture()
    if not B.Capture then return {stopped = false, reason = "unavailable"} end
    return B.Capture.Stop("cancelled")
end
