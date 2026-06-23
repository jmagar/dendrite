# Repo-Specific Deltas

Several repos intentionally moved beyond the baseline `rmcp-template` shape. Do
not force them back to the template when their local contract is newer. This
reference collects the per-repo deltas across architecture, surface parity,
action dispatch, auth/scopes, and testing. Always confirm against the target
repo's own `CLAUDE.md` and docs.

## Architecture deltas

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

## Surface parity deltas

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

## Action dispatch / schema deltas

Patterns that are stale or too narrow:

- Do not maintain a static `HELP_TEXT` or static action enum when the repo has
  a registry-derived help/schema system.
- Do not assume every action is an enum variant. Rustarr curated commands are
  descriptor rows plus a single `Curated { name, params }` carrier.
- Do not assume every repo's action metadata is root `src/actions.rs`. Cortex
  and Axon use different module ownership.
- Do not hand-maintain separate action lists for schema, scope gates, docs, and
  help. Every reviewed repo has moved toward one registry/contract source.

## Auth / scope deltas

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

## Testing deltas

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
