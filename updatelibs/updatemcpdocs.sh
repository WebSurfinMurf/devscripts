#!/usr/bin/env bash
# updatemcpdocs.sh — Generate MCP tools executive summary
#
# Queries the MCP code-executor to get current tool inventory and generates
# an executive-level summary at $HOME/projects/ainotes/shared/mcptools.md
#
# Usage: ./updatemcpdocs.sh
# Dependencies: curl, jq

set -euo pipefail

OUTPUT_DIR="$HOME/projects/ainotes/shared"
OUTPUT_FILE="$OUTPUT_DIR/mcptools.md"
MCP_ENDPOINT="http://localhost:3001"

echo "=== updatemcpdocs: Generating MCP Tools Summary ==="
echo "Output: $OUTPUT_FILE"
echo ""

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Try to query live MCP tool list via code-executor
LIVE_DATA=""
if command -v curl &>/dev/null && curl -sf "${MCP_ENDPOINT}/health" &>/dev/null 2>&1; then
    echo "Querying MCP code-executor for live tool data..."
    LIVE_DATA=$(curl -sf --max-time 10 "${MCP_ENDPOINT}/api/tools" 2>/dev/null || true)
fi

# Parse live data if available, otherwise use static fallback
if [ -n "$LIVE_DATA" ] && echo "$LIVE_DATA" | jq -e '.toolsByServer' &>/dev/null 2>&1; then
    echo "Using live MCP data"
    TOTAL_TOOLS=$(echo "$LIVE_DATA" | jq '.totalTools')
    TOTAL_SERVERS=$(echo "$LIVE_DATA" | jq '.servers')
    UPDATED_SOURCE="live query"
else
    echo "Using static inventory (run inside Claude Code for live data)"
    TOTAL_TOOLS=71
    TOTAL_SERVERS=9
    UPDATED_SOURCE="static inventory"
fi

TIMESTAMP=$(date -Iseconds)
DATE_SHORT=$(date +%Y-%m-%d)

cat > "$OUTPUT_FILE" << 'HEADER'
# MCP Tools Reference

> **Executive summary for awareness.** For complete tool signatures and options,
> use the MCP code-executor inside Claude Code:
> ```
> mcp__code-executor__list_mcp_tools()        # List all tools by server
> mcp__code-executor__search_tools()           # Search by keyword
> mcp__code-executor__get_tool_info()          # Get full tool details
> ```

HEADER

cat >> "$OUTPUT_FILE" << EOF
**${TOTAL_SERVERS} servers | ${TOTAL_TOOLS} tools** (source: ${UPDATED_SOURCE}, ${DATE_SHORT})

---

## Tool Categories

| Category | Server | Tools | Capabilities |
|----------|--------|-------|-------------|
| **Database** | postgres | 9 | Query, describe tables, list schemas/indexes/constraints, table stats |
| **Time-Series** | timescaledb | 6 | Query, describe tables, list hypertables, table stats |
| **Multi-Model DB** | arangodb | 7 | AQL queries, CRUD operations, collection management, backups |
| **Object Storage** | minio | 9 | Bucket CRUD, object upload/download/delete, size and info queries |
| **Filesystem** | filesystem | 9 | Read/write files, directory ops, search, file info, move |
| **Knowledge Graph** | memory | 9 | Entity/relation/observation CRUD, graph traversal, node search |
| **Browser Automation** | playwright | 6 | Navigate, click, fill forms, extract text, screenshots |
| **Workflow Engine** | n8n | 6 | List/execute/activate workflows, view credentials and executions |
| **Financial Data** | ib | 10 | Account summary, positions, contracts, historical data, news |

## Category Details

### Database & Storage
- **postgres** — Full PostgreSQL introspection and query execution. Schema browsing, index analysis, constraint inspection, and table statistics.
- **timescaledb** — TimescaleDB extension operations. Hypertable management, time-series queries, and standard table operations.
- **arangodb** — Multi-model database (document, graph, key-value). AQL query execution, collection management, document CRUD, and backups.
- **minio** — S3-compatible object storage. Bucket lifecycle, object upload/download, storage metrics.

### Knowledge & Files
- **filesystem** — Sandboxed file operations within allowed directories. Read, write, search, move files and manage directories.
- **memory** — Persistent knowledge graph. Create entities with observations, define relationships, traverse and search the graph.

### Automation & Integration
- **playwright** — Headless browser automation. Page navigation, element interaction, form filling, text extraction, and screenshot capture.
- **n8n** — Workflow automation platform. Trigger and monitor workflows, inspect credentials and execution history.

### Financial
- **ib** — Interactive Brokers API (paper trading). Account data, position tracking, contract lookup, historical market data, and news articles.

---

EOF

cat >> "$OUTPUT_FILE" << 'FOOTER'
## Planning Reference

For phase 2 planning and architecture reviews, consult the view board presentation at:
- **AI Agents Matrix**: https://nginx.ai-servicers.com/shared/createsolution/ai-agents-matrix/
- **Agent Coordination**: https://nginx.ai-servicers.com/shared/createplan/agent-coordination/

All MCP tools are available to aiagentchat agents via the code-executor MCP server.

---
FOOTER

echo "Last generated: ${TIMESTAMP}" >> "$OUTPUT_FILE"

echo ""
echo "=== Done ==="
echo "Generated: $OUTPUT_FILE"
echo "Servers:   $TOTAL_SERVERS"
echo "Tools:     $TOTAL_TOOLS"
echo "Source:    $UPDATED_SOURCE"
