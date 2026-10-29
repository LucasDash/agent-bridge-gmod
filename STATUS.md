# Agent Bridge status

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
package consent, actual MCP transport and multi-player checks remain pending.

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
