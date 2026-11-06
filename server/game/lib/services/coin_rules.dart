import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../models/active_game.dart';
import '../models/app_config.dart';
import '../models/coin.dart';
import '../models/game_enums.dart';

// 엽전 계산. DB에 닿지 않는 순수 함수다(`docs/server.md`의 엽전). Functions의 `coinService.ts`와 규칙을 일치시킨다.

/// 지갑과 내역에 함께 쓸 엽전 움직임 하나.
class CoinMove {
  final String uid;
  final String transactionId;
  final CoinTransaction transaction;

  const CoinMove({required this.uid, required this.transactionId, required this.transaction});
}

/// 트랜잭션에서 쓸 움직임들과 그 뒤의 지갑. [wallets]에는 바뀐 사용자만 있다.
class CoinPlan {
  final Map<String, CoinWallet> wallets;
  final List<CoinMove> moves;

  const CoinPlan({required this.wallets, required this.moves});

  static const empty = CoinPlan(wallets: {}, moves: []);
}

/// 하루의 기준. 서울 시간 0시에 바뀌는 yyyy-MM-dd다(`docs/monetization.md`의 엽전). Functions의 `getCoinDay`와 같다.
String getCoinDay(DateTime time) => time.toUtc().add(coinDayUtcOffset).toIso8601String().substring(0, 10);

/// 내역 문서 ID. 이유, uid, 한 번만 일어나는 일의 열쇠로 정해 같은 일이 두 번 쓰이지 않게 한다. Functions의 `getCoinTransactionId`와
/// 같은 모양이다.
String getCoinTransactionId(CoinReason reason, String uid, String key) => '${reason.name}_${uid}_$key';

/// 대국 종류가 참가비와 보상을 받는지. 방·링크 대국은 둘 다 없다(`docs/monetization.md`의 엽전).
bool isCoinGame(GameMeta meta) => meta.mode != GameMode.room;

/// 참가비를 받는 움직임을 정한다(`docs/monetization.md`의 엽전).
///
/// [feeTransactions]에 이미 있는 사용자는 건너뛰어 한 번만 받는다. 잔액이 참가비보다 적으면, 바닥 구제 대상이고 오늘 아직 받지
/// 않았을 때 구제를 먼저 주고 받는다. 그래도 모자라면 참가비 없이 두고 0인 내역을 남긴다. 그래서 엽전 때문에 대국을 못 만드는 일은 없다.
CoinPlan planEntryFees({
  required String gameId,
  required List<String> uids,
  required Map<String, CoinWallet?> wallets,
  required Map<String, CoinTransaction?> feeTransactions,
  required AppConfig config,
  required DateTime now,
}) {
  final fee = config.coinEntryFee;
  if (!config.entryFeeEnabled || fee <= 0) {
    return CoinPlan.empty;
  }
  final day = getCoinDay(now);
  final nextWallets = <String, CoinWallet>{};
  final moves = <CoinMove>[];
  for (final uid in uids) {
    if (feeTransactions[getCoinTransactionId(CoinReason.entryFee, uid, gameId)] != null) {
      continue;
    }
    var wallet = wallets[uid] ?? _emptyWallet(now);
    if (wallet.balance < fee && wallet.balance < config.coinRescueThreshold && wallet.rescueDay != day) {
      wallet = _apply(wallet, freeDelta: config.coinRescueReward, paidDelta: 0, rescueDay: day, now: now);
      moves.add(_createMove(uid, CoinReason.rescue, day, wallet, config.coinRescueReward, 0, null, now));
    }
    if (wallet.balance >= fee) {
      final fromFree = wallet.freeCoins < fee ? wallet.freeCoins : fee;
      final fromPaid = fee - fromFree;
      wallet = _apply(wallet, freeDelta: -fromFree, paidDelta: -fromPaid, now: now);
      moves.add(_createMove(uid, CoinReason.entryFee, gameId, wallet, -fromFree, -fromPaid, gameId, now));
    } else {
      wallet = _apply(wallet, freeDelta: 0, paidDelta: 0, now: now);
      moves.add(_createMove(uid, CoinReason.entryFee, gameId, wallet, 0, 0, gameId, now));
    }
    nextWallets[uid] = wallet;
  }
  return CoinPlan(wallets: nextWallets, moves: moves);
}

/// 끝난 대국의 참가비 돌려주기나 보상을 정한다(`docs/server.md`의 엽전).
///
/// 수가 하나도 없이 끝나면 대국이 성립하지 않은 것으로 보고 참가비를 낸 그대로(무상은 무상으로, 유상은 유상으로) 돌려주며 보상은
/// 없다. 끝낸 쪽이 누구든 같다. 그 밖에는 이긴 쪽과 진 쪽에게 보상을 무상으로 준다. 무승부는 지금 규칙에 없어 쓰지 않는다
/// (`docs/monetization.md`의 엽전). 한 번만 반영되는 것은 부르는 쪽(`finalizeGame`)이 기보 저장과 같은 트랜잭션에서 보장한다.
CoinPlan planGameEnd({
  required String gameId,
  required ActiveGame game,
  required Map<String, CoinWallet?> wallets,
  required Map<String, CoinTransaction?> feeTransactions,
  required AppConfig config,
  required DateTime now,
}) {
  final players = game.meta.players;
  final nextWallets = <String, CoinWallet>{};
  final moves = <CoinMove>[];
  final established = game.moves.isNotEmpty;
  for (final side in Side.values) {
    final uid = players.get(side).uid;
    final wallet = wallets[uid] ?? _emptyWallet(now);
    if (established) {
      final amount = side == game.state.result!.winner ? config.coinWinReward : config.coinLossReward;
      if (amount > 0) {
        final next = _apply(wallet, freeDelta: amount, paidDelta: 0, now: now);
        nextWallets[uid] = next;
        moves.add(_createMove(uid, CoinReason.gameReward, gameId, next, amount, 0, gameId, now));
      }
      continue;
    }
    final fee = feeTransactions[getCoinTransactionId(CoinReason.entryFee, uid, gameId)];
    if (fee == null || (fee.freeDelta == 0 && fee.paidDelta == 0)) {
      continue;
    }
    final next = _apply(wallet, freeDelta: -fee.freeDelta, paidDelta: -fee.paidDelta, now: now);
    nextWallets[uid] = next;
    moves.add(_createMove(uid, CoinReason.entryFeeRefund, gameId, next, -fee.freeDelta, -fee.paidDelta, gameId, now));
  }
  return CoinPlan(wallets: nextWallets, moves: moves);
}

/// 지갑이 없는 사용자(엽전이 생기기 전에 가입)는 잔액 0으로 본다.
CoinWallet _emptyWallet(DateTime now) => CoinWallet(
  freeCoins: 0,
  paidCoins: 0,
  balance: 0,
  attendanceDay: null,
  attendanceStreak: 0,
  rescueDay: null,
  updatedAt: now,
);

CoinWallet _apply(
  CoinWallet wallet, {
  required int freeDelta,
  required int paidDelta,
  String? rescueDay,
  required DateTime now,
}) {
  final freeCoins = wallet.freeCoins + freeDelta;
  final paidCoins = wallet.paidCoins + paidDelta;
  return CoinWallet(
    freeCoins: freeCoins,
    paidCoins: paidCoins,
    balance: freeCoins + paidCoins,
    attendanceDay: wallet.attendanceDay,
    attendanceStreak: wallet.attendanceStreak,
    rescueDay: rescueDay ?? wallet.rescueDay,
    updatedAt: now,
  );
}

CoinMove _createMove(
  String uid,
  CoinReason reason,
  String key,
  CoinWallet after,
  int freeDelta,
  int paidDelta,
  String? gameId,
  DateTime now,
) {
  return CoinMove(
    uid: uid,
    transactionId: getCoinTransactionId(reason, uid, key),
    transaction: CoinTransaction(
      uid: uid,
      reason: reason,
      freeDelta: freeDelta,
      paidDelta: paidDelta,
      freeBalance: after.freeCoins,
      paidBalance: after.paidCoins,
      gameId: gameId,
      createdAt: now,
    ),
  );
}
