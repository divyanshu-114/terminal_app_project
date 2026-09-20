#!/usr/bin/env bash
# notes.sh — Notes CLI: a command-line note-taking tool for macOS
# Author: Notes CLI
# Usage: notes <command> [arguments]
# All notes are stored in ~/Desktop/Notes/ (or $NOTES_DIR if set).

set -uo pipefail
# NOTE: We deliberately do NOT use `set -e` globally because many commands
# perform expected-failure checks (file existence, grep misses, etc.) that
# would cause premature exits under -e. All error paths use explicit `if`
# checks and `exit 1`.

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

# Allow NOTES_DIR to be overridden by an environment variable (used in tests).
NOTES_DIR="${NOTES_DIR:-$HOME/Desktop/Notes}"

# ---------------------------------------------------------------------------
# HELPER: ensure_notes_dir
# Creates the notes directory if it does not exist. Exits with a clear
# message if the directory cannot be created (e.g. permission denied).
# ---------------------------------------------------------------------------
ensure_notes_dir() {
    if [[ ! -d "$NOTES_DIR" ]]; then
        if ! mkdir -p "$NOTES_DIR" 2>/dev/null; then
            printf '❌ Error: Cannot create notes directory: %s\n' "$NOTES_DIR" >&2
            printf '   Please check permissions and try again.\n' >&2
            exit 1
        fi
    fi
    # Verify the directory is writable
    if [[ ! -w "$NOTES_DIR" ]]; then
        printf '❌ Error: No write permission on notes directory: %s\n' "$NOTES_DIR" >&2
        printf '   Please check permissions and try again.\n' >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# HELPER: pad_id <number>
# Zero-pads an integer to 3 digits. e.g. pad_id 4 → "004"
# ---------------------------------------------------------------------------
pad_id() {
    printf '%03d' "$1"
}

# ---------------------------------------------------------------------------
# HELPER: note_path <id>
# Returns the full path to a note file given a (possibly unpadded) ID.
# ---------------------------------------------------------------------------
note_path() {
    local id
    id=$(pad_id "$1")
    printf '%s/%s.md' "$NOTES_DIR" "$id"
}

# ---------------------------------------------------------------------------
# HELPER: note_exists <id>
# Returns 0 (true) if the note file exists, 1 (false) otherwise.
# ---------------------------------------------------------------------------
note_exists() {
    local path
    path=$(note_path "$1")
    [[ -f "$path" ]]
}

# ---------------------------------------------------------------------------
# HELPER: next_id
# Scans existing note files, finds the highest numeric ID, and returns
# the next sequential ID (zero-padded). Returns "001" if no notes exist yet.
# ---------------------------------------------------------------------------
next_id() {
    local max_id=0
    local file num

    # Find all *.md files whose basename is exactly 3 digits
    while IFS= read -r file; do
        # Extract the numeric part from the filename (e.g. "007.md" → 7)
        num=$(basename "$file" .md)
        # Strip leading zeros so bash does not treat it as octal
        num=$((10#$num))
        if (( num > max_id )); then
            max_id=$num
        fi
    done < <(find "$NOTES_DIR" -maxdepth 1 -name '[0-9][0-9][0-9].md' 2>/dev/null)

    pad_id $(( max_id + 1 ))
}

# ---------------------------------------------------------------------------
# HELPER: parse_frontmatter <file>
# Parses the YAML-style frontmatter from a note file and sets globals:
#   NOTE_ID, NOTE_TITLE, NOTE_CREATED, NOTE_BODY
# ---------------------------------------------------------------------------
parse_frontmatter() {
    local file="$1"
    NOTE_ID=""
    NOTE_TITLE=""
    NOTE_CREATED=""
    NOTE_BODY=""

    local in_frontmatter=0
    local frontmatter_closed=0
    local body=""
    local first_body=1
    local line

    while IFS= read -r line; do
        if (( frontmatter_closed )); then
            if (( first_body )); then
                body="$line"
                first_body=0
            else
                body="${body}"$'\n'"${line}"
            fi
            continue
        fi

        if [[ "$line" == "---" ]]; then
            if (( in_frontmatter )); then
                frontmatter_closed=1
            else
                in_frontmatter=1
            fi
            continue
        fi

        if (( in_frontmatter )); then
            case "$line" in
                id:*)
                    NOTE_ID="${line#id:}"
                    NOTE_ID="${NOTE_ID# }"
                    ;;
                title:*)
                    NOTE_TITLE="${line#title:}"
                    NOTE_TITLE="${NOTE_TITLE# }"
                    ;;
                created:*)
                    NOTE_CREATED="${line#created:}"
                    NOTE_CREATED="${NOTE_CREATED# }"
                    ;;
            esac
        fi
    done < "$file"

    # Remove leading blank line from body (the blank line after "---")
    NOTE_BODY="${body#$'\n'}"
}

# ---------------------------------------------------------------------------
# HELPER: format_date <YYYY-MM-DD>
# Converts a date string like "2026-09-20" to "20 Sep 2026".
# Uses macOS/BSD date syntax (date -j -f).
# ---------------------------------------------------------------------------
format_date() {
    local raw_date="$1"
    date -j -f '%Y-%m-%d' "$raw_date" '+%d %b %Y' 2>/dev/null || printf '%s' "$raw_date"
}

# ---------------------------------------------------------------------------
# HELPER: truncate_str <string> <max_length>
# Truncates a string to max_length, appending "…" if truncated.
# ---------------------------------------------------------------------------
truncate_str() {
    local str="$1"
    local max="$2"
    if (( ${#str} > max )); then
        printf '%s…' "${str:0:$(( max - 1 ))}"
    else
        printf '%s' "$str"
    fi
}

# ---------------------------------------------------------------------------
# CMD: cmd_list / cmd_help
# Displays the help screen with all available commands.
# ---------------------------------------------------------------------------
cmd_list() {
    printf '╔══════════════════════════════════════════╗\n'
    printf '║              NOTES CLI                   ║\n'
    printf '╚══════════════════════════════════════════╝\n'
    printf '\n'
    printf 'Available Commands:\n'
    printf '\n'
    printf 'notes list\n'
    printf '    Show all available commands\n'
    printf '\n'
    printf 'notes add <title>\n'
    printf '    Create a new note\n'
    printf '\n'
    printf 'notes view <id>\n'
    printf '    View a note\n'
    printf '\n'
    printf 'notes edit <id>\n'
    printf '    Edit an existing note\n'
    printf '\n'
    printf 'notes delete <id>\n'
    printf '    Delete a note\n'
    printf '\n'
    printf 'notes search <keyword>\n'
    printf '    Search notes\n'
    printf '\n'
    printf 'notes all\n'
    printf '    Show all saved notes\n'
    printf '\n'
    printf 'notes help\n'
    printf '    Show help information\n'
    printf '\n'
    printf 'notes exit\n'
    printf '    Exit the application\n'
}

cmd_help() {
    cmd_list
}

# ---------------------------------------------------------------------------
# CMD: cmd_add <title>
# Creates a new note. Reads body content from stdin until EOF (Ctrl+D).
# Aborts without creating a file if title or body is empty.
# ---------------------------------------------------------------------------
cmd_add() {
    local title="${1:-}"

    if [[ -z "$title" ]]; then
        printf '❌ Error: Note title cannot be empty.\n' >&2
        printf 'Usage: notes add "<title>"\n' >&2
        exit 1
    fi

    printf 'Creating new note...\n'
    printf '\n'
    printf 'Title: %s\n' "$title"
    printf '\n'
    printf 'Enter your note.\n'
    printf 'Press Ctrl+D when finished.\n'
    printf '\n'

    # Read body content from stdin until EOF
    local body
    body=$(cat)

    if [[ -z "$body" ]]; then
        printf '\n❌ Error: Note content cannot be empty. Note not created.\n' >&2
        exit 1
    fi

    local id
    id=$(next_id)

    local filepath
    filepath=$(note_path "$id")

    local created
    created=$(date +%Y-%m-%d)

    if ! {
        printf -- '---\n'
        printf 'id: %s\n' "$id"
        printf 'title: %s\n' "$title"
        printf 'created: %s\n' "$created"
        printf -- '---\n'
        printf '\n'
        printf '%s\n' "$body"
    } > "$filepath" 2>/dev/null; then
        printf '❌ Error: Could not write note to %s\n' "$filepath" >&2
        printf '   Please check permissions and disk space.\n' >&2
        exit 1
    fi

    printf '✓ Note created successfully.\n'
    printf '\n'
    printf 'ID: %s\n' "$id"
    printf 'Location: ~/Desktop/Notes/%s.md\n' "$id"
}

# ---------------------------------------------------------------------------
# CMD: cmd_view <id>
# Displays a single note by ID. Normalizes the ID to 3-digit zero-padded.
# ---------------------------------------------------------------------------
cmd_view() {
    local raw_id="${1:-}"

    if [[ -z "$raw_id" ]]; then
        printf '❌ Error: Please provide a note ID.\n' >&2
        printf 'Usage: notes view <id>\n' >&2
        exit 1
    fi

    local numeric
    numeric=$(( 10#$raw_id ))
    local id
    id=$(pad_id "$numeric")

    if ! note_exists "$numeric"; then
        printf '❌ Note %s does not exist.\n' "$id" >&2
        exit 1
    fi

    local filepath
    filepath=$(note_path "$numeric")

    parse_frontmatter "$filepath"

    local display_date
    display_date=$(format_date "$NOTE_CREATED")

    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    printf '\n'
    printf 'ID: %s\n' "$NOTE_ID"
    printf 'Title: %s\n' "$NOTE_TITLE"
    printf 'Created: %s\n' "$display_date"
    printf '\n'
    printf '%s\n' "$NOTE_BODY"
    printf '\n'
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}

# ---------------------------------------------------------------------------
# CMD: cmd_all
# Lists all notes in a formatted table, sorted numerically by ID.
# Shows a friendly empty-state message if no notes exist.
# ---------------------------------------------------------------------------
cmd_all() {
    local files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "$NOTES_DIR" -maxdepth 1 -name '[0-9][0-9][0-9].md' 2>/dev/null | sort)

    if (( ${#files[@]} == 0 )); then
        printf 'No notes found.\n'
        printf '\n'
        printf 'Create your first note using:\n'
        printf '\n'
        printf '    notes add "My First Note"\n'
        return 0
    fi

    # Column widths (excluding border chars)
    local col_id=3       # "001"
    local col_title=23   # title text
    local col_created=12 # "20 Sep 2026"

    # Top border:  ┌─────┬─────────────────────────┬──────────────┐
    printf '┌'
    printf '─%.0s' $(seq 1 $(( col_id + 2 )))
    printf '┬'
    printf '─%.0s' $(seq 1 $(( col_title + 2 )))
    printf '┬'
    printf '─%.0s' $(seq 1 $(( col_created + 2 )))
    printf '┐\n'

    # Header
    printf '│ %-*s │ %-*s │ %-*s │\n' \
        "$col_id"      "ID" \
        "$col_title"   "Title" \
        "$col_created" "Created"

    # Header separator:  ├─────┼─────────────────────────┼──────────────┤
    printf '├'
    printf '─%.0s' $(seq 1 $(( col_id + 2 )))
    printf '┼'
    printf '─%.0s' $(seq 1 $(( col_title + 2 )))
    printf '┼'
    printf '─%.0s' $(seq 1 $(( col_created + 2 )))
    printf '┤\n'

    local file id_str title_trunc display_date
    for file in "${files[@]}"; do
        parse_frontmatter "$file"

        id_str=$(pad_id "$(( 10#${NOTE_ID:-0} ))")
        title_trunc=$(truncate_str "$NOTE_TITLE" "$col_title")
        display_date=$(format_date "$NOTE_CREATED")

        printf '│ %-*s │ %-*s │ %-*s │\n' \
            "$col_id"      "$id_str" \
            "$col_title"   "$title_trunc" \
            "$col_created" "$display_date"
    done

    # Bottom border:  └─────┴─────────────────────────┴──────────────┘
    printf '└'
    printf '─%.0s' $(seq 1 $(( col_id + 2 )))
    printf '┴'
    printf '─%.0s' $(seq 1 $(( col_title + 2 )))
    printf '┴'
    printf '─%.0s' $(seq 1 $(( col_created + 2 )))
    printf '┘\n'
}

# ---------------------------------------------------------------------------
# CMD: cmd_edit <id>
# Opens the note file in the user's preferred editor ($EDITOR, default nano).
# ---------------------------------------------------------------------------
cmd_edit() {
    local raw_id="${1:-}"

    if [[ -z "$raw_id" ]]; then
        printf '❌ Error: Please provide a note ID.\n' >&2
        printf 'Usage: notes edit <id>\n' >&2
        exit 1
    fi

    local numeric
    numeric=$(( 10#$raw_id ))
    local id
    id=$(pad_id "$numeric")

    if ! note_exists "$numeric"; then
        printf '❌ Note %s does not exist.\n' "$id" >&2
        exit 1
    fi

    local filepath
    filepath=$(note_path "$numeric")

    local editor="${EDITOR:-nano}"
    "$editor" "$filepath"
}

# ---------------------------------------------------------------------------
# CMD: cmd_delete <id>
# Deletes a note after displaying its title and requesting confirmation.
# ---------------------------------------------------------------------------
cmd_delete() {
    local raw_id="${1:-}"

    if [[ -z "$raw_id" ]]; then
        printf '❌ Error: Please provide a note ID.\n' >&2
        printf 'Usage: notes delete <id>\n' >&2
        exit 1
    fi

    local numeric
    numeric=$(( 10#$raw_id ))
    local id
    id=$(pad_id "$numeric")

    if ! note_exists "$numeric"; then
        printf '❌ Note %s does not exist.\n' "$id" >&2
        exit 1
    fi

    local filepath
    filepath=$(note_path "$numeric")

    parse_frontmatter "$filepath"

    printf 'Are you sure you want to delete:\n'
    printf '\n'
    printf '%s\n' "$NOTE_TITLE"
    printf '\n'
    printf '[Y/n] '

    local response
    IFS= read -r response

    # Empty input defaults to "Y" (confirm)
    response="${response:-Y}"

    case "$response" in
        [Yy])
            if ! rm "$filepath" 2>/dev/null; then
                printf '❌ Error: Could not delete note %s. Check permissions.\n' "$id" >&2
                exit 1
            fi
            printf '✓ Note deleted successfully.\n'
            ;;
        *)
            printf 'Cancelled. Note was not deleted.\n'
            ;;
    esac
}

# ---------------------------------------------------------------------------
# CMD: cmd_search <keyword>
# Case-insensitive search across note titles and body content.
# ---------------------------------------------------------------------------
cmd_search() {
    local keyword="${1:-}"

    if [[ -z "$keyword" ]]; then
        printf '❌ Error: Please provide a search keyword.\n' >&2
        printf 'Usage: notes search <keyword>\n' >&2
        exit 1
    fi

    printf 'Search results for: %s\n' "$keyword"
    printf '\n'

    local files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(find "$NOTES_DIR" -maxdepth 1 -name '[0-9][0-9][0-9].md' 2>/dev/null | sort)

    local match_count=0
    local file id_str

    for file in "${files[@]}"; do
        if grep -qi "$keyword" "$file" 2>/dev/null; then
            parse_frontmatter "$file"
            id_str=$(pad_id "$(( 10#${NOTE_ID:-0} ))")
            printf '[%s] %s\n' "$id_str" "$NOTE_TITLE"
            (( match_count++ )) || true
        fi
    done

    printf '\n'

    if (( match_count == 0 )); then
        printf 'No notes found matching "%s".\n' "$keyword"
    else
        if (( match_count == 1 )); then
            printf '%d note found.\n' "$match_count"
        else
            printf '%d notes found.\n' "$match_count"
        fi
    fi
}

# ---------------------------------------------------------------------------
# CMD: cmd_exit
# Prints a goodbye message and exits cleanly.
# Note: since notes CLI is not a REPL (each invocation is a single shell
# command), this provides a graceful exit signal. See README for details.
# ---------------------------------------------------------------------------
cmd_exit() {
    printf 'Goodbye! Your notes are safe in %s\n' "$NOTES_DIR"
    exit 0
}

# ---------------------------------------------------------------------------
# MAIN DISPATCH
# Ensures the notes directory exists, then routes $1 to the correct function.
# ---------------------------------------------------------------------------
main() {
    ensure_notes_dir

    local cmd="${1:-list}"
    if (( $# > 0 )); then
        shift
    fi

    case "$cmd" in
        list)    cmd_list    "$@" ;;
        help)    cmd_help    "$@" ;;
        add)     cmd_add     "$@" ;;
        view)    cmd_view    "$@" ;;
        all)     cmd_all     "$@" ;;
        edit)    cmd_edit    "$@" ;;
        delete)  cmd_delete  "$@" ;;
        search)  cmd_search  "$@" ;;
        exit)    cmd_exit    "$@" ;;
        *)
            printf '❌ Unknown command: %s\n' "$cmd" >&2
            printf '\n' >&2
            printf 'Run:\n' >&2
            printf '\n' >&2
            printf '    notes list\n' >&2
            printf '\n' >&2
            printf 'to see all available commands.\n' >&2
            exit 1
            ;;
    esac
}

main "$@"
