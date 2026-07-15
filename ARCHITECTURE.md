# Personal Assistant on Hermes Agent — Reference Architecture & Project Plan

## Feasibility verdict

Hermes Agent (NousResearch/hermes-agent, MIT, released Feb 2026) covers nearly every requirement natively:

- **Perform tasks / browse the internet**: native — built-in browser automation (navigate, click, type, screenshot), web search, page extraction.
- **Call other agents / create workflows**: native — "parallel sub-agents," isolated sub-agents spawned over RPC for multi-step pipelines; combined with skills + cron this is your workflow engine.
- **Add new skills**: native — automatic skill creation from experience, manual `SKILL.md` authoring, and one-command install from the agentskills.io community hub.
- **Offline local LLMs, cloud as manual opt-in**: native, and better than originally scoped. Hermes has first-class *native* (not proxy) providers for Anthropic, OpenAI (via Codex OAuth or direct API key), and Hugging Face — none of which require OpenRouter or Nous Portal as an intermediary. **OpenRouter and Nous Portal are dropped from this design**: neither works in airplane mode (both are cloud relay/subscription services), and neither is needed since Anthropic, OpenAI, and Hugging Face all have direct first-class support. See "Provider policy" below.
- **Start automatically at boot, local LLM default**: native — `hermes gateway install --system` registers a systemd unit that starts at boot; Ollama's own systemd service is enabled the same way. See "Boot autostart" below.
- **Reinstall from scratch (GitHub, containers, various OS)**: mostly native — one-line curl installer for Linux/macOS/WSL2, official Docker image + docker-compose, systemd service install. Native Windows is explicitly experimental upstream (WSL2 is the supported path).
- **Make purchases**: not native. Per your call, **deferred** — architecture reserves a slot for a future purchase skill but nothing is wired into v1.
- **Easily create new instances (manual, human-in-the-loop)**: not a distinct built-in feature, but straightforward to layer on top of the existing config-profile + installer primitives — this is custom glue we build.
- **Bootable USB, device-agnostic**: not native — a custom image-build layer on top of standard Linux live-USB tooling. Per your call, **one Ventoy multi-boot drive** carrying a persistent Ubuntu + Ollama + Hermes image.

Net: yes, Hermes gets you there, with a thin custom layer for instance provisioning, deferred purchasing, and the USB image pipeline. No need to build an agent framework from scratch.

---

## Provider policy (local-first, cloud by manual approval)

**Default, always-on**: local **Ollama**, reached through Hermes's Custom Endpoint flow (`http://localhost:11434/v1`, no API key, no internet required). This is baked into every config profile as `model.provider: ollama-local` / `base_url: http://localhost:11434/v1`. A model meeting the ≥64k context requirement is pre-pulled at install time so a cold boot in airplane mode works with zero setup.

**Cloud, configured but inactive by default** — each gets credentials wired in `~/.hermes/.env` during install, but is never selected automatically:
- **Anthropic** — native first-class provider, no OpenRouter proxy. Either OAuth (Claude Max + purchased extra credits) or a plain `ANTHROPIC_API_KEY` (pay-per-token, independent of any subscription).
- **OpenAI** — either "OpenAI Codex" OAuth (ChatGPT plan, Codex models) or a Custom Endpoint entry pointed at `https://api.openai.com/v1` with `OPENAI_API_KEY` (OpenAI's API is natively OpenAI-shaped, so this is a first-class-quality path even without a dedicated provider ID).
- **Hugging Face** — native first-class provider (`HF_TOKEN`), routes to 20+ open models across multiple backends, has a free tier.

**Switching model**: switching providers is always a deliberate, explicit action — `hermes model` (full switch, outside a session) or `/model <provider>:<model>` (quick switch inside a session, e.g. `/model anthropic:claude-sonnet-4-6`). That explicit command *is* your approval step. We deliberately do **not** configure Hermes's `fallback_providers:` chain to auto-fail over to a cloud provider — automatic fallback would silently spend cloud credits without your sign-off, which conflicts with "cloud only when I approve it." If you later want a safety-net (e.g., auto-retry on a second local model if the first errors), that stays local-only.

## Boot autostart

- `sudo hermes gateway install --system` registers `hermes-gateway` as a systemd service: starts at boot, restarts automatically on crash, no dependency on user login/linger.
- Ollama is installed as its own systemd service (`systemctl enable ollama`) so the local model server is already up before Hermes starts.
- The default provider in every profile's `config.yaml` is the local Ollama endpoint, so a fresh boot with no network — laptop in airplane mode, USB drive with no wifi configured yet — comes up fully functional on the free local model. Cloud providers sit there configured and idle until you explicitly invoke them.
- Order of startup dependency: `ollama.service` → `hermes-gateway.service` (systemd `After=`/`Requires=` on the Hermes unit) so Hermes never starts before its default model backend is reachable.

---

## Reference architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         GitHub repo (source of truth)                │
│  fork of NousResearch/hermes-agent (tracked remote: upstream)        │
│  + overlay/  (your customizations, versioned separately)             │
│     ├─ skills/custom/        (your SKILL.md files)                   │
│     ├─ config-profiles/      (cloud-server, on-prem, usb-offline)    │
│     ├─ install/              (setup.sh, docker-compose overrides)    │
│     ├─ iso-usb/              (Ventoy image build scripts)            │
│     └─ docs/                 (runbooks)                              │
└──────────────────────────────────────────────────────────────────────┘
                 │  single command: git clone + ./install.sh
                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      Core Hermes Agent Runtime                       │
│  Python/uv process · CLI + interactive setup wizard                  │
│                                                                        │
│  ┌─────────────────┐  ┌───────────────┐  ┌─────────────────────────┐ │
│  │ LLM Provider     │  │ Skills System │  │ Sub-Agent Orchestration │ │
│  │ abstraction:     │  │ 40+ built-in  │  │ parallel sub-agents,    │ │
│  │ - Local Ollama   │  │ + auto-created│  │ isolated conv./terminal │ │
│  │   = DEFAULT,     │  │ + custom repo │  │ per sub-agent, RPC      │ │
│  │   offline, free  │  │ + agentskills │  │ = your "call other      │ │
│  │ - Anthropic      │  │   .io hub     │  │   agents" + workflows   │ │
│  │   (native)       │  │               │  │                         │ │
│  │ - OpenAI (Codex   │  │               │  │                         │ │
│  │   OAuth / API key)│  │               │  │                         │ │
│  │ - Hugging Face   │  │               │  │                         │ │
│  │   (native)       │  │               │  │                         │ │
│  │ cloud = manual    │  │               │  │                         │ │
│  │ switch only,      │  │               │  │                         │ │
│  │ no auto-fallback  │  │               │  │                         │ │
│  └─────────────────┘  └───────────────┘  └─────────────────────────┘ │
│                                                                        │
│  ┌─────────────────┐  ┌───────────────┐  ┌─────────────────────────┐ │
│  │ Browser Control  │  │ Cron          │  │ Messaging Gateway       │ │
│  │ nav/click/type/  │  │ Scheduler     │  │ Telegram / Discord /    │ │
│  │ screenshot, web  │  │ (automations, │  │ Slack / WhatsApp /      │ │
│  │ search/extract   │  │  briefings)   │  │ Signal / CLI            │ │
│  └─────────────────┘  └───────────────┘  └─────────────────────────┘ │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ Memory (~/.hermes/): skill memory, conversation memory,      │    │
│  │ user model. Backed up/restorable across reinstalls.          │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ [reserved, not wired v1] Purchase skill — human approval gate │   │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
                 │
                 ▼  deployed via one of:
┌──────────────────────────────────────────────────────────────────────┐
│ Deployment / Infrastructure targets                                   │
│  • Bare-metal Ubuntu (native install + systemd)                      │
│  • Docker / docker-compose (cloud VPS, on-prem server)                │
│  • WSL2 (Windows — native Windows is experimental upstream)           │
│  • macOS (native)                                                     │
│  • Ventoy bootable USB: persistent Ubuntu + Ollama + Hermes,          │
│    pre-configured "usb-offline"