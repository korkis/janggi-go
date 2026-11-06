import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_config.dart';

/// Firestore `configs` 컬렉션. 로그인 전에도 읽을 수 있다.
class ConfigRepository {
  final FirebaseFirestore firestore;

  ConfigRepository({required this.firestore});

  /// `configs/app`. 문서가 없으면 운영 설정이 빠진 것이므로 오류를 던진다.
  Future<AppConfig> getAppConfig() async {
    final snapshot = await firestore.collection('configs').doc('app').get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('configs/app 문서가 없습니다');
    }
    return AppConfig.fromJson(data);
  }

  /// `configs/app`을 듣는다. 문서가 없으면 null을 보낸다.
  Stream<AppConfig?> watchAppConfig() => firestore.collection('configs').doc('app').snapshots().map(_decode);

  static AppConfig? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : AppConfig.fromJson(data);
  }
}
