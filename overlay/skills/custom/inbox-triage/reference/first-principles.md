# Inbox Management / Email Triage — First Principles

These principles govern how email triage policies are written and
maintained for the personal assistant. Actual policies (the rules that map
email characteristics to actions, see `policy-set-v1.1.md`) should be
derived from and checked against these before being added.

## 1. Minimalism, with a bias toward generalizing over adding

Write as few policies as possible to achieve the desired triage outcome.
When an email doesn't fit any existing policy, the first move is to check
whether an existing policy can be *widened* to cover it — not to write a new
one. A new policy is a last resort, reserved for emails that represent a
genuinely new category, not just a new instance of something already close
to an existing rule.

## 2. No contradiction, enforced by precedence

No two policies may prescribe conflicting actions for the same email.
Because policy scopes can overlap as the set grows, this is enforced
structurally with an explicit precedence order (e.g., most-specific-match
wins) rather than relying on manual review to catch conflicts.

## 3. Default to the reversible action under uncertainty

When confidence is low, or a policy's applicability is ambiguous, the
assistant defaults to the least destructive / most reversible action
available (e.g., label or flag for review) rather than a high-stakes one
(e.g., delete, reply, unsubscribe, purchase).

## 4. Cheap evaluation first

Policies should be matched using simple, deterministic signals — sender,
domain, subject pattern, keyword — wherever possible. Model reasoning is
reserved for genuinely ambiguous cases that deterministic matching can't
resolve. This keeps triage fast, cheap, and auditable, in line with the
project's goal of minimal-resource orchestration.

## 5. New policies are drafts until approved by a human

When principle 1 is exhausted and a new policy is genuinely warranted, the
assistant drafts the policy and flags the triggering email for the user's
review. The new policy does not act autonomously until the user approves
it. This mirrors the project's broader "new instances created with a human
in the loop" requirement, applied to policy creation itself.

## 6. Periodic consolidation

Because principle 5 guarantees the policy set grows over time, there must
be a standing process to periodically review, merge, generalize, or retire
policies — otherwise principle 1 only holds at inception and erodes as
exceptions accumulate.

---
*Status: draft, agreed with user on 2026-08-15. Next step: use these
principles to draft the actual triage policy set.*
