#!/bin/bash
set -euo pipefail

LOCK_USER="$(whoami)"
CONFIG_FILE="$HOME/.config/reaper-sync/config"

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

SERVER="${SERVER:?ERROR: SERVER not set. Run the setup script in Reaper or add SERVER=hostname to $CONFIG_FILE}"
REMOTE_BASE="${REMOTE_BASE:?ERROR: REMOTE_BASE not set. Run the setup script in Reaper or add REMOTE_BASE=/path to $CONFIG_FILE}"
LOCAL_BASE="${LOCAL_BASE:?ERROR: LOCAL_BASE not set. Run the setup script in Reaper or add LOCAL_BASE=/path to $CONFIG_FILE}"

RSYNC_OPTS=(-avz -e ssh --exclude='Peaks/' --exclude='Backups/' --exclude='*.RPP-bak' --exclude='*.rpp-bak' --exclude='.DS_Store' --exclude='.lock')

usage() {
    cat <<'EOF'
Usage: reaper-sync <command> [project]

Commands:
  pull <project>        Lock and pull project for editing
  push <project>        Push changes and unlock
  listen <project>      Pull read-only copy (no lock)
  status                Show all projects and lock status
  list                  List project names
  break-lock <project>  Force-remove a lock
EOF
    exit 1
}

remote() {
    ssh "$SERVER" "$@"
}

get_lock() {
    remote "cat '$REMOTE_BASE/$1/.lock' 2>/dev/null" || true
}

lock_owner() {
    echo "$1" | head -1
}

require_project_arg() {
    if [ $# -lt 1 ] || [ -z "$1" ]; then
        echo "ERROR: project name required" >&2
        exit 1
    fi
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: project name can only contain letters, numbers, hyphens, and underscores" >&2
        exit 1
    fi
}

require_remote_project() {
    if ! remote "test -d '$REMOTE_BASE/$1'" 2>/dev/null; then
        echo "ERROR: project '$1' does not exist on server" >&2
        echo "Use 'reaper-sync list' to see available projects." >&2
        exit 1
    fi
}

cmd_pull() {
    local project="$1"
    require_remote_project "$project"

    local lock
    lock=$(get_lock "$project")

    if [ -n "$lock" ]; then
        local owner
        owner=$(lock_owner "$lock")
        if [ "$owner" != "$LOCK_USER" ]; then
            echo "ERROR: '$project' is locked by $owner" >&2
            echo "$lock" >&2
            exit 1
        fi
        echo "Already locked by you, re-pulling..."
    else
        remote "printf '%s\n%s\n' '$LOCK_USER' '$(date -u +%Y-%m-%dT%H:%M:%SZ)' > '$REMOTE_BASE/$project/.lock'"
        echo "Locked '$project'"
    fi

    mkdir -p "$LOCAL_BASE/$project"
    rsync "${RSYNC_OPTS[@]}" "$SERVER:$REMOTE_BASE/$project/" "$LOCAL_BASE/$project/"
    echo "Pulled '$project' → $LOCAL_BASE/$project"
}

cmd_push() {
    local project="$1"

    if [ ! -d "$LOCAL_BASE/$project" ]; then
        echo "ERROR: local project '$LOCAL_BASE/$project' not found" >&2
        exit 1
    fi

    if remote "test -d '$REMOTE_BASE/$project'" 2>/dev/null; then
        local lock
        lock=$(get_lock "$project")
        if [ -n "$lock" ]; then
            local owner
            owner=$(lock_owner "$lock")
            if [ "$owner" != "$LOCK_USER" ]; then
                echo "ERROR: '$project' is locked by $owner — cannot push" >&2
                exit 1
            fi
        else
            echo "WARNING: '$project' is not locked by you. Pushing anyway."
        fi
    else
        echo "Project '$project' is new — creating on server..."
        remote "mkdir -p '$REMOTE_BASE/$project'"
    fi

    rsync "${RSYNC_OPTS[@]}" --delete "$LOCAL_BASE/$project/" "$SERVER:$REMOTE_BASE/$project/"
    remote "rm -f '$REMOTE_BASE/$project/.lock'"
    echo "Pushed '$project' and unlocked"
}

cmd_listen() {
    local project="$1"
    require_remote_project "$project"

    local lock
    lock=$(get_lock "$project")
    if [ -n "$lock" ]; then
        local owner
        owner=$(lock_owner "$lock")
        echo "Note: '$project' is locked by $owner (pulling read-only copy)"
    fi

    mkdir -p "$LOCAL_BASE/$project"
    rsync "${RSYNC_OPTS[@]}" "$SERVER:$REMOTE_BASE/$project/" "$LOCAL_BASE/$project/"
    echo "Pulled read-only copy of '$project' → $LOCAL_BASE/$project"
}

cmd_status() {
    local projects
    projects=$(remote "ls -1 '$REMOTE_BASE' 2>/dev/null" || true)

    if [ -z "$projects" ]; then
        echo "No projects on server."
        return
    fi

    while IFS= read -r project; do
        local lock
        lock=$(get_lock "$project")
        if [ -n "$lock" ]; then
            local owner
            owner=$(lock_owner "$lock")
            local when
            when=$(echo "$lock" | sed -n '2p')
            echo "$project  (locked by $owner since $when)"
        else
            echo "$project"
        fi
    done <<< "$projects"
}

cmd_list() {
    remote "ls -1 '$REMOTE_BASE' 2>/dev/null" || echo "No projects on server."
}

cmd_break_lock() {
    local project="$1"
    require_remote_project "$project"

    local lock
    lock=$(get_lock "$project")

    if [ -z "$lock" ]; then
        echo "'$project' is not locked."
        return
    fi

    echo "Current lock:"
    echo "$lock"


    remote "rm -f '$REMOTE_BASE/$project/.lock'"
    echo "Lock removed from '$project'"
}

[ $# -lt 1 ] && usage

cmd="$1"
shift

case "$cmd" in
    pull|push|listen|break-lock)
        require_project_arg "$@"
        "cmd_$(echo "$cmd" | tr '-' '_')" "$1"
        ;;
    status) cmd_status ;;
    list)   cmd_list ;;
    -h|--help|help) usage ;;
    *) echo "Unknown command: $cmd" >&2; usage ;;
esac
