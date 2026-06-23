import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_project_time_tracker/modules/authorization/domain/user_data_repository.dart';
import 'package:open_project_time_tracker/modules/authorization/infrastructure/user_data_api.dart';
import 'package:sqflite/sqflite.dart';
import 'package:open_project_time_tracker/database_helper.dart';

class ApiUserDataRepository implements UserDataRepository {
  final UserDataApi _restApi;
  static UserData? _cachedUserData = null;

  ApiUserDataRepository(this._restApi);

  Future<UserData> getUserData() async {
    const String reqString = 'userdata';
    bool storeData = false;
    if (_cachedUserData == null) {
      try {
        _cachedUserData = await _restApi.getUserData().timeout(const Duration(seconds: 3));
        storeData = true;
      }
      catch (e) {
        if ((e is TimeoutException) || (e is SocketException)  || ((e is DioException) && (e.error is SocketException))) {
          final String jE = e.toString();
          print("timeout userdata: $jE");
          final List<String> columns = [
            DatabaseHelper.columnRequest,
            DatabaseHelper.columnData
          ];
          final String columnRequest = DatabaseHelper.columnRequest;
          final String queryEquals = ' = ?';
          final String where = columnRequest + queryEquals;
          final List<String> whereArgs = [ reqString];
          final DatabaseHelper _databaseHelper = DatabaseHelper();
          final Database db = await _databaseHelper.database;
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
                  if (jsonObj.runtimeType.toString() == "_Map<String, dynamic>") {
                    final UserData listElementUserdata = UserData.fromJson(
                        jsonObj);
                    /*print("----------------------userdata---------------------\n");
                  print(listElementUserdata.toString());*/
                    _cachedUserData = listElementUserdata;
                    /*print("-------------------------------------------\n");
                  print("_cachedUserData filled");*/
                  }
                }
              }
            }
          }
        } else {
          rethrow;
        }
      } on Exception catch (e) {
        print(e.toString());
      }
      finally {
      }
      if (storeData && (_cachedUserData != null)) {
        final DatabaseHelper _databaseHelper = DatabaseHelper();
        final Database db = await _databaseHelper.database;
        try {
          final String userdataString = jsonEncode(_cachedUserData);
          print("got userdata: $userdataString");
          final Map<String, String> row = {
            DatabaseHelper.columnRequest: reqString,
            DatabaseHelper.columnData: userdataString
          };
          final String jRow = jsonEncode(row);
          print("store userdata: $jRow");
          await db.insert(DatabaseHelper.tableCache, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        on Exception catch(e) {
          final String jE = jsonEncode(e);
          print("userdata error: $jE");
        }
        finally {}
        // show the results: print all rows in the db
        print(await db.query(DatabaseHelper.tableCache));
      }
    }
    if (_cachedUserData != null) {
      final String cachedUserDataJson = jsonEncode(_cachedUserData);
      print('return userdata : "$cachedUserDataJson"');
      return _cachedUserData!;
    }
    else {
      return UserData(id: -1, name: "");
    }
  }

  void clearCache() {
    _cachedUserData = null;
  }

  @override
  Future<int> userId() async {
    final userData = await getUserData();
    return userData.id;
  }

  @override
  Future<String> userName() async {
    final userData = await getUserData();
    return userData.name;
  }
}
