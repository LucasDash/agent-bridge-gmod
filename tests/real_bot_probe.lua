-- Disposable test: loads the candidate in a private environment, creates one
-- bot and one prop, and removes only those owned fixtures. Run on an empty lab.
if #player.GetAll() ~= 0 then print('AIM_BOT_PROBE refused: server is occupied') return end
local source = file.Read('agent_bridge_aim_probe/aim.lua', 'DATA')
if not source then print('AIM_BOT_PROBE missing candidate') return end
local fn = CompileString(source, 'agent_bridge_aim_probe', false)
if not isfunction(fn) then print('AIM_BOT_PROBE compile failed: ' .. tostring(fn)) return end
local api = {Schema = 1, Chat = {epoch = 'aim-bot-fixture'}}
function api.Vector(v) return {x = math.Round(v.x, 2), y = math.Round(v.y, 2), z = math.Round(v.z, 2)} end
function api.Text(v, limit) local s = tostring(v or '') return #s > limit and '[overlong]' or s end
setfenv(fn, setmetatable({AgentBridge = api}, {__index = _G}))
fn()
local bot = player.CreateNextBot('agent_bridge_aim_fixture')
if not IsValid(bot) then print('AIM_BOT_PROBE cannot create bot') return end
local prop
timer.Simple(1, function()
    local ok, err = xpcall(function()
        assert(IsValid(bot), 'bot disappeared')
        bot:SetPos(Vector(0, 0, 1000))
        bot:SetMoveType(MOVETYPE_NONE)
        bot:SetEyeAngles(Angle(0, 0, 0))
        local start = bot:GetShootPos()
        local direction = bot:GetAimVector()
        prop = ents.Create('prop_physics')
        assert(IsValid(prop), 'prop creation failed')
        prop:SetModel('models/props_junk/wood_crate001a.mdl')
        prop:SetPos(start + direction * 140)
        prop:Spawn()
        local phys = prop:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        local args = {player_id = bot:EntIndex(), player_creation_id = bot:GetCreationID(), epoch = api.Chat.epoch, distance = 512}
        local direct = util.TraceLine({start = start, endpos = start + direction * args.distance, filter = bot, mask = MASK_SHOT})
        local snapshot = api.InspectPlayerAim(args)
        assert(direct.Hit and direct.Entity == prop, 'fixture prop not hit by native trace')
        assert(snapshot.available and snapshot.kind == 'entity', 'candidate did not report entity hit')
        assert(snapshot.entity.index == prop:EntIndex() and snapshot.entity.creationID == prop:GetCreationID(), 'entity identity differs')
        assert(snapshot.player.index == bot:EntIndex() and snapshot.player.creationID == bot:GetCreationID(), 'player identity differs')
        for _, axis in ipairs({'x', 'y', 'z'}) do
            assert(math.abs(snapshot.hitPosition[axis] - direct.HitPos[axis]) < .02, 'hit position differs')
        end
        args.player_creation_id = args.player_creation_id + 1
        assert(api.InspectPlayerAim(args).reason == 'player_changed', 'stale player identity accepted')
        args.epoch = 'wrong'
        assert(api.InspectPlayerAim(args).reason == 'session_changed', 'stale session accepted')
    end, debug.traceback)
    if IsValid(prop) then prop:Remove() end
    if IsValid(bot) then bot:Kick('Fixture complete') end
    timer.Simple(1, function()
        local clean = not IsValid(bot) and not IsValid(prop)
        local report = {passed = ok and clean, fixturePassed = ok, cleanupPassed = clean, error = not ok and tostring(err) or nil}
        file.Write('agent_bridge_aim_probe/bot_result.json', util.TableToJSON(report))
        print('AIM_BOT_PROBE ' .. util.TableToJSON(report))
    end)
end)
