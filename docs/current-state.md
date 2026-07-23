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
- Syntax-checked (`bash -n`) for all shell scripts — confirms no shell
  syntax errors, confirms nothing about actual runtime correctness.
- All files committed to git and pushed to
  `https://github.com/sheridanwendt/kilo` (`main` branch).

## Partially implemented

- **Provider policy**: the *design* (local-first default, cloud manual-only,
  no fallback) is fully specified and reflected in
  `overlay/config-profiles/default.yaml`'s comments and structure. **Update
  (2026-07-23)**: first real run on Sheridan's on-prem box ("stick") — the
  `provider`/`base_url`/`default` keys under `model:` were accepted by a
  live Hermes install, but it then refused to initialize the agent with a
  context-window error (`OLLAMA_CONTEXT_LENGTH`'s systemd override isn't
  reflected in Ollama's model-info metadata that Hermes checks). Fixed by
  adding `model.context_length: 65536` to `default.yaml`, per Hermes's own
  error-message guidance — not yet re-verified end-to-end on real hardware
  after the fix. Still unconfirmed: whether `custom_providers:` would be
  more correct, and the full first-run wizard schema (agent name, gateway
  platform selection) — see `docs/open-questions.md` item 1.
- **Docker deployment**: `docker-compose.override.yml` exists and expresses
  the intent (sidecar Ollama container, local-first even in containers),
  but the mechanism for pointing the Hermes container at the sidecar
  (`HPA_OLLAMA_BASE_URL` env var) is explicitly flagged as unconfirmed —
  might need to be a mounted `config.yaml` instead.
- **Messaging gateway config**: `gateway.platforms` key in the profile
  YAMLs is a placeholder pending confirmation against `hermes gateway
  setup`'s actual generated config.

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
- Any real benchmarking of `qwen2.5:14b` (the default local model) against
  actual target hardware — the choice is a reasonable placeholder, not a
  validated one.
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