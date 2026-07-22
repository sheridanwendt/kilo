# Backlog

Prioritized remaining engineering work. P0 = blocks everything else, P1 =
needed for v1, P2 = valuable but not v1-blocking, P3 = nice-to-have /
future. Cross-referenced with `docs/implementation-plan.md` phases and
`PROJECT_PLAN.md` step numbers where applicable.

---

### P0 — Blocking

**Validate/fix the `config.yaml` provider schema against a real `hermes model` run**
- Description: `overlay/config-profiles/default.yaml`'s `model:` block is a
  best-effort guess from documentation, unconfirmed. Everything else in
  Phase 1 depends on this being right.
- Dependencies: none — this is the first real thing to do.
- Complexity: Low-medium (mostly diagnostic: run `hermes model`
  interactively, diff its output against this repo's file, fix
  discrepancies).
- Expected impact: Unblocks all of Phase 1.
- Acceptance criteria: `hermes` successfully makes a tool-calling request
  against local Ollama using a config produced by `03-apply-profile.sh`,
  with no manual post-install edits required.
- Plan step: 4.

**Validate/fix `gateway.platforms` schema against `hermes gateway setup`**
- Description: same category of risk as above, for the messaging gateway
  config key.
- Dependencies: none, can be done in parallel with the provider schema fix.
- Complexity: Low-medium.
- Expected impact: Unblocks step 10 and any messaging-platform testing.
- Acceptance criteria: `hermes gateway install --system` starts
  successfully using a config produced by this repo, actually connects to
  at least one configured platform (Telegram or CLI).
- Plan step: 10.

**Full reboot test of boot autostart, offline**
- Description: prove the "starts automatically at boot, local LLM default"
  requirement actually holds under a real power cycle with no network.
- Dependencies: provider schema fix (above) must land first, or this test
  will fail for the wrong reason.
- Complexity: Low (mechanically simple, high-value proof point).
- Expected impact: Validates one of the two "never change without review"
  requirements in `CLAUDE.md`.
- Acceptance criteria: reboot a real machine with networking disabled;
  `ollama.service` and `hermes-gateway.service` both active afterward with
  zero manual steps; a chat message gets a response from the local model.
- Plan step: 11.

---

### P1 — Needed for v1

**Resolve Docker↔Ollama networking mechanism**
- Description: `overlay/docker/docker-compose.override.yml` has an open
  TODO about whether `HPA_OLLAMA_BASE_URL` env var or a mounted
  `config.yaml` is the right way to point the Hermes container at the
  sidecar Ollama container.
- Dependencies: P0 items (need a working bare-metal config first, to know
  what "correct" looks like in container form).
- Complexity: Medium.
- Expected impact: Unblocks the `cloud-server` Docker deployment path.
- Acceptance criteria: `docker compose up -d` produces a Hermes container
  that successfully talks to the sidecar Ollama container with zero manual
  fixes.
- Plan step: 13.

**Build `instance-health` skill**
- Description: reports active provider, Ollama reachability, disk/memory
  headroom, last-backup timestamp. Described but not built.
- Dependencies: P0 items complete (need a working instance to build/test
  the skill against).
- Complexity: Low-medium (well-understood pattern, Hermes's own skill
  authoring loop can likely assist).
- Expected impact: First real proof of the "add new skills" requirement in
  a way specific to this project, plus an operationally useful diagnostic
  tool.
- Acceptance criteria: correctly detects both a healthy and a deliberately
  broken instance (e.g. Ollama stopped).
- Plan step: 7.

**Build `instance-provision` skill (human-in-the-loop new-instance flow)**
- Description: the concrete implementation of the original "easily create
  new instances (manually, with a human in the loop)" requirement. Profile
  selection, install summary, explicit typed confirmation before running
  `install.sh`.
- Dependencies: P0 items complete.
- Complexity: Medium (the confirmation-gate behavior is
  security-relevant and needs careful testing of the "does not confirm"
  path, not just happy path).
- Expected impact: Closes a named original requirement that currently has
  zero implementation.
- Acceptance criteria: cannot proceed to actually running `install.sh`
  without an explicit, unambiguous human confirmation step; test both the
  confirm and decline paths.
- Plan step: 18.

**Ventoy USB image build + multi-machine test**
- Description: turn `overlay/iso-usb/README.md`'s manual process into a
  working, then scripted (`build-image.sh`), Ventoy image; test on 2+
  physically different machines.
- Dependencies: P0 items complete.
- Complexity: High (first-time OS image work; biggest unknown in the
  project is Ventoy persistence portability across hardware).
- Expected impact: Closes the original "bootable USB, device agnostic"
  requirement.
- Acceptance criteria: boots and runs correctly, offline, on at least two
  machines with different hardware.
- Plan steps: 16, 17.

**Full acceptance pass against every original requirement**
- Description: systematically check `README.md`'s capability matrix against
  reality once everything above is done.
- Dependencies: everything else in P0/P1.
- Complexity: Low (verification, not building), but only after real
  substance exists to verify.
- Expected impact: The actual "are we done" gate for v1.
- Acceptance criteria: every row in the capability matrix is either
  genuinely working or explicitly, deliberately still marked deferred (not
  silently missing).
- Plan step: 20.

---

### P2 — Valuable, not v1-blocking

**macOS launchd autostart implementation**
- Description: currently just a warning message; no real launchd unit
  exists. See `docs/implementation-plan.md` Phase 3.
- Dependencies: P0 complete on Linux first (validate the pattern once
  before porting it).
- Complexity: Medium.
- Expected impact: Makes macOS a genuinely first-class target instead of
  "probably works, autostart definitely doesn't."
- Acceptance criteria: reboot/login test on macOS shows Ollama + Hermes
  gateway running unattended.
- Plan step: 15.

**WSL2 autostart design + implementation**
- Description: no design exists yet at all (not even a placeholder) for
  how "boots automatically" translates to WSL2's different startup model.
- Dependencies: none technically, but lower priority than native Linux/macOS
  since WSL2 was always the secondary Windows path.
- Complexity: Medium-high (genuine design work needed, not just testing).
- Expected impact: Completes the Windows story within its documented WSL2-
  only scope (ADR-0007).
- Acceptance criteria: TBD once designed — needs its own spec before
  acceptance criteria can be written meaningfully.
- Plan step: 15.

**"Policy lint" check for provider config drift**
- Description: nothing currently prevents a future edit from accidentally
  introducing a `fallback_providers:` cloud entry or otherwise violating
  ADR-0005. A simple script (or a check inside `03-apply-profile.sh`) that
  fails loudly if the merged config would violate the provider policy.
- Dependencies: P0 config-schema work (need to know the real schema to lint
  against it).
- Complexity: Low.
- Expected impact: Turns a documentation-only guarantee into an enforced
  one.
- Acceptance criteria: a deliberately-broken test profile (with a cloud
  fallback entry) causes `install.sh` to fail with a clear error, not
  silently succeed.

**Container hardening pass**
- Description: read-only root, dropped capabilities, PID limits for the
  Docker deployment path — mentioned in early research as a Hermes-native
  Docker feature, never actually configured/verified in this repo.
- Dependencies: Docker path (P1) working first.
- Complexity: Medium.
- Expected impact: Closes a real security gap flagged in
  `docs/security.md`.
- Acceptance criteria: documented hardening flags present and verified in
  the running container's actual config, not just referenced in a comment.
- Plan step: 12.

---

### P3 — Future / experimental

See `docs/future-ideas.md` for the full list with priority tiers; the
following are specifically backlog-shaped (concrete enough to eventually
become P1/P2 items) rather than purely speculative:

- Real upstream version pinning (clone `NousResearch/hermes-agent` at a
  specific tag ourselves, rather than always installing "whatever upstream
  currently ships") — would resolve the tradeoff noted in ADR-0003.
- Encrypted, automated `~/.hermes` backup (currently manual `tar czf` per
  `overlay/docs/runbook.md`).
- Selective cross-instance memory/skill sync (currently full-state clone
  only, or nothing) — see `docs/data-model.md` "Migration considerations."
- GitHub App/connector integration for routine push access, replacing the
  one-off PAT pattern if pushing becomes a recurring need (ADR-0010).
- Purchase-making capability (ADR-0002) — explicitly not backlog-ready
  until the owner reopens the decision; listed here only for completeness,
  not as actionable work.
