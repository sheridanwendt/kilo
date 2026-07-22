# Architecture Decision Log

ADR-style record of every significant decision made during this project's
design phase (a single extended conversation between the owner, Sheridan,
and a Cowork Claude instance, before any code was written or tested). Each
entry includes rejected alternatives — several later decisions only make
sense in light of what was rejected earlier, so don't prune those sections.

---

## ADR-0001: Use Hermes Agent as the base framework

**Decision**: Build on NousResearch/hermes-agent (MIT license, released Feb
2026) rather than building a custom agent framework or using a different
existing one.

**Context**: The owner wanted an agentic personal assistant with: task
execution, calling other agents, workflow creation, internet browsing,
purchasing, skill authoring, easy human-gated instance creation, one-command
reinstall across many environments (GitHub-sourced, containerized, ISO/USB,
Windows/Linux/Mac, on-prem/cloud), offline local LLM support, and bootable
USB support. The framework choice was named by the owner up front ("likely
using the Hermes agent framework") but its actual fit was unverified at the
start of the conversation.

**Alternatives considered**: None formally evaluated against Hermes — the
owner's brief already named Hermes as the intended framework, and research
confirmed it covered nearly every requirement natively (see the capability
matrix in `README.md`). Building a custom framework from scratch was
implicitly rejected as unnecessary effort given Hermes's native coverage.
No other existing agent framework (e.g., AutoGPT-style frameworks, LangGraph
agent scaffolds, OpenAI's own agent SDKs) was researched or compared,
because Hermes was specified rather than being chosen from a field —
**this is a real gap**: if Hermes turns out to have a fatal blocker during
Phase 1 testing, no fallback framework has been vetted. See
`docs/open-questions.md`.

**Why this option was selected**: Hermes natively provides persistent
memory, automatic + manual skill creation (agentskills.io-compatible),
parallel sub-agent orchestration over RPC, built-in browser automation, a
cron scheduler, a multi-platform messaging gateway, and — critically —
native (non-proxied) support for local Ollama plus Anthropic, OpenAI, and
Hugging Face as cloud providers. The only gaps against requirements were
purchasing (not native anywhere) and bootable-USB imaging (not an agent
framework concern at all, an OS/imaging concern) — both are addressed by a
thin custom layer rather than needing a different framework.

**Consequences**: This repo's architecture is entirely shaped by Hermes's
CLI, config schema, and installer conventions. Any Hermes upstream breaking
change (config schema, installer behavior, CLI flags) is a direct risk to
this repo. Hermes's fast growth (175k+ GitHub stars in under 4 months as of
this research) suggests active development and potential churn.

**Future implications**: If Hermes is ever abandoned upstream or a critical
blocker is found, most of `overlay/` (config profiles, install scripts)
would need to be rewritten for a new framework, but the *requirements* and
*decisions* in this log (provider policy, purchase deferral, USB approach,
profile structure) would largely transfer.

---

## ADR-0002: Defer purchase-making capability

**Decision**: Do not build any purchase/payment capability in v1. Reserve an
architectural slot (documented, unwired) for a future purchase skill.

**Context**: One of the owner's original requirements was that the agent
"make purchases." This is the highest-risk capability in the entire
project — it involves real money, real external accounts, and (if built
carelessly) real credential storage.

**Alternatives considered**:
1. **Hard human gate** — agent can browse/compare/fill carts, but every
   payment submission requires explicit human confirmation (e.g. a
   Telegram/Slack approve prompt) before checkout completes; no stored
   payment credentials.
2. **Pre-approved rules + spend cap** — agent can autonomously complete
   purchases under a defined dollar cap and category allowlist (e.g.
   reordering supplies) without per-purchase confirmation; anything above
   cap or outside allowlist requires approval.
3. **Defer entirely** — design a slot for it, build nothing.

**Why this option was selected**: The owner explicitly chose "defer" when
presented with all three options. No reasoning beyond the explicit choice
was recorded in conversation, but it's consistent with the broader
local-first / manual-approval philosophy applied to cloud providers later
in the conversation (ADR-0005) — the owner's evident preference throughout
this project is to gate anything involving spend or external
irreversible action behind explicit, in-the-moment human action rather than
pre-authorized automation.

**Consequences**: `overlay/skills/custom/README.md` explicitly warns against
putting credentials or payment integrations in any skill. No purchasing
code exists anywhere in this repo. The capability gap is documented (not
hidden) in `README.md`'s capability matrix and `docs/current-state.md`.

**Future implications**: When the owner revisits this, option 1 (hard human
gate) is the natural next step given the pattern established by ADR-0005 —
but this should be a fresh, explicit conversation with the owner, not an
autonomous implementation decision by a future Claude instance. Do not
build toward this speculatively (see CLAUDE.md constraints).

---

## ADR-0003: Repo strategy — intended "fork + overlay," actually implemented as "thin wrapper"

**Decision (as stated by owner)**: Fork `NousResearch/hermes-agent` and keep
upstream as a git remote to track releases, with customizations layered in
a separate `overlay/` directory (chosen over "vendor a full copy" and "thin
wrapper repo only").

**What was actually built**: A **thin wrapper repo** (`sheridanwendt/kilo`)
that contains only `overlay/`-style content at its root (install scripts,
config profiles, custom skills, docs) and installs Hermes via upstream's own
official curl installer at install time. There is no git fork relationship,
no `upstream` remote, and no vendored Hermes source anywhere in this repo.

**Context**: This discrepancy was discovered and flagged (not hidden) when
`PROJECT_PLAN.md` was written — see the note at the top of that file. It
happened because Hermes's own installation model (a self-contained curl
installer that clones/manages its own copy of itself, plus `hermes update`
for staying current) doesn't actually require or benefit from *this* repo
also containing a git-level fork of Hermes's source. The "fork + overlay"
answer was chosen when the question was framed abstractly, before the
concrete mechanics of Hermes's installer were being worked with directly.

**Alternatives considered** (re-litigated after the fact): 
1. **Fork + overlay** (originally chosen) — would mean this repo (or a
   sibling repo) contains a full checkout of `NousResearch/hermes-agent`
   with an `upstream` remote, plus this overlay content layered in.
2. **Vendor a full copy** — same as above but decoupled from upstream
   entirely (no remote), full manual merge responsibility.
3. **Thin wrapper repo only** — what actually exists: no Hermes source in
   this repo at all, install-time reference to upstream via its installer.

**Why the thin-wrapper outcome is being kept rather than corrected**: It
still achieves update-ability — `hermes update` talks to upstream directly
and is independent of any git relationship this repo has (or doesn't have)
with `NousResearch/hermes-agent`. It has less to maintain (no merge
conflicts between a vendored fork and upstream releases) and matches how
Hermes is actually designed to be installed and kept current by its own
authors. The tradeoff is `overlay/UPSTREAM_VERSION` is documentation only,
not an enforced pin — see `docs/open-questions.md`.

**Consequences**: No true reproducibility guarantee against a specific
upstream Hermes version — `install.sh` always installs "whatever upstream's
installer currently installs" unless a future change adds real pinning
(e.g., cloning `NousResearch/hermes-agent` at a specific tag ourselves — see
`docs/future-ideas.md`).

**Future implications**: Do not silently "fix" this back to a real fork
without discussing it with the owner — see CLAUDE.md constraints. If
reproducibility against a pinned upstream version becomes a real problem in
practice, that's the trigger to revisit this ADR, not a hypothetical
concern now.

---

## ADR-0004: Bootable USB approach — single Ventoy multi-boot drive

**Decision**: Build one Ventoy-based USB drive carrying a persistent Ubuntu
image with Ollama + a preloaded local model + Hermes pre-configured for the
`usb-offline` profile.

**Context**: Original requirement: "supports an instance on a bootable USB
to be device agnostic, possibly multiple USBs."

**Alternatives considered**:
1. **Single Ventoy multi-boot drive** (chosen) — one USB, Ventoy-managed,
   persistent casper/overlay image, room to add more ISOs later.
2. **Multiple purpose-built USBs** — separate dd-flashed persistent Ubuntu
   images per drive, potentially with different roles/configs per drive
   (e.g. "travel assistant" vs "homelab ops agent").
3. **Not a near-term priority** — document as a target, defer actual
   build work.

**Why this option was selected**: Owner's explicit choice. Simpler to
maintain and update one image; the image itself (Ventoy's persistence data
file) is the single artifact that needs to be kept current and can be
copied to additional physical drives later if a second one is ever needed,
without maintaining divergent per-drive builds.

**Consequences**: `overlay/iso-usb/README.md` documents the Ventoy-based
process. `overlay/iso-usb/build-image.sh` does not exist yet — the README
is a manual-steps outline, not an automated script (Project Plan step 16).
If the owner does eventually want purpose-built divergent USBs (different
roles per drive), that's a bigger change than just copying the Ventoy image
and would need its own design pass.

**Future implications**: The README already documents a fallback path (plain
dd-flashed persistent image) "if Ventoy's persistence proves too fragile
across very different host hardware" — this was anticipated as a realistic
risk at design time, not discovered later. If that risk materializes,
re-open this ADR rather than silently switching approaches.

---

## ADR-0005: Provider policy — local-first default, cloud by manual approval only; drop OpenRouter and Nous Portal

**Decision**: Local Ollama is the only default, always-active provider,
configured identically across every profile. Anthropic (native), OpenAI
(Codex OAuth or direct API key), and Hugging Face (native) are configured
with credentials available but are never auto-selected — switching to any
of them requires an explicit `hermes model` or `/model` command from the
user. No `fallback_providers:` entry routes to any cloud provider.
OpenRouter and Nous Portal are excluded from the design entirely.

**Context**: This decision was made in a follow-up turn after the initial
architecture doc was drafted (which had originally listed Nous Portal and
OpenRouter as available cloud options among others). The owner clarified
the actual requirement: "run offline for free with local LLMs, with the
option of using cloud-based inference providers (openai, anthropic,
huggingface, etc.)... The offline (free local LLM) provider(s) should be
prioritized and the default option, only switching to a cloud option
manually or specific tasks when approved by me." The owner also explicitly
asked whether OpenRouter/Nous Portal were even needed and whether they could
run offline.

**Alternatives considered**:
- Keep OpenRouter and/or Nous Portal in the provider list as additional
  cloud options (rejected — neither works offline, i.e. in airplane mode;
  both are redundant given native support exists for the three cloud
  providers the owner actually named).
- Use Hermes's `fallback_providers:` mechanism to auto-fail over to a cloud
  provider on local errors (rejected — this would spend cloud credits
  without explicit per-instance approval, directly violating the stated
  requirement; a technical failure of the local model should not silently
  become a cloud API call).
- Route OpenAI access exclusively through "OpenAI Codex" OAuth (rejected as
  the *only* path — kept as one option, but a direct `OPENAI_API_KEY` via
  Hermes's Custom Endpoint flow against `api.openai.com/v1` was documented
  as the alternative, since OpenAI's API is natively OpenAI-shaped and needs
  no special provider ID).
- Route Anthropic access through the (researched) Anthropic OpenAI-compatible
  endpoint (launched March 2026, `api.anthropic.com/v1`, OpenAI-SDK
  compatible) — rejected as unnecessary, since Hermes has genuine *native*
  Anthropic support (not proxied through an OpenAI-compatibility shim),
  which additionally avoids that compatibility layer's documented
  limitations (no prompt caching, no extended thinking, capped temperature,
  concatenated system messages — it's positioned by Anthropic as a
  testing/eval convenience, not a production-parity path).

**Why this option was selected**: Directly satisfies the owner's explicit,
restated requirement. Native Anthropic/OpenAI/Hugging Face support in
Hermes made OpenRouter and Nous Portal genuinely redundant, not just
undesirable — there was no capability lost by dropping them.

**Consequences**: `overlay/config-profiles/default.yaml` sets
`model.provider: custom` / `base_url: http://localhost:11434/v1` as the only
active provider config, with cloud credentials documented as expected in
`~/.hermes/.env` but never referenced by the active `model:` block. No
`fallback_providers:` block exists anywhere in this repo's config. This is
called out as a "never change without review" item in `CLAUDE.md`.

**Future implications**: If the owner later wants *automatic* resilience
(e.g., "if local Ollama is down, do something sensible"), the correct
design under this ADR is local-only fallback (a second local model) or an
explicit new opt-in, not silently reintroducing cloud auto-routing. This
should get its own ADR if/when it happens.

---

## ADR-0006: Ubuntu Server for always-on profiles, Desktop acceptable only for the USB profile

**Decision**: Recommend and design around Ubuntu Server for `on-prem` and
`cloud-server` profiles. Ubuntu Desktop is acceptable (not required) for the
`usb-offline` profile only.

**Context**: Owner asked directly: "Should I use ubuntu desktop or server?"

**Alternatives considered**: Desktop everywhere (rejected — unnecessary
resource overhead competing with local model RAM/CPU budget on always-on
boxes; Hermes doesn't need a GUI since it's CLI/messaging-gateway driven and
its browser automation runs headless Chromium). Server everywhere (rejected
for the USB case specifically — the point of a walk-up USB is ease of use
on unfamiliar hardware, and a GUI meaningfully lowers the bar for wifi setup
and terminal access for a non-expert user in that specific scenario).

**Why this option was selected**: The two profiles have genuinely different
usage patterns (always-on unattended server vs. occasional walk-up-and-use
device), so it was treated as a legitimate profile-level split rather than
a single universal answer.

**Consequences**: `overlay/iso-usb/README.md` already reflects this (allows
either Ubuntu Server or Desktop ISO for the USB build). No enforcement
exists anywhere (this is guidance, not a check in any script) — a future
Claude instance building the actual Ventoy image script should default to
Desktop for `usb-offline` per this ADR unless told otherwise.

**Future implications**: A hybrid (Server + a minimal desktop environment
layered on afterward) was mentioned as a possible middle ground but not
pursued or designed.

---

## ADR-0007: Native Windows out of scope; WSL2 is the supported Windows path

**Decision**: Do not attempt to support native Windows. WSL2 is the only
Windows deployment path.

**Context**: This is inherited directly from upstream Hermes Agent, which
documents native Windows support as "experimental" and directs users to
WSL2. Not an independent decision by this project — a constraint accepted
from upstream.

**Alternatives considered**: None seriously — building/maintaining native
Windows support independent of upstream's own stance would be significant
effort for a capability upstream itself doesn't stand behind.

**Why this option was selected**: Follows upstream's own guidance; avoids
maintaining a support path upstream doesn't consider production-ready.

**Consequences**: Project Plan step 15 tests "macOS and WSL2 for Windows,"
not native Windows. `README.md` and `CLAUDE.md` both state this explicitly
so it isn't mistaken for an oversight later.

**Future implications**: If upstream ever graduates native Windows support
out of "experimental," this ADR should be revisited.

---

## ADR-0008: Boot autostart via systemd, with explicit ordering and a context-length override

**Decision**: Register both Ollama and Hermes as systemd services
(`ollama.service`, `hermes-gateway.service` via `hermes gateway install
--system`), with a systemd drop-in forcing `hermes-gateway` to start
`After=`/`Requires=` `ollama.service`. Separately, force
`OLLAMA_CONTEXT_LENGTH=65536` via another systemd drop-in on
`ollama.service`.

**Context**: New requirement added mid-project: "I'd like the agent to
start automatically, at boot (local LLM default)." Research into Hermes's
own gateway-install command revealed both a user-service mode (needs
`loginctl enable-linger`, auto-enabled by the install command) and a
system-service mode (`--system`, for VPS/headless hosts, survives reboot
without depending on any user session). Separately, research into Ollama's
behavior surfaced that it truncates context by default and doesn't expose
its full context window unless `OLLAMA_CONTEXT_LENGTH` is set, which
conflicts with Hermes's documented minimum of ≥64k tokens of context for
reliable tool-calling.

**Alternatives considered**: User-level systemd service with linger
(rejected as the default — system-level is more appropriate for the
always-on `on-prem`/`cloud-server` profiles this repo primarily targets,
per Hermes's own docs recommending `--system` for headless/VPS hosts). No
explicit systemd ordering between the two services (rejected — without it,
Hermes could start before Ollama is ready to accept connections, especially
on a slow-booting or resource-constrained machine, causing spurious startup
failures).

**Why this option was selected**: Matches Hermes's own documented guidance
for headless/server deployments, and directly solves a real correctness
problem (context truncation) discovered during research, not just a
theoretical concern.

**Consequences**: `overlay/install/04-enable-autostart.sh` implements the
ordering drop-in; `overlay/install/01-install-ollama.sh` implements the
context-length drop-in. Both are called out in `CLAUDE.md` as things that
should not be removed or lowered without review.

**Future implications**: If a profile ever needs to run without `sudo`
access (e.g., a restricted shared host), the system-service approach won't
work and this ADR would need revisiting for a user-service + linger
fallback.

---

## ADR-0009: Config merging via Python + PyYAML deep merge, not bash/yq/templating

**Decision**: `overlay/install/03-apply-profile.sh` shells out to an inline
Python script (using `pyyaml`, auto-installed with
`pip install --break-system-packages` if missing) to deep-merge
`default.yaml` with the selected profile YAML into `~/.hermes/config.yaml`.

**Context**: Profiles need to override/extend a shared base config without
duplicating the entire file per profile. Bash has no good native YAML
handling.

**Alternatives considered**: `yq` (a Go-based YAML CLI tool) — would add an
external binary dependency not otherwise needed; rejected in favor of
Python, which Hermes's own installer already requires (Python 3.11), so
it's not a genuinely new dependency. Plain file concatenation — rejected,
doesn't support real overriding of nested keys, only appending, which
doesn't match how profile overrides are actually used (e.g. `gateway:`
blocks need to fully replace, not merge oddly with, any `gateway:` key in
the base). Jinja2/templating — rejected as unnecessary complexity for what
is fundamentally a two-file merge, not a many-variable substitution problem.

**Why this option was selected**: No new hard dependency (Python is already
required by Hermes itself), correct nested-dict merge semantics, and simple
enough to inline in the shell script rather than needing its own file.

**Consequences**: Requires `python3` on the target machine (already
guaranteed by the time this script runs, since `02-install-hermes.sh` has
already run Hermes's installer, which itself requires Python 3.11).
Existing `config.yaml` is backed up with a timestamp before being
overwritten, specifically to protect against clobbering manual
`hermes model`/`hermes gateway setup` wizard changes.

**Future implications**: If profile logic ever needs to be more than a
static merge (e.g., conditional keys based on detected hardware), this
inline script would need to grow into a real Python module rather than a
heredoc — worth watching for.

---

## ADR-0010: GitHub push mechanism — fine-grained PAT, no connector available

**Decision**: Push this repo to GitHub using a fine-grained Personal Access
Token supplied directly by the owner in chat, scoped to only the
`sheridanwendt/kilo` repository with `Contents: Read and write` permission,
short expiration. Used once within the Cowork sandbox session to set an
authenticated remote URL, push, then immediately strip the token back out
of local git config.

**Context**: The owner asked for code to be pushed to a GitHub repo they
created (`sheridanwendt/kilo`). The Cowork environment was checked for an
existing GitHub MCP connector or installable plugin — none was found in
either the connector registry or the plugin directory at the time. No
`gh` CLI, SSH key, or credential helper was present in the sandbox either.

**Alternatives considered**: Ask the owner to push manually from their own
machine using commands provided by the assistant (this was the *first*
offered option, and remains a valid fallback — see the conversation
history/`docs/current-state.md` for the exact commands). The owner instead
asked how to grant direct access, leading to the PAT approach.

**Why this option was selected**: No connector-based option existed to
offer. A narrowly-scoped, short-lived PAT is the standard, lowest-blast-
radius way to grant a single-repo write capability to an agent session that
has no persistent credential storage.

**Consequences**: The token was pasted in the conversation transcript (an
inherent exposure of using this method) — the owner was advised to revoke
or let it expire after use. It is not stored anywhere in this repo, in the
sandbox's persistent filesystem, or in any file that was written to the
owner's synced output folder. Any future Claude instance needing to push to
this repo again will need a fresh credential from the owner — there is no
standing access.

**Future implications**: If push access is needed routinely (not just for
occasional handoffs), a real GitHub App/connector integration would be a
better long-term solution than repeated one-off PATs — worth suggesting to
the owner if this pattern recurs. See `docs/future-ideas.md`.

---

## ADR-0011: Repo root is the overlay content directly, not nested under a subdirectory

**Decision**: The GitHub repo `sheridanwendt/kilo`'s root directly contains
`README.md`, `CLAUDE.md`, `install.sh`, `overlay/`, `docs/`, etc. — there is
no top-level `hermes-personal-assistant/` wrapper folder inside the repo,
even though that was the local working-directory name used while building
it.

**Context**: During scaffold construction, files were assembled locally
under a directory literally named `hermes-personal-assistant/` for clarity
during the build process (before a GitHub repo existed to push to). When
the repo was pushed, the *contents* of that directory were used as the git
repo root, not the directory itself, so the naming artifact doesn't leak
into the actual repo structure.

**Alternatives considered**: None deliberately — this is a documented
implementation detail so a future Claude instance isn't confused if it
encounters references to a `hermes-personal-assistant/` path in earlier
design docs (e.g. `ARCHITECTURE.md`'s repo-layout diagram shows this name)
and expects to find a matching subdirectory in the actual repo. There isn't
one — the repo root *is* that content.

**Why recorded**: Purely to prevent confusion. See `docs/file-structure.md`
for the authoritative current layout.

**Consequences**: None functional. Purely a documentation/expectation-
alignment note.

**Future implications**: None.

---

## ADR-0013: Stale-checkout self-detection guard in `install.sh`, plus a regression fix

**Decision**: `install.sh` now runs two guards before doing any real work:
(1) an inline `ensure_core_tools` check that installs `curl`/`git` via apt if
either is missing, redundant with but independent of
`overlay/install/00-install-prereqs.sh`; (2) a `check_for_stale_checkout`
guard that fetches `origin/main` and, if the local checkout is a strict
ancestor of it (i.e., genuinely behind, not just diverged), prints a clear
explanation and exits rather than proceeding with old code.

**Context**: The owner ran the previous commit's `install.sh` on real
hardware (`kilo@stick`) and hit `curl: command not found` — but not because
the fix from ADR-0012 was wrong. `git clone` had failed silently (target
directory already existed, non-empty, from an earlier attempt) and `cd kilo`
dropped into that stale, pre-fix checkout. The owner asked for `install.sh`
itself to be hardened against this class of mistake recurring.

**A real limitation, found while validating this fix**: `sheridanwendt/kilo`
is a **private** repository. An anonymous `git fetch` against a private repo
fails immediately with an auth error (`could not read Username for
'https://github.com': No such device or address`) rather than a clean
network-timeout signal. The guard treats any fetch failure as "can't check,
proceed anyway" (fail open, not fail closed — an installer should not hard-
block on a network hiccup). **Practical consequence: this guard only
actually engages on a machine that has git credentials cached for this repo**
(SSH key, `gh auth login`, or a stored credential helper entry) or if the
repo is later made public. On a machine with no such credentials, the
checkout-staleness check silently no-ops every time — safe, but not the
strong guarantee it might first appear to be. This is called out explicitly
in the script's own comments and here, rather than left for someone to
discover the hard way.

**Alternatives considered**: Make the fetch failure fatal (block install
entirely if staleness can't be verified) — rejected, since it would brick
the install for the very common case of no cached git credentials, which is
worse than the problem being solved. Require the repo to be public —
rejected as out of scope for this ADR (repo visibility is the owner's call,
not something to change as a side effect of an installer robustness fix).
Skip the guard entirely and rely on documentation alone (e.g., README
instructions for a clone-or-pull one-liner) — rejected as insufficient on
its own, since the whole point is that people (understandably) don't always
follow the README's fine print; a self-check in the code that runs
regardless of which instructions were followed is a stronger guarantee than
documentation alone, even with the credentials caveat.

**Also fixed as part of this same pass (regression, not new work)**: while
validating this fix, a comparison against the actually-pushed commit
revealed that `install.sh`'s header comment had regressed back to the
placeholder clone URL (`<you>/hermes-personal-assistant.git`) instead of
the real one (`sheridanwendt/kilo.git`) — a leftover from an earlier merge
(see ADR-0011/the "Merge remote README/install.sh URL fixes" commit) that
didn't get carried forward correctly when a later commit was assembled by
copying files from one working copy into another. The same stale placeholder
was also found, never having been fixed at all, in
`overlay/docs/runbook.md` and `overlay/iso-usb/README.md`. All three are
corrected in this commit.

**A tooling note for whoever works on this repo next in a similar
assistant-driven environment**: while making this fix, the assistant's own
sandbox exhibited a caching bug where a file (`install.sh`) that had already
been read via shell commands earlier in the session stopped picking up
subsequent content changes made through the assistant's file-editing tool,
even though the tool reported success — while files not yet read via the
shell picked up changes immediately. The workaround was writing to a new,
never-before-read filename and copying that into place for the actual git
commit. This is an environment quirk of that assistant session, not a
property of this repository or its scripts, but is recorded here in case a
similar discrepancy (edits that don't seem to "take" when inspected via
shell, despite a successful-looking edit) recurs in a future session.

**Consequences**: `install.sh` is now more defensive in two independent ways
(core-tool bootstrap, staleness detection), plus a real regression is fixed.
Verified: `bash -n` syntax check on all scripts, and the staleness-detection
core logic (`merge-base --is-ancestor` comparison) validated against a
throwaway local git repo with two synthetic commits standing in for
local/remote state, confirming both the "correctly flags a stale checkout"
and "correctly does not flag an up-to-date checkout" cases. **Not yet
validated**: an actual end-to-end run of the fetch path against the real
`sheridanwendt/kilo` remote with real cached credentials — that still
belongs to Phase 1 real-hardware testing.

**Future implications**: If the owner ever makes this repo public, the
staleness guard becomes unconditionally effective for anyone (no
credentials needed for anonymous fetch of a public repo), which is a
straightforward improvement with no action needed on the script's part.
