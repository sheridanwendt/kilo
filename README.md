# Hermes Personal Assistant

A self-hosted, local-first personal agent built on [Hermes Agent](https://github.com/NousResearch/hermes-agent) (NousResearch, MIT). This repo is an **overlay** on top of upstream Hermes: it doesn't fork the agent's source, it pins an upstream version and layers profile-specific config, install automation, and custom skills on top.

Full design doc: [`ARCHITECTURE.md`](./ARCHITECTURE.md).

## What this gives you

- **Local-first, free**: local Ollama is the default model provider on every install. Works fully offline (airplane mode, no wifi USB boot) once installed.
- **Cloud on manual approval only**: Anthropic, OpenAI, and Hugging Face are configured but never auto-selected. You switch to them explicitly with `hermes model` / `/model`. No automatic cloud fallback is configured.
- **Starts at boot**: installs as a systemd service (`hermes-gateway` + `ollama`), ordered so the local model backend is up before the agent starts.
- **One-command install**: `git clone` + `./install.sh` gets a clean Ubuntu box (or macOS/WSL2) to a fully running agent.
- **Three deployment profiles**: `on-prem` (default), `cloud-server`, `usb-offline` (Ventoy bootable USB).

## Quick start

```bash
git clone https://github.com/<your-username>/hermes-personal-assistant.git
cd hermes-personal-assistant
./install.sh --profile on-prem
```

That's the single command referenced in the architecture doc. It:

1. Installs Ollama, enables it at boot, pulls the default local model.
2. Installs Hermes Agent (via upstream's official installer) pinned to the version in `overlay/UPSTREAM_VERSION`.
3. Applies the chosen config profile from `overlay/config-profiles/`.
4. Registers Hermes as a boot-time systemd service.

Run `./install.sh --help` for all profile and flag options.

## Profiles

| Profile | File | Use case |
|---|---|---|
| `on-prem` | `overlay/config-profiles/on-prem.yaml` | Default. Bare-metal or VM Ubuntu box you own, always-on. |
| `cloud-server` | `overlay/config-profiles/cloud-server.yaml` | VPS/cloud instance, headless, Docker-first. |
| `usb-offline` | `overlay/config-profiles/usb-offline.yaml` | Ventoy bootable USB, assume no network at first boot. |

All three inherit from `overlay/config-profiles/default.yaml`, which sets local Ollama as the default provider and lists the cloud providers in their inactive/configured-only state.

## Repo layout

```
hermes-personal-assistant/
├── install.sh                        # single entrypoint
├── overlay/
│   ├── UPSTREAM_VERSION               # pinned hermes-agent tag/commit
│   ├── config-profiles/               # per-target config.yaml overlays
│   ├── install/                       # numbered install steps, called by install.sh
│   ├── skills/custom/                 # your custom SKILL.md files
│   ├── docker/                        # docker-compose overrides (cloud-server profile)
│   ├── iso-usb/                       # Ventoy image build notes/scripts
│   └── docs/                          # runbooks
```

## Updating

```bash
cd hermes-personal-assistant
git pull
./install.sh --profile <same-profile-as-before> --update
```

`--update` re-runs the upstream `hermes update` and re-applies your profile without re-doing OS-level setup.

## Known gaps (tracked, not yet built)

- Purchase-making skill: reserved but not wired in v1 (see architecture doc).
- Native Windows: experimental upstream — use WSL2.
