-- Optional read-only adapter to Dash Reality's documented Development API-1.
-- Only explicitly selected fields cross the agent boundary. No player command
-- or gameplay action is invoked, and the provider is looked up on each call.
local A = AgentBridge
local function integer(n, min, max)
    return isnumber(n) and n == math.floor(n) and n >= min and n <= max
end

local function finite(n)
    return isnumber(n) and n == n and n > -1000000000 and n < 1000000000
end

local function actor(value)
    assert(istable(value), "invalid actor")
    assert(isbool(value.player) and isbool(value.npc) and isbool(value.nextbot), "invalid actor flags")
    assert(finite(value.health) and finite(value.max_health), "invalid health")
    return {player = value.player, npc = value.npc, nextbot = value.nextbot,
        health = value.health, max_health = value.max_health}
end

local function snapshot(value)
    assert(istable(value) and istable(value.entity), "invalid snapshot")
    local entity = value.entity
    assert(integer(entity.index, 0, 65535) and integer(entity.creation_id, -2147483648, 2147483647), "invalid identity")
    assert(isstring(entity.class), "invalid class")
    assert(entity.model == nil or isstring(entity.model), "invalid model")
    assert(isbool(value.frozen_flag) and isbool(value.time_frozen), "invalid freeze state")
    local result = {
        entity = {index = entity.index, creation_id = entity.creation_id,
            class = A.Text(entity.class, 96), model = entity.model and A.Text(entity.model, 192) or nil},
        actor = actor(value.actor), frozen_flag = value.frozen_flag, time_frozen = value.time_frozen,
    }
    assert(istable(value.physics) and integer(value.physics.count, 0, 65535), "invalid physics")
    result.physics = {count = value.physics.count}
    local body = value.physics.primary
    if body ~= nil then
        assert(istable(body) and finite(body.mass_kg) and body.mass_kg >= 0
            and isbool(body.motion_enabled), "invalid physics body")
        result.physics.primary = {mass_kg = body.mass_kg, motion_enabled = body.motion_enabled}
    end
    return result
end

function A.InspectDashEntity(id)
    assert(SERVER, "Dash Reality inspection requires the server realm")
    assert(integer(id, 0, 65535), "Invalid entity index")
    local base = {schema = A.Schema, available = false, id = id}
    local dev = istable(DashReality) and DashReality.Development or nil
    if not istable(dev) or not isfunction(dev.InspectEntity) then
        base.reason = "provider_unavailable"
        return base
    end
    if dev.API_VERSION ~= 1 then
        base.reason = "unsupported_api_version"
        return base
    end
    local ent = Entity(id)
    if not IsValid(ent) then
        base.reason = "invalid_entity"
        return base
    end
    local ok, result = pcall(function()
        local report = dev.InspectEntity(ent)
        assert(istable(report) and report.api_version == 1 and report.realm == "server", "invalid report")
        local selected = snapshot(report.selected)
        assert(selected.entity.index == id, "wrong entity")
        return {schema = A.Schema, available = true, id = id, provider_api_version = 1,
            selected = selected, subject = report.subject ~= nil and snapshot(report.subject) or nil}
    end)
    if not ok then
        base.reason = "provider_error_or_invalid_snapshot"
        return base
    end
    return result
end
