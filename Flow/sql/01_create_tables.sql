-- =====================================================================
-- FLOW | Phase 3 | 01_create_tables.sql
-- Target : MySQL 8.0+ (DBeaver). All data is synthetic.
-- Run    : 1) PART A  2) import the 6 CSVs into stg_* tables (DBeaver wizard)
--          3) PART B (typed tables + load from staging)
-- Design : stg_* = raw CSV text, untouched (audit trail)
--          raw_* = typed copies with primary keys and documented foreign keys
-- =====================================================================

-- ===== PART A: database and staging tables ===========================
CREATE DATABASE IF NOT EXISTS flow_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE flow_db;

DROP TABLE IF EXISTS stg_applications;
CREATE TABLE stg_applications (
  application_id VARCHAR(30), customer_id VARCHAR(30), created_at VARCHAR(30),
  application_type VARCHAR(60), segment VARCHAR(30), source_channel VARCHAR(40),
  complexity_band VARCHAR(20), priority VARCHAR(20), final_status VARCHAR(30),
  completed_at VARCHAR(30), closed_at VARCHAR(30), cancellation_reason VARCHAR(80));

DROP TABLE IF EXISTS stg_stage_history;
CREATE TABLE stg_stage_history (
  stage_event_id VARCHAR(30), application_id VARCHAR(30), stage_name VARCHAR(60),
  entered_at VARCHAR(30), exited_at VARCHAR(30), status VARCHAR(30),
  owner_id VARCHAR(30), exit_reason VARCHAR(60));

DROP TABLE IF EXISTS stg_tasks;
CREATE TABLE stg_tasks (
  task_id VARCHAR(30), application_id VARCHAR(30), task_type VARCHAR(80),
  created_at VARCHAR(30), assigned_at VARCHAR(30), due_at VARCHAR(30),
  completed_at VARCHAR(30), owner_id VARCHAR(30), task_status VARCHAR(30),
  blocked_reason VARCHAR(80));

DROP TABLE IF EXISTS stg_owners;
CREATE TABLE stg_owners (
  owner_id VARCHAR(30), team VARCHAR(40), role VARCHAR(80), active_from VARCHAR(30),
  active_to VARCHAR(30), monthly_capacity_hours VARCHAR(30), cost_per_hour VARCHAR(30),
  FTE_fraction VARCHAR(30));

DROP TABLE IF EXISTS stg_rework_events;
CREATE TABLE stg_rework_events (
  rework_event_id VARCHAR(30), application_id VARCHAR(30), stage_name VARCHAR(60),
  event_at VARCHAR(30), reason_code VARCHAR(80), source_team VARCHAR(40),
  receiving_team VARCHAR(40), estimated_minutes VARCHAR(30), resolution_status VARCHAR(30));

DROP TABLE IF EXISTS stg_calendar;
CREATE TABLE stg_calendar (
  date_key VARCHAR(30), calendar_date VARCHAR(30), weekday VARCHAR(30),
  month VARCHAR(30), holiday_flag VARCHAR(30), working_day_flag VARCHAR(30));

-- >>> NOW IMPORT THE 6 CSV FILES INTO THE stg_* TABLES (see the DBeaver steps) <<<

-- PRE-CHECK: run this before PART B. Expected rows: 2711 / 18332 / 21363 / 31 / 604 / 426
SELECT 'stg_applications' AS staging_table, COUNT(*) AS rows_loaded, 2711 AS expected FROM stg_applications
UNION ALL SELECT 'stg_stage_history', COUNT(*), 18332 FROM stg_stage_history
UNION ALL SELECT 'stg_tasks', COUNT(*), 21363 FROM stg_tasks
UNION ALL SELECT 'stg_owners', COUNT(*), 31 FROM stg_owners
UNION ALL SELECT 'stg_rework_events', COUNT(*), 604 FROM stg_rework_events
UNION ALL SELECT 'stg_calendar', COUNT(*), 426 FROM stg_calendar;

-- ===== PART B: typed raw tables + load from staging ==================
USE flow_db;

DROP TABLE IF EXISTS raw_rework_events;
DROP TABLE IF EXISTS raw_tasks;
DROP TABLE IF EXISTS raw_stage_history;
DROP TABLE IF EXISTS raw_applications;
DROP TABLE IF EXISTS raw_owners;
DROP TABLE IF EXISTS raw_calendar;

CREATE TABLE raw_owners (
  owner_id VARCHAR(10) NOT NULL,
  team VARCHAR(30) NOT NULL,
  role VARCHAR(60) NOT NULL,
  active_from DATE NOT NULL,
  active_to DATE NULL,
  monthly_capacity_hours INT NOT NULL,
  cost_per_hour INT NOT NULL,
  FTE_fraction DECIMAL(3,2) NOT NULL,
  PRIMARY KEY (owner_id));

CREATE TABLE raw_applications (
  application_id VARCHAR(20) NOT NULL,
  customer_id VARCHAR(20) NOT NULL,
  created_at DATETIME NOT NULL,
  application_type VARCHAR(40) NOT NULL,
  segment VARCHAR(20) NOT NULL,
  source_channel VARCHAR(30) NOT NULL,
  complexity_band VARCHAR(10) NOT NULL,
  priority VARCHAR(10) NOT NULL,
  final_status VARCHAR(20) NOT NULL,
  completed_at DATETIME NULL,
  closed_at DATETIME NULL,
  cancellation_reason VARCHAR(60) NULL,
  PRIMARY KEY (application_id),
  INDEX idx_app_created (created_at));

CREATE TABLE raw_stage_history (
  stage_event_id VARCHAR(20) NOT NULL,
  application_id VARCHAR(20) NOT NULL,
  stage_name VARCHAR(40) NOT NULL,
  entered_at DATETIME NOT NULL,
  exited_at DATETIME NULL,
  status VARCHAR(20) NOT NULL,
  owner_id VARCHAR(10) NULL,
  exit_reason VARCHAR(40) NULL,
  PRIMARY KEY (stage_event_id),
  INDEX idx_sh_app_stage (application_id, stage_name, entered_at),
  CONSTRAINT fk_sh_app FOREIGN KEY (application_id) REFERENCES raw_applications (application_id),
  CONSTRAINT fk_sh_owner FOREIGN KEY (owner_id) REFERENCES raw_owners (owner_id));

CREATE TABLE raw_tasks (
  task_id VARCHAR(20) NOT NULL,
  application_id VARCHAR(20) NOT NULL,
  task_type VARCHAR(60) NOT NULL,
  created_at DATETIME NOT NULL,
  assigned_at DATETIME NULL,
  due_at DATETIME NOT NULL,
  completed_at DATETIME NULL,
  owner_id VARCHAR(10) NULL,
  task_status VARCHAR(20) NOT NULL,
  blocked_reason VARCHAR(60) NULL,
  PRIMARY KEY (task_id),
  INDEX idx_tk_app_created (application_id, created_at),
  CONSTRAINT fk_tk_app FOREIGN KEY (application_id) REFERENCES raw_applications (application_id),
  CONSTRAINT fk_tk_owner FOREIGN KEY (owner_id) REFERENCES raw_owners (owner_id));

-- No foreign key on application_id here on purpose: the data contains
-- intentional orphan rows (quality issue Q12) that profiling must detect.
CREATE TABLE raw_rework_events (
  rework_event_id VARCHAR(20) NOT NULL,
  application_id VARCHAR(20) NOT NULL,
  stage_name VARCHAR(40) NOT NULL,
  event_at DATETIME NOT NULL,
  reason_code VARCHAR(60) NOT NULL,
  source_team VARCHAR(30) NOT NULL,
  receiving_team VARCHAR(30) NOT NULL,
  estimated_minutes INT NOT NULL,
  resolution_status VARCHAR(20) NOT NULL,
  PRIMARY KEY (rework_event_id),
  INDEX idx_rw_app (application_id));

CREATE TABLE raw_calendar (
  date_key INT NOT NULL,
  calendar_date DATE NOT NULL,
  weekday VARCHAR(12) NOT NULL,
  month CHAR(7) NOT NULL,
  holiday_flag TINYINT NOT NULL,
  working_day_flag TINYINT NOT NULL,
  PRIMARY KEY (date_key),
  UNIQUE KEY uq_cal_date (calendar_date));

-- Load order respects foreign keys. NULLIF/TRIM turns empty CSV cells into NULL.
INSERT INTO raw_owners
SELECT TRIM(owner_id), TRIM(team), TRIM(role), CAST(TRIM(active_from) AS DATE),
       CAST(NULLIF(TRIM(active_to), '') AS DATE), CAST(TRIM(monthly_capacity_hours) AS SIGNED),
       CAST(TRIM(cost_per_hour) AS SIGNED), CAST(TRIM(FTE_fraction) AS DECIMAL(3,2))
FROM stg_owners;

INSERT INTO raw_applications
SELECT TRIM(application_id), TRIM(customer_id), CAST(TRIM(created_at) AS DATETIME),
       TRIM(application_type), TRIM(segment), TRIM(source_channel), TRIM(complexity_band),
       TRIM(priority), TRIM(final_status), CAST(NULLIF(TRIM(completed_at), '') AS DATETIME),
       CAST(NULLIF(TRIM(closed_at), '') AS DATETIME), NULLIF(TRIM(cancellation_reason), '')
FROM stg_applications;

INSERT INTO raw_stage_history
SELECT TRIM(stage_event_id), TRIM(application_id), TRIM(stage_name), CAST(TRIM(entered_at) AS DATETIME),
       CAST(NULLIF(TRIM(exited_at), '') AS DATETIME), TRIM(status),
       NULLIF(TRIM(owner_id), ''), NULLIF(TRIM(exit_reason), '')
FROM stg_stage_history;

INSERT INTO raw_tasks
SELECT TRIM(task_id), TRIM(application_id), TRIM(task_type), CAST(TRIM(created_at) AS DATETIME),
       CAST(NULLIF(TRIM(assigned_at), '') AS DATETIME), CAST(TRIM(due_at) AS DATETIME),
       CAST(NULLIF(TRIM(completed_at), '') AS DATETIME), NULLIF(TRIM(owner_id), ''),
       TRIM(task_status), NULLIF(TRIM(blocked_reason), '')
FROM stg_tasks;

INSERT INTO raw_rework_events
SELECT TRIM(rework_event_id), TRIM(application_id), TRIM(stage_name), CAST(TRIM(event_at) AS DATETIME),
       TRIM(reason_code), TRIM(source_team), TRIM(receiving_team),
       CAST(TRIM(estimated_minutes) AS SIGNED), TRIM(resolution_status)
FROM stg_rework_events;

INSERT INTO raw_calendar
SELECT CAST(TRIM(date_key) AS SIGNED), CAST(TRIM(calendar_date) AS DATE), TRIM(weekday), TRIM(month),
       CAST(TRIM(holiday_flag) AS SIGNED), CAST(TRIM(working_day_flag) AS SIGNED)
FROM stg_calendar;

-- Quick check: staging and typed row counts should match
SELECT 'applications' AS tbl, (SELECT COUNT(*) FROM stg_applications) AS stg_rows, (SELECT COUNT(*) FROM raw_applications) AS raw_rows
UNION ALL SELECT 'stage_history', (SELECT COUNT(*) FROM stg_stage_history), (SELECT COUNT(*) FROM raw_stage_history)
UNION ALL SELECT 'tasks', (SELECT COUNT(*) FROM stg_tasks), (SELECT COUNT(*) FROM raw_tasks)
UNION ALL SELECT 'owners', (SELECT COUNT(*) FROM stg_owners), (SELECT COUNT(*) FROM raw_owners)
UNION ALL SELECT 'rework_events', (SELECT COUNT(*) FROM stg_rework_events), (SELECT COUNT(*) FROM raw_rework_events)
UNION ALL SELECT 'calendar', (SELECT COUNT(*) FROM stg_calendar), (SELECT COUNT(*) FROM raw_calendar);