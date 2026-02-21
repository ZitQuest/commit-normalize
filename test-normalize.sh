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

# === Installer integration tests ===

echo ""
echo "=== install.sh tests ==="

INSTALLER="${SCRIPT_DIR}/install.sh"
TEST_REPO=$(mktemp -d)
ORIG_GLOBAL_HOOKS_PATH=$(git config --global core.hooksPath 2>/dev/null || true)

installer_cleanup() {
  rm -f "$TMPFILE"
  rm -rf "$TEST_REPO"
  # Restore original global hooksPath
  if [ -n "$ORIG_GLOBAL_HOOKS_PATH" ]; then
    git config --global core.hooksPath "$ORIG_GLOBAL_HOOKS_PATH"
  else
    git config --global --unset core.hooksPath 2>/dev/null || true
  fi
  rm -rf "$HOME/.git-hooks-test-backup"
}
trap installer_cleanup EXIT

# Create a test git repo
git init "$TEST_REPO" >/dev/null 2>&1

# --- Per-repo install ---
install_output=$("$INSTALLER" "$TEST_REPO" 2>&1)
if [ -L "${TEST_REPO}/.git/hooks/commit-msg" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: per-repo install creates symlink\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: per-repo install creates symlink\n'
fi

# Verify symlink target
link_target=$(readlink "${TEST_REPO}/.git/hooks/commit-msg")
if [ "$link_target" = "$SCRIPT_DIR/commit-normalize.sh" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: symlink points to commit-normalize.sh\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: symlink points to commit-normalize.sh (got: %s)\n' "$link_target"
fi

# --- Per-repo install over existing hook creates backup ---
rm -f "${TEST_REPO}/.git/hooks/commit-msg"
echo "#!/bin/sh" > "${TEST_REPO}/.git/hooks/commit-msg"
"$INSTALLER" "$TEST_REPO" 2>/dev/null
if [ -e "${TEST_REPO}/.git/hooks/commit-msg.bak" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: per-repo install backs up existing hook\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: per-repo install backs up existing hook\n'
fi

# --- Per-repo uninstall ---
"$INSTALLER" --uninstall "$TEST_REPO" 2>/dev/null
if [ ! -e "${TEST_REPO}/.git/hooks/commit-msg" ] || [ "$(cat "${TEST_REPO}/.git/hooks/commit-msg")" = "#!/bin/sh" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: per-repo uninstall removes hook or restores backup\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: per-repo uninstall removes hook or restores backup\n'
fi

# Verify backup was restored
if [ -e "${TEST_REPO}/.git/hooks/commit-msg" ] && [ "$(cat "${TEST_REPO}/.git/hooks/commit-msg")" = "#!/bin/sh" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: per-repo uninstall restores backup\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: per-repo uninstall restores backup\n'
fi

# --- Per-repo uninstall when no hook exists ---
rm -f "${TEST_REPO}/.git/hooks/commit-msg" "${TEST_REPO}/.git/hooks/commit-msg.bak"
uninstall_output=$("$INSTALLER" --uninstall "$TEST_REPO" 2>&1)
if echo "$uninstall_output" | grep -q "No hook found"; then
  PASS=$((PASS + 1))
  printf '  PASS: uninstall with no hook prints message\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: uninstall with no hook prints message\n'
fi

# --- Global install ---
# Back up existing global hooks dir if it exists
if [ -d "$HOME/.git-hooks" ]; then
  mv "$HOME/.git-hooks" "$HOME/.git-hooks-test-backup"
fi

"$INSTALLER" --global 2>/dev/null
if [ -L "$HOME/.git-hooks/commit-msg" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: global install creates symlink\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: global install creates symlink\n'
fi

global_hooks_path=$(git config --global core.hooksPath 2>/dev/null || true)
if [ "$global_hooks_path" = "$HOME/.git-hooks" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: global install sets core.hooksPath\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: global install sets core.hooksPath (got: %s)\n' "$global_hooks_path"
fi

# --- Global uninstall ---
"$INSTALLER" --uninstall --global 2>/dev/null
if [ ! -e "$HOME/.git-hooks/commit-msg" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: global uninstall removes hook\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: global uninstall removes hook\n'
fi

global_hooks_path_after=$(git config --global core.hooksPath 2>/dev/null || true)
if [ -z "$global_hooks_path_after" ]; then
  PASS=$((PASS + 1))
  printf '  PASS: global uninstall clears core.hooksPath\n'
else
  FAIL=$((FAIL + 1))
  printf '  FAIL: global uninstall clears core.hooksPath (got: %s)\n' "$global_hooks_path_after"
fi

# Restore backed-up global hooks dir
if [ -d "$HOME/.git-hooks-test-backup" ]; then
  mv "$HOME/.git-hooks-test-backup" "$HOME/.git-hooks"
fi

# --- Unknown flag ---
if "$INSTALLER" --bogus 2>/dev/null; then
  FAIL=$((FAIL + 1))
  printf '  FAIL: unknown flag exits non-zero\n'
else
  PASS=$((PASS + 1))
  printf '  PASS: unknown flag exits non-zero\n'
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
