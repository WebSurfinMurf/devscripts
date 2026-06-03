#!/usr/bin/env bash
# Integration smoke test for gitlab-status. Runs each mode against the LIVE GitLab
# (mocking glab is more trouble than it's worth for a tool this thin) and asserts
# the load-bearing behaviours from SPEC.md §6. Requires glab to be authenticated.
set -uo pipefail

CLI="$(dirname "$0")/gitlab-status"
PASS=0 FAIL=0

check() {  # check <description> <test-command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS  $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc"; FAIL=$((FAIL + 1))
  fi
}

echo "gitlab-status integration smoke test (live GitLab)"
echo "=================================================="

# 1. single project by full path surfaces tmux-backbone + a working issue URL
out_webui="$("$CLI" claude-webui/webui-claude 2>&1)"
check "webui-claude shows tmux-backbone" grep -q "tmux-backbone" <<<"$out_webui"
check "webui-claude shows an issue URL"  grep -q "/-/issues/"   <<<"$out_webui"

# 2. cicd surfaces context-strategy with the awaiting DECISION cards counted
out_cicd="$("$CLI" cicd 2>&1)"
check "cicd shows context-strategy"      grep -q "context-strategy"           <<<"$out_cicd"
check "cicd counts open decisions"       grep -Eq "DECISION ×[0-9]+|decisions: [0-9]+ awaiting" <<<"$out_cicd"

# 3. --all lists every project; missing-card projects show (idle)
out_all="$("$CLI" --all 2>&1)"
check "--all non-empty"                  test -n "$out_all"
check "--all includes webui-claude"      grep -q "claude-webui/webui-claude"  <<<"$out_all"
check "--all shows idle rows"            grep -q "(idle," <<<"$out_all"

# 4. --recent is a subset of --all (stale projects dropped)
n_all=$("$CLI" --all --json 2>/dev/null | jq 'length')
n_recent=$("$CLI" --recent --json 2>/dev/null | jq 'length')
check "--recent ≤ --all project count"   test "$n_recent" -le "$n_all"

# 5. --json emits valid JSON keyed by project path
check "--json valid + keyed by path" bash -c \
  "'$CLI' claude-webui/webui-claude --json 2>/dev/null | jq -e '.\"claude-webui/webui-claude\".enhancements' >/dev/null"

# 6. --all completes in < 5s
start=$(date +%s%N)
"$CLI" --all >/dev/null 2>&1
elapsed_ms=$(( ($(date +%s%N) - start) / 1000000 ))
check "--all completes < 5000ms (was ${elapsed_ms}ms)" test "$elapsed_ms" -lt 5000

# 7. piped (non-TTY) output carries no ANSI escapes
check "no ANSI when piped" bash -c "! '$CLI' cicd 2>/dev/null | grep -q $'\033'"

echo "=================================================="
echo "  $PASS passed, $FAIL failed"
exit $(( FAIL > 0 ? 1 : 0 ))
