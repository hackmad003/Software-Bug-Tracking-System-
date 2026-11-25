-- =====================================================================
-- CS 480 Term Project, D4: Software Bug Tracking System
-- queries.sql  (MySQL 8.0.16+; run AFTER schema.sql and data.sql)
-- Team: Michael Nguyen, Ahmad Awaidah, Angelo Mustafa, Dev Patel
--
-- Run:  mysql -u <user> -p bug_tracker < queries.sql
-- 13 queries. Each one answers a numbered requirement from D1 (R17-R25,
-- plus R8, R11, R18, R19 for the variants). Queries that change data run
-- inside a transaction and ROLLBACK so the sample data is left unchanged;
-- =====================================================================

USE bug_tracker;

-- ---------------------------------------------------------------------
-- Q1 (R17): List every bug with its project name and each developer assigned to it, with the developer's role.
-- ---------------------------------------------------------------------
SELECT b.bug_id, b.title, p.name AS project, d.name AS developer, a.role
FROM bug b
JOIN project    p ON p.project_id   = b.project_id
JOIN assignment a ON a.bug_id       = b.bug_id
JOIN developer  d ON d.developer_id = a.developer_id
ORDER BY b.bug_id, d.name;

-- ---------------------------------------------------------------------
-- Q2 (R18): Find the projects that contain more than 5 bugs, with their bug counts.
-- ---------------------------------------------------------------------
SELECT p.project_id, p.name, COUNT(*) AS bug_count
FROM project p
JOIN bug b ON b.project_id = p.project_id
GROUP BY p.project_id, p.name
HAVING COUNT(*) > 5
ORDER BY bug_count DESC, p.name;

-- ---------------------------------------------------------------------
-- Q3 (R19): Find the developers assigned to more than 3 unresolved (open or in progress) bugs.
-- ---------------------------------------------------------------------
SELECT d.developer_id, d.name, COUNT(*) AS unresolved_bugs
FROM developer d
JOIN assignment a ON a.developer_id = d.developer_id
JOIN bug        b ON b.bug_id       = a.bug_id
WHERE b.status IN ('Open', 'In Progress')
GROUP BY d.developer_id, d.name
HAVING COUNT(*) > 3
ORDER BY unresolved_bugs DESC, d.name;

-- ---------------------------------------------------------------------
-- Q4 (R20): For each project, show its 3 most recently created bugs.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Q5 (R21): Find the bugs that have never been assigned to any developer.
-- ---------------------------------------------------------------------
SELECT b.bug_id, b.title, b.severity, b.status
FROM bug b
LEFT JOIN assignment a ON a.bug_id = b.bug_id
WHERE a.bug_id IS NULL
ORDER BY b.bug_id;

-- ---------------------------------------------------------------------
-- Q6 (R22): Rank the bugs of each project by severity (Critical first); equal severities share a rank.
-- ---------------------------------------------------------------------
SELECT p.name AS project, b.bug_id, b.title, b.severity,
       RANK() OVER (PARTITION BY b.project_id
                    ORDER BY FIELD(b.severity, 'Critical', 'High', 'Medium', 'Low')) AS severity_rank
FROM bug b
JOIN project p ON p.project_id = b.project_id
ORDER BY p.project_id, severity_rank, b.bug_id;

-- ---------------------------------------------------------------------
-- Q7 (R19): Find the developers whose unresolved workload is above the average workload of developers who have unresolved bugs.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Q8 (R23): Record a new bug for an existing project (INSERT through the project foreign key). Run inside a transaction and rolled back so the data is unchanged.
-- ---------------------------------------------------------------------
START TRANSACTION;

INSERT INTO bug (project_id, title, description, severity)
VALUES (1, 'Dark mode toggle resets after refresh',
        'The theme preference is not saved between sessions.', 'Medium');

SELECT b.bug_id, p.name AS project, b.title, b.severity, b.status, b.created_at
FROM bug b
JOIN project p ON p.project_id = b.project_id
WHERE b.bug_id = LAST_INSERT_ID();

ROLLBACK;

-- Not executed (would fail):
-- INSERT INTO bug (project_id, title, severity) VALUES (999, 'Orphan bug', 'Low');
-- Rejected: project 999 does not exist, so the foreign key fk_bug_project fails (R8: every bug belongs to exactly one project).

-- ---------------------------------------------------------------------
-- Q9 (R8, R11): Delete a bug and show what ON DELETE did to its comments, tags and assignments (CASCADE). Rolled back afterwards.
-- ---------------------------------------------------------------------
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

-- Deleting a project that still has bugs is blocked by ON DELETE RESTRICT:
-- DELETE FROM project WHERE project_id = 1;
-- Rejected: project 1 still has bugs, so ON DELETE RESTRICT keeps the bug history.

-- ---------------------------------------------------------------------
-- Q10 (R24): Transfer bug 10's assignment from developer 2 to developer 11 as a single transaction: the new assignment is inserted and the old one removed together, or neither happens.
-- ---------------------------------------------------------------------
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

-- Restore block (undoes Q10 so this file can be re-run; original date kept):
START TRANSACTION;
INSERT INTO assignment (bug_id, developer_id, assigned_at, role)
SELECT bug_id, 2, '2026-08-28 22:37:52', role FROM assignment WHERE bug_id = 10 AND developer_id = 11;
DELETE FROM assignment WHERE bug_id = 10 AND developer_id = 11;
COMMIT;

-- ---------------------------------------------------------------------
-- Q11 (R25): Create a reusable view of unresolved bugs (status open or in progress), with the project name.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW unresolved_bugs AS
SELECT b.bug_id, b.project_id, p.name AS project,
       b.title, b.severity, b.status, b.created_at
FROM bug b
JOIN project p ON p.project_id = b.project_id
WHERE b.status IN ('Open', 'In Progress');

SELECT * FROM unresolved_bugs ORDER BY bug_id LIMIT 5;

-- ---------------------------------------------------------------------
-- Q12 (R25): Using the view: list the unresolved Critical and High bugs with the number of developers on each (0 means nobody is working on it).
-- ---------------------------------------------------------------------
SELECT u.bug_id, u.project, u.title, u.severity,
       COUNT(a.developer_id) AS developers_assigned
FROM unresolved_bugs u
LEFT JOIN assignment a ON a.bug_id = u.bug_id
WHERE u.severity IN ('Critical', 'High')
GROUP BY u.bug_id, u.project, u.title, u.severity
ORDER BY FIELD(u.severity, 'Critical', 'High'), u.bug_id;

-- ---------------------------------------------------------------------
-- Q13 (R18): Find the projects that have no bugs at all.
-- ---------------------------------------------------------------------
SELECT p.project_id, p.name, COUNT(b.bug_id) AS bug_count
FROM project p
LEFT JOIN bug b ON b.project_id = p.project_id
GROUP BY p.project_id, p.name
HAVING COUNT(b.bug_id) = 0
ORDER BY p.name;

-- ---------------------------------------------------------------------
-- Q14: Find bugs that have more than 2 comments.
-- ---------------------------------------------------------------------
SELECT b.bug_id, b.title, COUNT(c.comment_id) AS comment_count
FROM bug b
JOIN comment c ON c.bug_id = b.bug_id
GROUP BY b.bug_id, b.title
HAVING COUNT(c.comment_id) > 2
ORDER BY comment_count DESC, b.bug_id;

-- ---------------------------------------------------------------------
-- Q15: Find the most frequently used bug tags.
-- ---------------------------------------------------------------------
SELECT tag, COUNT(bug_id) AS bug_count
FROM bug_tag
GROUP BY tag
ORDER BY bug_count DESC, tag;
