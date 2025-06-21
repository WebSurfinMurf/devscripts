#!/usr/bin/env bash
set -euo pipefail   # exit on error, unset var, or pipe failure

# Usage check
if [ $# -ne 1 ]; then
  echo "Usage: $0 <GitHub-project-name>"
  echo "Example: $0 MyNewApp"
  exit 1
fi

PROJECT="$1"
BASE_DIR="${HOME}/projects"
TARGET_DIR="${BASE_DIR}/${PROJECT}"
REPO_SSH="git@github.com:WebSurfinMurf/${PROJECT}.git"

# AI note: ensure your SSH key is added to your GitHub account
#AI: you can test your SSH connection with `ssh -T git@github.com` before running this.

echo "ℹ️  Initializing project '${PROJECT}' in ${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
cd "${TARGET_DIR}"

# If already a git repo, bail out
if [ -d ".git" ]; then
  echo "⚠️  Directory already contains a Git repo. Skipping clone."
  exit 0
fi

echo "⏬ Cloning via SSH (${REPO_SSH}) into current directory…"
git clone --depth 1 "${REPO_SSH}" .

echo "✅ Project '${PROJECT}' initialized successfully."
