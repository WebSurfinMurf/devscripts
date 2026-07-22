---
id: 2026-07-22-gitpull-dirty-guard-beb0fd
status: result
child_session_id: beb0fd6a-d756-4688-931f-85f2502a5f3c
spawn_mode: execute
tier: low
spawned_at: 2026-07-22T03:12:21Z
launched_at: 2026-07-22T03:24:06Z
completed_at: 2026-07-22T03:29:00Z
source_dir: /home/administrator/projects/claudecodeconfig
source_session_id: unknown
dest_dir: /home/administrator/projects/devscripts
slug: gitpull-dirty-guard
parent_refocus_id: 2026-07-03-gitpull-skills-trigger-fef9a3
related_refocus_ids: ["2026-07-03-gitpull-skills-trigger-fef9a3"]
done_when:
  - "`gitpull` REFUSES `git reset --hard` on any repo with modified tracked files OR unpushed local commits; that repo is skipped, the run continues, and it is reported in the summary under a new 'Dirty — skipped' category"
  - "On refusal the script prints a clearly delimited, copy-pasteable PROMPT BLOCK the user can paste to an LLM to resolve the dirty state (contents specified below)"
  - "`--force` flag bypasses the guard and restores today's unconditional hard-reset behavior"
  - "Guard applies to ALL repos (it lives in pull_single_project), not just the skills collections"
  - "Clean repos are completely unaffected — `gitpull skills` / `gitpull all` behave exactly as today when nothing is dirty"
out_of_scope:
  - "Do NOT auto-stash, auto-commit, or auto-discard anything — refuse-and-report only. Silent stashing is a different flavor of data loss."
  - "Do NOT touch claudecodeconfig/gitsyncfirst.sh"
  - "Do NOT change the gitleaks / GitHub-visibility security work — that is a separate pending track"
related: []
---

# Brief: `gitpull` dirty-worktree guard + paste-to-LLM remediation prompt

## Why this branch exists
`gitpull` updates every repo — including the `~/.claude/skills/*` collections — with
`git reset --hard origin/<branch>` (`gitpull:137`). That force-overwrites the working
tree, silently destroying modified tracked files and discarding unpushed local commits.
The skill collections are hand-edited in place, so this is a live footgun, made more
likely by the `gitpull skills` trigger added in the parent refocus. The user wants the
reset guarded — and, when it trips, wants the script to print text they can paste
straight into an LLM to sort out the dirty state.

## Inherited context
- Target: `~/projects/devscripts/gitpull`. Repo is clean and pushed (GitHub remote — **note: this repo is PUBLIC**, so never add secrets).
- The destructive line is `git reset --hard "origin/${DEFAULT_BRANCH}"` at **`gitpull:137`**, inside `pull_single_project()` (starts `gitpull:51`), reached only after a successful `git fetch --depth=1` (`gitpull:112`).
- Because the guard goes in `pull_single_project`, it protects **every** mode — `skills`, `all`, and single-project — for free. That is the intent.
- Two distinct hazards, both must be caught:
  1. **Modified tracked files** → use `git status --porcelain --untracked-files=no`. Untracked files SURVIVE `reset --hard` (no `git clean` is run), so untracked must NOT trigger the guard — that would cause constant false positives.
  2. **Unpushed local commits** → `git rev-list --count origin/${DEFAULT_BRANCH}..HEAD`. `reset --hard origin/main` moves the branch back, discarding them.
- On trigger: **skip that repo and continue the run.** Do not abort the whole sweep. Use a distinct return code (e.g. `3`) and add a new tracking array + summary category, e.g. `DIRTY_PROJECTS` → "Dirty — skipped (uncommitted work)". Mirror the existing `AUTH_FAILED_PROJECTS` pattern (`gitpull:242-244`, summary block in `print_pull_summary()`).
- Existing shared helpers to reuse: `pull_all_skills()` (`gitpull:219`), `print_pull_summary()` (`gitpull:269`). Tracking arrays are declared by the caller before invoking.
- `--force` should be parsed alongside the existing `-gitlab` flag (arg parsing at `gitpull:10-27`).
- Consider whether `gitpush` needs a symmetric change — it does NOT reset --hard, so probably no. State the finding either way; do not change `gitpush` unless there's a real hazard.

## The paste-to-LLM prompt block (the novel requirement)
When the guard trips, print a visually delimited block the user can select and paste
verbatim into an LLM. It must be self-contained — the LLM receives no other context.
Include: repo path, remote URL, branch, the list of modified tracked files, the unpushed
commit count, and an explicit instruction. Target shape:

```
──────── COPY EVERYTHING BELOW AND PASTE TO YOUR LLM ────────
gitpull refused to update a repo because the working tree has
changes that `git reset --hard` would permanently destroy.

Repo:   /home/administrator/.claude/skills/claude-shared
Remote: ssh://git@gitlab.ai-servicers.com:2222/claude-skills/claude-shared.git
Branch: main

Modified tracked files (WOULD BE DESTROYED):
  M CLAUDE.md
  M .gitignore

Unpushed local commits (WOULD BE DISCARDED): 2

Please: review these changes, decide what is worth keeping, commit
and push what should be kept, discard the rest, then confirm it is
safe to re-run `gitpull`.
─────────────────────────────────────────────────────────────
```

Keep the delimiters ASCII-safe and the block free of ANSI colour codes so a
terminal copy-paste stays clean. Emit real values, not placeholders.

## Open questions / desired deliverables
- Guard in `pull_single_project` before the hard reset; both hazard checks.
- Paste block printed on refusal, populated with real values.
- New "Dirty — skipped" summary category; run continues; correct exit code.
- `--force` bypass documented in usage/help text.
- Verify: clean repo → unchanged behaviour; artificially dirtied throwaway repo in `$TMPDIR` → guard trips, block prints, run continues, summary lists it.

## Hard rule for child
- Children are leaves. If you discover work that belongs in a different
  directory, do NOT call /refocus. Surface it in Result.suggested_follow_ups
  for the parent to decide.

## Testing constraint
- Do NOT test by dirtying the real `~/.claude/skills/*` collections — they were just
  cleaned and pushed. Build a throwaway repo in `$TMPDIR` with an origin and dirty it there.

## Pointer back
- Source session: `~/.claude/projects/-home-administrator-projects-claudecodeconfig/<source-session>.jsonl` (~2026-07-22T03:12Z)
- To continue this child later: `cd /home/administrator/projects/devscripts && claude --resume beb0fd6a-d756-4688-931f-85f2502a5f3c`

---

## Result

**Status:** completed

**Definition-of-Done met:**
- ✓ `gitpull` refuses `git reset --hard` on any repo with modified tracked files OR unpushed local commits — guard added in `pull_single_project()` (`gitpull:176-184`), checked right after a successful fetch and before `git checkout`/`git reset --hard`. Trips on either hazard, returns exit code `3`, repo is skipped, run continues. New `DIRTY_PROJECTS` array + "Dirty — skipped" category added to `print_pull_summary()`, wired into both `pull_all_skills()` and the `all`-mode repo loop, plus a dedicated line in the single-project summary.
- ✓ On refusal, `print_dirty_guard_prompt()` (`gitpull:58-88`) prints the exact copy-pasteable, ASCII-safe, ANSI-free block specified in the brief, populated with real repo path, resolved remote URL, branch, modified-file list, and unpushed-commit count.
- ✓ `--force` parses alongside `-gitlab` (either order, either combination) and restores the unconditional hard-reset for that invocation.
- ✓ Guard lives in `pull_single_project()`, so it applies uniformly to `skills`, `all`, and single-project/`.` modes.
- ✓ Clean repos are unaffected — verified empirically (see Testing below), including after fixing a bug that would otherwise have made this false.

**Summary:** Added a dirty-worktree guard to `gitpull` that checks for modified tracked files (`git status --porcelain --untracked-files=no`) and unpushed local commits (`git rev-list --count origin/<branch>..HEAD`) before every `git reset --hard`, refusing and printing a self-contained paste-to-LLM remediation block instead of silently destroying work. `--force` bypasses it. While testing, discovered and fixed a real bug that the brief's literal spec would otherwise have shipped broken: the existing-repo fetch already used `git fetch --depth=1`, which repeatedly shallow-truncates history and disconnects local HEAD's ancestry from origin's ref on every fetch — this made the new unpushed-commit check **false-positive on every single normal pull**, even with zero local changes (reproduced and confirmed on a fresh, previously-full clone). Fixed by dropping `--depth=1` from the existing-repo fetch (`gitpull:152`); the new-clone path's `--depth 1` is untouched since it doesn't affect ongoing ancestry once the shallow-from-birth clone starts fetching incrementally. Verified `gitpush` has no symmetric hazard (no `reset --hard` there) — left untouched per the brief.

**Artifacts produced:**
- `gitpull` — dirty-worktree guard, `print_dirty_guard_prompt()`, `--force` flag, `DIRTY_PROJECTS` tracking + summary category, and the `--depth=1` fetch fix. Committed as `200fe6c` and pushed to both `github` and `origin` (GitLab) remotes.

**Suggested follow-ups (parent decides):** none. This closes the brief; no cross-directory work was discovered.

**Material changes (for /context-save):** `gitpull` now guards every hard-reset against dirty state (modified tracked files or unpushed commits) and refuses with a paste-to-LLM remediation block instead of destroying work; `--force <target>` restores the old unconditional-reset behavior; existing-repo fetches no longer force `--depth=1` (was causing repeated shallow-history truncation). Any `docs/context/operations.md` or equivalent describing `gitpull`'s pull/reset behavior should reflect the new refuse-and-report guard and the `--force` escape hatch.
