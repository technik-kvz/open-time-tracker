import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide FilledButton;
import 'package:intl/intl.dart';
import 'package:open_project_time_tracker/app/app_router.dart';
import 'package:open_project_time_tracker/app/ui/bloc/bloc_page.dart';
import 'package:open_project_time_tracker/app/ui/widgets/activity_indicator.dart';
import 'package:open_project_time_tracker/app/ui/widgets/filled_button.dart';
import 'package:open_project_time_tracker/app/ui/widgets/time_picker.dart';
import 'package:open_project_time_tracker/extensions/duration.dart';
import 'package:open_project_time_tracker/l10n/app_localizations.dart';
import 'package:open_project_time_tracker/modules/timer/ui/time_entry_summary/time_entry_summary_bloc.dart';

import '../../../task_selection/domain/time_entries_repository.dart';


// ignore: must_be_immutable
class TimeEntrySummaryPage
    extends
        EffectBlocPage<
          TimeEntrySummaryBloc,
          TimeEntrySummaryState,
          TimeEntrySummaryEffect
        > {
  final _form = GlobalKey<FormState>();
  final _timeFieldController = TextEditingController();
  final _commentFieldController = TextEditingController();
  late final List<TextEditingController> _customFieldsFieldController = [];

  TimeEntry? _timeEntry;

  TimeEntrySummaryPage({super.key});

  void _showTimePicker(BuildContext context) {
    if (_timeEntry != null) {
      final Duration spendTime = _timeEntry!.hours;
      if (spendTime.inSeconds <= 0) {
        final hours = spendTime.inHours;
        final minutes = spendTime.inMinutes.remainder(60);
        showCupertinoModalPopup(
          context: context,
          builder: ((_) =>
              TimePicker(
                hours: hours,
                minutes: minutes,
                onTimeChanged: (value) {
                  final duration = Duration(
                      hours: value.hour, minutes: value.minute);
                  context.read<TimeEntrySummaryBloc>().updateTimeSpent(
                      duration);
                },
              )),
        );
      }
    }
  }

  void _updateCustomFieldController(BuildContext context, String cF, String iKey) {
    if ((_timeEntry != null) && _timeEntry!.customField.containsKey(iKey) && TimeEntry.bekannteFelder.containsKey(iKey)) {
    } else {
      context.read<TimeEntrySummaryBloc>().updateCustomField(cF, iKey);
    }
  }

  void _showTimePickerCustomField(BuildContext context, int i, String iKey) {
    try {
      if ((_timeEntry != null) && _timeEntry!.customField.containsKey(iKey) && TimeEntry.bekannteFelder.containsKey(iKey)) {
        final String cF = _timeEntry!.customField[iKey] as String;
        double altF = double.tryParse(TimeEntry.defaultCustomFields[iKey]!) ?? 0.0;
        double mF = double.infinity;
        switch (TimeEntry.bekannteFelder[iKey] as BekannteFelder) {
          case BekannteFelder.anteilTechnik:
            altF = _timeEntry!.hours.inMinutes / 60.0;
            mF = _timeEntry!.hours.inMinutes / 60.0;
            break;
          case BekannteFelder.anteilPause :
            mF = _timeEntry!.hours.inMinutes / 60.0;
            break;
        }
        double f = double.tryParse(cF) ?? altF;
        final int h = f.floor();
        final double dm = (f - h.toDouble()) * 60.0;
        final int m = dm.round();
        final Duration spendTime = Duration(hours: h, minutes: m);
        final hours = spendTime.inHours;
        final minutes = spendTime.inMinutes.remainder(60);
        showCupertinoModalPopup(
          context: context,
          builder: ((_) =>
            TimePicker(
              hours: hours,
              minutes: minutes,
              minuteInterval : 1,
              onTimeChanged: (value) {
                final Duration newDuration = Duration(hours: value.hour, minutes: value.minute);
                final double doubleDuration = (newDuration.inMinutes / 60.0);
                final double finalDuration = (doubleDuration >= 0.0) && (doubleDuration <= mF) ? doubleDuration : mF;
                context.read<TimeEntrySummaryBloc>().updateCustomField(finalDuration.toStringAsFixed(3), iKey);
                //print(jsonEncode(_timeEntry).toString());
                final Duration correctDuration = Duration(minutes: (finalDuration * 60.0).round());
                _customFieldsFieldController[i].text = correctDuration.shortWatch();
              },
            )
          ),
        );
      }
    } catch(e) {
      print(e.toString());
    }
    finally {
    }
  }

  Future<void> _submit(BuildContext context) async {
    _form.currentState?.save();
    context.read<TimeEntrySummaryBloc>().submit();
  }

  void _showCommentSuggestions(
    BuildContext context,
    List<String> commentSuggestions,
  ) {
    AppRouter.routeToCommentSuggestions(
      context: context,
      comments: commentSuggestions,
      handler: (comment) {
        context.read<TimeEntrySummaryBloc>().updateComment(comment);
        _commentFieldController.text = comment;
      },
    );
  }

  @override
  void onEffect(BuildContext context, TimeEntrySummaryEffect effect) {
    effect.when(
      complete: (timeEntry) {
        // Just pop back with the created entry - let it bubble up the navigation stack
        Navigator.of(context).pop(timeEntry);
      },
      error: () {
        final snackBar = SnackBar(
          content: Text(AppLocalizations.of(context).generic_error),
          duration: const Duration(seconds: 2),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      },
    );
  }

  @override
  void onStateChange(BuildContext context, TimeEntrySummaryState state) {
    super.onStateChange(context, state);
    state.whenOrNull(
      idle: (title, timeEntry, commentSuggestions, timeEntries) {
        this._timeEntry = timeEntry;
        if ((timeEntry.customField != null) && timeEntry.customField.isNotEmpty) {
          for (int i=0; i<timeEntry.customField.length; i++) {
            while (_customFieldsFieldController.length <= i) {
              _customFieldsFieldController.add(TextEditingController());
            }
            final String iKey = timeEntry.customField.keys.elementAt(i);
            if (TimeEntry.bekannteFelder.containsKey(iKey)) {
              switch (TimeEntry.bekannteFelder[iKey] as BekannteFelder) {
                case BekannteFelder.anteilTechnik:
                  final String cFT = timeEntry.customField[iKey] ?? '';
                  final double f = double.tryParse(cFT) ?? -1.0;
                  final double ref = timeEntry.hours.inMinutes / 60.0;
                  final String cF = (cFT == '') ? timeEntry.hours.shortWatch() : (f >= 0.0) && (f < ref) ? Duration(minutes: (f * 60.0).round()).shortWatch() : timeEntry.hours.shortWatch();
                  _customFieldsFieldController[i].text = cF;
                  break;
                case BekannteFelder.anteilPause:
                  final String cFT = timeEntry.customField[iKey] ?? '';
                  final double f = double.tryParse(cFT) ?? -1.0;
                  final double ref = timeEntry.hours.inMinutes / 60.0;
                  final String cF = (cFT == '') ? timeEntry.hours.shortWatch() : (f >= 0.0) && (f < ref) ? Duration(minutes: (f * 60.0).round()).shortWatch() : timeEntry.hours.shortWatch();
                  _customFieldsFieldController[i].text = cF;
                  break;
              }
            } else {
              _customFieldsFieldController[i].text = timeEntry.customField[iKey] ?? '';
            }
          }
        }
        if ((timeEntry.customFieldName != null) && timeEntry.customFieldName.isNotEmpty) {
          for (int i=0; i<timeEntry.customFieldName.length; i++) {
            while (_customFieldsFieldController.length <= i) {
              _customFieldsFieldController.add(TextEditingController());
            }
          }
        }
        // TODO: fix comment lose after hot reload
        _commentFieldController.text = timeEntry.comment ?? '';
      },
    );
  }

  @override
  Widget buildState(BuildContext context, TimeEntrySummaryState state) {
    final deviceSize = MediaQuery.of(context).size;
    final buttonWidth = deviceSize.width * 0.7;

    if (_timeEntry != null) {
      if (_timeEntry!.customField.isNotEmpty) {
        for (int i = 0; i < _timeEntry!.customField.length; i++) {
          while (_customFieldsFieldController.length <= i) {
            _customFieldsFieldController.add(TextEditingController());
          }
        }
      }
      if (_timeEntry!.customFieldName.isNotEmpty) {
        for (int i = 0; i < _timeEntry!.customFieldName.length; i++) {
          while (_customFieldsFieldController.length <= i) {
            _customFieldsFieldController.add(TextEditingController());
          }
        }
      }
    }

    final Widget body = state.when(
      loading: () => const Center(child: ActivityIndicator()),
      idle: (title, timeEntry, commentSuggestions, timeEntries) {
        this._timeEntry = timeEntry;
        if (timeEntry.customField != null) {
          if (timeEntry.customField.isNotEmpty) {
            for (int i = 0; i < timeEntry.customField.length; i++) {
              while (_customFieldsFieldController.length <= i) {
                _customFieldsFieldController.add(TextEditingController());
              }
            }
          }
        }
        if (timeEntry.customFieldName != null) {
          if (timeEntry.customFieldName.isNotEmpty) {
            for (int i = 0; i < timeEntry.customFieldName.length; i++) {
              while (_customFieldsFieldController.length <= i) {
                _customFieldsFieldController.add(TextEditingController());
              }
            }
          }
        }
        _timeFieldController.text = timeEntry.hours.shortWatch();
        DateTime? _startTime = DateTime.tryParse(timeEntry.startTime);
        if (_startTime == null) {
          if (timeEntries != null) {
            for (int j = 0; j < timeEntries.length; j++) {
              DateTime? jD = DateTime.tryParse(timeEntries[j].endTime);
              if (jD != null) {
                _startTime = jD;
              }
            }
            _startTime ??= DateTime.now();
          } else {
            _startTime = DateTime.now();
          }
        }
        DateTime? _endTime = DateTime.tryParse(timeEntry.endTime);
        _endTime ??= _startTime;
        Padding retP = Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: title,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).time_entry_summary_task,
                      ),
                      enabled: false,
                    ),
                    TextFormField(
                      initialValue: timeEntry.projectTitle,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).time_entry_summary_project,
                      ),
                      enabled: false,
                    ),
                    TextFormField(
                      initialValue: DateFormat("yyyy-MM-dd HH:mm").format(_startTime.toLocal()),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).time_entry_summary_project,
                      ),
                      enabled: false,
                    ),
                    TextFormField(
                      initialValue: DateFormat("yyyy-MM-dd HH:mm").format(_endTime.toLocal()),
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).time_entry_summary_project,
                      ),
                      enabled: false,
                    ),
                    TextFormField(
                      controller: _timeFieldController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).time_entry_summary_time_spent,
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    TextFormField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _commentFieldController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(
                          context,
                        ).time_entry_summary_comment,
                        suffixIcon: commentSuggestions == null
                            ? SizedBox(
                                width: IconTheme.of(context).size,
                                height: IconTheme.of(context).size,
                                child: const ActivityIndicator(),
                              )
                            : commentSuggestions.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => _showCommentSuggestions(
                                  context,
                                  commentSuggestions,
                                ),
                                icon: const Icon(Icons.more_horiz),
                              ),
                      ),
                      readOnly: false,
                      onChanged: (_) => context
                          .read<TimeEntrySummaryBloc>()
                          .updateComment(_commentFieldController.text),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: SizedBox(
                  width: buttonWidth,
                  child: FilledButton(
                    onPressed: () => _submit(context),
                    text: AppLocalizations.of(context).generic_save,
                  ),
                ),
              ),
            ],
          ),
        );
        if (timeEntry.customField != null) {
          if (timeEntry.customField.isNotEmpty) {
            for (int i = 0; i < timeEntry.customField.length; i++) {
              while (_customFieldsFieldController.length <= i) {
                _customFieldsFieldController.add(TextEditingController());
              }
              final String iKey = timeEntry.customField.keys.elementAt(i);
              bool readOnly = false;
              if (timeEntry.customFieldName.containsKey(iKey)) {
              } else {
                timeEntry.customFieldName[iKey] = "customField$iKey";
              }
              String cF = _customFieldsFieldController[i].text;
              if (TimeEntry.bekannteFelder.containsKey(iKey)) {
                switch (TimeEntry.bekannteFelder[iKey] as BekannteFelder) {
                  case BekannteFelder.anteilTechnik:
                    readOnly = true;
                    break;
                  case BekannteFelder.anteilPause:
                    readOnly = true;
                    break;
                }
              }
              if (retP.child.runtimeType == Column) {
                Column colRetP = retP.child as Column;
                if (colRetP.children.isNotEmpty &&
                    colRetP.children.first.runtimeType == Form) {
                  Form formColRetP = colRetP.children.first as Form;
                  if (formColRetP.child.runtimeType == Column) {
                    Column colFormColRetP = formColRetP.child as Column;
                    Widget widgetI = TextFormField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: _customFieldsFieldController[i],
                      decoration: InputDecoration(
                        labelText: timeEntry.customFieldName[iKey],
                      ),
                      readOnly: readOnly,
                      onTap: () => _showTimePickerCustomField(context, i, iKey),
                    );
                    colFormColRetP.children.add(widgetI);
                  }
                }
              }
            }
          }
        }
        return retP;
      },
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(AppLocalizations.of(context).time_entry_summary_title),
      ),
      body: body,
    );
  }
}
