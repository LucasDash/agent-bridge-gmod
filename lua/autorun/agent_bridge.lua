if SERVER then
    AddCSLuaFile("agent_bridge/shared.lua")
    AddCSLuaFile("agent_bridge/client.lua")
    AddCSLuaFile("agent_bridge/capture.lua")
    AddCSLuaFile("gterm_packages/agent_bridge.lua")
end

include("agent_bridge/shared.lua")
if SERVER then
    include("agent_bridge/chat.lua")
    include("agent_bridge/dash_reality.lua")
else
    include("agent_bridge/client.lua")
end
