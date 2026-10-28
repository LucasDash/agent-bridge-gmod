# Agent Bridge

One foundational GMod addon for external development agents. GTerm supplies
the MCP transport; Agent Bridge supplies a single opt-in package of game-side
observations and development utilities. Dash Reality owns player-facing game
capabilities. No VJ Base, Starfall, provider key or separate MCP sidecar is
required by this addon.

## Install and use

Install this folder as `garrysmod/addons/agent_bridge` and use one copy.
Retire the former `codex_feedback_bridge`, `codex_feedback_tools`,
`mod_workbench_tools` and `mod_workbench_dev` helper installs. Restart GMod
after checkpointing a live Sandbox world. In GTerm's packages prompt, inspect
and enable `agent_bridge`; consent is managed by GTerm, not this addon.

Use `call_package_tool` with package `agent_bridge`:

| Tool | Realm | Purpose |
| --- | --- | --- |
| `status` | server | Version, map, player/entity counts and chat availability |
| `read_chat` | server | Up to two attributed chat messages with epoch/sequence |
| `inspect_entity` | server | Entity identity, transform, health and physics data |
| `inspect_scene` | client | Up to eight nearby model entities |
| `capture_status` | client | Current capture state and saved artifact path |
| `capture_view` | client | One to eight fixed-eye 1280x720 PNG images |
| `capture_stop` | client | Cancel only the owned capture job |

For example, `status` accepts `{}`, `inspect_entity` accepts `{"id":123}`,
and `capture_view` accepts `{"name":"scene_review_01","count":1}`.
Capture is asynchronous: read `capture_status` until `active=false`, then
check `outcome` and `final_save.saved`. Images and JSON reports are under
`garrysmod/data/agent_bridge/captures/<name>/`. Names must be unique.

Chat starts with server autorun. Ordinary messages are `ambient`; `!agent`
and `!codex` followed by a space identify `direct` messages; either bare tag
also counts as a direct ping and retains its tag as text. Both remain
untrusted player data and never execute commands. Start reading with
`{"after":0,"limit":2}`, then supply `epoch` and the last processed sequence
as `after`. Reset after `epochChanged` or `cursorAhead`; record gaps reported
by `droppedBefore`. The memory-only ring retains at most 64 entries of 512
bytes, rate-limited per player and category. A tag does not grant authority.
An active agent must poll; this addon does not wake an idle Codex chat.

Client package discovery requires GTerm's reachable client realm and mounted
package. Server tools also require the server realm. Those constraints make
the current local single-player target distinct from remote or dedicated
servers; see [status](STATUS.md) for checks actually completed.

## Ownership and development

`AgentBridge` is the sole runtime namespace. Shared helpers describe versioned,
bounded observations; `AgentBridge.Chat` owns one PlayerSay hook and
`AgentBridge.Capture` owns its rendering hooks and cancellation command.
Capture leaves the player's camera and controls available. It excludes the
HUD and held viewmodel and captures a fixed view established at request time.
`AgentBridge.Chat.Stop()` unregisters its chat hook;
`AgentBridge.StopCapture()` stops capture. Source removal takes effect fully
after a fresh process.

The foundation deliberately contains no NPC controller, provider settings,
API credentials, arbitrary-code endpoint or automatic action executor.
Future game actions belong to Dash Reality through explicit, versioned
adapters that report capability and preserve the owner's permissions and
cleanup behavior. GTerm remains responsible for connection, realm checks and
package consent.

This addon consolidates the prior feedback helpers and a small subset of Mod
Workbench's inspection/render lifecycle. Its bounded text/vector/entity
observations rebuild useful AI Citizen patterns under a neutral namespace.
The original NPC/provider implementation and offline Workbench authoring tools
remain historical/development references. Developed with OpenAI Codex
assistance; upstream GTerm remains Earu's separately licensed project.
