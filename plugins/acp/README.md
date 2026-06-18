# ACP Plugin

Claude Code and Codex plugin providing Rust implementation patterns for the
homelab agent ecosystem, including Agent Client Protocol (ACP) integrations,
rmcp-derived MCP servers, and Lab runtime work.

## What this plugin provides

- **Rust patterns skill** (`skills/rust/SKILL.md`) — triggered for Rust work in Jacob's rmcp-derived MCP servers, Lab runtime code, and ACP agents or clients. Covers service-layer architecture, action-dispatched MCP tools, CLI/MCP/API parity, auth/config contracts, test strategy, and ACP session lifecycle patterns.

- **Reference material** (`skills/rust/references/`) — detailed reference files for wire format, message types, tool calls, Codex production patterns, and unstable feature flags. Intended for use alongside the skill when implementing specific subsystems.

- **Example implementations** (`skills/rust/examples/`) — complete working skeletons for both agent-side and client-side ACP implementations in Rust.

## Quick reference

| File | Purpose |
|---|---|
| `skills/rust/SKILL.md` | Main skill — session lifecycle, streaming, tool calls, checklists |
| `skills/rust/references/wire-format.md` | Full JSON-RPC message examples |
| `skills/rust/references/message-reference.md` | All 24 ACP methods and SessionUpdate variants |
| `skills/rust/references/tool-calls.md` | Tool call streaming patterns and wire format |
| `skills/rust/references/codex-patterns.md` | Production patterns from the codex-acp reference implementation |
| `skills/rust/references/unstable-features.md` | Unstable feature flags and stability tracking |
| `skills/rust/examples/agent-impl.rs` | Complete Agent trait skeleton |
| `skills/rust/examples/client-impl.rs` | Complete Client trait skeleton |

## Key rules

- Use native `async fn in trait` (stable Rust 1.75+) — do not add `async-trait` as a dependency.
- ACP agents run inside `tokio::task::LocalSet` with `flavor = "current_thread"` because the SDK uses `Rc` internally.
- Always use `.compat()` / `.compat_write()` from `tokio_util::compat` — tokio IO types do not implement `futures::AsyncRead/Write` natively.
- Never write to stdout from an agent — it corrupts the binary JSON-RPC stream. Use stderr for logs only.
