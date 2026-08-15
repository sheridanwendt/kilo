# Current state

**Read this first if you're picking up the project.** Single most important
fact: everything below "Complete (authored)" has been written and reviewed
for internal consistency, but **nothing has been executed on real
hardware**. Treat every script and config file as a hypothesis until proven
otherwise on an actual machine.

## Complete (authored, not execution-tested)

- Repo scaffold: `README.md`, `CLAUDE.md`, `ARCHITECTURE.md`,
  `PROJECT_PLAN.md`, `.gitignore`.
- `install.sh` — top-level entrypoint, argument parsing (`--profile`,
  `--update`, `--skip-autostart`), calls the five numbered scripts in order
  (was four — see below).
- `overlay/install/00-install-prereqs.sh` — **added in a robustness audit**
  (ADR-0012): installs `curl`, `git`, `ca-certificates`, `python3`,
  `python3-pip`, `python3-venv`, `python3-yaml` via apt, plus soft RAM/disk
  warnings. Closes the "fresh Ubuntu has none of these" gap.
- `overlay/install/01-install-ollama.sh` — Ollama install, systemd enable,
  `OLLAMA_CONTEXT_LENGTH` override, model pull (now retried up to 3x on
  failure — ADR-0012).
- `overlay/install/02-install-hermes.sh` — upstream installer wrapper,
  `--update` mode.
- `overlay/install/03-apply-profile.sh` — Python/PyYAML deep-merge of
  config profiles into `~/.hermes/config.yaml`, with backup. **Fixed**
  (ADR-0012): no longer blindly passes `--break-system-packages` to pip,
  which broke on Ubuntu 22.04's older pip; tries plain install first, and
  in the common case doesn't need pip at all now that
  `00-install-prereqs.sh` installs `python3-yaml` via apt.
- `overlay/install/04-enable-autostart.sh` — `hermes gateway install
  --system`, systemd ordering drop-in. **Fixed** (ADR-0012): two real bugs
  — `sudo hermes ...` couldn't find the `hermes` binary (PATH reset under
  sudo; upstream installs to user-space, not a root-visible path), and the
  resulting system service would have run as `root` and read
  `/root/.hermes` instead of the installing user's config. Both fixed by
  resolving the binary path explicitly, preserving PATH under `sudo env`,
  and pinning `User=`/`Group=`/`HOME=` in the systemd drop-in.
- `overlay/config-profiles/default.yaml`, `on-prem.yaml`,
  `cloud-server.yaml`, `usb-offline.yaml`.
- `overlay/docker/docker-compose.override.yml` — has an unresolved TODO
  (see Known limitations below).
- `overlay/iso-usb/README.md` — manual process outline only, no automation
  script yet.
- `overlay/docs/runbook.md` — reinstall/recovery runbook, unverified by an
  actual restore test.
- `overlay/skills/custom/README.md` — describes two skills that should be
  built (`instance-health`, `instance-provision`); neither exists as actual
  `SKILL.md` content yet.
- `overlay/skills/custom/inbox-triage/` — Gmail triage *policy* skill
  (pairs with the bundled Google Workspace skill for actual OAuth-based
  Gmail access; this skill only decides what to do with a message),
  content-complete: `SKILL.md` (compact runtime card) plus
  `reference/first-principles.md` and `reference/policy-set-v1.1.md` (full
  rationale, loaded on demand). Not yet run against Hermes or a real Gmail
  inbox — see "Partially implemented" below.
- `sync-to-hermes.sh` (bash) / `sync-to-hermes.ps1` (PowerShell) — standalone
  content-sync scripts (ADR-0014), root-level, independent of `install.sh`.
  Copy `overlay/skills/custom/*` (and `memories/`, `cron/`, `hooks/`, once
  populated) into an existing Hermes agent's directory
  (`~/.hermes/`/`%LOCALAPPDATA%\hermes`), with a confirmation prompt,
  `--dry-run`, and `--hermes-dir`/`-HermesDir` override. `install.sh`'s own
  custom-skill step now calls `sync-to-hermes.sh` directly rather than
  maintaining separate copy logic (the earlier
  `overlay/install/05-install-custom-skills.sh` is removed). The bash
  version has been exercised end-to-end against a mock Hermes directory
  (dry-run, real copy, idempotent re-run, missing-directory error path all
  verified) in this container; the PowerShell version has only been
  reviewed, not executed — no `pwsh`/PowerShell runtime was available in
  this environment. The target path itself remains an unconfirmed
  assumption against a real Hermes instance (see `docs/open-questions.md`
  #11).
- Syntax-checked (`bash -n`) for all shell scripts — confirms no shell
  syntax errors, confirms nothing about actual runtime correctness.
- All files committed to git and pushed to
  `https://github.com/sheridanwendt/kilo` (`main` branch).

## Partially implemented

- **Provider policy**: the *design* (local-first default, cloud manual-only,
  no fallback) is fully specified and reflected in
  `overlay/config-profiles/default.yaml`'s comments and structure. **Update
  (2026-07-23/24)**: first real runs on Sheridan's on-prem box ("stick") —
  `docs/open-questions.md` items 1, 2, and 6 are now resolved. The
  `model:` and `gateway.platforms` schemas were confirmed correct by
  diffing the live-generated `~/.hermes/config.yaml` against what
  `03-apply-profile.sh` writes (byte-for-byte match). The default local
  model turned out to be a real dead end, though: `qwen2.5:14b`'s native
  context is only 32,768 tokens (confirmed via Qwen's own model card),
  below Hermes's 64k minimum and not safely extensible without YaRN
  scaling — no config override could fix this honestly, since the model
  genuinely can't serve that much context. Replaced the default with
  `qwen3.5:9b` (native 262,144-token context), confirmed working
  end-to-end on the same hardware. `model.context_length: 65536` in
  `default.yaml` now reflects a real, actually-served window rather than
  a workaround.
- **Docker deployment**: `docker-compose.override.yml` exists and expresses
  the intent (sidecar Ollama container, local-first even in containers),
  but the mechanism for pointing the Hermes container at the sidecar
  (`HPA_OLLAMA_BASE_URL` env var) is explicitly flagged as unconfirmed —
  might need to be a mounted `config.yaml` instead.
- **Messaging gateway config**: `gateway.platforms` key in the profile
  YAMLs is a placeholder pending confirmation against `hermes gateway
  setup`'s actual generated config.
- **`inbox-triage` skill**: policy content is written and internally
  consistent with its own `reference/first-principles.md`, but three
  things are unconfirmed: (1) whether `~/.hermes/skills/custom/` is
  actually where Hermes looks for custom skills — a real instance's
  `skills/` folder was observed to contain only bundled category folders
  (`email`, `productivity`, etc.) plus manifest/`.hub` bookkeeping, with no
  `custom/` folder, which doesn't confirm or rule out the assumption (see
  open question #11, now elevated to higher risk); (2) whether the
  deterministic-match patterns (domain lists, keyword lists) hold up
  against a real inbox — the policy doc says as much in its own status
  line; (3) whether the skill's description is enough to keep it from
  being confused with the bundled `email` category or the Google Workspace
  skill when a (especially smaller, local) model is choosing between them
  — mitigated in the current draft by stating explicitly that this skill
  doesn't access Gmail itself, but unverified against an actual model
  making that choice.

## Complete (validated)

Nothing yet. No step past "written" has been confirmed by actually running
it.

## Still needs work (not yet started at all)

- Any actual execution/testing (Project Plan steps 4-21 — see
  `docs/implementation-plan.md` for phased breakdown).
- `instance-health` custom skill (design only).
- `instance-provision` custom skill / human-in-the-loop new-instance flow
  (design only) — this is the concrete implementation of the original
  "easily create new instances (manually, with a human in the loop)"
  requirement, and it does not exist as code yet.
- `overlay/iso-usb/build-image.sh` (README exists, script doesn't).
- macOS launchd autostart (currently just a warning message, not a real
  implementation — see `docs/implementation-plan.md` Phase 3).
- WSL2 boot-autostart design (WSL2 doesn't boot like bare metal; no design
  work has happened here at all, only "test it" is on the checklist).
- Any real benchmarking of `qwen3.5:9b` (the default local model since
  2026-07-24) against actual target hardware — confirmed *working* on one
  machine (~7GB RAM), but not benchmarked for quality/speed, and not
  tried against other hardware tiers.
- Purchase-making capability — deliberately not started (ADR-0002).
- Any CI/automated testing (see `docs/testing.md`).

## Known technical debt

- `overlay/UPSTREAM_VERSION` is a documentation string, not an enforced
  pin. `install.sh` will always install whatever upstream's installer
  currently ships, which could be a different version than what this repo
  was last validated against, with no automated detection of drift.
- Config-schema TODOs (`gateway.platforms`, `model:`/`custom_providers:`
  keys, `HPA_OLLAMA_BASE_URL`) — see `docs/open-questions.md` for the full
  list. These aren't bugs yet because nothing has been run, but they will
  need fixing in Phase 1/2.
- No automated tests of any k