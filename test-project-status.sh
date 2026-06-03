#!/usr/bin/env bash
# Smoke test for the project-status CLI. Run from anywhere.
# Asserts the engine produces a sensible briefing against ~/projects/webui-claude
# (the project whose transcript drove the spec), then exercises --read/--json.
set -uo pipefail

BIN="$HOME/projects/devscripts/project-status"
PROJ="$HOME/projects/webui-claude"
pass=0 fail=0
ok()  { echo "  PASS: $1"; pass=$((pass+1)); }
no()  { echo "  FAIL: $1"; fail=$((fail+1)); }
has() { grep -q "$1" "$2" && ok "$3" || no "$3"; }

[ -x "$BIN" ] || { echo "missing $BIN"; exit 1; }
[ -d "$PROJ" ] || { echo "SKIP: $PROJ not present"; exit 0; }
cd "$PROJ" || exit 1

echo "== render =="
out="$(mktemp)"; "$BIN" --no-color >"$out" 2>&1
[ -s "$out" ]                            && ok "non-empty output"        || no "non-empty output"
has "tmux-backbone"        "$out" "mentions tmux-backbone"
has "https://gitlab"       "$out" "surfaces a GitLab URL"
has "NEXT MOVE"            "$out" "has NEXT MOVE section"
has "RECENT SESSIONS"      "$out" "has RECENT SESSIONS section"

echo "== persisted file =="
SAVED="$PROJ/docs/project-status.md"
[ -f "$SAVED" ]                          && ok "briefing saved to docs/" || no "briefing saved to docs/"
grep -q "project-status.md" "$PROJ/.gitignore" && ok "briefing is gitignored" || no "briefing is gitignored"

echo "== --read round-trips =="
rd="$(mktemp)"; "$BIN" --read >"$rd" 2>&1
diff -q <(tail -n +12 "$SAVED") <(tail -n +12 "$rd") >/dev/null \
  && ok "--read matches saved file" || no "--read matches saved file"

echo "== --json valid =="
"$BIN" --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['identity']['name']; assert 'sessions' in d['transcripts']" \
  && ok "--json is valid & structured" || no "--json is valid & structured"

rm -f "$out" "$rd"
echo "== $pass passed, $fail failed =="
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
