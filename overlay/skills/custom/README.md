# Custom skills

Drop your own `SKILL.md` files here (one directory per skill, following the
`agentskills.io` open standard Hermes already speaks natively). These are
copied into Hermes's skill search path during install so they're available
alongside the 40+ built-in skills and anything Hermes auto-creates.

Suggested first skills to build (Project Plan step 7):

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
