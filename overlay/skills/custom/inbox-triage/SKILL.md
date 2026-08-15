---
name: inbox-triage
description: Decision policy for what to DO with a Gmail message once it's already in hand — label/archive/unsubscribe/delete choices and a human-approval gate for anything new or destructive. This is a policy/reasoning skill, not a mail-access tool: it does not read, send, or otherwise talk to Gmail itself. Pair it with the Google Workspace skill (OAuth), which handles actual mail access. Deterministic sender/domain/header/regex checks should run first, in code; load this skill only when that deterministic pass returns no match or low confidence, or when asked to review/edit triage policy itself.
---

# Inbox Triage — Runtime Card v1.1

Not an email client. This skill takes a message the Google Workspace skill
has already retrieved (via its own OAuth-based Gmail access) and decides
what should happen to it — it never calls Gmail itself. If you need to
actually fetch, send, or search mail, that's the Google Workspace skill,
not this one.

(Full rationale: `reference/policy-set-v1.1.md`, incl. resiliency notes.
Deterministic sender/domain/header/regex checks run in code, not here — only
load this card when a deterministic pass returns no match or low confidence.
Source of truth is the full doc; if that changes, regenerate this card and
bump both version numbers together. First-principles rationale behind why
these policies are shaped this way — before proposing any new or edited
policy, read `reference/first-principles.md`.)

Precedence: P1 > P2 > P3 > P4, lower number wins on overlap.

**P1 Work/Clients/Calendar** — known sender/contact, thread reply, or
calendar invite. → label `Work`, keep in inbox. Reply: draft only, never
auto-send.

**P2 Receipts/Orders/Finance** — transactional sender/subject pattern. →
label `Finance`, archive. Never delete, any confidence. → Unrecognized
sender but transactional-looking: archive + flag for spot-check, don't file
silently.

**P3 Cold Outreach/Sales/Marketing** — bulk-mail header + no prior contact +
sales language. High confidence (all signals, zero interaction): unsubscribe
+ delete/archive — autonomous. Low confidence (partial signals, or past
interaction): label + archive only, no delete/unsubscribe.

**P4 No match** — touch nothing (no label/archive/delete). Draft a proposed
policy (trigger/action/autonomy) and hold for user approval. Never goes live
same-pass.

**Autonomy ceiling**: label/archive/snooze = auto. Delete/unsubscribe = auto
only for P3-high. Replies = always drafted, never sent without approval.
New (P4) policies = never autonomous.

## Resiliency (fail safe, not fail open)

- Lookup data (contacts/domain/merchant list) unreachable → treat as
  no-match → P4. Never guess into a higher-autonomy tier.
- Idempotent: key every action to message ID; skip if already processed.
- Atomic: paired actions (label+archive, unsubscribe+delete) apply as a
  unit; partial failure → leave untouched, don't mark processed.
- On action failure: retry w/ backoff, max 3 → still failing: leave
  untouched + flag for review. Never drop silently, never escalate to a
  more destructive fallback.
- Malformed/unparseable email (broken headers/MIME) → treat as P4, never
  throw.
- Contradictory signals (e.g. bulk header + known contact) → take the
  least-destructive applicable tier, never the aggressive one.
- New/edited policy → first batch (10 emails or 48h) runs log-only before
  autonomous action resumes.
