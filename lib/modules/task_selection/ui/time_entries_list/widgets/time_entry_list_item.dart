import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_project_time_tracker/l10n/app_localizations.dart';

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
                      workPackageSubject,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(trailing, style: const TextStyle(color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 4),
              Text(projectTitle, style: const TextStyle(color: Colors.grey)),
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
                  cocGD.children.add(Text(cF));
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
