function wtm --description "Git worktree manager with advanced features"
    # Parse global options - stop at first non-option argument
    argparse -s h/help v/verbose q/quiet -- $argv
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

    # Prepare flags to pass to subcommands
    set -l flags_to_pass
    if $verbose
        set -a flags_to_pass --verbose
    end
    if $quiet
        set -a flags_to_pass --quiet
    end

    # Main command logic
    switch "$cmd"
        case "" # Interactive selection
            __wtm_interactive $argv $flags_to_pass

        case open
            __wtm_open $argv $flags_to_pass

        case add
            __wtm_add $argv $flags_to_pass

        case remove rm
            __wtm_remove $argv $flags_to_pass

        case list ls
            __wtm_list $argv $flags_to_pass

        case clean
            __wtm_clean $argv $flags_to_pass

        case cp
            __wtm_cp $argv $flags_to_pass

        case diff
            __wtm_diff $argv $flags_to_pass

        case mv
            __wtm_mv $argv $flags_to_pass

        case hook
            __wtm_hook $argv $flags_to_pass

        case init
            __wtm_init $argv $flags_to_pass

        case main default
            __wtm_main $argv $flags_to_pass

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

function __wtm_operate_files -a operation
    # Parse options
    argparse h/help v/verbose q/quiet 'b/branch=' -- $argv
    or return 1

    set -e argv[1]

    # Handle help flag
    if set -ql _flag_help
        if test "$operation" = cp
            __wtm_cp_help
        else if test "$operation" = diff
            __wtm_diff_help
        else if test "$operation" = mv
            __wtm_mv_help
        end
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

    if not set -ql _flag_branch
        echo "Error: Target branch name required, use -b/--branch flag" >&2
        if test "$operation" = cp
            __wtm_cp_help
        else if test "$operation" = diff
            __wtm_diff_help
        else
            __wtm_mv_help
        end
        return 1
    end
    set -l target_branch $_flag_branch
    set -l files $argv

    if test -z "$target_branch"
        echo "Error: Target branch name required" >&2
        if test "$operation" = cp
            __wtm_cp_help
        else if test "$operation" = diff
            __wtm_diff_help
        else if test "$operation" = mv
            __wtm_mv_help
        end
        return 1
    end

    if test -z "$files"
        echo "Error: At least one file must be specified" >&2
        if test "$operation" = cp
            __wtm_cp_help
        else if test "$operation" = diff
            __wtm_diff_help
        else if test "$operation" = mv
            __wtm_mv_help
        end
        return 1
    end

    # Get repository root
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$repo_root"
        echo "Error: Not in a Git repository" >&2
        return 1
    end

    # Get current working directory
    set -l cwd (pwd)

    # Find worktree for target branch
    set -l target_worktree_path
    git worktree list --porcelain | while read -l key value
        switch $key
            case worktree
                set current_path $value
            case branch
                if test (string replace 'refs/heads/' '' $value) = "$target_branch"
                    set target_worktree_path $current_path
                    break
                end
        end
    end

    if not set -q target_worktree_path
        echo "Error: No worktree found for branch '$target_branch'" >&2
        return 1
    end
    set -l resolved_target_path (path resolve $target_worktree_path)

    for file in $files
        set -l source_file (path resolve "$cwd/$file")
        set -l relative_path (string replace "$repo_root/" "" "$source_file")
        set -l dest_file (path resolve "$resolved_target_path/$relative_path")

        if not test -f "$source_file"
            echo "[WARN] Source file not found: $source_file" >&2
            continue
        end

        if test "$operation" = diff
            if not test -f "$dest_file"
                echo "[WARN] Destination file not found: $dest_file" >&2
                continue
            end
        else
            set -l dest_dir (dirname "$dest_file")
            if not test -d "$dest_dir"
                mkdir -p "$dest_dir"
                test "$verbose" = true; and echo "[INFO] Created directory: $dest_dir"
            end
        end

        if test "$operation" = diff
            if command -sq delta
                delta "$source_file" "$dest_file"
            else
                diff -u "$source_file" "$dest_file"
            end
        else
            $operation "$source_file" "$dest_file"
        end
    end
    return 0
end

function __wtm_cp
    __wtm_operate_files cp $argv
end

function __wtm_diff
    __wtm_operate_files diff $argv
end

function __wtm_mv
    __wtm_operate_files mv $argv
end

# Run hooks on existing worktrees
function __wtm_hook
    argparse a/all h/help v/verbose q/quiet -- $argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_hook_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

    set -l branch_name $argv[1]

    # Check if we're in a Git repository
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$repo_root"
        echo "Error: Not in a Git repository" >&2
        return 1
    end

    # Get project root (main repository) - use repo_root we already computed
    set -l project_root "$repo_root"

    # Find hook file (same logic as __wtm_add)
    set -l hook_file
    if test -f "$project_root/.wtm_hook.fish"
        set hook_file "$project_root/.wtm_hook.fish"
    else if test -f "$HOME/.config/wtm/hook.fish"
        set hook_file "$HOME/.config/wtm/hook.fish"
    end

    if test -z "$hook_file"
        echo "Error: No hook file found" >&2
        echo "Create .wtm_hook.fish in project root or ~/.config/wtm/hook.fish" >&2
        return 1
    end

    # Function to execute hook for a single branch
    function __wtm_execute_hook_for_branch -a branch -a hook_file_arg -a project_root_arg
        # Find worktree path
        set -l worktree_info (git worktree list | grep "\[$branch\]")
        if test -z "$worktree_info"
            echo "Error: No worktree found for branch '$branch'" >&2
            return 1
        end

        set -l worktree_path (echo $worktree_info | string split -f1 ' ')
        set -l resolved_path (path resolve $worktree_path)

        if not test -d "$resolved_path"
            echo "Error: Directory not found: $resolved_path" >&2
            return 1
        end

        test "$quiet" = false; and echo "[HOOK] Running hook for branch: $branch"
        test "$verbose" = true; and echo "  Worktree path: $resolved_path"

        # Determine base branch (current branch in worktree)
        set -l base_branch (git -C "$resolved_path" branch --show-current 2>/dev/null)
        if test -z "$base_branch"
            set base_branch "unknown"
        end

        # Set environment variables (same as __wtm_add)
        set -gx WTM_WORKTREE_PATH "$resolved_path"
        set -gx WTM_BRANCH_NAME "$branch"
        set -gx WTM_BASE_BRANCH "$base_branch"
        set -gx WTM_PROJECT_ROOT "$project_root_arg"
        set -gx WTM_TIMESTAMP (date +"%Y-%m-%d %H:%M:%S")

        # Execute hook
        fish "$hook_file_arg"
        set -l hook_status $status

        # Clean up environment variables
        set -e WTM_WORKTREE_PATH
        set -e WTM_BRANCH_NAME
        set -e WTM_BASE_BRANCH
        set -e WTM_PROJECT_ROOT
        set -e WTM_TIMESTAMP

        if test $hook_status -ne 0
            echo "[WARN] Hook execution failed for branch '$branch' with status $hook_status" >&2
            return 1
        else
            test "$quiet" = false; and echo "[OK] Hook executed successfully for branch: $branch"
            return 0
        end
    end

    # Mode 1: --all flag
    if set -ql _flag_all
        test "$quiet" = false; and echo "[HOOK] Running hooks on all worktrees..."

        set -l all_branches
        git worktree list | while read -l line
            set -l branch (echo $line | string match -r '\[([^\]]+)\]' | string split -f2 '[' | string trim -c ']')
            if test -n "$branch"
                set -a all_branches $branch
            end
        end

        if test (count $all_branches) -eq 0
            echo "Error: No worktrees found" >&2
            return 1
        end

        set -l success_count 0
        set -l total_count (count $all_branches)

        for branch in $all_branches
            __wtm_execute_hook_for_branch "$branch" "$hook_file" "$project_root"
            if test $status -eq 0
                set success_count (math $success_count + 1)
            end
        end

        test "$quiet" = false; and echo "[SUMMARY] Successfully executed hooks on $success_count of $total_count worktrees"
        return (test $success_count -eq $total_count; and echo 0; or echo 1)

    # Mode 2: Specific branch provided
    else if test -n "$branch_name"
        __wtm_execute_hook_for_branch "$branch_name" "$hook_file"
        return $status

    # Mode 3: Interactive selection (default)
    else
        # Check if fzf is available
        if not command -sq fzf
            echo "Error: fzf is not installed. Please install fzf to use interactive mode." >&2
            echo "Alternatively, specify a branch: wtm hook <branch>" >&2
            return 1
        end

        # Get worktree list for fzf
        set -l worktrees (git worktree list 2>/dev/null)
        if test -z "$worktrees"
            echo "Error: No worktrees found" >&2
            return 1
        end

        # Extract branch names for fzf display
        set -l branch_names
        for worktree in $worktrees
            set -a branch_names (echo $worktree | string match -r '\[([^\]]+)\]' | string split -f2 '[' | string trim -c ']')
        end

        # Select branch with fzf (multi-select enabled)
        set -l selected_branches (printf '%s\n' $branch_names | fzf \
            --multi \
            --preview-window="right:70%:wrap" \
            --preview='
                set -l branch {}
                set -l line (git worktree list | grep "\[$branch\]")
                set -l worktree_path (echo $line | string split -f1 " ")
                set -l resolved_path (path resolve $worktree_path)

                echo "╭───────────────────────────────────────────────────────────────────╮"
                echo "│  Worktree Information                                             │"
                echo "├───────────────────────────────────────────────────────────────────┤"
                echo "│   Branch:  $branch"
                echo "│   Path:    $resolved_path"
                echo "╰───────────────────────────────────────────────────────────────────╯"
                echo ""

                # Show hook file that would be executed
                set -l project_root (git rev-parse --show-toplevel)
                set -l hook_file
                if test -f "$project_root/.wtm_hook.fish"
                    set hook_file "$project_root/.wtm_hook.fish"
                else if test -f "$HOME/.config/wtm/hook.fish"
                    set hook_file "$HOME/.config/wtm/hook.fish"
                end

                if test -n "$hook_file"
                    echo "Hook file: $hook_file"
                    echo ""
                    echo "First 10 lines of hook file:"
                    echo "(string repeat -n 50 "─")"
                    head -10 "$hook_file" | string replace -r "^" "  "
                else
                    echo "No hook file found"
                end
            ' \
            --header="╭────────────────────────────────────────────────────────────────────╮
│  Select worktrees to run hooks on (TAB to select multiple)        │
│  ↑/↓ Navigate  ⏎ Execute  ^C Cancel                               │
╰────────────────────────────────────────────────────────────────────╯" \
            --border=rounded \
            --height=80% \
            --layout=reverse \
            --prompt="> " \
            --ansi)

        if test -z "$selected_branches"
            echo Cancelled
            return 0
        end

        set -l success_count 0
        set -l total_count (count $selected_branches)

        for branch in $selected_branches
            __wtm_execute_hook_for_branch "$branch" "$hook_file" "$project_root"
            if test $status -eq 0
                set success_count (math $success_count + 1)
            end
        end

        test "$quiet" = false; and echo "[SUMMARY] Successfully executed hooks on $success_count of $total_count selected worktrees"
        return (test $success_count -eq $total_count; and echo 0; or echo 1)
    end
end

# Interactive worktree selection with fzf
function __wtm_interactive
    argparse v/verbose q/quiet h/help -- $argv
    or return 1

    if set -ql _flag_help
        __wtm_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

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
        --prompt="> " \
        --ansi)

    __wtm_open_branch "$selected_branch" $verbose $quiet
end

function __wtm_open_branch -a branch verbose quiet
    if test -n "$branch"
        # Find the worktree path for the selected branch
        set -l worktree_info (git worktree list | grep "\[$branch\]")
        set -l worktree_path (echo $worktree_info | string split -f1 ' ')
        set -l resolved_path (path resolve $worktree_path)

        if test -d "$resolved_path"
            cd "$resolved_path"
            test "$quiet" = false; and echo "Switched to worktree '$branch'"
            test "$verbose" = true; and echo "Path: $resolved_path"
            return 0
        else
            echo "Error: Directory not found: $worktree_path" >&2
            return 1
        end
    end
end

# Open existing worktree
function __wtm_open
    # Parse open-specific options
    argparse h/help v/verbose q/quiet -- $argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_open_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

    set -l branch_name $argv[1]

    # If no branch name provided, use fzf for interactive selection
    if test -z "$branch_name"
        set -l flags_to_pass
        if test "$verbose" = true
            set -a flags_to_pass --verbose
        end
        if test "$quiet" = true
            set -a flags_to_pass --quiet
        end
        __wtm_interactive $flags_to_pass
    else
        __wtm_open_branch "$branch_name" $verbose $quiet
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
    echo "(string repeat -n 50 '─')"

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
                case "M " " M" MM
                    echo "   Modified: $file"
                case "A " AM
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
    echo "(string repeat -n 50 '─')"
    git -C "$resolved_path" log --oneline --color=always -10 2>/dev/null | string replace -r '^' '  '
end

# Add new worktree
function __wtm_add
    # Parse add-specific options
    argparse 'b/base=' no-hook sync h/help v/verbose q/quiet -- $argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_add_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

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

    # Use branch name for directory
    set -l worktree_path "$wtm_data_dir/$branch_name"

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
        set base_branch main
        # Check if main exists, otherwise try master
        if not git rev-parse --verify main &>/dev/null
            if git rev-parse --verify master &>/dev/null
                set base_branch master
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

    set -l worktree_add_cmd git worktree add
    set -l success_message_branch_info

    # Check if branch already exists
    if git rev-parse --verify "$branch_name" &>/dev/null
        # Branch exists, create worktree from it
        test "$verbose" = true; and echo "Branch '$branch_name' exists, creating worktree from it."
        set -a worktree_add_cmd "$worktree_path" "$branch_name"
        set success_message_branch_info "Branch: $branch_name (existing)"
    else
        # Check if branch exists remotely
        set -l remote_branch (git ls-remote --heads origin "$branch_name" | string split -f1 '\t')
        if test -n "$remote_branch"
            # Branch exists remotely, create tracking branch
            set base_branch "origin/$branch_name"
            test "$verbose" = true; and echo "Branch '$branch_name' exists remotely, creating tracking branch."
            set -a worktree_add_cmd --track -b "$branch_name" "$worktree_path" "$base_branch"
            set success_message_branch_info "Branch: $branch_name (tracking origin/$branch_name)"
        else
            # Branch doesn't exist, create new branch
            test "$verbose" = true; and echo "Branch '$branch_name' does not exist, creating new branch."
            set -a worktree_add_cmd -b "$branch_name" "$worktree_path" "$base_branch"
            set success_message_branch_info "Branch: $branch_name (based on $base_branch)"
        end
    end

    test "$verbose" = true; and echo "Command: $worktree_add_cmd"

    if $worktree_add_cmd &>/tmp/wtm_add.log
        test "$quiet" = false; and echo "[OK] Created worktree at: $worktree_path"
        test "$quiet" = false; and echo "     $success_message_branch_info"

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
            set -gx WTM_PROJECT_ROOT "$project_root_arg"
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
    # Parse remove-specific options
    argparse h/help b/branch f/force v/verbose q/quiet -- $argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_remove_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

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
        set -l worktrees (git worktree list 2>/dev/null | grep -v '.*\\\[\(main\|master\)\]')
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
            echo Cancelled
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
    if set -ql _flag_branch
        echo "This will also delete branch: $branch_name"
    else
        echo "The branch '$branch_name' will be kept"
    end

    read -l -P "Are you sure? (Y/n) " confirm
    if not string match -qi y $confirm
        echo Cancelled
        return 0
    end

    # Check for uncommitted changes before removing worktree
    set -l has_uncommitted_changes (git -C "$resolved_path" status --porcelain 2>/dev/null)
    if test -n "$has_uncommitted_changes"; and not set -ql _flag_force
        echo "Error: Worktree has uncommitted changes. Use --force to override." >&2
        return 1
    end

    # Check if branch is merged if --branch flag is provided
    if set -ql _flag_branch; and not set -ql _flag_force
        set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD | string split -f3 /)
        set -l is_merged (git branch --merged $default_branch | grep "$branch_name")
        if test -z "$is_merged"
            echo "Error: Branch '$branch_name' is not merged into '$default_branch'. Use --force to delete." >&2
            return 1
        end
    end

    # Remove worktree
    test "$quiet" = false; and echo "Removing worktree..."
    set -l remove_cmd git worktree remove "$worktree_path"
    if set -ql _flag_force
        set -a remove_cmd --force
    end

    if $remove_cmd &>/tmp/wtm_remove.log
        test "$quiet" = false; and echo "[OK] Removed worktree: $resolved_path"

        # Clean up empty parent directories
        set -l parent_dir (dirname "$resolved_path")
        set -l wtm_data_dir (path resolve (git rev-parse --git-common-dir)/wtm_data)
        while test "$parent_dir" != "$wtm_data_dir" -a "$parent_dir" != /
            if test (count (ls "$parent_dir")) -eq 0
                test "$verbose" = true; and echo "Removing empty directory: $parent_dir"
                rmdir "$parent_dir" 2>/dev/null
                set parent_dir (dirname "$parent_dir")
            else
                break
            end
        end

        # Make branch deletion conditional
        if set -ql _flag_branch
            # Delete branch
            set -l delete_branch_cmd git branch
            if set -ql _flag_force
                set -a delete_branch_cmd -D
            else
                set -a delete_branch_cmd -d
            end
            set -a delete_branch_cmd "$branch_name"

            if $delete_branch_cmd &>>/tmp/wtm_remove.log
                test "$quiet" = false; and echo "[OK] Deleted branch: $branch_name"
            else
                echo "[WARN] Failed to delete branch: $branch_name" >&2
                test "$verbose" = true; and cat /tmp/wtm_remove.log >&2
            end
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
    # Parse list-specific options
    argparse h/help v/verbose q/quiet -- $argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_list_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

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
    # Parse clean-specific options
    argparse n/dry-run 'days=' h/help v/verbose q/quiet -- $argv
    or return 1

    # Handle help flag
    if set -ql _flag_help
        __wtm_clean_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

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

    echo "(string repeat -n 50 '─')"
    if test "$dry_run" = true
        echo "Would remove $removed_count worktrees"
    else
        echo "Removed $removed_count worktrees"
    end
end

# Initialize hook template
function __wtm_init
    argparse v/verbose q/quiet h/help -- $argv
    or return 1

    if set -ql _flag_help
        __wtm_init_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

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

echo "[OK] Hook completed successfully"' >.wtm_hook.fish

    chmod +x .wtm_hook.fish

    test "$quiet" = false; and echo "[OK] Created .wtm_hook.fish template"
    test "$verbose" = true; and echo "Edit this file to customize worktree initialization"
    test "$verbose" = true; and echo "For global settings, you can use ~/.config/wtm/hook.fish"
end

# Switch to default branch (main/master)
function __wtm_main
    argparse v/verbose q/quiet h/help -- $argv
    or return 1

    if set -ql _flag_help
        __wtm_main_help
        return 0
    end

    set -l verbose (set -ql _flag_verbose; and echo true; or echo false)
    set -l quiet (set -ql _flag_quiet; and echo true; or echo false)

    # Find default branch (main or master)
    set -l default_branch
    if git rev-parse --verify main &>/dev/null
        set default_branch main
    else if git rev-parse --verify master &>/dev/null
        set default_branch master
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
        test "$quiet" = false; and echo "Switched to default branch '$default_branch'"
        test "$verbose" = true; and echo "Path: $resolved_path"
        return 0
    else
        echo "Error: Directory not found: $resolved_path" >&2
        return 1
    end
end

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
    echo "  wtm cp -b <branch> <files...>    - Copy files to another worktree"
    echo "  wtm mv -b <branch> <files...>    - Move files to another worktree"
    echo "  wtm diff -b <branch> <files...>  - Diff files with another worktree"
    echo "  wtm init                         - Create .wtm_hook.fish template"
    echo "  wtm main                         - Switch to default branch (main/master)"
    echo "  wtm hook [<branch>]              - Run hooks on existing worktrees"
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
    echo "HOOK OPTIONS:"
    echo "  -a, --all                       - Run hooks on all worktrees"
    echo ""
    echo "EXAMPLES:"
    echo "  wtm                              - Select worktree interactively"
    echo "  wtm add feature/new-ui          - Create new feature branch"
    echo "  wtm clean --days 30             - Remove worktrees older than 30 days"
    echo "  wtm main                         - Switch to main branch"
    echo "  wtm cp -b feature/new-ui src/main.js - Copy files to another worktree"
    echo "  wtm mv -b feature/new-ui src/main.js - Move files to another worktree"
    echo "  wtm diff -b feature/new-ui src/main.js - Diff files with another worktree"
    echo "  wtm hook --all                       - Run hooks on all worktrees"
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
    echo "│ wtm remove - Remove worktree and optionally branch       │"
    echo "╰──────────────────────────────────────────────────────────╯"
    echo ""
    echo "USAGE:"
    echo "  wtm remove [<branch>] [options]"
    echo ""
    echo "OPTIONS:"
    echo "  -b, --branch          Remove the branch as well (default: false)"
    echo "  -f, --force           Force removal of worktree with uncommitted changes or unmerged branches"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "DESCRIPTION:"
    echo "  Remove a worktree and its associated branch."
    echo "  If no branch is specified, interactive selection with fzf is used."
    echo "  Protected branches (main/master) and current branch cannot be removed."
    echo "  By default, it prevents removing worktrees with uncommitted changes or branches that are not merged."
    echo ""
    echo "EXAMPLES:"
    echo "  wtm remove                          - Interactive selection"
    echo "  wtm remove feature/old-ui           - Remove specific branch"
    echo "  wtm remove feature/old-ui --branch  - Remove worktree and branch"
    echo "  wtm remove feature/old-ui --branch --force - Force remove worktree and branch"
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

function __wtm_cp_help
    echo "╭──────────────────────────────────────────────────────────╮"
    echo "│ wtm cp - Copy files to another worktree                  │"
    echo "╰──────────────────────────────────────────────────────────╯"
    echo ""
    echo "USAGE:"
    echo "  wtm cp -b <branch> <file1> [file2 ...]"
    echo ""
    echo "OPTIONS:"
    echo "  -b, --branch <branch> The target worktree branch"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "DESCRIPTION:"
    echo "  Copy one or more files from the current worktree to the same relative path in another worktree."
    echo ""
    echo "EXAMPLES:"
    echo "  wtm cp -b feature/new-ui src/main.js"
    echo "  wtm cp --branch hotfix/bug-123 README.md package.json"
end

function __wtm_diff_help
    echo "╭──────────────────────────────────────────────────────────╮"
    echo "│ wtm diff - Diff files with another worktree              │"
    echo "╰──────────────────────────────────────────────────────────╯"
    echo ""
    echo "USAGE:"
    echo "  wtm diff -b <branch> <file1> [file2 ...]"
    echo ""
    echo "OPTIONS:"
    echo "  -b, --branch <branch> The target worktree branch"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "DESCRIPTION:"
    echo "  Diff one or more files from the current worktree to the same relative path in another worktree."
    echo ""
    echo "EXAMPLES:"
    echo "  wtm diff -b feature/new-ui src/main.js"
    echo "  wtm diff --branch hotfix/bug-123 README.md package.json"
end

function __wtm_mv_help
    echo "╭──────────────────────────────────────────────────────────╮"
    echo "│ wtm mv - Move files to another worktree                  │"
    echo "╰──────────────────────────────────────────────────────────╯"
    echo ""
    echo "USAGE:"
    echo "  wtm mv -b <branch> <file1> [file2 ...]"
    echo ""
    echo "OPTIONS:"
    echo "  -b, --branch <branch> The target worktree branch"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "DESCRIPTION:"
    echo "  Move one or more files from the current worktree to the same relative path in another worktree."
    echo ""
    echo "EXAMPLES:"
    echo "  wtm mv -b feature/new-ui src/main.js"
    echo "  wtm mv --branch hotfix/bug-123 README.md package.json"
end

function __wtm_hook_help
    echo "╭──────────────────────────────────────────────────────────╮"
    echo "│ wtm hook - Run hooks on existing worktrees               │"
    echo "╰──────────────────────────────────────────────────────────╯"
    echo ""
    echo "USAGE:"
    echo "  wtm hook [<branch>]"
    echo "  wtm hook --all"
    echo ""
    echo "OPTIONS:"
    echo "  -a, --all            Run hooks on all worktrees"
    echo "  -h, --help           Show this help message"
    echo "  -v, --verbose        Show detailed output"
    echo "  -q, --quiet          Suppress non-error output"
    echo ""
    echo "DESCRIPTION:"
    echo "  Run hooks on existing worktrees. Hooks are Fish scripts that can"
    echo "  automate setup tasks like copying environment files, creating"
    echo "  symlinks, or running initialization commands."
    echo ""
    echo "  If no branch is specified, opens an interactive fzf interface to"
    echo "  select worktree(s). Use TAB to select multiple worktrees."
    echo ""
    echo "  Hooks receive these environment variables:"
    echo "  - WTM_WORKTREE_PATH: Path to the worktree"
    echo "  - WTM_BRANCH_NAME: Name of the branch"
    echo "  - WTM_BASE_BRANCH: Current branch in the worktree"
    echo "  - WTM_PROJECT_ROOT: Path to the original project root"
    echo "  - WTM_TIMESTAMP: Current timestamp"
    echo ""
    echo "EXAMPLES:"
    echo "  wtm hook                     # Interactive selection"
    echo "  wtm hook feature/new-ui      # Run hook on specific branch"
    echo "  wtm hook --all               # Run hooks on all worktrees"
    echo "  wtm hook --all --verbose     # Run on all with detailed output"
end

function __wtm_init_help
    echo "╭──────────────────────────────────────────────────────────╮"
    echo "│ wtm init - Create a .wtm_hook.fish template              │"
    echo "╰──────────────────────────────────────────────────────────╯"
    echo ""
    echo "USAGE:"
    echo "  wtm init [options]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "DESCRIPTION:"
    echo "  Creates a '.wtm_hook.fish' file in the current directory."
    echo "  This hook file is executed after 'wtm add' and can be used to"
    echo "  automate setup tasks for new worktrees, like installing"
    echo "  dependencies or creating symlinks."
end

function __wtm_main_help
    echo "╭──────────────────────────────────────────────────────────╮"
    echo "│ wtm main - Switch to the default branch worktree         │"
    echo "╰──────────────────────────────────────────────────────────╯"
    echo ""
    echo "USAGE:"
    echo "  wtm main [options]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "DESCRIPTION:"
    echo "  Switches to the worktree associated with the default branch"
    echo "  of the repository (usually 'main' or 'master')."
end
