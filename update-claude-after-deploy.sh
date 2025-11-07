#!/bin/bash
# Auto-Update CLAUDE.md After Deployment
# Call this from deploy.sh scripts to automatically update documentation

set -e

# Configuration
PROJECT_DIR="${1:-.}"
CHANGE_MESSAGE="${2:-Service deployed}"
UPDATE_INDEX="${3:-yes}"

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
TODAY=$(date +%Y-%m-%d)
DATETIME=$(date +"%Y-%m-%d %H:%M:%S")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if CLAUDE.md exists
if [ ! -f "$CLAUDE_MD" ]; then
    echo -e "${YELLOW}⚠️  CLAUDE.md not found, skipping auto-update${NC}"
    exit 0
fi

echo "📝 Auto-updating CLAUDE.md..."

# Update "Last Updated" field
if grep -q "^\*\*Last Updated\*\*:" "$CLAUDE_MD"; then
    sed -i "s/^\*\*Last Updated\*\*:.*/\*\*Last Updated\*\*: $TODAY/" "$CLAUDE_MD"
    echo "✅ Updated 'Last Updated' field to $TODAY"
else
    echo -e "${YELLOW}⚠️  'Last Updated' field not found in CLAUDE.md${NC}"
fi

# Add entry to "Recent Changes" section
if grep -q "^## Recent Changes" "$CLAUDE_MD"; then
    # Find the line number of "## Recent Changes"
    RECENT_CHANGES_LINE=$(grep -n "^## Recent Changes" "$CLAUDE_MD" | cut -d: -f1)

    # Check if there's already an entry for today
    if grep -q "^### $TODAY" "$CLAUDE_MD"; then
        # Append to existing date entry
        # Find the line after "### $TODAY"
        DATE_LINE=$(grep -n "^### $TODAY" "$CLAUDE_MD" | head -1 | cut -d: -f1)
        NEXT_LINE=$((DATE_LINE + 1))

        # Insert new change after the date header
        sed -i "${NEXT_LINE}i\\- $CHANGE_MESSAGE (deployed at $(date +%H:%M))" "$CLAUDE_MD"
        echo "✅ Added change to existing $TODAY entry"
    else
        # Create new date entry
        # Insert after "## Recent Changes" line
        INSERT_LINE=$((RECENT_CHANGES_LINE + 1))

        # Check if there's already content after "## Recent Changes"
        # If next line is blank, insert after it; otherwise insert immediately
        NEXT_LINE=$((RECENT_CHANGES_LINE + 1))
        if sed -n "${NEXT_LINE}p" "$CLAUDE_MD" | grep -q "^$"; then
            INSERT_LINE=$((NEXT_LINE + 1))
        fi

        # Insert new date section
        sed -i "${INSERT_LINE}i\\### $TODAY\\n- $CHANGE_MESSAGE\\n" "$CLAUDE_MD"
        echo "✅ Created new Recent Changes entry for $TODAY"
    fi
else
    echo -e "${YELLOW}⚠️  'Recent Changes' section not found in CLAUDE.md${NC}"
fi

# Update search index if requested
if [ "$UPDATE_INDEX" = "yes" ]; then
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    echo "🔍 Updating search index for $PROJECT_NAME..."

    if python3 /home/administrator/projects/devscripts/build-claude-index.py --project "$PROJECT_NAME" 2>/dev/null; then
        echo "✅ Search index updated"
    else
        echo -e "${YELLOW}⚠️  Search index update failed (non-fatal)${NC}"
    fi
fi

echo -e "${GREEN}✅ CLAUDE.md auto-update complete${NC}"
