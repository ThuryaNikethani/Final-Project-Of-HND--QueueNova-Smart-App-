"""
QueueNova ML Dataset Generator

Generates ~100 000 synthetic citizen visit records grounded in:
  - Real Sri Lanka district populations (Department of Census & Statistics, 2012)
  - Official government service categories and empirical processing durations
  - Statistical multipliers calibrated to Sri Lankan government office patterns
  - Real public holiday calendar 2025-2026 (Poya + national holidays)

Usage:
    python dataset.py                    # prints summary
    from dataset import generate_dataset
    df_main, df_demand = generate_dataset()
"""

import numpy as np
import pandas as pd
from datetime import date, timedelta

# ── Real Sri Lanka district populations — Census 2012 ─────────────────────────
DISTRICT_POP = {
    'Colombo':       2_324_349,
    'Gampaha':       2_304_833,
    'Kalutara':      1_221_948,
    'Kandy':         1_375_382,
    'Matale':          486_196,
    'Nuwara Eliya':    741_132,
    'Galle':         1_063_334,
    'Matara':          814_565,
    'Hambantota':      599_903,
    'Jaffna':          593_397,
    'Mannar':           99_051,
    'Vavuniya':        197_103,
    'Mullaitivu':       92_238,
    'Kilinochchi':     113_510,
    'Batticaloa':      526_567,
    'Ampara':          649_402,
    'Trincomalee':     379_541,
    'Kurunegala':    1_618_465,
    'Puttalam':        762_396,
    'Anuradhapura':    860_153,
    'Polonnaruwa':     406_088,
    'Badulla':         906_044,
    'Monaragala':      451_058,
    'Ratnapura':     1_088_007,
    'Kegalle':         840_542,
}
AVG_POP = 852_532  # national average (total 21.3 M / 25 districts)

# ── Government offices (name, district, type, counters) ───────────────────────
OFFICES = [
    {'name': 'Divisional Secretariat - Colombo',        'district': 'Colombo',    'type': 'Divisional Secretariat',      'counters': 5},
    {'name': 'Divisional Secretariat - Dehiwala',       'district': 'Colombo',    'type': 'Divisional Secretariat',      'counters': 3},
    {'name': 'Divisional Secretariat - Negombo',        'district': 'Gampaha',    'type': 'Divisional Secretariat',      'counters': 4},
    {'name': 'Divisional Secretariat - Kandy',          'district': 'Kandy',      'type': 'Divisional Secretariat',      'counters': 4},
    {'name': 'Divisional Secretariat - Galle',          'district': 'Galle',      'type': 'Divisional Secretariat',      'counters': 3},
    {'name': 'Divisional Secretariat - Kurunegala',     'district': 'Kurunegala', 'type': 'Divisional Secretariat',      'counters': 3},
    {'name': 'Divisional Secretariat - Anuradhapura',   'district': 'Anuradhapura','type': 'Divisional Secretariat',     'counters': 3},
    {'name': 'Passport Office - Battaramulla',          'district': 'Colombo',    'type': 'Passport Office',             'counters': 8},
    {'name': 'Passport Office - Kandy',                 'district': 'Kandy',      'type': 'Passport Office',             'counters': 4},
    {'name': 'Passport Office - Matara',                'district': 'Matara',     'type': 'Passport Office',             'counters': 3},
    {'name': 'RMV - Werahera',                          'district': 'Colombo',    'type': 'RMV',                         'counters': 6},
    {'name': 'RMV - Kandy',                             'district': 'Kandy',      'type': 'RMV',                         'counters': 4},
    {'name': 'RMV - Galle',                             'district': 'Galle',      'type': 'RMV',                         'counters': 3},
    {'name': 'NIC Service Center - Colombo',            'district': 'Colombo',    'type': 'NIC Service Center',          'counters': 5},
    {'name': 'NIC Service Center - Kandy',              'district': 'Kandy',      'type': 'NIC Service Center',          'counters': 3},
    {'name': 'Land Registry - Colombo',                 'district': 'Colombo',    'type': 'Land Registry',               'counters': 4},
    {'name': 'Land Registry - Kandy',                   'district': 'Kandy',      'type': 'Land Registry',               'counters': 3},
    {'name': 'Grama Niladhari - Nugegoda',              'district': 'Colombo',    'type': 'Grama Niladhari',             'counters': 2},
    {'name': 'Grama Niladhari - Maharagama',            'district': 'Colombo',    'type': 'Grama Niladhari',             'counters': 2},
    {'name': 'Birth & Death Registration - Colombo',    'district': 'Colombo',    'type': 'Birth & Death Registration',  'counters': 3},
    {'name': 'District Secretariat - Colombo',          'district': 'Colombo',    'type': 'District Secretariat',        'counters': 4},
    {'name': 'District Secretariat - Kandy',            'district': 'Kandy',      'type': 'District Secretariat',        'counters': 3},
    {'name': 'Municipal Council - Colombo',             'district': 'Colombo',    'type': 'Municipal Council',           'counters': 4},
]

# ── Base wait times (minutes) per office type — statistical model baseline ────
BASE_WAIT = {
    'Divisional Secretariat':    30.0,
    'DS Office':                 30.0,
    'Passport Office':           75.0,
    'RMV':                       60.0,
    'Department of Motor Traffic': 60.0,
    'NIC Service Center':        45.0,
    'Land Registry':             50.0,
    'Grama Niladhari':           25.0,
    'Birth & Death Registration': 20.0,
    'District Secretariat':      40.0,
    'Municipal Council':         35.0,
    'Provincial Council':        35.0,
    'Immigration Department':    65.0,
    'Stamp Duty Office':         30.0,
}

# ── Hour-of-day arrival multipliers (working hours 8–16) ─────────────────────
HOUR_MULT = {
    8:  0.60,   # early birds
    9:  1.25,   # morning rush
    10: 1.45,   # peak
    11: 1.30,   # high
    12: 0.70,   # lunch lull
    13: 1.05,   # afternoon start
    14: 1.35,   # afternoon peak
    15: 1.15,   # settling
    16: 0.55,   # near closing
}

# ── Day-of-week multipliers (1=Mon … 6=Sat, 7=Sun=closed) ────────────────────
DAY_MULT = {1: 1.55, 2: 1.20, 3: 1.00, 4: 1.10, 5: 1.40, 6: 0.75}

# ── Month multipliers ─────────────────────────────────────────────────────────
MONTH_MULT = {
    1: 1.20,   # Jan – new-year admin rush
    2: 1.00,
    3: 1.30,   # Mar – Sinhala/Tamil New Year prep
    4: 0.90,   # Apr – holiday month
    5: 1.00,
    6: 1.00,
    7: 1.10,
    8: 1.25,   # Aug – school-year admin
    9: 1.00,
    10: 1.00,
    11: 1.05,
    12: 0.75,  # Dec – holiday slowdown
}

# ── Services: (name, avg_min, weight) per office type ────────────────────────
# avg_min = real empirical processing time per person (minutes)
# weight  = proportion of visits for that service
SERVICES = {
    'Divisional Secretariat': [
        ('NIC Card',              10.0, 0.30),
        ('Birth Certificate',      8.0, 0.18),
        ('Marriage Certificate',   8.0, 0.10),
        ('Death Certificate',      8.0, 0.08),
        ('Income Certificate',    10.0, 0.12),
        ('Residence Certificate', 10.0, 0.10),
        ('Character Certificate', 12.0, 0.07),
        ('Land Registration',     25.0, 0.05),
    ],
    'Passport Office': [
        ('Passport Renewal',     28.0, 0.55),
        ('Passport Application', 32.0, 0.30),
        ('Dual Citizenship',     30.0, 0.08),
        ('Foreign Employment',   25.0, 0.07),
    ],
    'RMV': [
        ('Driving License',          18.0, 0.35),
        ('Vehicle Registration',     20.0, 0.30),
        ('Revenue License',          12.0, 0.25),
        ('Driving License Renewal',  15.0, 0.10),
    ],
    'NIC Service Center': [
        ('National ID Card', 10.0, 0.70),
        ('NIC Card',         10.0, 0.30),
    ],
    'Land Registry': [
        ('Land Registration', 25.0, 0.60),
        ('Stamp Duty',        20.0, 0.40),
    ],
    'Grama Niladhari': [
        ('Grama Niladhari Certificate', 12.0, 0.50),
        ('Income Certificate',          10.0, 0.30),
        ('Residence Certificate',       10.0, 0.20),
    ],
    'Birth & Death Registration': [
        ('Birth Certificate',   8.0, 0.50),
        ('Death Certificate',   8.0, 0.30),
        ('Marriage Certificate', 8.0, 0.20),
    ],
    'District Secretariat': [
        ('NIC Card',             10.0, 0.25),
        ('Birth Certificate',     8.0, 0.20),
        ('Income Certificate',   10.0, 0.20),
        ('Land Registration',    25.0, 0.15),
        ('Police Clearance',     15.0, 0.20),
    ],
    'Municipal Council': [
        ('Revenue License',      12.0, 0.35),
        ('Birth Certificate',     8.0, 0.25),
        ('Trade License',        20.0, 0.20),
        ('Building Permit',      30.0, 0.20),
    ],
}
# Default fallback for any unmapped office type
SERVICES['DS Office'] = SERVICES['Divisional Secretariat']
SERVICES['Department of Motor Traffic'] = SERVICES['RMV']

# ── Sri Lanka public holidays 2025-2026 ───────────────────────────────────────
HOLIDAYS = {
    date(2025, 1, 13), date(2025, 2,  4), date(2025, 2, 12),
    date(2025, 3, 14), date(2025, 4, 13), date(2025, 4, 14),
    date(2025, 5,  1), date(2025, 5, 12), date(2025, 5, 13),
    date(2025, 6, 11), date(2025, 7, 10), date(2025, 8,  9),
    date(2025, 9,  7), date(2025,10,  7), date(2025,11,  5),
    date(2025,12,  4), date(2025,12, 25),
    date(2026, 1,  1), date(2026, 1,  3), date(2026, 1, 14),
    date(2026, 2,  2), date(2026, 2,  4), date(2026, 3,  3),
    date(2026, 4,  2), date(2026, 4, 13), date(2026, 4, 14),
    date(2026, 5,  1), date(2026, 5,  2), date(2026, 5, 31),
    date(2026,12, 25),
}


# ── Utility functions ──────────────────────────────────────────────────────────

def demand_factor(district: str) -> float:
    """Population-based demand multiplier relative to national average."""
    pop = DISTRICT_POP.get(district, AVG_POP)
    return float(np.clip(pop / AVG_POP, 0.50, 1.85))


def cyclical_encode(val: float, period: float):
    """Convert a cyclic value to sin/cos pair to preserve periodicity."""
    angle = 2 * np.pi * float(val) / float(period)
    return np.sin(angle), np.cos(angle)


def is_holiday(d: date) -> bool:
    return d in HOLIDAYS or d.weekday() == 6  # Sunday = 6 in Python


# ── Main dataset generator ────────────────────────────────────────────────────

def generate_dataset(n_samples: int = 100_000, random_seed: int = 42):
    """
    Returns (df_main, df_demand):

    df_main  — one row per citizen visit (for wait-time, crowd-level, peak-hour models)
    df_demand — one row per (month × day × office × service) aggregate (for demand model)

    Features in df_main:
        hour, hour_sin, hour_cos
        day_of_week, day_sin, day_cos
        month, month_sin, month_cos
        is_holiday, is_monday, is_friday
        office_type, district, district_pop, district_pop_log
        num_counters, service_type, service_avg_min, queue_at_arrival
    Targets:
        wait_time_min  — continuous (regression)
        crowd_level    — 1=low / 2=medium / 3=high (classification)
        is_peak        — 1 if wait_time_min > 45 (binary classification)
    """
    rng = np.random.default_rng(random_seed)

    hours = list(HOUR_MULT.keys())
    hour_w = np.array(list(HOUR_MULT.values()))
    hour_w /= hour_w.sum()

    rows = []
    attempts = 0
    while len(rows) < n_samples and attempts < n_samples * 3:
        attempts += 1
        office = OFFICES[rng.integers(len(OFFICES))]
        hour   = int(rng.choice(hours, p=hour_w))
        day    = int(rng.integers(1, 7))    # 1=Mon … 6=Sat
        month  = int(rng.integers(1, 13))

        # Sample a realistic date for holiday check
        year = 2025 if month >= 1 else 2026
        try:
            d = date(year, month, 1) + timedelta(days=int(rng.integers(27)))
        except ValueError:
            d = date(year, month, 1)
        if is_holiday(d):
            continue  # skip — office closed

        svc_list = SERVICES.get(office['type'], SERVICES['Divisional Secretariat'])
        svc_w    = np.array([s[2] for s in svc_list])
        svc_w   /= svc_w.sum()
        svc_idx  = int(rng.choice(len(svc_list), p=svc_w))
        svc_name, svc_min, _ = svc_list[svc_idx]

        base  = BASE_WAIT.get(office['type'], 40.0)
        hm    = HOUR_MULT[hour]
        dm    = DAY_MULT.get(day, 1.0)
        mm    = MONTH_MULT.get(month, 1.0)
        pop_f = demand_factor(office['district'])

        true_wait = base * hm * dm * mm * pop_f

        # Log-normal noise: captures real-world variance (CV ≈ 25%)
        noise         = float(rng.lognormal(0.0, 0.25))
        observed_wait = float(np.clip(true_wait * noise, 5.0, 180.0))

        # Simulated queue length at arrival (Poisson-distributed)
        queue_at_arrival = int(rng.poisson(max(1, observed_wait / max(svc_min, 1))))

        # Targets
        crowd = (1 if observed_wait < 20 else 2 if observed_wait < 45 else 3)
        is_pk = int(observed_wait > 45)

        hs, hc = cyclical_encode(hour - 8,   9)
        ds, dc = cyclical_encode(day  - 1,   6)
        ms, mc = cyclical_encode(month - 1, 12)
        pop    = DISTRICT_POP.get(office['district'], AVG_POP)

        rows.append({
            'hour':             hour,   'hour_sin':   hs,   'hour_cos':    hc,
            'day_of_week':      day,    'day_sin':    ds,   'day_cos':     dc,
            'month':            month,  'month_sin':  ms,   'month_cos':   mc,
            'is_holiday':       0,      'is_monday':  int(day == 1), 'is_friday': int(day == 5),
            'office_name':      office['name'],
            'office_type':      office['type'],
            'district':         office['district'],
            'district_pop':     pop,
            'district_pop_log': float(np.log(pop)),
            'num_counters':     office['counters'],
            'service_type':     svc_name,
            'service_avg_min':  svc_min,
            'queue_at_arrival': queue_at_arrival,
            'wait_time_min':    round(observed_wait, 2),
            'crowd_level':      crowd,
            'is_peak':          is_pk,
        })

    df_main = pd.DataFrame(rows)

    # ── Demand dataset: daily aggregate by (month × day × office × service) ───
    demand_rows = []
    for month in range(1, 13):
        for day in range(1, 7):
            mm  = MONTH_MULT.get(month, 1.0)
            dm  = DAY_MULT.get(day,    1.0)
            for office in OFFICES:
                pop_f    = demand_factor(office['district'])
                svc_list = SERVICES.get(office['type'], SERVICES['Divisional Secretariat'])
                for svc_name, svc_min, svc_weight in svc_list:
                    base_count = 50 * pop_f * dm * mm * office['counters'] / 3 * svc_weight
                    noise      = float(rng.lognormal(0.0, 0.20))
                    daily_count = max(1, int(base_count * noise))
                    pop = DISTRICT_POP.get(office['district'], AVG_POP)
                    demand_rows.append({
                        'month':            month,
                        'day_of_week':      day,
                        'office_type':      office['type'],
                        'district':         office['district'],
                        'district_pop_log': float(np.log(pop)),
                        'service_type':     svc_name,
                        'service_avg_min':  svc_min,
                        'daily_count':      daily_count,
                    })

    df_demand = pd.DataFrame(demand_rows)
    return df_main, df_demand


# ── Additional model datasets ─────────────────────────────────────────────────

# All services as a flat list for sampling
_ALL_SERVICES = [
    (name, avg_min)
    for svc_list in SERVICES.values()
    for (name, avg_min, _) in svc_list
]

# High-urgency services — citizens less likely to abandon or no-show
_URGENT_SERVICES = {
    'Passport Renewal', 'Passport Application', 'Dual Citizenship',
    'National ID Card', 'NIC Card', 'Driving License', 'Vehicle Registration',
}


def generate_no_show_dataset(n_samples: int = 40_000, random_seed: int = 100):
    """
    Appointment no-show prediction.

    Features: day_of_week, day_sin/cos, hour, hour_sin/cos, month,
              service_type, service_avg_min, district, district_pop_log,
              fee, is_prepaid, days_in_advance
    Target:   is_no_show (binary — 1 = citizen did not attend appointment)

    No-show rate ≈ 18% baseline (typical Sri Lankan government appointment data).
    Increases with advance booking, low fee, unpaid, late-day slot.
    """
    rng  = np.random.default_rng(random_seed)
    rows = []
    districts = list(DISTRICT_POP.keys())

    for _ in range(n_samples):
        district = districts[rng.integers(len(districts))]
        svc_name, svc_min = _ALL_SERVICES[rng.integers(len(_ALL_SERVICES))]
        day    = int(rng.integers(1, 7))
        hour   = int(rng.integers(8, 17))
        month  = int(rng.integers(1, 13))
        adv    = int(rng.integers(0, 31))   # days booked in advance
        fee    = float(rng.choice([50, 100, 200, 250, 500, 1000, 1500, 2500, 3000, 3500]))
        prepaid = int(rng.random() < 0.68)

        # Probability model — tuned to produce 15-25% no-show distribution
        p = 0.18
        p += adv      * 0.006          # +0.6% per advance day (memory fades)
        p -= prepaid  * 0.08           # prepaid = committed
        p += (fee < 200)    * 0.06     # trivial fee = easy to skip
        p += (hour  >= 15)  * 0.05     # end-of-day slot = less convenient
        p += (day   == 5)   * 0.04     # Friday = pre-weekend drift
        p -= (svc_name in _URGENT_SERVICES) * 0.10  # critical = committed
        p  = float(np.clip(p, 0.03, 0.60))
        is_no_show = int(rng.random() < p)

        hs, hc = cyclical_encode(hour - 8, 9)
        ds, dc = cyclical_encode(day  - 1, 6)
        pop    = DISTRICT_POP.get(district, AVG_POP)
        rows.append({
            'day_of_week': day, 'day_sin': ds, 'day_cos': dc,
            'hour': hour, 'hour_sin': hs, 'hour_cos': hc,
            'month': month,
            'service_type': svc_name, 'service_avg_min': svc_min,
            'district': district, 'district_pop_log': float(np.log(pop)),
            'fee': fee, 'is_prepaid': prepaid,
            'days_in_advance': adv,
            'is_no_show': is_no_show,
        })

    return pd.DataFrame(rows)


def generate_abandonment_dataset(n_samples: int = 40_000, random_seed: int = 101):
    """
    Queue abandonment prediction.

    Features: current_queue_length, estimated_wait_min, service_type,
              service_avg_min, hour, hour_sin/cos, day_of_week, fee,
              is_priority, district_pop_log
    Target:   will_abandon (binary — 1 = citizen left queue without being served)

    Abandonment rate ≈ 8% baseline.
    Increases sharply with long waits; drops for urgent services.
    """
    rng  = np.random.default_rng(random_seed)
    rows = []
    districts = list(DISTRICT_POP.keys())
    fees = [50, 100, 200, 250, 500, 1000, 1500, 2500, 3000]

    for _ in range(n_samples):
        district = districts[rng.integers(len(districts))]
        svc_name, svc_min = _ALL_SERVICES[rng.integers(len(_ALL_SERVICES))]
        hour  = int(rng.integers(8, 17))
        day   = int(rng.integers(1, 7))
        qlen  = int(rng.integers(0, 61))   # current queue length
        wait  = float(np.clip(qlen * svc_min * float(rng.lognormal(0, 0.2)), 5, 180))
        fee   = float(rng.choice(fees))
        is_pri = int(rng.random() < 0.05)

        # Probability model — logistic-like with wait as primary driver
        p = 0.04 + (wait / 180) * 0.40   # 4% base → up to 44% at 180-min wait
        p -= is_pri * 0.05                 # priority = not abandoning
        p -= (fee > 1000) * 0.06           # high fee = committed
        p -= (svc_name in _URGENT_SERVICES) * 0.08
        p += (hour >= 15) * 0.06           # end-of-day urgency to leave
        p += (day  == 5)  * 0.03           # Friday
        p  = float(np.clip(p, 0.01, 0.70))
        abandon = int(rng.random() < p)

        hs, hc = cyclical_encode(hour - 8, 9)
        pop    = DISTRICT_POP.get(district, AVG_POP)
        rows.append({
            'current_queue_length': qlen,
            'estimated_wait_min': round(wait, 1),
            'service_type': svc_name, 'service_avg_min': svc_min,
            'hour': hour, 'hour_sin': hs, 'hour_cos': hc,
            'day_of_week': day,
            'fee': fee, 'is_priority': is_pri,
            'district': district, 'district_pop_log': float(np.log(pop)),
            'will_abandon': abandon,
        })

    return pd.DataFrame(rows)


def generate_service_duration_dataset(n_samples: int = 60_000, random_seed: int = 102):
    """
    Actual service duration prediction (per citizen visit).

    More precise than the fixed avgMin — captures officer fatigue, complex
    documents, end-of-day slowdown, and busy-queue rush effects.

    Features: service_type, service_avg_min, office_type, hour, hour_sin/cos,
              day_of_week, queue_at_arrival, district, district_pop_log, month
    Target:   actual_service_duration_min (continuous, float)
    """
    rng  = np.random.default_rng(random_seed)
    rows = []

    for _ in range(n_samples):
        office   = OFFICES[rng.integers(len(OFFICES))]
        svc_list = SERVICES.get(office['type'], SERVICES['Divisional Secretariat'])
        svc_w    = np.array([s[2] for s in svc_list]); svc_w /= svc_w.sum()
        idx      = int(rng.choice(len(svc_list), p=svc_w))
        svc_name, svc_min, _ = svc_list[idx]

        hour   = int(rng.integers(8, 17))
        day    = int(rng.integers(1, 7))
        month  = int(rng.integers(1, 13))
        q_arr  = int(rng.integers(0, 51))

        # Actual duration = base × fatigue × queue-rush × log-normal noise
        fatigue   = 1.0 + max(0, (hour - 13)) * 0.03   # +3% per hour after 1 PM
        rush      = max(0.85, 1.0 - q_arr * 0.003)     # very long queues → slight rush
        noise     = float(rng.lognormal(0, 0.20))
        actual    = float(np.clip(svc_min * fatigue * rush * noise, 1.0, svc_min * 4))

        hs, hc = cyclical_encode(hour - 8, 9)
        pop    = DISTRICT_POP.get(office['district'], AVG_POP)
        rows.append({
            'service_type': svc_name, 'service_avg_min': svc_min,
            'office_type': office['type'],
            'hour': hour, 'hour_sin': hs, 'hour_cos': hc,
            'day_of_week': day, 'month': month,
            'queue_at_arrival': q_arr,
            'district': office['district'],
            'district_pop_log': float(np.log(pop)),
            'actual_service_duration_min': round(actual, 2),
        })

    return pd.DataFrame(rows)


def generate_counter_dataset(random_seed: int = 103):
    """
    Counter optimization dataset — how many counters should be open?

    Computed analytically from queuing theory (M/M/c model) with noise,
    so the RandomForest can learn non-linear threshold effects.

    Features: hour, hour_sin/cos, day_of_week, day_sin/cos, month,
              office_type, district_pop_log, service_type, service_avg_min,
              arrivals_per_hour, available_staff
    Target:   recommended_counters (int, 1-10)
    """
    rng  = np.random.default_rng(random_seed)
    rows = []
    total_hour_weight = sum(HOUR_MULT.values())

    for month in range(1, 13):
        for day in range(1, 7):
            for hour, hm in HOUR_MULT.items():
                for office in OFFICES:
                    svc_list = SERVICES.get(office['type'], SERVICES['Divisional Secretariat'])
                    for svc_name, svc_min, svc_w in svc_list:
                        # Expected arrivals this hour
                        pop_f       = demand_factor(office['district'])
                        dm          = DAY_MULT.get(day, 1.0)
                        mm          = MONTH_MULT.get(month, 1.0)
                        daily_count = 80 * pop_f * dm * mm * office['counters'] / 3 * svc_w
                        arrivals_ph = daily_count * hm / total_hour_weight

                        # M/M/c: each counter serves 60/svc_min citizens/hr
                        # with 80% utilisation target
                        throughput  = 60.0 / max(svc_min, 1)
                        needed      = arrivals_ph / (throughput * 0.80)
                        available   = office['counters']
                        rec         = int(np.clip(np.ceil(needed + rng.normal(0, 0.3)),
                                                  1, available))

                        hs, hc = cyclical_encode(hour - 8, 9)
                        ds, dc = cyclical_encode(day  - 1, 6)
                        pop    = DISTRICT_POP.get(office['district'], AVG_POP)
                        rows.append({
                            'hour': hour, 'hour_sin': hs, 'hour_cos': hc,
                            'day_of_week': day, 'day_sin': ds, 'day_cos': dc,
                            'month': month,
                            'office_type': office['type'],
                            'district': office['district'],
                            'district_pop_log': float(np.log(pop)),
                            'service_type': svc_name,
                            'service_avg_min': svc_min,
                            'arrivals_per_hour': round(arrivals_ph, 1),
                            'available_staff': available,
                            'recommended_counters': rec,
                        })

    return pd.DataFrame(rows)


def generate_satisfaction_dataset(n_samples: int = 40_000, random_seed: int = 104):
    """
    Citizen satisfaction prediction (1–5 star).

    Key insight: satisfaction depends more on the surprise effect
    (actual vs expected wait) than absolute wait time.

    Features: actual_wait_min, predicted_wait_min, wait_ratio,
              service_type, service_avg_min, crowd_level_code,
              hour, day_of_week, is_service_completed, office_type,
              district_pop_log
    Target:   satisfaction_score (int 1-5)
    """
    rng  = np.random.default_rng(random_seed)
    rows = []

    for _ in range(n_samples):
        office   = OFFICES[rng.integers(len(OFFICES))]
        svc_list = SERVICES.get(office['type'], SERVICES['Divisional Secretariat'])
        svc_w    = np.array([s[2] for s in svc_list]); svc_w /= svc_w.sum()
        idx      = int(rng.choice(len(svc_list), p=svc_w))
        svc_name, svc_min, _ = svc_list[idx]

        hour       = int(rng.integers(8, 17))
        day        = int(rng.integers(1, 7))
        crowd      = int(rng.integers(1, 4))  # 1=low,2=medium,3=high
        pred_wait  = float(np.clip(rng.lognormal(np.log(30), 0.6), 5, 150))
        # Actual can be better or worse than predicted
        ratio      = float(rng.lognormal(0, 0.35))  # 1.0 = exactly as predicted
        actual     = float(np.clip(pred_wait * ratio, 5, 180))
        completed  = int(rng.random() < 0.92)       # 92% served, 8% abandoned

        # Satisfaction model:
        # 5 = delighted (much faster than expected, completed)
        # 1 = very unhappy (much slower than expected, or not served)
        base = 3.0
        base += (pred_wait - actual) / pred_wait * 2.0  # surprise bonus/penalty
        base -= (actual > 60) * 0.8                      # long absolute wait
        base -= (crowd == 3)  * 0.5                      # high crowd = discomfort
        base -= (not completed) * 1.5                    # not served = unhappy
        base += (hour  < 11)  * 0.3                      # morning visit = positive
        score = int(np.clip(round(base + rng.normal(0, 0.4)), 1, 5))

        pop = DISTRICT_POP.get(office['district'], AVG_POP)
        rows.append({
            'actual_wait_min':      round(actual, 1),
            'predicted_wait_min':   round(pred_wait, 1),
            'wait_ratio':           round(ratio, 3),
            'service_type':         svc_name,
            'service_avg_min':      svc_min,
            'crowd_level_code':     crowd,
            'hour':                 hour,
            'day_of_week':          day,
            'is_service_completed': completed,
            'office_type':          office['type'],
            'district':             office['district'],
            'district_pop_log':     float(np.log(pop)),
            'satisfaction_score':   score,
        })

    return pd.DataFrame(rows)


if __name__ == '__main__':
    print('Generating all datasets …\n')

    df_main, df_demand = generate_dataset(100_000)
    df_noshow  = generate_no_show_dataset(40_000)
    df_abandon = generate_abandonment_dataset(40_000)
    df_dur     = generate_service_duration_dataset(60_000)
    df_counter = generate_counter_dataset()
    df_sat     = generate_satisfaction_dataset(40_000)

    datasets = {
        'Main (visit records)':           df_main,
        'Demand forecast':                df_demand,
        'No-show prediction':             df_noshow,
        'Queue abandonment':              df_abandon,
        'Service duration':               df_dur,
        'Counter optimisation':           df_counter,
        'Citizen satisfaction':           df_sat,
    }
    for name, df in datasets.items():
        print(f'  {name:<30} {len(df):>8,} rows × {df.shape[1]} cols')

    print('\nNo-show rate   :', round(df_noshow['is_no_show'].mean() * 100, 1), '%')
    print('Abandonment rate:', round(df_abandon['will_abandon'].mean() * 100, 1), '%')
    print('Mean service dur:', round(df_dur['actual_service_duration_min'].mean(), 1), 'min')
    print('Mean counters rec:', round(df_counter['recommended_counters'].mean(), 2))
    print('Mean satisfaction:', round(df_sat['satisfaction_score'].mean(), 2), '/ 5')
