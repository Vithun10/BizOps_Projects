-- =====================================================================
-- FLOW | Phase 3 | 04_kpi_analysis.sql
-- Purpose: KPI views (definitions in assumptions\KPI_definitions.md).
-- These views feed Excel (Phase 4) and Power BI (Phase 5).
-- Run the whole script once (Alt+X), then read the SELECTs at the bottom.
-- Percentiles: MySQL has no PERCENTILE function, so median and P90 use
-- ROW_NUMBER ranks (P90 = nearest-rank method, the value at rank CEIL(0.9*n)).
-- =====================================================================
USE flow_db;

-- 4.0 Month list (Oct 2025 - Sep 2026)
CREATE OR REPLACE VIEW kpi_months AS
SELECT month AS ym, MIN(calendar_date) AS month_start, DATE_ADD(MIN(calendar_date), INTERVAL 1 MONTH) AS next_start
FROM raw_calendar
WHERE month >= '2025-10'
GROUP BY month;

-- 4.1 Monthly flow and backlog reconciliation
CREATE OR REPLACE VIEW kpi_monthly_flow AS
SELECT t.*,
       t.received - t.completed AS net_change_vs_demand,
       CASE WHEN t.opening_backlog + t.received - t.completed - t.cancelled = t.closing_backlog
            THEN 'PASS' ELSE 'FAIL' END AS recon_check
FROM (
  SELECT m.ym,
    (SELECT COUNT(*) FROM v_applications_clean a
      WHERE a.created_at < m.month_start AND (a.closed_at IS NULL OR a.closed_at >= m.month_start)) AS opening_backlog,
    (SELECT COUNT(*) FROM v_applications_clean a
      WHERE a.created_at >= m.month_start AND a.created_at < m.next_start) AS received,
    (SELECT COUNT(*) FROM v_applications_clean a
      WHERE a.status_std = 'Completed' AND a.closed_at >= m.month_start AND a.closed_at < m.next_start) AS completed,
    (SELECT COUNT(*) FROM v_applications_clean a
      WHERE a.status_std = 'Cancelled' AND a.closed_at >= m.month_start AND a.closed_at < m.next_start) AS cancelled,
    (SELECT COUNT(*) FROM v_applications_clean a
      WHERE a.created_at < m.next_start AND (a.closed_at IS NULL OR a.closed_at >= m.next_start)) AS closing_backlog
  FROM kpi_months m
) t;

-- 4.2 Cycle time (mean, median, P90 in calendar and working days) and SLA attainment
CREATE OR REPLACE VIEW kpi_cycle_time_summary AS
WITH x AS (
  SELECT 'Overall' AS dim, 'All' AS val, cal_days, wd_days, sla_met FROM v_completed_cycle
  UNION ALL SELECT 'Completion month', completed_month, cal_days, wd_days, sla_met FROM v_completed_cycle
  UNION ALL SELECT 'Complexity band', complexity_band, cal_days, wd_days, sla_met FROM v_completed_cycle
  UNION ALL SELECT 'Application type', application_type, cal_days, wd_days, sla_met FROM v_completed_cycle
),
r AS (
  SELECT x.*,
         ROW_NUMBER() OVER (PARTITION BY dim, val ORDER BY cal_days) AS rn_c,
         ROW_NUMBER() OVER (PARTITION BY dim, val ORDER BY wd_days, cal_days) AS rn_w,
         COUNT(*) OVER (PARTITION BY dim, val) AS n
  FROM x
)
SELECT dim, val, MAX(n) AS completed_cases,
       ROUND(AVG(cal_days), 1) AS mean_cal_days,
       ROUND(AVG(CASE WHEN rn_c IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2)) THEN cal_days END), 1) AS median_cal_days,
       ROUND(MAX(CASE WHEN rn_c = CEIL(0.9 * n) THEN cal_days END), 1) AS p90_cal_days,
       ROUND(AVG(wd_days), 1) AS mean_working_days,
       ROUND(AVG(CASE WHEN rn_w IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2)) THEN wd_days END), 1) AS median_working_days,
       ROUND(MAX(CASE WHEN rn_w = CEIL(0.9 * n) THEN wd_days END), 1) AS p90_working_days,
       ROUND(100 * AVG(sla_met), 1) AS sla_attainment_pct
FROM r
GROUP BY dim, val;

-- 4.3 Stage metrics: elapsed, queue, re-entry, returns, queue ageing
CREATE OR REPLACE VIEW kpi_stage_metrics AS
WITH el AS (
  SELECT stage_no, elapsed_days AS v,
         ROW_NUMBER() OVER (PARTITION BY stage_no ORDER BY elapsed_days) AS rn,
         COUNT(*) OVER (PARTITION BY stage_no) AS n
  FROM v_stage_episodes WHERE elapsed_days IS NOT NULL
),
els AS (
  SELECT stage_no, COUNT(*) AS closed_episodes, ROUND(AVG(v), 2) AS mean_elapsed_days,
         ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2)) THEN v END), 2) AS median_elapsed_days,
         ROUND(MAX(CASE WHEN rn = CEIL(0.9 * n) THEN v END), 2) AS p90_elapsed_days
  FROM el GROUP BY stage_no
),
q AS (
  SELECT stage_no, queue_days AS v,
         ROW_NUMBER() OVER (PARTITION BY stage_no ORDER BY queue_days) AS rn,
         COUNT(*) OVER (PARTITION BY stage_no) AS n
  FROM v_stage_episodes WHERE queue_days IS NOT NULL
),
qs AS (
  SELECT stage_no, ROUND(AVG(v), 2) AS mean_queue_days,
         ROUND(AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2)) THEN v END), 2) AS median_queue_days,
         ROUND(MAX(CASE WHEN rn = CEIL(0.9 * n) THEN v END), 2) AS p90_queue_days
  FROM q GROUP BY stage_no
),
fl AS (
  SELECT stage_no, MAX(stage_name) AS stage_name, MAX(stage_team) AS stage_team, COUNT(*) AS episodes_total,
         SUM(is_reentry) AS reentry_episodes,
         SUM(CASE WHEN exit_reason = 'Returned for rework' THEN 1 ELSE 0 END) AS returned_episodes,
         SUM(CASE WHEN status = 'Queued' THEN 1 ELSE 0 END) AS queued_now,
         SUM(CASE WHEN status IN ('Queued', 'In Progress') THEN 1 ELSE 0 END) AS in_stage_now
  FROM v_stage_episodes GROUP BY stage_no
),
age AS (
  SELECT e.stage_no, ROUND(AVG(TIMESTAMPDIFF(SECOND, e.entered_at, p.cutoff) / 86400.0), 2) AS avg_age_of_queued_days,
         ROUND(MAX(TIMESTAMPDIFF(SECOND, e.entered_at, p.cutoff) / 86400.0), 2) AS max_age_of_queued_days
  FROM v_stage_episodes e CROSS JOIN v_params p
  WHERE e.status = 'Queued'
  GROUP BY e.stage_no
)
SELECT fl.stage_no, fl.stage_name, fl.stage_team, fl.episodes_total, els.closed_episodes,
       els.mean_elapsed_days, els.median_elapsed_days, els.p90_elapsed_days,
       qs.mean_queue_days, qs.median_queue_days, qs.p90_queue_days,
       fl.reentry_episodes, ROUND(100 * fl.reentry_episodes / fl.episodes_total, 1) AS reentry_pct,
       fl.returned_episodes, ROUND(100 * fl.returned_episodes / fl.episodes_total, 1) AS return_rate_pct,
       fl.queued_now, fl.in_stage_now, age.avg_age_of_queued_days, age.max_age_of_queued_days
FROM fl
LEFT JOIN els ON els.stage_no = fl.stage_no
LEFT JOIN qs ON qs.stage_no = fl.stage_no
LEFT JOIN age ON age.stage_no = fl.stage_no;

-- 4.4 Stage by month: entries, exits, queue time, work in progress at month end
CREATE OR REPLACE VIEW kpi_stage_monthly AS
WITH ep AS (
  SELECT e.*, DATE_FORMAT(e.exited_at, '%Y-%m') AS exited_month
  FROM v_stage_episodes e
  WHERE e.flag_negative_duration = 0
),
st AS (
  SELECT DISTINCT stage_no, stage_name FROM v_stage_episodes
),
ent AS (
  SELECT stage_no, entered_month AS ym, COUNT(*) AS entries, ROUND(AVG(queue_days), 2) AS avg_queue_days
  FROM ep GROUP BY stage_no, entered_month
),
ext AS (
  SELECT stage_no, exited_month AS ym, COUNT(*) AS exits
  FROM ep WHERE exited_at IS NOT NULL GROUP BY stage_no, exited_month
),
wip AS (
  SELECT m.ym, e.stage_no, COUNT(*) AS wip_in_stage_month_end,
         SUM(CASE WHEN (e.first_assigned_at IS NOT NULL AND e.first_assigned_at >= m.next_start)
                    OR (e.first_assigned_at IS NULL AND e.status = 'Queued') THEN 1 ELSE 0 END) AS wip_queued_month_end
  FROM kpi_months m
  JOIN ep e ON e.entered_at < m.next_start AND (e.exited_at IS NULL OR e.exited_at >= m.next_start)
  GROUP BY m.ym, e.stage_no
)
SELECT m.ym, st.stage_no, st.stage_name,
       COALESCE(ent.entries, 0) AS entries,
       COALESCE(ext.exits, 0) AS exits,
       ent.avg_queue_days,
       COALESCE(wip.wip_in_stage_month_end, 0) AS wip_in_stage_month_end,
       COALESCE(wip.wip_queued_month_end, 0) AS wip_queued_month_end
FROM kpi_months m
CROSS JOIN st
LEFT JOIN ent ON ent.stage_no = st.stage_no AND ent.ym = m.ym
LEFT JOIN ext ON ext.stage_no = st.stage_no AND ext.ym = m.ym
LEFT JOIN wip ON wip.stage_no = st.stage_no AND wip.ym = m.ym;

-- 4.5 Rework rate (eligible applications with at least one qualifying rework event)
CREATE OR REPLACE VIEW kpi_rework_rate AS
WITH el AS (
  SELECT a.application_id, a.application_type, a.complexity_band, a.source_channel, a.created_month,
         CASE WHEN rw.application_id IS NOT NULL THEN 1 ELSE 0 END AS has_rework
  FROM v_applications_clean a
  JOIN v_eligible_apps e ON e.application_id = a.application_id
  LEFT JOIN (SELECT DISTINCT application_id FROM v_rework_clean WHERE is_qualifying = 1) rw
         ON rw.application_id = a.application_id
),
x AS (
  SELECT 'Overall' AS dim, 'All' AS val, has_rework FROM el
  UNION ALL SELECT 'Application type', application_type, has_rework FROM el
  UNION ALL SELECT 'Complexity band', complexity_band, has_rework FROM el
  UNION ALL SELECT 'Source channel', source_channel, has_rework FROM el
  UNION ALL SELECT 'Created month (cohort)', created_month, has_rework FROM el
)
SELECT dim, val, COUNT(*) AS eligible_apps, SUM(has_rework) AS apps_with_rework,
       ROUND(100 * AVG(has_rework), 1) AS rework_rate_pct
FROM x
GROUP BY dim, val;

-- 4.6 Rework drivers: events and effort by reason, handoff, stage, type (Pareto-ready)
CREATE OR REPLACE VIEW kpi_rework_drivers AS
WITH q AS (
  SELECT * FROM v_rework_clean WHERE is_qualifying = 1
),
x AS (
  SELECT 'Reason' AS dim, reason_std AS val, application_id, estimated_minutes FROM q
  UNION ALL SELECT 'Handoff (source -> receiving)', handoff, application_id, estimated_minutes FROM q
  UNION ALL SELECT 'Detecting stage', stage_name, application_id, estimated_minutes FROM q
  UNION ALL SELECT 'Application type', application_type, application_id, estimated_minutes FROM q
),
agg AS (
  SELECT dim, val, COUNT(*) AS events, COUNT(DISTINCT application_id) AS apps,
         SUM(estimated_minutes) AS total_minutes, ROUND(AVG(estimated_minutes), 1) AS avg_minutes
  FROM x GROUP BY dim, val
)
SELECT agg.*,
       ROUND(100 * total_minutes / SUM(total_minutes) OVER (PARTITION BY dim), 1) AS pct_of_minutes,
       ROUND(100 * SUM(total_minutes) OVER (PARTITION BY dim ORDER BY total_minutes DESC, val
                                            ROWS UNBOUNDED PRECEDING)
             / SUM(total_minutes) OVER (PARTITION BY dim), 1) AS cumulative_pct_of_minutes
FROM agg;

-- 4.7 Owner workload WITH context (tenure, capacity, complexity)
CREATE OR REPLACE VIEW kpi_owner_workload AS
WITH own AS (
  SELECT o.owner_id, o.team, o.role, o.FTE_fraction, o.monthly_capacity_hours, o.active_from, o.active_to,
         GREATEST(0, DATEDIFF(LEAST(COALESCE(o.active_to, DATE(p.cutoff)), DATE(p.cutoff)),
                              GREATEST(o.active_from, DATE(p.period_start))) + 1) AS active_days
  FROM raw_owners o CROSS JOIN v_params p
),
work AS (
  SELECT e.owner_id, COUNT(*) AS episodes_handled,
         SUM(CASE e.complexity_band WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 ELSE 1 END) AS complexity_points
  FROM v_stage_episodes e CROSS JOIN v_params p
  WHERE e.owner_id IS NOT NULL AND e.flag_negative_duration = 0 AND e.entered_at >= p.period_start
  GROUP BY e.owner_id
)
SELECT own.owner_id, own.team, own.role, own.FTE_fraction, own.monthly_capacity_hours, own.active_from, own.active_to,
       ROUND(own.active_days / 30.4, 1) AS active_months_in_period,
       COALESCE(w.episodes_handled, 0) AS episodes_handled,
       ROUND(COALESCE(w.episodes_handled, 0) / NULLIF(own.active_days / 30.4, 0), 1) AS episodes_per_active_month,
       ROUND(COALESCE(w.complexity_points, 0) / NULLIF(own.active_days / 30.4, 0), 1) AS complexity_points_per_active_month,
       ROUND(COALESCE(w.complexity_points, 0) / NULLIF(own.monthly_capacity_hours * own.active_days / 30.4, 0), 3) AS complexity_points_per_capacity_hour
FROM own
LEFT JOIN work w ON w.owner_id = own.owner_id;

-- 4.8 Team demand vs capacity by month (arrivals weighted by complexity vs prorated capacity hours)
-- Read each team's trend over time; do not compare points_per_100_capacity_hours BETWEEN teams
-- (effort per case differs by team). Phase 4 converts this into hours using documented assumptions.
CREATE OR REPLACE VIEW kpi_team_monthly_load AS
WITH arr AS (
  SELECT e.stage_team AS team, e.entered_month AS ym, COUNT(*) AS episodes_entered,
         SUM(CASE e.complexity_band WHEN 'High' THEN 3 WHEN 'Medium' THEN 2 ELSE 1 END) AS complexity_points
  FROM v_stage_episodes e
  WHERE e.flag_negative_duration = 0
  GROUP BY e.stage_team, e.entered_month
),
cap AS (
  SELECT m.ym, o.team,
         ROUND(SUM(o.monthly_capacity_hours
                   * GREATEST(0, DATEDIFF(LEAST(COALESCE(o.active_to, DATE('2099-12-31')), DATE_SUB(m.next_start, INTERVAL 1 DAY)),
                                          GREATEST(o.active_from, m.month_start)) + 1)
                   / DATEDIFF(m.next_start, m.month_start)), 0) AS capacity_hours
  FROM kpi_months m CROSS JOIN raw_owners o
  GROUP BY m.ym, o.team
)
SELECT c.ym, c.team, COALESCE(a.episodes_entered, 0) AS episodes_entered,
       COALESCE(a.complexity_points, 0) AS complexity_points, c.capacity_hours,
       ROUND(100 * COALESCE(a.complexity_points, 0) / NULLIF(c.capacity_hours, 0), 1) AS points_per_100_capacity_hours
FROM cap c
LEFT JOIN arr a ON a.team = c.team AND a.ym = c.ym;

-- 4.9 Bottleneck evidence: stages ranked on SIX measures, not on longest average duration
-- Measures (rank 1 = worst on each): mean queue time, P90 queue time, queue change (Jul-Sep vs Oct-Dec),
-- queued items now, net accumulation in the last 3 months (entries - exits), return-to-earlier-stage rate.
-- composite_rank_score = average of the six ranks; bottleneck_rank orders stages by that score.
CREATE OR REPLACE VIEW kpi_bottleneck_evidence AS
WITH trend AS (
  SELECT stage_no,
         ROUND(AVG(CASE WHEN entered_month IN ('2025-10', '2025-11', '2025-12') THEN queue_days END), 2) AS queue_early,
         ROUND(AVG(CASE WHEN entered_month IN ('2026-07', '2026-08', '2026-09') THEN queue_days END), 2) AS queue_late
  FROM v_stage_episodes
  GROUP BY stage_no
),
acc AS (
  SELECT stage_no, SUM(entries) - SUM(exits) AS net_accumulation_last_3m
  FROM kpi_stage_monthly
  WHERE ym IN ('2026-07', '2026-08', '2026-09')
  GROUP BY stage_no
),
base AS (
  SELECT sm.stage_no, sm.stage_name, sm.stage_team, sm.mean_elapsed_days,
         sm.mean_queue_days, sm.p90_queue_days,
         ROUND(t.queue_late - t.queue_early, 2) AS queue_change_days,
         sm.queued_now, a.net_accumulation_last_3m, sm.return_rate_pct
  FROM kpi_stage_metrics sm
  JOIN trend t ON t.stage_no = sm.stage_no
  JOIN acc a ON a.stage_no = sm.stage_no
),
ranked AS (
  SELECT base.*,
         RANK() OVER (ORDER BY mean_queue_days DESC) AS r_mean_queue,
         RANK() OVER (ORDER BY p90_queue_days DESC) AS r_p90_queue,
         RANK() OVER (ORDER BY queue_change_days DESC) AS r_queue_change,
         RANK() OVER (ORDER BY queued_now DESC) AS r_queued_now,
         RANK() OVER (ORDER BY net_accumulation_last_3m DESC) AS r_accumulation,
         RANK() OVER (ORDER BY return_rate_pct DESC) AS r_return_rate,
         RANK() OVER (ORDER BY mean_elapsed_days DESC) AS rank_by_elapsed_only
  FROM base
)
SELECT ranked.*,
       ROUND((r_mean_queue + r_p90_queue + r_queue_change + r_queued_now + r_accumulation + r_return_rate) / 6, 2) AS composite_rank_score,
       RANK() OVER (ORDER BY (r_mean_queue + r_p90_queue + r_queue_change + r_queued_now + r_accumulation + r_return_rate)) AS bottleneck_rank
FROM ranked;

-- =====================================================================
-- REVIEW THE RESULTS (run these SELECTs one at a time)
-- =====================================================================
SELECT * FROM kpi_monthly_flow ORDER BY ym;

SELECT * FROM kpi_cycle_time_summary
ORDER BY FIELD(dim, 'Overall', 'Completion month', 'Complexity band', 'Application type'), val;

SELECT * FROM kpi_stage_metrics ORDER BY stage_no;

SELECT * FROM kpi_stage_monthly ORDER BY stage_no, ym;

SELECT * FROM kpi_rework_rate ORDER BY dim, val;

SELECT * FROM kpi_rework_drivers ORDER BY dim, total_minutes DESC;

SELECT * FROM kpi_owner_workload ORDER BY team, owner_id;

SELECT * FROM kpi_team_monthly_load ORDER BY team, ym;

SELECT stage_no, stage_name, bottleneck_rank, composite_rank_score, rank_by_elapsed_only,
       mean_elapsed_days, mean_queue_days, p90_queue_days, queue_change_days,
       queued_now, net_accumulation_last_3m, return_rate_pct
FROM kpi_bottleneck_evidence
ORDER BY bottleneck_rank, stage_no;