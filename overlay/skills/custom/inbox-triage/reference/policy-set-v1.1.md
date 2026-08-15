# Inbox Management / Email Triage — Policy Set v1.1

Scope: Gmail, accessed via the Google Workspace skill (OAuth) — this
policy set only decides what to do with a message, it does not read, send,
or otherwise talk to Gmail itself; see `../SKILL.md` for that boundary.
Derived from `first-principles.md`. Read that doc first if you're new to
this — every rule below traces back to one of its six principles.

This doc is the source of truth for editing and review. The companion file
`../SKILL.md` is the compact, execution-facing distillation of it — the two
must stay in sync. If you edit a policy here, update `../SKILL.md` in the
same change and bump both version numbers together; don't let them drift.

## How to read this document

- Precedence is absolute and explicit — if more than one policy's trigger
  matches an email, the lower-numbered policy wins. This is how Principle 2
  (no contradiction) is enforced structurally rather than by inspection.
- Match method says whether a policy is checked with cheap deterministic
  signals (headers, sender, subject pattern) or requires model judgment.
  Deterministic checks always run first (Principle 4).
- Autonomy says whether the action fires immediately or waits for your
  sign-off.
- Policies are numbered P1–P4. P4 is the catch-all and is what principle 5
  (draft-until-approved) actually runs through.

## Precedence order

1. P1 — Work, Clients & Calendar
2. P2 — Receipts, Orders & Finance
3. P3 — Cold Outreach, Sales & Marketing
4. P4 — Catch-all (no match)

## P1 — Work, Clients & Calendar

Trigger (any of):

- Sender's domain matches a configured list of work/client domains, or
  sender is in your contacts.
- Message is a reply within a thread you started or participated in.
- Message carries a `text/calendar` MIME part / `.ics` attachment, or
  subject matches meeting-invite patterns ("invited you to", "Updated
  invitation:", "Canceled event:").

Match method: Deterministic (domain list, contacts lookup, thread
reference, MIME type). No model reasoning needed.

Action: Label `Work`, leave in inbox (never auto-archived — these are
usually time-sensitive). If the message appears to need a reply (question
directed at you, meeting requiring RSVP), draft a reply and hold it for
your approval — never send autonomously.

Autonomy: Labeling is autonomous. Any reply is drafted only, always held
for approval, per your action-authority answer.

Notes: This policy has top precedence deliberately — a receipt or
newsletter-looking email from an actual colleague should still be treated
as work correspondence, not swept into P2/P3.

## P2 — Receipts, Orders & Finance

Trigger (any of):

- Sender matches known transactional patterns (`receipts@`, `orders@`,
  `billing@`, `noreply@` at a known merchant/bank/payment-processor
  domain).
- Subject/body matches transactional language: "order confirmation," "your
  receipt," "invoice," "payment received," "statement is ready."

Match method: Deterministic (sender pattern + subject keyword match).
Escalate to model judgment only when sender is unrecognized but subject
strongly resembles transactional language (to catch new merchants) — and
in that case, treat a positive match as lower-confidence (see Autonomy).

Action: Label `Finance`, archive (out of inbox — these are reference
material, not action items).

Autonomy: Labeling and archiving are autonomous for high-confidence
(deterministic) matches. Deletion is never autonomous for this policy, at
any confidence level — financial records are retained by default, since
destroying them is not reversible in practice even though "delete" sounds
low-stakes. Low-confidence model-judged matches are archived but flagged
with a note rather than filed silently, so you can spot-check the new
pattern.

Notes: This policy only files documentation. It does not authorize
initiating, approving, or acting on any purchase — that's a separate
capability outside inbox triage, and out of scope for this policy set.

## P3 — Cold Outreach, Sales & Marketing

Trigger (any of):

- Message carries a `List-Unsubscribe` header (or equivalent bulk-sender
  signal) and sender is not in contacts and there is no prior sent-mail
  thread with that sender.
- Subject/body matches sales-pitch language ("book a demo," "limited time
  offer," "% off," "here's what you're missing") from a sender you've
  never replied to.

Match method: Deterministic header check narrows the candidate set;
content-pattern match (deterministic keyword list first, model judgment
only for borderline phrasing) confirms intent.

Action — two confidence tiers, per Principle 3 (default to reversible under
uncertainty):

- High confidence (bulk header present + sales-pattern content + zero
  prior interaction): unsubscribe and archive/delete. This is the "obvious
  spam & bulk mail" case you authorized for autonomous cleanup.
- Lower confidence (only one signal present, or sender is a company you've
  interacted with before, e.g. a past purchase now sending marketing):
  label `Marketing` and archive only. No unsubscribe, no delete —
  reversible action only, until pattern is confirmed over time.

Autonomy: High-confidence tier is autonomous (label, archive, unsubscribe,
delete). Low-confidence tier is autonomous for label/archive only, never
delete/unsubscribe.

## P4 — Catch-all (no policy matched)

Trigger: Nothing above matched.

Action: Per Principle 1, first check whether this email is close enough to
an existing policy that widening P1–P3's trigger conditions would cover it
— that's a policy-maintenance action, not a per-email one, and should feed
into the Principle 6 consolidation review rather than happen ad hoc per
email.

If it's genuinely a new category: leave the email untouched in the inbox
(no label, no archive — nothing destructive), and produce a draft policy
proposal (trigger conditions + proposed action + proposed autonomy level,
following this same format) attached to that email for your review.

Autonomy: None. Per Principle 5, a P4-triggered draft policy never goes
live and never acts — including on the email that triggered it — until you
approve it. This is intentionally the slowest path in the system.

Notes: Today this bucket also covers categories you didn't ask to be
pre-built (newsletters/subscriptions you opted into, personal/family mail)
— they'll fall here until enough examples accumulate to justify a real
P-numbered policy, or until you tell me to build one now instead of
waiting.

## Resiliency & failure handling

This runs as unattended code against a live API (Google Workspace/Gmail,
via OAuth), not as a human checklist — it needs to fail safe, not fail
open.

- **Unknown/unreachable lookup data → treat as no-match.** If the contacts
  list, domain list, or merchant list can't be read, don't assume a match
  on the policy that would have used it. Route the email to P4 rather than
  guessing into a higher-precedence or higher-autonomy tier.
- **Idempotency.** Key every action to the email's message ID. Before
  acting, check whether this message ID already carries the label/state
  this policy would produce, to avoid double-applying actions on retries,
  webhook redelivery, or a restart.
- **Atomic actions.** Paired actions (label+archive, unsubscribe+delete)
  apply as a unit. If one leg's API call fails, don't apply the other, and
  don't mark the message processed — leave it as found and retry.
- **Bounded retries, then flag — never drop, never escalate.** On action
  failure (API error, rate limit, auth expiry), retry with backoff up to a
  fixed limit (e.g. 3 attempts). If it still fails, leave the email
  untouched and flag it for review. Never drop it silently, and never fall
  through to a more destructive action as a fallback.
- **Malformed input is a P4 case, not a crash.** Missing/broken headers,
  unparseable MIME, or encoding errors should never throw an unhandled
  exception into the triage loop — treat a parse failure the same as "no
  match."
- **Contradictory signals → least destructive applicable tier.** If
  signals conflict (e.g. bulk-mail header present but sender is also a
  contact), never take the destructive branch of any policy — resolve
  toward P1's "leave untouched" or P3's low-confidence tier, not the
  aggressive one.
- **Canary period after any policy edit.** Per Principle 6, when a policy
  is added or changed — especially anything touching delete/unsubscribe —
  its first batch of matches (e.g. 10 emails or 48 hours, whichever comes
  first) runs log-only: decide the action, record it, but don't execute
  it. Only resume autonomous action once that batch looks correct on
  review.

## Standing process (Principle 6)

Review the policy set periodically (suggested: monthly, or after ~10 P4
drafts have accumulated) to:

- Approve, reject, or merge pending P4 drafts into P1–P3.
- Check whether any two policies have drifted into overlapping triggers
  that precedence is silently papering over — if so, tighten the triggers
  rather than relying on precedence alone.
- Retire or narrow any policy that's stopped matching real mail.

---
v1.1 — drafted 2026-08-15, resiliency section added 2026-08-15, provider
corrected from Composio to Google Workspace (OAuth) 2026-08-15 (see
`docs/open-questions.md`). Scope will need real inbox samples to validate
the deterministic patterns (domain lists, keyword lists) before this goes
live against Gmail.
