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

/// [uid]의 엽전이 내야 할 값보다 적다. 앱에는 `coinsInsufficient`로 간다. 상대 때문에 막힌 호출은 [uid]를 보고 사유를 바꾼다.
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
    final next = _spend(wallet, fee, now);
    nextWallets[uid] = next;
    moves.add(
      _createMove(
        uid,
        CoinReason.entryFee,
        gameId,
        gameId,
        next,
        next.freeCoins - wallet.freeCoins,
        next.paidCoins - wallet.paidCoins,
        now,
      ),
    );
  }
  return CoinPlan(wallets: nextWallets, moves: moves);
}

/// 시간 연장의 내역 열쇠. [extensionIndex]는 그 대국에서 몇 번째 연장인지(0부터)다.
String getTimeExtensionKey(String gameId, int extensionIndex) => '${gameId}_${extensionIndex + 1}';

/// [uid]가 대국 [gameId]에서 [cost]를 내는 움직임을 정한다(시간 연장, 대국 중 놓아보기). 무상부터 쓴다. 내역 열쇠는 [key]다.
/// 모자라면 [InsufficientCoinsException]을 던진다. 지갑은 가입할 때 만들므로 없으면 잔액이 없는 것으로 본다.
CoinPlan planGameItemSpend({
  required String uid,
  required CoinWallet? wallet,
  required CoinReason reason,
  required String gameId,
  required String key,
  required int cost,
  required DateTime now,
}) {
  if (wallet == null || wallet.balance < cost) {
    throw InsufficientCoinsException(uid);
  }
  final next = _spend(wallet, cost, now);
  final move = _createMove(
    uid,
    reason,
    gameId,
    key,
    next,
    next.freeCoins - wallet.freeCoins,
    next.paidCoins - wallet.paidCoins,
    now,
  );
  return CoinPlan(wallets: {uid: next}, moves: [move]);
}

/// 값을 받았지만 대국에 반영하지 못한 시간 연장 [extension]을 낸 그대로 돌려주는 움직임을 정한다.
CoinPlan planTimeExtensionRefund({
  required String uid,
  required CoinWallet wallet,
  required CoinTransaction extension,
  required String gameId,
  required String key,
  required DateTime now,
}) {
  final next = _apply(wallet, freeDelta: -extension.freeDelta, paidDelta: -extension.paidDelta, now: now);
  final move = _createMove(
    uid,
    CoinReason.timeExtensionRefund,
    gameId,
    key,
    next,
    -extension.freeDelta,
    -extension.paidDelta,
    now,
  );
  return CoinPlan(wallets: {uid: next}, moves: [move]);
}

/// [gameId]에서 두 대국자의 시간 연장 내역과 그 돌려주기 내역의 문서 ID. 연장 최대 횟수만큼이다.
List<String> getTimeExtensionTransactionIds(String gameId, ActiveGame game) {
  final players = game.meta.players;
  return [
    for (final uid in [players.cho.uid, players.han.uid])
      for (var index = 0; index < game.meta.timeControl.extensionLimit; index++) ...[
        getCoinTransactionId(CoinReason.timeExtension, uid, getTimeExtensionKey(gameId, index)),
        getCoinTransactionId(CoinReason.timeExtensionRefund, uid, getTimeExtensionKey(gameId, index)),
      ],
  ];
}

/// 끝난 대국의 참가비 돌려주기나 보상을 정한다(`docs/server.md`의 엽전).
///
/// 수가 하나도 없이 끝나면 대국이 성립하지 않은 것으로 보고 참가비를 낸 그대로(무상은 무상으로, 유상은 유상으로) 돌려주며 보상은
/// 없다. 끝낸 쪽이 누구든 같다. 그 밖에는 이긴 쪽과 진 쪽에게 보상을 무상으로 준다. 한 번만 반영되는 것은 부르는 쪽(`finalizeGame`)이
/// 기보 저장과 같은 트랜잭션에서 보장한다.
///
/// [extensionTransactions]는 [getTimeExtensionTransactionIds]의 내역이다. 값을 받았지만 대국에 반영되지 않은 시간 연장(값을 받은 뒤
/// 서버가 멈췄거나 그 사이 대국이 끝났다)은 여기서 낸 그대로 돌려준다.
CoinPlan planGameEnd({
  required String gameId,
  required ActiveGame game,
  required Map<String, CoinWallet?> wallets,
  required Map<String, CoinTransaction?> feeTransactions,
  required Map<String, CoinTransaction?> extensionTransactions,
  required AppConfig config,
  required DateTime now,
}) {
  final players = game.meta.players;
  final nextWallets = <String, CoinWallet>{};
  final moves = <CoinMove>[];
  final established = game.moves.isNotEmpty;
  for (final side in Side.values) {
    final uid = players.get(side).uid;
    var wallet = wallets[uid];
    if (wallet == null) {
      continue;
    }
    if (established) {
      final amount = side == game.state.result!.winner ? config.coinWinReward : config.coinLossReward;
      if (amount > 0) {
        wallet = _apply(wallet, freeDelta: amount, paidDelta: 0, now: now);
        nextWallets[uid] = wallet;
        moves.add(_createMove(uid, CoinReason.gameReward, gameId, gameId, wallet, amount, 0, now));
      }
    } else {
      final fee = feeTransactions[getCoinTransactionId(CoinReason.entryFee, uid, gameId)];
      if (fee != null) {
        wallet = _apply(wallet, freeDelta: -fee.freeDelta, paidDelta: -fee.paidDelta, now: now);
        nextWallets[uid] = wallet;
        moves.add(
          _createMove(uid, CoinReason.entryFeeRefund, gameId, gameId, wallet, -fee.freeDelta, -fee.paidDelta, now),
        );
      }
    }
    final applied = game.state.clock.get(side).extensionsUsed;
    for (var index = applied; index < game.meta.timeControl.extensionLimit; index++) {
      final key = getTimeExtensionKey(gameId, index);
      final extension = extensionTransactions[getCoinTransactionId(CoinReason.timeExtension, uid, key)];
      final refunded = extensionTransactions[getCoinTransactionId(CoinReason.timeExtensionRefund, uid, key)] != null;
      if (extension == null || refunded) {
        continue;
      }
      wallet = _apply(wallet!, freeDelta: -extension.freeDelta, paidDelta: -extension.paidDelta, now: now);
      nextWallets[uid] = wallet;
      moves.add(
        _createMove(
          uid,
          CoinReason.timeExtensionRefund,
          gameId,
          key,
          wallet,
          -extension.freeDelta,
          -extension.paidDelta,
          now,
        ),
      );
    }
  }
  return CoinPlan(wallets: nextWallets, moves: moves);
}

/// [cost]를 무상부터 낸 지갑.
CoinWallet _spend(CoinWallet wallet, int cost, DateTime now) {
  final fromFree = wallet.freeCoins < cost ? wallet.freeCoins : cost;
  return _apply(wallet, freeDelta: -fromFree, paidDelta: -(cost - fromFree), now: now);
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
  String key,
  CoinWallet after,
  int freeDelta,
  int paidDelta,
  DateTime now,
) {
  return CoinMove(
    uid: gameUid,
    transactionId: getCoinTransactionId(reason, gameUid, key),
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
