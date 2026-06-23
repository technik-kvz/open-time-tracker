import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide FilledButton;
import 'package:open_project_time_tracker/app/app_router.dart';
import 'package:open_project_time_tracker/app/ui/bloc/bloc_page.dart';
import 'package:open_project_time_tracker/app/ui/widgets/activity_indicator.dart';
import 'package:open_project_time_tracker/app/ui/widgets/filled_button.dart';
import 'package:open_project_time_tracker/app/ui/widgets/time_picker.dart';
import 'package:open_project_time_tracker/extensions/duration.dart';
import 'package:open_project_time_tracker/l10n/app_localizations.dart';
import 'package:open_project_time_tracker/modules/timer/ui/time_entry_summary/time_entry_summary_bloc.dart';


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

  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now();
  Map<String, String> _customFields = const {};
  Map<String, String> _customFieldNames = const {};

  DateTime get startTime {
    return _startTime;
  }
  set startTime(DateTime t) {
    final Duration d = -_endTime.difference(_startTime);
    _startTime = t;
    _endTime = t.add(d);
  }
  DateTime get endTime {
    if (_endTime.millisecondsSinceEpoch < _startTime.millisecondsSinceEpoch) {
      final DateTime tmp = _endTime;
      _endTime = _startTime;
      _startTime = tmp;
    }
    return _endTime;
  }
  set endTime(DateTime t) {
    _endTime = t;
  }
  Map<String, String> get customFields {
    return _customFields;
  }
  set customFields(Map<String, String> l) {
    _customFields = l;
  }
  Map<String, String> get customFieldNames {
    return _customFieldNames;
  }
  set customFieldNames(Map<String, String> l) {
    _customFieldNames = l;
  }

  Duration get timeSpent {
    if (_endTime.millisecondsSinceEpoch < _startTime.millisecondsSinceEpoch) {
      final DateTime tmp = _endTime;
      _endTime = _startTime;
      _startTime = tmp;
    }
    return -_endTime.difference(_startTime);
  }
  set timeSpent(Duration d) {
    _endTime = _startTime.add(d);
  }

  TimeEntrySummaryPage({super.key});

  void _showTimePicker(BuildContext context) {
    if (timeSpent.inSeconds <= 0) {
      final hours = timeSpent.inHours;
      final minutes = timeSpent.inMinutes.remainder(60);
      showCupertinoModalPopup(
        context: context,
        builder: ((_) => TimePicker(
          hours: hours,
          minutes: minutes,
          onTimeChanged: (value) {
            final duration = Duration(hours: value.hour, minutes: value.minute);
            context.read<TimeEntrySummaryBloc>().updateTimeSpent(duration);
          },
        )),
      );
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
      idle: (title, projectTitle, timeSpent, comment, commentSuggestions, iCustomFields, iCustomFieldNames) {
        this.timeSpent = timeSpent;
        if ((iCustomFields != null) && iCustomFields.isNotEmpty) {
          this.customFields = iCustomFields;
          for (int i=0; i<iCustomFields.length; i++) {
            while (_customFieldsFieldController.length <= i) {
              _customFieldsFieldController.add(TextEditingController());
            }
            final String iKey = iCustomFields.keys.elementAt(i);
            _customFieldsFieldController[i].text = iCustomFields[iKey] ?? '';
          }
        }
        if ((iCustomFieldNames != null) && iCustomFieldNames.isNotEmpty) {
          this.customFieldNames = iCustomFieldNames;
          for (int i=0; i<iCustomFieldNames.length; i++) {
            while (_customFieldsFieldController.length <= i) {
              _customFieldsFieldController.add(TextEditingController());
            }
          }
        }
        // TODO: fix comment lose after hot reload
        _commentFieldController.text = comment ?? '';
      },
    );
  }

  @override
  Widget buildState(BuildContext context, TimeEntrySummaryState state) {
    final deviceSize = MediaQuery.of(context).size;
    final buttonWidth = deviceSize.width * 0.7;

    if (customFields.isNotEmpty) {
      for (int i = 0; i < customFields.length; i++) {
        while (_customFieldsFieldController.length <= i) {
          _customFieldsFieldController.add(TextEditingController());
        }
      }
    }
    if (customFieldNames.isNotEmpty) {
      for (int i = 0; i < customFieldNames.length; i++) {
        while (_customFieldsFieldController.length <= i) {
          _customFieldsFieldController.add(TextEditingController());
        }
      }
    }

    final Widget body = state.when(
      loading: () => const Center(child: ActivityIndicator()),
      idle: (title, projectTitle, timeSpent, comment, commentSuggestions, iCustomFields, iCustomFieldNames) {
        if (iCustomFields != null) {
          if (iCustomFields.isNotEmpty) {
            this._customFields = iCustomFields;
            for (int i = 0; i < customFields.length; i++) {
              while (_customFieldsFieldController.length <= i) {
                _customFieldsFieldController.add(TextEditingController());
              }
            }
          }
        }
        if (iCustomFieldNames != null) {
          if (iCustomFieldNames.isNotEmpty) {
            this._customFieldNames = iCustomFieldNames;
            for (int i = 0; i < _customFieldNames.length; i++) {
              while (_customFieldsFieldController.length <= i) {
                _customFieldsFieldController.add(TextEditingController());
              }
            }
          }
        }
        this.timeSpent = timeSpent;
        _timeFieldController.text = timeSpent.shortWatch();
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
                      initialValue: projectTitle,
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
                      onTap: () => _showTimePicker(context),
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
        if (_customFields != null) {
          if (_customFields.isNotEmpty) {
            for (int i = 0; i < _customFields.length; i++) {
              while (_customFieldsFieldController.length <= i) {
                _customFieldsFieldController.add(TextEditingController());
              }
              final String iKey = _customFields.keys.elementAt(i);
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
                        labelText: _customFieldNames[iKey],
                      ),
                      readOnly: false,
                      onChanged: (_) =>
                          context
                              .read<TimeEntrySummaryBloc>()
                              .updateCustomField(
                              _customFieldsFieldController[i].text, iKey),
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
