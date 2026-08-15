# Testing

## Testing philosophy

This project's core risk isn't logic bugs in the shell scripts (they're
simple and syntax-checked) — it's **unverified assumptions about an
external system's behavior** (Hermes's config schema, Ollama's context
handling, systemd/launchd/WSL2 boot semantics, Ventoy persistence across
hardware). Testing philosophy follows from that: prioritize real-execution
validation on real targets over unit-testing shell script logic in
isolation. A shell script that parses its arguments correctly but installs
against a wrong config schema has "passed" a unit test and still failed the
project.

**As of this handoff, zero real-execution testing has occurred.** Every
"done" item in `docs/current-state.md` is done in the "written and
internally reviewed" sense only.

## What "done" means for a Project Plan step

A step in `PROJECT_PLAN.md` should only be checked off once it has been:
1. Actually run on the target it claims to support (not just written).
2. Observed to produce the claimed outcome (not assumed from reading the
   script).
3. Had any discovered schema/assumption errors fixed, with the fix recorded
   in `docs/open-questions.md` (moved from open to resolved) and, if it
   changes an architectural assumption, a note added to the relevant ADR in
   `docs/decisions.md`.

Do not check a box because the corresponding script exists and looks
correct.

## Required test coverage by layer

### Install scripts (`overlay/install/*.sh`)

- **Idempotency test**: run `install.sh` twice in a row on the same clean
  machine; second run must not error and must leave the system in the same
  state as after the first run. This is an explicit requirement (see
  `CLAUDE.md`), not optional.
- **Fresh-machine test**: run on a genuinely clean OS install (not a
  machine that's had manual fixes applied) — this is the only way to
  catch implicit assumptions about pre-existing tools/state.
- **`--update` mode test**: run once fully, then run again with `--update`;
  confirm it does not redo OS-level setup and does correctly re-apply
  profile changes.
- **`--skip-autostart` test**: confirm the flag actually skips step 4 and
  that the rest of the install still functions (relevant for USB image
  building, where autostart may need to be configured differently).

### Config correctness (highest priority — see `docs/open-questions.md`)

- After `03-apply-profile.sh` runs, **diff the generated
  `~/.hermes/config.yaml` against what `hermes model` / `hermes gateway
  setup` would generate interactively** for the same intended settings.
  This is the single most important test in the whole project right now —
  it's how the unconfirmed schema assumptions in
  `overlay/config-profiles/*.yaml` get validated or corrected.
- Confirm `hermes` actually starts and successfully makes a tool-calling
  request against local Ollama using the generated config, with networking
  disabled (true offline test, not just "no cloud key configured").
- Confirm a manual `/model anthropic:...` (or openai/huggingface) switch
  works using credentials placed in `~/.hermes/.env`, and confirm that
  *without* that manual switch, no cloud request is ever made (this is the
  test for ADR-0005's core guarantee — arguably deserves an explicit,
  repeatable check rather than a one-time manual verification, e.g.
  network-traffic monitoring during a normal offline session to confirm
  zero outbound calls to any cloud provider domain).

### Boot / autostart

- Full reboot test (not just `systemctl start`) on `on-prem`/`cloud-server`
  targets: power-cycle or `reboot`, then confirm both `ollama.service` and
  `hermes-gateway.service` are active, in the correct order, with no manual
  intervention.
- Explicitly test with networking disabled at boot, to confirm the "starts
  automatically, local LLM default" requirement holds even in the airplane-
  mode scenario the owner cares about.
- macOS: once a real launchd implementation exists (currently just a
  warning — see `docs/current-state.md`), test actual login/boot behavior,
  since launchd's semantics (user vs. system daemons, login-item vs.
  boot-time) differ meaningfully from systemd's.
- WSL2: needs a testing plan designed alongside the (currently
  nonexistent) autostart design — see `docs/implementation-plan.md` Phase
  3.

### Docker path

- Full `docker compose up -d` → verify Hermes container can reach the
  sidecar Ollama container (this test *is* how the open TODO about
  `HPA_OLLAMA_BASE_URL` vs. mounted config gets resolved — write the test
  first, let it tell you which mechanism actually works).
- Teardown-and-rebuild test on a fresh VM (explicitly named as the "Docker
  path" acceptance criterion in the original design conversation).

### USB image

- Boot on at least two physically different machines (this is the actual
  acceptance test for "device agnostic" — booting once on the machine you
  built it on proves nothing about portability).
- Test with no network available at all on second/third boots, confirming
  the offline-after-first-setup design goal.

### Skills

- `instance-health`: verify it accurately reports active provider, Ollama
  reachability, disk/memory headroom, last backup timestamp — test against
  both a healthy and a deliberately broken instance (e.g. Ollama service
  stopped) to confirm it actually detects problems, not just happy-path
  output.
- `instance-provision`: verify the human-confirmation step actually blocks
  execution until explicit confirmation — this is a security-relevant
  behavior (the human-in-the-loop gate is the whole point of this skill),
  so test the "user does not confirm" path as carefully as the "user
  confirms" path.
- `inbox-triage`: two independent things need validating before this is
  "done," not just written:
  1. **Install wiring**: after `install.sh` runs, confirm Hermes actually
     discovers the skill at `~/.hermes/skills/custom/inbox-triage/` (see
     `docs/open-questions.md` #11) and loads `reference/*.md` on demand
     rather than every session.
  2. **Policy correctness**: run it against a real (or realistic sample)
     Gmail inbox via Composio and check each precedence tier fires
     correctly — especially the P3 high/low-confidence split and the P4
     "never autonomous" guarantee, since those are the destructive/
     highest-risk paths. Confirm the canary-period (log-only first batch)
     behavior actually withholds action, not just logs alongside it.

## Unit / integration / end-to-end split

Given the nature of this project:
- **"Unit" level** ≈ `bash -n` syntax checks (already done for all
  scripts) plus, if the Python config-merge logic grows more complex,
  actual unit tests for the `deep_merge` function in isolation (currently
  simple enough that this hasn't been deemed necessary, but worth adding if
  it grows conditional logic).
- **"Integration" level** ≈ running individual `overlay/install/*.sh`
  scripts against a real (but disposable, e.g. VM snapshot) machine and
  checking their direct outputs (files written, services enabled).
- **"End-to-end" level** ≈ full `install.sh` runs plus actual agent
  interaction (chat, tool call, provider switch, reboot) — this is where
  most of the real risk in this project lives, per the testing philosophy
  above, and should get proportionally more attention than unit-level
  testing.

## Regression testing

No regression suite exists yet. Once Phase 1 (`docs/implementation-plan.md`)
establishes a working baseline, the config-correctness and offline-provider
tests above should be re-run after any change to
`overlay/config-profiles/*.yaml` or `overlay/install/03-apply-profile.sh`,
since those are the files most likely to silently break the provider-policy
guarantee (ADR-0005) if edited carelessly.

## Mocking strategy

Largely not applicable/not recommended for this project — the highest-value
tests are real-execution tests against real Ollama/Hermes/systemd, precisely
because the risk is in *external system behavior assumptions*, which mocks
would hide rather than reveal. If unit tests are added for the Python
config-merge logic, mocking the filesystem (e.g. via `tmp_path` fixtures if
this ever grows into a pytest suite) is reasonable; mocking Hermes or Ollama
themselves is not — those are exactly the things that need real testing.

## CI expectations

None exist yet. When CI is added (not yet started — see
`docs/backlog.md`), the minimum bar should be:
- `bash -n` syntax check on every shell script, on every push (cheap,
  catches nothing deep, but catches typos immediately).
- A containerized or VM-based integration test running `install.sh
  --profile on-prem` against a fresh Ubuntu image, at minimum through Phase
  1's steps (Ollama up, Hermes up, offline tool-call succeeds) — this is
  the test that would have caught the config-schema assumptions early,
  and is the highest-value CI investment once Phase 1 is manually validated
  once (turn the manual Phase 1 validation into the first CI test, don't
  design CI abstractly before that).
- Docker path build + up as a separate CI job once Phase 2 is validated
  manually.
- No CI plan yet for the USB image (building/testing bootable images in CI
  is a much bigger undertaking; not recommended to pursue until everything
  else is stable).
