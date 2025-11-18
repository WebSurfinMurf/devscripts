# Claude AI Assistant Notes

> **For overall environment context, see: `/home/claude/workspace/AINotes/AINotes.md`**

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
├── maintenance/                     # Log rotation & cleanup (NEW)
│   ├── cleanup-logs-and-ephemeral-data.sh  # Weekly cleanup script
│   ├── setup-docker-log-rotation.sh        # Docker daemon config (one-time)
│   ├── README.md                           # Maintenance documentation
│   └── logs/                               # Cleanup logs
├── gitinit                          # Initialize git repo on GitLab/GitHub
├── gitpush                         # Git push helper
├── gitpull                         # Git pull helper
├── gitversion                      # Git version/tag helper
└── CLAUDE.md                        # This file
```

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
  - Example use case: claude-code-config syncs ~/.claude and ~/projects/.claude
  - **REPLACES claude-push/claude-pull scripts** - unified workflow now
- **Updated all three git scripts:**
  - gitpush: Runs gitsyncfirst.sh "push" before git operations
  - gitpull: Runs gitsyncfirst.sh "pull" after successful pull/clone
  - gitversion: Runs gitsyncfirst.sh "version" before tagging
- **Created gitsyncfirst.sh for claude-code-config:**
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
./gitpull -gitlab claude-code-config

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
```

## Using gitsyncfirst.sh for Dependency Syncing

Projects can include a `gitsyncfirst.sh` script in their root directory to sync dependencies before/after git operations.

### How it works:
- **gitpush/gitversion**: Executes `gitsyncfirst.sh "push"` BEFORE git operations
  - Use this to sync external files/directories INTO the repository
- **gitpull**: Executes `gitsyncfirst.sh "pull"` AFTER successful pull/clone
  - Use this to restore files/directories FROM the repository to system

### Example: claude-code-config
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
- Session storage relocated to AINotes/claude/ for organization
- All session management scripts updated with new paths
- Ready for claude-code restart with proper context persistence

### Session: 2025-11-12
- **Added `-gitlab` parameter to gitpull**
  - Allows explicit GitLab remote specification for new clones
  - Usage: `gitpull -gitlab claude-code-config`
  - Existing repos still auto-detect GitLab from remote URL
  - Solves first-time clone scenario where repo doesn't exist yet
  - Example: On laptop run `gitpull -gitlab claude-code-config` to clone from GitLab

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
