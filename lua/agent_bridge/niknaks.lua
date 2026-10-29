-- Optional on-demand metadata adapter. Never loads NikNaks during addon startup.
local A = AgentBridge

local function numberInRange(value, min, max, integer)
    return isnumber(value) and value == value and value >= min and value <= max
        and (not integer or value == math.floor(value))
end

function A.InspectMapMetadata()
    assert(SERVER, "Map metadata inspection requires the server realm")
    local result = {schema = A.Schema, available = false}

    -- Include the lookup and method calls in the protected boundary: providers
    -- may be absent, partially initialized, incompatible, or throw errors.
    local ok, report = pcall(function()
        local provider = NikNaks
        if provider == nil then
            if not file.Exists('includes/modules/niknaks.lua', 'LUA') then
                return {schema = A.Schema, available = false, reason = 'provider_unavailable'}
            end
            local loaded = pcall(require, 'niknaks')
            if not loaded then
                return {schema = A.Schema, available = false, reason = 'provider_load_failed'}
            end
            -- GMod's require can return nil even on success; use its global API.
            provider = NikNaks
        end
        if not istable(provider) or not numberInRange(provider.VERSION, 0, 100000, false)
            or not istable(provider.CurrentMap) then
            return {schema = A.Schema, available = false, reason = 'provider_incompatible'}
        end
        local map = provider.CurrentMap
        if not isfunction(map.GetMapName) or not isfunction(map.GetVersion)
            or not isfunction(map.GetSize) or not isfunction(map.GetMapRevision) then
            return {schema = A.Schema, available = false, reason = 'provider_incompatible'}
        end
        local name, version, size, revision = map:GetMapName(), map:GetVersion(), map:GetSize(), map:GetMapRevision()
        if not isstring(name) or #name < 1 or #name > 128 or name:find('[%c]')
            or name ~= game.GetMap() or not numberInRange(version, 0, 32767, true)
            or not numberInRange(size, 0, 9007199254740991, true)
            or not numberInRange(revision, -2147483648, 2147483647, true) then
            return {schema = A.Schema, available = false, reason = 'invalid_snapshot'}
        end
        return {schema = A.Schema, available = true, provider = 'NikNaks', provider_version = provider.VERSION,
            map = {name = name, bsp_version = version, size_bytes = size, revision = revision}}
    end)
    if not ok then result.reason = 'provider_error' return result end
    return report
end
