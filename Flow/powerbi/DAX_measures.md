## 1. Purpose

This document defines the DAX measures required for the five-page FLOW Power BI dashboard.

The measures use the existing Phase 3 processed CSV outputs and the Phase 4 `decision_model.xlsx` workbook. The dashboard must reconcile historical metrics to SQL and distinguish observed synthetic-data results from modelled intervention outcomes.

## 2. Data tables and naming conventions

Import the following files using Power BI Desktop's **Get Data** feature. Rename each query to the table name shown below.

| Power BI table | Source file |
|---|---|
| `MonthlyFlow` | `data/processed/kpi_monthly_flow.csv` |
| `CycleTimeSummary` | `data/processed/kpi_cycle_time_summary.csv` |
| `ReworkRate` | `data/processed/kpi_rework_rate.csv` |
| `ReworkDrivers` | `data/processed/kpi_rework_drivers.csv` |
| `StageMetrics` | `data/processed/kpi_syage_metrics.csv` |
| `StageMonthly` | `data/processed/kpi_stage_monthly.csv` |
| `BottleneckEvidence` | `data/processed/kpi_bottleneck_evidence.csv` |
| `TeamMonthlyLoad` | `data/processed/kpi_team_monthly_load.csv` |
| `OwnerWorkload` | `data/processed/kpi_owner_workload.csv` |
| `InterventionScenarios` | Phase 4 workbook, `Intervention Scenarios` worksheet |

Use the original column names from the CSV files. Set numeric fields to numeric data types and retain `ym` as a `YYYY-MM` text label. Create a separate `MonthStart` date column in the three monthly tables (`MonthlyFlow`, `StageMonthly` and `TeamMonthlyLoad`) by parsing `ym` as the first day of the month.

For the Excel scenario table, remove the title and subtitle rows, promote the actual header row, and retain the 12 scenario records only.

### Important percentage convention

The processed CSV files store percentages as values such as `49.2` and `19.9`, not `0.492` and `0.199`.

The DAX measures below divide these fields by 100 before displaying them as percentages.

---

## 3. Core business measures

Create these measures in a dedicated Power BI measures table or in `MonthlyFlow`.

### 3.1 Demand and throughput

```dax
Applications Received =
SUM ( MonthlyFlow[received] )
```

```dax
Applications Completed =
SUM ( MonthlyFlow[completed] )
```

```dax
Applications Cancelled =
SUM ( MonthlyFlow[cancelled] )
```

```dax
Net Demand Gap =
[Applications Received] - [Applications Completed]
```

A positive net demand gap means more applications were received than completed during the selected period. Cancellations are shown separately.

```dax
Average Monthly Receipts =
AVERAGE ( MonthlyFlow[received] )
```

```dax
Average Monthly Completions =
AVERAGE ( MonthlyFlow[completed] )
```

```dax
Completion Target =
240
```

```dax
Average Monthly Completion Gap =
[Completion Target] - [Average Monthly Completions]
```

### 3.2 Backlog

```dax
Opening Backlog =
SUM ( MonthlyFlow[opening_backlog] )
```

```dax
Closing Backlog =
SUM ( MonthlyFlow[closing_backlog] )
```

```dax
Closing Backlog - Latest Month =
MAXX (
    TOPN (
        1,
        ALL ( MonthlyFlow ),
        MonthlyFlow[ym], DESC
    ),
    MonthlyFlow[closing_backlog]
)
```

```dax
Backlog Change =
[Closing Backlog] - [Opening Backlog]
```

Use the monthly opening and closing backlog fields for trend visuals. Use the latest-month measure for the current reporting-period KPI card.

### 3.3 Cycle time and SLA

The overall row in `CycleTimeSummary` is identified by `dim = "Overall"` and `val = "All"`.

```dax
Valid Completed Cycles =
CALCULATE (
    MAX ( CycleTimeSummary[completed_cases] ),
    CycleTimeSummary[dim] = "Overall",
    CycleTimeSummary[val] = "All"
)
```

```dax
Mean Cycle Time - Calendar Days =
CALCULATE (
    MAX ( CycleTimeSummary[mean_cal_days] ),
    CycleTimeSummary[dim] = "Overall",
    CycleTimeSummary[val] = "All"
)
```

```dax
Median Cycle Time - Calendar Days =
CALCULATE (
    MAX ( CycleTimeSummary[median_cal_days] ),
    CycleTimeSummary[dim] = "Overall",
    CycleTimeSummary[val] = "All"
)
```

```dax
P90 Cycle Time - Calendar Days =
CALCULATE (
    MAX ( CycleTimeSummary[p90_cal_days] ),
    CycleTimeSummary[dim] = "Overall",
    CycleTimeSummary[val] = "All"
)
```

```dax
SLA Attainment =
DIVIDE (
    CALCULATE (
        MAX ( CycleTimeSummary[sla_attainment_pct] ),
        CycleTimeSummary[dim] = "Overall",
        CycleTimeSummary[val] = "All"
    ),
    100
)
```

```dax
SLA Target Days =
35
```

Format `SLA Attainment` as a percentage. The 35-day SLA is a calendar-day target.

**Important:** The overall summary row is a pre-calculated KPI. When analysing by application type or another dimension, use the corresponding rows of `CycleTimeSummary` rather than assuming the overall measure can be averaged across categories.

### 3.4 Rework

The overall row in `ReworkRate` is identified by `dim = "Overall"` and `val = "All"`.

```dax
Eligible Applications - Rework =
CALCULATE (
    MAX ( ReworkRate[eligible_apps] ),
    ReworkRate[dim] = "Overall",
    ReworkRate[val] = "All"
)
```

```dax
Applications With Rework =
CALCULATE (
    MAX ( ReworkRate[apps_with_rework] ),
    ReworkRate[dim] = "Overall",
    ReworkRate[val] = "All"
)
```

```dax
Application Rework Rate =
DIVIDE (
    [Applications With Rework],
    [Eligible Applications - Rework]
)
```

```dax
Rework Events =
571
```

`Rework Events` is the validated Phase 3 qualifying-event count. It is a fixed baseline value, not a time-responsive event count. Import the raw rework-event data if an interactive event-count measure is required.

```dax
Rework Minutes by Selected Driver =
SUM ( ReworkDrivers[total_minutes] )
```

```dax
Rework Hours by Selected Driver =
DIVIDE ( [Rework Minutes by Selected Driver], 60 )
```

```dax
Rework Share of Minutes =
DIVIDE (
    SUM ( ReworkDrivers[total_minutes] ),
    CALCULATE (
        SUM ( ReworkDrivers[total_minutes] ),
        ALLEXCEPT ( ReworkDrivers, ReworkDrivers[dim] )
    )
)
```

Use `ReworkDrivers[dim]` as a slicer and `ReworkDrivers[val]` as the category for driver charts. The table contains multiple analytical dimensions; **never sum all rows across all dimensions**, because the same events are represented in separate breakdowns.

Format `Application Rework Rate` and `Rework Share of Minutes` as percentages.

---

## 4. Process bottleneck measures

### 4.1 Stage-level duration and queues

```dax
Mean Stage Elapsed Days =
AVERAGE ( StageMetrics[mean_elapsed_days] )
```

```dax
Mean Stage Queue Days =
AVERAGE ( StageMetrics[mean_queue_days] )
```

```dax
P90 Stage Queue Days =
AVERAGE ( StageMetrics[p90_queue_days] )
```

```dax
Applications Queued Now - Stage =
SUM ( StageMetrics[queued_now] )
```

```dax
Applications In Stage Now =
SUM ( StageMetrics[in_stage_now] )
```

```dax
Stage Re-entry Episodes =
SUM ( StageMetrics[reentry_episodes] )
```

```dax
Stage Return Rate =
DIVIDE (
    AVERAGE ( StageMetrics[return_rate_pct] ),
    100
)
```

These stage measures operate over the stage summary table. They are useful for stage comparisons, but averages of pre-aggregated stage statistics should not be interpreted as a weighted overall mean.

### 4.2 Bottleneck ranking

```dax
Bottleneck Rank =
MIN ( BottleneckEvidence[bottleneck_rank] )
```

```dax
Composite Bottleneck Score =
MIN ( BottleneckEvidence[composite_rank_score] )
```

```dax
Mean Queue Change Days =
AVERAGE ( BottleneckEvidence[queue_change_days] )
```

```dax
Net Accumulation - Last 3 Months =
SUM ( BottleneckEvidence[net_accumulation_last_3m] )
```

Use the rank field for sorting the bottleneck table, not for calculating a new ranking across an already-ranked dataset.

### 4.3 Monthly stage workload in progress

```dax
Stage Entries =
SUM ( StageMonthly[entries] )
```

```dax
Stage Exits =
SUM ( StageMonthly[exits] )
```

```dax
Queued WIP =
SUM ( StageMonthly[wip_queued_month_end] )
```

```dax
Total Stage WIP =
SUM ( StageMonthly[wip_in_stage_month_end] )
```

These are stage-episode counts, not distinct application counts. A case can enter a stage more than once.

---

## 5. Capacity and workload measures

### 5.1 Team capacity and workload

```dax
Available Capacity Hours =
SUM ( TeamMonthlyLoad[capacity_hours] )
```

```dax
Complexity Points =
SUM ( TeamMonthlyLoad[complexity_points] )
```

```dax
Stage Episodes Entered =
SUM ( TeamMonthlyLoad[episodes_entered] )
```

```dax
Complexity Points per 100 Capacity Hours =
DIVIDE (
    [Complexity Points],
    [Available Capacity Hours]
) * 100
```

```dax
Episodes per Capacity Hour =
DIVIDE (
    [Stage Episodes Entered],
    [Available Capacity Hours]
)
```

These measures describe workload intensity. They do not prove active labour utilisation or establish a direct relationship between capacity hours and completed applications.

### 5.2 Owner-level indicators

```dax
Owner Count =
DISTINCTCOUNT ( OwnerWorkload[owner_id] )
```

```dax
Average Episodes per Active Month =
AVERAGE ( OwnerWorkload[episodes_per_active_month] )
```

```dax
Average Complexity per Active Month =
AVERAGE ( OwnerWorkload[complexity_points_per_active_month] )
```

Use owner-level measures with team and role context. Do not use individual owner rankings without explaining the differences in FTE, active months and workload complexity.

---

## 6. Intervention scenario measures

Import the `Intervention Scenarios` worksheet from the Phase 4 workbook as `InterventionScenarios`. It contains four options, each with three scenarios.

Use the workbook's calculated scenario values as the source of truth. If Excel has not recalculated the formulas, open the workbook in Excel, recalculate, save it, and then refresh Power BI.

```dax
Scenario Demand per Month =
MAX ( InterventionScenarios[Demand / month] )
```

```dax
Baseline Throughput Proxy =
MAX ( InterventionScenarios[Baseline throughput proxy] )
```

```dax
Modelled Throughput per Month =
MAX ( InterventionScenarios[Modelled throughput] )
```

```dax
Modelled Monthly Demand Gap =
MAX ( InterventionScenarios[Gap to demand] )
```

```dax
First-Year Modelled Cost =
SUM ( InterventionScenarios[First-year modelled cost] )
```

```dax
Added FTEs =
MAX ( InterventionScenarios[Added FTE] )
```

Use `InterventionScenarios[Option]` and `InterventionScenarios[Scenario]` as visual categories and slicers.

**Interpretation rule:** Scenario throughput is a planning proxy based on assumed redesign uplift and added throughput per FTE. It is not measured capacity. Scenario costs are not automatically netted against benefits, and the model does not establish validated cash savings.

---

## 7. Dashboard reconciliation checks

Create a validation page or use the following measures during development.

```dax
Monthly Backlog Reconciliation Variance =
SUM ( MonthlyFlow[opening_backlog] )
    + SUM ( MonthlyFlow[received] )
    - SUM ( MonthlyFlow[completed] )
    - SUM ( MonthlyFlow[cancelled] )
    - SUM ( MonthlyFlow[closing_backlog] )
```

This measure is useful for a single-month filter context. For an all-month dashboard total, the opening and closing backlogs do not represent a single roll-forward period, so validate monthly rows individually.

```dax
Monthly Reconciliation Status =
IF (
    [Monthly Backlog Reconciliation Variance] = 0,
    "PASS",
    "CHECK"
)
```

Use `MonthlyFlow[ym]` in the table or matrix alongside the reconciliation status. The expected historical result is `PASS` for each of the 12 months.

### Baseline reference values

Use these supplied Phase 3 values to verify the report:

| KPI | Expected baseline |
|---|---:|
| Applications received | 2,508 |
| Completed applications | 2,167 |
| Valid completed cycles | 2,162 |
| Closing backlog | 360 |
| Mean cycle time | 40.8 calendar days |
| Median cycle time | 35.1 calendar days |
| P90 cycle time | 70.0 calendar days |
| SLA attainment | 49.2% |
| Eligible applications for rework | 2,665 |
| Applications with rework | 530 |
| Application rework rate | 19.9% |
| Qualifying rework events | 571 |

If a KPI differs, check the selected filters, imported data types, duplicate dimension rows, and whether the overall row has been applied correctly before changing the measure.

---

## 8. General rules

1. Use calendar days for the 35-day SLA unless a visual explicitly states working days.
2. Do not average pre-aggregated statistics across groups and label them as a weighted overall KPI.
3. Do not sum `ReworkDrivers` across multiple dimensions.
4. Do not treat stage episodes as distinct applications.
5. Do not multiply `monthly_capacity_hours` by `FTE_fraction` again; capacity is already FTE-adjusted in the source.
6. Do not treat task elapsed time as active labour time.
7. Keep historical results separate from forecast and intervention results.
8. Keep the four intervention options and three scenario cases visible in the report.
9. Report modelled outcomes as estimates based on assumptions, never as realised benefits.
10. Reconcile historical metrics to the SQL exports and scenario measures to the Phase 4 Excel model before capturing screenshots.

**Definition of done:** the five dashboard pages display the agreed metrics, key filters work as intended, historical totals reconcile to SQL, intervention outputs reconcile to Excel, and the four to five exported screenshots are saved in `powerbi/screenshots/`.