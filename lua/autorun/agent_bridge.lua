if SERVER then
    AddCSLuaFile("agent_bridge/shared.lua")
    AddCSLuaFile("agent_bridge/client.lua")
    AddCSLuaFile("agent_bridge/capture.lua")
    AddCSLuaFile("agent_bridge/gwater.lua")
    AddCSLuaFile("agent_bridge/source_editor.lua")
    AddCSLuaFile("agent_bridge/lua_highlighter.lua")
    AddCSLuaFile("agent_bridge/text_layout.lua")
    AddCSLuaFile("agent_bridge/gpeek_workspace.lua")
    AddCSLuaFile("gterm_packages/agent_bridge.lua")
end

include("agent_bridge/shared.lua")
if SERVER then
    include("agent_bridge/chat.lua")
    include("agent_bridge/dash_reality.lua")
    include("agent_bridge/aim.lua")
    include("agent_bridge/niknaks.lua")
    include("agent_bridge/vfire.lua")
else
    include("agent_bridge/client.lua")
    include("agent_bridge/gwater.lua")
    include("agent_bridge/source_editor.lua")
    include("agent_bridge/lua_highlighter.lua")
    include("agent_bridge/text_layout.lua")
    include("agent_bridge/gpeek_workspace.lua")
end
