AgentBridge = AgentBridge or {}
local A = AgentBridge
A.Version = 1
A.Schema = 1

-- Bounded serialization patterns rebuilt from AI Citizen's observation helpers.
function A.Text(value, maxBytes)
    local text = tostring(value or ""):gsub("[%c]", " ")
    if #text > maxBytes then return "[overlong]" end
    return text
end

function A.Vector(value)
    return {x = math.Round(value.x, 2), y = math.Round(value.y, 2), z = math.Round(value.z, 2)}
end

function A.Status()
    local result = {schema = A.Schema, version = A.Version,
        realm = SERVER and "server" or "client", map = game.GetMap(),
        time = os.time(), capabilities = SERVER and {"status", "read_chat", "inspect_entity", "inspect_dash_entity"}
            or {"inspect_scene", "capture_status", "capture_view", "capture_stop"}}
    if SERVER then
        result.entityCount = #ents.GetAll()
        result.playerCount = #player.GetAll()
        result.chat = A.Chat and A.Chat.Status() or {available = false}
    end
    return result
end

function A.InspectEntity(id)
    assert(SERVER, "Entity inspection requires the server realm")
    assert(isnumber(id) and id == math.floor(id) and id >= 0 and id <= 65535, "Invalid entity index")
    local ent = Entity(id)
    if not IsValid(ent) then return {schema = A.Schema, available = false, id = id} end
    local parent = ent:GetParent()
    local phys = ent:GetPhysicsObject()
    return {schema = A.Schema, available = true, id = id, creationID = ent:GetCreationID(),
        class = A.Text(ent:GetClass(), 96), model = A.Text(ent:GetModel(), 192),
        position = A.Vector(ent:GetPos()), velocity = A.Vector(ent:GetVelocity()),
        health = ent:Health(), isPlayer = ent:IsPlayer(), isNPC = ent:IsNPC(),
        parent = IsValid(parent) and parent:EntIndex() or nil,
        physics = IsValid(phys) and {mass = phys:GetMass(), motionEnabled = phys:IsMotionEnabled()} or nil}
end
