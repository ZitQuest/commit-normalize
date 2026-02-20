#!/bin/sh
# commit-normalize.sh — git commit-msg hook
# Normalizes commit messages to Conventional Commits format.
# Usage: Place as .git/hooks/commit-msg (must be executable)
#        commit-normalize.sh --check <commit-msg-file>  (dry-run, exit 1 if changed)

set -e

# Parse flags
CHECK_MODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_MODE=1; shift ;;
    *) break ;;
  esac
done

COMMIT_MSG_FILE="$1"

if [ -z "$COMMIT_MSG_FILE" ]; then
  echo "Usage: $0 [--check] <commit-msg-file>" >&2
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

# --- Extract git trailers from body ---
# Trailers are key-value lines (e.g. "Signed-off-by: Name <email>") at the end of the message,
# separated from the body by a blank line. We preserve them verbatim.
trailers=""
if [ -n "$body" ]; then
  # Count total body lines
  _total=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
  # Walk backwards from the end to find contiguous trailer lines
  _trailer_start=0
  _i="$_total"
  while [ "$_i" -gt 0 ]; do
    _line=$(printf '%s\n' "$body" | sed -n "${_i}p")
    if printf '%s' "$_line" | grep -qE '^[A-Za-z][A-Za-z0-9_-]*:[[:space:]]'; then
      _trailer_start="$_i"
      _i=$((_i - 1))
    elif [ -z "$_line" ] && [ "$_trailer_start" -gt 0 ]; then
      # blank line immediately before trailer block — stop
      break
    else
      # non-trailer, non-blank line — no trailer block
      _trailer_start=0
      break
    fi
  done
  if [ "$_trailer_start" -gt 0 ]; then
    trailers=$(printf '%s\n' "$body" | sed -n "${_trailer_start},${_total}p")
    # Body is everything before the blank line preceding trailers
    _body_end=$((_trailer_start - 1))
    if [ "$_body_end" -gt 0 ]; then
      body=$(printf '%s\n' "$body" | sed -n "1,${_body_end}p")
      # Strip trailing blank lines from body
      while [ -n "$body" ]; do
        _last=$(printf '%s\n' "$body" | tail -n 1)
        if [ -z "$_last" ]; then
          body=$(printf '%s\n' "$body" | sed '$d')
        else
          break
        fi
      done
    else
      body=""
    fi
  fi
fi

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

# --- Build normalized message ---

normalized=$(printf '%s\n' "$new_subject")
if [ -n "$body" ]; then
  normalized=$(printf '%s\n%s\n' "$new_subject" "$body")
fi
if [ -n "$trailers" ]; then
  # Ensure blank line before trailers
  normalized=$(printf '%s\n\n%s\n' "$normalized" "$trailers")
fi

# --- Check mode: compare and exit ---

if [ "$CHECK_MODE" -eq 1 ]; then
  original=$(cat "$COMMIT_MSG_FILE")
  if [ "$original" = "$normalized" ]; then
    exit 0
  else
    echo "Commit message would be normalized:" >&2
    echo "$normalized" >&2
    exit 1
  fi
fi

# --- Write normalized message ---

printf '%s' "$normalized" > "$COMMIT_MSG_FILE"
