---
id: 2026-07-22-gitpush-gitlab-default-000f6f
status: result
child_session_id: 000f6f5f-5b52-4019-b3b7-9e17745af11b
spawn_mode: execute
tier: medium
spawned_at: 2026-07-22T03:15:35Z
launched_at: 2026-07-22T03:30:39Z
completed_at: 2026-07-22T03:32:55Z
source_dir: /home/administrator/projects/claudecodeconfig
source_session_id: unknown
dest_dir: /home/administrator/projects/devscripts
slug: gitpush-gitlab-default
parent_refocus_id: null
related_refocus_ids: ["2026-07-22-gitpull-dirty-guard-beb0fd"]
done_when:
  - "A NEW repo (directory with no .git) pushed via gitpush defaults to GitLab: ssh://git@gitlab.ai-servicers.com:2222/administrators/<project>.git — never GitHub"
  - "An explicit `-github` flag remains available as a deliberate opt-in for public repos"
  - "EXISTING repos are untouched: auto-detection of the current origin still wins, so a repo already pointing at GitHub keeps pushing to GitHub. No remote is ever silently re-pointed."
  - "All GitHub-hardcoded user-facing strings are made host-aware: the 'DOES NOT EXIST' guidance block, its matching grep in the failure-reason classifier, and the closing 'Repository URL' line"
  - "bash -n passes; a dry-run against an existing GitLab repo and an existing GitHub repo both still resolve to their current remotes"
out_of_scope:
  - "Do NOT re-point, rename, or migrate any EXISTING remote. This changes the default for brand-new repos only."
  - "Do NOT add the gitleaks pre-push secret gate here — separate pending track"
  - "Do NOT touch gitpull (see sibling refocus 2026-07-22-gitpull-dirty-guard-beb0fd)"
  - "Do NOT change repo visibility or push anything to GitHub as part of this work"
related: []
---

# Brief: `gitpush` — default NEW repos to GitLab instead of GitHub

## Why this branch exists
A security review found ~26 `~/projects` repos pushing to **public** GitHub, several
carrying live infrastructure credentials. A root cause is `gitpush`: any directory
without a `.git` defaults to a GitHub remote (`gitpush:68-69`), so a brand-new internal
service project silently lands on a public host. Internal infra belongs on the closed
GitLab by default; GitHub should require a deliberate opt-in.

## Inherited context
- Target: `~/projects/devscripts/gitpush`. **This repo itself is PUBLIC on GitHub** — never add secrets to it.
- Current behaviour, `push_single_project()`:
  - `gitpush:52` — `local remote_type="github"` (the default)
  - `gitpush:57-59` — if an existing origin matches `gitlab.ai-servicers.com`, it correctly rebuilds a GitLab URL. **Keep this auto-detection exactly as is.**
  - `gitpush:62-63` — existing repo, non-GitLab origin → GitHub
  - `gitpush:68-69` — **no `.git` at all → GitHub. This is the line to flip.**
- Other GitHub-hardcoded sites that must become host-aware:
  - `gitpush:155` — `"⚠️  REPOSITORY DOES NOT EXIST ON GITHUB"` banner
  - `gitpush:161` — `👉 https://github.com/new` instruction
  - `gitpush:360` — closing `🔗 Repository URL: https://github.com/${OWNER}/...`
  - `gitpush:547` — the failure-reason classifier greps the literal string `"DOES NOT EXIST ON GITHUB"`. **If you reword the banner, update this grep or the classifier silently breaks.**
- `OWNER="WebSurfinMurf"` (`gitpush:42`) is GitHub-only — keep it, but it should only be consulted on the GitHub path.
- **Reuse the convention already established in the sibling `gitinit` script** (do not invent a new one):
  - `gitinit` supports `-gitlab [group]`, default group `administrators` (`gitinit:15`)
  - GitLab URL form: `ssh://git@gitlab.ai-servicers.com:2222/${GROUP}/${PROJECT}.git` (`gitinit:59`)
  - Web URL form: `https://gitlab.ai-servicers.com/${GROUP}/${PROJECT}` (`gitinit:60`)
  - Note the SSH port is **2222**, not 22.
- For the new-repo-doesn't-exist-yet guidance block, the best instruction is to point the
  user at `gitinit -gitlab` (which already creates the remote project) rather than a
  manual web flow — but a GitLab new-project URL is an acceptable fallback. Use judgement.
- `gitpull` already accepts a `-gitlab` flag for forcing GitLab on new clones; consider
  mirroring that flag naming for consistency (`-github` as the inverse here).

## Open questions / desired deliverables
- Flip the new-repo default to GitLab (`administrators` group) using gitinit's URL convention.
- Add an explicit `-github` opt-in flag, documented in usage/help text.
- Make the four GitHub-hardcoded strings host-aware, including the `:547` classifier grep.
- Confirm existing-repo auto-detection is genuinely unchanged — this is the highest-risk
  regression: silently re-pointing an existing remote would be far worse than the bug
  being fixed.
- Update usage/help text and the `devscripts/CLAUDE.md` gitpush entry.

## Hard rule for child
- Children are leaves. If you discover work that belongs in a different
  directory, do NOT call /refocus. Surface it in Result.suggested_follow_ups
  for the parent to decide.

## Testing constraint
- Do NOT create real repos on GitLab or GitHub to test. Use throwaway dirs in `$TMPDIR`
  and inspect the resolved URL / dry-run output. Never push during verification.

## Pointer back
- Source session: `~/.claude/projects/-home-administrator-projects-claudecodeconfig/<source-session>.jsonl` (~2026-07-22T03:15Z)
- To continue this child later: `cd /home/administrator/projects/devscripts && claude --resume 000f6f5f-5b52-4019-b3b7-9e17745af11b`

---

## Result

**Status:** completed

### Definition-of-Done met
- ✓ NEW repo (no `.git`) defaults to `ssh://git@gitlab.ai-servicers.com:2222/administrators/<project>.git` — verified in a throwaway `$TMPDIR` dir, resolver prints `(GitLab - new)`.
- ✓ Explicit `-github` flag added as a leading opt-in flag (mirrors `gitpull -gitlab`); verified it yields `(GitHub - new, explicit -github)`.
- ✓ EXISTING repos untouched: origin auto-detection still wins. Verified a GitLab-origin repo and a GitHub-origin repo both resolve to their current remote, **including when a contradicting flag is passed** (`-gitlab` against a GitHub-origin repo still resolves GitHub). `git remote get-url origin` unchanged on both after the runs.
- ✓ All GitHub-hardcoded user-facing strings made host-aware: remote-add messages (x2), "Checking if repository exists on …", the "DOES NOT EXIST" banner (now `DOES NOT EXIST ON REMOTE (<label>)`), the "Pushing to …" line, the closing `Repository URL`, and the `all`-mode failure-reason classifier grep (updated in lockstep with the banner).
- ✓ `bash -n gitpush` passes; six-case dry resolution matrix run with `.nogit` markers so no network/push occurred.

### Summary
`gitpush` no longer silently lands brand-new internal projects on public GitHub. The new-repo default is the internal GitLab using `gitinit`'s exact URL convention (SSH port 2222, `administrators` group), with `-gitlab`/`-github` leading flags selecting the platform for NEW repos only. Existing-repo origin auto-detection is byte-for-byte the same logic, now parameterised by `GITLAB_HOST` — no remote is ever re-pointed, and the flags are deliberately ignored on existing repos. The local `github_url` variable was renamed `remote_url` and paired with `remote_label` / `web_url` so every user-facing string derives from the resolved host rather than a hardcoded "GitHub". The GitLab guidance block for a missing remote points at `gitinit -gitlab` (with a manual `projects/new` fallback) instead of the GitHub web flow. Committed as `edf3152` and pushed to `administrators/devscripts`.

### Artifacts produced
- `gitpush` — new-repo GitLab default, `-gitlab`/`-github` flags, host-aware output, classifier grep updated.
- `CLAUDE.md` — gitpush inventory entry, usage examples, and a `Session: 2026-07-22` change record.

### Suggested follow-ups (parent decides)
- `~/projects/devscripts` · `gitpush-gitleaks-pre-push` — the pending secret-scanning gate before push (explicitly out of scope here).
- `~/projects/devscripts` · `gitversion-gitlab-default` — `gitversion` was not reviewed; if it contains the same GitHub-default fallthrough it has the same exposure. Not touched (out of brief scope).
- Remediation of the ~26 EXISTING repos already on public GitHub is a separate operational track — this change only stops *new* ones. Nothing was migrated or re-pointed.

### Material changes (for /context-save)
- `docs/context/conventions.md` — new-repo git remote default is internal GitLab (`administrators` group, port 2222); GitHub requires explicit `-github`.
- `docs/context/interfaces.md` — `gitpush` CLI surface gained leading `-gitlab` / `-github` flags.
- `docs/context/invariants.md` — gitpush must never re-point an existing origin; the `all`-mode failure classifier grep is coupled to the "DOES NOT EXIST ON REMOTE" banner wording.

