SERVER = true
function isnumber(x) return type(x) == "number" end
function isstring(x) return type(x) == "string" end
function isbool(x) return type(x) == "boolean" end
function istable(x) return type(x) == "table" end
function isfunction(x) return type(x) == "function" end
local entity = {}
function Entity(id) if id == 42 then return entity end end
function IsValid(value) return value == entity end
game = {GetMap = function() return "test_map" end}
ents = {GetAll = function() return {} end}
player = {GetAll = function() return {} end}
assert(loadstring(shared_source))()
assert(loadstring(adapter_source))()
local inspect = AgentBridge.InspectDashEntity
local status = AgentBridge.Status()
local status_capability
for _, capability in ipairs(status.capabilities) do
    if capability == "inspect_dash_entity" then status_capability = true end
end
assert(status_capability and status.realm == "server")
assert(inspect(42).reason == "provider_unavailable")
DashReality = {Development = {API_VERSION = 2, InspectEntity = function() end}}
assert(inspect(42).reason == "unsupported_api_version")
DashReality.Development.API_VERSION = 1
assert(inspect(2).reason == "invalid_entity")
DashReality.Development.InspectEntity = function() error("provider failure") end
assert(inspect(42).reason == "provider_error_or_invalid_snapshot")
local function snapshot(id)
    return {
        entity = {index = id, creation_id = 9, class = "npc_citizen", model = "models/x.mdl"},
        actor = {player = false, npc = true, nextbot = false, health = 100, max_health = 100},
        frozen_flag = true, time_frozen = true,
        physics = {count = 1, primary = {mass_kg = 8, motion_enabled = false}},
        private = "must not escape",
    }
end
local report = {api_version = 1, realm = "server", selected = snapshot(42), subject = snapshot(43)}
DashReality.Development.InspectEntity = function(received)
    assert(received == entity)
    return report
end
local result = inspect(42)
assert(result.available and result.provider_api_version == 1)
assert(result.selected.entity.index == 42 and result.subject.entity.index == 43)
assert(result.selected.time_frozen and result.subject.actor.npc)
assert(result.selected.private == nil and result.selected.physics.primary.mass_kg == 8)
report.selected.entity.class = string.rep("x", 1000)
report.selected.entity.model = "a\nb"
result = inspect(42)
assert(result.selected.entity.class == "[overlong]" and result.selected.entity.model == "a b")
report.selected.entity.index = 44
assert(inspect(42).reason == "provider_error_or_invalid_snapshot")
report.selected.entity.index = 42
report.subject.physics.primary.mass_kg = 0/0
assert(inspect(42).reason == "provider_error_or_invalid_snapshot")
report.subject = nil
report.selected.physics.count = 0
report.selected.physics.primary = nil
report.selected.entity.model = nil
report.selected.entity.creation_id = -1
result = inspect(42)
assert(result.available and result.subject == nil and result.selected.physics.count == 0
    and result.selected.physics.primary == nil and result.selected.entity.model == nil
    and result.selected.entity.creation_id == -1)
report.realm = "client"
assert(inspect(42).reason == "provider_error_or_invalid_snapshot")
report.realm = "server"
report.api_version = 2
assert(inspect(42).reason == "provider_error_or_invalid_snapshot")
assert(not pcall(inspect, -1) and not pcall(inspect, 1.5) and not pcall(inspect, 65536))
SERVER = false
assert(not pcall(inspect, 42))
SERVER = true
local package = assert(loadstring(package_source))()
local found
for _, tool in ipairs(package.tools) do
    if tool.name == "inspect_dash_entity" then found = tool end
end
assert(found and found.realm == "server" and found.inputSchema.required[1] == "id")
report.api_version = 1
assert(found.run({id = 42}).available)
