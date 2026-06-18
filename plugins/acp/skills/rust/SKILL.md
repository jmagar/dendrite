---
name: rust
version: "1.1.0"
description: >-
  Use when working on Rust code in Jacob's repos, especially the rmcp MCP server family and Lab runtime. Covers rmcp-template derived server patterns, action-dispatched MCP tools, CLI/MCP/API parity, service-layer architecture, config/auth/scope contracts, testing strategy, release/build conventions, and ACP runtime/provider work.
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

`lab` is not a normal rmcp clone. It uses `crates/lab/src/dispatch/<service>/`
as the surface-neutral semantic layer between CLI, MCP, API, web, and
`lab-apis`. Migrated services are directory-first from day one:

```text
crates/lab/src/dispatch/<service>.rs
crates/lab/src/dispatch/<service>/catalog.rs
crates/lab/src/dispatch/<service>/client.rs
crates/lab/src/dispatch/<service>/params.rs
crates/lab/src/dispatch/<service>/dispatch.rs
```

In Lab, `catalog.rs` owns `ActionSpec` / `ParamSpec`; `client.rs` owns env,
instance, auth, and client construction; `params.rs` owns coercion; and
`dispatch.rs` owns action routing and help payloads. `node`, `security`,
`upstream`, `gateway/code_mode`, and `snippets` have documented layout
exceptions. Do not cite those shared subsystems as precedent for skipping
`client.rs` or `params.rs` in a normal upstream-backed service.

`rustarr` is descriptor-driven for most domain actions. The generic
`ACTION_SPECS` set is intentionally small; curated media commands live as
`CommandDescriptor` const slices under `src/actions/commands/<cap>.rs`, then
flow through `curated_commands()`, schema generation, help text, CLI usage, and
the shared `execute_service_action` path. Do not add a giant enum variant and
match arm for every curated action.

`cortex` keeps the MCP action registry under `src/mcp/actions.rs`, not root
`src/actions.rs`, and its action metadata includes `Scope`, `Cost`, and an
`ActionHandler`. That cost metadata is part of agent planning and help/schema
behavior, so preserve it when adding actions.

`axon` is an application/platform server whose direct REST API is now the
canonical product API. Its `/v1/actions` action-envelope endpoint has been
removed. Use typed direct routes, `services::client_contract::*`, OpenAPI
generation, and `docs/reference/api-parity.md` when changing API-facing
behavior.

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

Do not assume parity means the same shape in every repo:

- Lab service actions use dotted `<resource>.<verb>` names, with built-in
  `help` and `schema` actions and `lab://<service>/actions` catalog resources.
  Historical bare aliases may exist only as deprecated aliases; new actions must
  be dotted.
- Rustarr's MCP grammar is one tool with global snake_case action names, while
  its CLI grammar is service-grouped (`rustarr <service> <verb>`). The
  bidirectional parity guard lives in `tests/parity.rs`.
- Axon tracks CLI/MCP/direct-REST parity in `docs/reference/api-parity.md`.
  Some local commands (`setup`, `config`, `mcp`, `serve`, `monitor`, `smoke`,
  etc.) are intentionally deferred from remote REST.
- Cortex explicitly keeps lifecycle mutations CLI-only while the MCP surface
  stays query/admin-action oriented.

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

Patterns that are stale or too narrow:

- Do not maintain a static `HELP_TEXT` or static action enum when the repo has
  a registry-derived help/schema system.
- Do not assume every action is an enum variant. Rustarr curated commands are
  descriptor rows plus a single `Curated { name, params }` carrier.
- Do not assume every repo's action metadata is root `src/actions.rs`. Cortex
  and Axon use different module ownership.
- Do not hand-maintain separate action lists for schema, scope gates, docs, and
  help. Every reviewed repo has moved toward one registry/contract source.

## Auth And Scopes

Use the `AuthPolicy` model from `rmcp-template`:

- `LoopbackDev`: loopback or stdio trust boundary; no auth/scope checks.
- `TrustedGatewayUnscoped`: upstream gateway enforces auth; local server does not.
- `Mounted { auth_state: None }`: static bearer token.
- `Mounted { auth_state: Some(_) }`: OAuth plus optional static bearer token.

Non-loopback HTTP servers must refuse to start without authentication unless the deployment explicitly sets the trusted-gateway override. Public endpoints such as `/health`, `/status`, and `/openapi.json` stay unauthenticated and must redact secrets.

Scope rules belong in `actions.rs` and are enforced in the MCP/REST auth paths. Write scope can satisfy read scope where the repo's `scopes_satisfy()` says so. Unknown actions should map to a deny scope, not accidentally fall through as public.

Repo-specific auth deltas:

- Lab uses `ActionSpec.destructive` as the central dangerous-operation flag.
  MCP confirms destructive calls through elicitation, CLI requires `-y` /
  `--yes`, and HTTP callers use an explicit confirmation parameter. New Lab
  code should not invent a second confirmation policy.
- Rustarr uses read/write scopes, but curated commands also carry
  `confirm_required` and `mutates`; `mutates=true` implies
  `confirm_required=true` and is mechanically tested.
- Cortex has `cortex:read` plus `cortex:admin`, not just read/write. Static
  bearer tokens are read-only unless `CORTEX_STATIC_TOKEN_ADMIN=true`.
- Cortex's `/api/*` router forces mounted bearer auth even when the listener
  would otherwise be `LoopbackDev`; do not treat LoopbackDev as a universal REST
  bypass there.
- Axon has read/write/full-access scopes and protects destructive admin REST
  routes with an unconditional guard even in LoopbackDev. Write routes may be
  blocked in local no-auth mode instead of allowed through.

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

Repo-specific checks to look for:

- Lab: architecture/catalog lints, generated action catalog checks, and
  service-layout tests in `crates/lab/tests/architecture_orchestrator.rs`.
- Rustarr: `tests/parity.rs` for curated command MCP/CLI coverage and
  `mutates => confirm_required`.
- Axon: `cargo test --test http_api_parity_inventory -- --nocapture`,
  OpenAPI export/checks, and route-contract tests from
  `services::client_contract`.
- Cortex: `scripts/smoke-test.sh` and mcporter tests for all MCP actions, plus
  API auth invariants for forced `/api/*` bearer behavior.

## Build And Release Conventions

The rmcp family assumes host-level Cargo config for fast local builds. Do not add repo-local linker settings unless the repo has a documented exception.

Important conventions from `rmcp-template/docs/RUST.md`:

- Rust stable tracks the family MSRV/current stable policy.
- `mold`/`clang`, sccache, global job limits, and dev profile tuning live in `~/.cargo/config.toml`.
- Per-repo `.cargo/config.toml` is minimal: xtask alias and target-specific fallback only.
- Do not add `[target.x86_64-unknown-linux-gnu].rustflags` in repo config if it would shadow global mold flags.
- Windows release/cross-compile settings must avoid machine-specific `target-cpu=native`.

Current global Cargo baseline on Jacob's machines:

```toml
[build]
# Keep conservative for multiple concurrent agents. Solo builds can override.
jobs = 4
rustc-wrapper = "/home/jmagar/.local/bin/sccache-wrapper"

[env]
CARGO_PROFILE_DEV_CODEGEN_BACKEND = "llvm"
SCCACHE_SERVER_UDS = "/tmp/sccache-jmagar.sock"

[unstable]
codegen-backend = true

[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[profile.dev]
debug = 1
codegen-units = 8
split-debuginfo = "unpacked"
incremental = false
opt-level = 0

[profile.test]
debug = 1
codegen-units = 8

[profile.dev.package."*"]
opt-level = 1
```

Interpretation:

- `rustc -> clang -> mold`: `clang` is the linker driver; `-fuse-ld=mold`
  chooses the fast linker backend. Prefer this over `linker = "mold"`.
- Global `jobs = 4` is intentional for many simultaneous agent builds. For a
  solo local build on the current 20-logical-CPU host, override per command:

  ```bash
  CARGO_BUILD_JOBS=16 cargo build --release --locked --bin <name>
  CARGO_BUILD_JOBS=16 cargo build --profile release-fast --locked --bin <name>
  ```

- Do not make `jobs = 16` global unless the machine is dedicated to one build at
  a time.
- Cranelift is not the current default. The config keeps
  `CARGO_PROFILE_DEV_CODEGEN_BACKEND=llvm` because Cranelift-backed dev/test
  links have failed in aws-lc-backed binaries in this environment. Consider
  Cranelift only as a repo-specific experiment after verifying `cargo check`,
  `cargo test`, and any native TLS/aws-lc/ring paths.
- sccache is enabled through `/home/jmagar/.local/bin/sccache-wrapper`, not by
  pointing Cargo directly at `sccache`. The wrapper bypasses clippy, resolves
  rustup toolchain paths to stable version-pinned paths for sccache-dist safety,
  exports `SCCACHE_SERVER_UDS=/tmp/sccache-jmagar.sock`, and then execs the
  mise-pinned `/home/jmagar/.local/sccache`.
- Some repos add a repo-local rustc wrapper for project-specific side effects.
  Axon's `.cargo/config.toml` points at `scripts/cargo-rustc-wrapper`, which
  delegates to sccache and copies completed `axon` binaries into local PATH.
  Keep that kind of install-copy behavior repo-local or explicitly opt-in; do
  not make it global for all Rust projects without a collision policy.

Use a repo-local fast release profile when the command should be portable across
CI, containers, and clean hosts. Example:

```toml
[profile.release-fast]
inherits = "release"
lto = false
codegen-units = 16
```

This keeps `opt-level = 3` from `release`, but skips whole-program ThinLTO and
lets the final crate codegen run with more parallelism. It is appropriate for
local deployable binaries and smoke testing. Keep full `release` for published
artifacts, benchmark-sensitive builds, and size-sensitive binaries.

Benchmark profile changes with warm rebuilds, not the first build of a new
profile:

```bash
touch src/main.rs
time CARGO_BUILD_JOBS=16 cargo build --profile release-fast --locked --bin <name>
touch src/main.rs
time CARGO_BUILD_JOBS=16 cargo build --release --locked --bin <name>
```

Release workflows attach built artifacts to GitHub Releases. Do not commit generated binaries or release tarballs back to `main`.

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
