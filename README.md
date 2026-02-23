# commit-normalize

A portable POSIX shell git `commit-msg` hook that normalizes commit messages to [Conventional Commits](https://www.conventionalcommits.org/) format.

## What it does

- Enforces a type prefix (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `revert`)
- Auto-detects type from keywords if missing, defaults to `chore`
- Lowercases the type prefix
- Ensures `type: Description` format (colon + space separator)
- Capitalizes the first letter of the description
- Strips trailing periods from the description
- Warns if the subject line exceeds 72 characters
- Ensures a blank line between subject and body
- Preserves scoped types like `feat(api): ...`
- Preserves breaking change indicators like `feat!: ...` and `fix(api)!: ...`
- Skips merge commits
- Preserves git trailers (`Signed-off-by`, `Co-Authored-By`, `Nightshift-Task`, etc.) verbatim
- Passes through `fixup!`, `squash!`, and `amend!` commits for interactive rebase
- Supports `--check` mode for CI linting (exits non-zero if message would change)

## Install

```sh
# Install into the current repo
./install.sh

# Install into a specific repo
./install.sh /path/to/repo

# Install globally (all repos)
./install.sh --global
```

This symlinks `commit-normalize.sh` as `.git/hooks/commit-msg`. If a hook already exists, it is backed up to `commit-msg.bak`.

Global install sets `git config --global core.hooksPath` to `~/.git-hooks/`, so the hook applies to every repository.

## Uninstall

```sh
# Uninstall from the current repo
./install.sh --uninstall

# Uninstall from a specific repo
./install.sh --uninstall /path/to/repo

# Uninstall globally
./install.sh --uninstall --global
```

Uninstall removes the hook symlink and restores any `.bak` backup. Global uninstall also clears `core.hooksPath`.

## Examples

| Input | Output |
|---|---|
| `fix a bug in parser` | `fix: Fix a bug in parser` |
| `FIX: resolved crash` | `fix: Resolved crash` |
| `add new login page` | `feat: Add new login page` |
| `updated README` | `docs: Updated README` |
| `some random change` | `chore: Some random change` |
| `feat: Add feature.` | `feat: Add feature` |
| `feat!: Drop Node 12` | `feat!: Drop Node 12` |
| `fixup! feat: Add feature` | `fixup! feat: Add feature` |

## Configuration

Create a `.commitnormalizerc` file in your repo root or at `$HOME/.commitnormalizerc` for global defaults. Repo-level config takes precedence over the global config.

```sh
# .commitnormalizerc
types = feat fix docs style refactor test chore build ci perf revert
max_subject_length = 72
capitalize_first = on
strip_trailing_period = on
```

| Option | Default | Description |
|---|---|---|
| `types` | `feat fix docs style refactor test chore build ci perf revert` | Space-separated list of valid commit types |
| `max_subject_length` | `72` | Maximum subject length before a warning is shown |
| `capitalize_first` | `on` | Capitalize the first letter of the description (`on`/`off`) |
| `strip_trailing_period` | `on` | Remove trailing periods from the description (`on`/`off`) |

See [`.commitnormalizerc.example`](.commitnormalizerc.example) for a commented sample.

## CI / Linting

Use `--check` to verify a commit message is already normalized without modifying it:

```sh
# Exits 0 if already normalized, 1 if it would change
./commit-normalize.sh --check .git/COMMIT_EDITMSG
```

## Testing

```sh
./test-normalize.sh
```

## License

MIT
