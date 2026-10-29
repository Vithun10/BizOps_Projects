"""
FLOW - Synthetic Data Generator
Company : Northstar Cloud Services (fictional B2B SaaS) - ALL DATA IS SYNTHETIC
Output  : 6 CSV files in .\\raw\\  and  generation_summary.txt in this folder
Usage   : python generate_flow_data.py
Needs   : pip install numpy pandas
Design  : see assumptions\\data_generation_assumptions.md
"""
import heapq
import itertools
from bisect import bisect_left, bisect_right
from collections import Counter
from datetime import date, datetime, time, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 20261013
rng = np.random.default_rng(SEED)
HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
RAW.mkdir(parents=True, exist_ok=True)

# ======================================================================
# 1. CALENDAR  (simulation runs on a working-day axis, then maps to dates)
# ======================================================================
SIM_START = date(2025, 8, 1)      # warm-up start (avoids an empty-system cold start)
PERIOD_START = date(2025, 10, 1)  # analysis period start
PERIOD_END = date(2026, 9, 30)    # data extract cutoff
SIM_END = date(2027, 12, 31)
HOLIDAYS = {                      # illustrative public holidays (synthetic)
    date(2025, 8, 15), date(2025, 10, 2), date(2025, 10, 20), date(2025, 12, 25),
    date(2026, 1, 1), date(2026, 1, 26), date(2026, 3, 4), date(2026, 4, 3),
    date(2026, 5, 1), date(2026, 8, 15), date(2026, 9, 14),
}

WD = []
_d = SIM_START
while _d <= SIM_END:
    if _d.weekday() < 5 and _d not in HOLIDAYS:
        WD.append(_d)
    _d += timedelta(days=1)


def wd_to_dt(x):
    """Working-day float -> datetime (working hours 09:00-18:00)."""
    i = min(int(x), len(WD) - 1)
    return datetime.combine(WD[i], time(9)) + timedelta(hours=9 * (x - i))


P0 = float(bisect_left(WD, PERIOD_START))            # period start on the wd axis
CUT = float(bisect_right(WD, PERIOD_END))            # end of last working day of period

# ======================================================================
# 2. PROCESS DEFINITION
# ======================================================================
STAGES = [  # effort = hands-on hours (medium complexity); ext = mean external wait (working days)
    dict(name="Intake & Submission", team="Sales", effort=1.2, ext=2.5, sla=2,
         task="Intake form completion", block="Awaiting customer information"),
    dict(name="Handoff Acceptance", team="RevOps", effort=0.7, ext=0.3, sla=1,
         task="Handoff validation", block="Awaiting clarification from Sales"),
    dict(name="Contract & Legal Review", team="Legal", effort=1.2, ext=6.0, sla=8,
         task="Contract and risk review", block="Awaiting counterparty redlines"),
    dict(name="Finance Approval", team="Finance", effort=1.1, ext=2.5, sla=3,
         task="Credit check and billing setup", block="Awaiting credit or customer documents"),
    dict(name="Implementation Setup", team="Implementation", effort=4.5, ext=8.0, sla=12,
         task="Configuration", block="Awaiting customer data or environment"),
    dict(name="Go-live Readiness", team="Implementation", effort=1.5, ext=4.5, sla=6,
         task="UAT and training", block="Awaiting customer UAT sign-off"),
    dict(name="Activation Handoff", team="Customer Success", effort=0.75, ext=1.0, sla=2,
         task="Activation handoff", block="Awaiting customer contact"),
]
LAST_STAGE = len(STAGES) - 1
CPLX_MULT = {"Low": 0.6, "Medium": 1.0, "High": 1.9}   # effort multiplier
EXT_MULT = {"Low": 0.7, "Medium": 1.0, "High": 1.8}    # external-wait multiplier
RETURN_STAGES = (1, 2, 3, 4)
ROUTES = {1: [0, 1], 2: [0, 1, 2], 3: [1, 3], 4: [1, 4]}   # re-entry path after a return
MINOR_P = {1: 0.02, 2: 0.025, 3: 0.03}                     # corrections that do not cause a loop

RETURN_REASONS = {
    1: [("Missing required fields", .45), ("Incorrect pricing or contract data", .25), ("Missing customer contact details", .30)],
    2: [("Missing signed contract documents", .55), ("Non-standard terms not flagged", .45)],
    3: [("Incorrect billing details", .60), ("Credit information missing", .40)],
    4: [("Unclear requirements", .55), ("Missing technical specification", .45)],
}

TYPE_SPEC = {
    "Standard Subscription": dict(p=.50, seg=[.65, .30, .05], cplx=[.55, .38, .07]),
    "Custom Integration": dict(p=.18, seg=[.20, .55, .25], cplx=[.10, .45, .45]),
    "Enterprise Multi-Entity": dict(p=.12, seg=[0, .30, .70], cplx=[.05, .40, .55]),
    "Reseller/Partner": dict(p=.12, seg=[.50, .50, 0], cplx=[.40, .45, .15]),
    "Pilot-to-Paid": dict(p=.08, seg=[.60, .40, 0], cplx=[.60, .35, .05]),
}
SEGS = ["SMB", "Mid-Market", "Enterprise"]
BANDS = ["Low", "Medium", "High"]
CHANNELS = ["Direct Sales", "Inbound Web", "Partner Referral", "Marketplace"]
CHANNEL_P = [.45, .25, .20, .10]
PRIORITIES = ["Standard", "High", "Urgent"]
PRIORITY_P = [.70, .22, .08]

# ======================================================================
# 3. OWNERS (each owner behaves as one server in a FIFO queue)
# ======================================================================
TEAMS = {  # team: (monthly onboarding hours per 1.0 FTE, base cost INR/hour)
    "Sales": (75, 720), "RevOps": (120, 580), "Legal": (150, 1050),
    "Finance": (95, 680), "Implementation": (180, 640), "Customer Success": (90, 520),
}
EARLY = date(2023, 1, 1)
OWNER_DEF = [  # id, team, role, active_from, active_to, FTE
    *[(f"S0{i}", "Sales", "Account Executive", EARLY, None, 0.8 if i == 6 else 1.0) for i in range(1, 8)],
    ("S08", "Sales", "Account Executive", date(2026, 1, 15), None, 1.0),
    ("R01", "RevOps", "RevOps Lead", EARLY, None, 0.8),
    ("R02", "RevOps", "RevOps Analyst", EARLY, None, 1.0),
    ("R03", "RevOps", "RevOps Analyst", EARLY, None, 1.0),
    ("L01", "Legal", "Legal Counsel", EARLY, None, 1.0),
    ("L02", "Legal", "Contracts Manager", EARLY, None, 1.0),
    ("L03", "Legal", "Paralegal", EARLY, None, 0.5),
    ("F01", "Finance", "Credit Analyst", EARLY, None, 1.0),
    ("F02", "Finance", "Billing Specialist", EARLY, None, 1.0),
    ("F03", "Finance", "Finance Associate", EARLY, None, 0.6),
    ("I01", "Implementation", "Implementation Lead", EARLY, None, 1.0),
    *[(f"I0{i}", "Implementation", "Implementation Specialist", EARLY,
       date(2026, 8, 31) if i == 7 else None, 1.0) for i in range(2, 9)],
    ("I09", "Implementation", "Implementation Specialist", date(2026, 2, 1), None, 1.0),
    ("I10", "Implementation", "Implementation Consultant", EARLY, None, 0.6),
    *[(f"C0{i}", "Customer Success", "Customer Success Manager", EARLY, None, 1.0) for i in range(1, 5)],
]
NEW_REP = "S08"

owners_rows, POOLS = [], {}
for oid, team, role, a_from, a_to, fte in OWNER_DEF:
    base_hours, rate = TEAMS[team]
    hours = round(base_hours * fte)
    cost = int(round(rate * rng.uniform(0.9, 1.15) / 10.0) * 10)
    owners_rows.append(dict(owner_id=oid, team=team, role=role, active_from=a_from.isoformat(),
                            active_to=a_to.isoformat() if a_to else None,
                            monthly_capacity_hours=hours, cost_per_hour=cost, FTE_fraction=fte))
    POOLS.setdefault(team, []).append(dict(
        id=oid, daily=hours / 21.0, speed=float(rng.normal(1.0, 0.07)), free=0.0,
        frm=float(bisect_left(WD, a_from)),
        to=float(bisect_right(WD, a_to)) if a_to else 1e9))


def pick_server(team, t):
    best, best_start = None, 1e18
    for s in POOLS[team]:
        st = max(t, s["free"], s["frm"])
        if st > s["to"]:
            continue
        if st < best_start - 1e-12 or (abs(st - best_start) <= 1e-12 and rng.random() < 0.5):
            best, best_start = s, st
    if best is None:  # everyone inactive: fall back to the earliest-free server
        best = min(POOLS[team], key=lambda s: s["free"])
        best_start = max(t, best["free"])
    return best, best_start


def lognorm_mean(mean, sigma):
    return float(rng.lognormal(np.log(mean) - 0.5 * sigma ** 2, sigma))


# ======================================================================
# 4. DEMAND (Poisson arrivals on working days)
# ======================================================================
PERIOD_MONTHS = [(2025, 10), (2025, 11), (2025, 12), (2026, 1), (2026, 2), (2026, 3),
                 (2026, 4), (2026, 5), (2026, 6), (2026, 7), (2026, 8), (2026, 9)]
SEASON = dict(zip(PERIOD_MONTHS, [.95, .95, 1.10, .85, .95, 1.20, .90, .95, 1.00, 1.00, 1.05, 1.15]))
BASE_DEMAND = 212.0


def monthly_demand(key):
    if key in SEASON:
        i = PERIOD_MONTHS.index(key)
        return BASE_DEMAND * SEASON[key] * (0.85 + 0.30 * i / 11.0)
    return 175.0   # warm-up months


wd_in_month = Counter((d.year, d.month) for d in WD if d <= PERIOD_END)

apps, events, seq = [], [], itertools.count()
customer_pool, cust_counter = [], 0
for i, day in enumerate(WD):
    if day > PERIOD_END:
        break
    key = (day.year, day.month)
    for _ in range(rng.poisson(monthly_demand(key) / wd_in_month[key])):
        created = i + float(rng.random())
        atype = rng.choice(list(TYPE_SPEC), p=[v["p"] for v in TYPE_SPEC.values()])
        spec = TYPE_SPEC[atype]
        channel = "Partner Referral" if (atype == "Reseller/Partner" and rng.random() < .85) \
            else str(rng.choice(CHANNELS, p=CHANNEL_P))
        if customer_pool and rng.random() < 0.10:
            cust = int(rng.choice(customer_pool))
        else:
            cust_counter += 1
            cust = cust_counter
            customer_pool.append(cust)
        apps.append(dict(
            idx=len(apps), created=created, type=str(atype), cust=cust, channel=channel,
            seg=str(rng.choice(SEGS, p=spec["seg"])), cplx=str(rng.choice(BANDS, p=spec["cplx"])),
            prio=str(rng.choice(PRIORITIES, p=PRIORITY_P)),
            route=[], main=-1, loops=0, closed=None, status="Open", cancel_reason=None,
            intake_owner=None, visits=[], reworks=[]))
        heapq.heappush(events, (created, next(seq), len(apps) - 1, 0, False))


# ======================================================================
# 5. SIMULATION
# ======================================================================
def p_return(app, s):
    t = app["type"]
    if s == 1:
        p = 0.16 if t == "Custom Integration" else 0.04
        if app["channel"] == "Partner Referral":
            p += 0.03
        if app["intake_owner"] == NEW_REP:
            p *= 2.0
    elif s == 2:
        p = 0.07 if t == "Enterprise Multi-Entity" else 0.02
    elif s == 3:
        p = 0.06 if t == "Reseller/Partner" else 0.025
    else:
        p = 0.07 if t == "Custom Integration" else 0.02
    return p


def pick_reason(app, s):
    t = app["type"]
    if t == "Custom Integration" and s == 4 and rng.random() < .75:
        return "Missing technical specification"
    if t == "Custom Integration" and s == 1 and rng.random() < .65:
        return "Missing required fields"
    reasons = RETURN_REASONS[s]
    return reasons[int(rng.choice(len(reasons), p=[w for _, w in reasons]))][0]


def source_receiving(s):
    if s == 1:
        return "Sales", "RevOps"
    if s == 2:
        return "Sales", "Legal"
    if s == 3:
        return ("Sales" if rng.random() < .6 else "RevOps"), "Finance"
    return ("RevOps" if rng.random() < .5 else "Sales"), "Implementation"


CANCEL_REASONS = ["Customer withdrew - delay", "Deal lost / contract not signed",
                  "Budget freeze at customer", "Duplicate request"]

while events:
    t, _, a, s, rw = heapq.heappop(events)
    if t > CUT:
        break
    app, st = apps[a], STAGES[s]
    effort = st["effort"] * CPLX_MULT[app["cplx"]] * lognorm_mean(1.0, 0.35) * (0.5 if rw else 1.0)
    srv, start = pick_server(st["team"], t)
    end = start + effort / (srv["daily"] * srv["speed"])
    srv["free"] = end
    ext_mean = st["ext"] * EXT_MULT[app["cplx"]] * (0.8 if app["prio"] == "Urgent" else 1.0) * (0.5 if rw else 1.0)
    ext = lognorm_mean(ext_mean, 0.6)
    exit_t = end + ext
    v = dict(s=s, rw=rw, entered=t, owner=srv["id"], start=start, end=end, exit=exit_t, ext=ext, outcome="Passed")
    app["visits"].append(v)
    if s == 0 and app["intake_owner"] is None:
        app["intake_owner"] = srv["id"]

    # --- cancellation (hazard rises with long waits) ---
    p_c = min(0.15, 0.006 + 0.004 * max(0.0, (exit_t - t) - 6.0)) * (0.5 if rw else 1.0)
    if rng.random() < p_c:
        v["outcome"] = "Cancelled"
        app["closed"], app["status"] = exit_t, "Cancelled"
        if (exit_t - t) > 8 and rng.random() < .6:
            app["cancel_reason"] = "Customer withdrew - delay"
        elif s == 2 and rng.random() < .3:
            app["cancel_reason"] = "Compliance rejected (Legal)"
        elif s == 3 and rng.random() < .3:
            app["cancel_reason"] = "Credit not approved (Finance)"
        else:
            app["cancel_reason"] = str(rng.choice(CANCEL_REASONS))
        continue

    # --- return to an earlier stage (rework loop) ---
    if (not rw) and s in RETURN_STAGES and app["loops"] < 3 and rng.random() < p_return(app, s):
        v["outcome"] = "Returned"
        app["loops"] += 1
        src, recv = source_receiving(s)
        mins = lognorm_mean(60, 0.5) * (1.3 if app["cplx"] == "High" else 1.0)
        app["reworks"].append(dict(stage=s, at=exit_t, code=pick_reason(app, s), src=src, recv=recv,
                                   minutes=mins, loop=True, resolve=None))
        app["route"] = list(ROUTES[s])
        heapq.heappush(events, (exit_t, next(seq), a, app["route"].pop(0), True))
        continue

    # --- minor correction that does not cause a loop ---
    if (not rw) and s in MINOR_P and rng.random() < MINOR_P[s]:
        src, recv = source_receiving(s)
        app["reworks"].append(dict(stage=s, at=float(rng.uniform(start, exit_t)), code=pick_reason(app, s),
                                   src=src, recv=recv, minutes=lognorm_mean(22, 0.5), loop=False, resolve=exit_t))

    # --- pass ---
    app["main"] = max(app["main"], s)
    if rw and not app["route"]:
        for r in reversed(app["reworks"]):
            if r["loop"] and r["resolve"] is None:
                r["resolve"] = exit_t
                break
    if app["route"]:
        heapq.heappush(events, (exit_t, next(seq), a, app["route"].pop(0), True))
    elif app["main"] == LAST_STAGE:
        app["closed"], app["status"] = exit_t, "Completed"
    else:
        heapq.heappush(events, (exit_t, next(seq), a, app["main"] + 1, False))

# ======================================================================
# 6. BUILD TABLES (truncate everything at the extract cutoff)
# ======================================================================
fmt = lambda dt: dt.strftime("%Y-%m-%d %H:%M:%S") if dt is not None else None


def closed_out(app):
    return app["closed"] if (app["closed"] is not None and app["closed"] <= CUT) else None


kept = [a for a in apps if not (closed_out(a) is not None and closed_out(a) < P0)]
kept.sort(key=lambda a: a["created"])

app_rows, stage_rows, task_rows, rework_rows = [], [], [], []
n_stage = n_task = n_rw = 0
for n, app in enumerate(kept, start=1):
    app_id = f"APP-{n:06d}"
    c = closed_out(app)
    status = app["status"] if c is not None else "Open"
    app_rows.append(dict(
        application_id=app_id, customer_id=f"CUST-{app['cust']:04d}", created_at=fmt(wd_to_dt(app["created"])),
        application_type=app["type"], segment=app["seg"], source_channel=app["channel"],
        complexity_band=app["cplx"], priority=app["prio"], final_status=status,
        completed_at=fmt(wd_to_dt(c)) if status == "Completed" else None,
        closed_at=fmt(wd_to_dt(c)) if c is not None else None,
        cancellation_reason=app["cancel_reason"] if status == "Cancelled" else None))

    for v in sorted(app["visits"], key=lambda x: x["entered"]):
        st = STAGES[v["s"]]
        done = v["exit"] <= CUT
        picked = v["start"] <= CUT
        n_stage += 1
        if done:
            status_v = {"Passed": "Completed", "Returned": "Returned", "Cancelled": "Cancelled"}[v["outcome"]]
            reason_v = {"Passed": "Passed", "Returned": "Returned for rework", "Cancelled": "Application cancelled"}[v["outcome"]]
        else:
            status_v, reason_v = ("In Progress" if picked else "Queued"), None
        stage_rows.append(dict(
            stage_event_id=f"STG-{n_stage:06d}", application_id=app_id, stage_name=st["name"],
            entered_at=fmt(wd_to_dt(v["entered"])), exited_at=fmt(wd_to_dt(v["exit"])) if done else None,
            status=status_v, owner_id=v["owner"] if picked else None, exit_reason=reason_v))

        blocked = (v["ext"] > 2.0) if done else (v["end"] <= CUT)
        specs = [(st["task"], v["exit"], True)]
        if v["s"] == 4:
            specs = [("Configuration", v["end"], False), ("Data migration", v["exit"], True)]
        elif v["s"] == 2 and app["cplx"] == "High":
            specs = [("Contract and risk review", v["exit"], True), ("Security and data-protection review", v["exit"], False)]
        for ttype, t_done, is_main in specs:
            n_task += 1
            finished = t_done <= CUT
            task_rows.append(dict(
                task_id=f"TSK-{n_task:06d}", application_id=app_id, task_type=ttype,
                created_at=fmt(wd_to_dt(v["entered"])),
                assigned_at=fmt(wd_to_dt(v["start"])) if picked else None,
                due_at=fmt(wd_to_dt(v["entered"] + st["sla"])),
                completed_at=fmt(wd_to_dt(t_done)) if finished else None,
                owner_id=v["owner"] if picked else None,
                task_status=("Cancelled" if (finished and v["outcome"] == "Cancelled" and is_main)
                             else "Completed" if finished else ("In Progress" if picked else "Not Started")),
                blocked_reason=st["block"] if (blocked and is_main) else None))

    for r in app["reworks"]:
        if r["at"] > CUT:
            continue
        n_rw += 1
        resolved = r["resolve"] is not None and r["resolve"] <= CUT
        rework_rows.append(dict(
            rework_event_id=f"RWK-{n_rw:06d}", application_id=app_id, stage_name=STAGES[r["stage"]]["name"],
            event_at=fmt(wd_to_dt(r["at"])), reason_code=r["code"], source_team=r["src"],
            receiving_team=r["recv"], estimated_minutes=int(round(r["minutes"])),
            resolution_status="Resolved" if resolved else "Open"))

applications = pd.DataFrame(app_rows)
stage_history = pd.DataFrame(stage_rows)
tasks = pd.DataFrame(task_rows)
rework_events = pd.DataFrame(rework_rows)
owners = pd.DataFrame(owners_rows)
cal_days = pd.date_range(SIM_START, PERIOD_END)
calendar = pd.DataFrame(dict(
    date_key=[int(d.strftime("%Y%m%d")) for d in cal_days], calendar_date=[d.date().isoformat() for d in cal_days],
    weekday=[d.strftime("%A") for d in cal_days], month=[d.strftime("%Y-%m") for d in cal_days],
    holiday_flag=[int(d.date() in HOLIDAYS) for d in cal_days],
    working_day_flag=[int(d.weekday() < 5 and d.date() not in HOLIDAYS) for d in cal_days]))


# ======================================================================
# 7. INTENTIONAL DATA-QUALITY PROBLEMS (documented; flagged, never silently fixed)
# ======================================================================
def sample_idx(df, mask, n):
    pool = df.index[mask].to_numpy()
    return rng.choice(pool, size=min(n, len(pool)), replace=False)


injected = {}
# stage_history
n_sh = len(stage_history)
ix = sample_idx(stage_history, stage_history["exited_at"].notna(), round(0.003 * n_sh))
stage_history.loc[ix, ["entered_at", "exited_at"]] = stage_history.loc[ix, ["exited_at", "entered_at"]].values
injected["stage_history: exited_at earlier than entered_at (swapped)"] = len(ix)
ix = sample_idx(stage_history, stage_history["owner_id"].notna() & stage_history["exited_at"].notna(), round(0.005 * n_sh))
stage_history.loc[ix, "owner_id"] = None
injected["stage_history: missing owner_id on a worked stage"] = len(ix)
ix = sample_idx(stage_history, stage_history["exited_at"].notna(), round(0.003 * n_sh))
dups = stage_history.loc[ix].copy()
dups["stage_event_id"] = [f"STG-{n_sh + k + 1:06d}" for k in range(len(dups))]
stage_history = pd.concat([stage_history, dups], ignore_index=True)
injected["stage_history: duplicate-looking rows (new stage_event_id, same content)"] = len(dups)
# applications
comp = applications.index[applications["final_status"] == "Completed"].to_numpy()
canc = applications.index[applications["final_status"] == "Cancelled"].to_numpy()
pick = rng.choice(comp, size=12, replace=False)
applications.loc[pick[:3], "final_status"] = "Complete"
applications.loc[pick[3:6], "final_status"] = "completed"
injected["applications: invalid status 'Complete' / 'completed'"] = 6
applications.loc[pick[6:12], "completed_at"] = None
injected["applications: Completed but completed_at missing"] = 6
ix2 = rng.choice(canc, size=2, replace=False)
applications.loc[ix2, "final_status"] = "Canceled"
injected["applications: invalid status 'Canceled'"] = 2
bad_seq = rng.choice(np.setdiff1d(comp, pick), size=5, replace=False)
applications.loc[bad_seq, "completed_at"] = (pd.to_datetime(applications.loc[bad_seq, "completed_at"]) - pd.Timedelta(days=3)).dt.strftime("%Y-%m-%d %H:%M:%S")
injected["applications: completed_at earlier than final stage exit (impossible sequence)"] = 5
# tasks
n_tk = len(tasks)
ix = sample_idx(tasks, tasks["completed_at"].notna() & tasks["assigned_at"].notna(), round(0.01 * n_tk))
tasks.loc[ix, "assigned_at"] = None
injected["tasks: completed task with missing assigned_at"] = len(ix)
ix = sample_idx(tasks, tasks["due_at"].notna(), round(0.005 * n_tk))
tasks.loc[ix, "due_at"] = (pd.to_datetime(tasks.loc[ix, "created_at"]) - pd.Timedelta(days=1)).dt.strftime("%Y-%m-%d %H:%M:%S")
injected["tasks: due_at earlier than created_at"] = len(ix)
# rework_events
n_rk = len(rework_events)
ix = sample_idx(rework_events, rework_events["reason_code"].notna(), round(0.02 * n_rk))
rework_events.loc[ix, "reason_code"] = rework_events.loc[ix, "reason_code"].str.lower()
injected["rework_events: reason_code in inconsistent case"] = len(ix)
ix = sample_idx(rework_events, rework_events["estimated_minutes"] > 0, round(0.03 * n_rk))
rework_events.loc[ix, "estimated_minutes"] = 0
injected["rework_events: estimated_minutes = 0"] = len(ix)
ix = sample_idx(rework_events, rework_events["resolution_status"] == "Resolved", round(0.02 * n_rk))
rework_events.loc[ix, "resolution_status"] = "Invalid"
injected["rework_events: resolution_status = Invalid"] = len(ix)
orph = rework_events.sample(3, random_state=SEED).copy()
orph["rework_event_id"] = [f"RWK-{n_rk + k + 1:06d}" for k in range(3)]
orph["application_id"] = ["APP-999001", "APP-999002", "APP-999003"]
rework_events = pd.concat([rework_events, orph], ignore_index=True)
injected["rework_events: orphan application_id (not in applications)"] = 3

# ======================================================================
# 8. WRITE CSVs
# ======================================================================
tables = dict(applications=applications, stage_history=stage_history, tasks=tasks,
              owners=owners, rework_events=rework_events, calendar=calendar)
for name, df in tables.items():
    df.to_csv(RAW / f"{name}.csv", index=False)

# ======================================================================
# 9. VALIDATION + SUMMARY (checks run on the generated, pre-cleaning tables)
# ======================================================================
lines = ["FLOW - generation summary (synthetic data)", f"seed = {SEED}", ""]
lines.append("ROW COUNTS")
for name, df in tables.items():
    lines.append(f"  {name:<14}{len(df):>8,}")
lines += ["", "PRIMARY KEY UNIQUENESS"]
pks = dict(applications="application_id", stage_history="stage_event_id", tasks="task_id",
           owners="owner_id", rework_events="rework_event_id", calendar="date_key")
for name, pk in pks.items():
    lines.append(f"  {name:<14}{'PASS' if tables[name][pk].is_unique else 'FAIL'}")
lines += ["", "FOREIGN KEYS (rows failing; planted orphans are expected in rework_events)"]
app_ids, own_ids = set(applications["application_id"]), set(owners["owner_id"])
for tname in ("stage_history", "tasks", "rework_events"):
    lines.append(f"  {tname}.application_id -> applications : {(~tables[tname]['application_id'].isin(app_ids)).sum()}")
for tname in ("stage_history", "tasks"):
    bad = (~tables[tname]["owner_id"].dropna().isin(own_ids)).sum()
    lines.append(f"  {tname}.owner_id -> owners : {bad}")

ap = applications.copy()
ap["created"] = pd.to_datetime(ap["created_at"])
ap["closed"] = pd.to_datetime(ap["closed_at"])
ap["status_clean"] = ap["final_status"].str.strip().str.lower().replace({"complete": "completed", "canceled": "cancelled"})
lines += ["", "MONTHLY RECONCILIATION  (opening + received - completed - cancelled = closing)",
          f"  {'month':<9}{'opening':>8}{'received':>9}{'completed':>10}{'cancelled':>10}{'closing':>8}  check"]
all_ok = True
for (y, m) in PERIOD_MONTHS:
    ms = pd.Timestamp(y, m, 1)
    me = ms + pd.offsets.MonthBegin(1)
    opening = ((ap["created"] < ms) & (ap["closed"].isna() | (ap["closed"] >= ms))).sum()
    received = ((ap["created"] >= ms) & (ap["created"] < me)).sum()
    inm = (ap["closed"] >= ms) & (ap["closed"] < me)
    completed = (inm & (ap["status_clean"] == "completed")).sum()
    cancelled = (inm & (ap["status_clean"] == "cancelled")).sum()
    closing = ((ap["created"] < me) & (ap["closed"].isna() | (ap["closed"] >= me))).sum()
    ok = opening + received - completed - cancelled == closing
    all_ok &= bool(ok)
    lines.append(f"  {y}-{m:02d}  {opening:>8}{received:>9}{completed:>10}{cancelled:>10}{closing:>8}  {'PASS' if ok else 'FAIL'}")
lines.append(f"  overall: {'PASS' if all_ok else 'FAIL'}")
lines += ["", "INJECTED DATA-QUALITY PROBLEMS (answer key: your Phase 3 profiling should find these)"]
for k, n in injected.items():
    lines.append(f"  {n:>5}  {k}")
summary = "\n".join(lines)
(HERE / "generation_summary.txt").write_text(summary, encoding="utf-8")
print(summary)