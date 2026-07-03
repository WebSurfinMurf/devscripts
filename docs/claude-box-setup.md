# Claude Code box setup — new machine / new user onboarding

Complete, role-agnostic directions to bring a fresh box onto the shared Claude Code
config (skills, agents, hooks, output styles) + the `devscripts` helper scripts.
Works for both **administrator** and **developer** roles — pick your role where noted.

> Everything here lives on GitLab (`gitlab.ai-servicers.com`), not GitHub.

---

## 0. Mental model — two independent mechanisms

Do not conflate these. They update differently.

| What | Where | How it updates |
|------|-------|----------------|
| **Skill collections** (our config) | `~/.claude/skills/<collection>/` — each is a GitLab clone under `claude-skills/` | `gitpull skills` / `gitpush skills` |
| **Anthropic plugin marketplaces** (upstream) | `~/.claude/plugins/marketplaces/*` — clones of `github.com/anthropics/*` | Claude Code's built-in `/plugin` updater — **never** `gitpull skills` |

`gitpull skills` only ever touches `~/.claude/skills/*/`. It leaves the Anthropic
marketplaces alone.

---

## 1. Prerequisites

1. **SSH key registered on GitLab** for your account (`ssh -T -p 2222 git@gitlab.ai-servicers.com` should greet you).
2. **Group membership** — you must be in the group whose repos you clone:
   - `administrators` → can access `administrators/*` + `claude-skills/claude-admin`
   - `developers` → can access `developers/*` + `claude-skills/claude-dev`
   - **Both** roles can access the shared repos (`claude-skills/claude-shared`, `administrators/devscripts` — shared with developers).
3. `git` installed and on `PATH`.

---

## 2. Get the helper scripts (`devscripts`)

`devscripts` provides `gitpull`, `gitpush`, `gitversion`, etc. Clone it once and put it on your `PATH`.

```bash
mkdir -p ~/projects
git clone ssh://git@gitlab.ai-servicers.com:2222/administrators/devscripts.git ~/projects/devscripts
# put the scripts on PATH (adjust to your shell rc):
echo 'export PATH="$HOME/projects/devscripts:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

`administrators/devscripts` is shared with the `developers` group, so both roles can clone it.
(The git scripts hardcode the `administrators/` GitLab namespace — that's why the repo lives there.)

---

## 3. Clone your skill collections into `~/.claude/skills/`

Everyone clones `claude-shared`. Then clone the **one** collection for your role.

```bash
mkdir -p ~/.claude/skills

# Everyone:
git clone ssh://git@gitlab.ai-servicers.com:2222/claude-skills/claude-shared.git ~/.claude/skills/claude-shared

# Administrators ONLY:
git clone ssh://git@gitlab.ai-servicers.com:2222/claude-skills/claude-admin.git  ~/.claude/skills/claude-admin

# Developers ONLY:
git clone ssh://git@gitlab.ai-servicers.com:2222/claude-skills/claude-dev.git    ~/.claude/skills/claude-dev
```

**What you get "for free" from `claude-shared`:** it's a plugin bundle (`.claude-plugin/`
manifest) that ships the shared **skills, agents, hooks, commands, and output styles**.
You do **not** clone or symlink those separately — they ride inside the collection:
- `~/.claude/output-styles` → symlink into `claude-shared/output-styles` resolves once cloned (ships `enterprise-architect.md`).
- Agents/hooks/commands are sourced from inside the plugin, not from top-level `~/.claude/agents` (that dir is legitimately sparse/absent).

---

## 4. Verify

```bash
# collections are git-backed and discovered:
for d in ~/.claude/skills/*/; do [[ -d "$d.git" ]] && echo "git: $d"; done

# launch (or exit + resume) Claude Code and confirm the namespaced skills appear:
#   claude-shared:*   (everyone)
#   claude-admin:*    (admin)  |  claude-dev:*  (developer)
```

**How registration works (confirmed):** Claude Code **auto-discovers** each collection
via its `~/.claude/skills/<collection>/.claude-plugin/plugin.json` on launch. There is
**no `/plugin install` step** and `installed_plugins.json` stays `{}` — that's expected,
not a problem. If skills don't appear immediately after cloning, **exit and resume**
Claude Code so discovery re-runs. If they still don't appear, see Troubleshooting §6.

---

## 5. Ongoing sync

```bash
gitpull skills     # pull latest for ALL cloned collections (skips the ~/projects sweep)
gitpush skills     # push your local skill edits back
```

- Acts only on git-backed dirs under `~/.claude/skills/*/`; non-git local skills (e.g. `idiot/`) are skipped.
- Exit `0` clean / `1` on any failed-or-auth-required collection; prints a PULL/PUSH SUMMARY.
- **Update-only** — it syncs collections that already exist; it does **not** clone new ones. Do the one-time clones in §3 first (otherwise `gitpull skills` is a harmless no-op).

To update the Anthropic marketplaces instead, use Claude Code's `/plugin` — not `gitpull`.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `gitpull skills` prints a clean summary but syncs nothing | Collections never cloned (pre-plugin flat layout) | Do the §3 clones |
| `git clone` of a collection → permission denied | Your role isn't granted on that repo | Confirm group membership; `claude-shared`/`claude-dev` are shared with `developers`, `claude-admin` is admin-only |
| `~/.claude/output-styles` dangling symlink | `claude-shared` not cloned yet | Clone `claude-shared` (§3); the symlink then resolves |
| Namespaced skills don't appear after cloning | Discovery hasn't re-run | **Exit and resume** Claude Code — registration is auto-discovery of `.claude-plugin/plugin.json` on launch. Verify that file exists in the collection. `installed_plugins.json` staying `{}` is normal. |
| Cross-user path in `~/.claude/plugins/known_marketplaces.json` (`installLocation` points at another user's home) | Vestigial marketplace config; currently unused (`installed_plugins.json = {}`) | Cosmetic — correct it to your home if you like, but nothing depends on it |

**Migrating an old box?** If you have `*.pre-plugin-bak` dirs, **do not delete them** until
§4 verification passes — they're your rollback.

---

## Access summary

| Repo | administrators | developers |
|------|----------------|------------|
| `claude-skills/claude-shared` | ✅ | ✅ (shared) |
| `claude-skills/claude-admin` | ✅ | ❌ admin-only |
| `claude-skills/claude-dev` | ✅ | ✅ (shared) |
| `administrators/devscripts` | ✅ | ✅ (shared) |
