#!/usr/bin/env fish
# .wtm_hook.fish - Executed after 'wtm add' command in worktree directory
#
# This is a project-specific hook. For a global hook, create a file at:
# ~/.config/wtm/hook.fish
#
# Available environment variables:
# - $WTM_WORKTREE_PATH : Path to the new worktree (current directory)
# - $WTM_BRANCH_NAME   : Name of the branch
# - $WTM_BASE_BRANCH   : Base branch used for creation
# - $WTM_PROJECT_ROOT  : Path to the original project root
# - $WTM_TIMESTAMP     : Timestamp of worktree creation

# Show worktree creation information
function show_creation_info
    echo "[HOOK] Worktree hook executing..."
    echo "   Branch: $WTM_BRANCH_NAME (from $WTM_BASE_BRANCH)"
    echo "   Location: $WTM_WORKTREE_PATH"
end

# Copy files and directories from project root to worktree
function copy_project_files
    # Files and directories to copy from project root
    set -l copy_items \
        ".env" \
        ".env.local" \
        ".env.development" \
        ".claude" \
        node_modules \
        vendor \
        "QWEN.md" \
        "GEMINI.md" \
        "AGENTS.md" \
        "CLAUDE.md"

    # Copy items if they exist
    for item in $copy_items
        set -l source "$WTM_PROJECT_ROOT/$item"
        set -l target "$WTM_WORKTREE_PATH/$item"

        if test -e "$source"
            # Skip if target already exists
            if test -e "$target"
                echo "       [SKIP] $item (already exists)"
                continue
            end

            # Determine copy method based on type and name
            if test -d "$source"
                switch $item
                    case node_modules vendor ".git"
                        # Create symlink for large directories
                        ln -s "$source" "$target"
                        echo "       [LINK] $item"
                    case '*'
                        # Copy directory
                        cp -r "$source" "$target"
                        echo "       [COPY] $item/"
                end
            else
                # Copy file
                cp "$source" "$target"
                echo "       [COPY] $item"
            end
        end
    end
end

# Setup direnv if available
function setup_direnv
    if test -f .envrc
        and type -q direnv
        echo "[DIRENV] Allowing .envrc..."
        direnv allow
    end
end

# Set upstream for the new branch
function setup_git_upstream
    set -l other_remotes (git remote | string collect | string match -v 'origin')
    set -l remote_count (count $other_remotes)

    # Check if branch already has upstream set
    if git rev-parse --abbrev-ref @{u} 2>/dev/null > /dev/null
        echo "[GIT] Branch '$WTM_BRANCH_NAME' already has upstream set. Skipping git push."
        return 0
    end

    if test $remote_count -gt 1
        echo "[GIT] Multiple remotes found. Please choose one to set as upstream for '$WTM_BRANCH_NAME':"
        for i in (seq $remote_count)
            echo "  [$i] $other_remotes[$i]"
        end

        while true
            read -P "Enter number (or 's' to skip): " -l choice
            if string match -q -r '^[1-9][0-9]*$' -- $choice
                if test $choice -le $remote_count
                    set -l selected_remote $other_remotes[$choice]
                    echo "[GIT] Setting upstream to '$selected_remote'..."
                    git push --no-verify --set-upstream $selected_remote $WTM_BRANCH_NAME
                    return 0
                else
                    echo "Invalid number. Please try again."
                end
            else if test "$choice" = s
                echo "[GIT] Skipping upstream setup."
                return 0
            else
                echo "Invalid input. Please enter a number or 's'."
            end
        end
    else if test $remote_count -eq 1
        set -l remote_to_set $other_remotes[1]
        echo "[GIT] Setting upstream to '$remote_to_set'..."
        git push --no-verify --set-upstream $remote_to_set $WTM_BRANCH_NAME
    else
        echo "[GIT] No other remotes found to set as upstream."
    end
end

# Main execution
show_creation_info
copy_project_files
setup_direnv
setup_git_upstream

echo "[OK] Hook completed successfully"
