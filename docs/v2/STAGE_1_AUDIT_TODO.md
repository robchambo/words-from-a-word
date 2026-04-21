# Stage 1 — deferred writing-plans audit

**Status:** deferred per user directive on 2026-04-21.
**Target branch to audit:** `docs/stage-1-plan-reconciliation` (commit `b1462ca`).
**Performed by:** whoever resumes Stage 1 review — expected to be the same agent (post-merge of Stage 2 infra) or a subagent dispatched via `superpowers:subagent-driven-development`.

## Why this exists

Stage 1 rewrote / amended three plans without the `superpowers:writing-plans` skill loaded:

- `docs/superpowers/plans/2026-04-16-phase-2-scoring-hints.md` — added v2-baseline preamble.
- `docs/superpowers/plans/2026-04-16-phase-7-content.md` — full rewrite (100 levels/lang, 20/difficulty).
- `docs/superpowers/plans/2026-04-16-phase-9-store-readiness.md` — added v2-baseline preamble.

The skill has opinions the author bypassed. The audit must confirm compliance or file follow-up edits.

## Audit checklist (run against each of the three plans above)

### 1. Header conformance

Every plan MUST start with the canonical header:

```
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence]

**Architecture:** [2-3 sentences]

**Tech Stack:** [Key libs]

---
```

Confirm each file opens with this shape. The v2 preambles I added sit **after** `Goal`/`Architecture`/`Tech Stack` but **before** `## File Structure` — check that's still legal under the skill's header rule, or move them below the `---` divider if not.

### 2. Placeholder scan

Grep each plan for skill-prohibited patterns:

- `TBD`, `TODO`, `implement later`, `fill in details`
- `add appropriate error handling`, `add validation`, `handle edge cases`
- `Write tests for the above` (without test code shown)
- `Similar to Task N` (without the code repeated inline)
- Steps that describe what to do without showing the code

Phase 7 was rewritten from scratch — heightened risk of placeholder code blocks. Phase 2's preamble is descriptive rather than task-shaped, so less risk there. Phase 9's preamble is conditional ("skip this", "do only iOS half") — confirm the conditionals don't turn into placeholder instructions ("verify X exists") without specifying what success looks like.

### 3. Type / identifier consistency

Grep for symbol drift across tasks within each plan. Flags:

- Phase 2 preamble mentions `pickSafeHintLetter` — confirm every downstream task that references the hint algorithm uses this name exactly, not `pickHintLetter` or `selectSafeLetter`.
- Phase 2 mentions `TargetWord.revealedIndices: Set<int>` as reused — confirm no task adds a shadow field like `revealedPositions: Map<String, Set<int>>`.
- Phase 7 task 1 code block defines `validateLevelBlob(...)`, `ValidationReport`, `_difficulties` — confirm every later reference uses these exact identifiers.

### 4. Step granularity

Skill rule: each step = one action, 2–5 minutes. Common violations:

- Multi-step "Write the X" that bundles test + impl + commit
- Missing "Run it to verify it fails" between test-write and implementation
- Missing explicit `git commit` step at end of each task

Phase 7's Task 1 ships a ~80-line Dart file in a single code block — that's fine as long as the TDD dance is present (failing test → implement → pass → commit). Confirm it is.

### 5. Spec coverage

For each plan, read the `Goal` sentence and cross-reference against the task list. Any goal clause without a corresponding task is a gap.

Specifically for Phase 7: goal says "100 levels per language, 20 per difficulty." Confirm:
- Task 5 (loader tests) actually asserts those counts.
- Task 6 (final verification) names 100/lang and 20/diff explicitly as exit criteria.
- There is a task (or explicit note) covering the existing 23 RU / 20 EN source words — Phase 7's current rewrite says "use existing words for the source words" but may not spell out what "existing" means numerically.

### 6. Execution handoff

Skill requires the author to offer two execution paths at the end of a plan:
1. Subagent-Driven (recommended)
2. Inline Execution

Our plans aren't *new* plans — they're amendments to existing ones. Probably no new handoff is needed. Confirm this interpretation is correct, or add a handoff block if the skill's rule applies.

## Output of the audit

A single follow-up commit on a branch named `docs/stage-1-audit-fixups` (branched from whatever `v2` looks like at audit time), with either:

- empty diff + a note here ("audit clean") if nothing needs fixing; or
- edits to the three plan files addressing every issue above.

Do not rebase `b1462ca` or amend it — it's already on origin. A fix-up commit is cleaner.

## When to do this

Before any of the Phase 1–9 execution branches start. The audit output influences how subagents read these plans, so it blocks real code work but not infra work (Stage 2).
