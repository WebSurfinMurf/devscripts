# Claude AI Assistant Notes

> **For overall environment context, see: `/home/claude/workspace/ainotes/ainotes.md`**

## Project Overview
Development helper scripts for managing GitHub repositories, version control, backups, and system maintenance.

## Project Structure
```
devscripts/
├── backup/                          # Multi-user backup system
│   ├── backup-projects-data.sh     # Main backup script (daily/weekly/monthly)
│   ├── setup-backup-mount.sh       # USB drive setup (one-time)
│   ├── BACKUP-README.md            # User documentation
│   ├── BACKUPS-VARIABLE.md         # $BACKUPS env variable docs
│   └── CLAUDE.md                   # Backup system context
├── maintenance/                     # Log rotation & cleanup
│   ├── cleanup-logs-and-ephemeral-data.sh  # Weekly cleanup script
│   ├── setup-docker-log-rotation.sh        # Docker daemon config (one-time)
│   ├── README.md                           # Maintenance documentation
│   └── logs/                               # Cleanup logs
├── .claude/                         # Claude Code command definitions
├── Git Management Scripts
│   ├── gitinit                      # Initialize git repo on GitLab/GitHub
│   ├── gitpush                      # Git push helper with retry logic
│   ├── gitpull                      # Git pull helper with retry logic
│   └── gitversion                   # Git version/tag helper
├── System Maintenance Scripts
│   ├── healthcheck.sh               # System and Docker health monitoring (NEW)
│   ├── cleanserver.sh               # Docker cleanup and log rotation (NEW)
│   ├── updatelinux.sh               # System update automation
│   └── cleanup                      # Legacy Docker container cleanup
├── Claude Code Management Scripts
│   ├── claudeauto                   # Sandboxed autonomous mode launcher (NEW)
│   ├── claude-push                  # Push Claude config to GitLab
│   ├── claude-pull                  # Pull Claude config from GitLab
│   ├── claude-session               # Manage Claude session storage
│   ├── startclaude                  # Start Claude Code with config
│   ├── build-claude-index.py        # Build searchable index
│   ├── validate-claude-md.py        # Validate CLAUDE.md files
│   ├── bulk-generate-claude.sh      # Generate CLAUDE.md for all projects
│   ├── update-claude-after-deploy.sh # Update Claude docs post-deployment
│   └── detect-patterns.py           # Detect code patterns for documentation
├── Utilities
│   ├── find-project.py              # Search for projects by name/pattern
│   ├── mergecode                    # Merge code from multiple sources
│   ├── restorecode                  # Restore code from backups
│   ├── sharefile                    # Share file via temporary link
│   ├── note                         # Quick note-taking utility
│   ├── cleanup-github-repos.sh      # Clean sensitive data from Git
│   └── delete_repos.sh              # Bulk delete repositories
├── Tools
│   ├── glab                         # GitLab CLI (44MB binary)
│   ├── claude-diff.py               # Compare Claude configurations
│   └── project-health-check.py      # Project health assessment
└── Documentation
    ├── CLAUDE.md                    # This file
    ├── LICENSE                      # Project license
    └── note.txt                     # Session notes
```

## Scripts Inventory

### System Maintenance (NEW)

**healthcheck.sh** - System and Docker Health Check
- Checks Docker daemon, container health, disk/memory/CPU usage
- Analyzes recent container log errors (last hour)
- Detects recurring errors (3+ occurrences)
- Logs all output to `/home/administrator/projects/data/logs/healthcheck/`
- Auto-removes logs older than 90 days
- Exit codes: 0=healthy, 1-99=fatal errors, 100+=soft warnings
- Usage: `./healthcheck.sh`

**cleanserver.sh** - Server Cleanup
- Removes stopped Docker containers
- Prunes dangling Docker images
- Prunes dangling Docker volumes (safe - only unused)
- Clears Docker build cache
- Removes all log files older than 90 days from `/home/administrator/projects/data/logs/`
- Must run as administrator user
- Exit codes: 0=success, N=number of errors
- Usage: `./cleanserver.sh`

**updatelinux.sh** - System Update Automation
- Updates Ubuntu packages
- Handles Docker and system-level updates
- Usage: `./updatelinux.sh`

### Git Management

**gitinit** - Initialize Git Repository
- Creates repo on GitLab (administrators/developers group) or GitHub
- Initializes local git repo with README and .gitignore
- Pushes initial commit
- Usage: `gitinit -gitlab [group]` or `gitinit -github [owner]`

**gitpush** - Git Push Helper
- Commits and pushes changes to remote
- Supports single project, current directory (.), or all projects
- 3-attempt retry with exponential backoff
- Runs gitsyncfirst.sh if present
- Usage: `gitpush <project|.|all> "commit message"`

**gitpull** - Git Pull Helper
- Pulls latest changes from remote
- Supports GitLab and GitHub repos
- Handles new clones and existing repos
- Runs gitsyncfirst.sh after pull if present
- Usage: `gitpull <project|.|all>` or `gitpull -gitlab <project>`

**gitversion** - Git Version/Tag Helper
- Creates version tags (patch/stable/major)
- Supports single project, current directory (.), or all projects
- Runs gitsyncfirst.sh before tagging
- Usage: `gitversion <project|.|all> [-stable|-major] "message"`

### Claude Code Management

**claude-push** - Push Claude Config to GitLab
- Backs up ~/.claude and ~/projects/.claude to GitLab
- Usage: `claude-push "commit message"`

**claude-pull** - Pull Claude Config from GitLab
- Restores Claude configuration from GitLab
- Usage: `claude-pull`

**build-claude-index.py** - Build Searchable Index
- Creates searchable index of projects and documentation
- Python script (9.0K)

**validate-claude-md.py** - Validate CLAUDE.md Files
- Validates structure and content of CLAUDE.md files
- Python script (12K)

**bulk-generate-claude.sh** - Generate CLAUDE.md for All Projects
- Auto-generates CLAUDE.md files for projects
- Bash script (3.4K)

**update-claude-after-deploy.sh** - Update Docs Post-Deployment
- Updates Claude documentation after service deployment
- Bash script (2.9K)

**detect-patterns.py** - Detect Code Patterns
- Analyzes code for patterns to document
- Python script (21K)

**claude-diff.py** - Compare Claude Configurations
- Compares different Claude config versions
- Python script (15K)

**claude-session** - Manage Claude Session Storage
- Manages Claude Code session data
- Bash script (3.1K)

**startclaude** - Start Claude Code
- Launches Claude Code with proper configuration
- Bash script (3.4K)

### Utilities

**find-project.py** - Search Projects
- Searches for projects by name or pattern
- Python script (7.6K)

**mergecode** - Merge Code
- Merges code from multiple sources
- Bash script (6.9K)

**restorecode** - Restore Code
- Restores code from backups
- Bash script (2.1K)

**sharefile** - Share Files
- Creates temporary file sharing links
- Bash script (759 bytes)

**note** - Quick Notes
- Quick note-taking utility
- Bash script (1.3K)

**cleanup-github-repos.sh** - Clean Git Repositories
- Removes sensitive data from Git history
- Bash script (4.0K)

**delete_repos.sh** - Bulk Delete Repositories
- Deletes multiple repositories
- Bash script (842 bytes)

**cleanup** - Docker Container Cleanup (Legacy)
- Original Docker cleanup script
- Bash script (3.4K)
- Note: Superseded by cleanserver.sh

**project-health-check.py** - Project Health Assessment
- Assesses overall project health
- Python script (6.6K)

### Tools

**glab** - GitLab CLI
- Official GitLab command-line interface
- Binary (44MB)
- Version: v1.77.0
- Configured for gitlab.ai-servicers.com

### Documentation

**CLAUDE.md** - This file (12K)
**LICENSE** - MIT License (1.1K)
**note.txt** - Session notes and reminders (1.4K)

## Recent Work & Changes
_This section is updated by Claude during each session_

### Session: 2025-08-17
- Initial CLAUDE.md created
- Modified gitpush to support 'all' parameter
  - Added function push_single_project() for reusability
  - When 'all' is passed, loops through all .git directories in ~/projects
  - Shows full path being processed
  - Continues even if one repo fails
- Modified gitpull to support 'all' parameter  
  - Added function pull_single_project() for reusability
  - When 'all' is passed, loops through all .git directories in ~/projects
  - Shows full path being processed
  - Continues even if one repo fails
- Modified gitpush to detect and skip directories with .nogit marker file
- Updated gitpush to NOT create/push tags when there are no changes to commit
- Updated cleanup script
  - Removed default "pipeline-runner" target
  - Now requires explicit container name filter
  - Shows usage and lists containers when run without parameters
  - Added forced prune after cleanup
  - Enhanced to show container sizes and cleanup impact
  - Shows which images would be removed vs kept
  - Displays Docker system disk usage summary
  - Shows preview of what will be removed before cleanup
- **FIXED**: gitpush hanging issues
  - Added safe.directory environment variables to handle git ownership issues
  - Added 10-second timeout on git fetch operations
  - Added 5-second timeout on git ls-remote operations  
  - Added 10-second timeout on git pull operations
  - Added 1-second delays between commit push and tag operations
  - Added debug info for MSFGet SSH connectivity
  - Better error messages with exit codes and possible causes
- Modified gitversion to support 'all' parameter
  - Added function version_single_project() for reusability
  - When 'all' is passed, versions all .git directories in ~/projects
  - Includes same timeout and safe.directory fixes as gitpush
  - Skips directories with .nogit marker
  - Continues processing even if one repo fails
- **FINAL OPTIMIZATIONS**: Added retry logic to all scripts
  - All scripts now have 3-attempt retry with exponential backoff (2s, 4s delays)
  - Reduced timeouts from 20s to 7s (faster fail, multiple attempts)
  - Added 2-second delay between repos in 'all' mode to avoid rate limiting
  - gitpull: Added retry for both fetch and clone operations
  - gitversion: Added retry for fetch and pull operations
  - Consistent progress indicators: ↻ retry, ⏱️ timeout, ⏸️ pause

### Session: 2025-11-08
- **Added "." parameter support** to gitpush, gitpull, gitversion
  - Use "." as first parameter to operate on current directory
  - Automatically detects project name from basename of pwd
  - Example: `cd ~/projects/nginx && gitpush . "Quick fix"`
- **Added .claude directory detection**
  - When gitpush/gitpull run from ~/.claude or ~/projects/.claude
  - Automatically redirects to claude-push/claude-pull scripts
  - Ensures proper GitLab backup workflow for Claude Code config
  - No manual switching needed between GitHub and GitLab workflows

### Session: 2025-11-08 (Session 2)
- **Implemented gitsyncfirst.sh dependency syncing**
  - Scripts now auto-detect `gitsyncfirst.sh` in project root
  - Executes BEFORE push/version (syncs dependencies TO repo)
  - Executes AFTER pull/clone (restores dependencies FROM repo)
  - Example use case: claudecodeconfig syncs ~/.claude and ~/projects/.claude
  - **REPLACES claude-push/claude-pull scripts** - unified workflow now
- **Updated all three git scripts:**
  - gitpush: Runs gitsyncfirst.sh "push" before git operations
  - gitpull: Runs gitsyncfirst.sh "pull" after successful pull/clone
  - gitversion: Runs gitsyncfirst.sh "version" before tagging
- **Created gitsyncfirst.sh for claudecodeconfig:**
  - Syncs $HOME/.claude → home/
  - Syncs $HOME/projects/.claude → infrastructure/
  - Preserves .credentials.json during restore
  - Handles both push and pull operations

## Known Issues & TODOs
- ~~gitpush 'all' appears to hang~~ **FIXED with timeouts and safe.directory**

## Important Notes
- Owner: WebSurfinMurf
- File ownership should be: node:node
- Scripts expect GitHub username: WebSurfinMurf

## Dependencies
- git
- GitHub CLI (gh) - optional but recommended
- SSH keys configured for GitHub

## Common Commands
```bash
# Initialize a new git repository
cd ~/projects/mynewproject
./gitinit -gitlab                      # Create on GitLab (administrators group)
./gitinit -gitlab developers           # Create on GitLab (developers group)
./gitinit -github                      # Create on GitHub (WebSurfinMurf owner)

# Push single project
./gitpush ProjectName "Commit message"

# Push current directory (NEW)
cd ~/projects/myproject
./gitpush . "Quick fix"

# Push all projects
./gitpush all "Bulk update message"

# Pull single project
./gitpull ProjectName

# Pull from GitLab (NEW)
./gitpull -gitlab claudecodeconfig

# Pull current directory (NEW)
cd ~/projects/myproject
./gitpull .

# Pull all projects
./gitpull all

# Version a single project
./gitversion ProjectName "Version message"

# Version all projects (patch bump)
./gitversion all "Bulk version message"

# Version all projects (stable bump)
./gitversion all -stable "Stable release"

# Version all projects (major bump)
./gitversion all -major "Major release"

# Claude Code configuration backup (DEPRECATED - use gitsyncfirst.sh)
./claude-push "Optional commit message"  # Backup current config to GitLab
./claude-pull                             # Restore config from GitLab

# Backup commands
cd backup/
./backup-projects-data.sh              # Backup ~/projects/data (daily/weekly/monthly)
sudo ./setup-backup-mount.sh           # One-time USB drive setup

# Maintenance commands (NEW)
cd maintenance/
sudo ./cleanup-logs-and-ephemeral-data.sh --dry-run  # Preview cleanup
sudo ./cleanup-logs-and-ephemeral-data.sh            # Run cleanup
sudo ./setup-docker-log-rotation.sh                  # One-time Docker log config

# System health and cleanup (NEW)
./healthcheck.sh                   # Check system and Docker health
./cleanserver.sh                   # Clean up Docker and logs
```

## Using gitsyncfirst.sh for Dependency Syncing

Projects can include a `gitsyncfirst.sh` script in their root directory to sync dependencies before/after git operations.

### How it works:
- **gitpush/gitversion**: Executes `gitsyncfirst.sh "push"` BEFORE git operations
  - Use this to sync external files/directories INTO the repository
- **gitpull**: Executes `gitsyncfirst.sh "pull"` AFTER successful pull/clone
  - Use this to restore files/directories FROM the repository to system

### Example: claudecodeconfig
```bash
#!/usr/bin/env bash
# gitsyncfirst.sh - Syncs Claude Code configuration

case "$1" in
  push|version)
    # Sync live config TO repository before committing
    rsync -av ~/.claude/ ./home/
    rsync -av ~/projects/.claude/ ./infrastructure/
    ;;
  pull)
    # Restore config FROM repository after pulling
    rsync -av ./home/ ~/.claude/
    rsync -av ./infrastructure/ ~/projects/.claude/
    ;;
esac
```

### Benefits:
- No manual sync steps needed
- Works with all three git scripts (gitpush, gitpull, gitversion)
- Automatic dependency management
- Replaces the need for separate sync scripts like claude-push/claude-pull

### Session: 2025-08-17 (Session 3)
- Added cleanup-github-repos.sh script for removing sensitive files from git
- Script updated to use /home/websurfinmurf/projects paths
- Added comprehensive .gitignore file

### Session: 2025-08-17 (Session 3 Final)
- Session storage relocated to ainotes/claude/ for organization
- All session management scripts updated with new paths
- Ready for claude-code restart with proper context persistence

### Session: 2025-11-12
- **Added `-gitlab` parameter to gitpull**
  - Allows explicit GitLab remote specification for new clones
  - Usage: `gitpull -gitlab claudecodeconfig`
  - Existing repos still auto-detect GitLab from remote URL
  - Solves first-time clone scenario where repo doesn't exist yet
  - Example: On laptop run `gitpull -gitlab claudecodeconfig` to clone from GitLab

### Session: 2025-11-15
- **Created maintenance/ directory with log/data cleanup scripts**
  - `cleanup-logs-and-ephemeral-data.sh` - Weekly cleanup of logs and ephemeral data
  - `setup-docker-log-rotation.sh` - One-time Docker daemon log rotation setup
  - `README.md` - Complete maintenance documentation
- **Updated backup/backup-projects-data.sh with exclusions**
  - Excludes netdata cache (runtime metadata, ~656MB)
  - Excludes volume-backups (old nested backups, ~235MB)
  - Excludes mongodb journals (ephemeral WAL, ~315MB)
  - Excludes gitlab logs (growing logs, ~100MB+)
  - Total savings: ~1.3GB per backup (4.7GB → ~3.4GB)
- **Identified backup growth causes**
  - Analyzed Nov 10-15 backup growth (3.9GB → 4.7GB)
  - Root causes: Netdata metadata (67% of growth), nested backups, logs, journals
  - See: `/home/administrator/projects/devscripts/backup/CLAUDE.md` for details

### Session: 2025-11-17
- **Created gitinit command**
  - Initialize git repos and create them on GitLab or GitHub
  - Usage: `gitinit -gitlab [group]` or `gitinit -github [owner]`
  - Detects project name from current directory
  - Creates repository on remote platform (using glab/gh CLI if available)
  - Initializes git repo with default README.md and .gitignore
  - Sets up remote and pushes initial commit
  - Works with gitpush/gitpull for subsequent operations
  - Examples:
    - `gitinit -gitlab` - Creates in administrators group
    - `gitinit -gitlab developers` - Creates in developers group
    - `gitinit -github` - Creates for WebSurfinMurf owner
- **Installed and configured glab CLI**
  - Downloaded glab v1.77.0 for Linux
  - Configured for gitlab.ai-servicers.com
  - Created personal access token for administrator user
  - Made administrator a GitLab super admin
  - Added administrator to developers group as Owner
- **Renamed git commands for consistency**
  - `pushcode` → `gitpush`
  - `pullcode` → `gitpull`
  - `versioncode` → `gitversion`
  - Updated all internal references in scripts
  - Updated all documentation (CLAUDE.md, note.txt, etc.)
  - Maintains git command naming convention (like gitinit)

### Session: 2025-11-22
- **Created healthcheck.sh - System and Docker Health Monitor**
  - Comprehensive health checks: Docker daemon, containers, disk, memory, CPU, network
  - Container health validation (unhealthy, restarting, high restart counts)
  - Critical infrastructure monitoring (traefik, keycloak, postgres, loki, grafana)
  - **Log error analysis**: Scans last hour of container logs for recurring errors (3+ occurrences)
  - Filters out benign errors (shutdowns, network timeouts, handshake failures)
  - **Logging**: All output saved to `/home/administrator/projects/data/logs/healthcheck/`
  - Auto-cleanup: Removes healthcheck logs older than 90 days
  - Exit codes: 0=healthy, 1-99=fatal errors, 100+N=soft warnings
  - Fixed 3 fatal errors: timescaledb unhealthy, postgres unhealthy, mcp-memory restarting
    - Root cause: Missing environment variables in healthcheck commands
    - Solution: Redeployed containers with proper environment loading
    - mcp-memory: Removed (stdio MCP server shouldn't run as daemon)

- **Created cleanserver.sh - Server Cleanup Script**
  - Docker cleanup: Stopped containers, dangling images, dangling volumes, build cache
  - **Log cleanup**: Removes all `.log` files older than 90 days from `/home/administrator/projects/data/logs/`
  - Recursive search through all log subdirectories
  - Shows space freed and cleanup summary
  - Must run as administrator user
  - Exit codes: 0=success, N=number of errors
  - First run freed ~29GB (build cache and dangling resources)

- **Enhanced both scripts with logging and maintenance**
  - healthcheck.sh: Auto-creates log directory, timestamps all runs
  - cleanserver.sh: Scans entire data/logs tree for old files
  - Both scripts maintain their own logs (healthcheck 90-day retention)
  - Log location: `/home/administrator/projects/data/logs/healthcheck/`

- **Updated CLAUDE.md with complete scripts inventory**
  - Added comprehensive "Scripts Inventory" section
  - Categorized all 27+ scripts by function
  - Documented purpose, usage, and key features for each script
  - File sizes and types included

### Session: 2026-01-30
- **Claude Skills Reorganization**
  - Skills and config now tracked in GitLab repos under `claude-skills/` group
  - Three repos: `shared` (16 skills + common config), `administrators` (6 skills + admin config), `developers` (placeholder)
  - `~/.claude/skills/` → cloned from `claude-skills/shared`
  - `~/projects/.claude/skills/` → cloned from `claude-skills/administrators`
  - **Removed claude-push/claude-pull scripts** - skills now use standard git workflow
  - **Updated gitpush/gitpull** - removed `.claude` directory special handling
  - **Created backup-claude-session.sh** - backs up non-git-tracked session data:
    - `projects/`, `file-history/`, `todos/`, `history.jsonl`, `plans/`, `paste-cache/`
  - **Cleaned up old artifacts**: `~/.claude/home/`, `~/.claude/infrastructure/`, `~/.claude/skills.bak.*`

- **GitLab claude-skills Group Structure**
  ```
  gitlab.ai-servicers.com/claude-skills/
  ├── shared/         # 16 skills + agents, commands, hooks, docs, tools
  ├── administrators/ # 6 infra skills + architect, developer, security, qa agents
  └── developers/     # Future developer-specific skills
  ```

- **Access Permissions (Project-Level)**
  | Repo | administrators | developers |
  |------|----------------|------------|
  | shared | Read/Write | Read/Write |
  | administrators | Read/Write | No access |
  | developers | No access | Read/Write |

### Session: 2025-12-07
- **Created claudeauto - Sandboxed Autonomous Mode Launcher**
  - Launches Claude Code in a specific project with OS-level sandboxing
  - Uses bubblewrap (bwrap) for filesystem isolation
  - **Write access**: Project directory only + `/mnt/shared/aichat/` (inter-AI handoff)
  - **Read access**: System libs, `~/.claude`, `~/secrets`, `~/projects/CLAUDE.md`
  - Runs with `--dangerously-skip-permissions` inside the sandbox
  - Hardcoded prompt instructs Claude about sandbox limitations
  - If changes needed outside project, writes handoff to shared folder
  - Usage: `claudeauto <project-name>` (e.g., `claudeauto nginx`)

- **Inter-AI Communication Protocol Design**
  - Design document: `/home/administrator/projects/ainotes/interai.md`
  - Commands: `/cread` (check inbox), `/cwrite` (send message)
  - Shared definitions at `/mnt/shared/aichat/definitions/`
  - Supports Claude Code, Gemini CLI, and Codex CLI
  - Agent registry: server.admin, server.dev, laptop.dev, gemini, codex
  - Status: Design complete, implementation pending
