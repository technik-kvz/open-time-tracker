import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:open_project_time_tracker/app/live_activity/domain/live_activity_manager.dart';
import 'package:open_project_time_tracker/app/live_activity/infrastructure/default_live_activity_manager.dart';
import 'package:open_project_time_tracker/app/ui/bloc/bloc.dart';
import 'package:open_project_time_tracker/l10n/app_localizations.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/time_entries_repository.dart';
import 'package:open_project_time_tracker/modules/timer/domain/timer_repository.dart';

part 'timer_bloc.freezed.dart';

@freezed
class TimerState with _$TimerState {
  const factory TimerState.idle({
    required DateTime startTime,
    required DateTime endTime,
    required String title,
    required String subtitle,
    required List<TimeEntry>? timeEntries,
  }) = _Idle;
}

@freezed
class TimerEffect with _$TimerEffect {
  const factory TimerEffect.finish() = _Finish;
}

class TimerBloc extends EffectCubit<TimerState, TimerEffect> {
  final TimerRepository _timerRepository;

  // Track current task to detect task switches
  String? _currentTaskTitle;

  AppLocalizations _l10n() {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final resolvedLocale = basicLocaleListResolution([
      deviceLocale,
    ], AppLocalizations.supportedLocales);

    return lookupAppLocalizations(resolvedLocale);
  }

  TimerBloc(this._timerRepository)
    : super(
        TimerState.idle(
          startTime: DateTime.now(),
          endTime: DateTime.now(), /// TODO
          title: '',
          subtitle: '',
          timeEntries: [],
        ),
      );

  Future<void> updateState() async {
    final data = await Future.wait([
      _timerRepository.timeEntry,
      _timerRepository.startTime,
      _timerRepository.endTime,
      _timerRepository.timeEntries,
    ]);
    try {
      final timeEntry = data[0] as TimeEntry?;
      if (timeEntry == null) {
        _currentTaskTitle = null;
        // Emit empty idle state
        emit(
          TimerState.idle(
            startTime: DateTime.now(),
            endTime: DateTime.now(),
            title: '',
            subtitle: '',
            timeEntries: [],
          ),
        );
        return;
      }

      List<TimeEntry> timeEntries = await _timerRepository.timeEntries ?? [];
      final DateTime? lastEnd = timeEntries.isEmpty ? null : DateTime.tryParse(timeEntries.last.endTime);
      DateTime startTime = DateTime.tryParse(timeEntry.startTime) ?? lastEnd ?? state.startTime;
      DateTime endTime = DateTime.tryParse(timeEntry.endTime) ?? (lastEnd != null ? DateTime.now() : state.endTime);
      if (startTime.toIso8601String() != timeEntry.startTime || endTime.toIso8601String() != timeEntry.endTime) {
        emit(state.copyWith(startTime: startTime, endTime: endTime));
        await _timerRepository.updateTimer(startTime: startTime, stopTime: endTime);
      }

      final taskChanged = _currentTaskTitle != null && _currentTaskTitle != timeEntry.workPackageSubject;
      if (taskChanged) {
        _currentTaskTitle = null;
      }
      _currentTaskTitle = timeEntry.workPackageSubject;

      emit(
        TimerState.idle(
          startTime: startTime,
          endTime: endTime,
          title: timeEntry.workPackageSubject,
          subtitle: timeEntry.projectTitle,
          timeEntries: timeEntries
        ),
      );
    } catch (e) {
      print('Cannot load timer data: $e');
    }
  }

  Future<void> reset() async {
    await _timerRepository.reset();
    _currentTaskTitle = null;
  }

  Future<void> start() async {
    await _timerRepository.startTimer(startTime: DateTime.now());

    // Get the actual time spent to handle resume correctly
    final startTime = await _timerRepository.startTime;

    _currentTaskTitle = state.title;
    await updateState();
  }

  Future<void> stop() async {
    await _timerRepository.stopTimer(stopTime: DateTime.now());
    await updateState();
  }

  Future<void> finish() async {
    await updateState();
    emitEffect(const TimerEffect.finish());
  }


  Future<void> update(DateTime start, DateTime end) async {
    await _timerRepository.updateTimer(startTime: start, stopTime: end);
    final TimeEntry? timeEntry = await _timerRepository.timeEntry;
    if (timeEntry != null) {
      DateTime startTime = DateTime.tryParse(timeEntry.startTime)!;
      DateTime endTime = DateTime.tryParse(timeEntry.endTime)!;
      emit(state.copyWith(startTime: startTime, endTime: endTime));
    }
  }

  Future<void> add(Duration duration) async {
    await _timerRepository.add(duration);
    final startTime = state.startTime;
    final endTime = state.endTime.add(duration);
    emit(state.copyWith(startTime: startTime, endTime: endTime));
  }
}
