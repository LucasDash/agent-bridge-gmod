# Agent Bridge status

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
