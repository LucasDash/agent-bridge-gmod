-- A server owner must explicitly opt in; no GTerm package permission is implied.
if not SERVER then return end
local enabled = CreateConVar("agent_bridge_lab_policy", "0", FCVAR_ARCHIVE,
    "Apply the restricted Agent Bridge lab player policy on this server.")
local function ordinaryUser(ply)
    if enabled:GetBool() and IsValid(ply) and ply:IsPlayer() and ply:GetUserGroup() ~= "user" then
        ply:SetUserGroup("user")
    end
end
hook.Add("PlayerInitialSpawn", "AgentBridge.LabPolicy.User", ordinaryUser)
hook.Add("PlayerSpawn", "AgentBridge.LabPolicy.User", ordinaryUser)
hook.Add("PlayerLoadout", "AgentBridge.LabPolicy.Loadout", function(ply)
    if not enabled:GetBool() then return end
    ply:StripWeapons()
    ply:RemoveAllAmmo()
    ply:Give("weapon_fists")
    ply:Give("gmod_camera")
    ply:SelectWeapon("weapon_fists")
    return true
end)
for _, event in ipairs({
    "PlayerSpawnProp", "PlayerSpawnRagdoll", "PlayerSpawnEffect", "PlayerSpawnNPC",
    "PlayerSpawnSENT", "PlayerSpawnVehicle", "PlayerSpawnSWEP", "PlayerGiveSWEP",
    "CanTool", "CanProperty"
}) do
    hook.Add(event, "AgentBridge.LabPolicy.Restrict", function()
        if enabled:GetBool() then return false end
    end)
end

hook.Add("PlayerNoClip", "AgentBridge.LabPolicy.NoClip", function(ply, desiredState)
    if not enabled:GetBool() then return end
    if desiredState then
        return false -- Prevent entering noclip.
    end
    return true -- Allow exiting noclip.
end)
