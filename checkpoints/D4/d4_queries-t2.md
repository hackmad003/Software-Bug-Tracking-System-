# D4: Queries

**Software Bug Tracking System** | CS 480 Database Systems | Due Nov 28, 2026  
**Team:** Michael Nguyen, Ahmad Awaidah, Angelo Mustafa, Dev Patel

15 queries on the D3 schema and data from `queries.sql`. Each query is shown as Task with the D1 requirement it answers, SQL and the first rows of its result. Requirement numbers R1 to R25 refer to D1. The values in the queries such as "more than 5 bugs" are fixed for this report; the web app passes them as parameters.

## Coverage of the required query types

| Query type | Min | Queries |
|---|---|---|
| join of 3 or more tables | 2 | Q1, Q3, Q12 |
| GROUP BY with HAVING | 2 | Q2, Q3, Q13, Q14 |
| subquery or CTE | 2 | Q4, Q7 |
| window function with PARTITION BY | 2 | Q4, Q6 |
| outer join keeping unmatched rows | 1 | Q5, Q13 |
| INSERT / UPDATE / DELETE through a foreign key | 1 | Q8, Q9 |
| CREATE VIEW used by a later query | 1 | Q11, Q12 |
| transaction (START TRANSACTION ... COMMIT) | 1 | Q8, Q9, Q10 |

One query can count for more than one type. Every query was run on the loaded D3 database and the results below are its real output. Queries that change data (Q8, Q9) run inside a transaction and are rolled back, so the data stays as D3 loaded it.

## Queries

### Q1 (R17)


**Task:** List every bug with its project name and each developer assigned to it, with the developer's role.

**SQL**

```sql
SELECT b.bug_id, b.title, p.name AS project, d.name AS developer, a.role
FROM bug b
JOIN project    p ON p.project_id   = b.project_id
JOIN assignment a ON a.bug_id       = b.bug_id
JOIN developer  d ON d.developer_id = a.developer_id
ORDER BY b.bug_id, d.name;
```

**Result**

| bug_id | title | project | developer | role |
|---:|---|---|---|---|
| 1 | Login button misaligned | Atlas Web | Ana Ruiz | Owner |
| 1 | Login button misaligned | Atlas Web | Ben Okoye | Reviewer |
| 2 | Token leak in logs | Beacon Mobile | Ana Ruiz | Owner |
| 3 | Slow search | Atlas Web | Chen Li | Owner |
| 5 | Warehouse transfer returns HTTP 500 for valid requests | Harbor Inventory | Ana Ruiz | Owner |

... (129 rows total, first 5 shown)

### Q2 (R18)


**Task:** Find the projects that contain more than 5 bugs, with their bug counts.

**SQL**

```sql
SELECT p.project_id, p.name, COUNT(*) AS bug_count
FROM project p
JOIN bug b ON b.project_id = p.project_id
GROUP BY p.project_id, p.name
HAVING COUNT(*) > 5
ORDER BY bug_count DESC, p.name;
```

**Result**

| project_id | name | bug_count |
|---:|---|---:|
| 1 | Atlas Web | 9 |
| 2 | Beacon Mobile | 8 |
| 6 | Falcon Payments | 8 |
| 3 | Cobalt API | 7 |
| 5 | Echo Messaging | 6 |

... (6 rows total, first 5 shown)

### Q3 (R19)


**Task:** Find the developers assigned to more than 3 unresolved (Open or In Progress) bugs.

**SQL**

```sql
SELECT d.developer_id, d.name, COUNT(*) AS unresolved_bugs
FROM developer d
JOIN assignment a ON a.developer_id = d.developer_id
JOIN bug        b ON b.bug_id       = a.bug_id
WHERE b.status IN ('Open', 'In Progress')
GROUP BY d.developer_id, d.name
HAVING COUNT(*) > 3
ORDER BY unresolved_bugs DESC, d.name;
```

**Result**

| developer_id | name | unresolved_bugs |
|---:|---|---:|
| 1 | Ana Ruiz | 8 |
| 2 | Ben Okoye | 7 |
| 3 | Chen Li | 4 |
| 4 | Dana Kim | 4 |
| 5 | Elena Petrova | 4 |

... (8 rows total, first 5 shown)

### Q4 (R20)


**Task:** For each project, show its 3 most recently created bugs.

**SQL**

```sql
WITH ranked AS (
    SELECT b.project_id, b.bug_id, b.title, b.created_at,
           ROW_NUMBER() OVER (PARTITION BY b.project_id
                              ORDER BY b.created_at DESC, b.bug_id DESC) AS rn
    FROM bug b
)
SELECT p.name AS project, r.bug_id, r.title, r.created_at, r.rn
FROM ranked r
JOIN project p ON p.project_id = r.project_id
WHERE r.rn <= 3
ORDER BY p.project_id, r.rn;
```

**Result**

| project | bug_id | title | created_at | rn |
|---|---:|---|---|---:|
| Atlas Web | 78 | Login button is misaligned on small screens | 2026-11-10 04:48:07 | 1 |
| Atlas Web | 1 | Login button misaligned | 2026-10-28 09:14:00 | 2 |
| Atlas Web | 3 | Slow search | 2026-10-25 11:05:00 | 3 |
| Beacon Mobile | 4 | Crash on upload | 2026-11-05 13:22:00 | 1 |
| Beacon Mobile | 2 | Token leak in logs | 2026-10-30 16:40:00 | 2 |

... (48 rows total, first 5 shown)

### Q5 (R21)


**Task:** Find the bugs that have never been assigned to any developer.

**SQL**

```sql
SELECT b.bug_id, b.title, b.severity, b.status
FROM bug b
LEFT JOIN assignment a ON a.bug_id = b.bug_id
WHERE a.bug_id IS NULL
ORDER BY b.bug_id;
```

**Result**

| bug_id | title | severity | status |
|---:|---|---|---|
| 4 | Crash on upload | High | Open |
| 42 | Session expiry leaks memory in long sessions | High | Open |
| 43 | Search results page fails intermittently in CI | Medium | Open |
| 50 | Health check fails intermittently in CI | High | Open |
| 53 | Photo upload is misaligned on small screens | Medium | Open |

... (15 rows total, first 5 shown)

### Q6 (R22)


**Task:** Rank the bugs of each project by severity (Critical first); equal severities share a rank.

**SQL**

```sql
SELECT p.name AS project, b.bug_id, b.title, b.severity,
       RANK() OVER (PARTITION BY b.project_id
                    ORDER BY FIELD(b.severity, 'Critical', 'High', 'Medium', 'Low')) AS severity_rank
FROM bug b
JOIN project p ON p.project_id = b.project_id
ORDER BY p.project_id, severity_rank, b.bug_id;
```

**Result**

| project | bug_id | title | severity | severity_rank |
|---|---:|---|---|---:|
| Atlas Web | 59 | Login button leaks memory in long sessions | Critical | 1 |
| Atlas Web | 66 | Profile settings throws an unhandled exception | Critical | 1 |
| Atlas Web | 1 | Login button misaligned | High | 3 |
| Atlas Web | 19 | Session handling crashes when the input is empty | High | 3 |
| Atlas Web | 3 | Slow search | Medium | 5 |

... (83 rows total, first 5 shown)

### Q7 (R19)


**Task:** Find the developers whose unresolved workload is above the average workload of developers who have unresolved bugs.

**SQL**

```sql
SELECT d.developer_id, d.name, w.unresolved_bugs
FROM developer d
JOIN (SELECT a.developer_id, COUNT(*) AS unresolved_bugs
      FROM assignment a
      JOIN bug b ON b.bug_id = a.bug_id
      WHERE b.status IN ('Open', 'In Progress')
      GROUP BY a.developer_id) w ON w.developer_id = d.developer_id
WHERE w.unresolved_bugs > (SELECT AVG(x.n)
                           FROM (SELECT COUNT(*) AS n
                                 FROM assignment a2
                                 JOIN bug b2 ON b2.bug_id = a2.bug_id
                                 WHERE b2.status IN ('Open', 'In Progress')
                                 GROUP BY a2.developer_id) x)
ORDER BY w.unresolved_bugs DESC, d.name;
```

**Result**

| developer_id | name | unresolved_bugs |
|---:|---|---:|
| 1 | Ana Ruiz | 8 |
| 2 | Ben Okoye | 7 |
| 3 | Chen Li | 4 |
| 4 | Dana Kim | 4 |
| 5 | Elena Petrova | 4 |

... (9 rows total, first 5 shown)

### Q8 (R23)


**Task:** Record a new bug for an existing project (INSERT through the project foreign key). Run inside a transaction and rolled back so the data is unchanged.

**SQL**

```sql
START TRANSACTION;

INSERT INTO bug (project_id, title, description, severity)
VALUES (1, 'Dark mode toggle resets after refresh',
        'The theme preference is not saved between sessions.', 'Medium');

SELECT b.bug_id, p.name AS project, b.title, b.severity, b.status, b.created_at
FROM bug b
JOIN project p ON p.project_id = b.project_id
WHERE b.bug_id = LAST_INSERT_ID();

ROLLBACK;
```

*status and created_at come from the column defaults 'Open' and the current time.*

**Result**

| bug_id | project | title | severity | status | created_at |
|---:|---|---|---|---|---|
| 84 | Atlas Web | Dark mode toggle resets after refresh | Medium | Open | 2026-11-22 05:20:39 |

**Error case**

```sql
INSERT INTO bug (project_id, title, severity) VALUES (999, 'Orphan bug', 'Low');
```

```{.text .res style="white-space:pre-wrap;font-size:8.3pt"}
ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails (`bug_tracker`.`bug`, CONSTRAINT `fk_bug_project` FOREIGN KEY (`project_id`) REFERENCES `project` (`project_id`) ON UPDATE CASCADE)
```

*Rejected: project 999 does not exist, so the foreign key fk_bug_project fails, R8: every bug belongs to exactly one project.*


### Q9 (R8, R11)


**Task:** Delete a bug and show what ON DELETE did to its comments, tags and assignments (CASCADE). Rolled back afterwards.

**SQL**

```sql
START TRANSACTION;

SELECT 'before' AS stage,
       (SELECT COUNT(*) FROM comment    WHERE bug_id = 17) AS comments,
       (SELECT COUNT(*) FROM bug_tag    WHERE bug_id = 17) AS tags,
       (SELECT COUNT(*) FROM assignment WHERE bug_id = 17) AS assignments;

DELETE FROM bug WHERE bug_id = 17;

SELECT 'after' AS stage,
       (SELECT COUNT(*) FROM comment    WHERE bug_id = 17) AS comments,
       (SELECT COUNT(*) FROM bug_tag    WHERE bug_id = 17) AS tags,
       (SELECT COUNT(*) FROM assignment WHERE bug_id = 17) AS assignments;

ROLLBACK;
```

**Result**

| stage | comments | tags | assignments |
|---|---:|---:|---:|
| before | 4 | 3 | 3 |

| stage | comments | tags | assignments |
|---|---:|---:|---:|
| after | 0 | 0 | 0 |

**Error case**

```sql
DELETE FROM project WHERE project_id = 1;
```

```{.text .res style="white-space:pre-wrap;font-size:8.3pt"}
ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails (`bug_tracker`.`bug`, CONSTRAINT `fk_bug_project` FOREIGN KEY (`project_id`) REFERENCES `project` (`project_id`) ON UPDATE CASCADE)
```

*Rejected: project 1 still has bugs, so ON DELETE RESTRICT keeps the bug history.*


### Q10 (R24)


**Task:** Transfer bug 10's assignment from developer 2 to developer 11 as a single transaction: the new assignment is inserted and the old one removed together, or neither happens.

**SQL**

```sql
START TRANSACTION;

INSERT INTO assignment (bug_id, developer_id, role)
SELECT bug_id, 11, role
FROM assignment
WHERE bug_id = 10 AND developer_id = 2;

DELETE FROM assignment
WHERE bug_id = 10 AND developer_id = 2;

COMMIT;

SELECT a.bug_id, d.name AS developer, a.role, a.assigned_at
FROM assignment a
JOIN developer d ON d.developer_id = a.developer_id
WHERE a.bug_id = 10;
```

**Result**

| bug_id | developer | role | assigned_at |
|---:|---|---|---|
| 10 | Kenji Tanaka | Owner | 2026-11-22 05:20:39 |

**Restore block** undoes the changes so `queries.sql` can be re-run

```sql
START TRANSACTION;
INSERT INTO assignment (bug_id, developer_id, assigned_at, role)
SELECT bug_id, 2, '2026-08-28 22:37:52', role FROM assignment WHERE bug_id = 10 AND developer_id = 11;
DELETE FROM assignment WHERE bug_id = 10 AND developer_id = 11;
COMMIT;
```

### Q11 (R25)


**Task:** Create a reusable view of unresolved bugs (status Open or In Progress), with the project name.

**SQL**

```sql
CREATE OR REPLACE VIEW unresolved_bugs AS
SELECT b.bug_id, b.project_id, p.name AS project,
       b.title, b.severity, b.status, b.created_at
FROM bug b
JOIN project p ON p.project_id = b.project_id
WHERE b.status IN ('Open', 'In Progress');

SELECT * FROM unresolved_bugs ORDER BY bug_id LIMIT 5;
```

**Result**

| bug_id | project_id | project | title | severity | status | created_at |
|---:|---:|---|---|---|---|---|
| 1 | 1 | Atlas Web | Login button misaligned | High | Open | 2026-10-28 09:14:00 |
| 2 | 2 | Beacon Mobile | Token leak in logs | Critical | In Progress | 2026-10-30 16:40:00 |
| 4 | 2 | Beacon Mobile | Crash on upload | High | Open | 2026-11-05 13:22:00 |
| 5 | 8 | Harbor Inventory | Warehouse transfer returns HTTP 500 for valid requests | Critical | Open | 2026-08-22 10:03:37 |
| 10 | 10 | Juniper CMS | Rich text editor returns HTTP 500 for valid requests | Critical | In Progress | 2026-08-26 06:37:52 |

### Q12 (R25)


**Task:** Using the view: list the unresolved Critical and High bugs with the number of developers on each (0 means nobody is working on it).

**SQL**

```sql
SELECT u.bug_id, u.project, u.title, u.severity,
       COUNT(a.developer_id) AS developers_assigned
FROM unresolved_bugs u
LEFT JOIN assignment a ON a.bug_id = u.bug_id
WHERE u.severity IN ('Critical', 'High')
GROUP BY u.bug_id, u.project, u.title, u.severity
ORDER BY FIELD(u.severity, 'Critical', 'High'), u.bug_id;
```

**Result**

| bug_id | project | title | severity | developers_assigned |
|---:|---|---|---|---:|
| 2 | Beacon Mobile | Token leak in logs | Critical | 1 |
| 5 | Harbor Inventory | Warehouse transfer returns HTTP 500 for valid requests | Critical | 1 |
| 10 | Juniper CMS | Rich text editor returns HTTP 500 for valid requests | Critical | 1 |
| 40 | Granite Auth | Account lockout writes sensitive data to the logs | Critical | 2 |
| 56 | Cobalt API | OAuth token endpoint throws an unhandled exception | Critical | 2 |

... (23 rows total, first 5 shown)

### Q13 (R18)


**Task:** Find the projects that have no bugs at all.

**SQL**

```sql
SELECT p.project_id, p.name, COUNT(b.bug_id) AS bug_count
FROM project p
LEFT JOIN bug b ON b.project_id = p.project_id
GROUP BY p.project_id, p.name
HAVING COUNT(b.bug_id) = 0
ORDER BY p.name;
```

**Result**

| project_id | name | bug_count |
|---:|---|---:|
| 19 | Summit CRM | 0 |
| 20 | Tundra Sync | 0 |

### Q14 (R6, R11)

**Task:** Find the bugs that have more than 2 comments.

**SQL**

```sql
SELECT b.bug_id, b.title, COUNT(c.comment_id) AS comment_count
FROM bug b
JOIN comment c ON c.bug_id = b.bug_id
GROUP BY b.bug_id, b.title
HAVING COUNT(c.comment_id) > 2
ORDER BY comment_count DESC, b.bug_id;
```

**Result**

| bug_id | title | comment_count |
|---:|---|---:|
| 6 | File upload displays the wrong time zone | 4 |
| 9 | Sharing links returns HTTP 500 for valid requests | 4 |
| 15 | Refund flow ignores the saved user preferences | 4 |
| 17 | Filter sidebar is not reachable by keyboard | 4 |
| 22 | Profile settings fails intermittently in CI | 4 |

... (22 rows total, first 5 shown)

### Q15 (R4)

**Task:** Find the most frequently used bug tags.

**SQL**

```sql
SELECT tag, COUNT(bug_id) AS bug_count
FROM bug_tag
GROUP BY tag
ORDER BY bug_count DESC, tag;
```

**Result**

| tag | bug_count |
|---|---:|
| Performance | 26 |
| Backend | 19 |
| Security | 19 |
| UI | 19 |
| Usability | 12 |

... (12 rows total, first 5 shown)
