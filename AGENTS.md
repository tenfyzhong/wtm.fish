# Repository Guidelines

This repository provides the `wtm` Fish shell command for managing Git worktrees. Use this guide when adding features or adjusting behavior.

## Project Structure & Module Organization
- `functions/wtm.fish` contains the main `wtm` entrypoint and all helper functions.
- `completions/wtm.fish` provides Fish shell completions.
- `hook/hook.fish` is the hook template used by `wtm init`.
- `README.md` documents usage; keep it updated when commands/options change.

## Build, Test, and Development Commands
- No build step; scripts run directly in Fish.
- `fish -n functions/wtm.fish` checks syntax for core logic.
- `fish -n completions/wtm.fish` checks completions syntax.
- `wtm --help` prints CLI usage (run inside a Git repo).
- `wtm list` is a quick smoke test to verify worktree discovery.

## Coding Style & Naming Conventions
- Fish scripts use 4-space indentation; YAML/JSON uses 2 spaces.
- No trailing whitespace on any line.
- Public commands are named `wtm`; internal helpers use `__wtm_*`.
- Prefer clear flag names in `argparse` (short + long forms).

## Testing Guidelines
- There is no automated test suite today.
- If adding tests, use the project’s test framework (no one-off scripts) and document how to run them in `README.md`.
- Use `fish -n` checks before opening a PR.

## Architecture Overview
- `wtm` dispatches subcommands to helper functions that wrap `git worktree` and fzf-based selection.
- Worktrees are stored under `.git/wtm_data/` in each repository.
- Hooks run from `.wtm_hook.fish` (project) or `~/.config/wtm/hook.fish` (global), with project hooks taking priority.

## Commit & Pull Request Guidelines
- Commit messages follow a Conventional Commit style, e.g. `feat(hook): ...`, `fix(wtm): ...`, `refactor(worktree): ...`.
- All commits must be signed off: `git commit -s`.
- PRs should describe behavior changes, include CLI output examples for UX changes, and update docs when commands or options change.
