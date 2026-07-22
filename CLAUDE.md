# CLAUDE.md — persistent instructions for Claude instances working on this repo

This file is the authoritative instruction set for any Claude (Claude Code
or otherwise) continuing work on `sheridanwendt/kilo`. It was written by a
prior Claude instance (Cowork) at handoff time, transcribing decisions made
directly with the project owner, Sheridan. Read this in full before making
changes. When this file and your own judgment disagree, prefer this file and
ask the owner rather than silently overriding it — every rule below traces
back to an explicit owner decision, not a default assumption.

## Project goals (priority order)

1. **Local-first, free by default.** The agent must run entirely offline on
   a local Ollama model with zero API cost, on every profile, at all times,
   unless a human explicitly switches providers for a specific task.
2. **Cloud only by manual, explicit approval.** Never wire automatic
   fallback or silent routing to a paid provider. The act of typing
   `hermes model` or `/model <provider>` IS the approval mechanism — do not
   build a separate approval UI, and do not add `fallback_providers:`
   entries that point at a cloud provider.
3. **Reinstallable from scratch, one command, anywhere.** `git clone && cd
   kilo && ./install.sh --profile <name>` must be able to take a bare OS to
   a fully running agent. Every change to install behavior must preserve
   this property.
4. **Boots itself.** The agent must come up unattended after a reboot,
   already on the local model, with no login or manual step required.
5. **Real agentic capability**: task execution, sub-agent orchestration,
   browsing, skill authoring — via Hermes's native features, not
   reimplemented here.
6. **No purchasing capability**, until the owner explicitly revisits that
   decision. Do not build it "just in case." See Constraints below.

## Architectural principles

- **This repo is a thin overlay, not a fork.** It does not vendor Hermes
  Agent's source. It installs upstream Hermes via upstream's own official
  installer/updater and layers config, install automation, and custom
  skills on top. Do not start copying Hermes source into this repo without
  discussing it with the owner first — see `docs/decisions.md` ADR-0003 for
  the full reasoning and the tradeoff this implies (no true version pinning
  of upstream; `overlay/UPSTREAM_VERSION` is documentation, not enforcement).
- **Profiles are config, not code branches.** `on-prem`, `cloud-server`, and
  `usb-offline` are YAML files deep-merged onto `default.yaml`. New
  deployment targets should be new profile files, not new install scripts or
  conditional logic scattered through the shell scripts.
- **Numbered install scripts run in a fixed order.** `overlay/install/01-*`
  through `04-*` are called in sequence by `install.sh`. If you add a new
  install stage, give it the next number and keep it idempotent —
  `./install.sh` must be safely re-runnable on a machine that's already been
  set up.
- **Everything writes into `~/.hermes/`.** That directory is Hermes's own
  state (memory, config, auth tokens). This repo's job is to arrive at a
  correct `~/.hermes/config.yaml` and correct systemd units; it does not
  maintain parallel state elsewhere.
- **Env var prefix `HPA_`** for anything this repo (not upstream Hermes)
  controls: `HPA_PROFILE`, `HPA_PROFILE_FILE`, `HPA_OVERLAY_DIR`,
  `HPA_LOCAL_MODEL`, `HPA_OLLAMA_CONTEXT_LENGTH`. Keep using this prefix for
  new variables so it's always obvious what's ours vs. upstream Hermes's own
  env vars (`ANTHROPIC_API_KEY`, `HF_TOKEN`, etc.).

## Naming conventions

- Shell scripts: `NN-verb-noun.sh` inside `overlay/install/` (e.g.
  `01-install-ollama.sh`). Top-level entrypoint is always `install.sh`.
- Config profiles: `overlay/config-profiles/<profile-name>.yaml`, lowercase,
  hyphenated (`on-prem`, `cloud-server`, `usb-offline`).
- Custom skills: `overlay/skills/custom/<skill-name>/SKILL.md`, following the
  agentskills.io standard Hermes already reads natively.
- Docs: everything project-level and durable goes in `docs/`. Anything
  scratch/ephemeral (build logs, generated images) must be gitignored, not
  committed.

## Libraries / tools to prefer

- **Shell**: POSIX-ish bash with `set -euo pipefail`, already the pattern in
  every existing script. Keep using it for install/glue code — do not
  introduce Python or another language for install orchestration unless a
  task genuinely needs it (the config-merge step already uses Python because
  YAML deep-merging in bash is a bad idea).
- **Python** (only where bash is a poor fit, e.g. YAML merging): use the
  standard library plus `pyyaml`, installed on demand with
  `pip install --break-system-packages` (already the pattern in
  `03-apply-profile.sh` — Ubuntu 24.04+ externally-managed-environment
  restrictions require this flag).
- **Ollama** for all local inference. Do not introduce a second local
  inference server (vLLM, llama.cpp, LM Studio) without a specific reason
  tied to a profile's hardware constraints — Ollama was chosen for
  simplicity and because Hermes's docs treat it as the reference "offline"
  path.
- **systemd** for process supervision on Linux targets. Do not introduce
  supervisord, PM2, or a custom init wrapper.
- **Ventoy** for the USB image, per the owner's explicit choice over
  per-drive dd-flashed images (see ADR-0004). Do not switch approaches
  without checking with the owner — this was a deliberate tradeoff, not an
  oversight.

## Libraries / tools to avoid

- **OpenRouter and Nous Portal as LLM providers.** Explicitly excluded from
  this project. Both are cloud relay/subscription services that do not work
  offline, and both are redundant given Hermes's native Anthropic, OpenAI,
  and Hugging Face support. Do not add them back in "for convenience" — see
  ADR-0005.
- **Any `fallback_providers:` entry pointing at a cloud model.** This would
  silently spend money without approval and directly violates goal #2
  above. If you add resilience/retry behavior, keep it local-only (e.g.
  retry against a second local model) or make it require an explicit
  human-confirmed opt-in, not a config default.
- **Any payment/checkout automation, stored payment credentials, or browser
  autofill of card data**, anywhere in this repo or in any skill under
  `overlay/skills/custom/`. Purchasing is deferred (ADR-0002); do not
  implement it speculatively.
- **Full desktop environments on always-on server profiles**
  (`on-prem`, `cloud-server`). Ubuntu Server, not Desktop — RAM/CPU headroom
  matters for local model inference, and Hermes doesn't need a GUI. Desktop
  is only justified for the `usb-offline` profile's walk-up-friendliness;
  see ADR-0006.

## Performance priorities

1. Local model responsiveness / resource headroom over feature breadth —
   default model choice (`qwen2.5:14b` via `HPA_LOCAL_MODEL`) is a
   deliberately adjustable placeholder, not a fixed requirement. Prefer
   smaller models on constrained profiles (`cloud-server` CPU-only VPS,
   `usb-offline` unknown hardware) over forcing one model size everywhere.
2. Boot-to-ready time matters for the "starts automatically at boot"
   requirement — don't add slow synchronous steps to the systemd startup
   path without considering whether they belong in `install.sh` (one-time)
   instead.
3. Context window: Hermes requires ≥64k tokens of context for reliable
   tool-calling. `OLLAMA_CONTEXT_LENGTH` is set via a systemd drop-in
   specifically because Ollama truncates context by default — do not remove
   this override, and do not lower it below 64k.

## Security principles

- No secrets committed to this repo, ever. `.gitignore` already excludes
  `.env`, `*.env`, `.hermes/`, and backup files — keep it that way as new
  file types get introduced.
- Cloud provider credentials live only in `~/.hermes/.env` on the target
  machine, populated manually or via a mechanism this repo does not
  automate (deliberately — see ADR-0005's discussion of the manual-approval
  requirement extending to credential setup too).
- If you ever need to push to GitHub or authenticate to any external service
  from within an agent session, use the shortest-lived, most narrowly
  scoped credential possible (see `docs/security.md` for the precedent set
  during initial repo setup: a fine-grained, single-repo PAT, used once,
  then stripped from local git config immediately after use).
- Purchasing capability is deferred specifically because it's the
  highest-risk item in the original requirements — do not build toward it
  without the owner explicitly re-opening that decision.

## Testing expectations

- **Nothing in this repo has been executed on real hardware as of this
  handoff.** Treat every script as unvalidated until proven otherwise. See
  `docs/current-state.md` and `docs/testing.md`.
- Before marking any `PROJECT_PLAN.md` step complete, it must have been
  actually run end-to-end on the target it claims to support, not just
  written and reviewed.
- When you discover a config schema assumption is wrong (very likely for
  the items flagged `TODO` in `overlay/config-profiles/*.yaml` and
  `overlay/docker/docker-compose.override.yml`), fix the file, remove the
  TODO, and record what you learned in `docs/open-questions.md` (move it
  from "open" to resolved, with the answer) and `docs/decisions.md` if it
  changes an architectural assumption.
- `install.sh` must remain idempotent — re-running it on an already-set-up
  machine should not break anything. Test this explicitly when changing any
  `overlay/install/*.sh` script.

## Documentation expectations

- Every new architectural decision gets an ADR entry in `docs/decisions.md`
  — decision, context, alternatives considered, why chosen, consequences.
  Don't skip the alternatives section even if the answer feels obvious in
  hindsight.
- Every new unconfirmed assumption gets logged in `docs/open-questions.md`
  until verified.
- Keep `PROJECT_PLAN.md` checkboxes in sync with actual, tested completion —
  it's the owner's primary way of tracking progress and is meant to be
  read, not just written to.
- Update `docs/current-state.md` whenever a plan step moves from
  unvalidated to validated, or when new technical debt is discovered.

## How new features should be implemented

1. Check whether Hermes Agent already does it natively (consult upstream
   docs at `hermes-agent.nousresearch.com/docs` and the
   `NousResearch/hermes-agent` repo) before building it here. This repo
   exists to configure and orchestrate Hermes, not to duplicate its
   functionality.
2. If it's a new capability the agent should have at runtime (not an
   install-time concern), it's almost always a **skill**
   (`overlay/skills/custom/<name>/SKILL.md`), not a change to the install
   scripts.
3. If it's a new deployment target or hardware profile, it's a new
   **config profile**, deep-merged onto `default.yaml`, not a fork of
   `install.sh`.
4. If it touches provider/model selection, it must preserve the
   local-default / manual-cloud-switch policy — no exceptions without an
   explicit owner conversation and a new ADR.
5. Write the acceptance test (what does "done" look like, on what target)
   before writing the implementation, and add it to `docs/testing.md` and/or
   `docs/backlog.md`.

## Important constraints

- Native Windows support is explicitly out of scope; WSL2 is the only
  supported Windows path (this is an upstream Hermes limitation, not a gap
  in this repo — see ADR-0007).
- The USB approach is one Ventoy multi-boot drive with a persistent image,
  not a fleet of separately-flashed drives, per owner decision (ADR-0004).
- Repo strategy is "thin wrapper," not literal fork-with-upstream-remote,
  per what was actually implemented (a deviation from the originally
  discussed "fork + overlay" — see ADR-0003 for the full story). This is
  intentional and should not be "corrected" back to a real fork without
  discussing it with the owner.

## Things that should never be changed without explicit owner review

- Any change that causes a cloud provider to be selected automatically
  (default provider, fallback chain, or otherwise) without a manual command
  from the user in the moment.
- Any change that adds purchase/payment/checkout capability.
- Any change that stores payment credentials, browser autofill profiles
  containing card data, or similar, anywhere in `~/.hermes` or this repo.
- Any change to `.gitignore` that could cause `.env` or `.hermes/` to be
  committed.
- Switching the USB strategy away from single-Ventoy-drive.
- Switching the local inference engine away from Ollama.
- Removing or lowering the `OLLAMA_CONTEXT_LENGTH` override below 64k.

## Where to look next

Start with `docs/current-state.md` for exactly what's built vs. stubbed,
then `docs/implementation-plan.md` for the phase you should be working in,
then `docs/open-questions.md` for landmines to check before you trust any
given config file.
