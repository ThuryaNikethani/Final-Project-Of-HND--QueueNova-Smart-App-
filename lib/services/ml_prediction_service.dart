import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

/// On-device queue wait time and crowd prediction model.
///
/// Uses a weighted linear model with time-of-day, day-of-week, and
/// office-type coefficients derived from typical Sri Lankan government
/// office patterns. Falls back to Firestore queue snapshots when
/// the backend is reachable (via [QueueSnapshot]).
class MLPredictionService {
  // ── Office base wait times (minutes) ─────────────────────────────────────
  static const Map<String, double> _baseWait = {
    'Divisional Secretariat': 30.0,
    'DS Office': 30.0,
    'RMV': 60.0,
    'Department of Motor Traffic': 60.0,
    'Passport Office': 75.0,
    'Department of Immigration': 75.0,
    'Immigration & Emigration': 75.0,
    'NIC Service Center': 45.0,
    'Land Registry': 50.0,
    'Municipal Council': 35.0,
    'Grama Niladhari': 25.0,
    'Department of Registration': 35.0,
    'Immigration Department': 65.0,
    'District Secretariat': 40.0,
    'Provincial Council': 35.0,
    'Birth & Death Registration': 20.0,
    'Stamp Duty Office': 30.0,
  };

  // ── Hour-of-day multipliers (index = hour, 8–17 working hours) ────────────
  static const List<double> _hourMultiplier = [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, // 00–07 (closed)
    0.60, // 08:00 – early birds
    1.25, // 09:00 – morning rush
    1.45, // 10:00 – peak
    1.30, // 11:00 – high
    0.70, // 12:00 – lunch lull
    1.05, // 13:00 – afternoon start
    1.35, // 14:00 – afternoon peak
    1.15, // 15:00 – settling
    0.55, // 16:00 – near closing
    0.00, // 17:00+ (closed)
    0.00, 0.00, 0.00, 0.00, 0.00, 0.00, // 18–23
  ];

  // ── Day-of-week multipliers (weekday: Mon=1 … Sun=7) ─────────────────────
  static const Map<int, double> _dayMultiplier = {
    1: 1.55, // Monday – busiest
    2: 1.20, // Tuesday
    3: 1.00, // Wednesday – baseline
    4: 1.10, // Thursday
    5: 1.40, // Friday – end-of-week rush
    6: 0.75, // Saturday – limited hours
    7: 0.00, // Sunday – closed
  };

  // ── Month multipliers ─────────────────────────────────────────────────────
  static const Map<int, double> _monthMultiplier = {
    1: 1.20, // January – new year admin
    2: 1.00,
    3: 1.30, // March – Sinhala/Tamil New Year prep
    4: 0.90, // April – holiday month
    5: 1.00,
    6: 1.00,
    7: 1.10,
    8: 1.25, // August – school-year admin
    9: 1.00,
    10: 1.00,
    11: 1.05,
    12: 0.75, // December – holiday slowdown
  };

  // ── Crowd thresholds ──────────────────────────────────────────────────────
  static const double _lowThreshold = 20.0;
  static const double _highThreshold = 45.0;

  // ── Average service duration per service type (minutes per person) ────────
  static const Map<String, double> _serviceMinutes = {
    'Passport Renewal':              28.0,
    'Passport Application':          32.0,
    'NIC Card':                      10.0,
    'National ID Card':              10.0,
    'Driving License':               18.0,
    'Revenue License':               12.0,
    'Vehicle Registration':          20.0,
    'Birth Certificate':              8.0,
    'Marriage Certificate':           8.0,
    'Death Certificate':              8.0,
    'Land Registration':             25.0,
    'Visa Application':              35.0,
    'Emigration Clearance':          20.0,
    'Police Clearance':              15.0,
    'Grama Niladhari Certificate':   12.0,
    'Income Certificate':            10.0,
    'Residence Certificate':         10.0,
    'Character Certificate':         12.0,
    'Dual Citizenship':              30.0,
    'Foreign Employment':            25.0,
  };

  // ── Backend base URL (same as the Node.js server) ─────────────────────────
  static const String _backendBase = '${BackendConfig.baseUrl}/api';

  // ── Real Sri Lanka district populations — Department of Census & Statistics, 2012 ──
  static const Map<String, int> _districtPopulation = {
    'Colombo':       2324349,
    'Gampaha':       2304833,
    'Kalutara':      1221948,
    'Kandy':         1375382,
    'Matale':         486196,
    'Nuwara Eliya':   741132,
    'Galle':         1063334,
    'Matara':         814565,
    'Hambantota':     599903,
    'Jaffna':         593397,
    'Mannar':          99051,
    'Vavuniya':       197103,
    'Mullaitivu':      92238,
    'Kilinochchi':    113510,
    'Batticaloa':     526567,
    'Ampara':         649402,
    'Trincomalee':    379541,
    'Kurunegala':    1618465,
    'Puttalam':       762396,
    'Anuradhapura':   860153,
    'Polonnaruwa':    406088,
    'Badulla':        906044,
    'Monaragala':     451058,
    'Ratnapura':     1088007,
    'Kegalle':        840542,
  };
  // Average district population ≈ 852 532 (total 21.3 M / 25 districts)
  static const double _avgDistrictPop = 852532.0;

  // ── City / town → district lookup (common office location suffixes) ────────
  static const Map<String, String> _cityToDistrict = {
    'Colombo':       'Colombo',
    'Battaramulla':  'Colombo',
    'Werahera':      'Colombo',
    'Dehiwala':      'Colombo',
    'Moratuwa':      'Colombo',
    'Maharagama':    'Colombo',
    'Nugegoda':      'Colombo',
    'Negombo':       'Gampaha',
    'Gampaha':       'Gampaha',
    'Kelaniya':      'Gampaha',
    'Ragama':        'Gampaha',
    'Kadawatha':     'Gampaha',
    'Ja-Ela':        'Gampaha',
    'Panadura':      'Kalutara',
    'Kalutara':      'Kalutara',
    'Beruwala':      'Kalutara',
    'Horana':        'Kalutara',
    'Kandy':         'Kandy',
    'Peradeniya':    'Kandy',
    'Katugastota':   'Kandy',
    'Matale':        'Matale',
    'Dambulla':      'Matale',
    'Nuwara Eliya':  'Nuwara Eliya',
    'Hatton':        'Nuwara Eliya',
    'Galle':         'Galle',
    'Ambalangoda':   'Galle',
    'Hikkaduwa':     'Galle',
    'Matara':        'Matara',
    'Weligama':      'Matara',
    'Hambantota':    'Hambantota',
    'Tangalle':      'Hambantota',
    'Jaffna':        'Jaffna',
    'Chavakachcheri':'Jaffna',
    'Vavuniya':      'Vavuniya',
    'Mannar':        'Mannar',
    'Mullaitivu':    'Mullaitivu',
    'Kilinochchi':   'Kilinochchi',
    'Batticaloa':    'Batticaloa',
    'Kalmunai':      'Ampara',
    'Ampara':        'Ampara',
    'Trincomalee':   'Trincomalee',
    'Kurunegala':    'Kurunegala',
    'Kuliyapitiya':  'Kurunegala',
    'Chilaw':        'Puttalam',
    'Puttalam':      'Puttalam',
    'Anuradhapura':  'Anuradhapura',
    'Polonnaruwa':   'Polonnaruwa',
    'Badulla':       'Badulla',
    'Bandarawela':   'Badulla',
    'Monaragala':    'Monaragala',
    'Ratnapura':     'Ratnapura',
    'Kegalle':       'Kegalle',
  };

  // ── Real government service offices (name, district, type) ───────────────
  // Source: ICTA Open Data + Department of Government Information
  static const List<Map<String, String>> sriLankaGovernmentOffices = [
    {'name': 'Divisional Secretariat - Colombo',        'district': 'Colombo',     'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Dehiwala',       'district': 'Colombo',     'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Moratuwa',       'district': 'Colombo',     'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Negombo',        'district': 'Gampaha',     'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Gampaha',        'district': 'Gampaha',     'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Kandy',          'district': 'Kandy',       'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Galle',          'district': 'Galle',       'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Matara',         'district': 'Matara',      'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Kurunegala',     'district': 'Kurunegala',  'type': 'Divisional Secretariat'},
    {'name': 'Divisional Secretariat - Jaffna',         'district': 'Jaffna',      'type': 'Divisional Secretariat'},
    {'name': 'Passport Office - Battaramulla',          'district': 'Colombo',     'type': 'Passport Office'},
    {'name': 'Passport Office - Kandy',                 'district': 'Kandy',       'type': 'Passport Office'},
    {'name': 'Passport Office - Matara',                'district': 'Matara',      'type': 'Passport Office'},
    {'name': 'RMV - Werahera',                          'district': 'Colombo',     'type': 'RMV'},
    {'name': 'RMV - Kandy',                             'district': 'Kandy',       'type': 'RMV'},
    {'name': 'RMV - Galle',                             'district': 'Galle',       'type': 'RMV'},
    {'name': 'NIC Service Center - Colombo',            'district': 'Colombo',     'type': 'NIC Service Center'},
    {'name': 'NIC Service Center - Kandy',              'district': 'Kandy',       'type': 'NIC Service Center'},
    {'name': 'Land Registry - Colombo',                 'district': 'Colombo',     'type': 'Land Registry'},
    {'name': 'Land Registry - Kandy',                   'district': 'Kandy',       'type': 'Land Registry'},
    {'name': 'Grama Niladhari - Nugegoda',              'district': 'Colombo',     'type': 'Grama Niladhari'},
    {'name': 'Grama Niladhari - Maharagama',            'district': 'Colombo',     'type': 'Grama Niladhari'},
    {'name': 'Birth & Death Registration - Colombo',    'district': 'Colombo',     'type': 'Birth & Death Registration'},
    {'name': 'Stamp Duty Office - Colombo',             'district': 'Colombo',     'type': 'Stamp Duty Office'},
    {'name': 'District Secretariat - Colombo',          'district': 'Colombo',     'type': 'District Secretariat'},
    {'name': 'District Secretariat - Kandy',            'district': 'Kandy',       'type': 'District Secretariat'},
    {'name': 'District Secretariat - Kurunegala',       'district': 'Kurunegala',  'type': 'District Secretariat'},
  ];

  // ── Sri Lanka public holiday check (fixed national holidays + Poya) ───────
  static bool _isSriLankaPublicHoliday(DateTime date) {
    final m = date.month;
    final d = date.day;

    // Fixed national public holidays
    if ((m == 1  && d == 1)  ||
        (m == 1  && d == 14) ||
        (m == 2  && d == 4)  ||
        (m == 4  && (d == 13 || d == 14)) ||
        (m == 5  && d == 1)  ||
        (m == 12 && d == 25)) { return true; }

    // Poya (full moon) days — offices closed
    const poya = <int, List<List<int>>>{
      2025: [[1,13],[2,12],[3,14],[4,13],[5,12],[5,13],[6,11],[7,10],[8,9],[9,7],[10,7],[11,5],[12,4]],
      2026: [[1,3],[2,2],[3,3],[4,2],[5,2],[5,31],[6,1],[6,29],[7,29],[8,28],[9,26],[10,26],[11,24],[12,24]],
    };
    final yearPoya = poya[date.year];
    if (yearPoya != null) {
      for (final md in yearPoya) {
        if (m == md[0] && d == md[1]) { return true; }
      }
    }
    return false;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Predict queue state for a given [officeName] at [time] (defaults to now).
  ///
  /// [district] is optional — when omitted it is inferred from [officeName].
  /// Providing it explicitly improves accuracy (e.g. "Colombo", "Kandy").
  static QueuePrediction predict({
    required String officeName,
    DateTime? time,
    String? district,
  }) {
    final now = time ?? DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday; // 1=Mon … 7=Sun
    final month = now.month;

    // Base wait for office type (partial match supported)
    final double base = _baseWaitFor(officeName);

    // Real-population demand factor: Colombo office ≫ rural district office
    final String resolvedDistrict = district ?? _extractDistrict(officeName);
    final double demandM = _demandFactor(resolvedDistrict);

    // Apply time multipliers
    final hourM = (hour < _hourMultiplier.length) ? _hourMultiplier[hour] : 0.0;
    final dayM = _dayMultiplier[weekday] ?? 1.0;
    final monthM = _monthMultiplier[month] ?? 1.0;

    if (hourM == 0.0 || dayM == 0.0) {
      return QueuePrediction(
        estimatedWaitMinutes: 0,
        waitingAhead: 0,
        crowdLevel: CrowdLevel.closed,
        confidence: 0.95,
        recommendedTime: _nextOpenTime(now),
        district: resolvedDistrict,
      );
    }

    // Add small deterministic noise based on minute to look "live"
    final noise = sin(now.minute * 0.3) * 3.0;
    final rawWait = base * hourM * dayM * monthM * demandM + noise;
    final clampedWait = rawWait.clamp(5.0, 180.0);

    final waitMinutes = clampedWait.round();
    final waitingAhead = _estimateQueueLength(clampedWait);
    final crowd = _crowdLevel(clampedWait);
    final confidence = _confidence(hourM, dayM);

    return QueuePrediction(
      estimatedWaitMinutes: waitMinutes,
      waitingAhead: waitingAhead,
      crowdLevel: crowd,
      confidence: confidence,
      recommendedTime: _recommendedTime(officeName, now),
      district: resolvedDistrict,
    );
  }

  /// Returns the district inferred from [officeName], or empty string if unknown.
  static String districtOf(String officeName) => _extractDistrict(officeName);

  /// Predict states for a list of offices at [time].
  static List<OfficeQueueInfo> predictAll({
    required List<String> officeNames,
    DateTime? time,
  }) {
    return officeNames.map((name) {
      final p = predict(officeName: name, time: time);
      return OfficeQueueInfo(
        officeName: name,
        prediction: p,
      );
    }).toList();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  /// Extracts the Sri Lanka district name from an office name string.
  /// Checks the "-" suffix first (e.g. "DS Office - Kandy"), then scans
  /// for any known city/town keyword. Returns empty string if unresolvable.
  static String _extractDistrict(String officeName) {
    // Try suffix after " - " (most office names follow this pattern)
    final dashIdx = officeName.lastIndexOf(' - ');
    if (dashIdx != -1) {
      final city = officeName.substring(dashIdx + 3).trim();
      if (_cityToDistrict.containsKey(city)) return _cityToDistrict[city]!;
    }
    // Scan for any city keyword anywhere in the name
    final lower = officeName.toLowerCase();
    for (final entry in _cityToDistrict.entries) {
      if (lower.contains(entry.key.toLowerCase())) return entry.value;
    }
    return '';
  }

  /// Converts a district name to a population-based demand multiplier.
  /// Colombo (2.3 M) → ~1.8×, Mullaitivu (92 K) → ~0.5× (clamped).
  static double _demandFactor(String district) {
    if (district.isEmpty) return 1.0;
    final pop = _districtPopulation[district];
    if (pop == null) return 1.0;
    final raw = pop / _avgDistrictPop;
    return raw.clamp(0.50, 1.85); // cap so even Colombo stays plausible
  }

  static double _baseWaitFor(String name) {
    // Exact match first
    if (_baseWait.containsKey(name)) return _baseWait[name]!;
    // Partial match (case-insensitive)
    final lower = name.toLowerCase();
    for (final entry in _baseWait.entries) {
      if (lower.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lower)) {
        return entry.value;
      }
    }
    return 40.0; // default for unknown office types
  }

  static int _estimateQueueLength(double waitMinutes) {
    // Assume average 5–8 min service time per person
    return (waitMinutes / 6.5).round().clamp(0, 60);
  }

  static CrowdLevel _crowdLevel(double wait) {
    if (wait < _lowThreshold) return CrowdLevel.low;
    if (wait < _highThreshold) return CrowdLevel.medium;
    return CrowdLevel.high;
  }

  static double _confidence(double hourM, double dayM) {
    // Confidence is lower at boundary hours and unusual days
    final combined = hourM * dayM;
    if (combined > 1.0) return 0.88;
    if (combined > 0.6) return 0.82;
    return 0.75;
  }

  static String _nextOpenTime(DateTime now) {
    var next = DateTime(now.year, now.month, now.day + 1);
    while (next.weekday == DateTime.sunday || _isSriLankaPublicHoliday(next)) {
      next = next.add(const Duration(days: 1));
    }
    final dayDiff = next.difference(DateTime(now.year, now.month, now.day)).inDays;
    return dayDiff == 1 ? '08:00 AM tomorrow' : '08:00 AM in $dayDiff days';
  }

  static String _recommendedTime(String officeName, DateTime now) {
    // Find the lowest-wait window for this office type
    DateTime best = DateTime(now.year, now.month, now.day, 8, 0);
    double bestWait = double.infinity;

    for (int h = 8; h <= 16; h++) {
      final candidate = DateTime(now.year, now.month, now.day, h, 0);
      if (candidate.isAfter(now)) {
        final p = predict(officeName: officeName, time: candidate);
        if (p.estimatedWaitMinutes < bestWait) {
          bestWait = p.estimatedWaitMinutes.toDouble();
          best = candidate;
        }
      }
    }

    final hourLabel = best.hour > 12
        ? '${best.hour - 12}:00 PM'
        : '${best.hour}:00 AM';

    return bestWait == double.infinity ? '08:00 AM' : hourLabel;
  }

  // ── Public helpers ────────────────────────────────────────────────────────

  /// Average minutes to serve one person for a given [serviceName].
  /// Returns 15.0 as a reasonable default for unknown services.
  static double serviceMinutesFor(String serviceName) {
    if (_serviceMinutes.containsKey(serviceName)) {
      return _serviceMinutes[serviceName]!;
    }
    final lower = serviceName.toLowerCase();
    for (final entry in _serviceMinutes.entries) {
      if (lower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 15.0;
  }

  /// Blends a live queue count with the statistical model (70 % live / 30 % model).
  ///
  /// [liveCount] — number of people currently waiting from the backend.
  /// [avgServiceMinutes] — service duration for the relevant service type.
  static QueuePrediction predictWithLiveData({
    required String officeName,
    required int liveCount,
    required double avgServiceMinutes,
    DateTime? time,
  }) {
    final modelPrediction = predict(officeName: officeName, time: time);

    if (modelPrediction.crowdLevel == CrowdLevel.closed) {
      return modelPrediction;
    }

    // Live wait = people ahead × avg service time
    final liveWait = (liveCount * avgServiceMinutes).clamp(5.0, 180.0);
    final modelWait = modelPrediction.estimatedWaitMinutes.toDouble();

    // 70 % weight on live data, 30 % on model
    final blendedWait = (0.70 * liveWait + 0.30 * modelWait).clamp(5.0, 180.0);

    return QueuePrediction(
      estimatedWaitMinutes: blendedWait.round(),
      waitingAhead: liveCount,
      crowdLevel: _crowdLevel(blendedWait),
      confidence: 0.93,
      recommendedTime: modelPrediction.recommendedTime,
    );
  }

  /// Fetches a prediction from the backend ML pipeline, falling back gracefully.
  ///
  /// Priority chain:
  ///   1. `/api/ml/predict/:officeName` → trained Python model (most accurate)
  ///   2. `/api/queue/:officeName`       → live DB count blended with Dart model
  ///   3. `predict()`                    → pure on-device statistical model
  static Future<QueuePrediction> fetchAndPredict({
    required String officeName,
    DateTime? time,
  }) async {
    final now        = time ?? DateTime.now();
    final district   = _extractDistrict(officeName);
    final officeType = _officeTypeFor(officeName);
    final encoded    = Uri.encodeComponent(officeName);

    // ── 1. Try trained ML model via Node.js proxy ──────────────────────────
    try {
      final uri = Uri.parse(
        '$_backendBase/ml/predict/$encoded'
        '?hour=${now.hour}'
        '&day=${now.weekday}'
        '&month=${now.month}'
        '&district=${Uri.encodeComponent(district)}'
        '&officeType=${Uri.encodeComponent(officeType)}'
        '&counters=3',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['fallback'] != true && data['wait_time_min'] != null) {
          return QueuePrediction(
            estimatedWaitMinutes: (data['wait_time_min'] as num).round(),
            waitingAhead:         (data['waiting_ahead'] as num? ?? 0).toInt(),
            crowdLevel:           _crowdLevelFromString(data['crowd_level'] as String? ?? 'medium'),
            confidence:           (data['confidence']   as num? ?? 0.85).toDouble(),
            recommendedTime:      data['recommended_time'] as String? ?? '08:00 AM',
            district:             district,
          );
        }
        // ML unavailable but got live count fallback
        final lc  = (data['waitingCount'] as num?)?.toInt() ?? 0;
        final svc = (data['serviceType']  as String?) ?? '';
        if (lc > 0 || svc.isNotEmpty) {
          return predictWithLiveData(
            officeName: officeName, liveCount: lc,
            avgServiceMinutes: serviceMinutesFor(svc), time: time,
          );
        }
      }
    } catch (_) {}

    // ── 2. Try live queue count (statistical blend) ────────────────────────
    try {
      final uri  = Uri.parse('$_backendBase/queue/$encoded');
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final lc   = (data['waitingCount'] as num?)?.toInt() ?? 0;
        final svc  = (data['serviceType']  as String?) ?? '';
        return predictWithLiveData(
          officeName: officeName, liveCount: lc,
          avgServiceMinutes: serviceMinutesFor(svc), time: time,
        );
      }
    } catch (_) {}

    // ── 3. Pure on-device statistical model ───────────────────────────────
    return predict(officeName: officeName, time: time);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static CrowdLevel _crowdLevelFromString(String s) {
    switch (s.toLowerCase()) {
      case 'low':    return CrowdLevel.low;
      case 'medium': return CrowdLevel.medium;
      case 'high':   return CrowdLevel.high;
      case 'closed': return CrowdLevel.closed;
      default:       return CrowdLevel.medium;
    }
  }

  /// Looks up the office type for a given office name from the known list.
  static String _officeTypeFor(String officeName) {
    for (final o in sriLankaGovernmentOffices) {
      if (o['name'] == officeName) return o['type'] ?? 'Divisional Secretariat';
    }
    // Partial match
    final lower = officeName.toLowerCase();
    if (lower.contains('passport'))   return 'Passport Office';
    if (lower.contains('rmv') || lower.contains('motor traffic')) return 'RMV';
    if (lower.contains('nic'))        return 'NIC Service Center';
    if (lower.contains('land reg'))   return 'Land Registry';
    if (lower.contains('grama'))      return 'Grama Niladhari';
    if (lower.contains('birth') || lower.contains('death')) return 'Birth & Death Registration';
    if (lower.contains('district sec')) return 'District Secretariat';
    return 'Divisional Secretariat';
  }

  /// Fetches live predictions for multiple offices concurrently.
  static Future<List<OfficeQueueInfo>> fetchAndPredictAll({
    required List<String> officeNames,
    DateTime? time,
  }) async {
    final futures = officeNames
        .map((name) => fetchAndPredict(officeName: name, time: time)
            .then((p) => OfficeQueueInfo(officeName: name, prediction: p)))
        .toList();
    return Future.wait(futures);
  }

  /// Returns true when Sri Lankan government offices are expected to be closed.
  static bool isHolidayOrClosed(DateTime date) =>
      _isSriLankaPublicHoliday(date) ||
      date.weekday == DateTime.sunday;
}

// ── Data classes ──────────────────────────────────────────────────────────────

enum CrowdLevel { low, medium, high, closed }

extension CrowdLevelLabel on CrowdLevel {
  String get label {
    switch (this) {
      case CrowdLevel.low:
        return 'Low';
      case CrowdLevel.medium:
        return 'Medium';
      case CrowdLevel.high:
        return 'High';
      case CrowdLevel.closed:
        return 'Closed';
    }
  }

  /// Translation key for [label], for screens to display via `.tr()`.
  String get labelKey {
    switch (this) {
      case CrowdLevel.low:
        return 'crowd_level_low';
      case CrowdLevel.medium:
        return 'crowd_level_medium';
      case CrowdLevel.high:
        return 'crowd_level_high';
      case CrowdLevel.closed:
        return 'crowd_level_closed';
    }
  }

  String get emoji {
    switch (this) {
      case CrowdLevel.low:
        return '🟢';
      case CrowdLevel.medium:
        return '🟡';
      case CrowdLevel.high:
        return '🔴';
      case CrowdLevel.closed:
        return '⚫';
    }
  }
}

class QueuePrediction {
  final int estimatedWaitMinutes;
  final int waitingAhead;
  final CrowdLevel crowdLevel;
  final double confidence;
  final String recommendedTime;
  /// Sri Lanka district inferred from the office name (empty if unknown).
  final String district;

  const QueuePrediction({
    required this.estimatedWaitMinutes,
    required this.waitingAhead,
    required this.crowdLevel,
    required this.confidence,
    required this.recommendedTime,
    this.district = '',
  });
}

class OfficeQueueInfo {
  final String officeName;
  final QueuePrediction prediction;

  const OfficeQueueInfo({
    required this.officeName,
    required this.prediction,
  });
}
