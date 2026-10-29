"""Offline Lua 5.1 fixture; run with Python and the optional lupa package."""
from pathlib import Path

from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().shared_source = (root / "lua/agent_bridge/shared.lua").read_text(encoding="utf-8")
lua.globals().adapter_source = (root / "lua/agent_bridge/dash_reality.lua").read_text(encoding="utf-8")
lua.globals().package_source = (root / "lua/gterm_packages/agent_bridge.lua").read_text(encoding="utf-8")
lua.execute((root / "tests/dash_reality_fixture.lua").read_text(encoding="utf-8"))
print("Dash Reality adapter offline fixture passed")
