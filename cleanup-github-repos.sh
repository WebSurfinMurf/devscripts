#!/bin/bash
# Script to clean sensitive files from GitHub while keeping local copies
# This removes files from git tracking but keeps them locally

echo "🔒 GitHub Repository Cleanup Script"
echo "This will remove sensitive files from git tracking while keeping local copies"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to clean a repository
clean_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    echo -e "${BLUE}Processing $repo_name...${NC}"
    cd "$repo_path" || return
    
    # Check if it's a git repository
    if [ ! -d ".git" ]; then
        echo -e "${YELLOW}  Skipping - not a git repository${NC}"
        return
    fi
    
    # Add safe.directory config
    git config --global --add safe.directory "$repo_path"
    
    # Add .gitignore if it was just created
    if [ -f ".gitignore" ]; then
        git add .gitignore
        git commit -m "Add .gitignore to prevent sensitive file commits" 2>/dev/null && \
            echo -e "${GREEN}  ✓ Added .gitignore${NC}" || \
            echo -e "${YELLOW}  .gitignore already committed or no changes${NC}"
    fi
    
    # List of patterns to remove from tracking
    patterns=(
        "*.env"
        "*.key"
        "*.pem"
        "*.crt"
        "*.cert"
        "*.bak"
        "*.backup"
        "*.tmp"
        "*.old"
        "*.sql"
        "*.db"
        "*.sqlite"
        "realm.properties"
        "users.properties"
        "acme.json"
    )
    
    # Check and remove each pattern
    local files_removed=false
    for pattern in "${patterns[@]}"; do
        # Check if any files match this pattern in git
        if git ls-files "$pattern" 2>/dev/null | grep -q .; then
            echo -e "${YELLOW}  Removing $pattern from tracking...${NC}"
            git rm --cached $pattern 2>/dev/null
            files_removed=true
        fi
    done
    
    # Also check for directories that shouldn't be tracked
    dir_patterns=(
        "data/"
        "certs/"
        "certificates/"
        "ssl/"
        "logs/"
        "volumes/"
        "pgdata/"
        "dkim/"
        "mail/"
    )
    
    for dir_pattern in "${dir_patterns[@]}"; do
        if git ls-files "$dir_pattern" 2>/dev/null | grep -q .; then
            echo -e "${YELLOW}  Removing $dir_pattern from tracking...${NC}"
            git rm -r --cached "$dir_pattern" 2>/dev/null
            files_removed=true
        fi
    done
    
    # Commit if files were removed
    if [ "$files_removed" = true ]; then
        git commit -m "Remove sensitive files from git tracking (kept locally)" 2>/dev/null && \
            echo -e "${GREEN}  ✓ Committed removal of sensitive files${NC}" || \
            echo -e "${RED}  Failed to commit changes${NC}"
    else
        echo -e "${GREEN}  ✓ No sensitive files found in tracking${NC}"
    fi
    
    echo ""
}

# List of repositories to clean
repos=(
    "/home/websurfinmurf/projects/keycloak"
    "/home/websurfinmurf/projects/mailu"
    "/home/websurfinmurf/projects/postgres"
    "/home/websurfinmurf/projects/rundeck"
    "/home/websurfinmurf/projects/open-webui"
    "/home/websurfinmurf/projects/devscripts"
    "/home/websurfinmurf/projects/claude-code"
    "/home/websurfinmurf/projects/traefik"
    "/home/websurfinmurf/projects/MSFGet"
)

echo "📋 Repositories to clean:"
for repo in "${repos[@]}"; do
    [ -d "$repo/.git" ] && echo "  - $(basename $repo)"
done
echo ""

read -p "Continue with cleanup? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi
echo ""

# Process each repository
for repo in "${repos[@]}"; do
    clean_repo "$repo"
done

echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Review the changes with: git status (in each repo)"
echo "2. Push to GitHub with: gitpush all 'Security cleanup - remove sensitive files from tracking'"
echo ""
echo "Note: All files have been kept locally, only removed from git tracking"
