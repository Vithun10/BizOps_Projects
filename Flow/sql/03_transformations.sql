-- =====================================================================
-- FLOW | Phase 3 | 03_transformations.sql
-- Purpose: cleaned, flagged views. Raw tables are never modified.
-- Rules (see data_quality_report.md): problems are FLAGGED, not silently fixed.
-- Run the whole script once (Alt+X). Views can be re-created safely.
-- =====================================================================
USE flow_db;

-- 3.1 Parameters (cutoff, period start, SLA) - change here only, before analysis
CREATE OR REPLACE VIEW v_params AS
SELECT CAST('2025-10-01 00:00:00' AS DATETIME) AS period_start,
       CAST('2026-09-30 23:59:59' AS DATETIME) AS cutoff,
       35 AS sla_calendar_days;

-- 3.2 Calendar with a running working-day number (for working-day durations)
CREATE OR REPLACE VIEW v_calendar_wd AS
SELECT calendar_date, month AS ym, working_day_flag,
       SUM(working_day_flag) OVER (ORDER BY calendar_date) AS wd_no
FROM raw_calendar;

-- 3.3 Applications: standard status, quality flags, cycle-time validity
CREATE OR REPLACE VIEW v_applications_clean AS
WITH base AS (
  SELECT a.*,
         CASE LOWER(TRIM(a.final_status))
              WHEN 'completed' THEN 'Completed' WHEN 'complete' THEN 'Completed'
              WHEN 'cancelled' THEN 'Cancelled' WHEN 'canceled' THEN 'Cancelled'
              WHEN 'open' THEN 'Open' ELSE 'INVALID' END AS status_std
  FROM raw_applications a
),
last_exit AS (
  SELECT application_id, MAX(GREATEST(entered_at, exited_at)) AS last_stage_ts
  FROM raw_stage_history
  WHERE exited_at IS NOT NULL
  GROUP BY application_id
),
flagged AS (
  SELECT b.*, l.last_stage_ts,
         CASE WHEN b.final_status COLLATE utf8mb4_bin <> b.status_std THEN 1 ELSE 0 END AS flag_status_variant,
         CASE WHEN b.status_std = 'Completed' AND b.completed_at IS NULL THEN 1 ELSE 0 END AS flag_missing_completed_at,
         CASE WHEN b.status_std = 'Completed' AND b.completed_at IS NOT NULL
                   AND b.completed_at < l.last_stage_ts THEN 1 ELSE 0 END AS flag_completed_before_last_exit
  FROM base b
  LEFT JOIN last_exit l ON l.application_id = b.application_id
)
SELECT f.application_id, f.customer_id, f.created_at, DATE_FORMAT(f.created_at, '%Y-%m') AS created_month,
       f.application_type, f.segment, f.source_channel, f.complexity_band, f.priority,
       f.status_std, f.completed_at, f.closed_at, f.cancellation_reason,
       f.flag_status_variant, f.flag_missing_completed_at, f.flag_completed_before_last_exit,
       CASE WHEN f.status_std = 'Completed' AND f.flag_completed_before_last_exit = 0 THEN 1 ELSE 0 END AS cycle_time_valid,
       CASE WHEN f.status_std = 'Completed' THEN COALESCE(f.completed_at, f.closed_at) END AS cycle_end_at
FROM flagged f;

-- 3.4 Completed applications with a valid cycle time (calendar and working days, SLA flag)
CREATE OR REPLACE VIEW v_completed_cycle AS
SELECT a.application_id, a.application_type, a.complexity_band, a.segment, a.priority, a.created_month,
       DATE_FORMAT(a.cycle_end_at, '%Y-%m') AS completed_month,
       TIMESTAMPDIFF(SECOND, a.created_at, a.cycle_end_at) / 86400.0 AS cal_days,
       ce.wd_no - cs.wd_no AS wd_days,
       CASE WHEN TIMESTAMPDIFF(SECOND, a.created_at, a.cycle_end_at) / 86400.0 <= p.sla_calendar_days THEN 1 ELSE 0 END AS sla_met
FROM v_applications_clean a
JOIN v_calendar_wd cs ON cs.calendar_date = DATE(a.created_at)
JOIN v_calendar_wd ce ON ce.calendar_date = DATE(a.cycle_end_at)
CROSS JOIN v_params p
WHERE a.cycle_time_valid = 1;

-- 3.5 Stage episodes: duplicates removed, flags, queue and elapsed time, re-entry marker
CREATE OR REPLACE VIEW v_stage_episodes AS
WITH ranked AS (
  SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.application_id, s.stage_name, s.entered_at, s.exited_at
                                 ORDER BY s.stage_event_id) AS dup_rn
  FROM raw_stage_history s
),
dedup AS (
  SELECT * FROM ranked WHERE dup_rn = 1
),
pickup AS (
  SELECT application_id, created_at, MIN(assigned_at) AS first_assigned_at
  FROM raw_tasks
  GROUP BY application_id, created_at
),
numbered AS (
  SELECT d.*, ROW_NUMBER() OVER (PARTITION BY d.application_id, d.stage_name
                                 ORDER BY d.entered_at, d.stage_event_id) AS visit_no
  FROM dedup d
)
SELECT n.stage_event_id, n.application_id, n.stage_name,
       CASE n.stage_name WHEN 'Intake & Submission' THEN 1 WHEN 'Handoff Acceptance' THEN 2
            WHEN 'Contract & Legal Review' THEN 3 WHEN 'Finance Approval' THEN 4
            WHEN 'Implementation Setup' THEN 5 WHEN 'Go-live Readiness' THEN 6
            WHEN 'Activation Handoff' THEN 7 END AS stage_no,
       CASE n.stage_name WHEN 'Intake & Submission' THEN 'Sales' WHEN 'Handoff Acceptance' THEN 'RevOps'
            WHEN 'Contract & Legal Review' THEN 'Legal' WHEN 'Finance Approval' THEN 'Finance'
            WHEN 'Implementation Setup' THEN 'Implementation' WHEN 'Go-live Readiness' THEN 'Implementation'
            WHEN 'Activation Handoff' THEN 'Customer Success' END AS stage_team,
       n.entered_at, n.exited_at, n.status, n.owner_id, n.exit_reason, n.visit_no,
       CASE WHEN n.visit_no > 1 THEN 1 ELSE 0 END AS is_reentry,
       CASE WHEN n.exited_at IS NOT NULL AND n.exited_at < n.entered_at THEN 1 ELSE 0 END AS flag_negative_duration,
       CASE WHEN n.owner_id IS NULL AND n.status <> 'Queued' THEN 1 ELSE 0 END AS flag_missing_owner,
       p.first_assigned_at,
       CASE WHEN n.exited_at IS NOT NULL AND n.exited_at >= n.entered_at
            THEN TIMESTAMPDIFF(SECOND, n.entered_at, n.exited_at) / 86400.0 END AS elapsed_days,
       CASE WHEN p.first_assigned_at IS NOT NULL AND p.first_assigned_at >= n.entered_at
                 AND NOT (n.exited_at IS NOT NULL AND n.exited_at < n.entered_at)
            THEN TIMESTAMPDIFF(SECOND, n.entered_at, p.first_assigned_at) / 86400.0 END AS queue_days,
       DATE_FORMAT(n.entered_at, '%Y-%m') AS entered_month,
       a.application_type, a.complexity_band
FROM numbered n
LEFT JOIN pickup p ON p.application_id = n.application_id AND p.created_at = n.entered_at
JOIN raw_applications a ON a.application_id = n.application_id;

-- 3.6 Task performance: queue time, in-progress time, overdue flag
CREATE OR REPLACE VIEW v_task_performance AS
WITH t AS (
  SELECT k.*, a.application_type, a.complexity_band,
         CASE WHEN k.completed_at IS NOT NULL AND k.assigned_at IS NULL THEN 1 ELSE 0 END AS flag_assigned_missing,
         CASE WHEN k.due_at < k.created_at THEN 1 ELSE 0 END AS flag_due_invalid
  FROM raw_tasks k
  JOIN raw_applications a ON a.application_id = k.application_id
)
SELECT t.task_id, t.application_id, t.task_type, t.created_at, t.assigned_at, t.due_at, t.completed_at,
       t.owner_id, t.task_status, t.blocked_reason, t.application_type, t.complexity_band,
       t.flag_assigned_missing, t.flag_due_invalid,
       DATE_FORMAT(t.created_at, '%Y-%m') AS created_month,
       CASE WHEN t.assigned_at IS NOT NULL THEN TIMESTAMPDIFF(SECOND, t.created_at, t.assigned_at) / 86400.0 END AS queue_days,
       CASE WHEN t.assigned_at IS NOT NULL AND t.completed_at IS NOT NULL
            THEN TIMESTAMPDIFF(SECOND, t.assigned_at, t.completed_at) / 86400.0 END AS in_progress_days,
       CASE WHEN t.flag_due_invalid = 1 THEN NULL
            WHEN t.completed_at IS NOT NULL THEN CASE WHEN t.completed_at > t.due_at THEN 1 ELSE 0 END
            WHEN p.cutoff > t.due_at THEN 1 ELSE 0 END AS overdue_flag
FROM t
CROSS JOIN v_params p;

-- 3.7 Rework events: standard reason text, handoff label, qualifying flag
CREATE OR REPLACE VIEW v_rework_clean AS
SELECT r.rework_event_id, r.application_id, r.stage_name, r.event_at,
       CONCAT(UPPER(LEFT(TRIM(r.reason_code), 1)), LOWER(SUBSTRING(TRIM(r.reason_code), 2))) AS reason_std,
       r.source_team, r.receiving_team, CONCAT(r.source_team, ' -> ', r.receiving_team) AS handoff,
       r.estimated_minutes, r.resolution_status,
       CASE WHEN a.application_id IS NULL THEN 1 ELSE 0 END AS flag_orphan,
       CASE WHEN r.estimated_minutes = 0 THEN 1 ELSE 0 END AS flag_zero_minutes,
       CASE WHEN r.resolution_status = 'Invalid' THEN 1 ELSE 0 END AS flag_invalid,
       CASE WHEN a.application_id IS NOT NULL AND r.estimated_minutes > 0
                 AND r.resolution_status <> 'Invalid' THEN 1 ELSE 0 END AS is_qualifying,
       a.application_type, a.complexity_band, a.source_channel,
       DATE_FORMAT(a.created_at, '%Y-%m') AS created_month
FROM raw_rework_events r
LEFT JOIN raw_applications a ON a.application_id = r.application_id;

-- 3.8 Rework-eligible applications: exited Stage 1 (Intake) at least once
CREATE OR REPLACE VIEW v_eligible_apps AS
SELECT DISTINCT application_id
FROM v_stage_episodes
WHERE stage_name = 'Intake & Submission' AND exit_reason = 'Passed';

-- 3.9 Quick look at each cleaned view (row counts and flag totals)
SELECT 'v_applications_clean' AS view_name, COUNT(*) AS row_count,
       SUM(flag_status_variant) AS flag_a, SUM(flag_missing_completed_at) AS flag_b, SUM(flag_completed_before_last_exit) AS flag_c
FROM v_applications_clean
UNION ALL SELECT 'v_completed_cycle', COUNT(*), NULL, NULL, NULL FROM v_completed_cycle
UNION ALL SELECT 'v_stage_episodes', COUNT(*), SUM(flag_negative_duration), SUM(flag_missing_owner), SUM(is_reentry) FROM v_stage_episodes
UNION ALL SELECT 'v_task_performance', COUNT(*), SUM(flag_assigned_missing), SUM(flag_due_invalid), SUM(overdue_flag) FROM v_task_performance
UNION ALL SELECT 'v_rework_clean', COUNT(*), SUM(flag_orphan), SUM(flag_zero_minutes + flag_invalid), SUM(is_qualifying) FROM v_rework_clean
UNION ALL SELECT 'v_eligible_apps', COUNT(*), NULL, NULL, NULL FROM v_eligible_apps;
-- flag_a / flag_b / flag_c meanings by row:
--   applications : status variants / completed_at missing / completed_at before last exit
--   stage_episodes: negative durations / missing owner / re-entry episodes
--   tasks        : missing assigned_at / invalid due_at / overdue tasks
--   rework       : orphans / zero-minute + invalid / qualifying events