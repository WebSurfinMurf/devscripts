#!/usr/bin/env bash
set -euo pipefail

# claudesharedsetup.sh - Clone and set up shared Claude Code configuration
# Run as any user (websurfinmurf, joe, etc.) to get developer agents and shared config

REPO_URL="ssh://git@gitlab.ai-servicers.com:2222/administrators/claudecodeconfig.git"
CLONE_DIR="${HOME}/projects/claudecodeconfig"

echo "========================================"
echo "Claude Code Shared Config Setup"
echo "========================================"
echo ""
echo "User: ${USER}"
echo "Home: ${HOME}"
echo ""

# Step 1: Clone or pull
if [[ -d "${CLONE_DIR}/.git" ]]; then
  echo "[1/3] Repository exists, pulling latest..."
  git -C "${CLONE_DIR}" pull
else
  echo "[1/3] Cloning claudecodeconfig..."
  mkdir -p "${HOME}/projects"
  git clone "${REPO_URL}" "${CLONE_DIR}"
fi

echo ""

# Step 2: Run gitsyncfirst.sh pull (syncs developer/ -> ~/projects/.claude/ and shared agents)
echo "[2/3] Running gitsyncfirst.sh pull..."
cd "${CLONE_DIR}"
bash ./gitsyncfirst.sh pull

echo ""

# Step 3: Verify
echo "[3/3] Verifying setup..."
echo ""

PASS=0
FAIL=0

for f in "${HOME}/projects/.claude/agents/architect.md" \
         "${HOME}/projects/.claude/agents/security.md" \
         "${HOME}/projects/.claude/agents/developer.md" \
         "${HOME}/projects/.claude/CLAUDE.md" \
         "${HOME}/.claude/agents/pm.md"; do
  if [[ -f "$f" ]]; then
    echo "  OK  $f"
    ((PASS++))
  else
    echo "  MISSING  $f"
    ((FAIL++))
  fi
done

echo ""
echo "========================================"
if [[ ${FAIL} -eq 0 ]]; then
  echo "Setup complete! ${PASS} files verified."
else
  echo "Setup done with ${FAIL} missing file(s). Check above."
fi
echo "========================================"
echo ""
echo "Files to review:"
echo "  ${HOME}/projects/.claude/agents/architect.md"
echo "  ${HOME}/projects/.claude/agents/security.md"
echo "  ${HOME}/projects/.claude/agents/developer.md"
echo "  ${HOME}/projects/.claude/CLAUDE.md"
echo "  ${HOME}/.claude/agents/pm.md"
