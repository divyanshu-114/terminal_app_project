# Notes CLI

A lightweight, fast command-line note-taking tool for macOS. Notes CLI lets you create, view, edit, search, and delete plain-text notes directly from your terminal — no GUI, no cloud sync, no dependencies. Each note is a Markdown file with YAML-style frontmatter stored locally in `~/Desktop/Notes/`, making them easy to browse, back up, or version-control manually.

---

## Requirements

- **macOS** (tested on macOS Ventura and later)
- **Bash** 3.2+ (included with every macOS installation)
- No external dependencies — uses only standard BSD tools: `bash`, `date`, `mkdir`, `cat`, `grep`, `sed`, `find`, `rm`, `nano`

---

## Installation

### Step 1 — Clone or download

```bash
git clone <repo-url>
cd notes-cli
```

### Step 2 — Make the script executable

```bash
chmod +x notes.sh
```

### Step 3 (Optional) — Add to your PATH

To run `notes` from anywhere without typing the full path, move or symlink the script onto your `$PATH`:

```bash
# Option A: Copy to /usr/local/bin
cp notes.sh /usr/local/bin/notes
chmod +x /usr/local/bin/notes

# Option B: Symlink (stays in sync if you edit notes.sh)
ln -s "$(pwd)/notes.sh" /usr/local/bin/notes
```

Verify it's available:

```bash
notes list
```

---

## Storage

All notes are saved in: `~/Desktop/Notes/`

Each note is a separate `.md` file with a 3-digit zero-padded sequential ID:

```
~/Desktop/Notes/
├── 001.md
├── 002.md
└── 004.md
```

Note IDs are **never reused** or renumbered after deletion. If `002.md` is deleted, the next new note receives the next highest unused ID.

**Note file format:**

```markdown
---
id: 004
title: Python Interview
created: 2026-09-20
---

Python decorators are functions that
modify the behavior of another function.
```

---

## Command Reference

### `notes list`
Show the help screen listing all available commands.

```bash
notes list
```

### `notes help`
Identical to `notes list`.

```bash
notes help
```

### `notes add "<title>"`
Create a new note. After running the command, type your note content and press **Ctrl+D** when finished.

```bash
notes add "Python Interview Tips"
```

- The title argument is required and must be non-empty.
- The body content must be non-empty; pressing Ctrl+D immediately will abort without creating a file.

**Example output:**
```
Creating new note...

Title: Python Interview Tips

Enter your note.
Press Ctrl+D when finished.

[you type your content here, then press Ctrl+D]

✓ Note created successfully.

ID: 005
Location: ~/Desktop/Notes/005.md
```

### `notes view <id>`
Display a single note. The ID can be given with or without leading zeros (`notes view 4` and `notes view 004` are equivalent).

```bash
notes view 4
notes view 004
```

**Example output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ID: 004
Title: Python Interview Tips
Created: 20 Sep 2026

Python decorators are functions that
modify the behavior of another function.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### `notes all`
Show a formatted table of all saved notes, sorted by ID.

```bash
notes all
```

**Example output:**
```
┌─────┬─────────────────────────┬──────────────┐
│ ID  │ Title                   │ Created      │
├─────┼─────────────────────────┼──────────────┤
│ 001 │ DBMS Normalization      │ 20 Sep 2026  │
│ 002 │ Python Interview        │ 20 Sep 2026  │
└─────┴─────────────────────────┴──────────────┘
```

If no notes exist:
```
No notes found.

Create your first note using:

    notes add "My First Note"
```

### `notes edit <id>`
Open a note in your preferred terminal editor. The editor is determined by the `$EDITOR` environment variable; if not set, defaults to **nano**.

```bash
notes edit 3
EDITOR=vim notes edit 3
```

### `notes delete <id>`
Delete a note after asking for confirmation.

```bash
notes delete 3
```

**Example interaction:**
```
Are you sure you want to delete:

Git Basics

[Y/n] Y
✓ Note deleted successfully.
```

- Press Enter (or type `Y`/`y`) to confirm.
- Type anything else to cancel without deleting.

### `notes search <keyword>`
Case-insensitive search across both the title and full body content of every note.

```bash
notes search python
notes search "version control"
```

**Example output:**
```
Search results for: python

[002] Python Interview
[007] Python Functions

2 notes found.
```

### `notes exit`
Print a goodbye message and exit. (See [Known Limitations](#known-limitations) for why this command exists.)

```bash
notes exit
```

### Unknown commands

Any unrecognized command prints a helpful error:

```
❌ Unknown command: foo

Run:

    notes list

to see all available commands.
```

---

## Example Complete Workflow

```bash
# Create a couple of notes
notes add "DBMS Normalization"
# [type: Database normalization organizes data to reduce redundancy.]
# [Ctrl+D]

notes add "Python Interview"
# [type: Python decorators modify the behavior of another function.]
# [Ctrl+D]

# See the help screen
notes list

# View all notes as a table
notes all

# View a specific note
notes view 1

# Search across notes
notes search python

# Edit a note in your preferred editor
notes edit 2

# Delete a note
notes delete 1

# Exit gracefully
notes exit
```

---

## Running Tests

The test suite uses a temporary directory and never touches your real `~/Desktop/Notes/`.

```bash
bash test/test.sh
```

You should see output like:

```
  ✓ PASS  Notes dir was auto-created
  ✓ PASS  notes list shows NOTES CLI header
  ...
  ✓ ALL TESTS PASSED
```

---

## Known Limitations

1. **Not a REPL.** Notes CLI is not an interactive shell session. Every command is a separate shell invocation (e.g. `notes add "..."`, `notes view 3`). The `notes exit` command exists as a graceful signal but simply prints a goodbye message and exits the current invocation — it does not terminate a running session because there is no persistent session to terminate.

2. **`edit` does not protect frontmatter fields.** When you run `notes edit <id>`, the raw file is opened in your editor. If you accidentally modify the `id:` or `created:` fields inside the frontmatter, Notes CLI will read those modified values on subsequent `view` or `all` commands. Always leave the frontmatter intact. This is a known v1 limitation.

3. **No concurrency protection.** If two terminal windows run `notes add` simultaneously, there is a small window where both could compute the same next ID and create a collision. For personal single-user use this is extremely unlikely to matter, but be aware if scripting bulk imports.

---

## Planned Future Features

The following features are **not implemented** in v1 but are planned for future releases:

- **Tags & categories** — Organize notes with searchable `#tags` or category fields in frontmatter
- **Colors** — Color-coded output by category or tag
- **Archive** — Move notes to an archive folder without permanently deleting them
- **Favorites** — Mark notes as favorites and filter by favorites in `notes all`
- **Custom sorting** — Sort `notes all` by title, date created, or last modified
- **Fuzzy search** — Approximate matching so typos still find the right note
- **Export / Import** — Export notes to a `.zip` or import from another Notes CLI installation
- **Statistics** — `notes stats` command showing total notes, words, categories
- **Auto-backup** — Automatic periodic backup of the notes directory
- **Undo delete** — Trash-based delete with a recovery window before permanent removal
- **Encryption** — Optional password-protected notes using `openssl`
- **Git sync** — Automatic `git commit` + `git push` after each write operation for cloud backup
