#!/bin/bash

# Script to delete specified MCP repositories from GitHub
# Run this after executing: gh auth refresh -h github.com -s delete_repo
#Logout:
#  gh auth logout
#
#Login:
#  gh auth login



repos=(
  "infisical"
  "mailu"
  "pipeline-runner"
  "plane"
  "postgres-mcp"
  "ai"
)

echo "This will delete the following repositories from your GitHub account:"
for repo in "${repos[@]}"; do
  echo "  - WebSurfinMurf/$repo"
done

echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Deleting repositories..."

for repo in "${repos[@]}"; do
  echo "Deleting WebSurfinMurf/$repo..."
  gh repo delete "WebSurfinMurf/$repo" --yes
  if [ $? -eq 0 ]; then
    echo "  ✓ Deleted"
  else
    echo "  ✗ Failed"
  fi
done

echo ""
echo "Done!"
