import 'dart:convert';

import 'package:iso_duration_parser/iso_duration_parser.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/time_entries_repository.dart';

import 'preferences_storage.dart';

class TimerStorage {
  // Properties

  PreferencesStorage storage;

  final String _timeEntryKey = 'timeEntry';

  // Init

  TimerStorage(this.storage);

  //Private methods

  Future<void> _saveDateTime(String key, DateTime? dateTime) async {
    if (dateTime == null) {
      storage.remove(key);
      return;
    }
    final value = dateTime.toIso8601String();
    await storage.setString(key, value);
  }

  Future<DateTime?> _loadDateTime(String key) async {
    final string = await storage.getString(key);
    if (string == null) {
      return null;
    }
    return DateTime.tryParse(string);
  }

  // Public methods

  Future<TimeEntry?> getTimeEntry() async {
    TimeEntry? retVal;
    final string = await storage.getString(_timeEntryKey);
    if (string == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(string);
      // Removed excessive logging - was printing every 500ms
      retVal = _TimeEntrySerialization.parse(decoded);
    } catch (error) {
      print('Can\'t load time entry: $error');
      retVal = null;
    }
    return retVal;
  }

  Future<void> setTimeEntry(TimeEntry? timeEntry) async {
    if (timeEntry == null) {
      storage.remove(_timeEntryKey);
      return;
    }
    final string = jsonEncode(timeEntry.toJson());
    await storage.setString(_timeEntryKey, string);
    print('Time entry saved: "$string"');
  }
}

class _TimeEntrySerialization {
  static Map<String, dynamic> toMap(TimeEntry timeEntry) {
    final String customField = jsonEncode(timeEntry.customField);
    final String customFieldName = jsonEncode(timeEntry.customFieldName);
    return {
      'id': timeEntry.id,
      'workPackageSubject': timeEntry.workPackageSubject,
      'workPackageHref': timeEntry.workPackageHref,
      'projectTitle': timeEntry.projectTitle,
      'projectHref': timeEntry.projectHref,
      'startTime': timeEntry.startTime,
      'endTime': timeEntry.endTime,
      'spentOn': timeEntry.spentOn.toString(),
      'hours': timeEntry.hours.inSeconds,
      'comment': timeEntry.comment,
      'customField': customField,
      'customFieldName': customFieldName,
    };
  }

  static TimeEntry? parse(Map<String, dynamic> object) {
    try {
      final id = object['id'] as int?;
      String workPackageSubject =  "null";
      String workPackageHref =  "null";
      String projectTitle =  "null";
      String projectHref =  "null";
      if (object.containsKey("_links")) {
        final links = object["_links"];
        final workPackage = links["workPackage"];
        workPackageSubject = workPackage["title"];
        workPackageHref = workPackage["href"];

        final project = links["project"];
        projectTitle = project["title"];
        projectHref = project["href"];
      } else {
        if (object.containsKey("workPackageSubject")) {
          workPackageSubject = object['workPackageSubject'];
        }
        if (object.containsKey("workPackageHref")) {
          workPackageHref = object['workPackageHref'];
        }
        if (object.containsKey("projectTitle")) {
          projectTitle = object['projectTitle'];
        }
        if (object.containsKey("projectHref")) {
          projectHref = object['projectHref'];
        }
      }
      String startTime = "null";
      if (object.containsKey("startTime")) {
        startTime = (object['startTime'] != null) ? object['startTime'] : "null";
      }
      String endTime = "null";
      if (object.containsKey("endTime")) {
        endTime = (object['endTime'] != null) ? object['endTime'] : "null";
      }
      final DateTime spentOn = DateTime.parse(object['spentOn']);
      Duration hoursValue = Duration(seconds: 0);
      if (object.containsKey("hours")) {
        if (object['hours'].runtimeType.toString() == "int") {
          hoursValue = Duration(seconds: object['hours'] as int);
        } else {
          final String hoursString = object['hours'];
          final hoursPrase = IsoDuration.tryParse(hoursString);
          if (hoursPrase != null) {
            hoursValue = Duration(
              seconds: hoursPrase.toSeconds().round(),
            );
            if (hoursValue.inSeconds.remainder(60) == 59) {
              hoursValue += const Duration(seconds: 1);
            }
          }
        }
      }
      String? comment;
      if (object.containsKey("comment")) {
        final dynamic oComment = object['comment'];
        if (oComment.runtimeType.toString() == "String") {
          comment = object['comment'];
        } else {
          final Map<String, dynamic> oCommentMap = oComment;
          if (oCommentMap.isNotEmpty) {
            if (oComment.values.first.runtimeType.toString() == "String") {
              comment = oComment.values.first as String;
            } else {
              comment = oComment.values.first.toString();
            }
          }
        }
      }
      Map<String, String> customField = {};
      if (object.containsKey("customField")) {
        final Map<String, dynamic> jCustomField = jsonDecode(object['customField']);
        if (jCustomField.isNotEmpty) {
          for (int i = 0; i < jCustomField.length; i++) {
            final iKey = jCustomField.keys.elementAt(i);
            final dynamic iValue = jCustomField[iKey];
            if (iValue != null) {
              if (iValue.runtimeType == String) {
                customField[iKey] = iValue as String;
              } else {
                customField[iKey] = iValue.toString();
              }
            }
          }
        }
      } else {
        for (int i=0; i<object.keys.length; i++) {
          final String iKey = object.keys.elementAt(i);
          if (iKey.startsWith('customField')) {
            final String idStr = iKey.substring(0 + 'customField'.length);
            customField[idStr] = object[iKey];
          }
        }
        if (customField.isEmpty) {
          customField = TimeEntry.defaultCustomFields;
        }
      }
      Map<String, String> customFieldName = {};
      if (object.containsKey("customFieldName")) {
        final Map<String, dynamic> jCustomFieldName = jsonDecode(object['customFieldName']);
        if (jCustomFieldName.isNotEmpty) {
          for (int i = 0; i < jCustomFieldName.length; i++) {
            final iKey = jCustomFieldName.keys.elementAt(i);
            final dynamic iValue = jCustomFieldName[iKey];
            if (iValue != null) {
              if (iValue.runtimeType == String) {
                customFieldName[iKey] = iValue as String;
              } else {
                customFieldName[iKey] = iValue.toString();
              }
            }
          }
        }
      } else {
        for (int i=0; i<object.keys.length; i++) {
          final String iKey = object.keys.elementAt(i);
          if (iKey.startsWith('customFieldName')) {
            final String idStr = iKey.substring(0 + 'customFieldName'.length);
            customFieldName[idStr] = object[iKey];
          }
        }
        if (customFieldName.isEmpty) {
          customFieldName = TimeEntry.defaultCustomFieldNames;
        }
      }
      return TimeEntry(
        id: id,
        workPackageSubject: workPackageSubject,
        workPackageHref: workPackageHref,
        projectTitle: projectTitle,
        projectHref: projectHref,
        startTime: startTime,
        endTime: endTime,
        spentOn: spentOn,
        hoursValue: hoursValue,
        comment: comment,
        customField: customField,
        customFieldName: customFieldName
      );
    } catch (error) {
      print('Can\'t parse time entry: $error');
      return null;
    }
  }
}
