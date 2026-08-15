# Custom skills

Drop your own `SKILL.md` files here (one directory per skill, following the
`agentskills.io` open standard Hermes already speaks natively). These are
copied into Hermes's skill search path (`~/.hermes/skills/custom/`) by
`overlay/install/05-install-custom-skills.sh` during install, so they're
available alongside the 40+ built-in skills and anything Hermes
auto-creates. That target path is a best-effort assumption, not yet
confirmed on real hardware — see `docs/open-questions.md`.

Built so far:

- `inbox-triage/` — Gmail triage policy (via Composio): sender/subject-
  pattern rules that map to label/archive/unsubscribe/delete actions, with
  a human-approval gate for anything new or destructive. `SKILL.md` is the
  compact runtime card; `reference/first-principles.md` and
  `reference/policy-set-v1.1.md` hold the full rationale and are loaded on
  demand rather than every session. Content-complete but **not yet run
  against a real Gmail inbox** — see `docs/open-questions.md` and
  `docs/testing.md` before treating it as validated.

Suggested next skills to build (Project Plan step 7):

- `instance-health/` — a status/health-check skill: reports which model
  provider is active, whether Ollama is reachable, disk/memory headroom,
  and last-backup timestamp for `~/.hermes`. Useful for confirming a fresh
  install or USB boot came up correctly.
- `instance-provision/` — the human-in-the-loop "new instance" helper
  (Project Plan step 18): walks through profile selection, prints a summary
  of what will be installed, and requires an explicit typed confirmation
  before running `install.sh`.

Do not put credentials or payment integrations in any skill here — the
purchase-making capability is intentionally deferred (see architecture doc).
