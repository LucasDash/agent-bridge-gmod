-- On-demand observation only. A player and a map-session epoch are explicit;
-- creation ID is a best-effort check against a replacement, not a permanent ID.
local A = AgentBridge

local function integer(value, minimum, maximum)
    return isnumber(value) and value == math.floor(value) and value >= minimum and value <= maximum
end

function A.InspectPlayerAim(args)
    assert(SERVER, "Aim inspection requires the server realm")
    assert(istable(args), "Invalid aim arguments")
    assert(integer(args.player_id, 1, 65535), "Invalid player index")
    assert(integer(args.player_creation_id, -2147483648, 2147483647), "Invalid player creation ID")
    assert(isstring(args.epoch) and #args.epoch > 0 and #args.epoch <= 128, "Invalid session epoch")
    local distance = args.distance == nil and 1024 or args.distance
    assert(isnumber(distance) and distance == distance and distance >= 1 and distance <= 2048, "Invalid trace distance")

    local result = {schema = A.Schema, available = false, map = game.GetMap(),
        epoch = A.Chat and A.Chat.epoch or nil, player_id = args.player_id}
    if not result.epoch then result.reason = "session_unavailable" return result end
    if result.epoch ~= args.epoch then result.reason = "session_changed" return result end
    local ply = Entity(args.player_id)
    if not IsValid(ply) or not ply:IsPlayer() then result.reason = "invalid_player" return result end
    if ply:GetCreationID() ~= args.player_creation_id then result.reason = "player_changed" return result end

    local start = ply:GetShootPos()
    local trace = util.TraceLine({start = start, endpos = start + ply:GetAimVector() * distance,
        filter = ply, mask = MASK_SHOT})
    if not trace then result.reason = "trace_unavailable" return result end
    result.available = true
    result.time = CurTime()
    result.player = {index = ply:EntIndex(), creationID = ply:GetCreationID()}
    result.distance = distance
    result.start = A.Vector(start)
    result.hit = trace.Hit == true
    result.startSolid = trace.StartSolid == true
    result.hitPosition = A.Vector(trace.HitPos)
    result.hitNormal = A.Vector(trace.HitNormal)
    if not trace.Hit then
        result.kind = "none"
    elseif trace.HitSky then
        result.kind = "sky"
    elseif trace.HitWorld then
        result.kind = "world"
    elseif IsValid(trace.Entity) then
        result.kind = "entity"
        result.entity = {index = trace.Entity:EntIndex(), creationID = trace.Entity:GetCreationID(),
            class = A.Text(trace.Entity:GetClass(), 96), model = A.Text(trace.Entity:GetModel(), 192)}
        if integer(trace.PhysicsBone, 0, 65535) then result.physicsBoneRaw = trace.PhysicsBone end
    else
        result.kind = "other"
    end
    return result
end
