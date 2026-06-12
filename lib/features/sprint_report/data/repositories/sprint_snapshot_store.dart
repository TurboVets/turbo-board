import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/sprint_snapshot.dart';

/// Local daily-history store backing the burndown's actual line.
///
/// The GitHub Projects v2 API returns only the board's current state, so the
/// remaining-points-per-day history can't be queried — it has to accrue. On
/// each report view the repository records today's remaining points here, keyed
/// by sprint; over the iteration these accumulate into the burndown actuals.
///
/// Per-device, no backfill (history starts the first day the sprint is viewed).
abstract class SprintSnapshotStore {
  /// Record [remaining] points for sprint [sprintKey] at 0-based [day]. Idempotent
  /// per day — a later capture on the same day overwrites the earlier one.
  Future<void> capture({required String sprintKey, required int day, required int remaining, required DateTime now});

  /// All captured points for [sprintKey], ascending by day.
  Future<List<SprintSnapshot>> history(String sprintKey);
}

class SharedPrefsSprintSnapshotStore implements SprintSnapshotStore {
  const SharedPrefsSprintSnapshotStore();

  static const _prefix = 'sprint_snapshots:';

  @override
  Future<void> capture({
    required String sprintKey,
    required int day,
    required int remaining,
    required DateTime now,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final byDay = {for (final s in await history(sprintKey)) s.day: s};
      byDay[day] = SprintSnapshot(day: day, remaining: remaining, date: _isoDate(now));
      final ordered = byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
      await prefs.setString(_prefix + sprintKey, jsonEncode([for (final s in ordered) s.toJson()]));
    } catch (e, st) {
      // Capture is best-effort; never break the report over a storage hiccup.
      log('Failed to capture sprint snapshot', error: e, stackTrace: st);
    }
  }

  @override
  Future<List<SprintSnapshot>> history(String sprintKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefix + sprintKey);
      if (raw == null) return const [];
      final list = (jsonDecode(raw) as List<dynamic>).whereType<Map<String, dynamic>>();
      return list.map(SprintSnapshot.fromJson).toList()..sort((a, b) => a.day.compareTo(b.day));
    } catch (e, st) {
      log('Failed to read sprint snapshots', error: e, stackTrace: st);
      return const [];
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Builds a contiguous remaining-points-per-day line (day 0..[todayDay]) from
/// captured [history]: carries the last known value forward across days with no
/// snapshot; day 0 defaults to [committedPoints]. Pure — unit-tested directly.
List<int> buildBurndownActuals({
  required int committedPoints,
  required int todayDay,
  required List<SprintSnapshot> history,
}) {
  final byDay = {for (final s in history) s.day: s.remaining};
  final actual = <int>[];
  var last = committedPoints;
  for (var d = 0; d <= todayDay; d++) {
    if (byDay.containsKey(d)) last = byDay[d]!;
    actual.add(last);
  }
  return actual;
}

/// In-memory store for tests.
class InMemorySprintSnapshotStore implements SprintSnapshotStore {
  final Map<String, Map<int, SprintSnapshot>> _data = {};

  @override
  Future<void> capture({
    required String sprintKey,
    required int day,
    required int remaining,
    required DateTime now,
  }) async {
    (_data[sprintKey] ??= {})[day] = SprintSnapshot(
      day: day,
      remaining: remaining,
      date:
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  Future<List<SprintSnapshot>> history(String sprintKey) async =>
      (_data[sprintKey]?.values.toList() ?? [])..sort((a, b) => a.day.compareTo(b.day));
}
