#!/bin/sh
# test-normalize.sh — Unit tests for commit-normalize.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="${SCRIPT_DIR}/commit-normalize.sh"
TMPFILE=$(mktemp)
PASS=0
FAIL=0

cleanup() { rm -f "$TMPFILE"; }
trap cleanup EXIT

assert_eq() {
  test_name="$1"
  input="$2"
  expected="$3"

  printf '%s' "$input" > "$TMPFILE"
  "$HOOK" "$TMPFILE" 2>/dev/null || true
  actual=$(cat "$TMPFILE")

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$test_name"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s\n' "$test_name"
    printf '    input:    %s\n' "$(echo "$input" | head -n 1)"
    printf '    expected: %s\n' "$(echo "$expected" | head -n 1)"
    printf '    actual:   %s\n' "$(echo "$actual" | head -n 1)"
  fi
}

echo "=== commit-normalize tests ==="

# --- Already correct ---
assert_eq "already correct" \
  "feat: Add new feature" \
  "feat: Add new feature"

# --- Uppercase type ---
assert_eq "uppercase type lowercased" \
  "FIX: Resolve crash" \
  "fix: Resolve crash"

# --- Mixed case type ---
assert_eq "mixed case type" \
  "Feat: something" \
  "feat: Something"

# --- No type prefix, keyword detection ---
assert_eq "auto-detect fix" \
  "fix a bug in parser" \
  "fix: Fix a bug in parser"

assert_eq "auto-detect feat via add" \
  "add new login page" \
  "feat: Add new login page"

assert_eq "auto-detect docs via readme" \
  "updated README" \
  "docs: Updated README"

assert_eq "auto-detect test" \
  "add test for auth module" \
  "test: Add test for auth module"

assert_eq "auto-detect style via format" \
  "format code with prettier" \
  "style: Format code with prettier"

assert_eq "auto-detect refactor" \
  "refactor user service" \
  "refactor: Refactor user service"

assert_eq "auto-detect build via dep" \
  "update dependencies" \
  "build: Update dependencies"

assert_eq "auto-detect perf via optim" \
  "optimize database queries" \
  "perf: Optimize database queries"

assert_eq "fallback to chore" \
  "some random change" \
  "chore: Some random change"

# --- Capitalize description ---
assert_eq "capitalize description" \
  "fix: resolve issue" \
  "fix: Resolve issue"

# --- Extra whitespace around colon ---
assert_eq "whitespace around colon" \
  "fix :  resolve issue" \
  "fix: Resolve issue"

# --- Scoped type preserved ---
assert_eq "scoped type preserved" \
  "feat(api): add endpoint" \
  "feat(api): Add endpoint"

# --- Invalid type becomes chore ---
assert_eq "invalid type defaults to chore" \
  "banana: something weird" \
  "chore: Banana: something weird"

# --- Merge commit passthrough ---
assert_eq "merge commit passthrough" \
  "Merge branch 'main' into feature" \
  "Merge branch 'main' into feature"

# --- Body with blank line ---
assert_eq "body with existing blank line" \
  "feat: Add feature

This is the body" \
  "feat: Add feature

This is the body"

# --- Body without blank line ---
assert_eq "body without blank line gets one" \
  "feat: Add feature
This is the body" \
  "feat: Add feature

This is the body"

# --- Comment lines stripped ---
assert_eq "comment lines stripped" \
  "fix: Bug fix
# This is a comment
Details here" \
  "fix: Bug fix

Details here"

# --- Empty message ---
assert_eq "empty message passthrough" \
  "" \
  ""

# --- Trailing period removal ---
assert_eq "trailing period stripped" \
  "feat: Add new feature." \
  "feat: Add new feature"

assert_eq "multiple trailing periods stripped" \
  "fix: Resolve bug..." \
  "fix: Resolve bug"

assert_eq "trailing period with auto-detect" \
  "fix a bug." \
  "fix: Fix a bug"

# --- fixup!/squash!/amend! passthrough ---
assert_eq "fixup commit passthrough" \
  "fixup! feat: Add feature" \
  "fixup! feat: Add feature"

assert_eq "squash commit passthrough" \
  "squash! fix: Resolve crash" \
  "squash! fix: Resolve crash"

assert_eq "amend commit passthrough" \
  "amend! chore: Update deps" \
  "amend! chore: Update deps"

# --- Breaking change indicator ---
assert_eq "breaking change preserved" \
  "feat!: Drop support for Node 12" \
  "feat!: Drop support for Node 12"

assert_eq "breaking change with scope" \
  "fix(api)!: Remove deprecated endpoint" \
  "fix(api)!: Remove deprecated endpoint"

assert_eq "breaking change uppercase normalized" \
  "FEAT!: Major rewrite" \
  "feat!: Major rewrite"

# --- Trailer preservation ---
assert_eq "trailers preserved in body" \
  "feat: Add feature

This is the body.

Signed-off-by: Alice <alice@example.com>" \
  "feat: Add feature

This is the body.

Signed-off-by: Alice <alice@example.com>"

assert_eq "multiple trailers preserved" \
  "fix: Fix bug

Details here.

Co-Authored-By: Bob <bob@example.com>
Nightshift-Task: my-task" \
  "fix: Fix bug

Details here.

Co-Authored-By: Bob <bob@example.com>
Nightshift-Task: my-task"

assert_eq "trailers preserved with normalization" \
  "FIX: resolve crash.

Signed-off-by: Alice <alice@example.com>" \
  "fix: Resolve crash

Signed-off-by: Alice <alice@example.com>"

assert_eq "trailers without body text" \
  "feat: Add feature

Signed-off-by: Alice <alice@example.com>" \
  "feat: Add feature

Signed-off-by: Alice <alice@example.com>"

assert_eq "trailers with auto-detect type" \
  "fix a bug

Nightshift-Task: foo
Nightshift-Ref: https://example.com" \
  "fix: Fix a bug

Nightshift-Task: foo
Nightshift-Ref: https://example.com"

# --- --check mode ---
assert_check_pass() {
  test_name="$1"
  input="$2"

  printf '%s' "$input" > "$TMPFILE"
  if "$HOOK" --check "$TMPFILE" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$test_name"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (expected exit 0, got non-zero)\n' "$test_name"
  fi
}

assert_check_fail() {
  test_name="$1"
  input="$2"

  printf '%s' "$input" > "$TMPFILE"
  if "$HOOK" --check "$TMPFILE" 2>/dev/null; then
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (expected exit 1, got 0)\n' "$test_name"
  else
    PASS=$((PASS + 1))
    printf '  PASS: %s\n' "$test_name"
  fi
  # Verify file was NOT modified
  actual=$(cat "$TMPFILE")
  if [ "$actual" != "$input" ]; then
    FAIL=$((FAIL + 1))
    printf '  FAIL: %s (file was modified in --check mode)\n' "$test_name"
  fi
}

assert_check_pass "check mode: already normalized passes" \
  "feat: Add new feature"

assert_check_fail "check mode: needs normalization fails" \
  "FIX: resolve crash."

assert_check_pass "check mode: merge commit passes" \
  "Merge branch 'main' into feature"

assert_check_fail "check mode: missing type prefix fails" \
  "fix a bug in parser"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
