#!/usr/bin/env bash
# test/test.sh — Automated tests for Notes CLI
# Usage: bash test/test.sh
# Tests run against a temporary directory; real ~/Desktop/Notes/ is never touched.

set -uo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTES_SCRIPT="$(cd "$SCRIPT_DIR/.." && pwd)/notes.sh"

# Verify the main script exists
if [[ ! -f "$NOTES_SCRIPT" ]]; then
    printf 'ERROR: notes.sh not found at: %s\n' "$NOTES_SCRIPT"
    exit 1
fi

# Create a temporary directory for test notes; export so notes.sh picks it up
NOTES_DIR=$(mktemp -d)
export NOTES_DIR

# ---------------------------------------------------------------------------
# TEST FRAMEWORK
# ---------------------------------------------------------------------------

PASS_COUNT=0
FAIL_COUNT=0
TESTS_RUN=0

# Colors (ANSI) — gracefully degrade if terminal doesn't support them
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
    BOLD='\033[1m'
else
    GREEN='' RED='' YELLOW='' CYAN='' RESET='' BOLD=''
fi

# run_test <description> <expected_exit_code> <actual_exit_code> <output_to_check> <expected_pattern>
# Logs PASS or FAIL with context.
assert_pass() {
    local description="$1"
    local condition="$2"   # "true" or "false"
    TESTS_RUN=$(( TESTS_RUN + 1 ))
    if [[ "$condition" == "true" ]]; then
        printf "${GREEN}  ✓ PASS${RESET}  %s\n" "$description"
        PASS_COUNT=$(( PASS_COUNT + 1 ))
    else
        printf "${RED}  ✗ FAIL${RESET}  %s\n" "$description"
        FAIL_COUNT=$(( FAIL_COUNT + 1 ))
    fi
}

# assert_exit_code <description> <expected> <actual>
assert_exit_code() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    TESTS_RUN=$(( TESTS_RUN + 1 ))
    if [[ "$actual" -eq "$expected" ]]; then
        printf "${GREEN}  ✓ PASS${RESET}  %s (exit=%s)\n" "$description" "$actual"
        PASS_COUNT=$(( PASS_COUNT + 1 ))
    else
        printf "${RED}  ✗ FAIL${RESET}  %s (expected exit=%s, got exit=%s)\n" \
            "$description" "$expected" "$actual"
        FAIL_COUNT=$(( FAIL_COUNT + 1 ))
    fi
}

# assert_contains <description> <output> <pattern>
assert_contains() {
    local description="$1"
    local output="$2"
    local pattern="$3"
    TESTS_RUN=$(( TESTS_RUN + 1 ))
    if echo "$output" | grep -q "$pattern"; then
        printf "${GREEN}  ✓ PASS${RESET}  %s\n" "$description"
        PASS_COUNT=$(( PASS_COUNT + 1 ))
    else
        printf "${RED}  ✗ FAIL${RESET}  %s\n" "$description"
        printf "            Pattern not found: [%s]\n" "$pattern"
        printf "            In output:\n"
        echo "$output" | sed 's/^/              /' | head -20
        FAIL_COUNT=$(( FAIL_COUNT + 1 ))
    fi
}

# assert_not_contains <description> <output> <pattern>
assert_not_contains() {
    local description="$1"
    local output="$2"
    local pattern="$3"
    TESTS_RUN=$(( TESTS_RUN + 1 ))
    if ! echo "$output" | grep -q "$pattern"; then
        printf "${GREEN}  ✓ PASS${RESET}  %s\n" "$description"
        PASS_COUNT=$(( PASS_COUNT + 1 ))
    else
        printf "${RED}  ✗ FAIL${RESET}  %s\n" "$description"
        printf "            Unwanted pattern found: [%s]\n" "$pattern"
        FAIL_COUNT=$(( FAIL_COUNT + 1 ))
    fi
}

# run_notes <args...> — runs notes.sh with the given arguments
# Returns output in $NOTES_OUT and exit code in $NOTES_EXIT
run_notes() {
    set +e
    NOTES_OUT=$(bash "$NOTES_SCRIPT" "$@" 2>&1)
    NOTES_EXIT=$?
    set -e
}

# run_notes_stdin <stdin_data> <args...> — runs notes.sh with piped stdin
run_notes_stdin() {
    local stdin_data="$1"
    shift
    set +e
    NOTES_OUT=$(printf '%s' "$stdin_data" | bash "$NOTES_SCRIPT" "$@" 2>&1)
    NOTES_EXIT=$?
    set -e
}

# run_notes_stdin_eof <args...> — simulates Ctrl+D (empty stdin / immediate EOF)
run_notes_stdin_eof() {
    set +e
    NOTES_OUT=$(bash "$NOTES_SCRIPT" "$@" < /dev/null 2>&1)
    NOTES_EXIT=$?
    set -e
}

# ---------------------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------------------

printf '\n'
printf "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║         NOTES CLI — AUTOMATED TESTS          ║${RESET}\n"
printf "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${RESET}\n"
printf '\n'
printf "Notes dir: %s\n" "$NOTES_DIR"
printf "Script:    %s\n" "$NOTES_SCRIPT"
printf '\n'

# ============================================================
# SUITE 1: DIRECTORY AUTO-CREATION
# ============================================================
printf "${BOLD}[Suite 1] Directory auto-creation${RESET}\n"

# Remove the temp dir to simulate a fresh environment
rmdir "$NOTES_DIR"
assert_pass "Notes dir does not exist yet" "$( [[ ! -d "$NOTES_DIR" ]] && echo true || echo false )"

run_notes list
assert_exit_code "notes list creates missing directory" 0 "$NOTES_EXIT"
assert_pass "Notes dir was auto-created" "$( [[ -d "$NOTES_DIR" ]] && echo true || echo false )"
printf '\n'

# ============================================================
# SUITE 2: notes list / notes help — help screen
# ============================================================
printf "${BOLD}[Suite 2] notes list / notes help${RESET}\n"

run_notes list
assert_exit_code "notes list exits 0" 0 "$NOTES_EXIT"
assert_contains "notes list shows NOTES CLI header" "$NOTES_OUT" "NOTES CLI"
assert_contains "notes list shows 'notes add'" "$NOTES_OUT" "notes add"
assert_contains "notes list shows 'notes delete'" "$NOTES_OUT" "notes delete"
assert_contains "notes list shows 'notes search'" "$NOTES_OUT" "notes search"

run_notes help
assert_exit_code "notes help exits 0" 0 "$NOTES_EXIT"
assert_contains "notes help shows NOTES CLI header" "$NOTES_OUT" "NOTES CLI"
printf '\n'

# ============================================================
# SUITE 3: bare invocation (no args) behaves like notes list
# ============================================================
printf "${BOLD}[Suite 3] Bare invocation${RESET}\n"

run_notes
assert_exit_code "bare notes exits 0" 0 "$NOTES_EXIT"
assert_contains "bare notes shows NOTES CLI header" "$NOTES_OUT" "NOTES CLI"
printf '\n'

# ============================================================
# SUITE 4: notes all — empty state
# ============================================================
printf "${BOLD}[Suite 4] notes all (empty state)${RESET}\n"

run_notes all
assert_exit_code "notes all (empty) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes all (empty) shows 'No notes found'" "$NOTES_OUT" "No notes found"
assert_contains "notes all (empty) suggests first note command" "$NOTES_OUT" "notes add"
assert_not_contains "notes all (empty) does not show broken table" "$NOTES_OUT" "┌"
printf '\n'

# ============================================================
# SUITE 5: notes add — validation errors
# ============================================================
printf "${BOLD}[Suite 5] notes add — validation errors${RESET}\n"

# Empty title (no argument)
run_notes add
assert_exit_code "notes add (no title) exits non-zero" 1 "$NOTES_EXIT"
assert_contains "notes add (no title) shows error" "$NOTES_OUT" "title cannot be empty"
assert_pass "notes add (no title) creates no file" \
    "$( [[ $(find "$NOTES_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ') -eq 0 ]] && echo true || echo false )"

# Empty content (immediate EOF / Ctrl+D)
run_notes_stdin_eof add "Test Empty Content"
assert_exit_code "notes add (empty content) exits non-zero" 1 "$NOTES_EXIT"
assert_contains "notes add (empty content) shows error" "$NOTES_OUT" "content cannot be empty"
assert_pass "notes add (empty content) creates no file" \
    "$( [[ $(find "$NOTES_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ') -eq 0 ]] && echo true || echo false )"
printf '\n'

# ============================================================
# SUITE 6: notes add — successful creation
# ============================================================
printf "${BOLD}[Suite 6] notes add — successful creation${RESET}\n"

# Create first note
run_notes_stdin "DBMS Normalization is the process of organizing a database." \
    add "DBMS Normalization"
assert_exit_code "notes add (first note) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes add shows success message" "$NOTES_OUT" "Note created successfully"
assert_contains "notes add shows ID 001" "$NOTES_OUT" "ID: 001"
assert_contains "notes add shows location" "$NOTES_OUT" "001.md"
assert_pass "note file 001.md was created" \
    "$( [[ -f "$NOTES_DIR/001.md" ]] && echo true || echo false )"

# Verify frontmatter is correct
NOTE_CONTENT=$(cat "$NOTES_DIR/001.md")
assert_contains "001.md has correct id frontmatter" "$NOTE_CONTENT" "id: 001"
assert_contains "001.md has correct title frontmatter" "$NOTE_CONTENT" "title: DBMS Normalization"
assert_contains "001.md has correct created frontmatter" "$NOTE_CONTENT" "created:"
assert_contains "001.md has body content" "$NOTE_CONTENT" "DBMS Normalization is the process"

# Create second note
run_notes_stdin "Python decorators modify the behavior of another function." \
    add "Python Interview"
assert_exit_code "notes add (second note) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes add shows ID 002" "$NOTES_OUT" "ID: 002"
assert_pass "note file 002.md was created" \
    "$( [[ -f "$NOTES_DIR/002.md" ]] && echo true || echo false )"

# Create third note
run_notes_stdin "Git is a distributed version control system." \
    add "Git Basics"
assert_exit_code "notes add (third note) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes add shows ID 003" "$NOTES_OUT" "ID: 003"
printf '\n'

# ============================================================
# SUITE 7: ID padding — view 4 == view 004 equivalence
# ============================================================
printf "${BOLD}[Suite 7] ID padding equivalence${RESET}\n"

# Create a 4th note
run_notes_stdin "SQL JOIN combines rows from two or more tables." \
    add "SQL Joins"
assert_exit_code "notes add (fourth note) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes add shows ID 004" "$NOTES_OUT" "ID: 004"

# View using both padded and unpadded forms
run_notes view 4
assert_exit_code "notes view 4 (unpadded) exits 0" 0 "$NOTES_EXIT"
OUTPUT_UNPADDED="$NOTES_OUT"

run_notes view 004
assert_exit_code "notes view 004 (padded) exits 0" 0 "$NOTES_EXIT"
OUTPUT_PADDED="$NOTES_OUT"

assert_contains "'notes view 4' shows correct title" "$OUTPUT_UNPADDED" "SQL Joins"
assert_contains "'notes view 004' shows correct title" "$OUTPUT_PADDED" "SQL Joins"

# Both outputs should show the same content
STRIPPED_UNPADDED=$(echo "$OUTPUT_UNPADDED" | tr -d ' \t')
STRIPPED_PADDED=$(echo "$OUTPUT_PADDED" | tr -d ' \t')
assert_pass "'notes view 4' and 'notes view 004' produce same output" \
    "$( [[ "$STRIPPED_UNPADDED" == "$STRIPPED_PADDED" ]] && echo true || echo false )"
printf '\n'

# ============================================================
# SUITE 8: notes view
# ============================================================
printf "${BOLD}[Suite 8] notes view${RESET}\n"

run_notes view 1
assert_exit_code "notes view 1 exits 0" 0 "$NOTES_EXIT"
assert_contains "notes view shows ID" "$NOTES_OUT" "ID: 001"
assert_contains "notes view shows Title" "$NOTES_OUT" "Title: DBMS Normalization"
assert_contains "notes view shows Created" "$NOTES_OUT" "Created:"
assert_contains "notes view shows body" "$NOTES_OUT" "DBMS Normalization is the process"
assert_contains "notes view shows separator" "$NOTES_OUT" "━━━"

# View non-existent note
run_notes view 999
assert_exit_code "notes view (non-existent) exits non-zero" 1 "$NOTES_EXIT"
assert_contains "notes view (non-existent) shows error" "$NOTES_OUT" "does not exist"
printf '\n'

# ============================================================
# SUITE 9: notes all — with notes
# ============================================================
printf "${BOLD}[Suite 9] notes all (with notes)${RESET}\n"

run_notes all
assert_exit_code "notes all (with notes) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes all shows table top border" "$NOTES_OUT" "┌"
assert_contains "notes all shows ID header" "$NOTES_OUT" "ID"
assert_contains "notes all shows Title header" "$NOTES_OUT" "Title"
assert_contains "notes all shows Created header" "$NOTES_OUT" "Created"
assert_contains "notes all shows 001" "$NOTES_OUT" "001"
assert_contains "notes all shows DBMS Normalization" "$NOTES_OUT" "DBMS Normalization"
assert_contains "notes all shows 002" "$NOTES_OUT" "002"
assert_contains "notes all shows Python Interview" "$NOTES_OUT" "Python Interview"
assert_contains "notes all shows table bottom border" "$NOTES_OUT" "└"
printf '\n'

# ============================================================
# SUITE 10: notes search
# ============================================================
printf "${BOLD}[Suite 10] notes search${RESET}\n"

# Search for a keyword that appears in multiple notes
run_notes search "Python"
assert_exit_code "notes search (hit) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes search shows 'Search results for'" "$NOTES_OUT" "Search results for: Python"
assert_contains "notes search shows matching note" "$NOTES_OUT" "Python Interview"
assert_contains "notes search shows notes found count" "$NOTES_OUT" "note"

# Case-insensitive search
run_notes search "python"
assert_exit_code "notes search (case-insensitive) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes search (lowercase) finds Python note" "$NOTES_OUT" "Python Interview"

# Search with no results
run_notes search "xyzzy_no_match_12345"
assert_exit_code "notes search (miss) exits 0" 0 "$NOTES_EXIT"
assert_contains "notes search (miss) shows 'No notes found matching'" "$NOTES_OUT" "No notes found matching"

# Search for keyword in body content
run_notes search "distributed version control"
assert_exit_code "notes search body content exits 0" 0 "$NOTES_EXIT"
assert_contains "notes search body content finds Git note" "$NOTES_OUT" "Git Basics"
printf '\n'

# ============================================================
# SUITE 11: notes delete — with confirmation
# ============================================================
printf "${BOLD}[Suite 11] notes delete${RESET}\n"

# Delete with explicit "Y" confirmation
printf 'Y\n' | bash "$NOTES_SCRIPT" delete 3 > /tmp/notes_test_del_out 2>&1
DEL_EXIT=$?
DEL_OUT=$(cat /tmp/notes_test_del_out)
assert_exit_code "notes delete (confirm Y) exits 0" 0 "$DEL_EXIT"
assert_contains "notes delete shows confirmation prompt" "$DEL_OUT" "Are you sure"
assert_contains "notes delete shows title" "$DEL_OUT" "Git Basics"
assert_contains "notes delete shows success" "$DEL_OUT" "Note deleted successfully"
assert_pass "003.md was actually removed" \
    "$( [[ ! -f "$NOTES_DIR/003.md" ]] && echo true || echo false )"

# Delete with "n" cancellation
printf 'n\n' | bash "$NOTES_SCRIPT" delete 2 > /tmp/notes_test_del_out2 2>&1
DEL2_EXIT=$?
DEL2_OUT=$(cat /tmp/notes_test_del_out2)
assert_exit_code "notes delete (cancel n) exits 0" 0 "$DEL2_EXIT"
assert_contains "notes delete (cancel) shows Cancelled" "$DEL2_OUT" "Cancelled"
assert_pass "002.md still exists after cancel" \
    "$( [[ -f "$NOTES_DIR/002.md" ]] && echo true || echo false )"

# Delete a non-existent note
run_notes delete 999
assert_exit_code "notes delete (non-existent) exits non-zero" 1 "$NOTES_EXIT"
assert_contains "notes delete (non-existent) shows error" "$NOTES_OUT" "does not exist"
printf '\n'

# ============================================================
# SUITE 12: ID non-reuse after deletion
# ============================================================
printf "${BOLD}[Suite 12] ID non-reuse after deletion${RESET}\n"

# 003 was deleted in Suite 11. 001, 002, 004 remain.
# The next note should be 005 (max is 4, +1 = 5).
run_notes_stdin "This is the fifth note." add "Fifth Note"
assert_exit_code "notes add after deletion exits 0" 0 "$NOTES_EXIT"
assert_contains "new note gets ID 005 (no reuse of 003)" "$NOTES_OUT" "ID: 005"
assert_pass "005.md was created" \
    "$( [[ -f "$NOTES_DIR/005.md" ]] && echo true || echo false )"
assert_pass "003.md was NOT re-created" \
    "$( [[ ! -f "$NOTES_DIR/003.md" ]] && echo true || echo false )"
printf '\n'

# ============================================================
# SUITE 13: notes edit — existence check
# ============================================================
printf "${BOLD}[Suite 13] notes edit — existence check${RESET}\n"

# Test that edit rejects a non-existent ID
run_notes edit 999
assert_exit_code "notes edit (non-existent) exits non-zero" 1 "$NOTES_EXIT"
assert_contains "notes edit (non-existent) shows error" "$NOTES_OUT" "does not exist"

# Test that edit accepts a valid ID (we can't run the real editor in a test,
# so we override $EDITOR to a no-op command to verify the flow)
EDITOR="true" bash "$NOTES_SCRIPT" edit 1 > /tmp/notes_edit_out 2>&1
EDIT_EXIT=$?
assert_exit_code "notes edit (valid ID, no-op editor) exits 0" 0 "$EDIT_EXIT"
printf '\n'

# ============================================================
# SUITE 14: notes exit
# ============================================================
printf "${BOLD}[Suite 14] notes exit${RESET}\n"

run_notes exit
assert_exit_code "notes exit exits 0" 0 "$NOTES_EXIT"
assert_contains "notes exit shows goodbye" "$NOTES_OUT" "Goodbye"
printf '\n'

# ============================================================
# SUITE 15: Unknown command handling
# ============================================================
printf "${BOLD}[Suite 15] Unknown command${RESET}\n"

run_notes foobar
assert_exit_code "unknown command exits non-zero" 1 "$NOTES_EXIT"
assert_contains "unknown command shows error" "$NOTES_OUT" "Unknown command: foobar"
assert_contains "unknown command references notes list" "$NOTES_OUT" "notes list"

run_notes INVALID_COMMAND_XYZ
assert_exit_code "unknown command (uppercase) exits non-zero" 1 "$NOTES_EXIT"
assert_contains "unknown command (uppercase) shows error" "$NOTES_OUT" "Unknown command"
printf '\n'

# ============================================================
# SUITE 16: Duplicate ID collision prevention
# ============================================================
printf "${BOLD}[Suite 16] Duplicate ID collision prevention${RESET}\n"

# Collect all existing IDs before adding
BEFORE_IDS=$(find "$NOTES_DIR" -name '[0-9][0-9][0-9].md' | sort | xargs -I{} basename {} .md 2>/dev/null | sort)

run_notes_stdin "Collision test note body." add "Collision Test A"
ID_A=$(echo "$NOTES_OUT" | grep "^ID:" | awk '{print $2}')

run_notes_stdin "Collision test note body 2." add "Collision Test B"
ID_B=$(echo "$NOTES_OUT" | grep "^ID:" | awk '{print $2}')

assert_pass "Collision Test A and B have different IDs" \
    "$( [[ "$ID_A" != "$ID_B" ]] && echo true || echo false )"

# All IDs should be unique across all files
ALL_IDS=$(find "$NOTES_DIR" -name '[0-9][0-9][0-9].md' | sort | xargs -I{} basename {} .md 2>/dev/null)
UNIQUE_IDS=$(echo "$ALL_IDS" | sort -u)
ALL_COUNT=$(echo "$ALL_IDS" | wc -l | tr -d ' ')
UNIQUE_COUNT=$(echo "$UNIQUE_IDS" | wc -l | tr -d ' ')
assert_pass "All note IDs are unique (no duplicates)" \
    "$( [[ "$ALL_COUNT" == "$UNIQUE_COUNT" ]] && echo true || echo false )"
printf '\n'

# ============================================================
# SUITE 17: Permission error handling
# ============================================================
printf "${BOLD}[Suite 17] Permission error handling${RESET}\n"

# Create a locked directory to simulate permission failure
LOCKED_DIR=$(mktemp -d)
chmod 000 "$LOCKED_DIR"

# Try to use a sub-dir inside the locked dir as NOTES_DIR
# notes.sh should catch the failure and print a clear error
set +e
NOTES_DIR="$LOCKED_DIR/notes" bash "$NOTES_SCRIPT" list > /tmp/notes_perm_out 2>&1
PERM_EXIT=$?
set -e
PERM_OUT=$(cat /tmp/notes_perm_out)

assert_exit_code "permission error exits non-zero" 1 "$PERM_EXIT"
assert_contains "permission error shows clear message" "$PERM_OUT" "Cannot create notes directory"

# Restore permission so cleanup can proceed
chmod 755 "$LOCKED_DIR"
rmdir "$LOCKED_DIR"
printf '\n'

# ============================================================
# CLEANUP
# ============================================================
rm -rf "$NOTES_DIR" /tmp/notes_test_del_out /tmp/notes_test_del_out2 \
    /tmp/notes_edit_out /tmp/notes_perm_out 2>/dev/null || true

# ============================================================
# FINAL SUMMARY
# ============================================================
printf "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${BOLD}  TEST SUMMARY${RESET}\n"
printf "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "  Total:   %d\n" "$TESTS_RUN"
printf "  ${GREEN}Passed:  %d${RESET}\n" "$PASS_COUNT"
if (( FAIL_COUNT > 0 )); then
    printf "  ${RED}Failed:  %d${RESET}\n" "$FAIL_COUNT"
else
    printf "  Failed:  %d\n" "$FAIL_COUNT"
fi
printf '\n'

if (( FAIL_COUNT == 0 )); then
    printf "${GREEN}${BOLD}  ✓ ALL TESTS PASSED${RESET}\n"
    printf '\n'
    exit 0
else
    printf "${RED}${BOLD}  ✗ SOME TESTS FAILED${RESET}\n"
    printf '\n'
    exit 1
fi
