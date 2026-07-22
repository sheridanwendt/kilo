# Repository file structure

**Important**: the repo root at `github.com/sheridanwendt/kilo` contains
these files and directories *directly* — there is no
`hermes-personal-assistant/` wrapper folder inside the repo, even though
that name appears in some diagrams/discussion as the local working-directory
name used while building this (see `docs/decisions.md` ADR-0011). This
document describes the actual, current layout.

```
kilo/                                    (repo root)
├── README.md                            Project overview, entry point, doc map
├── CLAUDE.md                            Persistent instructions for Claude instances
├── ARCHITECTURE.md                      Original reference-architecture write-up
├── PROJECT_PLAN.md                      21-step checklist (owner-facing progress tracker)
├── .gitignore                           Excludes secrets, .hermes/, USB build artifacts
├── install.sh                           Single entrypoint: git clone + ./install.sh
├── docs/                                Deep-dive engineering documentation (this handoff)
│   ├── architecture.md                  System architecture, data flow, Mermaid diagrams
│   ├── decisions.md                     ADR log
│   ├── implementation-plan.md           Phased roadmap
│   ├── current-state.md                 What's built vs. stubbed vs. tested
│   ├── api-spec.md                      CLI contracts, config schema
│   ├── data-model.md                    ~/.hermes state, config merge semantics
│   ├── file-structure.md                This file
│   ├── testing.md                       Testing philosophy and expectations
│   ├── security.md                      Threat model, secrets handling
│   ├── backlog.md                       Prioritized remaining work
│   ├── open-questions.md                Unconfirmed assumptions
│   └── future-ideas.md                  Enhancements out of scope for v1
└── overlay/                             Everything actually installed/applied to a target machine
    ├── UPSTREAM_VERSION                 Documentation marker only, not an enforced pin (ADR-0003)
    ├── config-profiles/                 Deep-merged YAML configs, one per deployment target
    │   ├── default.yaml                 Base: local Ollama default, cloud providers documented-inactive
    │   ├── on-prem.yaml                 Default profile: always-on Ubuntu box/VM
    │   ├── cloud-server.yaml            VPS/cloud instance, headless, Docker-first
    │   └── usb-offline.yaml             Ventoy bootable USB, assume no network at first boot
    ├── install/                         Numbered, ordered install steps — called by install.sh
    │   ├── 00-install-prereqs.sh        Baseline apt packages (curl, git, python3/pip/venv/yaml) + RAM/disk warnings
    │   ├── 01-install-ollama.sh         Ollama install, systemd enable, context override, model pull (retried)
    │   ├── 02-install-hermes.sh         Upstream Hermes installer wrapper (+ --update mode)
    │   ├── 03-apply-profile.sh          Python/PyYAML config deep-merge -> ~/.hermes/config.yaml (pip-version-safe)
    │   └── 04-enable-autostart.sh       systemd registration, ordering, and User=/HOME= pinning (see ADR-0012)
    ├── skills/
    │   └── custom/
    │       └── README.md                Describes instance-health + instance-provision skills (not yet built)
    ├── docker/
    │   └── docker-compose.override.yml  Sidecar Ollama container for cloud-server profile (has open TODO)
    ├── iso-usb/
    │   └── README.md                    Manual Ventoy build process (build-image.sh not yet written)
    └── docs/
        └── runbook.md                   Reinstall/recovery runbook, backup/restore via tar of ~/.hermes
```

## Directory purposes

- **`docs/`** — durable, project-level engineering documentation. Anything
  that explains *why* the project is shaped the way it is, or that a future
  contributor (human or Claude) needs to understand before making changes,
  belongs here. Not generated/scratch content.
- **`overlay/`** — everything that actually gets installed onto or applied
  to a target machine. If it's not something `install.sh` (directly or
  transitively) touches or references, it probably doesn't belong under
  `overlay/`.
  - **`overlay/config-profiles/`** — declarative YAML only. No logic. New
    deployment targets go here as new files, per `CLAUDE.md`'s
    architectural principles.
  - **`overlay/install/`** — imperative shell (and one inline Python
    block). Numbered and ordered. New install stages get the next number.
  - **`overlay/skills/custom/`** — Hermes `SKILL.md` content, one directory
    per skill, following the agentskills.io standard. Currently only a
    README describing what should exist; no actual skill directories yet.
  - **`overlay/docker/`** — Docker-specific deployment assets, additive to
    (not replacing) upstream Hermes's own `docker-compose.yml`.
  - **`overlay/iso-usb/`** — USB/ISO image build assets. Currently
    documentation only; expected to gain a `build-image.sh` and possibly
    binary/image artifacts (which must stay gitignored — large binaries
    don't belong in git history).
  - **`overlay/docs/`** — operational runbooks (as opposed to `/docs/`
    at the repo root, which is design/architecture documentation). This
    split (`overlay/docs/` = "how to operate," `/docs/` = "how/why it's
    built") is intentional; keep it.

## Major modules

There are no "modules" in a programming-language sense — this is a shell
script + YAML config project, not a compiled application. The closest
equivalent to modules are the four numbered install scripts (each a
self-contained, idempotent unit of work) and the config-profile files (each
a self-contained deployment-target definition).

## Expected future additions

Based on `docs/implementation-plan.md` and `docs/backlog.md`:

- `overlay/skills/custom/instance-health/SKILL.md`
- `overlay/skills/custom/instance-provision/SKILL.md`
- `overlay/iso-usb/build-image.sh`
- Possibly `overlay/install/05-*.sh` or similar if a new install stage is
  needed (e.g. macOS launchd registration, currently just a warning inside
  `01-install-ollama.sh`/`04-enable-autostart.sh` rather than a real
  implementation)
- Possibly a `overlay/config-profiles/usb-offline-desktop.yaml` vs. a
  server variant, if the Desktop-vs-Server split for the USB profile
  (ADR-0006) ends up needing distinct config rather than just a different
  base ISO
- Test scripts/harness — none exist yet (see `docs/testing.md`); if added,
  a `tests/` directory at the repo root would be the natura