# wtm.fish - Git Worktree Manager for Fish Shell

A powerful Git worktree manager for Fish shell that makes working with multiple branches effortless.

![Fish Shell](https://img.shields.io/badge/fish-v4.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

- 🎯 **Interactive Selection** - Browse and switch between worktrees with fzf
- 🌳 **Smart Worktree Management** - Create, remove, and list worktrees with ease
- 🔄 **File Syncing** - Optionally sync staged/modified/untracked files when creating new worktrees
- 🧹 **Auto Cleanup** - Remove stale worktrees based on age
- 🪝 **Custom Hooks** - Run custom scripts after worktree creation
- 📝 **Rich Previews** - See worktree status, changes, and recent commits in fzf preview
- 🎨 **Beautiful UI** - Colorful and informative terminal interface

## Requirements

- Fish shell v4.0+
- Git v2.5+ (with worktree support)
- [fzf](https://github.com/junegunn/fzf) (for interactive selection)

## Installation

### Using Fisher

```fish
fisher install ktym4a/wtm.fish
```

### Manual Installation

```fish
# Clone the repository
git clone https://github.com/ktym4a/wtm.fish.git ~/.config/fish/wtm.fish

# Source the functions
ln -s ~/.config/fish/wtm.fish/functions/wtm.fish ~/.config/fish/functions/
ln -s ~/.config/fish/wtm.fish/completions/wtm.fish ~/.config/fish/completions/
```

## Usage

### Interactive Mode

Simply run `wtm` without arguments to interactively select and switch between worktrees:

```fish
wtm
```

This opens an fzf interface showing:
- All available worktrees
- Current branch status
- Changed files
- Recent commits

### Create a New Worktree

```fish
# Create from main branch (default)
wtm add feature/new-feature

# Create from specific base branch
wtm add hotfix/urgent-fix --base develop

# Create and sync current changes
wtm add feature/continue-work --sync
```

### Remove a Worktree

```fish
# Interactive selection
wtm remove

# Remove specific branch
wtm remove feature/old-feature
```

### List All Worktrees

```fish
wtm list
```

### Clean Stale Worktrees

```fish
# Remove worktrees older than 30 days (default)
wtm clean

# Remove worktrees older than 7 days
wtm clean --days 7

# Preview what would be removed
wtm clean --dry-run
```

### Switch to Main Branch

```fish
wtm main
```

### Initialize Hook Template

Create a `.wtm_hook.fish` file that runs after each worktree creation:

```fish
wtm init
```

## Command Reference

| Command | Description |
|---------|-------------|
| `wtm` | Interactive worktree selection with fzf |
| `wtm add <branch>` | Create new branch and worktree |
| `wtm remove [<branch>]` | Remove worktree and branch |
| `wtm list` | List all worktrees |
| `wtm clean` | Clean up stale worktrees |
| `wtm init` | Create hook template |
| `wtm main` | Switch to main/master branch |

### Global Options

- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose output
- `-q, --quiet` - Suppress informational output

### Add Options

- `-b, --base <branch>` - Base branch (default: main)
- `--sync` - Sync staged/modified/untracked files from current branch
- `--no-hook` - Skip hook execution

### Clean Options

- `-n, --dry-run` - Show what would be removed
- `--days <n>` - Remove worktrees older than n days (default: 30)

## Hook System

The hook system allows you to run custom commands after creating a new worktree. This is useful for:
- Copying environment files
- Installing dependencies
- Setting up symlinks
- Running initialization scripts

### Example Hook File

After running `wtm init`, customize `.wtm_hook.fish`:

```fish
#!/usr/bin/env fish

# Copy environment files
for env_file in .env .env.local
    if test -f "$WTM_PROJECT_ROOT/$env_file"
        cp "$WTM_PROJECT_ROOT/$env_file" "$WTM_WORKTREE_PATH/"
        echo "[COPY] $env_file"
    end
end

# Create symlink for node_modules
if test -d "$WTM_PROJECT_ROOT/node_modules"
    ln -s "$WTM_PROJECT_ROOT/node_modules" "$WTM_WORKTREE_PATH/node_modules"
    echo "[LINK] node_modules"
end
```

### Available Hook Variables

- `$WTM_WORKTREE_PATH` - Path to the new worktree
- `$WTM_BRANCH_NAME` - Name of the created branch
- `$WTM_BASE_BRANCH` - Base branch used for creation
- `$WTM_PROJECT_ROOT` - Path to the original project root
- `$WTM_TIMESTAMP` - Timestamp of worktree creation

## Workflow Examples

### Feature Development

```fish
# Start new feature
wtm add feature/user-authentication

# Work on the feature...

# Switch to another task
wtm add hotfix/login-bug

# Go back to feature
wtm  # Select interactively

# Clean up when done
wtm remove feature/user-authentication
```

### Parallel Development

```fish
# Create multiple feature branches
wtm add feature/ui-redesign
wtm add feature/api-v2
wtm add feature/documentation

# Switch between them instantly
wtm  # Use fzf to select

# See all active work
wtm list

# Clean up old branches
wtm clean --days 14
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

ktym4a

## Acknowledgments

- Inspired by various worktree management tools
- Built with ❤️ for the Fish shell community