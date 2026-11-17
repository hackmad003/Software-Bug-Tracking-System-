# D2 Design Notes: Software Bug Tracking System

Diagram: `D2_er.drawio` (crow's foot). 5 entity sets (Project, Developer, Bug, Comment, Release), 5 relationship sets, 1 multivalued attribute (Bug.tag), 2 relationship attributes (assigned_at, role).

## 1. Relationships

| Relationship | Entities | Cardinality | Participation | Requirements |
|---|---|---|---|---|
| contains | Project - Bug | 1:N | Bug total (exactly one project); Project partial | R8 |
| has | Project - Release | 1:N | Release total (exactly one project); Project partial | R13, R16 |
| has | Bug - Comment | 1:N | Comment total (exactly one bug); Bug partial | R11 |
| writes | Developer - Comment | 1:N | Comment total (exactly one author); Developer partial | R12 |
| assigned_to (assigned_at, role) | Developer - Bug | M:N | Partial on both sides (a bug may be unassigned) | R5, R9, R10 |


## 2. Design decisions

1. **Assignment is a relationship, not an entity.** A developer-bug assignment has no identity apart from the pair it connects, and its only data (assigned_at, role) describes that pair. Drawing it as a diamond with attributes is the standard M:N pattern and becomes a junction table in D3. The role values are Owner, Reviewer, Tester.
2. **Tag is a multivalued attribute, not an entity.** R4 treats a tag as a plain label with no attributes of its own and no requirement that queries tags independently. It becomes a bug_tag(bug_id, tag) table in D3. Trade-off is a typo creates a new tag; if tags later need descriptions or a fixed list, promote tag to an entity.
3. **Numeric surrogate keys everywhere.** Names, titles and emails can change or repeat, and a release version is only unique within a project (R16), so each entity gets its own ID. Release keeps (project, version) as a unique constraint.

## 3. Sample instance

**Project**: (1, Atlas Web), (2, Beacon Mobile), (3, Cobalt API)

**Developer**: (1, Ana Ruiz, ana@co.com), (2, Ben Okoye, ben@co.com), (3, Chen Li, chen@co.com), (4, Dana Kim, dana@co.com)

**Bug** (id, title, severity, status, project): (1, Login button misaligned, High, Open, 1), (2, Token leak in logs, Critical, In Progress, 2), (3, Slow search, Medium, Resolved, 1), (4, Crash on upload, High, Open, 2)

**assigned_to** (developer, bug, assigned_at, role): (1, 1, 2026-11-02, Owner), (2, 1, 2026-11-03, Reviewer), (1, 2, 2026-11-04, Owner), (3, 3, 2026-11-01, Owner)

**tag** (bug, tag): (1, UI), (2, Security), (2, Performance), (3, Performance)

**Comment** (id, bug, developer, text): (1, 1, 2, "Reproduced on Safari"), (2, 1, 1, "Fix in review"), (3, 2, 3, "Rotating keys"), (4, 3, 1, "Index added")

**Release** (id, project, version, date): (1, 1, 1.0, 2026-09-15), (2, 1, 1.1, 2026-10-20), (3, 2, 1.0, 2026-10-01)

**Check against every cardinality:**
- Bug-Project (1:N, Bug total): every bug has exactly one project (1, 2, 1, 2). Project 3 has no bugs, which is allowed.
- Release-Project (1:N, Release total): every release has exactly one project. Project 1 has two releases, Project 3 has none. Version 1.0 appears under Projects 1 and 2, which R16 allows, and no project repeats a version.
- Comment-Bug and Comment-Developer (1:N, Comment total): every comment has exactly one bug and one author. Bug 4 has no comments and Developer 4 wrote none, which is allowed. Developer 1 wrote two.
- assigned_to (M:N): Bug 1 has two developers (1, 2) and Developer 1 has two bugs (1, 2), so both directions are many. Bug 4 has no developer and Developer 4 has no bugs, which is allowed. No developer-bug pair repeats (R10), and every role is in the allowed set.
- tag (multivalued): Bug 2 has two tags, Bug 4 has none.
- Value constraints: all severities and statuses are in the allowed sets, and all emails are distinct.
