import 'package:open_project_time_tracker/extensions/duration.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/work_packages_repository.dart';
import 'package:iso_duration_parser/iso_duration_parser.dart';

abstract class TimeEntriesRepository {
  Future<List<TimeEntry>> list({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int? workPackageId,
    int? pageSize,
    bool fetchAll = false,
  });

  Future<TimeEntry> create({required TimeEntry timeEntry, required int userId});

  Future<TimeEntry> update({required TimeEntry timeEntry});

  Future<void> delete({required int id});
}

class TimeEntry {
  static const Map<String, String> defaultCustomFields = {"1": "100", "6": "0.0"};
  static const Map<String, String> defaultCustomFieldNames = {"1": "Anteil Technik in %", "6": "inkl. Pause"};

  late int? id;
  late String workPackageSubject;
  late String workPackageHref;
  late String projectTitle;
  late String projectHref;
  late String startTime;
  late String endTime;
  late DateTime spentOn;
  late Duration hoursValue;
  late String? comment;
  Map<String, String> customField = defaultCustomFields;
  Map<String, String> customFieldName = defaultCustomFieldNames;
  String? updatedAt;
  String? createdAt;

  TimeEntry({
    required this.id,
    required this.workPackageSubject,
    required this.workPackageHref,
    required this.projectTitle,
    required this.projectHref,
    required this.startTime,
    required this.endTime,
    required this.spentOn,
    required this.hoursValue,
    this.comment,
    this.customField = defaultCustomFields,
    this.customFieldName = defaultCustomFieldNames,
    this.updatedAt,
    this.createdAt
  });

  TimeEntry.fromJson(Map<String, dynamic> json) {
    try {
      id = json['id'];

      final Map<String, dynamic> links = json["_links"];
      final workPackage = links["workPackage"];
      workPackageSubject = workPackage["title"];
      workPackageHref = workPackage["href"];

      final project = links["project"];
      projectTitle = project["title"];
      projectHref = project["href"];

      spentOn = DateTime.parse(json['spentOn']);

      String hoursString = json['hours'];
      hoursValue = Duration(
        seconds: IsoDuration.parse(hoursString).toSeconds().round(),
      );
      if (hoursValue.inSeconds.remainder(60) == 59) {
        hoursValue += const Duration(seconds: 1);
      }

      final commentJson = json["comment"];
      comment = commentJson["raw"];

      customField = {};
      for (int i=0; i<json.keys.length; i++) {
        final String iKey = json.keys.elementAt(i);
        if (iKey.startsWith('customField')) {
          final String idStr = iKey.substring(0 + 'customField'.length);
          customField[idStr] = json[iKey];
        }
      }
      if (customField.isEmpty) {
        customField = defaultCustomFields;
      }

      customFieldName = {};
      for (int i=0; i<json.keys.length; i++) {
        final String iKey = json.keys.elementAt(i);
        if (iKey.startsWith('customFieldName')) {
          final String idStr = iKey.substring(0 + 'customFieldName'.length);
          customFieldName[idStr] = json[iKey];
        }
      }
      if (customFieldName.isEmpty) {
        customFieldName = defaultCustomFieldNames;
      }

      startTime = (json['startTime'] != null) && (json['startTime'] != "") ? json['startTime'] : "null";
      endTime = (json['endTime'] != null) && (json['endTime'] != "") ? json['endTime'] : "null";

      updatedAt = json['updatedAt'];
      createdAt = json['createdAt'];
      if (startTime == "null") {
        if (updatedAt != null) {
          DateTime? uA = DateTime.tryParse(updatedAt!);
          if (uA != null) {
            startTime = uA.toIso8601String();
          }
        }
        else if (createdAt != null) {
          DateTime? cA = DateTime.tryParse(createdAt!);
          if (cA != null) {
            startTime = cA.toIso8601String();
          }
        }
      }
    }
    on Exception catch (e) {
      print(e.toString());
    }
    finally {
    }
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    try {
      json['id'] = id;

      Map<String, dynamic> links = {};

      Map<String, String> workPackage = {};
      workPackage["title"] = workPackageSubject;
      workPackage["href"] = workPackageHref;
      links["workPackage"] = workPackage;

      Map<String, String> project = {};
      project["title"] = projectTitle;
      project["href"] = projectHref;
      links["project"] = project;

      json["_links"] = links;

      json['spentOn'] = spentOn.toIso8601String();

      json['hours'] = hours.toISO8601();

      Map<String, String> commentJson = {};
      if (comment != null) {
        commentJson["raw"] = comment!;
      }
      json["comment"] = commentJson;

      Map<String, String> customFields = {};
      for (int i=0; i<customField.keys.length; i++) {
        final String iKey = customField.keys.elementAt(i);
        final String jKey = 'customField$iKey';
        if (iKey.startsWith('customField')) {
          if (customField[iKey] != null) {
            customFields[jKey] = customField[iKey]!;
          }
        }
      }
      Map<String, String> customFieldNames = {};
      for (int i=0; i<customFieldName.keys.length; i++) {
        final String iKey = customFieldName.keys.elementAt(i);
        final String jKey = 'customFieldName$iKey';
        if (iKey.startsWith('customFieldName')) {
          if (customFieldName[iKey] != null) {
            customFieldNames[jKey] = customFieldName[iKey]!;
          }
        }
      }

      if (startTime != "null") {
        json['startTime'] = startTime;
      }
      if (endTime != "null") {
        json['endTime'] = endTime;
      }

      json['updatedAt'] = updatedAt;
      json['createdAt'] = createdAt;
    }
    finally {
    }
    return json;
  }

  TimeEntry.fromWorkPackage(WorkPackage workPackage, {DateTime? selectedDate})
    : id = null,
      workPackageSubject = workPackage.subject,
      workPackageHref = workPackage.href,
      projectTitle = workPackage.projectTitle,
      projectHref = workPackage.projectHref,
      startTime = "null",
      endTime = "null",
      spentOn = selectedDate ?? DateTime.now(),
      hoursValue = const Duration(),
      comment = null,
      updatedAt = DateTime.now().toIso8601String(),
      createdAt = DateTime.now().toIso8601String(),
      customField = defaultCustomFields,
      customFieldName = defaultCustomFieldNames;

  Duration get hours {
    Duration ret = hoursValue;
    if ((startTime != "null") && (endTime != "null")) {
      ret = DateTime.parse(endTime).difference(DateTime.parse(startTime));
    }
    return ret;
  }
}
