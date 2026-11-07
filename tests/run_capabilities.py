from pathlib import Path
from lupa import lua51, luajit21

root = Path(__file__).resolve().parents[1]
for name, engine in (("Lua 5.1", lua51), ("LuaJIT", luajit21)):
    lua = engine.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().shared_source = (root / "lua/agent_bridge/shared.lua").read_text(encoding="utf-8")
    lua.globals().capabilities_source = (root / "lua/agent_bridge/capabilities.lua").read_text(encoding="utf-8")
    lua.globals().package_source = (root / "lua/gterm_packages/agent_bridge.lua").read_text(encoding="utf-8")
    print(name, flush=True)
    lua.execute((root / "tests/capabilities.lua").read_text(encoding="utf-8"))
