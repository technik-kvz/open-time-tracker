import 'package:dio/dio.dart' hide Headers;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:retrofit/retrofit.dart';
import 'package:iso_duration_parser/iso_duration_parser.dart';

part 'time_entries_api.g.dart';

@RestApi()
abstract class TimeEntriesApi {
  factory TimeEntriesApi(Dio dio) = _TimeEntriesApi;

  @GET('/time_entries')
  Future<TimeEntriesResponse> timeEntries({
    @Query('filters') String? filters,
    @Query('pageSize') int? pageSize,
    @Query('offset') int? offset,
  });

  @GET('/time_entries/schema')
  Future<TimeEntriesSchemaResponse> timeEntriesSchema();

  @POST('/time_entries')
  @Headers(<String, dynamic>{"Content-Type": "application/json"})
  Future<HttpResponse<dynamic>> createTimeEntry({
    @Body() required Map<String, dynamic> body,
  });

  @PATCH('/time_entries/{id}')
  @Headers(<String, dynamic>{"Content-Type": "application/json"})
  Future<void> updateTimeEntry({
    @Path() required int? id,
    @Body() required Map<String, dynamic> body,
  });

  @DELETE('/time_entries/{id}')
  Future<void> deleteTimeEntry({@Path() required int? id});
}

class TimeEntryResponse {
  late int? id;
  late String workPackageSubject;
  late String workPackageHref;
  late String projectTitle;
  late String projectHref;
  late String startTime;
  late String endTime;
  late DateTime updatedAt;
  late DateTime spentOn;
  late Duration hours;
  late String? comment;
  late DateTime createdAt;
  Map<String, String> customField = {};

  TimeEntryResponse.fromJson(Map<String, dynamic> json) {
    try {
      id = json['id'];

      final commentJson = json["comment"];
      comment = commentJson["raw"];

      final links = json["_links"];
      final project = links["project"];
      projectTitle = project["title"];
      projectHref = project["href"];
      final workPackage = links["workPackage"];
      workPackageSubject = workPackage["title"];
      workPackageHref = workPackage["href"];

      startTime = "null";
      if ((json["startTime"] != null) && (json["startTime"].runtimeType == String)) {
        startTime = json["startTime"];
      }

      final hoursString = json["hours"];
      hours = Duration(
        seconds: IsoDuration.parse(hoursString).toSeconds().round(),
      );
      if (hours.inSeconds.remainder(60) == 59) {
        hours += const Duration(seconds: 1);
      }

      endTime = "null";
      if ((json["endTime"] != null) && (json["endTime"].runtimeType == String)) {
        endTime = json["endTime"];
      } else if (hours != Duration(seconds: 0)) {
        DateTime? sT = DateTime.tryParse(startTime);
        if (sT != null) {
          endTime = sT.add(hours).toIso8601String();
        }
      }

      spentOn = DateTime.parse(json['spentOn']);

      for (int i=0; i<json.keys.length; i++) {
        final String iKey = json.keys.elementAt(i);
        if (iKey.startsWith('customField')) {
          final String idStr = iKey.substring(0 + 'customField'.length);
          final dynamic iValue = json[iKey];
          final String sValue = iValue.runtimeType == String ? iValue : iValue.toString();
          customField[idStr] = sValue;
        }
      }

      updatedAt = DateTime.tryParse(json['updatedAt']) ?? DateTime.now();
      createdAt = DateTime.tryParse(json['createdAt']) ?? DateTime.now();
    }
    on Exception catch (e) {
      //print("-------------------2.2------------------- \n");
      print(e.toString());
    }
    finally {
    }
  }
}

class TimeEntriesResponse {
  late List<TimeEntryResponse> timeEntries;
  late int total;
  late int count;

  TimeEntriesResponse.fromJson(Map<String, dynamic> json) {
    try {
      //print("-------------------3------------------- \n");
      total = json['total'] ?? 0;
      count = json['count'] ?? 0;

      List<TimeEntryResponse> items = [];
      final embedded = json['_embedded'];
      final elements = embedded['elements'] as List<dynamic>;
      for (var element in elements) {
        items.add(TimeEntryResponse.fromJson(element));
      }
      timeEntries = items;
    }
    on Exception catch (e) {
      print(e.toString());
    }
    finally {
    }
  }
}

class TimeEntriesSchemaResponse {
  late Map<String, dynamic> response;

  TimeEntriesSchemaResponse.fromJson(Map<String, dynamic> json) {
    try {
      response = json;
    }
    on Exception catch (e) {
      print(e.toString());
    }
    finally {
    }
  }
}
