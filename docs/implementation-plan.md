# Implementation plan (phased)

This groups the 21 steps in `PROJECT_PLAN.md` into four phases with
dependencies, risks, and complexity. Steps 1-3 are done (authored, not yet
execution-tested); everything else is open. Work phases in order — later
phases assume earlier ones are validated on real hardware, not just written.

## Phase 0 — Done (scaffold, unvalidated)

Steps 1-3 from `PROJECT_PLAN.md`. Repo structure, config profiles, and
`install.sh` exist. **Not yet run on any real machine.** This is Phase 0
rather than part of Phase 1 because it's pure authoring with no execution
risk resolved yet — Phase 1 is where reality first meets these assumptions.

## Phase 1 — Prove the on-prem path works at all

**Goal**: `./install.sh --profile on-prem` produces a working, offline-capable,
boot-persistent agent on one real Ubuntu machine. This is the load-bearing
phase — every later phase builds on assumptions this phase either confirms
or breaks.

**Tasks** (maps to `PROJECT_PLAN.md` steps 4-12):
- Step 4: Ollama install, systemd enable, context-length override, model
  pull, offline tool-calling verification.
- Step 5: Cloud providers (Anthropic, OpenAI, Hugging Face) configured
  inactive; manual `/model` switch verified; confirm no
  `fallback_providers:` exists or gets auto-added by any wizard.
- Step 6: Sub-agent workflow validation.
- Step 7: Build and validate `instance-health` and `instance-provision`
  custom skills (see `overlay/skills/custom/README.md`); confirm
  auto-skill-creation fires.
- Step 8: Browser automation end-to-end test.
- Step 9: Cron scheduled automation (morning briefing) end-to-end test.
- Step 10: Messaging gateway (Telegram + CLI) as systemd-managed service —
  **this is also where `gateway.platforms` config schema gets confirmed or
  corrected** (see `docs/open-questions.md`).
- Step 11: Boot autostart — full reboot test, offline, confirm ordering
  works and the agent comes up on the local model unattended.
- Step 12: Security hardening pass (container hardening flags where
  relevant, secrets handling review, confirm purchase capability remains
  unwired).

**Dependencies**: A real Ubuntu machine (Server, per ADR-0006) with `sudo`,
internet access for the initial install, and enough RAM/CPU to run at least
a 14B-class local model reasonably (or override `HPA_LOCAL_MODEL` down —
see `docs/api-spec.md`).

**Risks**:
- The `model:`/`custom_providers:` config schema in
  `overlay/config-profiles/default.yaml` is based on documentation research,
  not a live wizard run — likely to need correction (flagged `TODO` in the
  file itself).
- `gateway.platforms` key name in the profile YAMLs is a placeholder,
  unconfirmed against `hermes gateway setup`'s actual output schema.
- Hardware may not support the default `qwen2.5:14b` model well; no
  benchmarking has been done on any specific target.
- Systemd ordering (`After=`/`Requires=`) assumes Ollama's own systemd unit
  name is exactly `ollama.service` (standard for the official installer,
  but not independently re-verified here).

**Complexity**: Medium. Mechanically straightforward (run scripts, observe,
fix), but every step is a first real-world test of a previously
paper-only design.

**Suggested order**: Steps 4 → 5 → 11 (get the core boot/offline/provider
behavior solid before layering on skills/browsing/scheduling) → 6 → 7 → 8 →
9 → 10 → 12. This reorders the numeric list slightly because boot-autostart
and provider policy are the two requirements with zero tolerance for being
wrong (they're named "never change without review" items in `CLAUDE.md`),
so validate them early even though they're numbered 5 and 11 in the
checklist.

## Phase 2 — Containerize and harden the "production ready" bar

**Goal**: The single-git-command install works cleanly on a throwaway VM,
and a Docker path exists as an alternative for `cloud-server` deployments.

**Tasks** (maps to steps 13-14):
- Step 13: Docker/docker-compose path. **Must first resolve the open
  question about how the Hermes container should reach the sibling Ollama
  container** (env var vs. mounted config — see
  `overlay/docker/docker-compose.override.yml`'s TODO and
  `docs/open-questions.md`).
- Step 14: Full clean-VM validation of `git clone && ./install.sh` — this
  is explicitly called out as the "production ready" bar in the original
  design conversation, i.e. this step is a gate, not just a checklist item.

**Dependencies**: Phase 1 complete and stable (Docker path reuses the same
profile/config logic; no point containerizing an install flow that's still
being debugged bare-metal).

**Risks**: Docker networking/volume behavior for Ollama (especially GPU
passthrough if the target VPS has one) is unexplored territory — nothing
in this repo has been tested against Docker's Ollama image
(`ollama/ollama`) yet, only referenced.

**Complexity**: Medium-high, mainly because of the unresolved
container-networking question.

**Suggested order**: 13 → 14.

## Phase 3 — Cross-platform validation

**Goal**: Confirm the install path works (or gracefully documents its
limits) on macOS and WSL2, per steps 15.

**Tasks** (maps to step 15):
- Native macOS install test — no systemd, so `01-install-ollama.sh` and
  `04-enable-autostart.sh`'s systemd-specific branches need real testing of
  their macOS fallback messages (currently just print a warning and exit
  0/1 rather than doing anything macOS-native like `launchd`/`brew
  services`). **This is a known gap** — no launchd unit has actually been
  written, only a warning message pointing the operator at
  `hermes gateway install` (user launchd agent, per upstream Hermes docs)
  and `brew services start ollama`.
- WSL2 install test on Windows — should behave like Linux since WSL2 is a
  real Linux kernel, but boot-autostart semantics differ (WSL2 doesn't
  "boot" the way bare metal does; it starts when first invoked or via
  Windows Task Scheduler / WSL's own autostart hooks) — this needs explicit
  research/design, not just "it'll work like Linux."

**Dependencies**: Phase 1 complete.

**Risks**: Two genuinely under-designed areas (macOS launchd, WSL2
autostart) — treat these as design tasks, not just test tasks. Budget more
time than the single checklist line suggests.

**Complexity**: Medium (macOS) to Medium-high (WSL2 autostart specifically).

**Suggested order**: macOS first (simpler, native systemd-equivalent story
via launchd is well-trodden), then WSL2.

## Phase 4 — USB image and instance provisioning

**Goal**: The Ventoy bootable USB works and is device-agnostic; the
human-gated new-instance flow exists.

**Tasks** (maps to steps 16-18):
- Step 16: Build the actual Ventoy image following
  `overlay/iso-usb/README.md`'s manual process; script it as
  `build-image.sh` once the manual process is proven.
- Step 17: Test on 2+ different physical machines — this is the actual
  acceptance test for "device agnostic," not just booting once.
- Step 18: Build the `instance-provision` skill (see
  `overlay/skills/custom/README.md`) — profile selection, summary of what
  will be installed, explicit typed confirmation before running
  `install.sh`. This is the closest thing to the original "easily create
  new instances (manually, with a human in the loop)" requirement, and it
  currently does not exist as code, only as a design note.

**Dependencies**: Phase 1 complete (the USB profile reuses the same
install pipeline). Phase 2 not required.

**Risks**: Ventoy persistence behavior across genuinely different hardware
(different firmware, different boot modes, different driver needs) is the
single biggest unknown in this phase — `overlay/iso-usb/README.md` already
documents a fallback plan (per-drive dd-flashed image) if this doesn't pan
out, per ADR-0004.

**Complexity**: High for step 16 (first-time OS image build work), medium
for 17 (mostly time/access to hardware), medium for 18 (skill authoring,
well-understood pattern by this point).

**Suggested order**: 16 → 17 → 18 (need a working image before you can
test it or wrap a provisioning flow around it).

## Phase 5 — Close-out

**Goal**: Ship v1.

**Tasks** (maps to steps 19-21):
- Step 19: Recovery runbook already drafted (`overlay/docs/runbook.md`) —
  this step is verifying it actually works (restore from a real backup
  onto a freshly-installed instance), not writing it from scratch.
- Step 20: Full acceptance pass against every requirement in `README.md`'s
  capability matrix, with known gaps explicitly documented rather than
  silently dropped.
- Step 21: Tag v1.0, finalize README, capture backlog
  (`docs/backlog.md`, `docs/future-ideas.md`).

**Dependencies**: All prior phases.

**Risks**: Low — this is mostly verification and documentation, not new
building, assuming Phases 1-4 are genuinely solid.

**Complexity**: Low-medium.

**Suggested order**: 19 → 20 → 21.

## Summary table

| Phase | Steps | Complexity | Primary risk |
|---|---|---|---|
| 0 (done) | 1-3 | — | Config schema assumptions unverified |
| 1 | 4-12 | Medium | Same, plus first real-hardware execution of everything |
| 2 | 13-14 | Medium-high | Docker↔Ollama networking mechanism unresolved |
| 3 | 15 | Medium-high | macOS launchd and WSL2 autostart are under-designed, not just untested |
| 4 | 16-18 | High (16), Medium (17-18) | Ventoy persistence portability across hardware |
| 5 | 19-21 | Low-medium | Low, if prior phases are solid |
