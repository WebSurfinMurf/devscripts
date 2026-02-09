#!/usr/bin/env bash
# jeffallanupdate.sh — Fetch selected skills from Jeffallan/claude-skills
#
# Source: https://github.com/Jeffallan/claude-skills (MIT license)
# Installs curated skills into ~/.claude/skills/ (flat, alongside local skills)
# Installs curated commands into ~/.claude/commands/
# Tracks source metadata in ~/.claude/skills/jeffallan/VERSION
#
# Usage: ./jeffallanupdate.sh

set -euo pipefail

REPO_URL="https://github.com/Jeffallan/claude-skills.git"
REPO_BRANCH="main"
SKILLS_DIR="$HOME/.claude/skills"
COMMANDS_DIR="$HOME/.claude/commands"
META_DIR="$SKILLS_DIR/jeffallan"
TMP_DIR=$(mktemp -d)

# Skills to install (curated subset of 65)
SKILLS=(
    feature-forge
    spec-miner
    python-pro
    postgres-pro
    typescript-pro
)

# Commands to install
COMMANDS=(
    common-ground
    intake
)

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "=== jeffallanupdate: Fetching Jeffallan/claude-skills ==="
echo "Repo:     $REPO_URL"
echo "Branch:   $REPO_BRANCH"
echo "Skills:   $SKILLS_DIR/{name}/"
echo "Commands: $COMMANDS_DIR/{name}/"
echo ""

# Shallow clone to temp
git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_DIR/repo" 2>&1 | tail -1

# Get version from plugin.json
VERSION=$(python3 -c "import json; print(json.load(open('$TMP_DIR/repo/.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo "unknown")
echo "Source version: $VERSION"
echo ""

# Install skills (flat into ~/.claude/skills/)
echo "Installing ${#SKILLS[@]} skills..."
installed=0
for skill in "${SKILLS[@]}"; do
    src="$TMP_DIR/repo/skills/$skill"
    dst="$SKILLS_DIR/$skill"
    if [ -d "$src" ]; then
        rm -rf "$dst"
        cp -r "$src" "$dst"
        echo "  + $skill"
        installed=$((installed + 1))
    else
        echo "  ! $skill (not found in repo, skipping)"
    fi
done
echo "  $installed skills installed"
echo ""

# Install commands (flat into ~/.claude/commands/)
echo "Installing ${#COMMANDS[@]} command groups..."
mkdir -p "$COMMANDS_DIR"
for cmd in "${COMMANDS[@]}"; do
    src="$TMP_DIR/repo/commands/$cmd"
    dst="$COMMANDS_DIR/$cmd"
    if [ -d "$src" ]; then
        rm -rf "$dst"
        cp -r "$src" "$dst"
        echo "  + $cmd/"
    else
        echo "  ! $cmd (not found in repo, skipping)"
    fi
done
echo ""

# Write version marker (metadata only — tracks what was installed)
mkdir -p "$META_DIR"
cat > "$META_DIR/VERSION" <<EOF
source: $REPO_URL
branch: $REPO_BRANCH
version: $VERSION
updated: $(date -Iseconds)
skills: ${SKILLS[*]}
commands: ${COMMANDS[*]}
EOF

echo "=== Done ==="
echo "Skills in:   $SKILLS_DIR/"
echo "Commands in: $COMMANDS_DIR/"
echo "Version:     $META_DIR/VERSION"
echo ""
echo "To update: re-run this script"
echo "To add skills: edit the SKILLS array in this script"
