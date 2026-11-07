-- On-demand server interface checks. A missing API is not proof that an addon
-- is uninstalled, and a detected API is not a player-permission decision.
local A = AgentBridge

local function checkProvider(value, predicate)
    if value == nil then return {state = "unavailable", reason = "not_detected"} end
    if type(value) ~= "table" then return {state = "unknown", reason = "unexpected_provider_type"} end
    local ok, ready = pcall(predicate, value)
    if not ok then return {state = "unknown", reason = "provider_error"} end
    if ready then return {state = "available"} end
    return {state = "unknown", reason = "interface_incomplete"}
end

local function motdMode(ulxStatus)
    if ulxStatus.state ~= "available" or type(GetConVar) ~= "function" then return "unknown" end
    local ok, mode = pcall(function()
        local cv = GetConVar("ulx_showMotd")
        if not cv or type(cv.GetInt) ~= "function" then return nil end
        local value = cv:GetInt()
        return ({[0] = "off", [1] = "file", [2] = "generator", [3] = "url"})[value]
    end)
    return ok and mode or "unknown"
end

local function sessionStatus()
    local provider = AgentSessionProfiles
    if provider == nil then return {state = "unknown", reason = "provider_not_detected"} end
    if type(provider) ~= "table" then return {state = "unknown", reason = "unexpected_provider_type"} end
    local ok, report = pcall(function()
        if type(provider.GetStatus) ~= "function" then return nil end
        return provider.GetStatus()
    end)
    if not ok or type(report) ~= "table" then return {state = "unknown", reason = "invalid_provider_status"} end
    local id = rawget(report, "active")
    if type(id) ~= "string" or #id < 1 or #id > 48 or not id:match("^[a-z0-9_-]+$") then
        return {state = "unknown", reason = "invalid_provider_status"}
    end
    local status = {state = "available", active = id}
    local kills = rawget(report, "npcKills")
    if kills ~= nil then
        if type(kills) ~= "number" or kills ~= kills or kills < 0 or kills > 2147483647 or kills ~= math.floor(kills) then
            return {state = "unknown", reason = "invalid_provider_status"}
        end
        status.npcKills = kills
    end
    local observerReady = rawget(report, "observerReady")
    if observerReady ~= nil then
        if type(observerReady) ~= "boolean" then return {state = "unknown", reason = "invalid_provider_status"} end
        status.observerReady = observerReady
    end
    local experimentReady = rawget(report, "experimentReady")
    if experimentReady ~= nil then
        if type(experimentReady) ~= "boolean" then return {state = "unknown", reason = "invalid_provider_status"} end
        status.experimentReady = experimentReady
    end
    return status
end

function A.InspectServerCapabilities()
    assert(SERVER, "Server capability inspection requires the server realm")
    local ulxStatus = checkProvider(ulx, function(p)
        return type(p.command) == "function" and type(p.convar) == "function"
    end)
    return {
        schema = 1,
        providers = {
            ulx = ulxStatus,
            ulib = checkProvider(ULib, function(p)
                return type(p.ucl) == "table" and type(p.ucl.query) == "function"
            end),
            cami = checkProvider(CAMI, function(p)
                return type(p.PlayerHasAccess) == "function" and type(p.RegisterPrivilege) == "function"
            end),
            dash_reality = checkProvider(DashReality, function(p)
                return type(p.Development) == "table" and p.Development.API_VERSION == 1
                    and type(p.Development.InspectEntity) == "function"
            end),
        },
        ulx_motd_mode = motdMode(ulxStatus),
        session_profile = sessionStatus(),
    }
end
