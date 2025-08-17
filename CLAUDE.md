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

# Push all projects
./pushcode all "Bulk update message"

# Pull single project  
./pullcode ProjectName

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
```
