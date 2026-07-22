# Interfaces and contracts

This repo doesn't expose a network API — its "interfaces" are CLI contracts
(this repo's own scripts) and a config-file contract (against Hermes's
schema). Documented separately since they have different stability
guarantees: this repo's own CLI contract is fully controlled and testable;
the Hermes config schema is external and partly unconfirmed (see
`docs/open-questions.md`).

## `install.sh` (this repo's primary interface)

```
./install.sh [--profile <on-prem|cloud-server|usb-offline>] [--update] [--skip-autostart]
```

Five steps as of ADR-0012 (was four): `00-install-prereqs.sh` runs first,
before Ollama, to guarantee `curl`/`git`/`python3`/pip exist even on a
minimal fresh Ubuntu install.

| Flag | Default | Effect |
|---|---|---|
| `--profile <name>` | `on-prem` | Selects `overlay/config-profiles/<name>.yaml`. Fails with a listing of valid profiles if the file doesn't exist. |
| `--update` | off | Skips OS-level setup (steps 1 and 4); runs `hermes update` then re-applies the profile. Assumes a prior full install already happened. |
| `--skip-autostart` | off | Skips step 4 (systemd registration). Intended for USB image builds (autostart configured differently there) or manual/dev testing. |
| `-h`, `--help` | — | Prints usage, exits 0. |

**Exit codes**: 0 on success, 1 on unknown profile or unknown argument.
Individual sub-scripts use `set -euo pipefail`, so any failure inside a
sub-script propagates as a non-zero exit from `install.sh` itself (no
explicit error handling/recovery across steps — a failure partway through
leaves the machine in whatever partial state the completed steps produced;
idempotency, per `CLAUDE.md`, is what makes re-running safe rather than any
transactional rollback).

**Environment variables read** (not CLI flags, but part of the contract):

| Variable | Default | Read by |
|---|---|---|
| `HPA_LOCAL_MODEL` | `qwen2.5:14b` | `01-install-ollama.sh` |
| `HPA_OLLAMA_CONTEXT_LENGTH` | `65536` | `01-install-ollama.sh` |
| `HPA_PROFILE` | (set by `install.sh`) | exported for sub-scripts, informational |
| `HPA_PROFILE_FILE` | (set by `install.sh`) | `03-apply-profile.sh` |
| `HPA_OVERLAY_DIR` | (set by `install.sh`) | `03-apply-profile.sh` |

Example: `HPA_LOCAL_MODEL=qwen2.5:7b ./install.sh --profile usb-offline`.

## Sub-script contracts (`overlay/install/*.sh`)

Each is designed to also be runnable standalone for debugging, though
`install.sh` is the supported entrypoint.

- **`01-install-ollama.sh`**: no args. Reads `HPA_LOCAL_MODEL`,
  `HPA_OLLAMA_CONTEXT_LENGTH`. Idempotent: checks `command -v ollama` before
  installing. Side effects: installs Ollama via its official installer,
  writes `/etc/systemd/system/ollama.service.d/override.conf`, enables and
  restarts `ollama.service`, pulls a model. Requires `sudo` (for the
  systemd operations) on Linux; on non-systemd hosts (macOS) it prints a
  warning and continues without enabling any service.
- **`02-install-hermes.sh`**: optional `--update` positional flag. No env
  var inputs. Idempotent: checks `command -v hermes` before installing (in
  non-update mode). Side effect: runs upstream's curl installer, or
  `hermes update`.
- **`03-apply-profile.sh`**: no args, requires `HPA_OVERLAY_DIR` and
  `HPA_PROFILE_FILE` env vars to be set (asserts with `: "${VAR:?...}"`,
  fails loudly if missing — this is why it's not meant to be run truly
  standalone without `install.sh` having set those first, or being set
  manually). Side effects: writes `~/.hermes/config.yaml`, backs up any
  existing file as `config.yaml.bak.<timestamp>`.
- **`04-enable-autostart.sh`**: no args. Requires `hermes` CLI and
  `systemctl` to be present; exits early (code 0) with a warning if
  `systemctl` is absent (non-systemd host), exits 1 if `hermes` is missing.
  Side effects: `sudo hermes gateway install --system`, writes
  `/etc/systemd/system/hermes-gateway.service.d/override.conf`, enables and
  restarts `hermes-gateway.service`.

## Hermes Agent's own interfaces (external, this repo configures against them)

This repo does not define these — they belong to upstream Hermes and are
documented here only so a future Claude instance knows what surface this
repo is targeting and doesn't need to re-derive it from scratch.

### `hermes` CLI (selected commands used by this repo or its docs)

| Command | Used by | Purpose |
|---|---|---|
| `hermes` | operator, manually | Interactive chat session |
| `hermes model` | operator, manually (not scripted) | Full provider setup wizard — OAuth, API keys, custom endpoints |
| `/model <provider>:<model>` | operator, manually, inside a session | Quick switch between already-configured providers |
| `hermes update` | `02-install-hermes.sh --update` | Pulls upstream updates |
| `hermes gateway setup` | operator, manually (not yet scripted) | Interactive messaging platform config wizard |
| `hermes gateway install --system` | `04-enable-autostart.sh` | Registers system-level systemd service |
| `hermes gateway start` / `stop` / `status` | operator, manually | Service management |
| `hermes tools` | not used yet | Enable Nous Portal Tool Gateway — not applicable, Nous Portal is excluded (ADR-0005) |

### `config.yaml` schema (as documented upstream; **partially unconfirmed**, see `docs/data-model.md` and `docs/open-questions.md`)

Top-level keys this repo writes or expects:

- `model:` — `provider`, `base_url`, `default` (or `model`, both keys work
  per upstream docs). **This repo uses `provider: "custom"` with a
  `base_url` for local Ollama** — confirmed as a documented pattern
  (`/model custom:qwen-2.5` syntax appears in upstream docs), but the exact
  shape of `default.yaml`'s `model:` block has not been validated against a
  real `hermes model` wizard-generated file.
- `custom_providers:` — list of `{name, base_url, key_env, api_mode}` for
  named custom endpoints. Documented upstream; not currently used in this
  repo's profiles (local Ollama is configured directly under `model:`
  rather than as a named `custom_providers` entry) — **this may itself be
  wrong**; see `docs/open-questions.md`.
- `fallback_providers:` — list of `{provider, model}` for automatic
  failover. **Deliberately absent from every file in this repo.** Do not
  add.
- `gateway:` — **placeholder key structure** (`platforms: [...]`) used in
  this repo's profile YAMLs; not confirmed against actual
  `hermes gateway setup` output.
- `auxiliary.*.provider` — controls routing for vision/summarization/MoA
  sub-tasks; defaults to `"auto"` (routes to main chat model) per upstream
  docs. Not currently overridden anywhere in this repo.

### Input/output contract for the agent itself

Out of scope for this repo to define — Hermes's own agent loop, tool
schemas, and skill format (`SKILL.md`, agentskills.io standard) are
upstream's contract, not this repo's. This repo's job ends at "produce a
correct `~/.hermes/config.yaml` and running services"; what Hermes does at
runtime with that config is upstream's responsibility.

## Error handling

- This repo's scripts favor **fail-fast** (`set -euo pipefail`) over
  partial-success/retry logic. No script currently implements retries.
- `03-apply-profile.sh` is the only script with explicit
  defensive/recovery behavior (config backup before overwrite) — this
  pattern should be extended to other destructive operations if any are
  added later.
- No centralized logging exists — all output goes to stdout/stderr,
  captured however the operator chooses to capture it (terminal, or
  `journalctl` once services are running).

## Authentication requirements

- **GitHub**: none stored; see ADR-0010 for the one-time PAT precedent if
  push access is needed again.
- **Cloud LLM providers**: credentials expected in `~/.hermes/.env`,
  populated manually by the operator (not automated by 