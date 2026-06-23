---
name: rust
version: "1.1.0"
description: >-
  Scoped to Jacob's homelab Rust repos — the rmcp MCP-server family (rustifi, rustify, rustscale, unrust, rarcane, rustarr, apprise-mcp, cortex, synapse2, rmcp-template) and the Lab runtime/ACP work. Use when editing those repos: covers rmcp-template-derived server patterns, action-dispatched MCP tools, CLI/MCP/API parity, service-layer architecture, config/auth/scope contracts, testing strategy, release/build conventions, and ACP runtime/provider work. Not a general-purpose Rust skill.
---

# Rust Patterns

Use this skill for Rust work in the homelab agent ecosystem. The default pattern
source is the sibling workspace repo `../rmcp-template` when it exists relative
to the target repo's workspace root; treat that repo as the canonical reference
for MCP server architecture unless the target repo documents a newer local rule.

## First Step

Identify the repo family before editing:

- `rmcp-template` derived MCP server: `rustifi`, `rustify`, `rustscale`, `unrust`, `rarcane`, `rustarr`, `apprise-mcp`, `cortex`, `synapse2`, and new servers cloned from `rmcp-template`.
- Lab platform/runtime: `lab`, including Labby gateway, dispatch, marketplace, auth, UI, and snippets.
- ACP work: `crates/lab/src/acp`, `codex-acp`, Zed/VS Code providers, or Agent Client Protocol stdio integration.
- Other Rust repo: follow the repo-local `CLAUDE.md`, `docs/`, `Justfile`, and existing module style first.

Before changing shared behavior, read the nearest source-of-truth docs:

```bash
RMCP_TEMPLATE="${RMCP_TEMPLATE:-$(cd .. && pwd)/rmcp-template}"
sed -n '1,220p' "$RMCP_TEMPLATE/docs/PATTERNS.md"
sed -n '1,220p' "$RMCP_TEMPLATE/docs/RUST.md"
sed -n '1,220p' "$RMCP_TEMPLATE/docs/TESTING.md"
sed -n '1,220p' "$RMCP_TEMPLATE/docs/AUTH.md"
```

Then check the target repo's `CLAUDE.md` and current docs for evolved local
patterns. Several repos intentionally moved beyond the baseline template; do
not force them back to the template shape when their local contract is newer.

For ACP-specific work, also read this skill's ACP references:

- `references/wire-format.md`
- `references/message-reference.md`
- `references/tool-calls.md`
- `references/unstable-features.md`
- `references/codex-patterns.md`
- `examples/agent-impl.rs`
- `examples/client-impl.rs`

## rmcp Server Architecture

The rmcp family uses one service facade and thin surfaces. Keep business logic out of transports.

Canonical layout:

```text
src/
  <service>.rs        # upstream HTTP/API transport only
  app/                # business logic, validation, defaults, safety gates
  actions.rs          # action names, scopes, transport availability, param parsing
  config.rs           # Config structs, env overrides, dotenv loading
  api.rs or api/      # REST handlers, thin over app/service
  server.rs           # AppState, AuthPolicy, auth layer construction
  server/routes.rs    # axum router and mounted auth/public routes
  mcp.rs              # MCP module entry and re-exports only
  mcp/tools.rs        # parse args -> call service -> return Value
  mcp/schemas.rs      # single-tool schema, ACTION_SPECS-backed action enum
  mcp/rmcp_server.rs  # ServerHandler, resources, prompts, scope enforcement
  cli.rs              # parse CLI -> call service -> format output
  main.rs             # mode dispatch only
```

Hard rule: if you are writing business logic in `mcp/tools.rs`, `api.rs`, `cli.rs`, or `main.rs`, move it into `app/`. Shims may extract typed inputs, call `state.service.*`, and format/return the result. They should not own defaults, retries, destructive gates, domain decisions, or custom error wording.

### Repo-specific architecture deltas

Several repos diverge from the baseline (Lab's `dispatch/<service>/` layer, rustarr's descriptor-driven curated commands, cortex's `src/mcp/actions.rs` registry with `Cost` metadata, axon's typed direct REST product API). Full per-repo architecture deltas — plus parity, action-dispatch, auth, and testing deltas — are in `references/repo-deltas.md`. Check that reference (and the target repo's own docs) before assuming the template shape applies.

## Surface Parity

Business actions must have MCP + CLI parity. Application/platform servers usually also expose REST/API and web UI; upstream-client MCP servers usually do not need a local REST API unless they own state or workflows.

Allowed exceptions:

- MCP-only protocol features such as elicitation, where there is no honest CLI equivalent.
- CLI-only operational modes such as `serve`, `mcp`, `doctor`, `watch`, and `setup`.

For a new or changed action, update all relevant surfaces in one pass:

- `src/actions.rs`: `ACTION_SPECS`, scopes, transport availability, parser enum.
- `src/app/`: service method and validation/defaults/safety gate.
- `src/mcp/tools.rs`: thin dispatch branch.
- `src/mcp/schemas.rs`: one-tool schema and conditional requirements.
- `src/cli.rs`: CLI command or flags.
- REST/API docs and OpenAPI if the repo exposes REST.
- Skill/plugin docs and `help` output.
- Tests for parser, service behavior, schema drift, CLI, and MCP dispatch.

Do not assume parity means the same shape in every repo (Lab dotted `<resource>.<verb>` names, rustarr's split MCP/CLI grammars, axon's REST-deferred local commands, cortex's CLI-only lifecycle mutations) — see "Surface parity deltas" in `references/repo-deltas.md`.

## Action Dispatch And Schemas

The rmcp pattern is one MCP tool per server with an `action` string, not one MCP tool per endpoint. The schema rejects unknown top-level parameters except reserved response continuation fields.

Use `ACTION_SPECS` in `src/actions.rs` as the source of truth for:

- valid action names
- required read/write scopes
- MCP-only vs REST-available transport
- `help` being public
- deny-by-default behavior for unknown actions

Expected action parsing pattern:

```rust
let action = ExampleAction::from_mcp_args(&args)?;
match action {
    ExampleAction::Help => Ok(json!({ "help": HELP_TEXT })),
    other => execute_service_action(&state.service, &other).await,
}
```

Do not duplicate action strings in unrelated docs without a check. Template repos use contract checks such as `cargo xtask contract-audit`, schema-doc sync scripts, or `just template-check` to catch drift.

Patterns that are stale or too narrow (don't keep static `HELP_TEXT`/action enums when a registry exists, don't assume every action is an enum variant or that metadata lives in root `src/actions.rs`, don't hand-maintain parallel action lists) — see "Action dispatch / schema deltas" in `references/repo-deltas.md`.

## Auth And Scopes

Use the `AuthPolicy` model from `rmcp-template`:

- `LoopbackDev`: loopback or stdio trust boundary; no auth/scope checks.
- `TrustedGatewayUnscoped`: upstream gateway enforces auth; local server does not.
- `Mounted { auth_state: None }`: static bearer token.
- `Mounted { auth_state: Some(_) }`: OAuth plus optional static bearer token.

Non-loopback HTTP servers must refuse to start without authentication unless the deployment explicitly sets the trusted-gateway override. Public endpoints such as `/health`, `/status`, and `/openapi.json` stay unauthenticated and must redact secrets.

Scope rules belong in `actions.rs` and are enforced in the MCP/REST auth paths. Write scope can satisfy read scope where the repo's `scopes_satisfy()` says so. Unknown actions should map to a deny scope, not accidentally fall through as public.

Repo-specific auth deltas (Lab's `ActionSpec.destructive` confirmation model, rustarr's `confirm_required`/`mutates`, cortex's `cortex:read`/`cortex:admin` split and forced `/api/*` bearer, axon's full-access scope and LoopbackDev admin guard) — see "Auth / scope deltas" in `references/repo-deltas.md`.

## Config And Secrets

Keep secrets in `.env` or plugin-generated private config files. Keep non-secret settings in `config.toml`.

Common split:

- `.env`: API keys, bearer tokens, service URLs, OAuth client secrets, Docker runtime env, `RUST_LOG`.
- `config.toml`: bind host/port, server name, OAuth mode, public URL, allowed origins, retention and resource settings.

`main.rs` should load dotenv before config and then dispatch modes only:

```rust
config::load_dotenv();
runtime::init_logging(stdio_mode, serve_mode);
match mode { serve => serve_http_mcp().await, stdio => serve_stdio_mcp().await, cli => run_cli().await }
```

Do not commit real credentials. Do not print tokens in test output, docs examples, or error messages.

## Testing Pattern

Default verification should prove behavior below the network layer first, then exercise MCP transport when needed.

Use these tiers:

- Service and parser tests: action parsing, validation, defaults, destructive gates.
- Contract/mock tests: outbound HTTP method/path/query/header/body against a local mock upstream.
- Schema/static checks: action docs, MCP schema, README/help text, plugin contracts.
- Live mcporter smoke: read-only MCP calls against a running server.

Preferred commands depend on the repo, but the common set is:

```bash
cargo check --all-targets --all-features
cargo nextest run
cargo test
cargo xtask contract-audit
just test-ci
bash tests/mcporter/test-mcp.sh
```

Use sidecar test files (`src/foo_tests.rs`) when tests need private items:

```rust
#[cfg(test)]
#[path = "foo_tests.rs"]
mod tests;
```

Live tests must assert semantic fields, not just `is_error: false`. Never include destructive, notification-sending, delete, update, or authorization-mutating actions in default live smoke tests unless the target is disposable and explicitly gated by env.

Repo-specific checks to look for (Lab architecture/catalog lints, rustarr `tests/parity.rs`, axon `http_api_parity_inventory` + OpenAPI checks, cortex `scripts/smoke-test.sh` + `/api/*` auth invariants) — see "Testing deltas" in `references/repo-deltas.md`.

## Build And Release Conventions

Builds rely on host-level Cargo config (`~/.cargo/config.toml`) — `mold`/`clang`, sccache via `sccache-wrapper`, conservative global `jobs = 4` for concurrent agents, LLVM (not Cranelift) dev backend. Keep per-repo `.cargo/config.toml` minimal; don't shadow global mold flags. For solo builds override with `CARGO_BUILD_JOBS=16`; use the `release-fast` profile for portable local/CI builds and full `release` for published artifacts. Full baseline `config.toml`, sccache-wrapper rationale, profile definitions, and warm-rebuild benchmarking are in `references/build-release.md`.

## ACP Work

For ACP-specific Rust work, keep the existing ACP rules:

- Agents speak JSON-RPC 2.0 over stdio; stdout/stdin are protocol, stderr is logs only.
- Lab acts as ACP client when spawning providers such as `codex-acp`.
- Use `Client.builder()`, `ByteStreams`, `.compat()`/`.compat_write()`, and `attach_session()` in the runtime.
- Session-scoped requests use `send_request_to(Agent, ...)`; protocol-level initialize uses `send_request(...)`.
- Read `config_options` before `attach_session()` consumes the `NewSessionResponse`.
- In ACP SDK `0.13.x`, provider implementations use `#[async_trait::async_trait(?Send)]` for the `Agent` trait.

When ACP behavior changes, update the ACP reference docs in this skill and verify against the SDK/codex-acp source, not memory.

## Review Checklist

Before finishing Rust work, check:

- Business logic is in `app/`, not transports.
- New actions have MCP + CLI parity or a documented exception.
- `ACTION_SPECS`, schemas, help text, docs, and tests agree.
- Auth startup guards still block unsafe non-loopback no-auth binds.
- Scope checks deny unknown actions and keep `help` public only by design.
- Config examples keep secrets out of committed files.
- Tests include the narrow behavior touched and any cross-surface contract impacted.
- Live verification, when run, is read-only or explicitly disposable.
