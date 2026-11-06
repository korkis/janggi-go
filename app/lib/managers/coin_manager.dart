import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import '../config.dart';
import '../models/coin_wallet.dart';
import '../repositories/app_repositories.dart';
import 'auth_manager.dart';

/// 내 엽전 잔액과 출석(`docs/monetization.md`의 엽전). 로그인한 동안 지갑을 듣는다.
///
/// 닉네임까지 정한 사용자가 앱을 열거나 다른 앱에서 돌아오면 그날의 출석을 받는다. 서버가 하루 한 번만 주므로 여러 기기에서 불려도 괜찮다.
class CoinManager extends ChangeNotifier {
  final AuthManager authManager;

  StreamSubscription<CoinWallet?>? _subscription;
  AppLifecycleListener? _lifecycleListener;

  // 지금 듣고 있는 사용자.
  String? _uid;
  CoinWallet? _wallet;

  // 이 사용자의 출석을 확인한 날(서울 기준). 같은 날 다시 부르지 않는다.
  String? _attendanceCheckedDay;
  var _claiming = false;

  // 받았지만 아직 알리지 않은 출석 엽전.
  int? _attendanceGrant;

  CoinManager({required this.authManager}) {
    authManager.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  @override
  void dispose() {
    authManager.removeListener(_onAuthChanged);
    _subscription?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  /// 잔액. 아직 읽지 못했거나 지갑이 없으면 null.
  int? get balance => _wallet?.balance;

  /// 다른 앱에서 돌아오는 것을 듣기 시작한다. `main()`이 한 번 부른다.
  void observeAppLifecycle() {
    _lifecycleListener ??= AppLifecycleListener(onResume: _claimAttendance);
  }

  /// 받았지만 아직 알리지 않은 출석 엽전을 꺼낸다. 없으면 null.
  int? takeAttendanceGrant() {
    final grant = _attendanceGrant;
    _attendanceGrant = null;
    return grant;
  }

  void _onAuthChanged() {
    final uid = authManager.uid;
    if (uid != _uid) {
      _uid = uid;
      _subscription?.cancel();
      _subscription = null;
      _wallet = null;
      _attendanceCheckedDay = null;
      _attendanceGrant = null;
      if (uid != null) {
        _subscription = repositories.coinWalletRepository
            .watchWallet(uid)
            .listen(_onWalletChanged, onError: _onWatchError);
      }
      notifyListeners();
    }
    _claimAttendance();
  }

  void _onWalletChanged(CoinWallet? wallet) {
    _wallet = wallet;
    notifyListeners();
  }

  void _onWatchError(Object error, StackTrace stackTrace) {
    developer.log('CoinManager 듣기 실패', error: error, stackTrace: stackTrace);
  }

  /// 오늘 아직 확인하지 않았으면 출석을 받는다. 실패하면 다음에 돌아올 때 다시 한다. 화면에 알리지 않는다.
  Future<void> _claimAttendance() async {
    final uid = _uid;
    final today = _getCoinDay(DateTime.now());
    if (uid == null || authManager.profile == null || _claiming || _attendanceCheckedDay == today) {
      return;
    }
    try {
      _claiming = true;
      final result = await repositories.coinWalletRepository.claimAttendance();
      if (uid == _uid) {
        _attendanceCheckedDay = today;
        if (result.granted) {
          _attendanceGrant = result.amount;
          notifyListeners();
        }
      }
    } catch (error, stackTrace) {
      developer.log('CoinWalletRepository.claimAttendance 실패', error: error, stackTrace: stackTrace);
    } finally {
      _claiming = false;
    }
    if (uid != _uid) {
      await _claimAttendance();
    }
  }

  /// 서버의 하루 기준(서울 0시)에 맞춘 날짜. 서버가 다시 판단하므로 기기 시계가 틀려도 한 번 더 부르는 것으로 끝난다.
  static String _getCoinDay(DateTime time) => time.toUtc().add(coinDayUtcOffset).toIso8601String().substring(0, 10);
}
