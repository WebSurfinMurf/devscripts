# claudeauto - Full Auto Claude Code Launcher

Launch Claude Code in full auto mode with no permission prompts.

## Usage

```bash
claudeauto                      # Start in ~/projects, full auto
claudeauto <project-name>       # Start in specific project, full auto
claudeauto <project> "prompt"   # Start with specific prompt
```

Examples:
```bash
claudeauto                      # Interactive in projects dir
claudeauto nginx                # Work on nginx project
claudeauto mcp "fix the bug"    # Start with specific task
```

## How It Works

1. If no project specified, changes to `~/projects`
2. If project specified, changes to `~/projects/<project>`
3. Launches Claude Code with `--dangerously-skip-permissions`
4. Claude can execute all operations without asking

## Full Auto Mode

The `--dangerously-skip-permissions` flag:
- Skips all tool permission prompts
- Allows unrestricted file read/write
- Allows unrestricted bash execution
- Allows network operations

**Use with caution** - Claude will execute operations without confirmation.

## Comparison

| Mode | Flag | Behavior |
|------|------|----------|
| Normal | (none) | Asks permission for each operation |
| Allowed Tools | `--allowedTools "..."` | Pre-approves specific tools |
| **Full Auto** | `--dangerously-skip-permissions` | No permission prompts |

## When to Use

- Trusted projects where you want uninterrupted work
- Automated scripts/pipelines
- When you'll monitor Claude's output

## See Also

- `claude --help` for all options
- `claudemanual` for sandboxed mode with permissions
