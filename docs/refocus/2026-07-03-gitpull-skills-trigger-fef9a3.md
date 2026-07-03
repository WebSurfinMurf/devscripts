---
id: 2026-07-03-gitpull-skills-trigger-fef9a3
status: result
child_session_id: fef9a3ce-b2bd-4e9b-8bc8-da62ae73b20e
spawn_mode: manual
tier: null
spawned_at: 2026-07-03T19:10:44Z
launched_at: 2026-07-03T19:20:00Z
completed_at: 2026-07-03T19:21:43Z
source_dir: /home/administrator/projects/claudecodeconfig
source_session_id: unknown
dest_dir: /home/administrator/projects/devscripts
slug: gitpull-skills-trigger
parent_refocus_id: null
related_refocus_ids: []
done_when:
  - "`gitpull skills` pulls ONLY the ~/.claude skill collections and exits with correct code (0 clean, 1 on any failed/auth-required), printing the PULL SUMMARY block"
  - "`gitpull all` still behaves identically — skills loop refactored into a shared function, not duplicated"
  - "Symmetric `gitpush skills` added, pushing only the skill collections"
  - "Usage/help text in both scripts documents the `skills` trigger"
out_of_scope:
  - "Do NOT touch claudecodeconfig/gitsyncfirst.sh (stale parallel rsync mechanism)"
  - "Do NOT commit the pending uncommitted `refocus` skill edits in ~/.claude/skills/claude-shared"
  - "Do NOT broaden discovery beyond ~/.claude/skills/*/ unless the user asks"
related: []
---

# Brief: Add `gitpull skills` trigger — refresh `~/.claude` collections without pulling all projects

## Why this branch exists
While tracing how `~/.claude/skills/` gets populated, we found each collection
(`claude-admin`, `claude-shared`) is its own GitLab clone under the `claude-skills/`
group. The only wrapper that refreshes them is `gitpull all`, which also sweeps every
`~/projects` repo. The user wants a lightweight positional trigger — `gitpull skills` —
to update just the `~/.claude` items. This work lives in `~/projects/devscripts/`, a
different subtree than the source session (`claudecodeconfig`), hence the refocus.

## Inherited context
- **Full design spec** is at `/tmp/claude-2000/-home-administrator-projects-claudecodeconfig/d3ffb5af-9edf-4caf-81e6-bc6b5ddb7ae9/scratchpad/gitpull-skills-enhancement.md` — read it first; it has line refs and the exact new-branch snippet.
- Target files: `~/projects/devscripts/gitpull` and `~/projects/devscripts/gitpush`.
- The skill-pull loop already exists **inline in the `all` branch**: `gitpull:224-271` (pull side), `gitpush:373-410` (push side).
- Discovery pattern (keep it): glob `~/.claude/skills/*/`, keep dirs where `${_d}.git` exists. Each is a plain clone of `claude-skills/<basename>.git`. `idiot/` is a non-git dir and is correctly skipped.
- Single-project and `.` modes resolve `<name>` against `~/projects/<name>` and never touch skills — that's the gap being closed.
- **Recommended design (DRY, confirmed with user):** extract the inline skill loop into a `pull_all_skills()` / `push_all_skills()` function; call it from BOTH the existing `all` branch and a new `skills` branch. Do NOT copy-paste the loop.
- Reuse the existing `SUCCESS_PROJECTS` / `FAILED_PROJECTS` / `AUTH_FAILED_PROJECTS` / `FAILURE_REASONS` tracking arrays and the shared PULL/PUSH SUMMARY block.
- New `skills` branch must be placed BEFORE the single-project dispatch (`gitpull:407`, `gitpush:542`) so it intercepts first. No collision risk with a real `~/projects/skills` repo (none exists).
- User confirmed: **both** `gitpull skills` and `gitpush skills`; **interactive** review of edits (this session).
- Verify by dry-run against the two live skill dirs (`claude-admin`, `claude-shared`). Note: `claude-shared` currently has uncommitted local edits — a pull there may report "cannot fast-forward"; that's expected, don't try to resolve it (out of scope).

## Open questions / desired deliverables
- `gitpull skills` — runs only the skill-collection loop, correct exit code + summary.
- `gitpush skills` — symmetric, push side.
- `all` branch on both scripts refactored to call the shared function (behavior identical).
- Usage/help text updated in both scripts.
- A quick dry-run / read-back showing `gitpull skills` discovers exactly the git-backed skill dirs and nothing under `~/projects`.

## Hard rule for child
- Children are leaves. If you discover work that belongs in a different
  directory, do NOT call /refocus. Surface it in Result.suggested_follow_ups
  for the parent to decide.

## Pointer back
- Source session: `~/.claude/projects/-home-administrator-projects-claudecodeconfig/<source-session>.jsonl` (session id was not exported in env; find by cwd + timestamp ~2026-07-03T19:10Z if needed)
- To continue this child later: `cd /home/administrator/projects/devscripts && claude --resume fef9a3ce-b2bd-4e9b-8bc8-da62ae73b20e`

---

## Result

**Status:** completed

### Definition-of-Done met
- ✓ `gitpull skills` pulls ONLY the `~/.claude` skill collections, exits 0 clean / 1 on
  any failed/auth-required, prints the PULL SUMMARY block. (Exit-1 path observed live;
  exit-0 path proven via stubbed harness — both scripts share the summary logic.)
- ✓ `gitpull all` behaves identically — skills loop extracted to `pull_all_skills()` and
  called from both branches, not duplicated. Summary also shared via `print_pull_summary()`.
- ✓ Symmetric `gitpush skills` added (`push_all_skills()` + `print_push_summary()`).
- ✓ Usage/help text documents the `skills` trigger in both scripts.

### What changed
- **`gitpull`** — added `pull_all_skills()` + `print_pull_summary()`; new `skills`
  branch dispatches before single-project resolution; `all` branch refactored to call
  both shared functions (inline loop + inline summary removed). Usage/help updated.
- **`gitpush`** — symmetric: `push_all_skills()` + `print_push_summary()`; new `skills`
  branch; `all` branch refactored to call the shared functions. Usage/help updated.
- **`devscripts/CLAUDE.md`** — session note added.

### Verification
- `bash -n` passes on both scripts.
- Discovery finds **exactly** the two git-backed dirs (`claude-admin`, `claude-shared`);
  non-git `idiot/` correctly skipped. Nothing under `~/projects` is touched.
- `gitpull skills` in-sandbox: fetches only the 2 skill repos, prints PULL SUMMARY,
  exits **1** on failure (fetch failed only because the sandbox mounts `~/.claude`
  read-only — not a script bug).
- `gitpush skills` (stubbed `push_single_project`, run in `$TMPDIR`): dispatches to the
  skills branch, discovers the same 2 dirs, prints PUSH SUMMARY, exits **0** on all-success.
  Confirms the clean-path exit-0 for both scripts (shared summary logic).

### Deliberately NOT run
- A **real** `gitpull skills` was not executed against the live dirs: `gitpull` does
  `git reset --hard origin/main`, which would **discard** the uncommitted `claude-shared`
  refocus edits that `out_of_scope` protects. Likewise a real `gitpush skills` would
  commit+push those edits. The sandbox blocked both writes; I did not override it.
  Clean-path behavior was proven via the stubbed harness instead.

### Artifacts produced
- `gitpull` — `pull_all_skills()` + `print_pull_summary()`, new `skills` branch, `all` refactored.
- `gitpush` — `push_all_skills()` + `print_push_summary()`, new `skills` branch, `all` refactored.
- `devscripts/CLAUDE.md` — 2026-07-03 session note.

### Material changes (for /context-save)
- N/A — this project has no `docs/context/` set; change is self-documented in `CLAUDE.md`
  and this brief. No canonical context state to promote.

### Suggested follow-ups (parent decides)
- **Data-loss footgun (pre-existing, not introduced here):** `gitpull <anything>` uses
  `git reset --hard origin/<branch>`, silently discarding uncommitted local edits in the
  target repo. For skill collections that routinely carry uncommitted edits (e.g.
  `claude-shared`), consider a guard: `git stash` first, or refuse the pull with a warning
  when the worktree is dirty. Parent to decide — belongs to the `gitpull` design, not this
  branch's scope.
