-- =====================================================================
-- CS 480 Term Project, D3: Software Bug Tracking System
-- schema.sql  (MySQL 8.0.16+; CHECK constraints are enforced)
-- Team: Michael Nguyen, Ahmad Awaidah, Angelo Mustafa, Dev Patel
--
-- Run:  mysql -u <user> -p < schema.sql
--       mysql -u <user> -p < data.sql
-- Re-runnable: drops and recreates the bug_tracker database.
--
-- 7 tables = 5 entity sets + 1 multivalued attribute (bug_tag)
--                           + 1 M:N relationship (assignment)
-- =====================================================================

DROP DATABASE IF EXISTS bug_tracker;
CREATE DATABASE bug_tracker CHARACTER SET utf8mb4;
USE bug_tracker;

-- ---------------------------------------------------------------------
-- Entity: Project                                              (R1)
-- ---------------------------------------------------------------------
CREATE TABLE project (
    project_id   INT           NOT NULL AUTO_INCREMENT,
    name         VARCHAR(100)  NOT NULL,
    description  TEXT,
    PRIMARY KEY (project_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entity: Developer                                            (R2)
-- email is unique: two developers cannot share an address.
-- ---------------------------------------------------------------------
CREATE TABLE developer (
    developer_id  INT           NOT NULL AUTO_INCREMENT,
    name          VARCHAR(100)  NOT NULL,
    email         VARCHAR(255)  NOT NULL,
    PRIMARY KEY (developer_id),
    CONSTRAINT uq_developer_email UNIQUE (email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entity: Bug                                       (R3, R8, R14, R15)
-- project 1:N bug. project_id is NOT NULL because a bug belongs to
-- EXACTLY ONE project (total participation, R8).
-- ON DELETE RESTRICT: a project that still has bugs cannot be deleted,
--   so bug history is never silently destroyed (interview A12).
-- ---------------------------------------------------------------------
CREATE TABLE bug (
    bug_id       INT           NOT NULL AUTO_INCREMENT,
    project_id   INT           NOT NULL,
    title        VARCHAR(200)  NOT NULL,
    description  TEXT,
    severity     VARCHAR(10)   NOT NULL,
    status       VARCHAR(20)   NOT NULL DEFAULT 'Open',
    created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (bug_id),
    CONSTRAINT fk_bug_project
        FOREIGN KEY (project_id) REFERENCES project (project_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_bug_severity
        CHECK (severity IN ('Low', 'Medium', 'High', 'Critical')),
    CONSTRAINT chk_bug_status
        CHECK (status IN ('Open', 'In Progress', 'Resolved'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entity: Release                                  (R7, R13, R16)
-- project 1:N release. A version is unique only WITHIN a project
-- (R16), so the unique key is (project_id, version), not version alone.
-- ON DELETE CASCADE: a release has no meaning without its project.
-- ---------------------------------------------------------------------
CREATE TABLE `release` (
    release_id    INT          NOT NULL AUTO_INCREMENT,
    project_id    INT          NOT NULL,
    version       VARCHAR(30)  NOT NULL,
    release_date  DATE         NOT NULL,
    PRIMARY KEY (release_id),
    CONSTRAINT uq_release_project_version UNIQUE (project_id, version),
    CONSTRAINT fk_release_project
        FOREIGN KEY (project_id) REFERENCES project (project_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Entity: Comment                                  (R6, R11, R12)
-- bug 1:N comment and developer 1:N comment. Both FKs are NOT NULL
-- (every comment has exactly one bug and exactly one author).
-- bug      -> CASCADE : deleting a bug deletes its comment thread.
-- developer-> RESTRICT: a developer who wrote comments cannot be deleted.
-- ---------------------------------------------------------------------
CREATE TABLE comment (
    comment_id    INT       NOT NULL AUTO_INCREMENT,
    bug_id        INT       NOT NULL,
    developer_id  INT       NOT NULL,
    content       TEXT      NOT NULL,
    created_at    DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (comment_id),
    CONSTRAINT fk_comment_bug
        FOREIGN KEY (bug_id) REFERENCES bug (bug_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_comment_developer
        FOREIGN KEY (developer_id) REFERENCES developer (developer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Multivalued attribute Bug.{tag}  ->  +1 table                 (R4)
-- PK (bug_id, tag) forbids the same tag twice on one bug.
-- A bug with zero tags simply has no rows here.
-- ---------------------------------------------------------------------
CREATE TABLE bug_tag (
    bug_id  INT          NOT NULL,
    tag     VARCHAR(50)  NOT NULL,
    PRIMARY KEY (bug_id, tag),
    CONSTRAINT fk_bug_tag_bug
        FOREIGN KEY (bug_id) REFERENCES bug (bug_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- M:N relationship assigned_to (Developer - Bug)  ->  +1 table
--                                                    (R5, R9, R10)
-- Relationship attributes assigned_at and role become columns here.
-- PK (bug_id, developer_id): at most one assignment per pair (R10).
-- bug      -> CASCADE : assignments go away with a deleted bug.
-- developer-> RESTRICT: assignment history keeps its developer (A12).
-- ---------------------------------------------------------------------
CREATE TABLE assignment (
    bug_id        INT          NOT NULL,
    developer_id  INT          NOT NULL,
    assigned_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    role          VARCHAR(20)  NOT NULL,
    PRIMARY KEY (bug_id, developer_id),
    CONSTRAINT fk_assignment_bug
        FOREIGN KEY (bug_id) REFERENCES bug (bug_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_assignment_developer
        FOREIGN KEY (developer_id) REFERENCES developer (developer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_assignment_role
        CHECK (role IN ('Owner', 'Reviewer', 'Tester'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Secondary indexes for the D4/D5 access paths (reports by status,
-- "most recent bugs per project", developer workload).
-- ---------------------------------------------------------------------
CREATE INDEX idx_bug_project_created ON bug (project_id, created_at);
CREATE INDEX idx_bug_status          ON bug (status);
CREATE INDEX idx_assignment_dev      ON assignment (developer_id);
CREATE INDEX idx_comment_bug         ON comment (bug_id);
