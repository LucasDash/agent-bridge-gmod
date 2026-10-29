-- On-demand, read-only adapter to vFire's entity lookup. No hooks or timers.
local A = AgentBridge
local limit = 8

local function integer(value, min, max)
    return isnumber(value) and value == value and value >= min and value <= max and value == math.floor(value)
end

function A.InspectFire(id, creationID)
    assert(SERVER, "Fire inspection requires the server realm")
    assert(integer(id, 0, 65535), "Invalid entity index")
    assert(integer(creationID, -2147483648, 2147483647), "Invalid creation ID")
    local ent = Entity(id)
    if not IsValid(ent) then return {schema = A.Schema, available = false, reason = "entity_unavailable"} end
    if ent:GetCreationID() ~= creationID then
        return {schema = A.Schema, available = false, reason = "identity_changed"}
    end
    local result = {schema = A.Schema, available = true, id = id, creationID = creationID,
        nativeOnFire = ent:IsOnFire(), vfire = {available = false}}
    if not isfunction(vFireGetFires) then
        result.vfire.reason = "provider_unavailable"
        return result
    end
    local ok, report = pcall(function()
        -- The upstream function constructs an array of all attached fires. We
        -- limit serialization and processing, but cannot bound its allocation.
        local fires = vFireGetFires(ent)
        if not istable(fires) then return {available = false, reason = "provider_incompatible"} end
        local count = #fires
        local items = {}
        for i = 1, math.min(count, limit) do
            local fire = fires[i]
            if not IsValid(fire) or fire:GetClass() ~= "vfire" or not isfunction(fire.GetFireState) then
                return {available = false, reason = "invalid_snapshot"}
            end
            local state, fireID, fireCreation = fire:GetFireState(), fire:EntIndex(), fire:GetCreationID()
            if not integer(state, 1, 7) or not integer(fireID, 0, 65535)
                or not integer(fireCreation, -2147483648, 2147483647) then
                return {available = false, reason = "invalid_snapshot"}
            end
            items[#items + 1] = {id = fireID, creationID = fireCreation, state = state}
        end
        return {available = true, fires = items, truncated = count > limit}
    end)
    result.vfire = ok and report or {available = false, reason = "provider_error"}
    return result
end
