import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/work_packages_repository.dart';
import 'package:open_project_time_tracker/modules/task_selection/infrastructure/work_packages_api.dart';
import 'package:sqflite/sqflite.dart';
import '../../../database_helper.dart';

class ApiWorkPackagesRepository implements WorkPackagesRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  WorkPackagesApi restApi;

  ApiWorkPackagesRepository(this.restApi);

  @override
  Future<List<WorkPackage>> list({
    String? projectId,
    int? pageSize,
    Set<int>? statuses,
    String? user,
  }) async {
    List<WorkPackage> result = [];
    bool fromDatabase = false;
    bool isOnline = false;
    List<String> filters = [];

    if (user != null) {
      filters.add('{"assigneeOrGroup":{"operator":"=","values":["$user"]}}');
    }
    if (statuses != null && statuses.isNotEmpty) {
      final statusesString = statuses.map((e) => '"$e"').join(', ');
      filters.add('{"status":{"operator":"=","values":[$statusesString]}}');
    } else {
      filters.add('{"status":{"operator":"o","values":[]}}');
    }
    final filtersString = '[${filters.join(', ')}]';
    final String jFiltersString = jsonEncode(filtersString);
    final String reqString = '{ "req": "workPackages", "filters" : "$jFiltersString" }';
    final Database db = await _databaseHelper.database;
    try {

      WorkPackagesListResponse response;
      if (projectId != null) {
        response = await restApi.workPackagesOfProject(
          projectId: projectId,
          filters: filtersString,
          pageSize: pageSize,
        ).timeout(const Duration(seconds: 3));
      } else {
        response = await restApi.workPackages(
          filters: filtersString,
          pageSize: pageSize,
        );
      }

      result = response.workPackages.map(
            (e) =>
            WorkPackage(
                id: e.id,
                subject: e.subject,
                href: e.href,
                projectTitle: e.projectTitle,
                projectHref: e.projectHref,
                priority: e.priority,
                status: e.status,
                assignee: WorkPackageAssignee(
                  type: switch (e.assignee.type) {
                    WorkPackageAssigneeTypeResponse.user =>
                    WorkPackageAssigneeType.user,
                    WorkPackageAssigneeTypeResponse.group =>
                    WorkPackageAssigneeType.group,
                  },
                  title: e.assignee.title,
                )),
      ).toList();
      isOnline = true;
    }
    on Exception catch(e) {
      print(e.toString());
      if ((e is TimeoutException) || (e is SocketException) ||
          ((e is DioException) && (e.error is SocketException))) {
        fromDatabase = true;
      }
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
                          final WorkPackage listElementWorkPackage = WorkPackage.fromJson(listObj[k]);
                          /*print("----------------------project---------------------\n");
                          print(listElementTimeEntry.toString());*/
                          result.add(listElementWorkPackage);
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
    if (isOnline && result.isNotEmpty) {
      try {
        final String datString = jsonEncode(result);
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
    return result;
  }
}
