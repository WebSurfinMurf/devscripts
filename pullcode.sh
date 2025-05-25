#!/usr/bin/env bash
set -euo pipefail   # exit on error, undefined var, or pipeline failure

# switch to the main branch
git checkout main

# pull the latest from origin/main
git pull origin main
