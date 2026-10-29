-- =====================================================================
-- FLOW | Phase 3 | 05_validation_checks.sql
-- Purpose: prove the SQL layer is correct before Excel and Power BI use it.
-- Every check returns PASS or FAIL. Expected values for 5.1 and 5.2 come
-- from generation_summary.txt (the independent Python tie-out).
-- =====================================================================
USE flow_db;

-- 5.1 Scalar checks (expected value vs actual value)
WITH checks AS (
  -- row counts tie to generation_summary.txt
  SELECT '5.1.01 applications row count' AS check_name, 2711 AS expected, (SELECT COUNT(*) FROM raw_applications) AS actual
  UNION ALL SELECT '5.1.02 stage_history row count', 18332, (SELECT COUNT(*) FROM raw_stage_history)
  UNION ALL SELECT '5.1.03 tasks row count', 21363, (SELECT COUNT(*) FROM raw_tasks)
  UNION ALL SELECT '5.1.04 owners row count', 31, (SELECT COUNT(*) FROM raw_owners)
  UNION ALL SELECT '5.1.05 rework_events row count', 604, (SELECT COUNT(*) FROM raw_rework_events)
  UNION ALL SELECT '5.1.06 calendar row count', 426, (SELECT COUNT(*) FROM raw_calendar)
  -- cleaning tie-outs
  UNION ALL SELECT '5.1.07 stage episodes = raw rows - duplicates (55)', 18332 - 55, (SELECT COUNT(*) FROM v_stage_episodes)
  UNION ALL SELECT '5.1.08 valid completed cycles = completed - impossible sequences (5)', 2167 - 5, (SELECT COUNT(*) FROM v_completed_cycle)
  UNION ALL SELECT '5.1.09 qualifying rework events = rows - orphans - zero minutes - invalid', 604 - 3 - 18 - 12, (SELECT COUNT(*) FROM v_rework_clean WHERE is_qualifying = 1)
  -- backlog ties to application status
  UNION ALL SELECT '5.1.10 closing backlog Sep 2026 = applications still Open', (SELECT COUNT(*) FROM v_applications_clean WHERE status_std = 'Open'),
         (SELECT closing_backlog FROM kpi_monthly_flow WHERE ym = '2026-09')
  UNION ALL SELECT '5.1.11 opening backlog Oct 2025 = carry-over applications', 203,
         (SELECT opening_backlog FROM kpi_monthly_flow WHERE ym = '2025-10')
  UNION ALL SELECT '5.1.12 total received over 12 months', 2508, (SELECT SUM(received) FROM kpi_monthly_flow)
  UNION ALL SELECT '5.1.13 applications = opening backlog + total received', (SELECT COUNT(*) FROM raw_applications),
         (SELECT MAX(CASE WHEN ym = '2025-10' THEN opening_backlog END) + SUM(received) FROM kpi_monthly_flow)
  -- stage history reconciles to application outcomes (all expected 0)
  UNION ALL SELECT '5.1.14 Completed apps without a passed Activation Handoff', 0,
         (SELECT COUNT(*) FROM v_applications_clean a
          WHERE a.status_std = 'Completed' AND NOT EXISTS
                (SELECT 1 FROM v_stage_episodes e WHERE e.application_id = a.application_id
                   AND e.stage_name = 'Activation Handoff' AND e.exit_reason = 'Passed'))
  UNION ALL SELECT '5.1.15 Completed apps that did not pass all 7 stages', 0,
         (SELECT COUNT(*) FROM v_applications_clean a
          WHERE a.status_std = 'Completed'
            AND (SELECT COUNT(DISTINCT e.stage_name) FROM v_stage_episodes e
                  WHERE e.application_id = a.application_id AND e.exit_reason = 'Passed') < 7)
  UNION ALL SELECT '5.1.16 Cancelled apps without a cancelling stage entry', 0,
         (SELECT COUNT(*) FROM v_applications_clean a
          WHERE a.status_std = 'Cancelled' AND NOT EXISTS
                (SELECT 1 FROM v_stage_episodes e WHERE e.application_id = a.application_id
                   AND e.exit_reason = 'Application cancelled'))
  UNION ALL SELECT '5.1.17 Open apps with a cancelling entry or a passed Activation Handoff', 0,
         (SELECT COUNT(*) FROM v_applications_clean a
          WHERE a.status_std = 'Open' AND EXISTS
                (SELECT 1 FROM v_stage_episodes e WHERE e.application_id = a.application_id
                   AND (e.exit_reason = 'Application cancelled'
                        OR (e.stage_name = 'Activation Handoff' AND e.exit_reason = 'Passed'))))
  UNION ALL SELECT '5.1.18 Valid stage episodes with no matching task', 0,
         (SELECT COUNT(*) FROM v_stage_episodes e
          WHERE e.flag_negative_duration = 0
            AND NOT EXISTS (SELECT 1 FROM raw_tasks t WHERE t.application_id = e.application_id AND t.created_at = e.entered_at))
  UNION ALL SELECT '5.1.19 First Intake entry not equal to application created_at', 0,
         (SELECT COUNT(*) FROM v_stage_episodes e JOIN raw_applications a ON a.application_id = e.application_id
          WHERE e.stage_no = 1 AND e.visit_no = 1 AND e.flag_negative_duration = 0 AND e.entered_at <> a.created_at)
  UNION ALL SELECT '5.1.20 Backlog reconciliation months failing', 0,
         (SELECT COUNT(*) FROM kpi_monthly_flow WHERE recon_check <> 'PASS')
)
SELECT check_name, expected, actual, CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks
ORDER BY check_name;

-- 5.2 Monthly backlog: SQL result vs the independent Python summary
WITH exp AS (
  SELECT '2025-10' AS ym, 203 AS opening_backlog, 158 AS received, 136 AS completed, 16 AS cancelled, 209 AS closing_backlog
  UNION ALL SELECT '2025-11', 209, 183, 139, 11, 242
  UNION ALL SELECT '2025-12', 242, 179, 174, 18, 229
  UNION ALL SELECT '2026-01', 229, 159, 152, 13, 223
  UNION ALL SELECT '2026-02', 223, 177, 144, 11, 245
  UNION ALL SELECT '2026-03', 245, 258, 183, 17, 303
  UNION ALL SELECT '2026-04', 303, 198, 205, 16, 280
  UNION ALL SELECT '2026-05', 280, 224, 183, 20, 301
  UNION ALL SELECT '2026-06', 301, 222, 204, 15, 304
  UNION ALL SELECT '2026-07', 304, 246, 226, 20, 304
  UNION ALL SELECT '2026-08', 304, 240, 223, 12, 309
  UNION ALL SELECT '2026-09', 309, 264, 198, 15, 360
)
SELECT k.ym, k.opening_backlog, k.received, k.completed, k.cancelled, k.closing_backlog,
       k.recon_check AS internal_check,
       CASE WHEN k.opening_backlog = e.opening_backlog AND k.received = e.received AND k.completed = e.completed
                 AND k.cancelled = e.cancelled AND k.closing_backlog = e.closing_backlog
            THEN 'PASS' ELSE 'FAIL' END AS matches_python_summary
FROM kpi_monthly_flow k
JOIN exp e ON e.ym = k.ym
ORDER BY k.ym;

-- 5.3 Roll-forward: each month's closing backlog equals the next month's opening backlog
SELECT a.ym, a.closing_backlog, b.ym AS next_ym, b.opening_backlog AS next_opening,
       CASE WHEN a.closing_backlog = b.opening_backlog THEN 'PASS' ELSE 'FAIL' END AS result
FROM kpi_monthly_flow a
JOIN kpi_monthly_flow b
  ON b.ym = DATE_FORMAT(DATE_ADD(STR_TO_DATE(CONCAT(a.ym, '-01'), '%Y-%m-%d'), INTERVAL 1 MONTH), '%Y-%m')
ORDER BY a.ym;

-- 5.4 Cycle-time cross-check: monthly completions vs monthly valid cycles
-- The only allowed difference is the applications excluded as impossible sequences.
SELECT f.ym, f.completed AS completed_in_flow, c.completed_cases AS valid_cycle_cases,
       f.completed - c.completed_cases AS excluded_as_invalid
FROM kpi_monthly_flow f
LEFT JOIN kpi_cycle_time_summary c ON c.dim = 'Completion month' AND c.val = f.ym
ORDER BY f.ym;

-- 5.5 Reference KPI card: record these values; Excel (Phase 4) and Power BI (Phase 5) must reproduce them
SELECT 'Applications in data' AS kpi, CAST(COUNT(*) AS CHAR) AS value FROM v_applications_clean
UNION ALL SELECT 'Completed applications (all months)', CAST(SUM(status_std = 'Completed') AS CHAR) FROM v_applications_clean
UNION ALL SELECT 'Cancelled applications', CAST(SUM(status_std = 'Cancelled') AS CHAR) FROM v_applications_clean
UNION ALL SELECT 'Open at cutoff (closing backlog)', CAST(SUM(status_std = 'Open') AS CHAR) FROM v_applications_clean
UNION ALL SELECT 'Valid completed cycles', CAST(completed_cases AS CHAR) FROM kpi_cycle_time_summary WHERE dim = 'Overall'
UNION ALL SELECT 'Mean cycle time (calendar days)', CAST(mean_cal_days AS CHAR) FROM kpi_cycle_time_summary WHERE dim = 'Overall'
UNION ALL SELECT 'Median cycle time (calendar days)', CAST(median_cal_days AS CHAR) FROM kpi_cycle_time_summary WHERE dim = 'Overall'
UNION ALL SELECT 'P90 cycle time (calendar days)', CAST(p90_cal_days AS CHAR) FROM kpi_cycle_time_summary WHERE dim = 'Overall'
UNION ALL SELECT 'SLA attainment % (35 calendar days)', CAST(sla_attainment_pct AS CHAR) FROM kpi_cycle_time_summary WHERE dim = 'Overall'
UNION ALL SELECT 'Rework rate % (eligible applications)', CAST(rework_rate_pct AS CHAR) FROM kpi_rework_rate WHERE dim = 'Overall'
UNION ALL SELECT 'Top-ranked bottleneck stage', stage_name FROM kpi_bottleneck_evidence WHERE bottleneck_rank = 1;