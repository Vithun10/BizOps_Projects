-- =====================================================================
-- FLOW | Phase 3 | 02_profile_and_quality_checks.sql
-- Purpose: profile the raw tables and DETECT the data-quality problems.
-- Nothing is changed here. Run each query separately (Ctrl+Enter) to read
-- the results, or run the whole script (Alt+X) and review each result tab.
-- NOTE: the database collation is case-insensitive, so queries that must see
--       case differences use COLLATE utf8mb4_bin.
-- =====================================================================
USE flow_db;

-- 2.1 Row counts (compare with generation_summary.txt)
SELECT 'applications' AS tbl, COUNT(*) AS row_count FROM raw_applications
UNION ALL SELECT 'stage_history', COUNT(*) FROM raw_stage_history
UNION ALL SELECT 'tasks', COUNT(*) FROM raw_tasks
UNION ALL SELECT 'owners', COUNT(*) FROM raw_owners
UNION ALL SELECT 'rework_events', COUNT(*) FROM raw_rework_events
UNION ALL SELECT 'calendar', COUNT(*) FROM raw_calendar;

-- 2.2 Duplicate primary keys (checked on staging, because raw_* enforce the keys)
SELECT 'applications' AS tbl, COUNT(*) AS duplicated_keys FROM (SELECT application_id FROM stg_applications GROUP BY application_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'stage_history', COUNT(*) FROM (SELECT stage_event_id FROM stg_stage_history GROUP BY stage_event_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'tasks', COUNT(*) FROM (SELECT task_id FROM stg_tasks GROUP BY task_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'owners', COUNT(*) FROM (SELECT owner_id FROM stg_owners GROUP BY owner_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'rework_events', COUNT(*) FROM (SELECT rework_event_id FROM stg_rework_events GROUP BY rework_event_id HAVING COUNT(*) > 1) d
UNION ALL SELECT 'calendar', COUNT(*) FROM (SELECT date_key FROM stg_calendar GROUP BY date_key HAVING COUNT(*) > 1) d;

-- 2.3 Null profile of the columns that may legitimately be empty
SELECT 'applications' AS tbl, 'completed_at' AS col, SUM(completed_at IS NULL) AS null_rows, COUNT(*) AS total_rows FROM raw_applications
UNION ALL SELECT 'applications', 'closed_at', SUM(closed_at IS NULL), COUNT(*) FROM raw_applications
UNION ALL SELECT 'applications', 'cancellation_reason', SUM(cancellation_reason IS NULL), COUNT(*) FROM raw_applications
UNION ALL SELECT 'stage_history', 'exited_at', SUM(exited_at IS NULL), COUNT(*) FROM raw_stage_history
UNION ALL SELECT 'stage_history', 'owner_id', SUM(owner_id IS NULL), COUNT(*) FROM raw_stage_history
UNION ALL SELECT 'stage_history', 'exit_reason', SUM(exit_reason IS NULL), COUNT(*) FROM raw_stage_history
UNION ALL SELECT 'tasks', 'assigned_at', SUM(assigned_at IS NULL), COUNT(*) FROM raw_tasks
UNION ALL SELECT 'tasks', 'completed_at', SUM(completed_at IS NULL), COUNT(*) FROM raw_tasks
UNION ALL SELECT 'tasks', 'owner_id', SUM(owner_id IS NULL), COUNT(*) FROM raw_tasks
UNION ALL SELECT 'tasks', 'blocked_reason', SUM(blocked_reason IS NULL), COUNT(*) FROM raw_tasks
UNION ALL SELECT 'owners', 'active_to', SUM(active_to IS NULL), COUNT(*) FROM raw_owners;

-- 2.4 Allowed-value checks (case-sensitive): every distinct value with its row count
SELECT 'applications.final_status' AS col, val, COUNT(*) AS n FROM (SELECT final_status COLLATE utf8mb4_bin AS val FROM raw_applications) t GROUP BY val
UNION ALL SELECT 'applications.application_type', val, COUNT(*) FROM (SELECT application_type COLLATE utf8mb4_bin AS val FROM raw_applications) t GROUP BY val
UNION ALL SELECT 'applications.complexity_band', val, COUNT(*) FROM (SELECT complexity_band COLLATE utf8mb4_bin AS val FROM raw_applications) t GROUP BY val
UNION ALL SELECT 'stage_history.stage_name', val, COUNT(*) FROM (SELECT stage_name COLLATE utf8mb4_bin AS val FROM raw_stage_history) t GROUP BY val
UNION ALL SELECT 'stage_history.status', val, COUNT(*) FROM (SELECT status COLLATE utf8mb4_bin AS val FROM raw_stage_history) t GROUP BY val
UNION ALL SELECT 'stage_history.exit_reason', val, COUNT(*) FROM (SELECT COALESCE(exit_reason, '(null)') COLLATE utf8mb4_bin AS val FROM raw_stage_history) t GROUP BY val
UNION ALL SELECT 'tasks.task_status', val, COUNT(*) FROM (SELECT task_status COLLATE utf8mb4_bin AS val FROM raw_tasks) t GROUP BY val
UNION ALL SELECT 'rework_events.reason_code', val, COUNT(*) FROM (SELECT reason_code COLLATE utf8mb4_bin AS val FROM raw_rework_events) t GROUP BY val
UNION ALL SELECT 'rework_events.resolution_status', val, COUNT(*) FROM (SELECT resolution_status COLLATE utf8mb4_bin AS val FROM raw_rework_events) t GROUP BY val
ORDER BY col, val;

-- 2.5 Invalid status values in applications (anything outside Completed / Cancelled / Open)
SELECT val AS final_status, COUNT(*) AS rows_affected
FROM (SELECT final_status COLLATE utf8mb4_bin AS val FROM raw_applications) t
WHERE val NOT IN ('Completed', 'Cancelled', 'Open')
GROUP BY val;

-- 2.6 Negative durations: stage exited before it was entered
SELECT COUNT(*) AS negative_duration_rows FROM raw_stage_history WHERE exited_at < entered_at;
SELECT stage_event_id, application_id, stage_name, entered_at, exited_at
FROM raw_stage_history WHERE exited_at < entered_at ORDER BY stage_event_id LIMIT 10;

-- 2.7 Timestamp sequence violations
-- (a) completed applications with no completed_at
SELECT COUNT(*) AS completed_missing_completed_at
FROM raw_applications
WHERE LOWER(TRIM(final_status)) IN ('completed', 'complete') AND completed_at IS NULL;

-- (b) completed_at earlier than the last stage exit
SELECT COUNT(*) AS completed_before_last_stage_exit
FROM raw_applications a
JOIN (SELECT application_id, MAX(GREATEST(entered_at, exited_at)) AS last_stage_ts
      FROM raw_stage_history WHERE exited_at IS NOT NULL GROUP BY application_id) l
  ON l.application_id = a.application_id
WHERE a.completed_at IS NOT NULL AND a.completed_at < l.last_stage_ts;

-- (c) stage entered before the application was created
SELECT COUNT(*) AS stage_entered_before_application_created
FROM raw_stage_history s JOIN raw_applications a ON a.application_id = s.application_id
WHERE s.entered_at < a.created_at;

-- (d) closed_at consistent with status (Completed/Cancelled need it, Open must not have it)
SELECT SUM(LOWER(TRIM(final_status)) IN ('completed', 'complete', 'cancelled', 'canceled') AND closed_at IS NULL) AS closed_status_without_closed_at,
       SUM(LOWER(TRIM(final_status)) = 'open' AND closed_at IS NOT NULL) AS open_with_closed_at
FROM raw_applications;

-- (e) task timestamp problems
SELECT SUM(completed_at IS NOT NULL AND assigned_at IS NULL) AS finished_task_missing_assigned_at,
       SUM(due_at < created_at) AS due_before_created,
       SUM(assigned_at < created_at) AS assigned_before_created,
       SUM(completed_at < assigned_at) AS completed_before_assigned
FROM raw_tasks;

-- 2.8 Owner problems on stage entries
-- owner missing on a stage that was worked, and owner present while still queued
SELECT SUM(owner_id IS NULL AND status <> 'Queued') AS worked_stage_missing_owner,
       SUM(owner_id IS NOT NULL AND status = 'Queued') AS queued_stage_with_owner
FROM raw_stage_history;

-- 2.9 Duplicate-looking stage rows (same application, stage, entered_at, exited_at)
SELECT COUNT(*) AS duplicate_groups, COALESCE(SUM(cnt - 1), 0) AS extra_rows
FROM (SELECT COUNT(*) AS cnt FROM raw_stage_history
      GROUP BY application_id, stage_name, entered_at, exited_at HAVING COUNT(*) > 1) d;

-- 2.10 Orphans and rework problems
SELECT COUNT(*) AS rework_orphan_rows
FROM raw_rework_events r LEFT JOIN raw_applications a ON a.application_id = r.application_id
WHERE a.application_id IS NULL;

SELECT SUM(reason_code COLLATE utf8mb4_bin <> CONCAT(UPPER(LEFT(reason_code, 1)), LOWER(SUBSTRING(reason_code, 2)))) AS reason_code_case_variants,
       SUM(estimated_minutes = 0) AS zero_minutes,
       SUM(resolution_status = 'Invalid') AS invalid_resolution_status
FROM raw_rework_events;

-- 2.11 SUMMARY: injected problems (from generation_summary.txt) vs detected
SELECT q_id, issue, injected, detected,
       CASE WHEN detected = injected THEN 'MATCH'
            WHEN detected > injected THEN 'MORE THAN INJECTED' ELSE 'FEWER THAN INJECTED' END AS result
FROM (
  SELECT 'Q1' AS q_id, 'stage_history: exited_at earlier than entered_at' AS issue, 55 AS injected,
         (SELECT COUNT(*) FROM raw_stage_history WHERE exited_at < entered_at) AS detected
  UNION ALL SELECT 'Q2', 'stage_history: missing owner_id on a worked stage', 91,
         (SELECT COUNT(*) FROM raw_stage_history WHERE owner_id IS NULL AND status <> 'Queued')
  UNION ALL SELECT 'Q3', 'stage_history: duplicate-looking rows', 55,
         (SELECT COALESCE(SUM(cnt - 1), 0) FROM (SELECT COUNT(*) AS cnt FROM raw_stage_history
                GROUP BY application_id, stage_name, entered_at, exited_at HAVING COUNT(*) > 1) d)
  UNION ALL SELECT 'Q4', 'applications: invalid final_status text', 8,
         (SELECT COUNT(*) FROM raw_applications WHERE final_status COLLATE utf8mb4_bin NOT IN ('Completed', 'Cancelled', 'Open'))
  UNION ALL SELECT 'Q5', 'applications: Completed but completed_at missing', 6,
         (SELECT COUNT(*) FROM raw_applications WHERE LOWER(TRIM(final_status)) IN ('completed', 'complete') AND completed_at IS NULL)
  UNION ALL SELECT 'Q6', 'applications: completed_at earlier than last stage exit', 5,
         (SELECT COUNT(*) FROM raw_applications a
          JOIN (SELECT application_id, MAX(GREATEST(entered_at, exited_at)) AS last_stage_ts
                FROM raw_stage_history WHERE exited_at IS NOT NULL GROUP BY application_id) l
            ON l.application_id = a.application_id
          WHERE a.completed_at IS NOT NULL AND a.completed_at < l.last_stage_ts)
  UNION ALL SELECT 'Q7', 'tasks: finished task (has completed_at) with missing assigned_at', 214,
         (SELECT COUNT(*) FROM raw_tasks WHERE completed_at IS NOT NULL AND assigned_at IS NULL)
  UNION ALL SELECT 'Q8', 'tasks: due_at earlier than created_at', 107,
         (SELECT COUNT(*) FROM raw_tasks WHERE due_at < created_at)
  UNION ALL SELECT 'Q9', 'rework_events: reason_code in inconsistent case', 12,
         (SELECT COUNT(*) FROM raw_rework_events
          WHERE reason_code COLLATE utf8mb4_bin <> CONCAT(UPPER(LEFT(reason_code, 1)), LOWER(SUBSTRING(reason_code, 2))))
  UNION ALL SELECT 'Q10', 'rework_events: estimated_minutes = 0', 18,
         (SELECT COUNT(*) FROM raw_rework_events WHERE estimated_minutes = 0)
  UNION ALL SELECT 'Q11', 'rework_events: resolution_status = Invalid', 12,
         (SELECT COUNT(*) FROM raw_rework_events WHERE resolution_status = 'Invalid')
  UNION ALL SELECT 'Q12', 'rework_events: orphan application_id', 3,
         (SELECT COUNT(*) FROM raw_rework_events r LEFT JOIN raw_applications a ON a.application_id = r.application_id
          WHERE a.application_id IS NULL)
) x
ORDER BY CAST(SUBSTRING(q_id, 2) AS UNSIGNED);