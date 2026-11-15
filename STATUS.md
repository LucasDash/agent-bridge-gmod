# Agent Bridge status

## gPeek-based native workspace candidate

On 2026-11-14 the owner selected a native editor and requested a unified
viewing/editing pane. Agent Bridge now provides an **Agent Editor** spawn-menu
tab hosting a private gPeek browser instance. Its Lua extension is replaced
per instance; no shared gPeek control is patched, and derived text previews
retain the original viewer. Edits are session drafts or separately saved DATA
copies. There is no execution or direct write-back. Noir was examined for
feature inspiration; its source is not included.

Lua 5.1 and LuaJIT fixtures cover source bounds, LF/CRLF handling, write errors,
file switching, source conflicts, concurrent views, the session-draft limit,
and preservation when a widget cannot represent a source. The owner tested a
Veejay Lua file, confirmed navigation and saving, and the saved DATA bytes
matched the session draft. The owner confirmed that the newer font and dark
controls improved readability.

The first candidate was copied into the existing loose Agent Bridge checkout
after checking its clean `bbd05c64` base; the original loader and docs are in
`gmod/staging/gpeek-noir-review/live-before/`. After a fresh GMod process and
map load, `CreateBrowser` came from the installed addon, the Agent Editor tab
was registered, and a hidden real-client panel passed open, edit, switch and
restore checks while preserving gPeek's original text viewer. The user's
previously saved DATA copy remains on disk.

On 2026-11-15 a subsequent syntax-coloring candidate was tested in an isolated
real-client panel. It retains native text input, selection and caret; verified
screenshots showed aligned colors, selected text and accented characters. A
pixel comparison of the underlying font established the native text origin and
row spacing; the adjusted gutter needs a real scrolling check. The lexer covers
GLua keywords, strings, long strings and comments and has Lua 5.1/LuaJIT tests.
That initial coloring candidate falls back to native text for tabs, wrapped
layouts, unsupported or invalid bytes, over 32 KiB, over 2,000 lines, or any line over 2 KiB. Work is
debounced and sliced over frames; in one live 27.9 KiB fixture, the largest of
38 parsing slices took 1.36 ms (not a general performance guarantee). Human
typing and scrolling with the colored candidate, clean startup of that revision,
non-local clients and wider addon compatibility remain to be tested. Changes
were not committed or published at that stage.

The syntax candidate was subsequently installed with the prior files backed
up under `gmod/staging/gpeek-noir-review/live-before-syntax/`. The running
client loaded the installed `gpeek_workspace.lua` and `lua_highlighter.lua`
(`62e595b2...` and `da3ba08d...`). Its existing workspace was refreshed only
after its open file was confirmed unmodified and identical to the resolved
source; its text and caret were restored. A separate hidden panel using the
installed code passed open, syntax generation, edit invalidation, recoloring,
file switching and draft restoration. Actual human typing and scrolling with
this revision and a fresh startup remain validation gates.

On 2026-11-15 the next candidate added a bounded visual-line layout calibrated
against a native text control. In an isolated running Windows GMod client,
Dash Reality's `autorun/dash_reality.lua` reached syntax colors with 171 native
and modeled visual rows (143 source lines), and Veejay's 96,251-byte normalized
`traversal.lua` reached colors with 1,757 matching visual rows (1,710 source
lines). Captures of the native and colored panes showed aligned glyphs for
wrapped text and a tabbed fixture. Across 210 generated ASCII cases and another
210 cases including tabs, modeled and native row counts agreed. Lua 5.1 and
LuaJIT fixtures cover line continuations, simulated scrolling, draft behavior,
and cancellation of stale highlighting. The maximum highlighted source is now
128 KiB and 8,000 lines; tabs are supported on the tested Windows path.
Unwrapped UTF-8 remains supported, while wrapped UTF-8, unsupported layouts and
other declared limits retain native plain rendering. One isolated parsing
benchmark of traversal took 20.85 ms across 72 coroutine resumes, with a worst
single resume of 3.82 ms; it is not a general frame-time guarantee. Actual
human scrolling, fresh startup, other operating systems and broader addon
coverage still need testing. This remains a development candidate.

The wrapped-layout candidate was then installed into the same loose development
addon after verifying the prior hashes. Backups are in
`gmod/staging/gpeek-noir-review/live-before-wrap/`. The actual installed Lua
modules subsequently opened and highlighted Veejay's traversal source in an
isolated live client panel, with matching native and modeled row counts and an
unchanged input value. The open Dash Reality view was refreshed only after its
text matched the source and it was not being edited; the text and caret were
restored. Human scrolling and a fresh start of this revision remain unverified.

## Optional gWater2 observation candidate

An on-demand client-only tool reports the local gWater2 solver's active particle
count and capacity. The addon does not load or modify gWater2, poll the solver,
scan particle positions or infer contact with fire. A Lua 5.1 fixture covered
missing, incompatible and failing providers and invalid counters. On 2026-10-29
the adapter and package run function were invoked directly in a real connected
client, returning 64 active particles and a capacity of 100,000. They were
temporarily loaded in memory and the prior global function was restored. The
new declaration has not been approved or called through GTerm MCP; other client
configurations and fresh startup remain unverified. Counts are per-client and
are not authoritative server-side water state.

## Optional vFire inspection candidate

An on-demand server tool reports the engine fire flag and a bounded list of
flames attached to a specifically identified entity through vFire's existing
lookup. A Lua 5.1 fixture covered invalid and stale identifiers, absent,
failing and incompatible providers, invalid snapshots, native fire state and
the eight-entry output limit. On 2026-10-29 an isolated dedicated server loaded
the real vFire addon: seven checks passed for provider availability, package
declaration, an empty target, one attached flame, identity rejection and flame
removal. The package run function was invoked directly from server Lua. After
the owner approved the changed package in a separate isolated GTerm instance,
an MCP call returned a real attached vFire entity and a stale identity was
rejected. The disposable fire and prop were removed. Multiplayer behavior,
visual fire and a fresh main-server startup remain unverified. vFire's lookup
allocates its full attached-fire list before the adapter can limit processing.
The candidate was then hot-loaded into the main server without restarting the
game. After separate main-GTerm package approval, an MCP call on the connected
player returned the native flag and an empty attached-fire list; the session's
chat epoch and retained entries were unchanged. An attached fire was not
created on the main server for this check.

## Optional NikNaks metadata candidate

An isolated source candidate adds a lazily initialized, bounded current-map
BSP metadata tool backed by a separate NikNaks installation. The provider is
not bundled. Twenty-one LuaJIT fixture checks cover the package declaration,
lazy loading, absent and failing providers, invalid snapshots and realm guard.
On 2026-10-29 a separate dedicated server mounted NikNaks 0.96 alongside the
development addon collection. The adapter and package declaration did not load
NikNaks until the tool was invoked. The package run function then returned
current `gm_construct` BSP metadata matching NikNaks. After the owner approved
the updated package in a separately scoped GTerm instance, the same tool ran
through MCP on the isolated dedicated server and returned map name, BSP
version 20, revision 1765 and file size 36,735,656 bytes. The candidate was
then deployed to the main dedicated server without restarting the game. The
owner separately approved its updated GTerm package there, and an actual MCP
call returned the same metadata while the existing chat epoch and messages
remained intact. Other maps and a fresh main-server startup remain unverified.
Map metadata is not evidence of routes or visibility.

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
