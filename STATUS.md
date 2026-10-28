# Agent Bridge implementation status

2026-10-28: first consolidated foundation. Seven opt-in GTerm tools cover
session status, chat, entity/scene inspection and bounded offscreen capture.
Source is under `gmod/lua-addons/agent_bridge`; dated evidence and retired
helper copies are under `gmod/staging/agent_bridge_consolidation_20261028`.

All Lua files passed GMod compilation. Explicit live loading preserved the
former chat epoch and entries, then removed its old chat hook. A scoped
server fixture checked the manifest, direct/ambient chat, cursor errors,
epoch recovery, entity inspection and status. Two fixed-view images and their
JSON report completed and passed file readback/size checks. These checks do not
alone establish multiplayer behavior.

A fresh process loaded the addon in both realms with the package mounted.
Old Citizen Agent Lab and feedback globals were absent, and the former
Workbench package was absent from the mounted VFS. Sandbox checkpoint
`gm_construct_remaster 2026-10-28 19-01-41.gms` (2673 bytes) was restored:
player position matched within physics tolerance, 23 physics props remained,
and the single native citizen retained 40 health. This establishes a
representative restore, not an exact continuation of every entity/timer.
The user enabled `agent_bridge` through GTerm's console prompt. All seven
tools then ran successfully through `call_package_tool` in their declared
realms. The MCP capture produced a 1280x720 PNG and a saved completion report;
the image was inspected and showed the expected world view. Clean-start
client fixtures additionally checked lazy initialization, duplicate-name
refusal, cancellation/timeout report saving and removal of owned hooks.
Actual multiplayer and sustained-load behavior remain unverified.

The listen host's real `!agent` message arrived through MCP after the clean
start (sequence 1). It exposed a bare-tag classification edge case; the chat
parser now treats bare `!agent` and `!codex` as direct pings, including mixed
case and surrounding whitespace. A six-case live fixture passed, also
checking ordinary text and similar unrecognized tags, plus blank rejection.
Earlier stored entries retain their original classification. No separate
ordinary human message was observed during this final check.
