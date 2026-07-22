# Security

## Threat model

This is a personal, single-user, single-operator system. The relevant
threats are not "external attacker targeting a multi-tenant service" but:

1. **The agent itself doing something costly or irreversible without
   authorization** — spending money via a cloud LLM API without approval,
   or (if ever built) making a purchase without approval. This is the
   threat the entire provider-policy design (ADR-0005) and purchase
   deferral (ADR-0002) exist to address.
2. **Credential exposure** — cloud provider API keys, OAuth tokens, or a
   GitHub PAT leaking via the repo, logs, or an agent skill.
3. **Supply-chain / upstream trust** — this project runs code from
   `NousResearch/hermes-agent`'s installer, from Ollama's installer, and
   from whatever models get pulled. This repo does not audit that code; it
   trusts upstream's own security posture (relevant given Hermes states
   "no tracking, zero telemetry" as a design principle, which was a factor
   in initial framework selection but was not independently verified).
4. **Physical access** (specifically for the USB profile) — a
   walk-up-and-use USB drive is a different threat surface than an always-on
   server the owner controls physically. Not deeply addressed yet — see
   Open items below.

Not in scope: protecting against a sophisticated remote attacker, multi-user
permission boundaries, or compliance/regulatory requirements (this is a
personal project, not a product with external users).

## Authentication

- **To the agent itself**: whatever Hermes's messaging gateway platforms
  provide natively (Telegram/Slack/etc. account-level auth) or local shell
  access for the CLI. This repo does not add any authentication layer on
  top of Hermes's own.
- **To cloud LLM providers**: OAuth (Anthropic Max, OpenAI Codex, etc.) or
  API keys, entirely managed by Hermes's own `hermes model` wizard and
  stored in `~/.hermes/auth.json` / `~/.hermes/.env`. This repo never
  generates, stores, or transmits these credentials itself — it only
  documents where the operator should put them.
- **To GitHub** (for pushing this repo): no standing credential. See
  "Secrets handling" below for the one-time PAT precedent.

## Authorization

There is no role/permission system anywhere in this project — a single
operator (the owner) has full control of their own instance(s). The only
"authorization" concept that exists is the **manual-approval gate** pattern
used for cloud provider switching (ADR-0005) and planned for instance
provisioning (`instance-provision` skill, not yet built) — these aren't
authorization in the access-control sense, they're deliberate friction
points requiring an explicit, in-the-moment human action before a
consequential operation proceeds.

## Secrets handling

- **`.gitignore`** excludes `.env`, `*.env`, and `.hermes/` at the repo
  root — these must never be committed. Any new file type that could
  contain secrets (e.g. a future credentials cache) must be added to
  `.gitignore` before it's ever written, not after.
- **Cloud provider credentials** live only in `~/.hermes/.env` and
  `~/.hermes/auth.json` on the target machine, populated manually by the
  operator. This repo's install scripts never read, write, or transmit
  these.
- **GitHub PAT precedent** (see `docs/decisions.md` ADR-0010): when this
  repo needed to be pushed for the first time, no persistent credential
  mechanism was available in the agent's environment (no connector, no `gh`
  CLI, no SSH key). The owner supplied a fine-grained PAT, scoped to only
  this one repo with `Contents: Read and write`, directly in the
  conversation. The agent used it within a single sandboxed session by
  embedding it in the git remote URL, pushed, then **immediately ran `git
  remote set-url` to strip the token back out of local git config**, and
  never wrote it to any file in the user's synced output folder. The owner
  was advised to revoke/let the token expire after use, since it had been
  exposed in the chat transcript by necessity of that method. **This is the
  reference pattern for any future one-off credential need**: narrowest
  possible scope, shortest possible lifetime, used once, scrubbed
  immediately, never persisted.
- **General principle for any future skill or script**: never write a
  secret to a location that syncs to a user-visible/output folder if a
  purely ephemeral (session-scratch) location will do instead.

## Encryption

- No encryption is implemented or required by this repo directly.
- `overlay/docs/runbook.md` advises operators to keep `~/.hermes` backups
  "off the machine itself (encrypted, on separate storage)" — this is
  operator guidance, not something this repo automates or enforces. If
  automated encrypted backup is ever wanted, it doesn't exist yet (see
  `docs/future-ideas.md`).
- Disk-at-rest encryption (e.g. LUKS on the target Ubuntu install, or
  whatever the USB drive's persistence layer uses) is entirely outside this
  repo's scope — an OS-level operator decision, not addressed anywhere in
  current scripts or docs.

## Input validation

- `install.sh` validates `--profile <name>` against the actual files present
  in `overlay/config-profiles/` (fails with a clear list of valid options
  if the name doesn't match a file) — the only real "input validation" in
  this repo, since there's no user-facing application accepting arbitrary
  input.
- No validation exists for the *content* of a modified `config.yaml` or
  profile file — if an operator (or a future Claude instance) hand-edits a
  profile to something that would violate the provider policy (e.g. adding
  a `fallback_providers:` block pointing at a cloud model), nothing in this
  repo would currently catch or prevent that. This is a real gap — see
  `docs/backlog.md` for a suggested "policy lint" check.

## Security assumptions

- The operator has full physical/administrative control of the target
  machine (has `sudo`, chooses what's plugged in, etc.) — this repo does
  not defend against a compromised or adversarial local operator, only
  against the *agent itself* overstepping its authorized scope.
- Upstream Hermes Agent and Ollama's installers are trusted as-is; this
  repo does not vet, pin, or sandbox them beyond what's documented (no
  container isolation is configured for the `on-prem` profile — Hermes runs
  with the operator's own user/system privileges via systemd).
- The USB profile's physical-access threat model (someone other than the
  owner plugging in and using the drive) has not been deeply designed —
  flagged as an open item below rather than glossed over.

## Security best practices established in this project

- **No automatic cloud spend** (ADR-0005) — treated as a security property,
  not just a cost-control preference, because it prevents the agent from
  taking an unbounded-cost action without a human in the loop.
- **No stored payment credentials anywhere** (ADR-0002) — purchasing is
  deferred specifically because it's the highest-risk capability in the
  original requirements.
- **Scoped, short-lived credentials over standing access** whenever a
  credential is genuinely needed (the GitHub PAT precedent).
- **Explicit human confirmation as the security boundary** for
  consequential actions (provider switching now; instance provisioning
  once `instance-provision` is built), rather than a technical
  allow/deny-list that could be misconfigured or bypassed.
- **Secrets never committed**, enforced via `.gitignore` from the very
  first commit, not retrofitted later.

## Open items (not yet addressed, flagged rather than ignored)

- No "policy lint" exists to catch a future accidental
  `fallback_providers:` cloud entry or similar drift from the provider
  policy — purely a documentation/discipline guard right now (`CLAUDE.md`),
  not a technical one.
- No container-level hardening (read-only root, dropped capabilities, PID
  limits — mentioned as a Hermes-native Docker feature in early research)
  has actually been configured or verified in this repo's Docker path yet;
  Project Plan step 12 ("security hardening pass") is where this should
  happen, and it hasn't happened yet.
- USB physical-access threat model is underdeveloped — if the USB is ever
  used by someone other than the owner, or lost/stolen, there's no
  documented mitigation (e.g. no disk encryption requirement, no
  session/credential expiry specific to that profile). Worth a dedicated
  design pass before the USB image is treated as "done."
- No documented incident-response plan (e.g. "what do I do if a cloud API
  key leaks" beyond the general advice to rotate it) — reasonable for a
  personal project's current stage, but worth a short runbook addition
  eventually.
