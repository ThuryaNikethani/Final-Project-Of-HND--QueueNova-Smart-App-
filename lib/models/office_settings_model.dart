import 'package:flutter/material.dart';

class OfficeSettings {
  final String officeId;
  final String officeName;
  final Map<int, WorkingHours> workingHours; // Day of week (1-7) -> WorkingHours
  final List<DateTime> holidays;
  final bool isActive;

  OfficeSettings({
    required this.officeId,
    required this.officeName,
    required this.workingHours,
    required this.holidays,
    this.isActive = true,
  });

  bool isWorkingDay(DateTime date) {
    // Check if date is a holiday
    if (holidays.any((holiday) =>
        holiday.year == date.year &&
        holiday.month == date.month &&
        holiday.day == date.day)) {
      return false;
    }

    // Check if it's a working day
    final dayOfWeek = date.weekday;
    return workingHours.containsKey(dayOfWeek);
  }

  bool isWorkingHour(DateTime date, TimeOfDay time) {
    if (!isWorkingDay(date)) return false;

    final dayOfWeek = date.weekday;
    final hours = workingHours[dayOfWeek];
    if (hours == null) return false;

    final timeInMinutes = time.hour * 60 + time.minute;
    final startMinutes = hours.start.hour * 60 + hours.start.minute;
    final endMinutes = hours.end.hour * 60 + hours.end.minute;

    // Check if time is within working hours
    if (timeInMinutes < startMinutes || timeInMinutes > endMinutes) {
      return false;
    }

    // Check if time is in lunch break
    if (hours.isInLunchBreak(time)) {
      return false;
    }

    return true;
  }

  List<DateTime> getUpcomingHolidays(int days) {
    final now = DateTime.now();
    return holidays
        .where((h) => h.isAfter(now) && h.isBefore(now.add(Duration(days: days))))
        .toList()
      ..sort();
  }

  Map<String, dynamic> toJson() {
    return {
      'officeId': officeId,
      'officeName': officeName,
      'workingHours': workingHours.map((key, value) => MapEntry(key.toString(), value.toJson())),
      'holidays': holidays.map((h) => h.toIso8601String()).toList(),
      'isActive': isActive,
    };
  }

  factory OfficeSettings.fromJson(Map<String, dynamic> json) {
    return OfficeSettings(
      officeId: json['officeId'],
      officeName: json['officeName'],
      workingHours: (json['workingHours'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(int.parse(key), WorkingHours.fromJson(value)),
      ),
      holidays: (json['holidays'] as List)
          .map((h) => DateTime.parse(h))
          .toList(),
      isActive: json['isActive'] ?? true,
    );
  }
}

class WorkingHours {
  final TimeOfDay start;
  final TimeOfDay end;
  final List<String> lunchBreakTimes; // e.g., ['12:00-13:00']

  WorkingHours({
    required this.start,
    required this.end,
    this.lunchBreakTimes = const [],
  });

  bool isInLunchBreak(TimeOfDay time) {
    for (var breakTime in lunchBreakTimes) {
      final parts = breakTime.split('-');
      if (parts.length == 2) {
        final startParts = parts[0].split(':');
        final endParts = parts[1].split(':');
        final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        final timeMin = time.hour * 60 + time.minute;
        if (timeMin >= startMin && timeMin <= endMin) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'start': '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      'end': '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      'lunchBreakTimes': lunchBreakTimes,
    };
  }

  factory WorkingHours.fromJson(Map<String, dynamic> json) {
    final startParts = json['start'].split(':');
    final endParts = json['end'].split(':');
    return WorkingHours(
      start: TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1])),
      end: TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1])),
      lunchBreakTimes: List<String>.from(json['lunchBreakTimes'] ?? []),
    );
  }
}