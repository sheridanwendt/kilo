# Project plan

Tracking checklist for building the Hermes-based personal assistant. Full
rationale for each item lives in [`ARCHITECTURE.md`](./ARCHITECTURE.md).
Check items off as you complete them — this file is meant to be edited
directly (or via a PR) as you go.

> **Note on step 1**: the original plan called this "fork + overlay." What
> actually got built is closer to a **thin wrapper repo** — `kilo` holds only
> install scripts, config profiles, and custom skills; it pins/references
> upstream `NousResearch/hermes-agent` at install time via the documented
> installer rather than vendoring its source. Functionally this still gets
> you `hermes update`-style upgrades (that command talks to upstream
> directly, independent of this repo), with less to maintain. Flagging the
> discrepancy here rather than letting it quietly diverge from the doc.

- [x] **1. Repo scaffold** — `kilo` created as a thin wrapper repo: `overlay/` with `skills/custom`, `config-profiles`, `install`, `docker`, `iso-usb`, `docs`.
- [x] **2. Instance profiles defined** — `cloud-server`, `on-prem`, `usb-offline` config templates (LLM provider, messaging platforms, skill set).
- [x] **3. Self-install entrypoint written** — `install.sh` clones-and-runs the upstream installer, then applies the chosen profile. Idempotent, re-runnable.
- [ ] **4. Local model online** — install Ollama, enable as a systemd service, pull a baseline model (≥64k context), set as default provider in every profile. Verify tool calling fully offline (network disabled).
- [ ] **5. Cloud providers wired but inactive** — configure Anthropic (native), OpenAI (Codex OAuth or API key), Hugging Face (native). Verify manual `/model` switch reaches each one. Confirm no `fallback_providers:` auto-routes to cloud.
- [ ] **6. Sub-agent workflows validated** — real multi-step task exercising parallel sub-agents (the "call other agents" requirement).
- [ ] **7. Custom skills built** — 2-3 skills (start with `instance-health`, `instance-provision`), confirm the auto-skill-creation loop fires on a solved problem.
- [ ] **8. Browser automation tested** — a real end-to-end browsing task.
- [ ] **9. Scheduled automation configured** — e.g. a cron morning briefing, validating the workflow/automation path.
- [ ] **10. Messaging gateway configured** — Telegram + CLI to start, systemd-managed.
- [ ] **11. Boot autostart registered** — `hermes gateway install --system`, `systemctl enable ollama`, ordering so Ollama starts before Hermes. Reboot and confirm it comes up unattended, offline.
- [ ] **12. Security hardening pass** — container hardening flags, secrets handling, confirm no purchase/payment integration is wired.
- [ ] **13. Docker/docker-compose path built** — full teardown-and-rebuild tested on a fresh VM.
- [ ] **14. Single-git-command install validated** — `git clone ... && ./install.sh` on a clean Ubuntu box. This is the "production ready" bar.
- [ ] **15. macOS and WSL2 (Windows) install tested.**
- [ ] **16. Ventoy bootable USB image built** — persistent Ubuntu + Ollama + preloaded model + Hermes pre-configured for `usb-offline`, first-boot setup script.
- [ ] **17. USB image tested on 2+ physical machines** — confirms device-agnostic behavior.
- [ ] **18. "New instance" bootstrap script built** — explicit human-confirmation step before any instance goes live.
- [ ] **19. Reinstall/recovery runbook written** — per target (cloud VM, on-prem box, USB); backup/restore for `~/.hermes` set up.
- [ ] **20. Full acceptance pass** — every original requirement checked; known gaps documented (Windows-native, deferred purchase skill).
- [ ] **21. v1.0 tagged** — README one-liner install finalized, follow-up backlog captured (purchase skill, multi-USB fleet management).

## Currently in progress

Step 4 (local model online) — see open question in chat about Ubuntu Desktop
vs Server for the target box, which affects how this and step 11 get tested.
