import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/office_settings_model.dart';

class OfficeSettingsService {
  static const String _settingsKey = 'office_settings';

  static Future<List<OfficeSettings>> getOfficeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_settingsKey);
    if (data != null && data.isNotEmpty) {
      final List<dynamic> decoded = json.decode(data);
      return decoded.map((e) => OfficeSettings.fromJson(e)).toList();
    }
    return _getDefaultSettings();
  }

  static Future<void> saveOfficeSettings(List<OfficeSettings> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonData = jsonEncode(settings.map((s) => s.toJson()).toList());
    await prefs.setString(_settingsKey, jsonData);
  }

  static List<OfficeSettings> _getDefaultSettings() {
    return [
      OfficeSettings(
        officeId: 'Divisional Secretariat - Colombo',
        officeName: 'Divisional Secretariat - Colombo',
        workingHours: {
          1: WorkingHours( // Monday
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          2: WorkingHours( // Tuesday
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          3: WorkingHours( // Wednesday
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          4: WorkingHours( // Thursday
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          5: WorkingHours( // Friday
            start: TimeOfDay(hour: 8, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            lunchBreakTimes: ['12:00-13:00'],
          ),
        },
        holidays: _getSriLankaPublicHolidays(),
      ),
      OfficeSettings(
        officeId: 'RMV - Werahera',
        officeName: 'RMV - Werahera',
        workingHours: {
          1: WorkingHours(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 16, minute: 0),
            lunchBreakTimes: ['12:30-13:30'],
          ),
          2: WorkingHours(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 16, minute: 0),
            lunchBreakTimes: ['12:30-13:30'],
          ),
          3: WorkingHours(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 16, minute: 0),
            lunchBreakTimes: ['12:30-13:30'],
          ),
          4: WorkingHours(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 16, minute: 0),
            lunchBreakTimes: ['12:30-13:30'],
          ),
          5: WorkingHours(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 16, minute: 0),
            lunchBreakTimes: ['12:30-13:30'],
          ),
        },
        holidays: _getSriLankaPublicHolidays(),
      ),
      OfficeSettings(
        officeId: 'Passport Office - Battaramulla',
        officeName: 'Passport Office - Battaramulla',
        workingHours: {
          1: WorkingHours(
            start: TimeOfDay(hour: 8, minute: 30),
            end: TimeOfDay(hour: 16, minute: 30),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          2: WorkingHours(
            start: TimeOfDay(hour: 8, minute: 30),
            end: TimeOfDay(hour: 16, minute: 30),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          3: WorkingHours(
            start: TimeOfDay(hour: 8, minute: 30),
            end: TimeOfDay(hour: 16, minute: 30),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          4: WorkingHours(
            start: TimeOfDay(hour: 8, minute: 30),
            end: TimeOfDay(hour: 16, minute: 30),
            lunchBreakTimes: ['12:00-13:00'],
          ),
          5: WorkingHours(
            start: TimeOfDay(hour: 8, minute: 30),
            end: TimeOfDay(hour: 16, minute: 30),
            lunchBreakTimes: ['12:00-13:00'],
          ),
        },
        holidays: _getSriLankaPublicHolidays(),
      ),
    ];
  }

  static List<DateTime> _getSriLankaPublicHolidays() {
    final year = DateTime.now().year;

    // Fixed national public holidays (same date every year)
    final holidays = <DateTime>[
      DateTime(year, 1, 1),   // New Year's Day
      DateTime(year, 1, 14),  // Tamil Thai Pongal Day
      DateTime(year, 2, 4),   // National Day (Independence Day)
      DateTime(year, 4, 13),  // Sinhala & Tamil New Year Eve
      DateTime(year, 4, 14),  // Sinhala & Tamil New Year
      DateTime(year, 5, 1),   // International Workers' Day (May Day)
      DateTime(year, 12, 25), // Christmas Day
    ];

    // Full Moon (Poya) days — every full moon is a public holiday in Sri Lanka.
    // Dates follow the lunar calendar; admin can update via Web Settings each year.
    const poyaDays = <int, List<List<int>>>{
      2025: [
        [1, 13],  // Duruthu Poya
        [2, 12],  // Navam Poya
        [3, 14],  // Madin Poya
        [4, 13],  // Bak Poya
        [5, 12], [5, 13],  // Vesak Poya (2 days)
        [6, 11],  // Poson Poya
        [7, 10],  // Esala Poya
        [8, 9],   // Nikini Poya
        [9, 7],   // Binara Poya
        [10, 7],  // Vap Poya
        [11, 5],  // Il Poya
        [12, 4],  // Unduvap Poya
      ],
      2026: [
        [1, 3],   // Duruthu Poya
        [2, 2],   // Navam Poya
        [3, 3],   // Madin Poya
        [4, 2],   // Bak Poya
        [5, 2],   // Extra full moon Poya
        [5, 31],  // Vesak Poya (Day 1)
        [6, 1],   // Vesak Poya (Day 2)
        [6, 29],  // Poson Poya
        [7, 29],  // Esala Poya
        [8, 28],  // Nikini Poya
        [9, 26],  // Binara Poya
        [10, 26], // Vap Poya
        [11, 24], // Il Poya
        [12, 24], // Unduvap Poya
      ],
    };

    final yearPoya = poyaDays[year];
    if (yearPoya != null) {
      for (final md in yearPoya) {
        holidays.add(DateTime(year, md[0], md[1]));
      }
    }

    // Variable religious public holidays (shift annually with lunar calendars).
    // Dates are approximate — admin should verify via Web Settings each year.
    const religiousHolidays = <int, List<List<int>>>{
      2025: [
        [2, 26],  // Maha Sivarathri
        [3, 31],  // Eid-ul-Fitr (Ramazan Festival Day)
        [4, 18],  // Good Friday
        [6, 7],   // Eid-ul-Adha (Hadji Festival Day)
        [9, 4],   // Milad-un-Nabi (Prophet's Birthday)
        [10, 20], // Deepavali Festival Day
      ],
      2026: [
        [2, 16],  // Maha Sivarathri
        [3, 20],  // Eid-ul-Fitr (Ramazan Festival Day)
        [4, 3],   // Good Friday
        [5, 27],  // Eid-ul-Adha (Hadji Festival Day)
        [8, 25],  // Milad-un-Nabi
        [11, 8],  // Deepavali Festival Day
      ],
    };

    final yearReligious = religiousHolidays[year];
    if (yearReligious != null) {
      for (final md in yearReligious) {
        holidays.add(DateTime(year, md[0], md[1]));
      }
    }

    // Deduplicate (e.g. Bak Poya may overlap with Sinhala New Year Eve)
    final seen = <String>{};
    return holidays
        .where((d) => seen.add('${d.year}-${d.month}-${d.day}'))
        .toList()
      ..sort();
  }

  // Default settings for offices not individually configured:
  // Mon–Fri, 8:00–17:00, lunch 12:00–13:00, all SL public holidays closed.
  static OfficeSettings _getGenericOfficeSettings(String officeId) {
    return OfficeSettings(
      officeId: officeId,
      officeName: officeId,
      workingHours: {
        for (int day = 1; day <= 5; day++)
          day: WorkingHours(
            start: const TimeOfDay(hour: 8, minute: 0),
            end: const TimeOfDay(hour: 17, minute: 0),
            lunchBreakTimes: ['12:00-13:00'],
          ),
      },
      holidays: _getSriLankaPublicHolidays(),
    );
  }

  static Future<OfficeSettings?> getOfficeSettingsById(String officeId) async {
    final settings = await getOfficeSettings();
    try {
      return settings.firstWhere((s) => s.officeId == officeId);
    } catch (e) {
      return _getGenericOfficeSettings(officeId);
    }
  }

  static Future<bool> isOfficeWorking(String officeId, DateTime date, TimeOfDay time) async {
    final settings = await getOfficeSettingsById(officeId);
    if (settings == null) return true; // If no settings, allow booking
    return settings.isWorkingHour(date, time);
  }

  static Future<List<DateTime>> getOfficeHolidays(String officeId) async {
    final settings = await getOfficeSettingsById(officeId);
    if (settings == null) return [];
    return settings.holidays;
  }

  static Future<List<DateTime>> getUpcomingHolidays(String officeId, {int days = 30}) async {
    final settings = await getOfficeSettingsById(officeId);
    if (settings == null) return [];
    return settings.getUpcomingHolidays(days);
  }

  static Future<Map<String, dynamic>> getOfficeAvailability(
    String officeId,
    DateTime date,
  ) async {
    final settings = await getOfficeSettingsById(officeId);
    if (settings == null) {
      return {
        'isWorking': true,
        'message': 'Office available',
        'start': null,
        'end': null,
        'lunchBreak': [],
      };
    }

    if (!settings.isWorkingDay(date)) {
      return {
        'isWorking': false,
        'message': 'Office is closed on this day',
        'start': null,
        'end': null,
        'lunchBreak': [],
      };
    }

    final dayOfWeek = date.weekday;
    final hours = settings.workingHours[dayOfWeek];
    if (hours == null) {
      return {
        'isWorking': false,
        'message': 'Office is closed on this day',
        'start': null,
        'end': null,
        'lunchBreak': [],
      };
    }

    return {
      'isWorking': true,
      'message': 'Office is open',
      'start': hours.start,
      'end': hours.end,
      'lunchBreak': hours.lunchBreakTimes,
    };
  }
}