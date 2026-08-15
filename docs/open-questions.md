# Open questions

Everything in this document is an assumption made during design that has
**not** been confirmed against a real, running Hermes instance. Resolve
these during Phase 1 (`docs/implementation-plan.md`) and move each item to
"Resolved" with the answer once confirmed — don't delete the question, keep
the record of what was uncertain and what turned out to be true.

## Resolved

### 1. Exact `model:` / `custom_providers:` schema for local Ollama — RESOLVED

`overlay/config-profiles/default.yaml` set:

```yaml
model:
  provider: "custom"
  base_url: "http://localhost:11434/v1"
  default: "qwen2.5:14b"
```

based on documentation references, not a confirmed `hermes`-generated
file. **Resolved 2026-07-23**, real run on Sheridan's on-prem box
"stick": after running `install.sh --profile on-prem` end to end and
letting Hermes's own first-run flow complete, `cat ~/.hermes/config.yaml`
came back byte-for-byte identical (for the `model:` block) to what
`03-apply-profile.sh` had already written — Hermes didn't rewrite or add
to it. Confirmed correct as-is; the `custom_providers:` alternative this
question originally worried about is not needed.

One real gap this run did surface: initializing the agent failed with a
context-window error (32,768 tokens reported vs. Hermes's 64k minimum),
even with `OLLAMA_CONTEXT_LENGTH=65536` already set via the systemd
drop-in — Ollama's model-info endpoint reports the model's default
Modelfile context, not the actual runtime serving window, and Hermes
checks the former. Hermes's own error text named the fix: a
`context_length` key alongside `default:` under `model:`. Added to
`default.yaml`.

Still open: whether the interactive wizard (`hermes setup`, distinct from
just running `hermes`) writes anything beyond `config.yaml` — e.g. the
agent's name ("kilo" in Sheridan's session) wasn't present anywhere in
`config.yaml`, so it's either a hardcoded Hermes default or lives in
separate state. Not investigated further since it isn't blocking.

### 2. Exact `gateway.platforms` schema — RESOLVED

`overlay/config-profiles/on-prem.yaml`, `cloud-server.yaml`, and
`usb-offline.yaml` all use:

```yaml
gateway:
  platforms: ["telegram", "cli"]
```

invented as a placeholder, not sourced from a confirmed schema reference.
**Resolved 2026-07-23**: confirmed via the same real run as #1 above —
`~/.hermes/config.yaml`'s `gateway:` block matched this exactly, key name
and structure both. No changes needed.

### 6. Default local model choice — RESOLVED (was `qwen2.5:14b`, now `qwen3.5:9b`)

`qwen2.5:14b` was chosen as a reasonable-sounding default balancing
capability against resource requirements, not benchmarked on real
hardware. **Resolved 2026-07-24, real run on "stick"**: it failed
outright — Hermes refused to run it, since its native context is only
32,768 tokens (confirmed via Qwen's own model card), below Hermes's 64k
minimum, and not safely extensible without YaRN rope-scaling that Hermes
wasn't configured to use. Setting `model.context_length` to satisfy
Hermes's check without the runtime actually serving that window would
have been reporting a context size the model doesn't genuinely support —
correctly rejected as a path to take.

Switched to `qwen3.5:9b`, confirmed working end-to-end on the same
hardware (~7GB RAM). Its native context is 262,144 tokens, comfortably
covering the 64k+ requirement with no extrapolation involved. This is
still only one data point on one machine — no formal benchmarking across
model sizes/hardware tiers has been done, and the earlier RAM-tiered
7b/14b selection in `01-install-ollama.sh` was dropped back to a single
size pending a second confirmed size for very constrained or high-RAM
hardware.

## Unresolved

### 11. `~/.hermes/skills/custom/` as the custom-skill target path — risk raised, still unresolved

`overlay/install/05-install-custom-skills.sh` copies
`overlay/skills/custom/<name>/` into `~/.hermes/skills/custom/<name>/`,
assuming that's where Hermes's skill loader looks for user-supplied
`SKILL.md` content (by analogy with `config.yaml` and skill memory already
living under `~/.hermes/`).

**New data point (2026-08-15, from the owner, not yet independently
verified by a Claude instance):** a real Hermes instance's skills
directory — `~/.hermes/skills/` on Linux, `%LOCALAPPDATA%\hermes\skills\`
on Windows (native Windows is out of scope per ADR-0007/CLAUDE.md, so only
the Linux path matters for `install.sh`, which only ever runs inside
Linux/WSL2) — contains, by default: bundled category folders (`apple`,
`autonomous-ai-agents`, `creative`, `email`, `github`, `media`, `mlops`,
`note-taking`, `productivity`, `research`, `smart-home`, `social-media`,
`software-development`), a hidden `.hub/` folder, and bookkeeping files
`.bundled_manifest`, `.usage.json`, `.usage.json.lock` — but **no
`custom/` folder**.

This does not confirm or rule out the `custom/` assumption — it's
consistent with nothing having been manually added to that particular
instance yet, but the presence of `.bundled_manifest` and `.usage.json`
also raises a real possibility this repo hadn't considered: Hermes may
track installed skills in that manifest rather than (or in addition to)
scanning the filesystem, in which case a raw `cp -r` into any folder —
`custom/` or otherwise — might be silently invisible to the skill loader,
or worse, might get treated as unmanaged content and pruned/flagged by a
future `hermes update`. **Raising this from Medium to High risk** given
that new information undermines confidence in the original assumption
rather than confirming it.

**Action**: before trusting this mechanism for anything real,
1. Run `overlay/install/05-install-custom-skills.sh` (or `install.sh`) on
   a real instance and confirm Hermes actually surfaces the `inbox-triage`
   skill — e.g. ask it something that should trigger the skill and see if
   its behavior/reasoning reflects the policy card.
2. Check `hermes skill --help` (or equivalent) for a registration command
   (e.g. `hermes skill install <path>`) — if one exists, it's more likely
   the intended mechanism than a raw file copy, and `.bundled_manifest`
   would need updating too, which a subcommand would handle and a copy
   would not.
3. If a raw copy does turn out to work, confirm it survives a `hermes
   update` / `install.sh --update` run rather than being silently removed.

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
| 1 | `model:` schema for local Ollama | `default.yaml` | **Resolved** — confirmed against real run 2026-07-23 |
| 2 | `gateway.platforms` schema | all profile YAMLs | **Resolved** — confirmed against real run 2026-07-23 |
| 3 | Docker env var mechanism | `docker-compose.override.yml` | Medium — blocks Docker path only |
| 4 | `ollama.service` unit name | `04-enable-autostart.sh` | Medium — boot ordering silently no-ops if wrong |
| 5 | Upstream version pinning capability | `UPSTREAM_VERSION`, ADR-0003 | Low — affects reproducibility, not function |
| 6 | Default model size/choice | `01-install-ollama.sh` | **Resolved** — `qwen2.5:14b` swapped for `qwen3.5:9b` 2026-07-24 after real-hardware failure |
| 7 | macOS launchd approach | not yet implemented | Medium — macOS autostart doesn't exist yet regardless |
| 8 | WSL2 autostart approach | not yet designed | Medium — same, no design yet |
| 9 | Ventoy cross-hardware portability | `iso-usb/README.md` | High — core "device agnostic" requirement |
| 10 | Thin-wrapper sufficiency long-term | ADR-0003 | Low near-term, unknown long-term |
| 11 | `~/.hermes/skills/custom/` target path | `05-install-custom-skills.sh` | High — custom skills silently invisible to Hermes if wrong, and a raw copy may not be the right mechanism at all (manifest-based registration possible) |

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
