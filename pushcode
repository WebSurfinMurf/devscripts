#!/usr/bin/env bash
set -euo pipefail

# Usage: ./update_repo.sh "Your commit message"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <commit-message>"
  exit 1
fi

COMMIT_MSG="$1"

# Switch to main branch and update
git checkout main
git pull origin main

# Stage all changes
git add --all

# Commit with provided message
git commit -m "$COMMIT_MSG"

# Push back to origin
git push origin main
