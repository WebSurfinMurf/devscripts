#!/bin/bash
# Bulk CLAUDE.md Generator
# Generates CLAUDE.md for all projects that don't have one

OUTPUT_REPORT="/tmp/bulk-claude-generation-$(date +%Y%m%d-%H%M%S).txt"

echo "=== Bulk CLAUDE.md Generator ===" | tee "$OUTPUT_REPORT"
echo "Started: $(date)" | tee -a "$OUTPUT_REPORT"
echo "" | tee -a "$OUTPUT_REPORT"

TOTAL=0
CREATED=0
SKIPPED=0
ERRORS=0

for project_dir in /home/administrator/projects/*/; do
  PROJECT=$(basename "$project_dir")

  # Skip special directories
  if [[ "$PROJECT" == "admin" || "$PROJECT" == "data" || "$PROJECT" == "devscripts" || "$PROJECT" == "claude" ]]; then
    continue
  fi

  TOTAL=$((TOTAL + 1))

  # Check if CLAUDE.md already exists
  if [ -f "$project_dir/CLAUDE.md" ]; then
    echo "⏭️  SKIP: $PROJECT (CLAUDE.md already exists)" | tee -a "$OUTPUT_REPORT"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Check if project has docker-compose.yml
  if [ ! -f "$project_dir/docker-compose.yml" ]; then
    echo "⏭️  SKIP: $PROJECT (no docker-compose.yml)" | tee -a "$OUTPUT_REPORT"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  echo "🔧 Generating: $PROJECT" | tee -a "$OUTPUT_REPORT"

  # Use claudemd-generator skill
  # For now, create a basic template
  cat > "$project_dir/CLAUDE.md" <<EOF
# $PROJECT

**Status**: 🚧 Development
**Version**: 1.0.0
**Deployed**: $(date +%Y-%m-%d)
**Last Updated**: $(date +%Y-%m-%d)
**Purpose**: Service deployment (auto-generated, needs manual update)

---

## Quick Start

### Deploy
\`\`\`bash
cd /home/administrator/projects/$PROJECT
./deploy.sh
\`\`\`

### Access
- **URL**: https://$PROJECT.ai-servicers.com

---

## Architecture

### Components
- $PROJECT: Main service

### Networks
$(grep -A 10 "networks:" "$project_dir/docker-compose.yml" 2>/dev/null | grep "^  - " | sed 's/^  - /- /' || echo "- traefik-net")

### Ports
$(grep -A 10 "ports:" "$project_dir/docker-compose.yml" 2>/dev/null | grep "^  - " | sed 's/^  - /- /' || echo "- Check docker-compose.yml")

---

## Operations

### View Logs
\`\`\`bash
docker logs $PROJECT -f
\`\`\`

### Restart Service
\`\`\`bash
cd /home/administrator/projects/$PROJECT
docker compose restart $PROJECT
\`\`\`

---

## Recent Changes

### $(date +%Y-%m-%d)
- Auto-generated CLAUDE.md using bulk generator
- Needs manual review and updates

---

**For infrastructure-wide context, see: \`/home/administrator/projects/CLAUDE.md\`**

**⚠️ This file was auto-generated. Please review and update with accurate project information.**
EOF

  if [ $? -eq 0 ]; then
    echo "✅ Created: $PROJECT" | tee -a "$OUTPUT_REPORT"
    CREATED=$((CREATED + 1))
  else
    echo "❌ Error: $PROJECT (creation failed)" | tee -a "$OUTPUT_REPORT"
    ERRORS=$((ERRORS + 1))
  fi
done

echo "" | tee -a "$OUTPUT_REPORT"
echo "=== Summary ===" | tee -a "$OUTPUT_REPORT"
echo "Total projects scanned: $TOTAL" | tee -a "$OUTPUT_REPORT"
echo "CLAUDE.md created: $CREATED" | tee -a "$OUTPUT_REPORT"
echo "Skipped (already exist): $SKIPPED" | tee -a "$OUTPUT_REPORT"
echo "Errors: $ERRORS" | tee -a "$OUTPUT_REPORT"
echo "" | tee -a "$OUTPUT_REPORT"
echo "Report saved: $OUTPUT_REPORT" | tee -a "$OUTPUT_REPORT"
echo "Finished: $(date)" | tee -a "$OUTPUT_REPORT"
echo ""
echo "⚠️  Next steps:"
echo "1. Review auto-generated files: ls -la /home/administrator/projects/*/CLAUDE.md"
echo "2. Validate quality: /validate-claude for each project"
echo "3. Update with accurate project information"
