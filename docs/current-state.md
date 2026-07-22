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
  `--update`, `--skip-autostart`), calls the four numbered scripts in order.
- `overlay/install/01-install-ollama.sh` — Ollama install, systemd enable,
  `OLLAMA_CONTEXT_LENGTH` override, model pull.
- `overlay/install/02-install-hermes.sh` — upstream installer wrapper,
  `--update` mode.
- `overlay/install/03-apply-profile.sh` — Python/PyYAML deep-merge of
  config profiles into `~/.hermes/config.yaml`, with backup.
- `overlay/install/04-enable-autostart.sh` — `hermes gateway install
  --system`, systemd ordering drop-in.
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
  `overlay/config-profiles/default.yaml`'s comments and structure, but the
  actual `model:`/`custom_providers:` YAML keys used are a best-effort
  guess based on documentation research (see `docs/open-questions.md`), not
  confirmed against a real `hermes model` wizard run. **This is the single
  highest-risk unverified assumption in the repo.**
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
- No automated tests of any kind exist. See `docs/testing.md`.
- `overlay/iso-usb/README.md` documents a fallback plan (per-drive
  dd-flashed images) in case Ventoy persistence doesn't hold up across
  hardware, but that fallback is not implemented, only described.

## Known bugs

None known — nothing has been executed, so no bugs have been observed yet.
This section should start filling in during Phase 1.

## Known limitations

- Native Windows is out of scope entirely (ADR-0007) — this is a permanent
  limitation inherited from upstream Hermes, not a temporary gap.
- Purchase-making is deliberately absent (ADR-0002) — permanent until the
  owner explicitly revisits it.
- No multi-instance memory sync — each `~/.hermes/` is fully independent
  per machine; there's no mechanism (yet, or planned for v1) to share
  learned skills/memory between, say, a home server instance and a laptop
  instance. See `docs/future-ideas.md`.
- Single-user design throughout — no multi-tenant, multi-user, or
  permission-separation concepts anywhere in this repo or in how Hermes
  itself is being configured.
