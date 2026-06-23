import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:open_project_time_tracker/extensions/duration.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/time_entries_repository.dart';
import 'package:open_project_time_tracker/modules/task_selection/infrastructure/time_entries_api.dart';

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../database_helper.dart';

/// Maximum number of pages to fetch when fetchAll is true (safety limit to prevent infinite loops)
const int _kMaxPaginationPages = 100;

class ApiTimeEntriesRepository implements TimeEntriesRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TimeEntriesApi _restApi;

  ApiTimeEntriesRepository(this._restApi);

  @override
  Future<List<TimeEntry>> list({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int? workPackageId,
    int? pageSize,
    bool fetchAll = false,
  }) async {
    final Database db = await _databaseHelper.database;
    bool fromDatabase = false;
    bool isOnline = false;
    List<TimeEntry> items = [];
    List<String> filters = [];
    if (userId != null) {
      filters.add('{"user":{"operator":"=","values":["$userId"]}}');
    }
    if (startDate != null && endDate != null) {
      filters.add(
          '{"spent_on":{"operator":"<>d","values":["$startDate", "$endDate"]}}');
    } else {
      final String date = DateFormat("yyyy-MM-dd").format(
          DateTime.now().toLocal());
      filters.add(
          '{"spent_on":{"operator":"<>d","values":["$date", "$date"]}}');
    }
    // keep work package filter last to replace it further for compatibility with old API versions
    if (workPackageId != null) {
      filters.add('{"entity":{"operator":"=","values":["$workPackageId"]}}');
    }
    final filtersString = '[${filters.join(', ')}]';
    final String jFiltersString = jsonEncode(filtersString);
    final String reqString = '{ "req": "timeEntries", "filters" : "$jFiltersString" }';

    // Fetch all pages if fetchAll is true, otherwise just fetch first page
    final List<TimeEntryResponse> allEntries = [];
    int offset = 1;
    int? total;
    int maxPages = _kMaxPaginationPages;

    Map<String, String> customFieldNames = {};
    try {
      try {
        final TimeEntriesSchemaResponse schema = await _restApi
            .timeEntriesSchema().timeout(const Duration(seconds: 3));
        final Map<String, dynamic> object = schema.response;
        //print(jsonEncode(schema.response));
        for (int i = 0; i < object.keys.length; i++) {
          final String iKey = object.keys.elementAt(i);
          if (iKey.startsWith('customField')) {
            final String idStr = iKey.substring(0 + 'customField'.length);
            final Map<String, dynamic> jObject = object[iKey];
            if (jObject.isNotEmpty && jObject.containsKey("name") &&
                (jObject["name"] != null)) {
              dynamic jObjectName = jObject["name"];
              if (jObjectName.runtimeType.toString() == "String") {
                customFieldNames[iKey] = jObjectName;
              } else {
                customFieldNames[iKey] = jObjectName.toString();
              }
            }
          }
        }
      }
      on Exception catch (e) {
        print(e.toString());
      }
      finally {}
      if (customFieldNames.isEmpty) {
        customFieldNames = TimeEntry.defaultCustomFieldNames;
      }
      do {
        TimeEntriesResponse? result;
        try {
          result = await _restApi.timeEntries(
            filters: filtersString,
            pageSize: pageSize,
            offset: offset,
          ).timeout(const Duration(seconds: 3));
        } on DioException catch (e) {
          final String error = e.toString();
          print('TimeEntriesResponse Expeption1: "$error"');
          // retry with deprecated old filter for older instances
          if ((e.response?.statusCode == 400) && (workPackageId != null)) {
            filters.removeLast();
            filters.add(
              '{"workPackage":{"operator":"=","values":["$workPackageId"]}}',
            );
            final updatedFiltersString = '[${filters.join(', ')}]';
            try {
              result = await _restApi.timeEntries(
                filters: updatedFiltersString,
                pageSize: pageSize,
                offset: offset,
              ).timeout(const Duration(seconds: 3));
            }
            on Exception catch (e) {
              final String error = e.toString();
              print('TimeEntriesResponse Expeption2 "$error"');
            }
            finally {}
          } else {
            fromDatabase = true;
          }
        }
        on Exception catch (e) {
          final String error = e.toString();
          print('TimeEntriesResponse Expeption2 "$error"');
          if ((e is TimeoutException) || (e is SocketException) ||
              ((e is DioException) && (e.error is SocketException))) {
            fromDatabase = true;
          }
        }
        finally {}
        if ((result != null) && !fromDatabase) {
          allEntries.addAll(result.timeEntries);
          total = result.total;

          // Break if no more entries returned
          if (result.timeEntries.isEmpty || result.count == 0) {
            break;
          }

          // Only continue fetching if fetchAll is true
          if (!fetchAll) {
            break;
          }

          offset++; // Move to next page (offset is page number, not item number)
          maxPages--;

          // Continue fetching if there are more results
        }
        else {
          break;
        }
      }
      while ((allEntries.length < total) && (maxPages > 0));

      if (allEntries.isNotEmpty && !fromDatabase) {
        allEntries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        items = allEntries.map(
          (e) => TimeEntry(
              id: e.id,
              workPackageSubject: e.workPackageSubject,
              workPackageHref: e.workPackageHref,
              projectTitle: e.projectTitle,
              projectHref: e.projectHref,
              startTime: e.startTime,
              endTime: e.endTime,
              spentOn: e.spentOn,
              hoursValue: e.hours,
              comment: e.comment,
              customField: e.customField,
              customFieldName: customFieldNames,
              updatedAt: e.updatedAt.toIso8601String(),
              createdAt: e.createdAt.toIso8601String()
          ),
        ).toList();
        for (int j = 0; j < items.length; j++) {
          if (items[j].startTime == "null") {
            if (items[j].updatedAt != null) {
              DateTime? uA = DateTime.tryParse(items[j].updatedAt!);
              if (uA != null) {
                items[j].startTime = uA.toIso8601String();
              }
            }
            else if (items[j].createdAt != null) {
              DateTime? cA = DateTime.tryParse(items[j].createdAt!);
              if (cA != null) {
                items[j].startTime = cA.toIso8601String();
              }
            }
          }
        }
        isOnline = true;
      }
    } catch (e) {
      print(e.toString());
    }
    finally {}
    if (fromDatabase) {
      try {
        final List<String> columns = [
          DatabaseHelper.columnRequest,
          DatabaseHelper.columnData
        ];
        final String columnRequest = DatabaseHelper.columnRequest;
        final String queryEquals = ' = ?';
        final String where = columnRequest + queryEquals;
        final List<String> whereArgs = [ reqString];
        final List<Map<String, Object?>> filteredResults = await db.query(
            DatabaseHelper.tableCache, columns: columns,
            where: where,
            whereArgs: whereArgs);
        if (filteredResults.isNotEmpty) {
          for (int j = 0; j < filteredResults.length; j++) {
            final Map<String, Object?> jsonResult = filteredResults[j];
            /*print("-------------------------------------------\n");
            print(jsonEncode(jsonResult));
            print("-------------------------------------------\n");*/
            for (int i = 0; i < jsonResult.length; i++) {
              final String key = jsonResult.keys.elementAt(i);
              dynamic jsonObj = jsonResult[key];
              if ((jsonObj != null) && (key == DatabaseHelper.columnData)) {
                if (jsonObj.runtimeType.toString() == "String") {
                  jsonObj = jsonDecode(jsonObj);
                }
                /*print("----------------------key---------------------\n");
                print(key);
                print("______________________value_____________________\n");
                print(jsonObj.runtimeType);
                print(jsonObj.toString());
                print("-------------------------------------------\n");*/
                if (jsonObj.runtimeType == List<dynamic>) {
                  final List<dynamic> listObj = jsonObj;
                  if (listObj.isNotEmpty) {
                    for (int k = 0; k < listObj.length; k++) {
                      if (listObj[k] != null) {
                        /* print("______________________listObj[$k]_____________________\n");
                        print(listObj[k].runtimeType);
                        print(listObj[k].toString());*/
                        if (listObj[k].runtimeType.toString() ==  "_Map<String, dynamic>") {
                          /*print("----------------------jsonMap---------------------\n");
                          print(listObj[k].toString());*/
                          final TimeEntry listElementTimeEntry = TimeEntry.fromJson(listObj[k]);
                          /*print("----------------------project---------------------\n");
                        print(listElementTimeEntry.toString());*/
                          items.add(listElementTimeEntry);
                        }
                      }
                    }
                    /*print("-------------------------------------------\n");*/
                    print("returnVal filled");
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print(e.toString());
      }
      finally {
      }
    }
    if (isOnline && items.isNotEmpty) {
      try {
        final String datString = jsonEncode(items);
        final Map<String, dynamic> row = {
          DatabaseHelper.columnRequest : reqString,
          DatabaseHelper.columnData  : datString
        };
        final int id = await db.insert(DatabaseHelper.tableCache, row, conflictAlgorithm: ConflictAlgorithm.replace);
        // show the results: print all rows in the db
        print(await db.query(DatabaseHelper.tableCache));
      }
      on Exception catch (e) {
        print(e.toString());
      }
      finally {}
    }
    try {
      final List<dynamic> pcValue = await processCache(isOnline: isOnline);
      if (pcValue.isNotEmpty) {
        for (int i = 0; i < pcValue.length; i++) {
          final dynamic pcD = pcValue[i];

          /// CASE: delete
          if (pcD.runtimeType.toString() == "int") {
            final int dID = pcD as int;
            for (int j = items.length - 1; j >= 0; j--) {
              if (items[j].id == dID) {
                items.removeAt(j);
              }
            }
          }

          /// CASE: create or update
          else if (pcD.runtimeType.toString() == "TimeEntry") {
            final TimeEntry cEntry = pcD;
            bool isNew = true;
            for (int j = items.length - 1; j >= 0; j--) {
              /// CASE: update
              if (items[j].id == cEntry.id) {
                items[j] = cEntry;
                isNew = false;
              }
            }

            /// CASE: create
            if (isNew) {
              items.add(cEntry);
            }
          }
        }
      }
    }
    on Exception catch (e) {
      e.toString();
    }
    finally {
    }
    return items;
  }

  @override
  Future<TimeEntry> create({
    required TimeEntry timeEntry,
    required int userId,
    bool storeInCache = true
  }) async {
    bool storeInDb = false;
    final Database db = await _databaseHelper.database;
    final String dateString = DateTime.now().toIso8601String();
    final String reqString = '{ "req": "updateLater", "item" : "TimeEntry", "action": "create" }';
    Map<String, dynamic> body = {
      'user': {'id': userId},
      'workPackage': {'href': timeEntry.workPackageHref},
      'project': {'href': timeEntry.projectHref},
      'spentOn': DateFormat('yyyy-MM-dd').format(timeEntry.spentOn),
      'hours': timeEntry.hours.toISO8601(),
      'comment': {'format': 'plain', 'raw': timeEntry.comment},
    };
    if (timeEntry.startTime != "null") {
      body['startTime'] = DateTime.parse(timeEntry.startTime).toUtc().toIso8601String();
    }
    /*if (timeEntry.endTime != "null") {
      body['endTime'] = timeEntry.endTime;
    }*/
    if (timeEntry.customField.isNotEmpty) {
      for (int i=0; i<timeEntry.customField.length; i++) {
        final String iKey = timeEntry.customField.keys.elementAt(i);
        if (timeEntry.customField[iKey] != null) {
          final String iValue = timeEntry.customField[iKey]!;
          body['customField$iKey'] = iValue;
        }
      }
    }
    if (timeEntry.customFieldName.isNotEmpty) {
      for (int i=0; i<timeEntry.customFieldName.length; i++) {
        final String iKey = timeEntry.customFieldName.keys.elementAt(i);
        if (timeEntry.customFieldName[iKey] != null) {
          final String iValue = timeEntry.customFieldName[iKey]!;
          body['customFieldName$iKey'] = iValue;
        }
      }
    }
    try {
      final response = await _restApi.createTimeEntry(body: body).timeout(Duration(seconds: 3));
      // Parse the response to get the ID and update the timeEntry
      final data = response.data;
      timeEntry.id = data['id'];
    } on Exception catch(e) {
      print(e.toString());
      if ((e is TimeoutException) || (e is SocketException) || ((e is DioException) && (e.error is SocketException))) {
        storeInDb = storeInCache;
      }
    }
    catch (e) {
      print(e.toString());
    }
    finally {
      timeEntry.createdAt = DateTime.now().toIso8601String();
      timeEntry.updatedAt = DateTime.now().toIso8601String();
    }
    try {
      if (storeInDb) {
        final Map<String, dynamic> data = { "timeEntry": timeEntry.toJson(), "userId": userId};
        final String datString = jsonEncode(data);
        final Map<String, dynamic> row = {
          DatabaseHelper.columnDate: dateString,
          DatabaseHelper.columnRequest: reqString,
          DatabaseHelper.columnData: datString
        };
        int id = await db.insert(DatabaseHelper.tableChanges, row, conflictAlgorithm: ConflictAlgorithm.replace);
        // show the results: print all rows in the db
        print(await db.query(DatabaseHelper.tableChanges));
      }
    }
    catch (e) {
      print(e.toString());
    }
    finally {}
    return timeEntry;
  }

  @override
  Future<TimeEntry> update({required TimeEntry timeEntry, bool storeInCache = true}) async {
    final Database db = await _databaseHelper.database;
    final String dateString = DateTime.now().toIso8601String();
    final String reqString = '{ "req": "updateLater", "item" : "TimeEntry", "action": "update" }';
    if (timeEntry.id == null) {
      throw Exception('Updating time entry without id');
    }
    Map<String, dynamic> body = {
      'id': timeEntry.id.toString(),
      'hours': timeEntry.hours.toISO8601(),
      'comment': {'format': 'plain', 'raw': timeEntry.comment},
      'spentOn': DateFormat('yyyy-MM-dd').format(timeEntry.spentOn),
    };
    if (timeEntry.startTime != "null") {
      body['startTime'] = DateTime.parse(timeEntry.startTime).toUtc().toIso8601String();
    }
    /*if (timeEntry.endTime != "null") {
      body['endTime'] = timeEntry.endTime;
    }*/
    if (timeEntry.customField.isNotEmpty) {
      for (int i=0; i<timeEntry.customField.length; i++) {
        final String iKey = timeEntry.customField.keys.elementAt(i);
        if (timeEntry.customField[iKey] != null) {
          final String iValue = timeEntry.customField[iKey]!;
          body['customField$iKey'] = iValue;
        }
      }
    }
    if (timeEntry.customFieldName.isNotEmpty) {
      for (int i=0; i<timeEntry.customFieldName.length; i++) {
        final String iKey = timeEntry.customFieldName.keys.elementAt(i);
        if (timeEntry.customFieldName[iKey] != null) {
          final String iValue = timeEntry.customFieldName[iKey]!;
          body['customFieldName$iKey'] = iValue;
        }
      }
    }
    try {
      await _restApi.updateTimeEntry(id: timeEntry.id, body: body).timeout(Duration(seconds: 3));
      timeEntry.updatedAt = DateTime.now().toIso8601String();
    } on Exception catch(e) {
      print(e.toString());
      if ((e is TimeoutException) || (e is SocketException) || ((e is DioException) && (e.error is SocketException))) {
        if (storeInCache) {
          final Map<String, dynamic> jsonObj = {"timeEntry": timeEntry.toJson()};
          final String datString = jsonEncode(jsonObj);
          final Map<String, dynamic> row = {
            DatabaseHelper.columnRequest: reqString,
            DatabaseHelper.columnDate: dateString,
            DatabaseHelper.columnData: datString
          };
          int id = await db.insert(DatabaseHelper.tableChanges, row, conflictAlgorithm: ConflictAlgorithm.replace);
          // show the results: print all rows in the db
          print(await db.query(DatabaseHelper.tableChanges));
        }
      }
    }
    catch (e) {
      print(e.toString());
    }
    finally {
    }
    return timeEntry;
  }

  @override
  Future<void> delete({required int id, bool storeInCache = true}) async {
    final Database db = await _databaseHelper.database;
    final String dateString = DateTime.now().toIso8601String();
    final String reqString = '{ "req": "updateLater", "item" : "TimeEntry", "action": "delete"}';
    try {
      await _restApi.deleteTimeEntry(id: id).timeout(Duration(seconds: 3));
    } on Exception catch(e) {
      if ((e is TimeoutException) || (e is SocketException) || ((e is DioException) && (e.error is SocketException))) {
        print(e.toString());
        if (storeInCache) {
          final Map<String, dynamic> jsonObj = {"id": id};
          final String datString = jsonEncode(jsonObj);
          final Map<String, dynamic> row = {
            DatabaseHelper.columnDate: dateString,
            DatabaseHelper.columnRequest: reqString,
            DatabaseHelper.columnData: datString
          };
          int dbID = await db.insert(DatabaseHelper.tableChanges, row, conflictAlgorithm: ConflictAlgorithm.replace);
          // show the results: print all rows in the db
          print(await db.query(DatabaseHelper.tableChanges));
        }
      }
    }
    catch (e) {
      print(e.toString());
    }
    finally {
    }
  }

  Future< List<dynamic> > processCache({required bool isOnline}) async {
    List<dynamic> retVal = [];
    final Database db = await _databaseHelper.database;
    const Map<String, DBAction> reqStrings = {
      '{ "req": "updateLater", "item" : "TimeEntry", "action": "create" }' : DBAction.create,
      '{ "req": "updateLater", "item" : "TimeEntry", "action": "update" }' : DBAction.update,
      '{ "req": "updateLater", "item" : "TimeEntry", "action": "delete" }' : DBAction.delete
    };
    bool noError = true;
    bool foundData = false;
    for (int i=0; i<reqStrings.length;i++) {
      final String reqString = reqStrings.keys.elementAt(i);
      final DBAction reqAction = reqStrings[reqString]!;
      final List<String> columns = [ DatabaseHelper.columnRequest, DatabaseHelper.columnData ];
      final String columnRequest = DatabaseHelper.columnRequest;
      final String queryEquals = ' = ?';
      final String where = columnRequest + queryEquals;
      final List<String> whereArgs = [ reqString ];
      final List<Map<String, Object?>> filteredResults = await db.query(DatabaseHelper.tableChanges, columns: columns, where: where, whereArgs: whereArgs);
      if (filteredResults.isNotEmpty) {
        foundData = true;
        try {
          for (int j = 0; j < filteredResults.length; j++) {
            final Map<String, Object?> jsonResult = filteredResults[j];
            /*print("-------------------------------------------\n");
            print(jsonEncode(jsonResult));
            print("-------------------------------------------\n");*/
            for (int i = 0; i < jsonResult.length; i++) {
              final String key = jsonResult.keys.elementAt(i);
              dynamic jsonObj = jsonResult[key];
              if ((jsonObj != null) && (key == DatabaseHelper.columnData)) {
                if (jsonObj.runtimeType == String) {
                  jsonObj = jsonDecode(jsonObj as String);
                }
                /*print("----------------------key---------------------\n");
                print(key);
                print("______________________value_____________________\n");
                print(jsonObj.runtimeType);
                print(jsonObj.toString());
                print("-------------------------------------------\n");*/
                if (jsonObj.runtimeType.toString() == "_Map<String, dynamic>") {
                  final Map<String, dynamic> listObj = jsonObj;
                  if (listObj.isNotEmpty) {
                    /* print("______________________listObj[$k]_____________________\n");
                    print(listObj[k].runtimeType);
                    print(listObj[k].toString());*/
                    if (listObj.runtimeType.toString() == "_Map<String, dynamic>") {
                      /*print("----------------------jsonMap---------------------\n");
                      print(listObj[k].toString());*/
                      switch (reqAction) {
                        case DBAction.create:
                          final nTimeEntry = TimeEntry.fromJson(listObj["timeEntry"]);
                          final int nUserId = listObj["userId"];
                          if (isOnline) {
                            create(timeEntry: nTimeEntry, userId: nUserId, storeInCache: false);
                          }
                          retVal.add(nTimeEntry);
                          break;

                        case DBAction.update:
                          final TimeEntry uTimeEntry = TimeEntry.fromJson(listObj["timeEntry"]);
                          if (isOnline) {
                            update(timeEntry: uTimeEntry, storeInCache: false);
                          }
                          retVal.add(uTimeEntry);
                          break;

                        case DBAction.delete:
                          final int teID = listObj["id"];
                          if (isOnline) {
                            delete(id: teID, storeInCache: false);
                          }
                          retVal.add(teID);
                          break;
                      }
                    }
                  }
                }
              }
            }
          }
        }
        on Exception catch (e) {
          print(e.toString());
          noError = false;
        }
        finally {
        }
      }
    }
    if (foundData && isOnline) {
      try {
        for (int i = 0; i < reqStrings.length; i++) {
          if (noError) {
            final String reqString = reqStrings.keys.elementAt(i);
            final String deleteStr = "DELETE FROM ${DatabaseHelper
                .tableChanges} WHERE ${DatabaseHelper
                .columnRequest} = '$reqString'";
            try {
              print('delete: "$deleteStr"');
              await db.rawDelete(deleteStr);
            }
            on Exception catch (e) {
              print(e.toString());
              noError = false;
            }
            finally {}
          }
        }
      }
      on Exception catch (e) {
        print(e.toString());
        noError = false;
      }
      finally {}
    }
    return retVal;
  }
}
