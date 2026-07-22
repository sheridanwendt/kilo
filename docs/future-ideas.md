# Future ideas

Every enhancement, optimization, or future feature discussed during design
that is explicitly **not** part of the v1 scope. Captured here so it isn't
lost, and so a future Claude instance doesn't rediscover-and-re-litigate
these from scratch. Ordered high → experimental within each project theme.

## High priority (natural next step after v1)

- **Purchase-making capability, hard-human-gate variant.** ADR-0002 deferred
  this entirely for v1, but of the three options considered (hard gate,
  pre-approved rules + spend cap, defer), "hard human gate" is the option
  most consistent with this project's established pattern (manual approval
  for cloud spend, manual confirmation for instance provisioning). When the
  owner revisits this, start there rather than re-evaluating all three from
  scratch — though it should still be the owner's explicit decision to
  reopen this, not an autonomous choice by whichever Claude instance picks
  it up (see `CLAUDE.md` constraints).
- **`overlay/iso-usb/build-image.sh`** — automating the currently-manual
  Ventoy build process once it's been proven manually. Directly named in
  the original Project Plan (step 16) as a "to be scripted" item.
- **"Policy lint" for provider-config drift** (also in `docs/backlog.md` as
  a concrete P2 item) — technical enforcement of the manual-cloud-approval
  guarantee, not just documentation/discipline.

## Medium priority

- **Real upstream version pinning.** Clone `NousResearch/hermes-agent`
  ourselves at a specific tag/commit instead of always installing "whatever
  upstream's installer currently ships." Would resolve the tradeoff
  documented in ADR-0003, at the cost of taking on real merge/update
  responsibility this repo currently avoids. Only worth doing if
  reproducibility problems actually materialize in practice (see
  `docs/open-questions.md` #10) — don't do this preemptively.
- **Automated, encrypted `~/.hermes` backups.** Currently a manual `tar czf`
  per `overlay/docs/runbook.md`, with encryption and off-machine storage
  left entirely to operator discretion. A scheduled Hermes cron skill that
  performs this automatically (and perhaps syncs to a location the owner
  controls) would close a real operational gap.
- **Container hardening pass for the Docker path** (also in
  `docs/backlog.md` P2) — read-only root, dropped capabilities, PID limits.
  Mentioned in early research as a Hermes-native Docker feature; never
  actually applied/verified in this repo.
- **A real "policy compliance" acceptance test** that runs periodically
  (not just once during Phase 1) to confirm the local-first/manual-cloud
  guarantee still holds after any config or upstream Hermes update — e.g.
  monitoring for unexpected outbound network calls to cloud provider
  domains during normal offline operation.

## Long-term

- **Selective cross-instance memory/skill sync.** Right now, each
  `~/.hermes/` instance (home server, laptop, USB) is fully independent;
  the only way to "share" state between them is a full-tarball
  clone/restore, which also carries over credentials/auth tokens
  undifferentiated. A real design would need to separate "portable
  learnings" (skills, general user-model facts) from "instance-specific
  state" (auth tokens, machine-specific config) — genuinely nontrivial,
  explicitly called out as unsolved in `docs/data-model.md`.
- **GitHub App / connector integration for routine push access.** The
  one-off PAT pattern (ADR-0010) works but requires the owner to generate
  and paste a new token every time an agent session needs to push. If this
  becomes a recurring workflow rather than an occasional handoff, a proper
  GitHub connector/App would remove that friction — worth revisiting if the
  pattern recurs more than a couple of times.
- **Multi-USB fleet management with divergent roles per drive.** Explicitly
  named in the original requirements ("possibly multiple USBs") but
  deliberately deferred in favor of a single Ventoy drive (ADR-0004). If
  the owner eventually wants genuinely different agent configurations on
  different physical drives (not just copies of the same image), that's a
  bigger design effort than the current single-image plan and should get
  its own ADR when/if it happens.
- **A hybrid Server+minimal-desktop USB build**, as a middle ground between
  the Server-vs-Desktop split in ADR-0006 — mentioned as a possibility
  during that discussion but not designed or pursued.

## Experimental / speculative

- **Home Assistant integration.** Hermes's own messaging gateway list
  (researched during framework evaluation) includes Home Assistant as a
  supported platform alongside Telegram/Discord/etc. — never discussed
  further in this project beyond noting it exists, but could be relevant
  given the personal-assistant, on-prem-server framing of this project.
- **RL training / trajectory export features.** Upstream Hermes markets
  itself partly as "a platform for generating training data, running RL
  experiments, and exporting trajectories for fine-tuning" (batch
  processing, Atropos RL integration, ShareGPT trajectory export). Entirely
  unexplored in this project — noted here only because it's a real upstream
  capability that was surfaced during research and might be relevant if the
  owner ever wants to fine-tune a model on their own agent's trajectories,
  which would tie back nicely to the "local, owner-controlled" theme of
  this whole project.
- **Cost-optimized cloud routing (ClawRouter, LiteLLM Proxy) for the
  *manual* cloud path.** These were researched as part of the provider
  landscape survey and explicitly not adopted (ADR-0005 excludes
  OpenRouter/Nous Portal, and by the same logic these weren't pursued
  either) — but if the owner's manual cloud usage ever grows enough to
  care about cost optimization *across* the three chosen cloud providers
  (Anthropic/OpenAI/Hugging Face) rather than just which one to use, a
  proxy layer could be reconsidered. Purely speculative; no indication this
  is currently wanted.
- **A "policy dashboard" skill** — an extension of the planned
  `instance-health` skill that specifically visualizes/reports on
  provider-policy compliance (how many local vs. cloud requests over time,
  confirming the manual-approval guarantee is holding in practice) rather
  than just infrastructure health. Not requested, but a natural extension
  of `instance-health` once that skill exists.
