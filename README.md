# commit-normalize

A portable POSIX shell git `commit-msg` hook that normalizes commit messages to [Conventional Commits](https://www.conventionalcommits.org/) format.

## What it does

- Enforces a type prefix (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `revert`)
- Auto-detects type from keywords if missing, defaults to `chore`
- Lowercases the type prefix
- Ensures `type: Description` format (colon + space separator)
- Capitalizes the first letter of the description
- Warns if the subject line exceeds 72 characters
- Ensures a blank line between subject and body
- Preserves scoped types like `feat(api): ...`
- Skips merge commits

## Install

```sh
# Install into the current repo
./install.sh

# Install into a specific repo
./install.sh /path/to/repo
```

This symlinks `commit-normalize.sh` as `.git/hooks/commit-msg`. If a hook already exists, it is backed up to `commit-msg.bak`.

## Examples

| Input | Output |
|---|---|
| `fix a bug in parser` | `fix: Fix a bug in parser` |
| `FIX: resolved crash` | `fix: Resolved crash` |
| `add new login page` | `feat: Add new login page` |
| `updated README` | `docs: Updated README` |
| `some random change` | `chore: Some random change` |

## Testing

```sh
./test-normalize.sh
```

## License

MIT
