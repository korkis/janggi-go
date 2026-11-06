import '../firebase/firestore_client.dart';
import '../http/callable.dart';
import '../logging.dart';
import '../models/active_game.dart';
import '../models/coin.dart';
import '../models/game_enums.dart';
import '../repositories/archived_games_repository.dart';
import '../repositories/coin_transactions_repository.dart';
import '../repositories/coin_wallets_repository.dart';
import '../repositories/configs_repository.dart';
import '../repositories/player_states_repository.dart';
import 'coin_rules.dart';
import 'game_rules.dart';
import 'game_service.dart';

/// 대국 중에 엽전을 내고 쓰는 것. 시간 연장과 놓아보기(`docs/server.md`의 시간 연장과 놓아보기).
class GameItemService {
  /// Firestore 트랜잭션을 시작할 때만 쓴다. 문서 읽기·쓰기는 repository가 한다.
  final FirestoreClient firestore;
  final GameService gameService;
  final ArchivedGamesRepository archivedGames;
  final PlayerStatesRepository playerStates;
  final ConfigsRepository configs;
  final CoinWalletsRepository coinWallets;
  final CoinTransactionsRepository coinTransactions;
  final GameLogger logger;

  const GameItemService({
    required this.firestore,
    required this.gameService,
    required this.archivedGames,
    required this.playerStates,
    required this.configs,
    required this.coinWallets,
    required this.coinTransactions,
    required this.logger,
  });

  /// [uid]가 [extensionIndex]번째 시간 연장을 쓴다. [coinCost]는 앱이 보여준 값이다.
  ///
  /// 엽전은 Firestore, 시계는 RTDB에 있어 한 트랜잭션으로 묶을 수 없다. 값을 먼저 받고 시계를 바꾼다. 내역 문서 ID에 [extensionIndex]가
  /// 들어 있으므로 같은 요청이 몇 번 와도 한 번만 받고, 시계도 번호로 확인하므로 한 번만 바뀐다. 시계를 바꾸기 전에 멈췄으면 같은 요청을
  /// 다시 보내 이어 가거나, 대국이 끝날 때 `finalizeGame`이 돌려준다. 값을 받은 뒤 대국이 먼저 끝났으면 바로 돌려준다.
  Future<void> useTimeExtension(
    String gameId, {
    required String uid,
    required int extensionIndex,
    required int coinCost,
    required DateTime now,
  }) async {
    final game = await gameService.updateGame(gameId, now: now);
    final side = requirePlayerSide(game, uid);
    if (isTimeExtensionApplied(game, side, extensionIndex)) {
      return;
    }
    checkCanExtendTime(game, side, extensionIndex);
    final key = getTimeExtensionKey(gameId, extensionIndex);
    await _chargeTimeExtension(gameId, uid: uid, key: key, coinCost: coinCost, now: now);
    try {
      await gameService.updateGame(
        gameId,
        now: now,
        action: (current) => extendTime(current, side, extensionIndex, now.millisecondsSinceEpoch),
      );
    } on CallableException {
      await _refundTimeExtension(gameId, uid: uid, key: key, now: now);
      rethrow;
    }
    logger.info('useTimeExtension 성공', {'gameId': gameId, 'uid': uid, 'extensionIndex': extensionIndex});
  }

  /// [uid]가 대국 중 놓아보기 값을 낸다. [coinCost]는 앱이 보여준 값이다.
  ///
  /// 값과 `player_states.gamePracticeGameId`를 한 트랜잭션으로 쓴다. 이미 냈으면 다시 받지 않는다. 상대가 볼 수 있는 RTDB에는 아무것도
  /// 쓰지 않는다.
  Future<void> useGamePractice(
    String gameId, {
    required String uid,
    required int coinCost,
    required DateTime now,
  }) async {
    final game = await gameService.updateGame(gameId, now: now);
    requirePlayerSide(game, uid);
    _checkPlaying(game);
    final appConfig = await configs.getAppConfig();
    final transactionId = getCoinTransactionId(CoinReason.gamePractice, uid, gameId);
    await firestore.runTransaction((transaction) async {
      final (archived, existing, wallets) = await (
        archivedGames.hasArchivedGameInTransaction(transaction, gameId),
        coinTransactions.getTransactionsInTransaction(transaction, [transactionId]),
        coinWallets.getWalletsInTransaction(transaction, [uid]),
      ).wait;
      if (archived) {
        throw const CallableException.failedPrecondition(GameErrorCode.gameOver, '이미 끝난 대국입니다');
      }
      if (existing[transactionId] == null) {
        if (!appConfig.gamePracticeEnabled) {
          throw const CallableException.failedPrecondition(GameErrorCode.featureDisabled, '대국 중 놓아보기를 멈췄습니다');
        }
        if (coinCost != appConfig.coinGamePracticeCost) {
          throw const CallableException.failedPrecondition(GameErrorCode.coinPriceChanged, '값이 바뀌었습니다');
        }
        final plan = planGameItemSpend(
          uid: uid,
          wallet: wallets[uid],
          reason: CoinReason.gamePractice,
          gameId: gameId,
          key: gameId,
          cost: coinCost,
          now: now,
        );
        gameService.writeCoinPlanInTransaction(transaction, plan);
      }
      playerStates.updateGamePracticeInTransaction(transaction, uid, gameId: gameId, now: now);
    });
    logger.info('useGamePractice 성공', {'gameId': gameId, 'uid': uid});
  }

  /// 시간 연장 값을 받는다. 같은 [key]의 내역이 있으면 이미 받은 것이므로 값과 스위치를 보지 않고 넘어간다.
  ///
  /// 기보가 있으면 받지 않는다. `finalizeGame`도 같은 트랜잭션 안에서 내역을 읽으므로, 받은 값은 반드시 그 확인에 걸려 돌려받는다.
  Future<void> _chargeTimeExtension(
    String gameId, {
    required String uid,
    required String key,
    required int coinCost,
    required DateTime now,
  }) async {
    final appConfig = await configs.getAppConfig();
    final transactionId = getCoinTransactionId(CoinReason.timeExtension, uid, key);
    await firestore.runTransaction((transaction) async {
      final (archived, existing, wallets) = await (
        archivedGames.hasArchivedGameInTransaction(transaction, gameId),
        coinTransactions.getTransactionsInTransaction(transaction, [transactionId]),
        coinWallets.getWalletsInTransaction(transaction, [uid]),
      ).wait;
      if (archived) {
        throw const CallableException.failedPrecondition(GameErrorCode.gameOver, '이미 끝난 대국입니다');
      }
      if (existing[transactionId] != null) {
        return;
      }
      if (!appConfig.timeExtensionEnabled) {
        throw const CallableException.failedPrecondition(GameErrorCode.featureDisabled, '시간 연장을 멈췄습니다');
      }
      if (coinCost != appConfig.coinTimeExtensionCost) {
        throw const CallableException.failedPrecondition(GameErrorCode.coinPriceChanged, '값이 바뀌었습니다');
      }
      final plan = planGameItemSpend(
        uid: uid,
        wallet: wallets[uid],
        reason: CoinReason.timeExtension,
        gameId: gameId,
        key: key,
        cost: coinCost,
        now: now,
      );
      gameService.writeCoinPlanInTransaction(transaction, plan);
    });
  }

  /// 대국에 반영하지 못한 시간 연장 값을 돌려준다. 이미 돌려줬으면(`finalizeGame`) 아무것도 하지 않는다.
  Future<void> _refundTimeExtension(
    String gameId, {
    required String uid,
    required String key,
    required DateTime now,
  }) async {
    final transactionId = getCoinTransactionId(CoinReason.timeExtension, uid, key);
    final refundId = getCoinTransactionId(CoinReason.timeExtensionRefund, uid, key);
    await firestore.runTransaction((transaction) async {
      final (existing, wallets) = await (
        coinTransactions.getTransactionsInTransaction(transaction, [transactionId, refundId]),
        coinWallets.getWalletsInTransaction(transaction, [uid]),
      ).wait;
      final extension = existing[transactionId];
      final wallet = wallets[uid];
      if (extension == null || existing[refundId] != null || wallet == null) {
        return;
      }
      final plan = planTimeExtensionRefund(
        uid: uid,
        wallet: wallet,
        extension: extension,
        gameId: gameId,
        key: key,
        now: now,
      );
      gameService.writeCoinPlanInTransaction(transaction, plan);
    });
    logger.warning('시간 연장 값을 돌려줬습니다', {'gameId': gameId, 'uid': uid, 'key': key});
  }

  /// 대국이 진행 중인지 확인한다. 상차림 중이거나 끝났으면 [CallableException]을 던진다.
  static void _checkPlaying(ActiveGame game) {
    if (game.state.phase == GamePhase.finished) {
      throw const CallableException.failedPrecondition(GameErrorCode.gameOver, '이미 끝난 대국입니다');
    }
    if (game.state.phase != GamePhase.playing) {
      throw const CallableException.failedPrecondition(GameErrorCode.notYourTurn, '아직 대국이 시작되지 않았습니다');
    }
  }
}
