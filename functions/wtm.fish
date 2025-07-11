function wtm --description "Git worktree manager with advanced features"
    # Define help function
    function __wtm_help
        echo "╭─────────────────────────────────────────────────────────────────────╮"
        echo "│ Git Worktree Manager - Manage Git worktrees efficiently             │"
        echo "╰─────────────────────────────────────────────────────────────────────╯"
        echo ""
        echo "USAGE:"
        echo "  wtm [options]                    - Interactive worktree selection with fzf"
        echo "  wtm open <branch>                - Open existing worktree"
        echo "  wtm add <branch> [options]       - Create new branch and worktree"
        echo "  wtm remove <branch> [options]    - Remove worktree and branch"
        echo "  wtm list [options]               - List all worktrees"
        echo "  wtm clean [options]              - Clean up stale worktrees"
        echo "  wtm init                         - Create .wtm_hook.fish template"
        echo "  wtm main                         - Switch to default branch (main/master)"
        echo ""
        echo "GLOBAL OPTIONS:"
        echo "  -h, --help                      - Show this help message"
        echo "  -v, --verbose                   - Enable verbose output"
        echo "  -q, --quiet                     - Suppress informational output"
        echo ""
        echo "ADD OPTIONS:"
        echo "  -b, --base <branch>             - Base branch (default: main)"
        echo "  --sync                          - Sync staged/modified/untracked files"
        echo "  --no-hook                       - Skip hook execution"
        echo ""
        echo "CLEAN OPTIONS:"
        echo "  -n, --dry-run                   - Show what would be removed"
        echo "  --days <n>                      - Remove worktrees older than n days"
        echo ""
        echo "EXAMPLES:"
        echo "  wtm                              - Select worktree interactively"
        echo "  wtm add feature/new-ui          - Create new feature branch"
        echo "  wtm clean --days 30             - Remove worktrees older than 30 days"
        echo "  wtm main                         - Switch to main branch"
    end

    # Handle help flag
    function __wtm_open_help
        echo "╭──────────────────────────────────────────────────────────╮"
        echo "│ wtm open - Open existing worktree                        │"
        echo "╰──────────────────────────────────────────────────────────╯"
        echo ""
        echo "USAGE:"
        echo "  wtm open [<branch>] [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help            Show this help message"
        echo ""
        echo "DESCRIPTION:"
        echo "  Open an existing worktree by branch name."
        echo "  If no branch is specified, interactive selection with fzf is used."
        echo ""
        echo "EXAMPLES:"
        echo "  wtm open                      - Interactive selection"
        echo "  wtm open feature/my-feature   - Open specific branch"
    end

    # Define subcommand help functions
    function __wtm_add_help
        echo "╭──────────────────────────────────────────────────────────╮"
        echo "│ wtm add - Create new branch and worktree                 │"
        echo "╰──────────────────────────────────────────────────────────╯"
        echo ""
        echo "USAGE:"
        echo "  wtm add <branch> [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -b, --base <branch>   Base branch (default: main)"
        echo "  --sync                Sync staged/modified/untracked files from current branch"
        echo "  --no-hook             Skip hook execution (.wtm_hook.fish or global hook)"
        echo "  -h, --help            Show this help message"
        echo ""
        echo "EXAMPLES:"
        echo "  wtm add feature/new-ui                    - Create from main branch"
        echo "  wtm add hotfix/bug-123 -b develop        - Create from develop branch"
        echo "  wtm add feature/continue --sync          - Create with current changes"
    end

    function __wtm_remove_help
        echo "╭──────────────────────────────────────────────────────────╮"
        echo "│ wtm remove - Remove worktree and branch                  │"
        echo "╰──────────────────────────────────────────────────────────╯"
        echo ""
        echo "USAGE:"
        echo "  wtm remove [<branch>] [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help            Show this help message"
        echo ""
        echo "DESCRIPTION:"
        echo "  Remove a worktree and its associated branch."
        echo "  If no branch is specified, interactive selection with fzf is used."
        echo "  Protected branches (main/master) and current branch cannot be removed."
        echo ""
        echo "EXAMPLES:"
        echo "  wtm remove                      - Interactive selection"
        echo "  wtm remove feature/old-ui       - Remove specific branch"
    end

    function __wtm_list_help
        echo "╭──────────────────────────────────────────────────────────╮"
        echo "│ wtm list - List all worktrees                            │"
        echo "╰──────────────────────────────────────────────────────────╯"
        echo ""
        echo "USAGE:"
        echo "  wtm list [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help            Show this help message"
        echo ""
        echo "DESCRIPTION:"
        echo "  Display all worktrees with their status and last commit."
    end

    function __wtm_clean_help
        echo "╭──────────────────────────────────────────────────────────╮"
        echo "│ wtm clean - Clean up stale worktrees                     │"
        echo "╰──────────────────────────────────────────────────────────╯"
        echo ""
        echo "USAGE:"
        echo "  wtm clean [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -n, --dry-run         Show what would be removed"
        echo "  --days <n>            Remove worktrees older than n days (default: 30)"
        echo "  -h, --help            Show this help message"
        echo ""
        echo "DESCRIPTION:"
        echo "  Remove worktrees that haven't been modified for the specified number of days."
        echo "  Protected branches (main/master) and current branch are never removed."
        echo ""
        echo "EXAMPLES:"
        echo "  wtm clean                       - Remove worktrees older than 30 days"
        echo "  wtm clean --days 7              - Remove worktrees older than 7 days"
        echo "  wtm clean --dry-run             - Preview what would be removed"
    end

    # Parse global options - stop at first non-option argument
    argparse -s 'h/help' 'v/verbose' 'q/quiet' -- $argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_help
        return 0
    end

    # Set verbosity
    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

    # Get subcommand
    set -l cmd $argv[1]
    set -e argv[1]

    # Main command logic
    switch "$cmd"
        case "" # Interactive selection
            __wtm_interactive -- $verbose $quiet

        case open
            __wtm_open -- $argv $verbose $quiet

        case add
            __wtm_add -- $argv $verbose $quiet

        case remove rm
            __wtm_remove -- $argv $verbose $quiet

        case list ls
            __wtm_list -- $argv $verbose $quiet

        case clean
            __wtm_clean -- $argv $verbose $quiet

        case init
            __wtm_init -- $verbose $quiet

        case main default
            __wtm_main -- $verbose $quiet

        case help
            __wtm_help
            return 0

        case __preview
            # Internal preview command for fzf
            __wtm_preview_worktree $argv
            return 0

        case '*'
            echo "Error: Unknown command '$cmd'" >&2
            echo "Run 'wtm --help' for usage information." >&2
            return 1
    end
end

# Interactive worktree selection with fzf
function __wtm_interactive
    # Parse arguments after --
    set -l verbose $argv[2]
    set -l quiet $argv[3]
    # Check if fzf is available
    if not command -sq fzf
        echo "Error: fzf is not installed. Please install fzf to use interactive mode." >&2
        return 1
    end

    # Get worktree list
    set -l worktrees (git worktree list 2>/dev/null)
    if test -z "$worktrees"
        echo "Error: No Git repository found or no worktrees exist." >&2
        return 1
    end

    # Extract branch names for fzf display
    set -l branch_names
    for worktree in $worktrees
        set -a branch_names (echo $worktree | string match -r '\[([^\]]+)\]' | string split -f2 '[' | string trim -c ']')
    end

    # Create a mapping of branch names to worktree info for preview
    set -l branch_worktree_map
    for i in (seq (count $branch_names))
        set branch_worktree_map[$i] $worktrees[$i]
    end

    # Select branch with fzf
    set -l selected_branch (printf '%s\n' $branch_names | fzf \
        --preview-window="right:70%:wrap" \
        --preview='
            set -l branch {}
            set -l line (git worktree list | grep "\[$branch\]")
            set -l worktree_path (echo $line | string split -f1 " ")
            set -l resolved_path (path resolve $worktree_path)

            # Get current directory for comparison
            set -l current_dir (pwd)
            set -l is_current (test "$current_dir" = "$resolved_path"; and echo "*" ; or echo " ")

            echo "╭───────────────────────────────────────────────────────────────────╮"
            echo "│  Worktree Information                                             │"
            echo "├───────────────────────────────────────────────────────────────────┤"
            echo "│   Branch:  $branch $is_current"
            echo "│   Path:    $resolved_path"
            echo "╰───────────────────────────────────────────────────────────────────╯"
            echo ""

            # Get stats
            set -l total_changes (git -C "$resolved_path" status --porcelain 2>/dev/null | wc -l | string trim)
            set -l staged_count (git -C "$resolved_path" diff --cached --numstat 2>/dev/null | wc -l | string trim)
            set -l modified_count (git -C "$resolved_path" diff --numstat 2>/dev/null | wc -l | string trim)
            set -l untracked_count (git -C "$resolved_path" ls-files --others --exclude-standard 2>/dev/null | wc -l | string trim)

            echo ""
            echo "╭─  Repository Status ──────────────────────────────────────────────╮"
            printf "│  Staged: %-3s  Modified: %-3s  Untracked: %-3s  Total: %-3s │\n" $staged_count $modified_count $untracked_count $total_changes
            echo "╰───────────────────────────────────────────────────────────────────╯"

            echo ""
            echo "╭─  Changed Files ──────────────────────────────────────────────────╮"
            set -l changes (git -C "$resolved_path" status --porcelain 2>/dev/null)
            if test -z "$changes"
                echo "│   Working tree is clean                                           │"
                echo "╰───────────────────────────────────────────────────────────────────╯"
            else
                set -l count 0
                for change in $changes
                    set count (math $count + 1)
                    if test $count -gt 10
                        echo "│   ... and "(math (count $changes) - 10)" more files"
                        break
                    end

                    set -l file_status (string sub -l 2 -- $change)
                    set -l file (string sub -s 4 -- $change)

                    switch $file_status
                        case "M " " M" "MM"
                            echo "│   M  $file"
                        case "A " "AM"
                            echo "│   A  $file"
                        case "D " " D"
                            echo "│   D  $file"
                        case "R "
                            echo "│   R  $file"
                        case "??"
                            echo "│   ?  $file"
                        case "*"
                            echo "│  [$file_status] $file"
                    end
                end
                echo "╰───────────────────────────────────────────────────────────────────╯"
            end

            echo ""
            echo "╭─  Recent Commits ─────────────────────────────────────────────────╮"
            set -l commits (git -C "$resolved_path" log --oneline --color=always -8 2>/dev/null)
            if test -n "$commits"
                for commit in $commits
                    echo "│ $commit"
                end
            else
                echo "│ No commits yet"
            end
            echo "╰───────────────────────────────────────────────────────────────────╯"
        ' \
        --header="╭────────────────────────────────────────────────────────────────────╮
│  Git Worktree Manager    ↑/↓ Navigate  ⏎ Select  ^C Cancel     │
╰────────────────────────────────────────────────────────────────────╯" \
        --border=rounded \
        --height=80% \
        --layout=reverse \
        --prompt="› " \
        --ansi)

    __wtm_open_branch "$selected_branch"
end

function __wtm_open_branch -a branch
    if test -n "$branch"
        # Find the worktree path for the selected branch
        set -l worktree_info (git worktree list | grep "\[$branch\]")
        set -l worktree_path (echo $worktree_info | string split -f1 ' ')
        set -l resolved_path (path resolve $worktree_path)

        if test -d "$resolved_path"
            cd "$resolved_path"
            test "$verbose" = true; and echo "Switched to worktree: $resolved_path"
            return 0
        else
            echo "Error: Directory not found: $worktree_path" >&2
            return 1
        end
    end
end

# Open existing worktree
function __wtm_open
    # The first argument is always "--", followed by actual arguments, then verbose and quiet
    set -l actual_argv $argv[2..-3]  # Skip first "--" and last two (verbose, quiet)
    set -l verbose $argv[-2]
    set -l quiet $argv[-1]

    # Parse open-specific options
    argparse 'h/help' -- $actual_argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_open_help
        return 0
    end

    set -l branch_name $argv[1]

    # If no branch name provided, use fzf for interactive selection
    if test -z "$branch_name"
        __wtm_interactive
    else
        __wtm_open_branch "$branch_name"
    end
end

# Preview function for fzf
function __wtm_preview_worktree
    set -l line $argv[1]
    set -l worktree_path (echo $line | string split -f1 ' ')
    set -l branch (echo $line | string match -r '\[([^\]]+)\]' | string split -f2 '[' | string trim -c ']')

    # Resolve path
    set -l resolved_path (path resolve $worktree_path)

    echo "┌─ 🌳 Worktree Information ─────────────────────────┐"
    echo "│ Branch: $branch"
    echo "│ Path: $resolved_path"
    echo "└───────────────────────────────────────────────────┘"
    echo ""

    # Changed files
    echo "  Changed Files:"
    echo (string repeat -n 50 '─')

    set -l changes (git -C "$resolved_path" status --porcelain 2>/dev/null)
    if test -z "$changes"
        echo "  Working tree clean"
    else
        set -l count 0
        for change in $changes
            set count (math $count + 1)
            if test $count -gt 10
                echo "  ... and "(math (count $changes) - 10)" more files"
                break
            end

            set -l status (string sub -l 2 -- $change)
            set -l file (string sub -s 4 -- $change)

            switch $status
                case "M " " M" "MM"
                    echo "   Modified: $file"
                case "A " "AM"
                    echo "  ➕ Added: $file"
                case "D " " D"
                    echo "  ➖ Deleted: $file"
                case "R "
                    echo "  ➡️  Renamed: $file"
                case "??"
                    echo "  ❓ Untracked: $file"
                case '*'
                    echo "   $status $file"
            end
        end
    end

    echo ""
    echo "📜 Recent Commits:"
    echo (string repeat -n 50 '─')
    git -C "$resolved_path" log --oneline --color=always -10 2>/dev/null | string replace -r '^' '  '
end

# Add new worktree
function __wtm_add
    # The first argument is always "--", followed by actual arguments, then verbose and quiet
    set -l actual_argv $argv[2..-3]  # Skip first "--" and last two (verbose, quiet)
    set -l verbose $argv[-2]
    set -l quiet $argv[-1]

    # Parse add-specific options
    argparse 'b/base=' 'no-hook' 'sync' 'h/help' -- $actual_argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_add_help
        return 0
    end

    # Get branch name from remaining arguments after argparse
    set -l branch_name $argv[1]

    if test -z "$branch_name"
        echo "Error: Branch name required" >&2
        echo "Usage: wtm add <branch_name> [options]" >&2
        return 1
    end

    # Store current directory and current branch before changing directory
    set -l original_dir $PWD
    set -l current_branch (git branch --show-current 2>/dev/null)

    # Always change to repository root for consistency
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$repo_root"
        echo "Error: Not in a Git repository" >&2
        return 1
    end

    # Get the main git directory (handles both regular repos and worktrees)
    set -l git_common_dir (git rev-parse --git-common-dir 2>/dev/null)
    if test -z "$git_common_dir"
        echo "Error: Not in a Git repository" >&2
        return 1
    end

    # Resolve Git directory path
    set -l git_dir_resolved (path resolve $git_common_dir)

    cd "$repo_root"
    test "$verbose" = true; and echo "Changed to repository root: $repo_root"

    # Determine worktree directory
    # Create wtm_data directory in .git
    set -l wtm_data_dir "$git_dir_resolved/wtm_data"
    if not test -d "$wtm_data_dir"
        mkdir -p "$wtm_data_dir"
        test "$verbose" = true; and echo "Created directory: $wtm_data_dir"
    end

    # Use branch name for directory, replacing slashes
    set -l dir_name (string replace -r '/' '_' -- "$branch_name")
    set -l worktree_path "$wtm_data_dir/$dir_name"

    # Get base branch (default to main)
    set -l base_branch
    if set -ql _flag_base
        set base_branch $_flag_base
    else if set -ql _flag_sync
        # If --sync flag is provided, use current branch as base
        set base_branch $current_branch
        test "$verbose" = true; and echo "Using current branch '$base_branch' as base (--sync flag provided)"
    else
        # Default to main branch
        set base_branch "main"
        # Check if main exists, otherwise try master
        if not git rev-parse --verify main &>/dev/null
            if git rev-parse --verify master &>/dev/null
                set base_branch "master"
            else
                # Fallback to current branch if neither main nor master exists
                set base_branch $current_branch
            end
        end
    end

    # Check for unstaged changes before creating worktree
    # Note: By default, we don't sync changes when base is main/master
    set -l should_sync_changes false
    set -l has_unstaged_changes (git status --porcelain 2>/dev/null)

    # Only sync changes if --sync flag is explicitly provided
    if set -ql _flag_sync
        set should_sync_changes true
        test "$verbose" = true; and echo "[INFO] Syncing changes (--sync flag provided)"
    else if test -n "$has_unstaged_changes"
        test "$verbose" = true; and echo "[INFO] Skipping unstaged changes sync (base: $base_branch, use --sync to include changes)"
    end

    # Create worktree
    test "$quiet" = false; and echo "Creating worktree for branch '$branch_name'..."

    if git worktree add -b "$branch_name" "$worktree_path" "$base_branch" &>/tmp/wtm_add.log
        test "$quiet" = false; and echo "[OK] Created worktree at: $worktree_path"
        test "$quiet" = false; and echo "     Branch: $branch_name (based on $base_branch)"

        # Store project root
        set -l project_root (git rev-parse --show-toplevel)

        # Sync all changes (staged, unstaged, and untracked) only if should_sync_changes is true
        if test "$should_sync_changes" = true
            test "$quiet" = false; and echo "[SYNC] Syncing all changes..."

            # Get list of files
            set -l staged_files (git diff --cached --name-only)
            set -l modified_files (git diff --name-only)
            set -l untracked_files (git ls-files --others --exclude-standard)

            # Copy staged files
            for file in $staged_files
                if test -f "$repo_root/$file"
                    set -l dir_path (dirname "$worktree_path/$file")
                    mkdir -p "$dir_path"
                    cp "$repo_root/$file" "$worktree_path/$file"
                    test "$verbose" = true; and echo "       Copied staged: $file"
                end
            end

            # Copy modified files (unstaged changes)
            for file in $modified_files
                if test -f "$repo_root/$file"
                    set -l dir_path (dirname "$worktree_path/$file")
                    mkdir -p "$dir_path"
                    cp "$repo_root/$file" "$worktree_path/$file"
                    test "$verbose" = true; and echo "       Copied modified: $file"
                end
            end

            # Copy untracked files
            for file in $untracked_files
                if test -f "$repo_root/$file"
                    set -l dir_path (dirname "$worktree_path/$file")
                    mkdir -p "$dir_path"
                    cp "$repo_root/$file" "$worktree_path/$file"
                    test "$verbose" = true; and echo "       Copied untracked: $file"
                end
            end

            test "$quiet" = false; and echo "[OK] Synced all changes"
        end

        # Change to new worktree
        cd "$worktree_path"

        # Execute hook if exists and not disabled
        set -l hook_file
        if test -f "$project_root/.wtm_hook.fish"
            set hook_file "$project_root/.wtm_hook.fish"
        else if test -f "$HOME/.config/wtm/hook.fish"
            set hook_file "$HOME/.config/wtm/hook.fish"
        end

        if not set -ql _flag_no_hook; and test -n "$hook_file"
            test "$quiet" = false; and echo "[HOOK] Executing hook file: $hook_file..."

            # Set environment variables for hook
            set -gx WTM_WORKTREE_PATH "$worktree_path"
            set -gx WTM_BRANCH_NAME "$branch_name"
            set -gx WTM_BASE_BRANCH "$base_branch"
            set -gx WTM_PROJECT_ROOT "$project_root"
            set -gx WTM_TIMESTAMP (date +"%Y-%m-%d %H:%M:%S")

            fish "$hook_file"
            set -l hook_status $status

            # Clean up environment variables
            set -e WTM_WORKTREE_PATH
            set -e WTM_BRANCH_NAME
            set -e WTM_BASE_BRANCH
            set -e WTM_PROJECT_ROOT
            set -e WTM_TIMESTAMP

            if test $hook_status -ne 0
                echo "[WARN] Hook execution failed with status $hook_status" >&2
            else
                test "$quiet" = false; and echo "[OK] Hook executed successfully"
            end
        end

        test "$quiet" = false; and echo "[PWD] Now in: $worktree_path"
    else
        echo "Error: Failed to create worktree" >&2
        test "$verbose" = true; and cat /tmp/wtm_add.log >&2
        rm -f /tmp/wtm_add.log
        return 1
    end

    rm -f /tmp/wtm_add.log
end

# Remove worktree
function __wtm_remove
    # The first argument is always "--", followed by actual arguments, then verbose and quiet
    set -l actual_argv $argv[2..-3]  # Skip first "--" and last two (verbose, quiet)
    set -l verbose $argv[-2]
    set -l quiet $argv[-1]

    # Parse remove-specific options
    argparse 'h/help' -- $actual_argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_remove_help
        return 0
    end

    set -l branch_name $argv[1]

    # Get current branch
    set -l current_branch (git branch --show-current 2>/dev/null)

    # If no branch name provided, use fzf for interactive selection
    if test -z "$branch_name"
        # Check if fzf is available
        if not command -sq fzf
            echo "Error: Branch name required or install fzf for interactive selection" >&2
            echo "Usage: wtm remove <branch_name>" >&2
            return 1
        end

        # Get worktree list excluding main/master and current branch
        set -l worktrees (git worktree list 2>/dev/null | grep -v '\[\(main\|master\)\]')
        if test -n "$current_branch"
            set worktrees (printf '%s\n' $worktrees | grep -v "\[$current_branch\]")
        end

        if test -z "$worktrees"
            echo "No removable worktrees found (main/master and current branches are protected)" >&2
            return 1
        end

        # Extract branch names for fzf display
        set -l branch_names
        for worktree in $worktrees
            set -a branch_names (echo $worktree | string match -r '\[([^\]]+)\]' | string split -f2 '[' | string trim -c ']')
        end

        # Select branch with fzf
        set -l selected_branch (printf '%s\n' $branch_names | fzf \
            --preview-window="right:70%:wrap" \
            --preview='
                set -l branch {}
                set -l line (git worktree list | grep "\[$branch\]")
                set -l worktree_path (echo $line | string split -f1 " ")
                set -l resolved_path (path resolve $worktree_path)

                echo "┌─ 🌳 Worktree Information ─────────────────────────┐"
                echo "│ Branch: $branch"
                echo "│ Path: $resolved_path"
                echo "└───────────────────────────────────────────────────┘"
                echo ""

                echo "  Changed Files:"
                echo (string repeat -n 50 "─")

                set -l changes (git -C "$resolved_path" status --porcelain 2>/dev/null)
                if test -z "$changes"
                    echo "  Working tree clean"
                else
                    set -l count 0
                    for change in $changes
                        set count (math $count + 1)
                        if test $count -gt 10
                            echo "  └─ ... and "(math (count $changes) - 10)" more files"
                            break
                        end

                        set -l status (string sub -l 2 -- $change)
                        set -l file (string sub -s 4 -- $change)

                        switch $status
                            case "M " " M" "MM"
                                echo "   Modified: $file"
                            case "A " "AM"
                                echo "   Added: $file"
                            case "D " " D"
                                echo "   Deleted: $file"
                            case "R "
                                echo "   Renamed: $file"
                            case "??"
                                echo "   Untracked: $file"
                            case "*"
                                echo "   $status $file"
                        end
                    end
                end

                echo ""
                echo "  Recent Commits:"
                echo (string repeat -n 50 "─")
                git -C "$resolved_path" log --oneline --color=always -10 2>/dev/null | string replace -r "^" "  "
            ' \
            --header="╭────────────────────────────────────────────────────────────────────╮
│  Remove Worktree    ↑/↓ Navigate  ⏎ Remove  ^C Cancel          │
╰────────────────────────────────────────────────────────────────────╯" \
            --border=rounded \
            --height=80% \
            --layout=reverse \
            --prompt="› " \
            --ansi)

        if test -z "$selected_branch"
            echo "Cancelled"
            return 0
        end

        set branch_name $selected_branch
    end

    # Check if trying to remove current branch
    if test "$branch_name" = "$current_branch"
        echo "Error: Cannot remove the current branch '$branch_name'" >&2
        echo "Please switch to a different branch first." >&2
        return 1
    end

    # Check if trying to remove main/master branches
    if string match -qr '^(main|master)$' "$branch_name"
        echo "Error: Cannot remove protected branch '$branch_name'" >&2
        return 1
    end

    # Find worktree by branch
    set -l worktree_info (git worktree list | grep "\[$branch_name\]")

    if test -z "$worktree_info"
        echo "Error: No worktree found for branch '$branch_name'" >&2
        return 1
    end

    set -l worktree_path (echo $worktree_info | string split -f1 ' ')
    set -l resolved_path (path resolve $worktree_path)

    # Confirmation with default to yes
    echo "Remove worktree at: $resolved_path"
    echo "This will also delete branch: $branch_name"

    read -l -P "Are you sure? (Y/n) " confirm
    if string match -qi 'n' $confirm
        echo "Cancelled"
        return 0
    end

    # Remove worktree
    test "$quiet" = false; and echo "Removing worktree..."
    if git worktree remove --force "$worktree_path" &>/tmp/wtm_remove.log
        test "$quiet" = false; and echo "[OK] Removed worktree: $resolved_path"

        # Delete branch
        if git branch -D "$branch_name" &>>/tmp/wtm_remove.log
            test "$quiet" = false; and echo "[OK] Deleted branch: $branch_name"
        else
            echo "[WARN] Failed to delete branch: $branch_name" >&2
            test "$verbose" = true; and cat /tmp/wtm_remove.log >&2
        end
    else
        echo "Error: Failed to remove worktree" >&2
        test "$verbose" = true; and cat /tmp/wtm_remove.log >&2
        rm -f /tmp/wtm_remove.log
        return 1
    end

    rm -f /tmp/wtm_remove.log
end

# List worktrees
function __wtm_list
    # The first argument is always "--", followed by actual arguments, then verbose and quiet
    set -l actual_argv $argv[2..-3]  # Skip first "--" and last two (verbose, quiet)
    set -l verbose $argv[-2]
    set -l quiet $argv[-1]

    # Parse list-specific options
    argparse 'h/help' -- $actual_argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_list_help
        return 0
    end

    # Get worktree list
    set -l worktrees (git worktree list 2>/dev/null)
    if test -z "$worktrees"
        echo "No worktrees found" >&2
        return 1
    end

    # Always show detailed format
    for worktree in $worktrees
        set -l path (echo $worktree | string split -f1 ' ')
        set -l branch (echo $worktree | string match -r '\[([^\]]+)\]' | string split -f2 '[' | string trim -c ']')
        set -l resolved (path resolve $path)

        # Get status
        set -l changes (git -C "$path" status --porcelain 2>/dev/null | count)
        set -l status_text (test $changes -eq 0; and echo "clean"; or echo "$changes changes")

        # Get last commit
        set -l last_commit (git -C "$path" log -1 --format="%h %s" 2>/dev/null)

        echo "Branch: $branch"
        echo "  Path: $resolved"
        echo "  Status: $status_text"
        echo "  Last commit: $last_commit"
        echo ""
    end
end

# Clean up stale worktrees
function __wtm_clean
    # The first argument is always "--", followed by actual arguments, then verbose and quiet
    set -l actual_argv $argv[2..-3]  # Skip first "--" and last two (verbose, quiet)
    set -l verbose $argv[-2]
    set -l quiet $argv[-1]

    # Parse clean-specific options
    argparse 'n/dry-run' 'days=' 'h/help' -- $actual_argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_clean_help
        return 0
    end

    set -l dry_run (set -ql _flag_dry_run; and echo true; or echo false)
    set -l days (set -ql _flag_days; and echo $_flag_days; or echo 30)

    # Validate days
    if not string match -qr '^\d+$' $days
        echo "Error: --days must be a positive number" >&2
        return 1
    end

    test "$quiet" = false; and echo "[CLEAN] Cleaning worktrees older than $days days..."
    test "$dry_run" = true; and echo "[DRY RUN] No changes will be made"
    echo ""

    set -l worktrees (git worktree list 2>/dev/null)
    if test -z "$worktrees"
        echo "No worktrees found" >&2
        return 1
    end

    set -l removed_count 0
    set -l cutoff_date (date -d "$days days ago" +%s 2>/dev/null; or date -v -"$days"d +%s)

    # Get current branch
    set -l current_branch (git branch --show-current 2>/dev/null)

    for worktree in $worktrees
        set -l path (echo $worktree | string split -f1 ' ')
        set -l branch (echo $worktree | string match -r '\[([^\]]+)\]' | string split -f2 '[' | string trim -c ']')

        # Skip main/master branches
        if string match -qr '^(main|master)$' $branch
            test "$verbose" = true; and echo "[SKIP] Protected branch: $branch"
            continue
        end

        # Skip current branch
        if test "$branch" = "$current_branch"
            test "$verbose" = true; and echo "[SKIP] Current branch: $branch"
            continue
        end

        # Check for uncommitted changes
        set -l changes (git -C "$path" status --porcelain 2>/dev/null)
        if test -n "$changes"
            test "$verbose" = true; and echo "[SKIP] Branch has uncommitted changes: $branch"
            continue
        end

        # Check last modification time
        if test -d "$path"
            # Get last commit date
            set -l last_commit_date (git -C "$path" log -1 --format=%ct 2>/dev/null)
            if test -z "$last_commit_date"
                # If no commits, check directory modification time
                set -l dir_mtime (stat -f %m "$path" 2>/dev/null; or stat -c %Y "$path" 2>/dev/null)
                set last_commit_date $dir_mtime
            end

            if test -n "$last_commit_date" -a "$last_commit_date" -lt "$cutoff_date"
                set -l age_days (math "($cutoff_date - $last_commit_date) / 86400")
                echo "[REMOVE] Branch: $branch (inactive for $age_days days)"
                echo "   Path: $path"

                if test "$dry_run" = false
                    # Remove worktree
                    if git worktree remove --force "$path" &>/dev/null
                        # Remove branch
                        git branch -D "$branch" &>/dev/null
                        echo "         [OK] Removed"
                        set removed_count (math $removed_count + 1)
                    else
                        echo "         [FAIL] Failed to remove" >&2
                    end
                else
                    echo "         [DRY] Would be removed"
                    set removed_count (math $removed_count + 1)
                end
                echo ""
            end
        else
            # Worktree directory doesn't exist
            echo "[WARN] Missing directory for branch: $branch"
            echo "   Path: $path"

            if test "$dry_run" = false
                if git worktree prune &>/dev/null
                    echo "       [OK] Pruned"
                    set removed_count (math $removed_count + 1)
                end
            else
                echo "       [DRY] Would be pruned"
                set removed_count (math $removed_count + 1)
            end
            echo ""
        end
    end

    echo (string repeat -n 50 '─')
    if test "$dry_run" = true
        echo "Would remove $removed_count worktrees"
    else
        echo "Removed $removed_count worktrees"
    end
end

# Initialize hook template
function __wtm_init
    # Parse arguments after --
    set -l verbose $argv[2]
    set -l quiet $argv[3]
    if test -f ".wtm_hook.fish"
        echo "Error: .wtm_hook.fish already exists" >&2
        echo "Remove it first if you want to recreate it." >&2
        return 1
    end

    echo '#!/usr/bin/env fish
# .wtm_hook.fish - Executed after \'wtm add\' command in worktree directory
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

# Example: Show creation info
echo "[HOOK] Worktree hook executing..."
echo "   Branch: $WTM_BRANCH_NAME (from $WTM_BASE_BRANCH)"
echo "   Location: $WTM_WORKTREE_PATH"

# Files and directories to copy from project root
set -l copy_items \
    ".env" \
    ".env.local" \
    ".env.development" \
    ".claude" \
    "node_modules" \
    "vendor"

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
                case "node_modules" "vendor" ".git"
                    # Create symlink for large directories
                    ln -s "$source" "$target"
                    echo "       [LINK] $item"
                case \'*\'
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

# Example: Run initialization commands
# Uncomment and modify as needed:

# Install dependencies (if not linked)
# if not test -L "node_modules"
#     echo "[INSTALL] Installing dependencies..."
#     npm install
# end

# Run setup script
# if test -x "./scripts/setup.sh"
#     echo "[SETUP] Running setup script..."
#     ./scripts/setup.sh
# end

# Create branch-specific config
# echo "BRANCH=$WTM_BRANCH_NAME" >> .env.local

echo "[OK] Hook completed successfully"' > .wtm_hook.fish

    chmod +x .wtm_hook.fish

    test "$quiet" = false; and echo "[OK] Created .wtm_hook.fish template"
    test "$verbose" = true; and echo "Edit this file to customize worktree initialization"
    test "$verbose" = true; and echo "For global settings, you can use ~/.config/wtm/hook.fish"
end

# Switch to default branch (main/master)
function __wtm_main
    # Parse arguments after --
    set -l verbose $argv[2]
    set -l quiet $argv[3]

    # Find default branch (main or master)
    set -l default_branch
    if git rev-parse --verify main &>/dev/null
        set default_branch "main"
    else if git rev-parse --verify master &>/dev/null
        set default_branch "master"
    else
        echo "Error: No default branch (main/master) found" >&2
        return 1
    end

    # Find worktree for default branch
    set -l worktree_info (git worktree list | grep "\[$default_branch\]")

    if test -z "$worktree_info"
        echo "Error: No worktree found for branch '$default_branch'" >&2
        echo "You may need to create it with: wtm add $default_branch" >&2
        return 1
    end

    set -l worktree_path (echo $worktree_info | string split -f1 ' ')
    set -l resolved_path (path resolve $worktree_path)

    if test -d "$resolved_path"
        cd "$resolved_path"
        test "$quiet" = false; and echo "Switched to $default_branch branch"
        test "$verbose" = true; and echo "Path: $resolved_path"
        return 0
    else
        echo "Error: Directory not found: $resolved_path" >&2
        return 1
    end
end
