# v2 Phase Execution Convention

How Phases 1–9 get executed on top of `v2`. This document is the single source of truth; if a plan contradicts it, the convention wins.

## Branch topology

```
main                  (docs + roadmap authority; fast-forwards to v2 only at release)
 └── v2               (integration branch; median-calibration code + main's docs)
      ├── docs/v2-baseline-audit              (Stage 0 — BASELINE_AUDIT.md)
      ├── docs/stage-1-plan-reconciliation    (Stage 1 — Phase 2/7/9 amendments)
      ├── docs/stage-2-execution-infra        (Stage 2 — this doc, CI, PR template)
      ├── feat/phase-1-<slug>                 (Phase 1 execution)
      ├── feat/phase-2-<slug>                 (Phase 2 execution, branches off v2 AFTER Phase 1 merges)
      └── …
origin/testing-dynamic-dictionary    (frozen; do not push)
origin/median-calibration            (frozen; do not push)
origin/kat-intro-edits               (frozen; do not push)
```

## Rules

### 1. All phase work branches off `v2`, targets `v2`

- No phase PR targets `main`. Main is a doc-archive branch until release.
- Each phase branch is named `feat/phase-N-<short-slug>` (e.g. `feat/phase-3-progression`).
- The branch is created from **current-tip `v2`**, not from a stale checkout. Always `git fetch origin && git checkout v2 && git pull --ff-only` first.

### 2. Use isolated worktrees (required for subagent-driven execution)

Per `superpowers:using-git-worktrees` (required sub-skill of `superpowers:executing-plans`), every phase runs in its own worktree, not in the main checkout. This lets subagents work in isolation without disturbing the user's IDE state.

```bash
# From the main checkout:
git fetch origin
git worktree add ../words-from-a-word-phase-N feat/phase-N-<slug> origin/v2
cd ../words-from-a-word-phase-N
```

When the phase is merged: `git worktree remove ../words-from-a-word-phase-N`.

### 3. Plans are executed via `superpowers:subagent-driven-development` or `superpowers:executing-plans`

Every phase plan opens with a header pointing at those skills. The executor — human or subagent — must load the skill before starting, not skip to the tasks.

- **Subagent-driven** (preferred for multi-task phases): one subagent per task, review between. Use `superpowers:subagent-driven-development`.
- **Inline** (acceptable for short phases): all tasks in one session. Use `superpowers:executing-plans`.

### 4. Between-phase gate (runs before a phase PR merges to v2)

Every phase PR must pass all of the following before merge:

- [ ] `flutter analyze` — zero issues.
- [ ] `flutter test` — all tests pass.
- [ ] Any plan-specified verification steps (smoke test, goldens, etc.) checked off in the PR body.
- [ ] All task checkboxes in the plan document marked `- [x]`.
- [ ] Plan's exit criteria explicitly met in PR description (quote them back).
- [ ] CI green on GitHub (see `.github/workflows/ci.yml`).
- [ ] Reviewer approval (the user; currently Rob).

### 5. Tagging scheme

After merging each phase to `v2`:

```bash
git checkout v2
git pull --ff-only
git tag v1.1.0-phase-N
git push origin v1.1.0-phase-N
```

At end of v1.1 (after Phase 9 merges):

```bash
# Fast-forward main to v2 head:
git checkout main
git merge --ff-only v2
git push origin main

# Release tag, matching pubspec version (e.g. 1.1.0+10):
git tag v1.1.0+10
git push origin v1.1.0+10
```

### 6. Plan modifications mid-execution

If during execution the plan turns out to be wrong, the executor STOPS (per `superpowers:executing-plans` "When to Stop and Ask for Help") and flags it. The fix is:

- A doc branch `docs/phase-N-fixup` off `v2` that amends the plan.
- Reviewed, merged, tagged as the new authority.
- The execution branch rebases or cherry-picks forward.

Do not let executors silently diverge from the plan. If they must diverge, the plan catches up.

### 7. Dependencies between phases

Per `docs/superpowers/plans/2026-04-16-v1_1-roadmap.md` (and `V1_1_ROADMAP.md`), phases have a dependency DAG. Execute in this order unless the dependency graph says otherwise:

```
Phase 1 (contracts + skeletons)
   → Phase 2 (scoring + hints)
   → Phase 3 (progression + level picker)
   → Phase 4 (monetization + ads)
   → Phase 5 (audio + haptics)
   → Phase 6 (analytics + remote config)
   → Phase 7 (content — blocked on Kat's generator output for source words)
   → Phase 8 (achievements + polish)
   → Phase 9 (store readiness)
```

Phase 7's required-level content is blocked on Kat. Engineering infrastructure for Phase 7 (validator CLI, CI workflow, loader tests, authoring guide) can land independently before Kat delivers — per the Stage 1 rewrite of the Phase 7 plan.

## Open questions / things not yet decided

- **Squash vs merge commits** for phase PRs. Default proposal: `--no-ff` merge commits so phase history is preserved on `v2`, squash commits on Stage-0/1/2 doc-only branches.
- **Who runs iOS builds for Phase 9.** CI on GitHub-hosted macOS runners is expensive; likely Rob runs iOS locally.
- **Versioning of `v1.1.0-beta.N`.** The current `pubspec.yaml` is `1.1.0-beta.1+2`. Each phase merge could bump `+N`, or we could wait until Phase 9.

These are tracked in `docs/V1_1_ROADMAP.md` and resolved before they block.
