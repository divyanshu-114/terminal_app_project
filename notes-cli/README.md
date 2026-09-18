# Notes CLI (`divyanshu-notes`)

A lightweight, fast, terminal-first note-taking tool for macOS. **Notes CLI** lets you create, view, edit, search, and delete plain-text Markdown notes directly from your terminal — zero GUI overhead, zero cloud lock-in, zero complex dependencies. 

Each note is saved as a Markdown file with YAML frontmatter locally in `~/Desktop/Notes/`, making your notes transparent, human-readable, and easily backable or version-controlled.

[![npm version](https://img.shields.io/npm/v/divyanshu-notes.svg?color=blue)](https://www.npmjs.com/package/divyanshu-notes)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](https://apple.com)

---

## 🚀 Quick Start (Installation)

### Option 1: Install Globally via npm (Recommended)

Anyone on macOS with Node.js/npm installed can install `divyanshu-notes` with a single command:

```bash
npm install -g divyanshu-notes
```

Now `notes` is available everywhere in your terminal:

```bash
notes list
```

---

### Option 2: Run via `npx` (No installation needed)

Run any command instantly without installing anything permanently:

```bash
npx divyanshu-notes add "Quick Thought"
npx divyanshu-notes all
```

---

### Option 3: Manual Clone & Installation

If you prefer to run directly from source without npm:

```bash
# 1. Clone the repository
git clone https://github.com/divyanshu-114/terminal_app_project.git
cd terminal_app_project/notes-cli

# 2. Make the script executable
chmod +x notes.sh

# 3. Symlink to /usr/local/bin for global access
sudo ln -s "$(pwd)/notes.sh" /usr/local/bin/notes
```

---

## 📂 Storage & Format

All notes live locally in: **`~/Desktop/Notes/`**

- If the directory doesn't exist, it is created automatically before any command runs.
- Notes are saved as 3-digit zero-padded Markdown files: `001.md`, `002.md`, `003.md`, etc.
- **Sequential IDs are never reused or renumbered after deletion.** If `002.md` is deleted, the next created note receives the next highest unused ID (e.g., `004.md`).

### Note File Structure (YAML Frontmatter + Body)

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

## 📖 Command Reference

### 1. `notes list` (or `notes help` / bare `notes`)
Displays the formatted help screen showing all available commands.

```bash
notes list
```

**Output:**
```text
╔══════════════════════════════════════════╗
║              NOTES CLI                   ║
╚══════════════════════════════════════════╝

Available Commands:

notes list
    Show all available commands

notes add <title>
    Create a new note

notes view <id>
    View a note

notes edit <id>
    Edit an existing note

notes delete <id>
    Delete a note

notes search <keyword>
    Search notes

notes all
    Show all saved notes

notes help
    Show help information

notes exit
    Exit the application
```

---

### 2. `notes add "<title>"`
Create a new note. Requires a non-empty title. Type your note content on stdin and press **Ctrl+D** when finished.

```bash
notes add "Python Decorators"
```

**Output:**
```text
Creating new note...

Title: Python Decorators

Enter your note.
Press Ctrl+D when finished.

[Type your note content here and press Ctrl+D]

✓ Note created successfully.

ID: 001
Location: ~/Desktop/Notes/001.md
```

- **Empty titles or empty body contents are rejected** — no empty file will be created.

---

### 3. `notes view <id>`
Displays the formatted content of a note. Accepts IDs with or without leading zeros (`notes view 1` and `notes view 001` both work).

```bash
notes view 1
notes view 001
```

**Output:**
```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ID: 001
Title: Python Decorators
Created: 20 Sep 2026

Python decorators are functions that modify the behavior of another function.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### 4. `notes all`
Displays a neatly formatted, border-aligned table listing all saved notes sorted numerically by ID.

```bash
notes all
```

**Output:**
```text
┌─────┬─────────────────────────┬──────────────┐
│ ID  │ Title                   │ Created      │
├─────┼─────────────────────────┼──────────────┤
│ 001 │ Python Decorators       │ 20 Sep 2026  │
│ 002 │ DBMS Normalization      │ 20 Sep 2026  │
└─────┴─────────────────────────┴──────────────┘
```

- Long titles are automatically truncated so table borders remain clean.
- If no notes exist, a friendly empty-state prompt is shown.

---

### 5. `notes edit <id>`
Opens the note file directly in your preferred text editor. Respects the `$EDITOR` environment variable (defaults to `nano`).

```bash
notes edit 1
EDITOR=vim notes edit 1
```

---

### 6. `notes delete <id>`
Prompts for confirmation before permanently deleting a note.

```bash
notes delete 1
```

**Output:**
```text
Are you sure you want to delete:

Python Decorators

[Y/n] y
✓ Note deleted successfully.
```

- Accepts `Y`, `y`, or hitting Enter to confirm deletion.
- Any other input cancels the operation without deleting the file.

---

### 7. `notes search <keyword>`
Performs a case-insensitive substring search across both titles and body text of all notes.

```bash
notes search decorators
```

**Output:**
```text
Search results for: decorators

[001] Python Decorators

1 note found.
```

---

### 8. `notes exit`
Gracefully prints a goodbye message indicating where your notes are stored and exits clean.

```bash
notes exit
```

**Output:**
```text
Goodbye! Your notes are safe in /Users/divyanshuraj/Desktop/Notes
```

---

## ⚡ Complete Workflow Example

```bash
# 1. Create a couple of notes
notes add "DBMS Normalization"
# [Type: Database normalization organizes fields and tables to reduce redundancy.]
# [Press Ctrl+D]

notes add "Python Tips"
# [Type: Use list comprehensions for concise array building.]
# [Press Ctrl+D]

# 2. View all notes table
notes all

# 3. View note 001
notes view 1

# 4. Search notes for a term
notes search "redundancy"

# 5. Edit a note
notes edit 2

# 6. Delete a note
notes delete 1
```

---

## 🧪 Automated Testing

The repository comes with a comprehensive Bash automated test suite (99 assertions across 17 test suites) that uses a temporary mock directory so your real notes are never touched.

Run tests using npm:

```bash
npm test
```

Or execute directly:

```bash
bash test/test.sh
```

---

## ⚠️ Known Limitations

1. **Not an interactive REPL:** Each command runs as an independent shell invocation.
2. **Frontmatter Edits:** Running `notes edit <id>` opens the raw Markdown file. Users should avoid altering the YAML frontmatter headers manually.
3. **Concurrency:** Notes CLI is designed for single-user interactive desktop use; simultaneous background writes from multiple scripts could compute identical IDs.

---

## 🔮 Planned Future Features

- **Tags & Categories** — `#tag` support and category filtering
- **Colors** — ANSI colorized terminal themes for `all` and `view`
- **Archive** — Soft-delete archive folder before permanent removal
- **Favorites** — Pin important notes to top of `notes all`
- **Export / Import** — Backup notes into a `.zip` archive or sync to Git

---

## 📄 License

MIT License © [divyanshu-114](https://github.com/divyanshu-114)
