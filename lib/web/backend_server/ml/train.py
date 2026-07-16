"""
QueueNova ML Training Pipeline

Trains five prediction models and saves them to models/:

  Model 1  WaitTimeModel        RandomForestRegressor
           Predicts wait time in minutes for a citizen visiting at a given
           hour / day / month / office / district.

  Model 2  CrowdLevelModel      RandomForestClassifier
           Classifies crowd level: 1=low / 2=medium / 3=high.

  Model 3  PeakHourModel        GradientBoostingClassifier
           Binary: is this hour a peak hour for this office? (F1-optimised)

  Model 4  DemandForecastModel  RandomForestRegressor
           Predicts expected daily visitor count for a (service × office × day).

  Model 5  OfficeScorer         Rule-based weighted scoring (exported as JSON)
           Ranks offices by (predicted wait, counters, population density).

Run:
    cd lib/web/backend_server/ml
    pip install -r requirements.txt
    python train.py

Output: models/ directory with .pkl files + feature_info.json
"""

import os
import sys
import json
import time

import numpy as np
import pandas as pd
import joblib
from sklearn.ensemble import (
    RandomForestRegressor,
    RandomForestClassifier,
    GradientBoostingClassifier,
)
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import cross_val_score
from sklearn.metrics import mean_absolute_error, accuracy_score, f1_score

# Ensure dataset module is importable from this directory
sys.path.insert(0, os.path.dirname(__file__))
from dataset import (
    generate_dataset, generate_no_show_dataset, generate_abandonment_dataset,
    generate_service_duration_dataset, generate_counter_dataset,
    generate_satisfaction_dataset,
    OFFICES, SERVICES, DISTRICT_POP, AVG_POP,
)

MODELS_DIR = os.path.join(os.path.dirname(__file__), 'models')
os.makedirs(MODELS_DIR, exist_ok=True)

# ── Feature column lists ───────────────────────────────────────────────────────
VISIT_FEATURES = [
    'hour', 'hour_sin', 'hour_cos',
    'day_of_week', 'day_sin', 'day_cos',
    'month', 'month_sin', 'month_cos',
    'is_holiday', 'is_monday', 'is_friday',
    'office_type_enc', 'district_enc', 'district_pop_log',
    'num_counters',
    'service_type_enc', 'service_avg_min',
    'queue_at_arrival',
]

DEMAND_FEATURES = [
    'month', 'day_of_week',
    'office_type_enc', 'district_enc', 'district_pop_log',
    'service_type_enc', 'service_avg_min',
]

NO_SHOW_FEATURES = [
    'day_of_week', 'day_sin', 'day_cos',
    'hour', 'hour_sin', 'hour_cos',
    'month', 'service_type_enc', 'district_enc',
    'district_pop_log', 'fee', 'is_prepaid',
    'days_in_advance', 'service_avg_min',
]

ABANDON_FEATURES = [
    'current_queue_length', 'estimated_wait_min',
    'service_type_enc', 'service_avg_min',
    'hour', 'hour_sin', 'hour_cos', 'day_of_week',
    'fee', 'is_priority', 'district_enc', 'district_pop_log',
]

DURATION_FEATURES = [
    'service_type_enc', 'service_avg_min',
    'office_type_enc',
    'hour', 'hour_sin', 'hour_cos',
    'day_of_week', 'month',
    'queue_at_arrival', 'district_enc', 'district_pop_log',
]

COUNTER_FEATURES = [
    'hour', 'hour_sin', 'hour_cos',
    'day_of_week', 'day_sin', 'day_cos', 'month',
    'office_type_enc', 'district_enc', 'district_pop_log',
    'service_type_enc', 'service_avg_min',
    'arrivals_per_hour', 'available_staff',
]

SATISFACTION_FEATURES = [
    'actual_wait_min', 'predicted_wait_min', 'wait_ratio',
    'service_type_enc', 'service_avg_min',
    'crowd_level_code', 'hour', 'day_of_week',
    'is_service_completed', 'office_type_enc', 'district_enc',
    'district_pop_log',
]


def _encode(df_main, df_demand):
    """Fit label encoders on main dataset and apply to both DataFrames."""
    le_office   = LabelEncoder().fit(df_main['office_type'])
    # Fit on every district in the country, not just the ones with an office
    # in OFFICES — generate_no_show_dataset/generate_abandonment_dataset
    # (Step 7) sample districts from the full DISTRICT_POP list, and would
    # otherwise raise "previously unseen labels" for any district without
    # a physical office (e.g. Batticaloa).
    le_district = LabelEncoder().fit(sorted(DISTRICT_POP.keys()))
    le_service  = LabelEncoder().fit(
        pd.concat([df_main['service_type'], df_demand['service_type']])
    )

    for df in (df_main, df_demand):
        df['office_type_enc']  = le_office.transform(df['office_type'])
        df['district_enc']     = le_district.transform(df['district'])
        df['service_type_enc'] = le_service.transform(df['service_type'])

    return le_office, le_district, le_service


def _save_feature_info(le_office, le_district, le_service):
    info = {
        'office_type_classes':  list(le_office.classes_),
        'district_classes':     list(le_district.classes_),
        'service_type_classes': list(le_service.classes_),
        'crowd_level_map':      {'1': 'low', '2': 'medium', '3': 'high'},
        'visit_feature_cols':   VISIT_FEATURES,
        'demand_feature_cols':  DEMAND_FEATURES,
        'office_scorer_weights': {
            'wait_time':   -0.60,
            'counters':    +0.20,
            'pop_density': -0.20,
        },
    }
    path = os.path.join(MODELS_DIR, 'feature_info.json')
    with open(path, 'w') as f:
        json.dump(info, f, indent=2)
    print(f'   Saved {path}')
    return info


def _section(title):
    print(f'\n{"─"*60}')
    print(f'  {title}')
    print(f'{"─"*60}')


def train():
    t0 = time.time()

    _section('Step 1/6 — Generating training data')
    df_main, df_demand = generate_dataset(n_samples=100_000, random_seed=42)
    print(f'   Visit records  : {len(df_main):>8,}')
    print(f'   Demand records : {len(df_demand):>8,}')

    _section('Step 2/6 — Encoding categorical features')
    le_office, le_district, le_service = _encode(df_main, df_demand)
    feature_info = _save_feature_info(le_office, le_district, le_service)
    print(f'   Office types   : {len(le_office.classes_)}')
    print(f'   Districts      : {len(le_district.classes_)}')
    print(f'   Service types  : {len(le_service.classes_)}')

    X      = df_main[VISIT_FEATURES].values.astype(float)
    y_wait = df_main['wait_time_min'].values.astype(float)
    y_crowd = df_main['crowd_level'].values.astype(int)
    y_peak  = df_main['is_peak'].values.astype(int)

    X_dem  = df_demand[DEMAND_FEATURES].values.astype(float)
    y_dem  = df_demand['daily_count'].values.astype(float)

    # ── Model 1: Wait Time Regression ─────────────────────────────────────────
    _section('Step 3/6 — Training WaitTimeModel (RandomForestRegressor)')
    wm = RandomForestRegressor(
        n_estimators=300, max_depth=18, min_samples_leaf=4,
        n_jobs=-1, random_state=42,
    )
    wm.fit(X, y_wait)
    train_mae = mean_absolute_error(y_wait, wm.predict(X))
    cv_mae    = -cross_val_score(wm, X, y_wait, cv=5,
                                 scoring='neg_mean_absolute_error', n_jobs=-1)
    print(f'   Train MAE : {train_mae:.2f} min')
    print(f'   CV MAE    : {cv_mae.mean():.2f} ± {cv_mae.std():.2f} min')
    joblib.dump(wm, os.path.join(MODELS_DIR, 'wait_time_model.pkl'), compress=3)
    print(f'   ✅ wait_time_model.pkl saved')

    # Feature importances
    imp = pd.Series(wm.feature_importances_, index=VISIT_FEATURES).sort_values(ascending=False)
    with open(os.path.join(MODELS_DIR, 'feature_importances.json'), 'w') as f:
        json.dump({k: round(float(v), 6) for k, v in imp.items()}, f, indent=2)
    print('   Top 5 features:', ', '.join(imp.head(5).index.tolist()))

    # ── Model 2: Crowd Level Classifier ───────────────────────────────────────
    _section('Step 4/6 — Training CrowdLevelModel (RandomForestClassifier)')
    cm = RandomForestClassifier(
        n_estimators=300, max_depth=14, min_samples_leaf=4,
        n_jobs=-1, random_state=42,
    )
    cm.fit(X, y_crowd)
    train_acc = accuracy_score(y_crowd, cm.predict(X))
    cv_acc    = cross_val_score(cm, X, y_crowd, cv=5, scoring='accuracy', n_jobs=-1)
    print(f'   Train Acc : {train_acc:.4f}')
    print(f'   CV Acc    : {cv_acc.mean():.4f} ± {cv_acc.std():.4f}')
    joblib.dump(cm, os.path.join(MODELS_DIR, 'crowd_level_model.pkl'), compress=3)
    print(f'   ✅ crowd_level_model.pkl saved')

    # ── Model 3: Peak Hour Classifier ─────────────────────────────────────────
    _section('Step 4b/6 — Training PeakHourModel (GradientBoostingClassifier)')
    pm = GradientBoostingClassifier(
        n_estimators=200, max_depth=5, learning_rate=0.10,
        subsample=0.8, random_state=42,
    )
    pm.fit(X, y_peak)
    train_f1 = f1_score(y_peak, pm.predict(X))
    cv_f1    = cross_val_score(pm, X, y_peak, cv=5, scoring='f1', n_jobs=-1)
    print(f'   Train F1  : {train_f1:.4f}')
    print(f'   CV F1     : {cv_f1.mean():.4f} ± {cv_f1.std():.4f}')
    joblib.dump(pm, os.path.join(MODELS_DIR, 'peak_hour_model.pkl'), compress=3)
    print(f'   ✅ peak_hour_model.pkl saved')

    # ── Model 4: Demand Forecast ───────────────────────────────────────────────
    _section('Step 5/6 — Training DemandForecastModel (RandomForestRegressor)')
    dm_model = RandomForestRegressor(
        n_estimators=200, max_depth=12, min_samples_leaf=2,
        n_jobs=-1, random_state=42,
    )
    dm_model.fit(X_dem, y_dem)
    train_mae_d = mean_absolute_error(y_dem, dm_model.predict(X_dem))
    cv_mae_d    = -cross_val_score(dm_model, X_dem, y_dem, cv=5,
                                   scoring='neg_mean_absolute_error', n_jobs=-1)
    print(f'   Train MAE : {train_mae_d:.1f} visits/day')
    print(f'   CV MAE    : {cv_mae_d.mean():.1f} ± {cv_mae_d.std():.1f}')
    joblib.dump(dm_model, os.path.join(MODELS_DIR, 'demand_forecast_model.pkl'), compress=3)
    print(f'   ✅ demand_forecast_model.pkl saved')

    # ── Model 5: Office Scorer (rule-based, JSON weights) ─────────────────────
    _section('Step 6/6 — Exporting OfficeScorer weights (rule-based)')
    scorer_config = {
        'description':   'Weighted scoring to rank offices — lower wait + more counters + lower population density = better',
        'weights':        feature_info['office_scorer_weights'],
        'crowd_penalty':  {'low': 0.0, 'medium': -0.10, 'high': -0.25},
        'holiday_closed': True,
        'version':        '1.0',
    }
    with open(os.path.join(MODELS_DIR, 'office_scorer.json'), 'w') as f:
        json.dump(scorer_config, f, indent=2)
    print('   ✅ office_scorer.json saved')

    # ── Models 6-10: Generate & encode additional datasets ────────────────────
    _section('Step 7/11 — Generating additional training datasets')
    df_noshow  = generate_no_show_dataset(40_000,  random_seed=100)
    df_abandon = generate_abandonment_dataset(40_000, random_seed=101)
    df_dur     = generate_service_duration_dataset(60_000, random_seed=102)
    df_counter = generate_counter_dataset(random_seed=103)
    df_sat     = generate_satisfaction_dataset(40_000, random_seed=104)
    print(f'   No-show rows       : {len(df_noshow):>8,}')
    print(f'   Abandonment rows   : {len(df_abandon):>8,}')
    print(f'   Service-dur rows   : {len(df_dur):>8,}')
    print(f'   Counter rows       : {len(df_counter):>8,}')
    print(f'   Satisfaction rows  : {len(df_sat):>8,}')

    # Apply same label encoders (office_type, district, service_type)
    for df in (df_noshow, df_abandon, df_dur, df_counter, df_sat):
        if 'service_type' in df.columns:
            df['service_type_enc']  = le_service.transform(df['service_type'])
        if 'district' in df.columns:
            df['district_enc']      = le_district.transform(df['district'])
        if 'office_type' in df.columns:
            df['office_type_enc']   = le_office.transform(df['office_type'])

    # ── Model 6: No-Show Predictor ─────────────────────────────────────────────
    _section('Step 8/11 — Training NoShowModel (GradientBoostingClassifier)')
    X_ns = df_noshow[NO_SHOW_FEATURES].values.astype(float)
    y_ns = df_noshow['is_no_show'].values.astype(int)
    ns_model = GradientBoostingClassifier(
        n_estimators=200, max_depth=4, learning_rate=0.10,
        subsample=0.8, random_state=42,
    )
    ns_model.fit(X_ns, y_ns)
    cv_ns = cross_val_score(ns_model, X_ns, y_ns, cv=5, scoring='f1', n_jobs=-1)
    print(f'   CV F1     : {cv_ns.mean():.4f} ± {cv_ns.std():.4f}')
    print(f'   No-show base rate: {y_ns.mean():.3f}')
    joblib.dump(ns_model, os.path.join(MODELS_DIR, 'no_show_model.pkl'), compress=3)
    print(f'   ✅ no_show_model.pkl saved')

    # ── Model 7: Queue Abandonment Predictor ───────────────────────────────────
    _section('Step 9/11 — Training AbandonmentModel (GradientBoostingClassifier)')
    X_ab = df_abandon[ABANDON_FEATURES].values.astype(float)
    y_ab = df_abandon['will_abandon'].values.astype(int)
    ab_model = GradientBoostingClassifier(
        n_estimators=200, max_depth=4, learning_rate=0.10,
        subsample=0.8, random_state=42,
    )
    ab_model.fit(X_ab, y_ab)
    cv_ab = cross_val_score(ab_model, X_ab, y_ab, cv=5, scoring='f1', n_jobs=-1)
    print(f'   CV F1     : {cv_ab.mean():.4f} ± {cv_ab.std():.4f}')
    print(f'   Abandon base rate : {y_ab.mean():.3f}')
    joblib.dump(ab_model, os.path.join(MODELS_DIR, 'abandonment_model.pkl'), compress=3)
    print(f'   ✅ abandonment_model.pkl saved')

    # ── Model 8: Service Duration Predictor ────────────────────────────────────
    _section('Step 10/11 — Training ServiceDurationModel (RandomForestRegressor)')
    X_dur = df_dur[DURATION_FEATURES].values.astype(float)
    y_dur = df_dur['actual_service_duration_min'].values.astype(float)
    dur_model = RandomForestRegressor(
        n_estimators=200, max_depth=12, min_samples_leaf=4,
        n_jobs=-1, random_state=42,
    )
    dur_model.fit(X_dur, y_dur)
    mae_dur = mean_absolute_error(y_dur, dur_model.predict(X_dur))
    cv_dur  = -cross_val_score(dur_model, X_dur, y_dur, cv=5,
                               scoring='neg_mean_absolute_error', n_jobs=-1)
    print(f'   Train MAE : {mae_dur:.2f} min')
    print(f'   CV MAE    : {cv_dur.mean():.2f} ± {cv_dur.std():.2f} min')
    joblib.dump(dur_model, os.path.join(MODELS_DIR, 'service_duration_model.pkl'), compress=3)
    print(f'   ✅ service_duration_model.pkl saved')

    # ── Model 9: Counter Optimization ──────────────────────────────────────────
    _section('Step 11/11 — Training CounterOptimizer (RandomForestRegressor)')
    X_ctr = df_counter[COUNTER_FEATURES].values.astype(float)
    y_ctr = df_counter['recommended_counters'].values.astype(float)
    ctr_model = RandomForestRegressor(
        n_estimators=200, max_depth=10, min_samples_leaf=2,
        n_jobs=-1, random_state=42,
    )
    ctr_model.fit(X_ctr, y_ctr)
    mae_ctr = mean_absolute_error(y_ctr, ctr_model.predict(X_ctr))
    cv_ctr  = -cross_val_score(ctr_model, X_ctr, y_ctr, cv=5,
                               scoring='neg_mean_absolute_error', n_jobs=-1)
    print(f'   Train MAE : {mae_ctr:.3f} counters')
    print(f'   CV MAE    : {cv_ctr.mean():.3f} ± {cv_ctr.std():.3f} counters')
    joblib.dump(ctr_model, os.path.join(MODELS_DIR, 'counter_optimizer_model.pkl'), compress=3)
    print(f'   ✅ counter_optimizer_model.pkl saved')

    # ── Model 10: Citizen Satisfaction Predictor ───────────────────────────────
    _section('Step 11b/11 — Training SatisfactionModel (GradientBoostingClassifier)')
    X_sat = df_sat[SATISFACTION_FEATURES].values.astype(float)
    y_sat = df_sat['satisfaction_score'].values.astype(int)
    sat_model = GradientBoostingClassifier(
        n_estimators=200, max_depth=4, learning_rate=0.08,
        subsample=0.8, random_state=42,
    )
    sat_model.fit(X_sat, y_sat)
    acc_sat = accuracy_score(y_sat, sat_model.predict(X_sat))
    cv_sat  = cross_val_score(sat_model, X_sat, y_sat, cv=5, scoring='accuracy', n_jobs=-1)
    print(f'   Train Acc : {acc_sat:.4f}')
    print(f'   CV Acc    : {cv_sat.mean():.4f} ± {cv_sat.std():.4f}')
    print(f'   Score distribution: {pd.Series(y_sat).value_counts().sort_index().to_dict()}')
    joblib.dump(sat_model, os.path.join(MODELS_DIR, 'satisfaction_model.pkl'), compress=3)
    print(f'   ✅ satisfaction_model.pkl saved')

    # ── Update feature_info.json with all 10 model feature columns ────────────
    _section('Updating feature_info.json with all model feature lists')
    info_path = os.path.join(MODELS_DIR, 'feature_info.json')
    with open(info_path) as f:
        fi = json.load(f)
    fi.update({
        'no_show_feature_cols':       NO_SHOW_FEATURES,
        'abandon_feature_cols':       ABANDON_FEATURES,
        'duration_feature_cols':      DURATION_FEATURES,
        'counter_feature_cols':       COUNTER_FEATURES,
        'satisfaction_feature_cols':  SATISFACTION_FEATURES,
        'satisfaction_classes':       list(map(int, sat_model.classes_)),
    })
    with open(info_path, 'w') as f:
        json.dump(fi, f, indent=2)
    print(f'   ✅ feature_info.json updated with all 10 model definitions')

    elapsed = time.time() - t0
    _section(f'All 10 models trained in {elapsed:.1f}s')
    print(f'   Models saved to: {MODELS_DIR}')
    print()
    print('   Model summary:')
    print('     1. wait_time_model.pkl         — RandomForestRegressor')
    print('     2. crowd_level_model.pkl        — RandomForestClassifier')
    print('     3. peak_hour_model.pkl          — GradientBoostingClassifier')
    print('     4. demand_forecast_model.pkl    — RandomForestRegressor')
    print('     5. office_scorer.json           — Rule-based scoring weights')
    print('     6. no_show_model.pkl            — GradientBoostingClassifier')
    print('     7. abandonment_model.pkl        — GradientBoostingClassifier')
    print('     8. service_duration_model.pkl   — RandomForestRegressor')
    print('     9. counter_optimizer_model.pkl  — RandomForestRegressor')
    print('    10. satisfaction_model.pkl       — GradientBoostingClassifier')
    print()
    print('   Run: python inference.py   to start the prediction server\n')


if __name__ == '__main__':
    train()
