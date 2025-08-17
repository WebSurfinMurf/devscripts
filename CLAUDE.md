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
- Issue: pushcode may hang when running 'all' - needs investigation

## Known Issues & TODOs
- pushcode 'all' appears to hang - possibly waiting for git credentials or SSH key passphrase

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

# Version a project
./versioncode ProjectName "Version message"
```
