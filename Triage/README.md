# TRIAGE: Client Onboarding & KYC Workflow Optimisation

> **Risk-based routing and control design for a digital-banking onboarding flow.**
> Replaces uniform identity verification with a transparent risk-tiering process, then tests where to set the escalation threshold using SQL, Python and Power BI.

**Disclosure:** This is a portfolio project using a fictional institution and a synthetic dataset (2,000 applicants). All findings describe the synthetic data. They are not results achieved for a real employer, and no real vendor or production system was used.

---

## The problem

A digital bank applies the same identity-verification effort to every applicant. Product wants a fast, low-friction signup to protect conversion. Compliance wants thorough scrutiny, especially for Politically Exposed Persons (PEPs). Uniform friction frustrates low-risk users, and uniform speed under-checks high-risk ones.

## The approach

A deterministic, explainable risk score (country risk 40%, transaction velocity 30%, verification mismatch 30%) sorts applicants into three tiers:

| Tier | Score | Routing |
|---|---|---|
| Low | < 50 | Automatic activation, decision logged |
| Medium | 50 to < 75 | One standard Compliance review |
| High | ≥ 75, or any PEP/sanctions match | Enhanced Due Diligence (two reviewers) |

PEP and sanctions matches always override the score. Input-quality checks (expired ID, low verification match) run first.

## Key findings (synthetic data, n = 2,000)

- **Funnel:** 21.85% overall drop-off, concentrated at document upload (8.25% of all applicants). The original 28% planning assumption was replaced by this measured figure.
- **Friction by tier:** average time-to-onboard of 4.04 minutes (Low), 17.79 (Medium) and 57.24 (High), roughly a 14x spread. 85.4% of completed onboardings were Low tier.
- **Threshold decision:** a sweep across thresholds 20 to 75 put the best F1 at 40 (precision 0.346, recall 0.548), but that pulls 32.2% of applicants out of the fast path. Threshold 50 was chosen instead: 15.2% of applicants escalated, precision 0.436, recall 0.324.
- **Tier mix at threshold 50:** Low 81.1%, Medium 14.0%, High/EDD 4.9% (86 of the 98 High-tier applicants are PEP overrides).

## Known limitations

- At threshold 50 the model still misses about two-thirds (67.6%) of applicants later flagged as risky. The three-factor formula separates risk only moderately, and no threshold fully closes the gap.
- Every High-tier country segment has fewer than 15 applicants, so country-level results are flagged in the dashboard and not reported as findings.
- The share of deceptive profiles in the data is a synthetic design choice, not a real-world prevalence figure.
- No SQL or script tests routing for FR-006 to FR-008. These are specified, not tested.

## How to reproduce

1. Run `06_Mock_Data/generate_mock_dataset.py` (seed 42) to create `mock_onboarding_dataset.csv`.
2. Run `07_Scoring_Script/threshold_sweep.py` for the 20 to 75 precision/recall sweep, and `threshold_analysis.py` for the original 70 vs 75 comparison.
3. Load the CSV into MySQL as table `onboarding` and run `08_SQL_Queries/funnel_and_risk_queries.sql` (funnel drop-off, time-to-onboard by tier, verification pass rate by tier and country).
4. Open `10_PowerBI/KYC_Onboarding_Dashboard_v1.0.pbix`, or see `12_Screenshots/`.

## Repository structure

| Folder | Contents |
|---|---|
| `06_Mock_Data/` | Dataset generator and synthetic dataset |
| `07_Scoring_Script/` | Threshold analysis and sweep (Python) |
| `08_SQL_Queries/` | Funnel, time-to-onboard and pass-rate queries |
| `10_PowerBI/`, `12_Screenshots/` | Dashboard file and previews |
| `11_Case_Study/` | Stakeholder narrative and findings |
| `00` to `05`, `09` | Supporting documentation: problem statement, stakeholder map, BRD, FRD, process maps, RTM, user stories, vendor API spec |

## Tools

SQL (MySQL), Python (pandas), Power BI, process mapping.

## Related project

**FLOW**: Customer Onboarding Throughput Diagnostic & Decision Model (capacity, bottlenecks and staffing decision). TRIAGE addresses a different question: who should receive heavier checks, and where the threshold should sit.

## Contact

**TR Vithun** | Business Operations | LinkedIn: https://www.linkedin.com/in/vithuntr/ | Email: vithunkpm@gmail.com