# claudeauto - Sandboxed Claude Code Launcher

Launch Claude Code for a specific project with automatic sandboxing.

## Usage

```bash
claudeauto <project-name>
```

Example:
```bash
claudeauto mcp
claudeauto traefik
claudeauto nginx
```

## How It Works

1. Changes to the project directory
2. Launches Claude Code
3. Claude's built-in sandbox restricts bash commands
4. File operations in project dir are auto-approved
5. File operations outside project dir require permission

## Setup Requirements

### 1. Enable Sandbox in settings.json

Add to `~/.claude/settings.json`:

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "excludedCommands": []
  }
}
```

### 2. Fix bwrap Permissions (Ubuntu 24.04)

Ubuntu 24.04 restricts user namespaces via AppArmor. Create an exception:

```bash
sudo bash -c 'cat > /etc/apparmor.d/bwrap << EOF
abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
}
EOF'

sudo apparmor_parser -r /etc/apparmor.d/bwrap
```

Test it works:
```bash
bwrap --ro-bind /usr /usr --ro-bind /bin /bin /bin/echo "bwrap works"
```

### 3. Verify Sandbox Active

When running Claude, check the status line shows sandbox is enabled, or run:
```bash
/sandbox
```

## Security Model

| Operation | Behavior |
|-----------|----------|
| Bash commands | Sandboxed (filesystem + network isolation) |
| Read in project | Auto-approved |
| Write in project | Auto-approved |
| Read outside project | Asks permission |
| Write outside project | Asks permission |

## Settings Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `false` | Enable bash sandboxing |
| `autoAllowBashIfSandboxed` | `true` | Auto-approve sandboxed bash |
| `allowUnsandboxedCommands` | `true` | Allow escape via `dangerouslyDisableSandbox` |
| `excludedCommands` | `[]` | Commands that bypass sandbox (e.g., `["docker"]`) |

## Troubleshooting

### "bwrap: setting up uid map: Permission denied"

Run the AppArmor fix above (step 2).

### Sandbox not activating

1. Check `~/.claude/settings.json` has `"sandbox": {"enabled": true}`
2. Restart Claude Code
3. Run `/sandbox` to verify status

### Need to run docker/git outside sandbox

Add to excludedCommands:
```json
"excludedCommands": ["docker", "git"]
```

## See Also

- [Claude Code Sandboxing Docs](https://code.claude.com/docs/en/sandboxing)
- [Anthropic Engineering Blog](https://www.anthropic.com/engineering/claude-code-sandboxing)
