import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/models/app_config.dart';
import 'package:janggigo_game/models/coin.dart';
import 'package:janggigo_game/models/game_enums.dart';
import 'package:janggigo_game/services/coin_rules.dart';
import 'package:janggigo_game/services/game_rules.dart';
import 'package:test/test.dart';

const _config = AppConfig(
  disconnectLimitSeconds: 30,
  quickRematchLimit: 5,
  onlineUsersVisible: false,
  autoSanctionEnabled: false,
  heartbeatSeconds: 5,
  entryFeeEnabled: true,
  coinSignupBonus: 300,
  coinEntryFee: 10,
  coinWinReward: 15,
  coinDrawReward: 10,
  coinLossReward: 5,
  coinAttendanceReward: 30,
  coinAttendanceStreakReward: 100,
  coinRescueReward: 50,
  coinRescueThreshold: 10,
  coinNicknameChangeCost: 300,
);

final _now = DateTime.utc(2026, 11, 6, 3);

CoinWallet _wallet({int free = 0, int paid = 0, String? rescueDay}) => CoinWallet(
  freeCoins: free,
  paidCoins: paid,
  balance: free + paid,
  attendanceDay: null,
  attendanceStreak: 0,
  rescueDay: rescueDay,
  updatedAt: _now,
);

CoinPlan _planFee(CoinWallet? wallet, {AppConfig config = _config, CoinTransaction? existingFee}) => planEntryFees(
  gameId: 'g1',
  uids: ['u1'],
  wallets: {'u1': wallet},
  feeTransactions: {'entryFee_u1_g1': existingFee},
  config: config,
  now: _now,
);

AppConfig _configWith({bool entryFeeEnabled = true, int fee = 10, int threshold = 10}) => AppConfig(
  disconnectLimitSeconds: 30,
  quickRematchLimit: 5,
  onlineUsersVisible: false,
  autoSanctionEnabled: false,
  heartbeatSeconds: 5,
  entryFeeEnabled: entryFeeEnabled,
  coinSignupBonus: 300,
  coinEntryFee: fee,
  coinWinReward: 15,
  coinDrawReward: 10,
  coinLossReward: 5,
  coinAttendanceReward: 30,
  coinAttendanceStreakReward: 100,
  coinRescueReward: 50,
  coinRescueThreshold: threshold,
  coinNicknameChangeCost: 300,
);

CoinTransaction _fee({required int free, required int paid}) => CoinTransaction(
  uid: 'cho',
  reason: CoinReason.entryFee,
  freeDelta: free,
  paidDelta: paid,
  freeBalance: 0,
  paidBalance: 0,
  gameId: 'g1',
  createdAt: _now,
);

/// 한이 기권해 끝난 대국. [moves]가 true면 수가 하나 있다.
ActiveGame _finishedGame({required bool moves}) {
  final game = createActiveGame(
    mode: GameMode.quick,
    rated: true,
    listed: true,
    players: const GamePlayers(
      cho: GamePlayer(uid: 'cho', nickname: '초', rankLevel: 1),
      han: GamePlayer(uid: 'han', nickname: '한', rankLevel: 1),
    ),
    timeControl: const TimeControl(
      baseMs: 60000,
      periodMs: 30000,
      periods: 3,
      setupMs: 20000,
      extensionPeriods: 2,
      extensionLimit: 2,
    ),
    disconnectLimitMs: 30000,
    now: 0,
    rematchBlocked: false,
  );
  final finished = resign(game, Side.han, 1000);
  if (!moves) {
    return finished;
  }
  return finished.copyWith(moves: const [GameMoveRecord(m: 'pass', spentMs: 1)]);
}

CoinPlan _planEnd(
  ActiveGame game, {
  Map<String, CoinWallet?> wallets = const {},
  Map<String, CoinTransaction?> fees = const {},
}) => planGameEnd(gameId: 'g1', game: game, wallets: wallets, feeTransactions: fees, config: _config, now: _now);

void main() {
  group('getCoinDay', () {
    test('서울 0시에 날이 바뀐다', () {
      expect(getCoinDay(DateTime.utc(2026, 11, 5, 14, 59)), '2026-11-05');
      expect(getCoinDay(DateTime.utc(2026, 11, 5, 15)), '2026-11-06');
    });
  });

  group('참가비', () {
    test('무상부터 쓴다', () {
      final plan = _planFee(_wallet(free: 20, paid: 5));
      expect(plan.wallets['u1']?.freeCoins, 10);
      expect(plan.wallets['u1']?.paidCoins, 5);
      expect(plan.moves.single.transactionId, 'entryFee_u1_g1');
      expect(plan.moves.single.transaction.freeDelta, -10);
      expect(plan.moves.single.transaction.paidDelta, 0);
    });

    test('무상이 모자라면 나머지를 유상에서 낸다', () {
      final plan = _planFee(_wallet(free: 3, paid: 20));
      expect(plan.wallets['u1']?.freeCoins, 0);
      expect(plan.wallets['u1']?.paidCoins, 13);
      expect(plan.wallets['u1']?.balance, 13);
      expect(plan.moves.single.transaction.freeDelta, -3);
      expect(plan.moves.single.transaction.paidDelta, -7);
    });

    test('잔액이 모자라고 오늘 구제를 받지 않았으면 구제를 주고 받는다', () {
      final plan = _planFee(_wallet(free: 4));
      expect(plan.wallets['u1']?.balance, 44);
      expect(plan.wallets['u1']?.rescueDay, '2026-11-06');
      expect(plan.moves.map((move) => move.transactionId), ['rescue_u1_2026-11-06', 'entryFee_u1_g1']);
      expect(plan.moves.first.transaction.freeDelta, 50);
      expect(plan.moves.last.transaction.freeBalance, 44);
    });

    test('지갑이 없어도(엽전이 생기기 전 가입) 구제를 주고 받는다', () {
      final plan = _planFee(null);
      expect(plan.wallets['u1']?.balance, 40);
    });

    test('잔액이 모자라고 오늘 구제를 받았으면 참가비 없이 둔다', () {
      final plan = _planFee(_wallet(free: 9, rescueDay: '2026-11-06'));
      expect(plan.wallets['u1']?.balance, 9);
      expect(plan.moves.single.transactionId, 'entryFee_u1_g1');
      expect(plan.moves.single.transaction.freeDelta, 0);
      expect(plan.moves.single.transaction.paidDelta, 0);
    });

    test('어제 구제를 받았으면 오늘 다시 받는다', () {
      final plan = _planFee(_wallet(rescueDay: '2026-11-05'));
      expect(plan.wallets['u1']?.balance, 40);
    });

    test('구제 기준 이상인데 참가비가 더 크면 구제 없이 참가비 없이 둔다', () {
      final plan = _planFee(_wallet(free: 15), config: _configWith(fee: 20));
      expect(plan.wallets['u1']?.balance, 15);
      expect(plan.moves.single.transaction.freeDelta, 0);
    });

    test('이미 받은 대국은 다시 받지 않는다', () {
      final plan = _planFee(_wallet(free: 100), existingFee: _fee(free: -10, paid: 0));
      expect(plan.wallets, isEmpty);
      expect(plan.moves, isEmpty);
    });

    test('entryFeeEnabled가 꺼져 있으면 받지 않는다', () {
      final plan = _planFee(_wallet(free: 100), config: _configWith(entryFeeEnabled: false));
      expect(plan.moves, isEmpty);
    });
  });

  group('대국 끝', () {
    test('이긴 쪽과 진 쪽에게 보상을 무상으로 준다', () {
      final plan = _planEnd(
        _finishedGame(moves: true),
        wallets: {'cho': _wallet(free: 1, paid: 2), 'han': _wallet(free: 3)},
      );
      expect(plan.wallets['cho']?.freeCoins, 16);
      expect(plan.wallets['cho']?.paidCoins, 2);
      expect(plan.wallets['han']?.freeCoins, 8);
      expect(plan.moves.map((move) => move.transactionId), ['gameReward_cho_g1', 'gameReward_han_g1']);
    });

    test('수가 없이 끝나면 참가비를 낸 그대로 돌려주고 보상은 없다', () {
      final plan = _planEnd(
        _finishedGame(moves: false),
        wallets: {'cho': _wallet(free: 0, paid: 13), 'han': _wallet(free: 90)},
        fees: {'entryFee_cho_g1': _fee(free: -3, paid: -7), 'entryFee_han_g1': _fee(free: -10, paid: 0)},
      );
      expect(plan.wallets['cho']?.freeCoins, 3);
      expect(plan.wallets['cho']?.paidCoins, 20);
      expect(plan.wallets['han']?.freeCoins, 100);
      expect(plan.moves.map((move) => move.transactionId), ['entryFeeRefund_cho_g1', 'entryFeeRefund_han_g1']);
      expect(plan.moves.first.transaction.paidDelta, 7);
    });

    test('참가비를 내지 않았으면(면제, 스위치 꺼짐) 돌려줄 것이 없다', () {
      final plan = _planEnd(
        _finishedGame(moves: false),
        wallets: {'cho': _wallet(free: 5)},
        fees: {'entryFee_cho_g1': _fee(free: 0, paid: 0), 'entryFee_han_g1': null},
      );
      expect(plan.wallets, isEmpty);
      expect(plan.moves, isEmpty);
    });
  });
}
