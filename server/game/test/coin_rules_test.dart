import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo_game/models/active_game.dart';
import 'package:janggigo_game/models/app_config.dart';
import 'package:janggigo_game/models/coin.dart';
import 'package:janggigo_game/models/game_enums.dart';
import 'package:janggigo_game/services/coin_rules.dart';
import 'package:janggigo_game/services/game_rules.dart';
import 'package:test/test.dart';

AppConfig _config({bool entryFeeEnabled = true}) => AppConfig(
  disconnectLimitSeconds: 30,
  quickRematchLimit: 5,
  onlineUsersVisible: false,
  autoSanctionEnabled: false,
  heartbeatSeconds: 5,
  entryFeeEnabled: entryFeeEnabled,
  coinSignupBonus: 300,
  coinEntryFee: 10,
  coinWinReward: 12,
  coinLossReward: 3,
  coinAttendanceReward: 30,
  coinAttendanceStreakReward: 100,
  coinNicknameChangeCost: 300,
  timeExtensionEnabled: true,
  gamePracticeEnabled: true,
  coinTimeExtensionCost: 30,
  coinGamePracticeCost: 30,
  chatEnabled: true,
  signupEnabled: true,
  webEnabled: true,
  coinSaleEnabled: true,
  minAppVersion: '1.0.0',
  serviceNotice: null,
);

final _now = DateTime.utc(2026, 11, 6, 3);

CoinWallet _wallet({int free = 0, int paid = 0}) => CoinWallet(
  freeCoins: free,
  paidCoins: paid,
  balance: free + paid,
  attendanceDay: null,
  attendanceStreak: 0,
  updatedAt: _now,
);

CoinPlan _planFee(CoinWallet? wallet, {bool entryFeeEnabled = true, CoinTransaction? existingFee}) => planEntryFees(
  gameId: 'g1',
  uids: ['u1'],
  wallets: {'u1': wallet},
  feeTransactions: {'entryFee_u1_g1': existingFee},
  config: _config(entryFeeEnabled: entryFeeEnabled),
  now: _now,
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
ActiveGame _finishedGame({required bool moves, GameMode mode = GameMode.quick}) {
  final game = createActiveGame(
    mode: mode,
    rated: false,
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
  required Map<String, CoinWallet?> wallets,
  Map<String, CoinTransaction?> fees = const {},
  Map<String, CoinTransaction?> extensions = const {},
}) => planGameEnd(
  gameId: 'g1',
  game: game,
  wallets: wallets,
  feeTransactions: fees,
  extensionTransactions: extensions,
  config: _config(),
  now: _now,
);

void main() {
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

    test('딱 참가비만큼 있으면 낸다', () {
      expect(_planFee(_wallet(free: 10)).wallets['u1']?.balance, 0);
    });

    test('모자라면 누구 때문인지 담아 거절한다', () {
      expect(
        () => _planFee(_wallet(free: 5, paid: 4)),
        throwsA(isA<InsufficientCoinsException>().having((error) => error.uid, 'uid', 'u1')),
      );
      expect(() => _planFee(null), throwsA(isA<InsufficientCoinsException>()));
    });

    test('이미 받은 대국은 다시 받지 않는다', () {
      final plan = _planFee(_wallet(free: 100), existingFee: _fee(free: -10, paid: 0));
      expect(plan.wallets, isEmpty);
      expect(plan.moves, isEmpty);
    });

    test('entryFeeEnabled가 꺼져 있으면 받지 않고 모자라도 거절하지 않는다', () {
      expect(_planFee(_wallet(free: 100), entryFeeEnabled: false).moves, isEmpty);
      expect(_planFee(_wallet(), entryFeeEnabled: false).moves, isEmpty);
    });
  });

  group('대국 끝', () {
    test('이긴 쪽과 진 쪽에게 보상을 무상으로 준다', () {
      final plan = _planEnd(
        _finishedGame(moves: true),
        wallets: {'cho': _wallet(free: 1, paid: 2), 'han': _wallet(free: 3)},
      );
      expect(plan.wallets['cho']?.freeCoins, 13);
      expect(plan.wallets['cho']?.paidCoins, 2);
      expect(plan.wallets['han']?.freeCoins, 6);
      expect(plan.moves.map((move) => move.transactionId), ['gameReward_cho_g1', 'gameReward_han_g1']);
    });

    test('방 대국도 보상을 준다', () {
      final plan = _planEnd(
        _finishedGame(moves: true, mode: GameMode.room),
        wallets: {'cho': _wallet(), 'han': _wallet()},
      );
      expect(plan.wallets['cho']?.balance, 12);
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

    test('참가비를 내지 않았으면(스위치 꺼짐) 돌려줄 것이 없다', () {
      final plan = _planEnd(_finishedGame(moves: false), wallets: {'cho': _wallet(free: 5), 'han': _wallet()});
      expect(plan.wallets, isEmpty);
      expect(plan.moves, isEmpty);
    });

    test('값을 받았지만 반영되지 않은 시간 연장은 보상과 함께 낸 그대로 돌려준다', () {
      final extension = _fee(free: -10, paid: -20);
      final plan = _planEnd(
        _finishedGame(moves: true),
        wallets: {'cho': _wallet(free: 0, paid: 5), 'han': _wallet()},
        extensions: {'timeExtension_cho_g1_1': extension},
      );
      expect(plan.wallets['cho']?.freeCoins, 22);
      expect(plan.wallets['cho']?.paidCoins, 25);
      expect(plan.moves.map((move) => move.transactionId), [
        'gameReward_cho_g1',
        'timeExtensionRefund_cho_g1_1',
        'gameReward_han_g1',
      ]);
    });

    test('이미 돌려줬거나 시계에 반영된 시간 연장은 돌려주지 않는다', () {
      final extension = _fee(free: -30, paid: 0);
      final game = _finishedGame(moves: false);
      final extended = game.copyWith(
        state: game.state.copyWith(
          clock: game.state.clock.copyWithSide(Side.cho, const SideClock(baseMs: 60000, periods: 5, extensionsUsed: 1)),
        ),
      );
      final plan = _planEnd(
        extended,
        wallets: {'cho': _wallet(free: 5), 'han': _wallet(free: 5)},
        extensions: {
          'timeExtension_cho_g1_1': extension,
          'timeExtension_han_g1_1': extension,
          'timeExtensionRefund_han_g1_1': extension,
        },
      );
      expect(plan.wallets, isEmpty);
      expect(plan.moves, isEmpty);
    });
  });

  group('대국 중 값', () {
    test('무상부터 내고 열쇠로 내역 문서 ID를 정한다', () {
      final plan = planGameItemSpend(
        uid: 'u1',
        wallet: _wallet(free: 10, paid: 25),
        reason: CoinReason.timeExtension,
        gameId: 'g1',
        key: getTimeExtensionKey('g1', 1),
        cost: 30,
        now: _now,
      );
      expect(plan.wallets['u1']?.freeCoins, 0);
      expect(plan.wallets['u1']?.paidCoins, 5);
      expect(plan.moves.single.transactionId, 'timeExtension_u1_g1_2');
      expect(plan.moves.single.transaction.gameId, 'g1');
    });

    test('모자라면 거절한다', () {
      expect(
        () => planGameItemSpend(
          uid: 'u1',
          wallet: _wallet(free: 29),
          reason: CoinReason.gamePractice,
          gameId: 'g1',
          key: 'g1',
          cost: 30,
          now: _now,
        ),
        throwsA(isA<InsufficientCoinsException>()),
      );
    });
  });
}
