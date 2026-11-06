import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/coin_wallet.dart';

/// Firestore `coin_wallets` 컬렉션과 출석 Callable. 지갑은 본인만 읽고 서버만 쓴다.
class CoinWalletRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  CoinWalletRepository({required this.firestore, required this.functions});

  /// 내 지갑을 듣는다. 엽전이 생기기 전에 가입해 아직 없으면 null을 보낸다.
  Stream<CoinWallet?> watchWallet(String uid) => firestore.collection('coin_wallets').doc(uid).snapshots().map(_decode);

  /// 내 지갑을 한 번 읽는다. 엽전이 생기기 전에 가입해 아직 없으면 null.
  Future<CoinWallet?> getWallet(String uid) async => _decode(await firestore.collection('coin_wallets').doc(uid).get());

  /// 오늘의 출석 엽전을 받는다. 오늘 이미 받았으면 `granted`가 false다.
  Future<AttendanceResult> claimAttendance() async {
    final result = await functions.httpsCallable('claimAttendance').call<Map<String, dynamic>>();
    final data = result.data;
    return AttendanceResult(granted: data['granted'] == true, amount: (data['amount'] as num).toInt());
  }

  static CoinWallet? _decode(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return data == null ? null : CoinWallet.fromJson(data);
  }
}
