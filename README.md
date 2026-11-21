# Software Bug Tracking System

CS 480 Database Systems, Term Project (UIC, Fall 2026)

A bug tracker for a software company: projects, the bugs reported in each one (with severity, status and tags), the developers assigned to each bug and in what role, comments, and releases. It is a MySQL 8 database with a lightweight Flask web interface.

**Team:** Michael Nguyen, Ahmad Awaidah, Angelo Mustafa, Dev Patel

## Features

The web app has four pages, each reading from or writing to MySQL live:

| # | Page | What it does |
|---|------|--------------|
| 1 | List | Shows bugs read live from the database |
| 2 | Search / filter | Finds bugs by a typed or picked value using a parameterized query (`WHERE title LIKE %s`) |
| 3 | Report | Runs one of the D4 queries (a join with GROUP BY or a window function) and shows the result as a table |
| 4 | Insert form | Adds a bug (a table with a foreign key) and shows the database's error on a violation instead of crashing |


## Prerequisites

- **MySQL 8.0.16 or newer** (CHECK constraints are enforced from 8.0.16)
- **uv**, the Python package manager. Install it once:
  - Windows (PowerShell): `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"`
  - macOS / Linux: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Python 3.12 or newer (uv downloads it automatically if missing)

## Setup and run
TBD


## Project Structure
```
Software-Bug-Tracking-System-/
├── README.md
├── pyproject.toml
├── uv.lock
├── .python-version
├── .gitignore
├── CLAUDE.md
├── backend/
│   ├── app.py
│   ├── db.py
│   └── templates/
│       ├── base.html
│       ├── bugs.html      1. list page
│       ├── search.html    2. search / filter
│       ├── report.html    3. report (join + GROUP BY or window query)
│       └── new_bug.html   4. insert form
├── checkpoints/
│   ├── D1/
│   │   ├── D1.md
│   │   └── D1_requirements.pdf
│   ├── D2/
│   │   ├── D2.pdf
│   │   ├── D2_design_notes.md
│   │   └── D2_er.pdf
│   ├── D3/
│   │   ├── D3_schema.pdf
│   │   ├── schema.sql
│   │   └── data.sql
│   └── D4/
├── docs/
│   ├── CODING_STYLE.md
│   ├── COMMENT_STYLE.md
│   ├── LIBRARIES.md
│   └── MILESTONES.md
└── reports/
```

| Path | Purpose |
|------|---------|
| `backend/app.py` | Flask routes for the four features |
| `backend/db.py` | Connection and query helper; parameters are always passed separately from the SQL |
| `backend/templates/` | HTML templates that Flask fills with rows from MySQL |
| `checkpoints/D1/` | Requirements (client brief, interview, R-numbered requirements) |
| `checkpoints/D2/` | ER design: diagram and design notes |
| `checkpoints/D3/schema.sql` | Creates the database and all 7 tables (keys, CHECKs, ON DELETE rules, indexes) |
| `checkpoints/D3/data.sql` | Sample data; every foreign key resolves |
| `checkpoints/D3/D3_schema.pdf` | Table list, normalization check and diagram |
| `checkpoints/D4/` | Queries deliverable (in progress) |
| `docs/` | Team conventions: coding and comment style, libraries, milestones |
| `reports/` | Generated reports |

## Database overview

Seven tables: `project`, `developer`, `bug`, `release`, `comment`, `bug_tag` and `assignment`.

- `bug_tag` comes from the multivalued attribute `Bug.{tag}`.
- `assignment` comes from the many-to-many relationship between developers and bugs, with the relationship attributes `assigned_at` and `role`.
- Every bug belongs to exactly one project; every comment has exactly one bug and one author; every release belongs to one project, and a version number is unique only within its project.
- `severity` is one of Low, Medium, High, Critical. `status` is one of Open, In Progress, Resolved. `role` is one of Owner, Reviewer, Tester.

The full table list, normalization check and diagram are in `docs/D3_schema.pdf`.

**Note for writing SQL:** `release` is a reserved word in MySQL 8, so always write it with backticks: `` `release` ``.

## Database Schema

Defined in `checkpoints/D3/schema.sql` (MySQL 8.0.16+, InnoDB, `utf8mb4`). Running it drops and recreates the `bug_tracker` database. Seven tables: five entity sets, plus one table for the multivalued attribute (`bug_tag`) and one for the M:N relationship (`assignment`).

PK = primary key, FK = foreign key, UQ = unique.

### `project` (R1)

| Column | Type | Constraints |
|--------|------|-------------|
| `project_id` | INT | PK, AUTO_INCREMENT |
| `name` | VARCHAR(100) | NOT NULL |
| `description` | TEXT | |

### `developer` (R2)

| Column | Type | Constraints |
|--------|------|-------------|
| `developer_id` | INT | PK, AUTO_INCREMENT |
| `name` | VARCHAR(100) | NOT NULL |
| `email` | VARCHAR(255) | NOT NULL, UQ |

### `bug` (R3, R8, R14, R15)

| Column | Type | Constraints |
|--------|------|-------------|
| `bug_id` | INT | PK, AUTO_INCREMENT |
| `project_id` | INT | NOT NULL, FK → `project` (ON DELETE RESTRICT, ON UPDATE CASCADE) |
| `title` | VARCHAR(200) | NOT NULL |
| `description` | TEXT | |
| `severity` | VARCHAR(10) | NOT NULL, CHECK in (`Low`, `Medium`, `High`, `Critical`) |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT `Open`, CHECK in (`Open`, `In Progress`, `Resolved`) |
| `created_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

### `` `release` `` (R7, R13, R16)

| Column | Type | Constraints |
|--------|------|-------------|
| `release_id` | INT | PK, AUTO_INCREMENT |
| `project_id` | INT | NOT NULL, FK → `project` (ON DELETE CASCADE, ON UPDATE CASCADE) |
| `version` | VARCHAR(30) | NOT NULL |
| `release_date` | DATE | NOT NULL |

UQ (`project_id`, `version`): a version number is unique only within its project.

### `comment` (R6, R11, R12)

| Column | Type | Constraints |
|--------|------|-------------|
| `comment_id` | INT | PK, AUTO_INCREMENT |
| `bug_id` | INT | NOT NULL, FK → `bug` (ON DELETE CASCADE, ON UPDATE CASCADE) |
| `developer_id` | INT | NOT NULL, FK → `developer` (ON DELETE RESTRICT, ON UPDATE CASCADE) |
| `content` | TEXT | NOT NULL |
| `created_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

### `bug_tag` (R4)

| Column | Type | Constraints |
|--------|------|-------------|
| `bug_id` | INT | PK (with `tag`), FK → `bug` (ON DELETE CASCADE, ON UPDATE CASCADE) |
| `tag` | VARCHAR(50) | PK (with `bug_id`) |

The composite PK stops the same tag from appearing twice on one bug. A bug with no tags has no rows here.

### `assignment` (R5, R9, R10)

| Column | Type | Constraints |
|--------|------|-------------|
| `bug_id` | INT | PK (with `developer_id`), FK → `bug` (ON DELETE CASCADE, ON UPDATE CASCADE) |
| `developer_id` | INT | PK (with `bug_id`), FK → `developer` (ON DELETE RESTRICT, ON UPDATE CASCADE) |
| `assigned_at` | DATETIME | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| `role` | VARCHAR(20) | NOT NULL, CHECK in (`Owner`, `Reviewer`, `Tester`) |

The composite PK allows at most one assignment per developer–bug pair (R10).

### Delete rules

| When you delete a... | Effect |
|----------------------|--------|
| `project` | Blocked if it still has bugs; its releases are deleted with it |
| `bug` | Its comments, tags and assignments are deleted with it |
| `developer` | Blocked if they wrote any comment or have any assignment |

### Indexes

| Index | Columns | Supports |
|-------|---------|----------|
| `idx_bug_project_created` | `bug (project_id, created_at)` | Most recent bugs per project |
| `idx_bug_status` | `bug (status)` | Reports by status |
| `idx_assignment_dev` | `assignment (developer_id)` | Developer workload |
| `idx_comment_bug` | `comment (bug_id)` | Loading a bug's comment thread |


## Day-to-day use

- powershell
- uv run python backend/app.py     # runs the app inside the project's .venv
- uv add <package>                 # adds a new dependency
- uv sync                          # teammates run this after cloning