SERVER = true
function isnumber(x) return type(x) == "number" end
function isstring(x) return type(x) == "string" end
function istable(x) return type(x) == "table" end
math.Round = function(v) return v end
local vector = {}
vector.__index = vector
vector.__add = function(a, b) return setmetatable({x = a.x+b.x, y = a.y+b.y, z = a.z+b.z}, vector) end
vector.__mul = function(a, b) return setmetatable({x = a.x*b, y = a.y*b, z = a.z*b}, vector) end
local function vec(x,y,z) return setmetatable({x=x,y=y,z=z}, vector) end
local ply = {id=4, creation=33}
function ply:IsPlayer() return true end
function ply:EntIndex() return self.id end
function ply:GetCreationID() return self.creation end
function ply:GetShootPos() return vec(1,2,3) end
function ply:GetAimVector() return vec(1,0,0) end
local target = {}
function target:IsPlayer() return false end
function target:EntIndex() return 19 end
function target:GetCreationID() return 90 end
function target:GetClass() return "prop_physics" end
function target:GetModel() return "models/can.mdl" end
function Entity(id) if id == 4 then return ply elseif id == 19 then return target end end
function IsValid(ent) return ent == ply or ent == target end
game = {GetMap=function() return "test_map" end}
ents = {GetAll=function() return {} end}
player = {GetAll=function() return {ply} end}
function CurTime() return 123 end
MASK_SHOT = 99
local result = {Hit=true, HitWorld=false, HitSky=false, StartSolid=false,
    HitPos=vec(100,2,3), HitNormal=vec(-1,0,0), Entity=target, PhysicsBone=3}
local count, received = 0
util = {TraceLine=function(args) count=count+1; received=args; return result end}
assert(loadstring(shared_source))()
AgentBridge.Chat = {epoch="session-A"}
assert(loadstring(aim_source))()
local args = {player_id=4, player_creation_id=33, epoch="session-A"}
local inspect = AgentBridge.InspectPlayerAim
local hit = inspect(args)
assert(hit.available and hit.kind == "entity" and hit.physicsBoneRaw == 3)
assert(hit.player.index == 4 and hit.player.creationID == 33 and hit.epoch == "session-A")
assert(hit.entity.index == 19 and hit.entity.creationID == 90 and hit.entity.class == "prop_physics")
assert(received.filter == ply and received.mask == MASK_SHOT and received.endpos.x == 1025 and hit.distance == 1024)
args.distance = 12.5
assert(inspect(args).distance == 12.5 and received.endpos.x == 13.5)
result.HitWorld = true
hit = inspect(args); assert(hit.kind == "world" and hit.entity == nil and hit.physicsBoneRaw == nil)
result.HitSky = true
hit = inspect(args); assert(hit.kind == "sky" and hit.entity == nil)
result.Hit = false
hit = inspect(args); assert(hit.kind == "none" and not hit.hit and hit.entity == nil)
result.Hit, result.HitWorld, result.HitSky, result.Entity = true, false, false, nil
hit = inspect(args); assert(hit.kind == "other" and hit.entity == nil)
result.Entity, result.PhysicsBone, result.StartSolid = target, -1, true
hit = inspect(args); assert(hit.kind == "entity" and hit.physicsBoneRaw == nil and hit.startSolid)
local before = count
args.epoch = "old-session"; assert(inspect(args).reason == "session_changed")
args.epoch = "session-A"; args.player_creation_id = 32; assert(inspect(args).reason == "player_changed")
args.player_creation_id = 33; args.player_id = 19; assert(inspect(args).reason == "invalid_player")
args.player_id = 4; AgentBridge.Chat = nil; assert(inspect(args).reason == "session_unavailable")
assert(count == before)
AgentBridge.Chat = {epoch="session-A"}
local savedResult = result
result = nil; assert(inspect(args).reason == "trace_unavailable"); result = savedResult
for _, bad in ipairs({0, 2049, 0/0, math.huge}) do args.distance = bad; assert(not pcall(inspect, args)) end
args.distance = nil
args.player_id = 0; assert(not pcall(inspect,args)); args.player_id = 4
args.player_creation_id = 1.5; assert(not pcall(inspect,args)); args.player_creation_id = 33
args.epoch = ""; assert(not pcall(inspect,args)); args.epoch = "session-A"
SERVER = false; assert(not pcall(inspect,args)); SERVER = true
local package = assert(loadstring(package_source))()
local found
for _, tool in ipairs(package.tools) do if tool.name == "inspect_player_aim" then found = tool end end
assert(found and found.realm == "server" and #found.inputSchema.required == 3)
assert(found.run(args).available)
