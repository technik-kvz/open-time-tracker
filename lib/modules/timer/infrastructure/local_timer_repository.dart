import 'package:flutter/material.dart';
import 'package:open_project_time_tracker/app/storage/timer_storage.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/time_entries_repository.dart';
import 'package:open_project_time_tracker/modules/timer/domain/timer_repository.dart';
import 'package:rxdart/rxdart.dart';

class LocalTimerRepository implements TimerRepository {
  final TimerStorage _timerStorage;

  final _state = BehaviorSubject<bool>();

  LocalTimerRepository(this._timerStorage);

  @override
  Stream<bool> observeIsSet() => _state.doOnListen(() async {
    await _init();
  });

  Future<void> _init() async {
    _state.add(await isSet);
  }

  @override
  Future<bool> get isSet async {
    final timeEntry = await _timerStorage.getTimeEntry();
    return timeEntry != null;
  }

  @override
  Future<bool> get isActive async {
    DateTime? startTime;
    DateTime? endTime;
    final TimeEntry? timeEntry = await _timerStorage.getTimeEntry();
    if ((timeEntry != null) && (timeEntry.startTime != "null")) {
      startTime = DateTime.tryParse(timeEntry.startTime);
    }
    if ((timeEntry != null) && (timeEntry.endTime != "null")) {
      endTime = DateTime.tryParse(timeEntry.endTime);
    }
    return startTime != null && endTime == null;
  }

  @override
  Future<TimeEntry?> get timeEntry async {
    return _timerStorage.getTimeEntry();
  }

  @override
  Future<DateTime> get startTime async {
    final TimeEntry? timeEntry = await _timerStorage.getTimeEntry();
    if ((timeEntry != null) && (timeEntry.startTime != "null")) {
      final DateTime? startTime = DateTime.tryParse(timeEntry.startTime);
      if (startTime != null) {
        return startTime;
      }
    }
    return DateTime.now();
  }
  @override
  Future<DateTime> get endTime async {
    final TimeEntry? timeEntry = await _timerStorage.getTimeEntry();
    if ((timeEntry != null) && (timeEntry.endTime != "null")) {
      final DateTime? endTime = DateTime.tryParse(timeEntry.endTime);
      if (endTime != null) {
        return endTime;
      }
    }
    return DateTime.now();
  }

  @override
  Future<void> setTimeEntry({required TimeEntry timeEntry}) async {
    DateTime sT = DateTime.now();
    if (timeEntry.startTime != "null") {
      sT = DateTime.parse(timeEntry.startTime);
    }
    DateTime eT = sT.add(timeEntry.hours);
    if (timeEntry.endTime != "null") {
      eT = DateTime.parse(timeEntry.endTime);
    }
    await Future.wait([
      _timerStorage.setTimeEntry(timeEntry),
    ]);
    _state.add(true);
  }

  @override
  Future<void> startTimer({required DateTime startTime}) async {
    DateTime? endTime;
    final TimeEntry? timeEntry = await _timerStorage.getTimeEntry();
    if (timeEntry != null) {
      final Duration diff = timeEntry.hours;
      timeEntry.startTime = startTime.toIso8601String();
      endTime = startTime.add(diff);
      timeEntry.endTime = "null";
      timeEntry.hoursValue = diff;
    }
    await Future.wait([
      _timerStorage.setTimeEntry(timeEntry)
    ]);
  }

  @override
  Future<void> stopTimer({required DateTime stopTime}) async {
    DateTime? startTime;
    final TimeEntry? timeEntry = await _timerStorage.getTimeEntry();
    if (timeEntry != null) {
      if (timeEntry.startTime == "null") {
        final Duration diff = timeEntry.hours;
        startTime = DateTime.now().add(-diff);
        timeEntry.startTime = startTime.toIso8601String();
      }
      timeEntry.endTime = stopTime.toIso8601String();
    }
    await Future.wait([
      _timerStorage.setTimeEntry(timeEntry)
    ]);
  }

  @override
  Future<void> updateTimer({required DateTime startTime, required DateTime stopTime}) async {
    final TimeEntry? timeEntry = await _timerStorage.getTimeEntry();
    if (timeEntry != null) {
      timeEntry.startTime = startTime.toIso8601String();
      timeEntry.endTime = stopTime.toIso8601String();
    }
    await Future.wait([
      _timerStorage.setTimeEntry(timeEntry)
    ]);
  }

  @override
  Future<void> reset() async {
    await Future.wait([
      _timerStorage.setTimeEntry(null),
    ]);
    _state.add(false);
  }

  @override
  Future<void> add(Duration duration) async {
    DateTime? startTime;
    DateTime? endTime;
    final TimeEntry? timeEntry = await _timerStorage.getTimeEntry();
    if (timeEntry != null) {
      final Duration diff = timeEntry.hours;
      if (timeEntry.startTime == "null") {
        startTime = DateTime.now().add(-diff);
        timeEntry.startTime = startTime.toIso8601String();
      }
      if (timeEntry.endTime == "null") {
        startTime = DateTime.parse(timeEntry.startTime);
        timeEntry.endTime = startTime.add(diff).toIso8601String();
      }
      endTime = DateTime.parse(timeEntry.endTime).add(duration);
      timeEntry.endTime = endTime.toIso8601String();
    }
    await Future.wait([
      _timerStorage.setTimeEntry(timeEntry)
    ]);
  }
}
