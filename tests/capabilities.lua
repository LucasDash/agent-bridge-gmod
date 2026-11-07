-- Offline contract fixture: provider names and profile status are untrusted.
SERVER = true
AgentBridge = {Version = 1}
local checks = 0
local function check(name, ok)
    checks = checks + 1
    assert(ok, name)
end
assert(loadstring(capabilities_source))()
local package = assert(loadstring(package_source))()
local tool, status
for _, item in ipairs(package.tools) do
    if item.name == "inspect_server_capabilities" then tool = item end
    if item.name == "status" then status = item end
end
check("new tool is server-only and has no inputs", tool and tool.realm == "server"
    and tool.inputSchema.additionalProperties == false and tool.inputSchema.properties == nil)
check("original status declaration is preserved", status and status.realm == "server")
local result = tool.run()
check("schema and absent ULX", result.schema == 1 and result.providers.ulx.state == "unavailable")
check("absent ULib", result.providers.ulib.state == "unavailable")
check("absent CAMI", result.providers.cami.state == "unavailable")
check("absent Dash Reality", result.providers.dash_reality.state == "unavailable")
check("absent session is unknown", result.session_profile.state == "unknown" and result.session_profile.active == nil)
check("absent ULX mode unknown", result.ulx_motd_mode == "unknown")
GetConVar = function() error("must not inspect a cvar before ULX exists") end
check("absent ULX does not query cvars", tool.run().ulx_motd_mode == "unknown")

ulx = {}; ULib = {}; CAMI = {}; DashReality = {}
result = tool.run()
for _, name in ipairs({"ulx", "ulib", "cami", "dash_reality"}) do
    check(name .. " incomplete is unknown", result.providers[name].state == "unknown")
end
ULib = false
check("unexpected provider type is unknown", tool.run().providers.ulib.state == "unknown")
ULib = setmetatable({}, {__index = function() error("bad provider") end})
check("provider failure is isolated", tool.run().providers.ulib.reason == "provider_error")

local noop = function() end
ulx = {command = noop, convar = noop}
ULib = {ucl = {query = noop}}
CAMI = {PlayerHasAccess = noop, RegisterPrivilege = noop}
DashReality = {Development = {API_VERSION = 1, InspectEntity = noop}}
local selectedMode = 0
GetConVar = function(name)
    assert(name == "ulx_showMotd")
    return {GetInt = function() return selectedMode end}
end
result = tool.run()
for _, name in ipairs({"ulx", "ulib", "cami", "dash_reality"}) do
    check(name .. " interface detected", result.providers[name].state == "available")
end
for mode, expected in pairs({[0] = "off", [1] = "file", [2] = "generator", [3] = "url"}) do
    selectedMode = mode
    check("MOTD mode " .. mode, tool.run().ulx_motd_mode == expected)
end
selectedMode = 4
check("unrecognized mode is unknown", tool.run().ulx_motd_mode == "unknown")
GetConVar = function() error("cvar failure") end
check("cvar failure is unknown", tool.run().ulx_motd_mode == "unknown")
DashReality.Development.API_VERSION = 2
check("unsupported Dash API is unknown", tool.run().providers.dash_reality.state == "unknown")

AgentSessionProfiles = {GetStatus = function() return {active = "none", secret = "do not expose"} end}
result = tool.run()
check("explicit no active profile", result.session_profile.state == "available" and result.session_profile.active == "none")
check("unrelated provider fields are not copied", result.session_profile.secret == nil)
AgentSessionProfiles.GetStatus = function() return {active = "gordon_01"} end
result = tool.run().session_profile
check("valid profile identifier", result.active == "gordon_01")
check("optional session fields can be absent", result.npcKills == nil and result.observerReady == nil and result.experimentReady == nil)
AgentSessionProfiles.GetStatus = function() return {active = "test", npcKills = 0, observerReady = false, experimentReady = false} end
result = tool.run().session_profile
check("zero kills and false readiness states preserved", result.state == "available" and result.npcKills == 0 and result.observerReady == false and result.experimentReady == false)
AgentSessionProfiles.GetStatus = function() return {active = "test", npcKills = 2147483647, observerReady = true, experimentReady = true} end
result = tool.run().session_profile
check("maximum kills and true readiness states preserved", result.state == "available" and result.npcKills == 2147483647 and result.observerReady == true and result.experimentReady == true)
for _, bad in ipairs({-1, 0.5, 2147483648, math.huge, -math.huge, 0/0, "2", false}) do
    AgentSessionProfiles.GetStatus = function() return {active = "test", npcKills = bad} end
    result = tool.run().session_profile
    check("invalid kill count is rejected", result.state == "unknown" and result.active == nil)
end
for _, bad in ipairs({0, 1, "false", {}}) do
    AgentSessionProfiles.GetStatus = function() return {active = "test", observerReady = bad} end
    result = tool.run().session_profile
    check("invalid observer state is rejected", result.state == "unknown" and result.active == nil)
    AgentSessionProfiles.GetStatus = function() return {active = "test", experimentReady = bad} end
    result = tool.run().session_profile
    check("invalid experiment state is rejected", result.state == "unknown" and result.active == nil)
end
AgentSessionProfiles.GetStatus = function() return {active = string.rep("x", 48)} end
check("maximum-length profile identifier", #tool.run().session_profile.active == 48)
for _, bad in ipairs({"", "../profile", "Contains Space", string.rep("x", 49)}) do
    AgentSessionProfiles.GetStatus = function() return {active = bad} end
    check("invalid profile is unknown", tool.run().session_profile.state == "unknown")
end
AgentSessionProfiles.GetStatus = function() return setmetatable({}, {__index = function() error("bad result") end}) end
check("hostile result metatable is ignored", tool.run().session_profile.state == "unknown")
AgentSessionProfiles.GetStatus = function() error("profile failure") end
check("failed profile provider is unknown", tool.run().session_profile.state == "unknown")
AgentSessionProfiles = 42
check("invalid profile provider type is unknown", tool.run().session_profile.state == "unknown")
AgentSessionProfiles = {}
check("profile provider without GetStatus is unknown", tool.run().session_profile.state == "unknown")
AgentSessionProfiles.GetStatus = function() return {active = "valid"} end
SERVER = false
check("client realm rejected", not pcall(tool.run))
print("SERVER_CAPABILITIES_CHECKS " .. checks)
