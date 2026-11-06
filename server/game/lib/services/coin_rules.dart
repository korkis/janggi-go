import 'package:janggi_core/janggi_core.dart';

import '../http/callable.dart';
import '../models/active_game.dart';
import '../models/app_config.dart';
import '../models/coin.dart';

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

/// [uid]의 엽전이 참가비보다 적다. 앱에는 `coinsInsufficient`로 간다. 상대 때문에 막힌 호출은 [uid]를 보고 사유를 바꾼다.
class InsufficientCoinsException extends CallableException {
  final String uid;

  const InsufficientCoinsException(this.uid)
    : super(CallableStatus.failedPrecondition, '엽전이 모자랍니다', code: GameErrorCode.coinsInsufficient);
}

/// 내역 문서 ID. 이유, uid, 한 번만 일어나는 일의 열쇠로 정해 같은 일이 두 번 쓰이지 않게 한다. Functions의 `getCoinTransactionId`와
/// 같은 모양이다.
String getCoinTransactionId(CoinReason reason, String uid, String key) => '${reason.name}_${uid}_$key';

/// 참가비를 받는 움직임을 정한다(`docs/monetization.md`의 엽전). 무상부터 쓴다.
///
/// [feeTransactions]에 이미 있는 사용자는 건너뛰어 한 번만 받는다. 엽전이 모자란 사람이 있으면
/// [InsufficientCoinsException]을 던진다. 지갑은 가입할 때 만들므로 없으면 잔액이 없는 것으로 본다.
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
  final nextWallets = <String, CoinWallet>{};
  final moves = <CoinMove>[];
  for (final uid in uids) {
    if (feeTransactions[getCoinTransactionId(CoinReason.entryFee, uid, gameId)] != null) {
      continue;
    }
    final wallet = wallets[uid];
    if (wallet == null || wallet.balance < fee) {
      throw InsufficientCoinsException(uid);
    }
    final fromFree = wallet.freeCoins < fee ? wallet.freeCoins : fee;
    final next = _apply(wallet, freeDelta: -fromFree, paidDelta: -(fee - fromFree), now: now);
    nextWallets[uid] = next;
    moves.add(_createMove(uid, CoinReason.entryFee, gameId, next, -fromFree, -(fee - fromFree), now));
  }
  return CoinPlan(wallets: nextWallets, moves: moves);
}

/// 끝난 대국의 참가비 돌려주기나 보상을 정한다(`docs/server.md`의 엽전).
///
/// 수가 하나도 없이 끝나면 대국이 성립하지 않은 것으로 보고 참가비를 낸 그대로(무상은 무상으로, 유상은 유상으로) 돌려주며 보상은
/// 없다. 끝낸 쪽이 누구든 같다. 그 밖에는 이긴 쪽과 진 쪽에게 보상을 무상으로 준다. 한 번만 반영되는 것은 부르는 쪽(`finalizeGame`)이
/// 기보 저장과 같은 트랜잭션에서 보장한다.
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
    final wallet = wallets[uid];
    if (wallet == null) {
      continue;
    }
    if (established) {
      final amount = side == game.state.result!.winner ? config.coinWinReward : config.coinLossReward;
      if (amount > 0) {
        final next = _apply(wallet, freeDelta: amount, paidDelta: 0, now: now);
        nextWallets[uid] = next;
        moves.add(_createMove(uid, CoinReason.gameReward, gameId, next, amount, 0, now));
      }
      continue;
    }
    final fee = feeTransactions[getCoinTransactionId(CoinReason.entryFee, uid, gameId)];
    if (fee == null) {
      continue;
    }
    final next = _apply(wallet, freeDelta: -fee.freeDelta, paidDelta: -fee.paidDelta, now: now);
    nextWallets[uid] = next;
    moves.add(_createMove(uid, CoinReason.entryFeeRefund, gameId, next, -fee.freeDelta, -fee.paidDelta, now));
  }
  return CoinPlan(wallets: nextWallets, moves: moves);
}

CoinWallet _apply(CoinWallet wallet, {required int freeDelta, required int paidDelta, required DateTime now}) {
  final freeCoins = wallet.freeCoins + freeDelta;
  final paidCoins = wallet.paidCoins + paidDelta;
  return CoinWallet(
    freeCoins: freeCoins,
    paidCoins: paidCoins,
    balance: freeCoins + paidCoins,
    attendanceDay: wallet.attendanceDay,
    attendanceStreak: wallet.attendanceStreak,
    updatedAt: now,
  );
}

CoinMove _createMove(
  String gameUid,
  CoinReason reason,
  String gameId,
  CoinWallet after,
  int freeDelta,
  int paidDelta,
  DateTime now,
) {
  return CoinMove(
    uid: gameUid,
    transactionId: getCoinTransactionId(reason, gameUid, gameId),
    transaction: CoinTransaction(
      uid: gameUid,
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
