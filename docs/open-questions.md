# Open questions

Everything in this document is an assumption made during design that has
**not** been confirmed against a real, running Hermes instance. Resolve
these during Phase 1 (`docs/implementation-plan.md`) and move each item to
"Resolved" with the answer once confirmed — don't delete the question, keep
the record of what was uncertain and what turned out to be true.

## Unresolved

### 1. Exact `model:` / `custom_providers:` schema for local Ollama

`overlay/config-profiles/default.yaml` currently sets:

```yaml
model:
  provider: "custom"
  base_url: "http://localhost:11434/v1"
  default: "qwen2.5:14b"
```

This is based on documentation references to a `/model custom:qwen-2.5`
switch syntax and a general description of the "Custom Endpoint flow," not
a confirmed `hermes model`-generated file. It's also unclear whether local
Ollama should instead be defined as a named entry under a top-level
`custom_providers:` list (which upstream docs show for *other* custom
endpoints, e.g. a corporate GPU server) rather than inline under `model:`.
**Action**: run `hermes model` interactively, choose the custom-endpoint
path pointed at `http://localhost:11434/v1`, and diff the resulting
`~/.hermes/config.yaml` against this file.

### 2. Exact `gateway.platforms` schema

`overlay/config-profiles/on-prem.yaml`, `cloud-server.yaml`, and
`usb-offline.yaml` all use:

```yaml
gateway:
  platforms: ["telegram", "cli"]
```

This key name and structure is a placeholder invented to express intent
("which messaging platforms should this profile enable"), not sourced from
a confirmed upstream schema reference. **Action**: run `hermes gateway
setup` interactively and inspect the resulting config structure.

### 3. Docker↔Ollama networking mechanism

`overlay/docker/docker-compose.override.yml` sets an
`HPA_OLLAMA_BASE_URL` environment variable on the `hermes-agent` service,
guessing that Hermes reads an env var to override its default provider
base URL inside a container. The alternative — mounting a `config.yaml`
into the container with the right `base_url` already set — was not ruled
out, just not chosen, pending an actual test. **Action**: bring up the
compose file and observe whether the env var has any effect; if not, switch
to a config-mount approach.

### 4. Ollama systemd unit name assumption

`overlay/install/04-enable-autostart.sh` assumes Ollama's official
installer creates a systemd unit literally named `ollama.service` (used in
the `After=`/`Requires=` drop-in for `hermes-gateway.service`). This is the
standard/documented name for Ollama's official Linux installer, but was not
independently re-verified by inspecting a real install. **Action**: after
running `01-install-ollama.sh`, confirm with `systemctl status ollama` (or
`systemctl list-units | grep ollama`) that the unit name matches exactly.

### 5. Upstream Hermes installer's actual version-pinning capability

ADR-0003 notes that `overlay/UPSTREAM_VERSION` is documentation only.
**Unconfirmed**: whether upstream's installer or `hermes update` command
actually supports installing/pinning to a specific tag/commit via an env
var or flag (e.g. something like `HERMES_VERSION=vX.Y.Z`) — if it does,
real pinning could be added relatively cheaply; if not, real pinning would
require cloning `NousResearch/hermes-agent` ourselves. **Action**: check
upstream's installer script source and `hermes update --help` (or
equivalent) for any version-selection capability before deciding this is
infeasible.

### 6. Default local model choice (`qwen2.5:14b`) — untested against real hardware

Chosen as a reasonable-sounding default balancing capability against
resource requirements, referencing (but not exactly matching) upstream
documentation's own example (`qwen2.5-coder:32b`, which was judged likely
too heavy for an unknown default target). No benchmarking has been done on
any actual machine. **Action**: once Phase 1 hardware is known, benchmark
at least two model sizes and adjust the default (and per-profile override
guidance) based on real performance/quality tradeoffs, not the current
placeholder reasoning.

### 7. macOS launchd implementation — not designed, only stubbed

`01-install-ollama.sh` and `04-enable-autostart.sh` print a warning and do
nothing real on non-systemd hosts. No launchd plist or `hermes gateway
install` (user-agent mode, per upstream docs) has actually been tested on
macOS. **Action**: design this properly in Phase 3, don't treat the warning
message as "macOS support," per `docs/current-state.md`.

### 8. WSL2 boot-autostart semantics — no design exists

Unlike the other unresolved items, this isn't "an assumption that might be
wrong" — it's a genuine design gap. WSL2 doesn't "boot" the way bare metal
does (it starts on first invocation, or via Windows-side mechanisms like
Task Scheduler or WSL's `boot.systemd` / `wsl --exec` hooks depending on
WSL version). **Action**: research current WSL2 autostart best practices
(this may have changed since Hermes's own docs were researched — re-check
current WSL2 documentation, not assumptions) before attempting
implementation.

### 9. Ventoy persistence portability across genuinely different hardware

The single biggest technical unknown in the USB workstream. Ventoy's
persistence mechanism is well-documented for a given machine, but
cross-hardware portability (different firmware/UEFI implementations,
different boot modes, different driver needs for wifi/graphics on
unfamiliar hardware) is unverified. A fallback plan (per-drive dd-flashed
images) is already documented in `overlay/iso-usb/README.md` in
anticipation of this risk. **Action**: this can only really be resolved by
testing on 2+ real, different machines (Project Plan step 17) — no amount
of further research substitutes for that test.

### 10. Whether the "fork + overlay" repo strategy discrepancy (ADR-0003) matters in practice

The thin-wrapper approach was kept as a pragmatic choice, but it's genuinely
unclear (not yet tested) whether `hermes update`'s behavior is fully
sufficient for keeping this project's assumptions in sync with upstream
changes, or whether upstream config-schema changes (see items 1-2 above)
will require this repo to actively track upstream release notes/changelogs
to stay correct over time. **Action**: revisit after the first time an
upstream Hermes update actually changes something this repo depends on —
until then this is a theoretical concern, not yet exercised.

## Assumptions requiring validation (summary table)

| # | Assumption | Where used | Risk if wrong |
|---|---|---|---|
| 1 | `model:` schema for local Ollama | `default.yaml` | High — core provider policy depends on this |
| 2 | `gateway.platforms` schema | all profile YAMLs | Medium — blocks messaging gateway, not core function |
| 3 | Docker env var mechanism | `docker-compose.override.yml` | Medium — blocks Docker path only |
| 4 | `ollama.service` unit name | `04-enable-autostart.sh` | Medium — boot ordering silently no-ops if wrong |
| 5 | Upstream version pinning capability | `UPSTREAM_VERSION`, ADR-0003 | Low — affects reproducibility, not function |
| 6 | Default model size/choice | `01-install-ollama.sh` | Low-medium — affects UX/performance, not correctness |
| 7 | macOS launchd approach | not yet implemented | Medium — macOS autostart doesn't exist yet regardless |
| 8 | WSL2 autostart approach | not yet designed | Medium — same, no design yet |
| 9 | Ventoy cross-hardware portability | `iso-usb/README.md` | High — core "device agnostic" requirement |
| 10 | Thin-wrapper sufficiency long-term | ADR-0003 | Low near-term, unknown long-term |

## Future architectural decisions not yet made

- Whether/how to implement selective cross-instance memory sync (currently
  explicitly out of scope — see `docs/data-model.md` and
  `docs/future-ideas.md`).
- Whether/how to eventually build the purchase-making capability (ADR-0002
  — deliberately not decided, owner must re-open this).
- Whether real upstream version pinning is worth the added maintenance
  burden of vendoring/tracking a specific Hermes commit (contingent on
  resolving open question #5 first).

## Research items

- Re-check upstream Hermes documentation for schema/behavior changes before
  relying on anything in `docs/api-spec.md` marked unconfirmed — this
  project's research was done at a single point in time (documented in
  conversation history as mid-2026) and Hermes was noted to be evolving
  fast (175k+ stars in under 4 months at time of research suggests an
  actively changing project).
- Current WSL2 autostart best practices (open question #8) — this is
  general Windows/WSL ecosystem knowledge that changes independent of
  Hermes itself and should be freshly researched, not assumed from
  general training knowledge.
