import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:open_project_time_tracker/app/ui/bloc/bloc.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/time_entries_repository.dart';
import 'package:open_project_time_tracker/modules/timer/domain/timer_repository.dart';
import 'package:open_project_time_tracker/modules/timer/domain/timer_service.dart';

part 'time_entry_summary_bloc.freezed.dart';

@freezed
class TimeEntrySummaryState with _$TimeEntrySummaryState {
  const factory TimeEntrySummaryState.loading() = _Loading;
  const factory TimeEntrySummaryState.idle({
    required String title,
    required TimeEntry timeEntry,
    required List<String>? commentSuggestions,
  }) = _Idle;
}

@freezed
class TimeEntrySummaryEffect with _$TimeEntrySummaryEffect {
  const factory TimeEntrySummaryEffect.complete({
    required TimeEntry timeEntry,
  }) = _Complete;
  const factory TimeEntrySummaryEffect.error() = _Error;
}

class TimeEntrySummaryBloc
    extends EffectCubit<TimeEntrySummaryState, TimeEntrySummaryEffect> {
  final TimeEntriesRepository _timeEntriesRepository;
  final TimerRepository _timerRepository;
  final TimerService _timerService;

  TimeEntry? timeEntry;
  List<String>? _commentSuggestions;
  bool _disposed = false;

  TimeEntrySummaryBloc(
    this._timeEntriesRepository,
    this._timerRepository,
    this._timerService,
  ) : super(const TimeEntrySummaryState.loading()) {
    _init();
  }

  Future<void> _emitIdleState() async {
    if (!_disposed) {
      emit(
        TimeEntrySummaryState.idle(
          title: timeEntry!.workPackageSubject,
          timeEntry: timeEntry!,
          commentSuggestions: _commentSuggestions,
        ),
      );
    }
  }

  Future<void> _init() async {
    TimeEntry? _timeEntry = await _timerRepository.timeEntry;
    int? workPackageId;
    if (_timeEntry != null) {
      final workPackageIdString = _timeEntry.workPackageHref.split('/').last;
      workPackageId = int.tryParse(workPackageIdString);
    }
    final timeEntries = await _timeEntriesRepository.list(workPackageId: workPackageId, pageSize: 100,);
    _timeEntry = await _timerRepository.timeEntry;
    
    if (_timeEntry != null) {
      this.timeEntry = _timeEntry;

      if (_disposed) return; // Check after setup, before emit
      await _emitIdleState();

      try {
        if (_disposed) return; // Exit after network call if disposed
        
        var comments = timeEntries.map((e) => e.comment ?? '').toSet().toList();
        comments.remove('');
        _commentSuggestions = comments;
        await _emitIdleState();
      } catch (e) {
        if (_disposed) return;
        print(e);
        _commentSuggestions = [];
        await _emitIdleState();
      }
    } else {
      if (!_disposed) emitEffect(const TimeEntrySummaryEffect.error());
    }
  }

  Future<void> updateTimeSpent(Duration timeSpent) async {
    timeEntry!.hoursValue = timeSpent;
    if (timeEntry!.startTime != "null") {
      timeEntry!.endTime = DateTime.parse(timeEntry!.startTime).add(timeSpent).toIso8601String();
    }
    await _emitIdleState();
  }

  Future<void> updateComment(String comment) async {
    timeEntry!.comment = comment;
    await _emitIdleState();
  }

  Future<void> updateCustomField(String customField, String iKey) async {
    try {
      Map<String, String> cF = Map<String, String>.from(timeEntry!.customField);
      if (TimeEntry.bekannteFelder.containsKey(iKey)) {
        switch(TimeEntry.bekannteFelder[iKey] as BekannteFelder) {
          case BekannteFelder.anteilTechnik:
            cF[iKey] = customField;
            break;
          case BekannteFelder.anteilPause:
            cF[iKey] = customField;
            break;
        }
      } else {
        cF[iKey] = customField;
      }
      timeEntry!.customField = cF;
    }
    catch(e) {
      e.toString();
    }
    finally {
    }
    await _emitIdleState();
  }
  Future<void> updateCustomFieldName(String customFieldName, String iKey) async {
    try {
        Map<String, String> cFN = Map<String, String>.from(timeEntry!.customFieldName);
        cFN[iKey] = customFieldName;
        timeEntry!.customFieldName = cFN;
    }
    catch(e) {
      e.toString();
    }
    finally {
    }
    await _emitIdleState();
  }

  Future<void> submit() async {
    if (_disposed) return;
    emit(const TimeEntrySummaryState.loading());
    try {
      final submittedEntry = await _timerService.submit(timeEntry: timeEntry);
      if (!_disposed) {
        emitEffect(TimeEntrySummaryEffect.complete(timeEntry: submittedEntry));
      }
    } catch (e) {
      if (_disposed) return;
      _emitIdleState();
      emitEffect(const TimeEntrySummaryEffect.error());
    }
  }

  @override
  Future<void> close() {
    _disposed = true;
    return super.close();
  }
}
