#!/bin/sh
# install.sh — Install or uninstall commit-normalize as a git commit-msg hook
# Usage: ./install.sh [--global | --uninstall | --uninstall --global] [/path/to/repo]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SRC="${SCRIPT_DIR}/commit-normalize.sh"

# Parse flags
GLOBAL=0
UNINSTALL=0
REPO_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --global)    GLOBAL=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo "Usage: $0 [--global] [--uninstall] [/path/to/repo]" >&2
      exit 1
      ;;
    *)
      REPO_DIR="$1"; shift ;;
  esac
done

# --- Global mode ---

GLOBAL_HOOKS_DIR="$HOME/.git-hooks"

if [ "$GLOBAL" -eq 1 ] && [ "$UNINSTALL" -eq 1 ]; then
  # Uninstall global hook
  HOOK_DST="${GLOBAL_HOOKS_DIR}/commit-msg"
  if [ -e "$HOOK_DST" ]; then
    rm "$HOOK_DST"
    echo "Removed global commit-normalize hook from ${HOOK_DST}"
  else
    echo "No global hook found at ${HOOK_DST}" >&2
  fi
  # Restore backup if it exists
  if [ -e "${HOOK_DST}.bak" ]; then
    mv "${HOOK_DST}.bak" "$HOOK_DST"
    echo "Restored backup to ${HOOK_DST}"
  fi
  # Unset hooksPath if it points to our directory
  current_hooks_path=$(git config --global core.hooksPath 2>/dev/null || true)
  if [ "$current_hooks_path" = "$GLOBAL_HOOKS_DIR" ]; then
    git config --global --unset core.hooksPath
    echo "Cleared global core.hooksPath"
  fi
  # Remove directory if empty
  if [ -d "$GLOBAL_HOOKS_DIR" ] && [ -z "$(ls -A "$GLOBAL_HOOKS_DIR" 2>/dev/null)" ]; then
    rmdir "$GLOBAL_HOOKS_DIR"
  fi
  exit 0
fi

if [ "$GLOBAL" -eq 1 ] && [ "$UNINSTALL" -eq 0 ]; then
  # Install globally
  mkdir -p "$GLOBAL_HOOKS_DIR"
  HOOK_DST="${GLOBAL_HOOKS_DIR}/commit-msg"
  if [ -e "$HOOK_DST" ]; then
    echo "Warning: ${HOOK_DST} already exists, backing up to ${HOOK_DST}.bak" >&2
    cp "$HOOK_DST" "${HOOK_DST}.bak"
  fi
  ln -sf "$HOOK_SRC" "$HOOK_DST"
  git config --global core.hooksPath "$GLOBAL_HOOKS_DIR"
  echo "Installed commit-normalize hook globally to ${HOOK_DST}"
  echo "Set git config --global core.hooksPath=${GLOBAL_HOOKS_DIR}"
  exit 0
fi

# --- Per-repo mode ---

REPO_DIR="${REPO_DIR:-.}"

# Resolve to absolute path
REPO_DIR="$(cd "$REPO_DIR" && pwd)"

GIT_DIR="${REPO_DIR}/.git"

if [ ! -d "$GIT_DIR" ]; then
  echo "Error: ${REPO_DIR} is not a git repository" >&2
  exit 1
fi

HOOKS_DIR="${GIT_DIR}/hooks"
HOOK_DST="${HOOKS_DIR}/commit-msg"

if [ "$UNINSTALL" -eq 1 ]; then
  # Uninstall per-repo hook
  if [ -e "$HOOK_DST" ]; then
    rm "$HOOK_DST"
    echo "Removed commit-normalize hook from ${HOOK_DST}"
  else
    echo "No hook found at ${HOOK_DST}" >&2
  fi
  # Restore backup if it exists
  if [ -e "${HOOK_DST}.bak" ]; then
    mv "${HOOK_DST}.bak" "$HOOK_DST"
    echo "Restored backup to ${HOOK_DST}"
  fi
  exit 0
fi

# Install per-repo
mkdir -p "$HOOKS_DIR"

if [ -e "$HOOK_DST" ]; then
  echo "Warning: ${HOOK_DST} already exists, backing up to ${HOOK_DST}.bak" >&2
  cp "$HOOK_DST" "${HOOK_DST}.bak"
fi

ln -sf "$HOOK_SRC" "$HOOK_DST"
echo "Installed commit-normalize hook to ${HOOK_DST}"
