"""
QueueNova ML Inference Server

Loads the five trained models and exposes a REST API.
Node.js backend proxies to this server for all ML predictions.

Run:
    cd lib/web/backend_server/ml
    python inference.py          # starts on http://localhost:5001

Endpoints:
    GET  /health
    POST /predict/wait-time      — wait time + crowd level + peak probability
    POST /predict/peak-hours     — hourly forecast for today (hours 8-16)
    POST /predict/demand         — daily service demand forecast
    POST /predict/crowd          — crowd level with full probability distribution
    POST /recommend/office       — rank a list of offices by predicted experience
"""

import os
import sys
import json
import math

import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE_DIR   = os.path.dirname(__file__)
MODELS_DIR = os.path.join(BASE_DIR, 'models')
sys.path.insert(0, BASE_DIR)

from dataset import DISTRICT_POP, AVG_POP  # noqa: E402  (must be after sys.path insert)

app = Flask(__name__)
CORS(app)

# ── Global model state ────────────────────────────────────────────────────────
_ready           = False
_wait_model      = None
_crowd_model     = None
_peak_model      = None
_demand_model    = None
_noshow_model    = None
_abandon_model   = None
_duration_model  = None
_counter_model   = None
_sat_model       = None
_feature_info    = {}
_office_scorer   = {}


def _load():
    global _ready
    global _wait_model, _crowd_model, _peak_model, _demand_model
    global _noshow_model, _abandon_model, _duration_model, _counter_model, _sat_model
    global _feature_info, _office_scorer

    info_path = os.path.join(MODELS_DIR, 'feature_info.json')
    if not os.path.exists(info_path):
        print('⚠️  models/feature_info.json not found — run train.py first.')
        return

    import joblib
    with open(info_path) as f:
        _feature_info = json.load(f)

    scorer_path = os.path.join(MODELS_DIR, 'office_scorer.json')
    if os.path.exists(scorer_path):
        with open(scorer_path) as f:
            _office_scorer = json.load(f)

    def _try_load(name):
        path = os.path.join(MODELS_DIR, name)
        if os.path.exists(path):
            return joblib.load(path)
        print(f'⚠️  {name} not found — some endpoints will return fallback.')
        return None

    _wait_model     = _try_load('wait_time_model.pkl')
    _crowd_model    = _try_load('crowd_level_model.pkl')
    _peak_model     = _try_load('peak_hour_model.pkl')
    _demand_model   = _try_load('demand_forecast_model.pkl')
    _noshow_model   = _try_load('no_show_model.pkl')
    _abandon_model  = _try_load('abandonment_model.pkl')
    _duration_model = _try_load('service_duration_model.pkl')
    _counter_model  = _try_load('counter_optimizer_model.pkl')
    _sat_model      = _try_load('satisfaction_model.pkl')

    _ready = all(m is not None for m in [
        _wait_model, _crowd_model, _peak_model, _demand_model,
        _noshow_model, _abandon_model, _duration_model, _counter_model, _sat_model,
    ])
    loaded = sum(1 for m in [
        _wait_model, _crowd_model, _peak_model, _demand_model,
        _noshow_model, _abandon_model, _duration_model, _counter_model, _sat_model,
    ] if m is not None)
    print(f'✅  {loaded}/9 models loaded — QueueNova ML server ready.')


# ── Feature-building helpers ───────────────────────────────────────────────────

def _enc(value: str, classes: list) -> int:
    """Label-encode a string value; partial-match fallback."""
    if value in classes:
        return classes.index(value)
    v = value.lower()
    for i, c in enumerate(classes):
        if v in c.lower() or c.lower() in v:
            return i
    return 0


def _cyc(val: float, period: float):
    angle = 2 * math.pi * val / period
    return math.sin(angle), math.cos(angle)


def _build_X(office_type, district, service_type,
              hour, day_of_week, month,
              num_counters, service_avg_min,
              queue_at_arrival=0, is_holiday=0):
    fi = _feature_info
    ot_enc  = _enc(office_type,  fi['office_type_classes'])
    d_enc   = _enc(district,     fi['district_classes'])
    svc_enc = _enc(service_type, fi['service_type_classes'])
    pop     = DISTRICT_POP.get(district, AVG_POP)

    hs, hc = _cyc(hour        - 8,  9)
    ds, dc = _cyc(day_of_week - 1,  6)
    ms, mc = _cyc(month       - 1, 12)

    return np.array([[
        float(hour),      hs, hc,
        float(day_of_week), ds, dc,
        float(month),     ms, mc,
        float(is_holiday),
        float(day_of_week == 1),  # is_monday
        float(day_of_week == 5),  # is_friday
        float(ot_enc),
        float(d_enc),
        float(np.log(pop)),
        float(num_counters),
        float(svc_enc),
        float(service_avg_min),
        float(queue_at_arrival),
    ]])


def _crowd_label(code: int) -> str:
    return {1: 'low', 2: 'medium', 3: 'high'}.get(code, 'unknown')


def _time_label(hour: int) -> str:
    if hour == 12:
        return '12:00 PM'
    return f'{hour - 12}:00 PM' if hour > 12 else f'{hour}:00 AM'


def _not_ready():
    return jsonify({
        'error': 'Models not loaded — run train.py first.',
        'fallback': True,
    }), 503


# ── Routes ─────────────────────────────────────────────────────────────────────

@app.get('/health')
def health():
    return jsonify({'status': 'ok', 'models_ready': _ready})


@app.post('/predict/wait-time')
def predict_wait_time():
    """
    Input JSON:
      officeType, district, serviceType, hour, dayOfWeek, month,
      numCounters, serviceAvgMin, queueAtArrival, isHoliday
    Output JSON:
      wait_time_min, waiting_ahead, crowd_level, crowd_level_code,
      crowd_probabilities, is_peak, peak_probability, confidence,
      district, recommended_time, fallback
    """
    if not _ready:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        ot      = d.get('officeType',     'Divisional Secretariat')
        dist    = d.get('district',        'Colombo')
        svc     = d.get('serviceType',     'NIC Card')
        hour    = int(d.get('hour',        10))
        dow     = int(d.get('dayOfWeek',   3))
        month   = int(d.get('month',       6))
        cntrs   = int(d.get('numCounters', 3))
        svc_min = float(d.get('serviceAvgMin', 10.0))
        q_arr   = int(d.get('queueAtArrival', 0))
        hol     = int(d.get('isHoliday',   0))

        X = _build_X(ot, dist, svc, hour, dow, month, cntrs, svc_min, q_arr, hol)

        wait_pred   = float(_wait_model.predict(X)[0])
        crowd_pred  = int(_crowd_model.predict(X)[0])
        crowd_proba = _crowd_model.predict_proba(X)[0]
        peak_pred   = int(_peak_model.predict(X)[0])
        peak_prob   = float(_peak_model.predict_proba(X)[0][1])

        # Confidence: certainty of crowd class + distance from peak boundary
        conf = float(max(crowd_proba)) * 0.70 + (1.0 - abs(peak_prob - 0.5) * 2) * 0.30

        # Recommended time: scan hours 8-16, pick lowest predicted wait
        best_h, best_w = hour, wait_pred
        for h in range(8, 17):
            Xh = _build_X(ot, dist, svc, h, dow, month, cntrs, svc_min, 0, hol)
            w  = float(_wait_model.predict(Xh)[0])
            if w < best_w:
                best_w, best_h = w, h

        classes = _crowd_model.classes_.tolist()
        return jsonify({
            'wait_time_min':       round(wait_pred, 1),
            'waiting_ahead':       max(0, round(wait_pred / max(svc_min, 1))),
            'crowd_level':         _crowd_label(crowd_pred),
            'crowd_level_code':    crowd_pred,
            'crowd_probabilities': {
                _crowd_label(int(c)): round(float(p), 3)
                for c, p in zip(classes, crowd_proba)
            },
            'is_peak':             bool(peak_pred),
            'peak_probability':    round(peak_prob, 3),
            'confidence':          round(min(conf, 0.99), 3),
            'district':            dist,
            'recommended_time':    _time_label(best_h),
            'fallback':            False,
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/predict/peak-hours')
def predict_peak_hours():
    """
    Input JSON:
      officeType, district, serviceType, dayOfWeek, month, numCounters, serviceAvgMin
    Output JSON:
      hours[] { hour, time, wait_time_min, crowd_level, is_peak, peak_probability }
      best_hour, best_time, worst_hour, worst_time
    """
    if not _ready:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        ot      = d.get('officeType',     'Divisional Secretariat')
        dist    = d.get('district',        'Colombo')
        svc     = d.get('serviceType',     'NIC Card')
        dow     = int(d.get('dayOfWeek',   3))
        month   = int(d.get('month',       6))
        cntrs   = int(d.get('numCounters', 3))
        svc_min = float(d.get('serviceAvgMin', 10.0))

        hours_out = []
        best_h, best_w = 8, float('inf')
        worst_h, worst_w = 8, 0.0

        for h in range(8, 17):
            X = _build_X(ot, dist, svc, h, dow, month, cntrs, svc_min)
            wait  = float(_wait_model.predict(X)[0])
            crowd = int(_crowd_model.predict(X)[0])
            peak  = int(_peak_model.predict(X)[0])
            pp    = float(_peak_model.predict_proba(X)[0][1])
            hours_out.append({
                'hour': h, 'time': _time_label(h),
                'wait_time_min':   round(wait, 1),
                'crowd_level':     _crowd_label(crowd),
                'is_peak':         bool(peak),
                'peak_probability': round(pp, 3),
            })
            if wait < best_w:
                best_w, best_h = wait, h
            if wait > worst_w:
                worst_w, worst_h = wait, h

        return jsonify({
            'hours':      hours_out,
            'best_hour':  best_h,
            'best_time':  _time_label(best_h),
            'worst_hour': worst_h,
            'worst_time': _time_label(worst_h),
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/predict/demand')
def predict_demand():
    """
    Input JSON:
      officeType, district, serviceType, month, dayOfWeek, serviceAvgMin
    Output JSON:
      predicted_daily_count, confidence_interval [p10, p90],
      service_type, district
    """
    if not _ready:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        ot      = d.get('officeType',  'Divisional Secretariat')
        dist    = d.get('district',    'Colombo')
        svc     = d.get('serviceType', 'NIC Card')
        month   = int(d.get('month',   6))
        dow     = int(d.get('dayOfWeek', 3))
        svc_min = float(d.get('serviceAvgMin', 10.0))

        fi      = _feature_info
        ot_enc  = _enc(ot,   fi['office_type_classes'])
        d_enc   = _enc(dist, fi['district_classes'])
        s_enc   = _enc(svc,  fi['service_type_classes'])
        pop     = DISTRICT_POP.get(dist, AVG_POP)

        X = np.array([[float(month), float(dow),
                        float(ot_enc), float(d_enc), float(np.log(pop)),
                        float(s_enc), float(svc_min)]])

        pred = float(_demand_model.predict(X)[0])

        # Tree ensemble confidence interval (10th–90th percentile)
        tree_preds = np.array([t.predict(X)[0] for t in _demand_model.estimators_])
        ci_lo = int(max(0, np.percentile(tree_preds, 10)))
        ci_hi = int(np.percentile(tree_preds, 90))

        return jsonify({
            'predicted_daily_count': max(1, round(pred)),
            'confidence_interval':   [ci_lo, ci_hi],
            'service_type':          svc,
            'district':              dist,
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/predict/crowd')
def predict_crowd():
    """
    Input JSON:
      officeType, district, serviceType, hour, dayOfWeek, month,
      numCounters, serviceAvgMin
    Output JSON:
      crowd_level, crowd_level_code, confidence, probability_distribution
    """
    if not _ready:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        ot      = d.get('officeType',     'Divisional Secretariat')
        dist    = d.get('district',        'Colombo')
        svc     = d.get('serviceType',     'NIC Card')
        hour    = int(d.get('hour',        10))
        dow     = int(d.get('dayOfWeek',   3))
        month   = int(d.get('month',       6))
        cntrs   = int(d.get('numCounters', 3))
        svc_min = float(d.get('serviceAvgMin', 10.0))

        X = _build_X(ot, dist, svc, hour, dow, month, cntrs, svc_min)
        crowd_pred  = int(_crowd_model.predict(X)[0])
        crowd_proba = _crowd_model.predict_proba(X)[0]
        classes     = _crowd_model.classes_.tolist()

        return jsonify({
            'crowd_level':      _crowd_label(crowd_pred),
            'crowd_level_code': crowd_pred,
            'confidence':       round(float(max(crowd_proba)), 3),
            'probability_distribution': {
                _crowd_label(int(c)): round(float(p), 3)
                for c, p in zip(classes, crowd_proba)
            },
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/recommend/office')
def recommend_office():
    """
    Input JSON:
      offices:        [ { name, type, district, counters } ]
      serviceType:    str
      serviceAvgMin:  float
      hour:           int
      dayOfWeek:      int
      month:          int
    Output JSON:
      recommendations: [ { name, score, predicted_wait_min, crowd_level, reason } ]
      best_office: str
    """
    if not _ready:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        offices   = d.get('offices', [])
        svc       = d.get('serviceType',    'NIC Card')
        svc_min   = float(d.get('serviceAvgMin', 10.0))
        hour      = int(d.get('hour',       10))
        dow       = int(d.get('dayOfWeek',  3))
        month     = int(d.get('month',      6))
        max_pop   = max(DISTRICT_POP.values())
        weights   = _office_scorer.get('weights', {'wait_time': -0.60, 'counters': 0.20, 'pop_density': -0.20})
        penalty   = _office_scorer.get('crowd_penalty', {'low': 0.0, 'medium': -0.10, 'high': -0.25})

        scored = []
        for o in offices:
            ot      = o.get('type',     'Divisional Secretariat')
            dist    = o.get('district', 'Colombo')
            cntrs   = int(o.get('counters', 3))

            X = _build_X(ot, dist, svc, hour, dow, month, cntrs, svc_min)
            wait  = float(_wait_model.predict(X)[0])
            crowd = int(_crowd_model.predict(X)[0])
            cl    = _crowd_label(crowd)

            pop   = DISTRICT_POP.get(dist, AVG_POP)
            score = (
                (1.0 - wait / 180.0)    * abs(weights.get('wait_time',   -0.60)) +
                (cntrs / 10.0)           *     weights.get('counters',    +0.20) +
                (1.0 - pop / max_pop)    * abs(weights.get('pop_density', -0.20)) +
                penalty.get(cl, 0.0)
            )
            scored.append({
                'name':               o.get('name', ot),
                'score':              round(max(0.0, score), 4),
                'predicted_wait_min': round(wait, 1),
                'crowd_level':        cl,
                'reason': (
                    'Very low crowd — great time to visit' if crowd == 1 else
                    'Moderate wait — manageable' if crowd == 2 else
                    'High demand — consider coming earlier or later'
                ),
            })

        scored.sort(key=lambda x: -x['score'])
        return jsonify({
            'recommendations': scored,
            'best_office':     scored[0]['name'] if scored else None,
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/predict/no-show')
def predict_no_show():
    """
    Appointment no-show probability.

    Input JSON:
      serviceType, district, hour, dayOfWeek, month,
      fee, isPrepaid, daysInAdvance, serviceAvgMin
    Output JSON:
      will_no_show (bool), no_show_probability, confidence,
      risk_level ('low'|'medium'|'high'), recommendation
    """
    if _noshow_model is None:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        svc     = d.get('serviceType',   'NIC Card')
        dist    = d.get('district',      'Colombo')
        hour    = int(d.get('hour',      10))
        dow     = int(d.get('dayOfWeek', 3))
        month   = int(d.get('month',     6))
        fee     = float(d.get('fee',     500.0))
        prepaid = int(d.get('isPrepaid', 1))
        adv     = int(d.get('daysInAdvance', 0))
        svc_min = float(d.get('serviceAvgMin', 10.0))

        fi  = _feature_info
        se  = _enc(svc,  fi['service_type_classes'])
        de  = _enc(dist, fi['district_classes'])
        pop = DISTRICT_POP.get(dist, AVG_POP)
        hs, hc = _cyc(hour - 8, 9)
        ds, dc = _cyc(dow  - 1, 6)

        X = np.array([[
            float(dow), ds, dc,
            float(hour), hs, hc,
            float(month),
            float(se), float(de), float(np.log(pop)),
            fee, float(prepaid), float(adv), svc_min,
        ]])

        prob      = float(_noshow_model.predict_proba(X)[0][1])
        will_ns   = bool(prob >= 0.40)
        risk      = 'low' if prob < 0.20 else ('medium' if prob < 0.40 else 'high')
        rec       = (
            'Low risk — citizen likely to attend.' if risk == 'low' else
            'Moderate risk — consider a reminder SMS.' if risk == 'medium' else
            'High risk — send reminder and consider overbooking this slot.'
        )
        return jsonify({
            'will_no_show':         will_ns,
            'no_show_probability':  round(prob, 3),
            'confidence':           round(float(max(_noshow_model.predict_proba(X)[0])), 3),
            'risk_level':           risk,
            'recommendation':       rec,
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/predict/abandonment')
def predict_abandonment():
    """
    Queue abandonment probability for a citizen currently waiting.

    Input JSON:
      currentQueueLength, estimatedWaitMin, serviceType, serviceAvgMin,
      hour, dayOfWeek, fee, isPriority, district
    Output JSON:
      will_abandon (bool), abandon_probability, risk_level, action
    """
    if _abandon_model is None:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        qlen    = int(d.get('currentQueueLength', 10))
        wait    = float(d.get('estimatedWaitMin', 30.0))
        svc     = d.get('serviceType',   'NIC Card')
        svc_min = float(d.get('serviceAvgMin', 10.0))
        hour    = int(d.get('hour',      10))
        dow     = int(d.get('dayOfWeek', 3))
        fee     = float(d.get('fee',     500.0))
        is_pri  = int(d.get('isPriority', 0))
        dist    = d.get('district',      'Colombo')

        fi  = _feature_info
        se  = _enc(svc,  fi['service_type_classes'])
        de  = _enc(dist, fi['district_classes'])
        pop = DISTRICT_POP.get(dist, AVG_POP)
        hs, hc = _cyc(hour - 8, 9)

        X = np.array([[
            float(qlen), wait,
            float(se), svc_min,
            float(hour), hs, hc, float(dow),
            fee, float(is_pri), float(de), float(np.log(pop)),
        ]])

        prob    = float(_abandon_model.predict_proba(X)[0][1])
        abandon = bool(prob >= 0.35)
        risk    = 'low' if prob < 0.15 else ('medium' if prob < 0.35 else 'high')
        action  = (
            'Citizen likely to stay — no action needed.' if risk == 'low' else
            'Possible abandonment — display estimated wait clearly.' if risk == 'medium' else
            'High abandonment risk — consider calling next early or updating wait estimate.'
        )
        return jsonify({
            'will_abandon':         abandon,
            'abandon_probability':  round(prob, 3),
            'risk_level':           risk,
            'action':               action,
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/predict/service-duration')
def predict_service_duration():
    """
    Predicted actual duration of one service interaction.

    More accurate than fixed avgMin — accounts for officer fatigue,
    queue rush effect, and district complexity.

    Input JSON:
      serviceType, officeType, hour, dayOfWeek, month,
      queueAtArrival, district, serviceAvgMin
    Output JSON:
      predicted_duration_min, lower_bound_min, upper_bound_min,
      vs_average (ratio to fixed average)
    """
    if _duration_model is None:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        svc     = d.get('serviceType',  'NIC Card')
        ot      = d.get('officeType',   'Divisional Secretariat')
        hour    = int(d.get('hour',     10))
        dow     = int(d.get('dayOfWeek', 3))
        month   = int(d.get('month',    6))
        q_arr   = int(d.get('queueAtArrival', 0))
        dist    = d.get('district',     'Colombo')
        svc_min = float(d.get('serviceAvgMin', 10.0))

        fi  = _feature_info
        se  = _enc(svc, fi['service_type_classes'])
        oe  = _enc(ot,  fi['office_type_classes'])
        de  = _enc(dist, fi['district_classes'])
        pop = DISTRICT_POP.get(dist, AVG_POP)
        hs, hc = _cyc(hour - 8, 9)

        X = np.array([[
            float(se), svc_min, float(oe),
            float(hour), hs, hc,
            float(dow), float(month),
            float(q_arr), float(de), float(np.log(pop)),
        ]])

        pred = float(_duration_model.predict(X)[0])
        # Tree variance for interval
        tree_preds = np.array([t.predict(X)[0] for t in _duration_model.estimators_])
        lo = float(np.percentile(tree_preds, 10))
        hi = float(np.percentile(tree_preds, 90))

        return jsonify({
            'predicted_duration_min': round(pred, 1),
            'lower_bound_min':        round(lo, 1),
            'upper_bound_min':        round(hi, 1),
            'vs_average':             round(pred / max(svc_min, 1), 2),
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/recommend/counters')
def recommend_counters():
    """
    Optimal counter count for an office at a given hour.

    Input JSON:
      officeType, district, serviceType, serviceAvgMin,
      hour, dayOfWeek, month, arrivalsPerHour, availableStaff
    Output JSON:
      recommended_counters (int), utilisation_pct,
      throughput_per_counter, can_handle_demand (bool)
    """
    if _counter_model is None:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        ot       = d.get('officeType',   'Divisional Secretariat')
        dist     = d.get('district',     'Colombo')
        svc      = d.get('serviceType',  'NIC Card')
        svc_min  = float(d.get('serviceAvgMin',     10.0))
        hour     = int(d.get('hour',               10))
        dow      = int(d.get('dayOfWeek',           3))
        month    = int(d.get('month',               6))
        arr_ph   = float(d.get('arrivalsPerHour',  10.0))
        avail    = int(d.get('availableStaff',      5))

        fi  = _feature_info
        oe  = _enc(ot,   fi['office_type_classes'])
        de  = _enc(dist, fi['district_classes'])
        se  = _enc(svc,  fi['service_type_classes'])
        pop = DISTRICT_POP.get(dist, AVG_POP)
        hs, hc = _cyc(hour - 8, 9)
        ds, dc = _cyc(dow  - 1, 6)

        X = np.array([[
            float(hour), hs, hc,
            float(dow), ds, dc, float(month),
            float(oe), float(de), float(np.log(pop)),
            float(se), svc_min, arr_ph, float(avail),
        ]])

        rec         = int(np.clip(round(float(_counter_model.predict(X)[0])), 1, avail))
        throughput  = 60.0 / max(svc_min, 1)
        util        = round(arr_ph / max(rec * throughput, 1) * 100, 1)

        return jsonify({
            'recommended_counters':   rec,
            'utilisation_pct':        min(util, 100.0),
            'throughput_per_counter': round(throughput, 1),
            'can_handle_demand':      bool(util <= 95),
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


@app.post('/predict/satisfaction')
def predict_satisfaction():
    """
    Predicted citizen satisfaction score (1-5) after a visit.

    Input JSON:
      actualWaitMin, predictedWaitMin, serviceType, serviceAvgMin,
      crowdLevelCode, hour, dayOfWeek, isServiceCompleted,
      officeType, district
    Output JSON:
      satisfaction_score (1-5), satisfaction_label,
      score_probabilities, improvement_tip
    """
    if _sat_model is None:
        return _not_ready()
    d = request.get_json(force=True) or {}
    try:
        actual    = float(d.get('actualWaitMin',     30.0))
        pred_wait = float(d.get('predictedWaitMin',  30.0))
        svc       = d.get('serviceType',   'NIC Card')
        svc_min   = float(d.get('serviceAvgMin', 10.0))
        crowd     = int(d.get('crowdLevelCode',  2))
        hour      = int(d.get('hour',            10))
        dow       = int(d.get('dayOfWeek',        3))
        completed = int(d.get('isServiceCompleted', 1))
        ot        = d.get('officeType',  'Divisional Secretariat')
        dist      = d.get('district',    'Colombo')

        ratio = actual / max(pred_wait, 1.0)

        fi  = _feature_info
        se  = _enc(svc,  fi['service_type_classes'])
        oe  = _enc(ot,   fi['office_type_classes'])
        de  = _enc(dist, fi['district_classes'])
        pop = DISTRICT_POP.get(dist, AVG_POP)

        X = np.array([[
            actual, pred_wait, ratio,
            float(se), svc_min,
            float(crowd), float(hour), float(dow),
            float(completed), float(oe), float(de), float(np.log(pop)),
        ]])

        score     = int(_sat_model.predict(X)[0])
        proba     = _sat_model.predict_proba(X)[0]
        classes   = _sat_model.classes_.tolist()
        labels    = {1: 'Very Dissatisfied', 2: 'Dissatisfied', 3: 'Neutral',
                     4: 'Satisfied', 5: 'Very Satisfied'}

        tip = (
            'Great experience predicted — maintain current service speed.' if score >= 4 else
            'Reduce queue length or set more accurate wait estimates to improve satisfaction.' if score == 3 else
            'Citizens are likely unhappy — prioritise faster processing and better communication.'
        )
        return jsonify({
            'satisfaction_score':    score,
            'satisfaction_label':    labels.get(score, 'Unknown'),
            'score_probabilities':   {str(c): round(float(p), 3) for c, p in zip(classes, proba)},
            'improvement_tip':       tip,
        })
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': True}), 400


if __name__ == '__main__':
    _load()
    print('🚀  QueueNova ML Inference Server → http://localhost:5001')
    app.run(host='0.0.0.0', port=5001, debug=False, use_reloader=False)
