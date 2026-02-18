#!/bin/sh
# commit-normalize.sh — git commit-msg hook
# Normalizes commit messages to Conventional Commits format.
# Usage: Place as .git/hooks/commit-msg (must be executable)

set -e

COMMIT_MSG_FILE="$1"

if [ -z "$COMMIT_MSG_FILE" ]; then
  echo "Usage: $0 <commit-msg-file>" >&2
  exit 1
fi

VALID_TYPES="feat fix docs style refactor test chore build ci perf revert"
MAX_SUBJECT_LENGTH=72

# Read the commit message
msg=$(cat "$COMMIT_MSG_FILE")

# Strip comment lines (lines starting with #)
cleaned=$(echo "$msg" | sed '/^#/d')

# Separate subject from body
subject=$(echo "$cleaned" | head -n 1)
body=$(echo "$cleaned" | tail -n +2)

# Skip merge commits and empty messages
case "$subject" in
  Merge\ *) exit 0 ;;
esac

if [ -z "$subject" ]; then
  exit 0
fi

# Skip fixup!, squash!, and amend! commits (used by interactive rebase)
case "$subject" in
  fixup!\ *|squash!\ *|amend!\ *) exit 0 ;;
esac

# --- Detect and normalize type prefix ---

detected_type=""
description=""

# Check if subject already has a type prefix (with optional scope and breaking !) followed by colon
if echo "$subject" | grep -qE '^[A-Za-z]+(\([^)]*\))?!?[[:space:]]*:[[:space:]]*'; then
  # Extract the type (everything before optional scope, bang, and colon)
  raw_type=$(echo "$subject" | sed -E 's/^([A-Za-z]+)(\([^)]*\))?!?[[:space:]]*:.*/\1/')
  scope=$(echo "$subject" | sed -E 's/^[A-Za-z]+(\([^)]*\))?!?[[:space:]]*:.*/\1/')
  # Detect breaking change indicator (!)
  breaking=""
  if echo "$subject" | grep -qE '^[A-Za-z]+(\([^)]*\))?![[:space:]]*:'; then
    breaking="!"
  fi
  description=$(echo "$subject" | sed -E 's/^[A-Za-z]+(\([^)]*\))?!?[[:space:]]*:[[:space:]]*//')

  # Lowercase the type
  normalized_type=$(echo "$raw_type" | tr '[:upper:]' '[:lower:]')

  # Validate type
  valid=0
  for t in $VALID_TYPES; do
    if [ "$normalized_type" = "$t" ]; then
      valid=1
      break
    fi
  done

  if [ "$valid" -eq 1 ]; then
    detected_type="$normalized_type"
  else
    # Unknown type prefix — treat entire subject as description, default to chore
    detected_type="chore"
    description="$subject"
    scope=""
    breaking=""
  fi
else
  # No type prefix found — auto-detect from keywords
  lower_subject=$(echo "$subject" | tr '[:upper:]' '[:lower:]')
  scope=""
  breaking=""

  case "$lower_subject" in
    *fix*|*bug*|*patch*|*resolve*)   detected_type="fix" ;;
    *test*)                          detected_type="test" ;;
    *doc*|*readme*)                  detected_type="docs" ;;
    *refactor*|*restructure*)        detected_type="refactor" ;;
    *style*|*format*|*lint*)         detected_type="style" ;;
    *perf*|*optim*)                  detected_type="perf" ;;
    *feat*|*add*|*new*|*implement*) detected_type="feat" ;;
    *build*|*dep*)                   detected_type="build" ;;
    *ci*|*pipeline*)                 detected_type="ci" ;;
    *revert*)                        detected_type="revert" ;;
    *)                               detected_type="chore" ;;
  esac

  description="$subject"
fi

# --- Normalize description ---

# Trim leading/trailing whitespace
description=$(echo "$description" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# Strip trailing period(s)
description=$(echo "$description" | sed -e 's/\.*$//')

# Capitalize first letter of description
if [ -n "$description" ]; then
  first_char=$(echo "$description" | cut -c1 | tr '[:lower:]' '[:upper:]')
  rest=$(echo "$description" | cut -c2-)
  description="${first_char}${rest}"
fi

# --- Reconstruct subject ---

new_subject="${detected_type}${scope}${breaking}: ${description}"

# --- Warn if subject exceeds max length ---

subject_length=$(printf '%s' "$new_subject" | wc -c | tr -d ' ')
if [ "$subject_length" -gt "$MAX_SUBJECT_LENGTH" ]; then
  echo "Warning: commit subject is ${subject_length} chars (max ${MAX_SUBJECT_LENGTH})" >&2
fi

# --- Ensure blank line between subject and body ---

if [ -n "$body" ]; then
  # Check if body starts with a blank line
  first_body_line=$(echo "$body" | head -n 1)
  if [ -n "$first_body_line" ]; then
    body="
${body}"
  fi
fi

# --- Write normalized message ---

printf '%s\n' "$new_subject" > "$COMMIT_MSG_FILE"
if [ -n "$body" ]; then
  printf '%s\n' "$body" >> "$COMMIT_MSG_FILE"
fi
