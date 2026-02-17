#!/bin/sh
# install.sh — Install commit-normalize as a git commit-msg hook
# Usage: ./install.sh [/path/to/repo]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SRC="${SCRIPT_DIR}/commit-normalize.sh"

REPO_DIR="${1:-.}"

# Resolve to absolute path
REPO_DIR="$(cd "$REPO_DIR" && pwd)"

GIT_DIR="${REPO_DIR}/.git"

if [ ! -d "$GIT_DIR" ]; then
  echo "Error: ${REPO_DIR} is not a git repository" >&2
  exit 1
fi

HOOKS_DIR="${GIT_DIR}/hooks"
HOOK_DST="${HOOKS_DIR}/commit-msg"

mkdir -p "$HOOKS_DIR"

if [ -e "$HOOK_DST" ]; then
  echo "Warning: ${HOOK_DST} already exists, backing up to ${HOOK_DST}.bak" >&2
  cp "$HOOK_DST" "${HOOK_DST}.bak"
fi

ln -sf "$HOOK_SRC" "$HOOK_DST"
echo "Installed commit-normalize hook to ${HOOK_DST}"
