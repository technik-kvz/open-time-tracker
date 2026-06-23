// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_project_time_tracker/app/services/analytics_service.dart';
import 'package:open_project_time_tracker/l10n/app_localizations.dart';
import 'package:open_project_time_tracker/app/navigation/app_router.dart';
import 'package:open_project_time_tracker/app/ui/asset_images.dart';
import 'app/di/inject.dart';
import 'app/services/local_notification_service.dart';
import 'modules/calendar/domain/calendar_notifications_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

void main() async {
  configureDependencies();
  await dotenv.load();
  inject<LocalNotificationService>().setup();

  // Initialize analytics in background - don't block app startup
  // ignore: unawaited_futures
  inject<AnalyticsService>().initialize();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory. On iOS/Android, if not using `sqlite_flutter_lib` you can forget
    // this step, it will use the sqlite version available on the system.
    databaseFactory = databaseFactoryFfi;
  }
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Database db = await _databaseHelper.database;
  final String now = DateTime.now().toLocal().toIso8601String();
  final String version = (await db.getVersion()).toString();
  final String reqString = 'startup';
  final String datString = '{ "date": "$now", "version", "$version" }';
  final Map<String, String> row = {
    DatabaseHelper.columnRequest : reqString,
    DatabaseHelper.columnData : datString
  };
  int id = await db.insert(DatabaseHelper.tableCache, row, conflictAlgorithm: ConflictAlgorithm.replace);
  // show the results: print all rows in the db
  print("\n-----------------DB Cache-----------------\n");
  print(await db.query(DatabaseHelper.tableCache));
  print("\n-----------------DB Changes-----------------\n");
  print(await db.query(DatabaseHelper.tableChanges));
  print("\n----------------------------------------\n");

  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CalendarNotificationsScheduler(inject<CalendarNotificationsService>()),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CalendarNotificationsScheduler extends StatefulWidget {
  final CalendarNotificationsService calendarNotificationsService;

  const CalendarNotificationsScheduler(
    this.calendarNotificationsService, {
    super.key,
  });

  @override
  State<CalendarNotificationsScheduler> createState() =>
      _CalendarNotificationsSchedulerState();
}

class _CalendarNotificationsSchedulerState
    extends State<CalendarNotificationsScheduler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _scheduleNotifications();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleNotifications();
    }
    super.didChangeAppLifecycleState(state);
  }

  _scheduleNotifications() async {
    try {
      await widget.calendarNotificationsService.removeNotifications();
      final context = navigatorKey.currentContext!;
      await widget.calendarNotificationsService.scheduleNotifications(
        AppLocalizations.of(context).notifications_calendar_title,
        AppLocalizations.of(context).notifications_calendar_body,
      );
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    precacheImage(AssetImage(AssetImages.logo), context);
    const themeColor = Color.fromRGBO(38, 92, 185, 1);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
        Locale('es'),
        Locale('fr'),
        Locale('tr'),
      ],
      title: 'Open Project Time Tracker',
      theme: ThemeData(
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 243, 243, 243),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 249, 249, 249),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        primaryColor: themeColor,
        fontFamily: 'Cupertino',
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: themeColor),
        ),
        cupertinoOverrideTheme: const CupertinoThemeData(
          primaryColor: themeColor,
        ),
      ),
      home: const AppRouter(),
    );
  }
}
