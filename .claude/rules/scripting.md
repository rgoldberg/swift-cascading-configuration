---
paths:
  - .github/workflows/**
  - Scripts/**
---

# Scripting

- Use zsh for scripts (except for shell-specific completion scripts), compatible
  with the zsh version ([currently 5.9](https://opensource.apple.com/releases/))
  bundled with the oldest macOS major version supported by
  `CascadingConfiguration` ([currently 15](../../Package.swift)) & all later
  ones
- Use a `#!/bin/zsh -f` shebang (changing options as necessary)
- Start each development script with `. "${0:A:h}/_setup-script"`, overriding
  its zsh settings as necessary
- Print each error of a development script itself (not each finding that it
  reports at a file location, e.g., a lint violation) via `print_error` & each
  heading of a section of its output via `print_section`, never directly
- Prefer concision to verbosity
- If performance is at least almost equivalent or better, prefer in descending
  order:
  - zsh expansions
  - zsh globs
  - zsh builtins
  - zsh loops
  - external commands
- Make variables local & readonly when possible
- Use `cp -c` instead of `cp`
- Use `trash` instead of `rm`
- In a GHA job that runs on any x86_64 runner, never use Homebrew (e.g., via
  `Scripts/bootstrap`), which no longer bottles updated formulae for x86_64, so
  upgrading builds them from source; install only the tools that the job needs,
  from their vendors' releases (e.g., Swiftly's `swiftly.pkg` from swift.org)

## Releases

- Never delete a valid public version tag (one with a trusted SSH signature that
  is on `main`, as `tag-pushed.yaml` checks); `release-cancel` retains local
  version tags, too
