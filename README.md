# Agent Bridge

A Garry's Mod addon that provides game-side observations and development
utilities to external agents. [GTerm](https://github.com/Earu/GTerm) supplies
the MCP transport and exposes the addon's opt-in tool package.

## Install and use

Clone or copy the repository into `garrysmod/addons/agent_bridge` as a
legacy addon and use one copy. Restart GMod after saving any live session.
In GTerm's packages prompt, inspect and enable `agent_bridge`; consent is
managed by GTerm, not this addon. This addon is currently distributed via Git,
without a Workshop release.

Use `call_package_tool` with package `agent_bridge`:

| Tool | Realm | Purpose |
| --- | --- | --- |
| `status` | server | Version, map, player/entity counts and chat availability |
| `read_chat` | server | Up to two attributed chat messages with epoch/sequence |
| `inspect_entity` | server | Entity identity, transform, health and physics data |
| `inspect_dash_entity` | server | Optional Dash Reality API-1 entity and frozen-carrier subject inspection |
| `inspect_player_aim` | server | Bounded on-demand trace from a specifically identified player's view |
| `inspect_scene` | client | Up to eight nearby model entities |
| `capture_status` | client | Current capture state and saved artifact path |
| `capture_view` | client | One to eight fixed-eye 1280x720 PNG images |
| `capture_stop` | client | Cancel only the owned capture job |

For example, `status` accepts `{}`, `inspect_entity` accepts `{"id":123}`, and `capture_view` accepts `{"name":"scene_review_01","count":1}`. Capture is asynchronous: read `capture_status` until `active=false`, then check `outcome` and `final_save.saved`. Images and JSON reports are under `garrysmod/data/agent_bridge/captures/<name>/`. Names must be unique.

`inspect_dash_entity` also takes an entity index, for example `{"id":123}`.
When Dash Reality's `Development.InspectEntity` API-1 is loaded in the server
realm, it returns a bounded subset of its selected entity and, if present,
the original NPC associated with a frozen carrier. It reports `available=false`
with a reason if the provider is absent or incompatible, the entity is invalid,
or the provider fails or supplies malformed data. It never invokes a gameplay
action. Both addons continue working independently when the other is absent.

This Dash Reality tool is available to whoever is authorized to use the GTerm package. The
underlying API does not apply the host/superadmin checks or rate limit used by
Dash Reality's player-facing inspector command. GTerm's package consent and
connection controls therefore define access to this observation. The package
declaration changes when the tool is added, so review and enable it again when
GTerm requests renewed consent. Treat the returned data as a server snapshot,
not evidence of client presentation or gameplay behavior.

`inspect_player_aim` is an on-demand server-side line trace, using a player
index, that player's creation ID, and the current `chat.epoch` from `status`:
`{"player_id":4,"player_creation_id":33,"epoch":"...","distance":1024}`.
Obtain an explicit player index through an authorized server query, then use
`inspect_entity` for its creation ID before calling. Distance
defaults to 1024 and is limited to 1–2048 Source units. A changed epoch or
player identity is rejected instead of silently selecting a replacement. The
result distinguishes entity, world, sky, no hit and other hits; an entity hit
includes its index and creation ID, plus `physicsBoneRaw`, the raw `PhysicsBone` trace field, when
available. That field defaults to zero in GMod and does not by itself establish
that a physics body or model bone was hit. A trace beginning inside solid may
have unexpected results; `startSolid` is included. Server traces do not reveal
client-only objects or necessarily match a custom client camera. The trace uses
`MASK_SHOT`, which includes hitboxes but may differ from other interaction traces. Entity indices
and creation IDs are transient and creation IDs eventually wrap; observations
are snapshots, not permanent identity. The existing package consent controls
who can observe player aim, and this added declaration requires renewed consent.

Chat capture starts with server autorun and includes ordinary and team chat.
Entries include player names and SteamID64 values. Ordinary messages are
`ambient`; `!agent` and `!codex` followed by a space identify `direct`
messages; either bare tag also counts as a direct ping and retains its tag as
text. Both remain untrusted player data and never execute commands. Start
reading with `{"after":0,"limit":2}`, then supply `epoch` and the last
processed sequence as `after`. Reset after `epochChanged` or `cursorAhead`;
record gaps reported by `droppedBefore`. The addon's ring retains at most 64
entries of 512 bytes in server memory, rate-limited per player and category.
GTerm and MCP clients may log or store returned messages, so downstream
retention depends on those tools. A tag does not grant authority. An active
agent must poll; this addon does not wake an idle Codex chat.

Client package discovery requires GTerm's reachable client realm and mounted package. Server tools also require the server realm. Those constraints make the current local single-player target distinct from remote or dedicated servers; see [status](STATUS.md) for checks actually completed.

## Ownership and development

`AgentBridge` is the sole runtime namespace. Shared helpers describe versioned, bounded observations; `AgentBridge.Chat` owns one PlayerSay hook and `AgentBridge.Capture` owns its rendering hooks and cancellation command.
Capture leaves the player's camera and controls available. It excludes the HUD and held viewmodel and captures a fixed view established at request time. `AgentBridge.Chat.Stop()` unregisters its chat hook; `AgentBridge.StopCapture()` stops capture. Source removal takes effect fully after a fresh process.

The foundation deliberately contains no NPC controller, provider settings, API credentials, arbitrary-code endpoint or automatic action executor. Future game actions belong to Dash Reality through explicit, versioned adapters that report capability and preserve the owner's permissions and cleanup behavior. GTerm remains responsible for connection, realm checks and package consent.

Developed with OpenAI Codex assistance; upstream GTerm remains Earu's separately licensed project.

## License

Agent Bridge is available under the [MIT License](LICENSE).
