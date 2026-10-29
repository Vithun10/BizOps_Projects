# FLOW: SQL Run Order (MySQL 8.0+, DBeaver)

| Step | Action |
|---|---|
| 1 | Run `01_create_tables.sql` PART A (creates database `flow_db` and 6 staging tables stg_*) |
| 2 | Import the 6 CSVs from `data\raw\` into the stg_* tables with the DBeaver import wizard |
| 3 | Run the PRE-CHECK query at the end of PART A. All six counts must match the expected column |
| 4 | Run `01_create_tables.sql` PART B (typed raw_* tables with keys, loaded from staging) |
| 5 | Run `02_profile_and_quality_checks.sql` (detects the 12 injected problems; last result must show MATCH) |
| 6 | Run `03_transformations.sql` (cleaned, flagged views) |
| 7 | Run `04_kpi_analysis.sql` (KPI views for Excel and Power BI) |
| 8 | Run `05_validation_checks.sql` (every check must show PASS) |
| 9 | Export the KPI views to `data\processed\` (see Phase 3 export steps) |

Design notes
- stg_* tables hold the raw CSV text untouched (audit trail). raw_* tables are typed copies with primary keys and foreign keys.
- raw_rework_events has no foreign key on application_id on purpose, because it contains intentional orphan rows (Q12).
- Data problems are flagged in views (flag_* columns), never silently corrected.
- All scripts can be re-run safely (DROP IF EXISTS / CREATE OR REPLACE).
- Parameters (cutoff date, period start, SLA of 35 calendar days) live in the view `v_params`.