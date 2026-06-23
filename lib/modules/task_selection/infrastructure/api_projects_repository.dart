import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_project_time_tracker/modules/task_selection/domain/projects_repository.dart';
import 'package:open_project_time_tracker/modules/task_selection/infrastructure/projects_api.dart';

import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../../../database_helper.dart';

class ApiProjectsRepository implements ProjectsRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ProjectsApi restApi;

  ApiProjectsRepository(this.restApi);

  @override
  Future<List<Project>> list({
    String? userId,
    bool? active,
    int? pageSize,
    bool sortByName = false,
    bool assignedToUser = false,
  }) async {
    List<String> filters = [];
    if (userId != null) {
      filters.add('{"visible":{"operator":"=","values":["$userId"]}}');
    }
    if (active != null) {
      filters.add(
          '{"active":{"operator":"=","values":["${active ? 't' : 'f'}"]}}');
    }
    if (assignedToUser) {
      filters.add('{"member_of":{"operator":"=","values":["t"]}}');
    }
    final filtersString = '[${filters.join(', ')}]';

    List<String> sorters = [];
    if (sortByName) {
      sorters.add('["name", "asc"]');
    }
    final sortString = '[${sorters.join(', ')}]';

    final Database db = await _databaseHelper.database;
    final String jFiltersString = jsonEncode(filtersString);
    final String reqString = '{ "req": "projects", "filters" : $jFiltersString }';
    List<Project> returnVal = [];
    bool online = false;
    try {
      final response = await restApi.projects(
        filters: filtersString,
        pageSize: pageSize,
        sortBy: sortString,
      ).timeout(const Duration(seconds: 3));
      returnVal = response.projects
          .map((element) =>
          Project(
            id: element.id,
            title: element.title,
            href: element.href,
            updatedAt: element.updatedAt,
          ))
          .toList();
      print("returnVal filled");
      online = true;
    } on Exception catch(e) {
      if ((e is TimeoutException) || (e is SocketException)  || ((e is DioException) && (e.error is SocketException))) {
        print(e.toString());
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
              if (jsonObj != null) {
                if (jsonObj.runtimeType == String) {
                  jsonObj = jsonDecode(jsonObj as String);
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
                        if (listObj[k].runtimeType.toString() ==
                            "_Map<String, dynamic>") {
                          /*print("----------------------jsonMap---------------------\n");
                        print(listObj[k].toString());*/
                          final Project listElementProject = Project.fromJson(
                              listObj[k]);
                          /*print("----------------------project---------------------\n");
                        print(listElementProject.toString());*/
                          returnVal.add(listElementProject);
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
      } else {
        rethrow;
      }
    } catch (e) {
      print(e.toString());
    } finally {
    }
    if (online) {
      try {
        final List<Project> projects = returnVal;
        final String datString = jsonEncode(projects);
        final Map<String, String> row = { DatabaseHelper.columnRequest: reqString, DatabaseHelper.columnData: datString };
        await db.insert(DatabaseHelper.tableCache, row, conflictAlgorithm: ConflictAlgorithm.replace);
        // show the results: print all rows in the db
        print(await db.query(DatabaseHelper.tableCache));
      } on Exception catch (e) {
        print(e.toString());
      } finally {}
    }
    return returnVal;
  }
}
