# Claude AI Assistant Notes

> **For overall environment context, see: `/home/claude/workspace/AINotes/AINotes.md`**

## Project Overview
Development helper scripts for managing GitHub repositories and version control.

## Recent Work & Changes
_This section is updated by Claude during each session_

### Session: 2025-08-17
- Initial CLAUDE.md created
- Modified pushcode to support 'all' parameter
  - Added function push_single_project() for reusability
  - When 'all' is passed, loops through all .git directories in ~/projects
  - Shows full path being processed
  - Continues even if one repo fails
- Modified pullcode to support 'all' parameter  
  - Added function pull_single_project() for reusability
  - When 'all' is passed, loops through all .git directories in ~/projects
  - Shows full path being processed
  - Continues even if one repo fails
- Modified pushcode to detect and skip directories with .nogit marker file
- Updated pushcode to NOT create/push tags when there are no changes to commit
- Updated cleanup script
  - Removed default "pipeline-runner" target
  - Now requires explicit container name filter
  - Shows usage and lists containers when run without parameters
  - Added forced prune after cleanup
  - Enhanced to show container sizes and cleanup impact
  - Shows which images would be removed vs kept
  - Displays Docker system disk usage summary
  - Shows preview of what will be removed before cleanup
- **FIXED**: pushcode hanging issues
  - Added safe.directory environment variables to handle git ownership issues
  - Added 10-second timeout on git fetch operations
  - Added 5-second timeout on git ls-remote operations  
  - Added 10-second timeout on git pull operations
  - Added 1-second delays between commit push and tag operations
  - Added debug info for MSFGet SSH connectivity
  - Better error messages with exit codes and possible causes
- Modified versioncode to support 'all' parameter
  - Added function version_single_project() for reusability
  - When 'all' is passed, versions all .git directories in ~/projects
  - Includes same timeout and safe.directory fixes as pushcode
  - Skips directories with .nogit marker
  - Continues processing even if one repo fails
- **FINAL OPTIMIZATIONS**: Added retry logic to all scripts
  - All scripts now have 3-attempt retry with exponential backoff (2s, 4s delays)
  - Reduced timeouts from 20s to 7s (faster fail, multiple attempts)
  - Added 2-second delay between repos in 'all' mode to avoid rate limiting
  - pullcode: Added retry for both fetch and clone operations
  - versioncode: Added retry for fetch and pull operations
  - Consistent progress indicators: ↻ retry, ⏱️ timeout, ⏸️ pause

### Session: 2025-11-08
- **Added "." parameter support** to pushcode, pullcode, versioncode
  - Use "." as first parameter to operate on current directory
  - Automatically detects project name from basename of pwd
  - Example: `cd ~/projects/nginx && pushcode . "Quick fix"`
- **Added .claude directory detection**
  - When pushcode/pullcode run from ~/.claude or ~/projects/.claude
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
  - pushcode: Runs gitsyncfirst.sh "push" before git operations
  - pullcode: Runs gitsyncfirst.sh "pull" after successful pull/clone
  - versioncode: Runs gitsyncfirst.sh "version" before tagging
- **Created gitsyncfirst.sh for claude-code-config:**
  - Syncs $HOME/.claude → home/
  - Syncs $HOME/projects/.claude → infrastructure/
  - Preserves .credentials.json during restore
  - Handles both push and pull operations

## Known Issues & TODOs
- ~~pushcode 'all' appears to hang~~ **FIXED with timeouts and safe.directory**

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
# Push single project
./pushcode ProjectName "Commit message"

# Push current directory (NEW)
cd ~/projects/myproject
./pushcode . "Quick fix"

# Push all projects
./pushcode all "Bulk update message"

# Pull single project
./pullcode ProjectName

# Pull current directory (NEW)
cd ~/projects/myproject
./pullcode .

# Pull all projects
./pullcode all

# Version a single project
./versioncode ProjectName "Version message"

# Version all projects (patch bump)
./versioncode all "Bulk version message"

# Version all projects (stable bump)
./versioncode all -stable "Stable release"

# Version all projects (major bump)
./versioncode all -major "Major release"

# Claude Code configuration backup (DEPRECATED - use gitsyncfirst.sh)
./claude-push "Optional commit message"  # Backup current config to GitLab
./claude-pull                             # Restore config from GitLab
```

## Using gitsyncfirst.sh for Dependency Syncing

Projects can include a `gitsyncfirst.sh` script in their root directory to sync dependencies before/after git operations.

### How it works:
- **pushcode/versioncode**: Executes `gitsyncfirst.sh "push"` BEFORE git operations
  - Use this to sync external files/directories INTO the repository
- **pullcode**: Executes `gitsyncfirst.sh "pull"` AFTER successful pull/clone
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
- Works with all three git scripts (pushcode, pullcode, versioncode)
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
