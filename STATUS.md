# Agent Bridge status

## Player aim snapshot candidate

An isolated development branch adds an on-demand server line trace for an
explicit player, with session epoch and creation-ID checks and a 2048-unit cap.
Offline Lua fixtures exercise input, identity, trace type, scope and manifest
behavior. On 2026-10-29 an isolated fixture compiled and ran in the dedicated
GMod server realm without replacing the loaded addon. A fake player with real
`util.TraceLine` matched a world hit and hit position; a mocked trace exercised
the other cases. A later dedicated-server probe used an actual Player bot and
physics prop: the candidate matched the engine entity trace and identities,
rejected stale player/session identity, and cleaned up both fixtures. This is
not a human-client input test. On 2026-10-29 a human joined a separate
dedicated server. A direct package-function probe matched 240 native traces,
including world and entity hits. After the user granted fresh package consent,
`inspect_player_aim` ran through GTerm MCP and returned the same entity and
rounded hit position as an independently sampled native trace. The tested
entity was `func_reflective_glass`; a human physics-prop/hitbox trace, multiple
human players, other clients and client-only targets remain unverified. It does
not install a continuous hook.

## Optional Dash Reality adapter

The source declares a separate server-side `inspect_dash_entity` tool for the
read-only Dash Reality Development API-1. The adapter checks provider and
snapshot versions and returns a small, validated selection of fields. Its
offline fixture checks the absent, incompatible, failing and valid provider
paths. On 2026-10-28 an isolated 64-bit dedicated Sandbox server loaded both
real addons. A disposable prop returned matching identity and physics data via
the Dash API, adapter and package run function; absent/incompatible provider
and invalid entity paths passed. Deferred prop removal was verified. The package
function was invoked directly from server Lua, not through GTerm MCP. Renewed
package consent and an MCP test subsequently passed in an isolated dedicated
server: a live player returned a snapshot, and an invalid entity returned
`invalid_entity`. Provider-absent, frozen-carrier and multiplayer paths have not
been validated through MCP.

The first version provides seven GTerm package tools for session status,
chat, entity and scene inspection, and offscreen capture.

On 2026-10-28, the addon was loaded in a fresh local single-player Sandbox
session. All seven tools were called through GTerm MCP after package consent;
the capture tool produced a PNG and saved completion report. Chat was received
from the listen host; parsing and capture lifecycle were also checked with
isolated fixtures.

These checks cover the tested local session. Remote and dedicated servers,
multiplayer privacy and access behavior, and sustained load have not yet been
validated. A separate ordinary human chat message was not observed in the final
check. GTerm package discovery requires a reachable client realm; server-side
tools require an appropriate reachable server realm.
