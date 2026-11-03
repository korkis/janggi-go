import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'managers/app_managers.dart';
import 'repositories/app_repositories.dart';
import 'utils/auth_emulator_origin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  repositories = AppRepositories.createDefault();
  managers = AppManagers.createDefault();
  managers.connectionManager.observeAppLifecycle();
  managers.inviteLinkManager.start();
  runApp(const JanggigoApp());
}

/// Firebase를 초기화한다. 개발 빌드는 에뮬레이터에 연결한다.
Future<void> _initializeFirebase() async {
  if (!useFirebaseEmulator) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return;
  }
  final host = getFirebaseEmulatorHost();
  rememberAuthEmulatorOrigin(defaultFirebaseAppName, 'http://$host:${EmulatorPorts.auth}');
  await Firebase.initializeApp(options: getEmulatorFirebaseOptions());
  await FirebaseAuth.instance.useAuthEmulator(host, EmulatorPorts.auth);
  FirebaseFirestore.instance.useFirestoreEmulator(host, EmulatorPorts.firestore);
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(host, EmulatorPorts.functions);
  // 안드로이드는 에뮬레이터 주소를 databaseURL에 직접 넣었다(getAndroidEmulatorDatabaseUrl).
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    FirebaseDatabase.instance.useDatabaseEmulator(host, EmulatorPorts.database);
  }
}
