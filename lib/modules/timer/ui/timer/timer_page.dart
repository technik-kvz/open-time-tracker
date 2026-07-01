import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide FilledButton;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_project_time_tracker/app/app_router.dart';
import 'package:open_project_time_tracker/app/live_activity/infrastructure/notification_permission_helper.dart';
import 'package:open_project_time_tracker/app/ui/bloc/bloc_page.dart';
import 'package:open_project_time_tracker/app/ui/widgets/filled_button.dart';
import 'package:open_project_time_tracker/l10n/app_localizations.dart';
import 'package:open_project_time_tracker/modules/timer/ui/timer/timer_bloc.dart';

import '../../../../app/ui/widgets/configured_outlined_button.dart';

// ignore: must_be_immutable
class TimerPage extends EffectBlocPage<TimerBloc, TimerState, TimerEffect> {
  const TimerPage({super.key});

  void _showCloseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: ((_) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context).generic_warning),
        content: Text(AppLocalizations.of(context).timer_warning),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).generic_no),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await context.read<TimerBloc>().reset();
              // ignore: use_build_context_synchronously
              Navigator.of(context).pop();
            },
            child: Text(AppLocalizations.of(context).generic_yes),
          ),
        ],
      )),
    );
  }

  @override
  void onEffect(BuildContext context, TimerEffect effect) {
    effect.when(finish: () => AppRouter.routeToTimeEntrySummary(context));
  }

  @override
  void onCreate(BuildContext context, TimerBloc bloc) {
    super.onCreate(context, bloc);
    bloc.updateState();

    // Proactively request notification permission on first launch after update
    // This provides better UX by explaining why the permission is needed
    _startNotificationPermissionFlow(context);
  }

  void _startNotificationPermissionFlow(BuildContext context) {
    unawaited(() async {
      try {
        await _requestNotificationPermissionIfNeeded(context);
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'timer_page',
            context: ErrorDescription(
              'while requesting notification permission from TimerPage.onCreate',
            ),
          ),
        );
      }
    }());
  }

  Future<void> _requestNotificationPermissionIfNeeded(
    BuildContext context,
  ) async {
    // Only show permission dialog if this is the first time
    if (await NotificationPermissionHelper.shouldRequestPermission()) {
      // Wait a bit to let the page render first
      await Future.delayed(const Duration(milliseconds: 500));

      if (context.mounted) {
        await NotificationPermissionHelper.requestPermissionWithDialog(context);
      }
    }
  }

  @override
  Widget buildState(BuildContext context, TimerState state) {
    try {
      final deviceSize = MediaQuery
          .of(context)
          .size;
      final buttonWidth = deviceSize.width * 0.39;
      final addButtonWidth = deviceSize.width * 0.23;

      return Scaffold(
        floatingActionButton: IconButton(
          onPressed: () => _showCloseDialog(context),
          icon: const Icon(Icons.close),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 5),
              SizedBox(
                width: addButtonWidth,
                child: ConfiguredOutlinedButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      firstDate: state.startTime.toLocal().add(-const Duration(
                          days: 7)),
                      lastDate: DateTime.now().toLocal(),
                      initialDate: state.startTime.toLocal(),
                    );
                    if (picked != null) {
                      final TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(state.startTime
                            .toLocal()),
                      );
                      if (pickedTime != null) {
                        final DateTime selectedDateTime = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                        context.read<TimerBloc>().update(
                            selectedDateTime.toUtc(), state.endTime);
                      }
                    }
                  },
                  text: '    Startzeit: ${DateFormat("yyyy-MM-dd HH:mm").format(
                      state.startTime.toLocal())}    ',
                  textStyle: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
                ),
              ),
              const Spacer(flex: 1),
              SizedBox(
                width: addButtonWidth,
                child: ConfiguredOutlinedButton(
                  onPressed: () async {
                    /*final DateTime? picked = await showDatePicker(
                      context: context,
                      firstDate: state.startTime,
                      lastDate: state.startTime,
                      initialDate: state.startTime,
                    );*/
                    final DateTime picked = state.startTime.toLocal();
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                          state.endTime.toLocal()),
                    );
                    if (pickedTime != null) {
                      final DateTime selectedDateTime = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                      context.read<TimerBloc>().update(
                          state.startTime, selectedDateTime.toUtc());
                    }
                  },
                  text: '    Endzeit: ${DateFormat("HH:mm").format(
                      state.endTime.toLocal())}    ',
                  textStyle: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
                ),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  state.title,
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              Text(
                state.subtitle,
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium,
              ),
              const Spacer(flex: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: addButtonWidth,
                    child: ConfiguredOutlinedButton(
                      text: AppLocalizations
                          .of(context)
                          .timer_add_5_min,
                      textStyle: const TextStyle(fontSize: 14),
                      onPressed: () =>
                          context.read<TimerBloc>().add(
                            const Duration(minutes: 5),
                          ),
                    ),
                  ),
                  SizedBox(
                    width: addButtonWidth,
                    child: ConfiguredOutlinedButton(
                      text: AppLocalizations
                          .of(context)
                          .timer_add_15_min,
                      textStyle: const TextStyle(fontSize: 14),
                      onPressed: () =>
                          context.read<TimerBloc>().add(
                            const Duration(minutes: 15),
                          ),
                    ),
                  ),
                  SizedBox(
                    width: addButtonWidth,
                    child: ConfiguredOutlinedButton(
                      text: AppLocalizations
                          .of(context)
                          .timer_add_30_min,
                      textStyle: const TextStyle(fontSize: 14),
                      onPressed: () =>
                          context.read<TimerBloc>().add(
                            const Duration(minutes: 30),
                          ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  /*SizedBox(
                    width: buttonWidth,
                    child: FilledButton(
                      onPressed: (state.isActive
                          ? context.read<TimerBloc>().stop
                          : context.read<TimerBloc>().start),
                      text: leftButtonTitle,
                    ),
                  ),*/
                  SizedBox(
                    width: buttonWidth,
                    child: FilledButton(
                      onPressed: (true
                          ? context
                          .read<TimerBloc>()
                          .finish
                          : null),
                      text: AppLocalizations
                          .of(context)
                          .timer_finish,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 14),
            ],
          ),
        ),
      );
    } catch (e) {
      e.toString();
      rethrow;
    }
    finally {
    }
  }
}
