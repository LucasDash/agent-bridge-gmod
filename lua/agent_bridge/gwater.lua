-- The gWater solver is client-owned. This module performs no network or gameplay actions.
if not CLIENT then return end
local A = AgentBridge

local function count(value)
    return isnumber(value) and value == value and value >= 0 and value <= 2147483647
        and value == math.floor(value)
end

function A.InspectGWater()
    local unavailable = {schema = A.Schema, available = false, realm = "client"}
    local ok, snapshot = pcall(function()
        if not istable(gwater2) or gwater2.solver == nil then
            return {schema = A.Schema, available = false, realm = "client", reason = "provider_unavailable"}
        end
        local solver = gwater2.solver
        if not isfunction(solver.GetActiveParticles) or not isfunction(solver.GetMaxParticles) then
            return {schema = A.Schema, available = false, realm = "client", reason = "provider_incompatible"}
        end
        local active, capacity = solver:GetActiveParticles(), solver:GetMaxParticles()
        if not count(active) or not count(capacity) or active > capacity then
            return {schema = A.Schema, available = false, realm = "client", reason = "invalid_snapshot"}
        end
        return {schema = A.Schema, available = true, realm = "client", provider = "gWater2",
            activeParticles = active, maxParticles = capacity}
    end)
    if not ok then unavailable.reason = "provider_error" return unavailable end
    return snapshot
end
