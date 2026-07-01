import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_project_time_tracker/l10n/app_localizations.dart';

import '../../../domain/time_entries_repository.dart';
import '/extensions/duration.dart';
import '../../../../../app/ui/widgets/configured_card.dart';

class TimeEntryListItem extends StatelessWidget {
  // Properties

  final String workPackageSubject;
  final String projectTitle;
  final Duration hours;
  final String startTime;
  final String endTime;
  final String? comment;
  final Map<String, String> customField;
  final Function()? action;
  final Future<bool> Function()? dismissAction;
  final bool colorRed;

  // Init
  const TimeEntryListItem({
    super.key,
    required this.workPackageSubject,
    required this.projectTitle,
    required this.startTime,
    required this.endTime,
    required this.hours,
    required this.comment,
    this.action,
    this.dismissAction,
    required this.customField,
    required this.colorRed,
  });

  Future<bool> _showCloseDialog(BuildContext context) async {
    var consent = false;
    await showDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context).generic_warning),
        content: Text(AppLocalizations.of(context).generic_deletion_warning),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).generic_no),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              consent = true;
              Navigator.of(context).pop();
            },
            child: Text(AppLocalizations.of(context).generic_yes),
          ),
        ],
      ),
    );
    return consent && dismissAction != null ? await dismissAction!() : false;
  }

  // Lifecycle

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    if (dismissAction == null) {
      return body;
    } else {
      return Dismissible(
        key: UniqueKey(),
        confirmDismiss: (direction) => _showCloseDialog(context),
        direction: DismissDirection.endToStart,
        background: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Icon(Icons.delete),
          ),
        ),
        child: body,
      );
    }
  }

  Widget _body(BuildContext context) {
    final trailing = hours.withLetters();
    GestureDetector gd = GestureDetector(
      onTap: action,
      child: ConfiguredCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${DateFormat("yyyy-MM-dd HH:mm").format(DateTime.parse(startTime).toLocal())} - ${DateFormat("HH:mm").format(DateTime.parse(endTime).toLocal())}${colorRed ? "\nFEHLER\nBeginnt < Ende(Vorgänger)!\nBitte korrigeren!" : ""}",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: colorRed ? const Color.fromARGB(255, 255, 0, 0) : const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ),
                  ),
                  Text(trailing),
                ],
              ),
              const SizedBox(height: 4),
              Text(projectTitle),
              Text(workPackageSubject),
              SizedBox(height: comment != null && comment!.isNotEmpty ? 6 : 0),
              if (comment != null && comment!.isNotEmpty) Text(comment!),
            ],
          ),
        ),
      ),
    );
    if (customField.isNotEmpty) {
      for (int i = 0; i < customField.length;i++) {
        final iKey = customField.keys.elementAt(i);
        if (customField[iKey] != null) {
          final String cF = customField[iKey]!;
          if (gd.child.runtimeType == ConfiguredCard) {
            ConfiguredCard cGD = gd.child as ConfiguredCard;
            if (cGD.child.runtimeType == Padding) {
              Padding pcGD = cGD.child as Padding;
              if (pcGD.child.runtimeType == Column) {
                Column cocGD = pcGD.child as Column;
                cocGD.children.add(SizedBox(height: cF.isNotEmpty ? 6 : 0));
                if (cF.isNotEmpty) {
                  if (TimeEntry.bekannteFelder.containsKey(iKey)) {
                    switch (TimeEntry.bekannteFelder[iKey] as BekannteFelder) {
                      case BekannteFelder.anteilTechnik:
                        final double mF = hours.inMinutes / 60.0;
                        final double f = double.tryParse(cF) ?? mF;
                        final int h = f.floor();
                        final double dm = (f - h.toDouble()) * 60.0;
                        final int m = dm.round();
                        final Duration d = Duration(hours:h, minutes: m);
                        cocGD.children.add(Text(d.shortWatch()));
                        break;

                      case BekannteFelder.anteilPause:
                        final double mF = hours.inMinutes / 60.0;
                        final double f = double.tryParse(cF) ?? 0.0;
                        final int h = f.floor();
                        final double dm = (f - h.toDouble()) * 60.0;
                        final int m = dm.round();
                        final Duration d = Duration(hours:h, minutes: m);
                        cocGD.children.add(Text(d.shortWatch()));
                        break;
                    }
                  } else {
                    cocGD.children.add(Text(cF));
                  }
                }
              }
            }
          }
        }
      }
    }
    return gd;
  }
}
