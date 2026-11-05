part of 'position.dart';

/// 대국이 끝난 사유.
enum GameEndReason {
  /// 장군을 받은 쪽이 둘 수 있는 수가 없다.
  checkmate,
  resignation,

  /// 시간을 모두 썼다. 시계는 서버가 판단하고 엔진은 결과만 기록한다.
  timeout,

  /// 한 대국 동안 연결이 끊겨 있던 시간의 합계가 허용 시간을 넘었다. 대국 서버가 판단하고 엔진은 결과만 기록한다.
  disconnect,

  /// 양쪽이 연속으로 한수쉼을 해서 점수로 판정했다.
  consecutivePasses,

  /// 총 [Game.maxMoves]수에 도달해서 점수로 판정했다.
  moveLimit,

  /// 장군이 아닌데 수도 한수쉼도 둘 수 없어서 점수로 판정했다.
  noLegalMoves;

  /// 점수승인지 여부. 아니면 완승(외통, 기권, 시간패, 접속 끊김)이다.
  bool get isScoreJudgment => this == consecutivePasses || this == moveLimit || this == noLegalMoves;
}

/// 기물 규칙으로는 갈 수 있지만 둘 수 없는 이유.
enum MoveRejection {
  /// 장군을 받은 상태에서 장군을 막지 못한다.
  mustStopCheck,

  /// 두면 내 궁이 장군을 받게 된다.
  exposesGeneral,

  /// 반복수 제한에 걸린다.
  repetition,
}

/// 대국 결과. 점수는 끝난 국면의 점수이며 한의 덤이 들어 있다.
final class GameResult {
  final Side winner;
  final GameEndReason reason;
  final double choScore;
  final double hanScore;

  const GameResult({required this.winner, required this.reason, required this.choScore, required this.hanScore});

  factory GameResult._fromPosition(Position position, Side winner, GameEndReason reason) => GameResult(
        winner: winner,
        reason: reason,
        choScore: position.score(Side.cho),
        hanScore: position.score(Side.han),
      );

  /// 점수 판정. 덤 때문에 동점은 나오지 않는다.
  factory GameResult._byScore(Position position, GameEndReason reason) {
    final winner = position.score(Side.cho) > position.score(Side.han) ? Side.cho : Side.han;
    return GameResult._fromPosition(position, winner, reason);
  }

  @override
  bool operator ==(Object other) =>
      other is GameResult &&
      other.winner == winner &&
      other.reason == reason &&
      other.choScore == choScore &&
      other.hanScore == hanScore;

  @override
  int get hashCode => Object.hash(winner, reason, choScore, hanScore);

  @override
  String toString() => 'GameResult(${winner.name}, ${reason.name}, $choScore:$hanScore)';
}

/// 한 대국. 처음 국면과 둔 수를 가지고 반복수, 한수쉼, 수 제한, 승패를 판정한다.
///
/// 불변 객체이며 [play], [resign], [timeout], [disconnect]는 새 객체를 반환한다.
final class Game {
  /// 초와 한의 수를 합산한 최대 수. 한수쉼도 1수로 센다.
  static const maxMoves = 200;

  /// 같은 국면이 이 횟수째 나오게 하는 수부터 금지수다.
  static const repetitionLimit = 3;

  final Position initialPosition;

  /// 둔 수. 한수쉼은 [Move.pass]다.
  final List<Move> moves;

  /// 끝났으면 결과, 진행 중이면 null이다.
  final GameResult? result;

  /// 처음 국면부터 지금까지의 국면. `positions[i]`에서 `moves[i]`를 두면 `positions[i + 1]`이다.
  final List<Position> positions;

  Game._(this.initialPosition, List<Move> moves, List<Position> positions, this.result)
      : moves = List.unmodifiable(moves),
        positions = List.unmodifiable(positions);

  /// [initialPosition]에서 대국을 시작한다.
  factory Game.start(Position initialPosition) {
    final game = Game._(initialPosition, const [], [initialPosition], null);
    return game._withResult(game._resolveEndAfterMove());
  }

  /// [initialPosition]에서 [moves]를 차례로 둔 대국. 둘 수 없는 수가 있으면 [ArgumentError]를 던진다.
  factory Game.replay(Position initialPosition, Iterable<Move> moves) {
    var game = Game.start(initialPosition);
    for (final move in moves) {
      game = game.play(move);
    }
    return game;
  }

  Position get position => positions.last;

  bool get isOver => result != null;

  /// 지금 차례가 둘 수 있는 수. 반복수 제한에 걸리는 수는 빠진다. 끝난 대국이면 빈 목록이다.
  List<Move> legalMoves() {
    if (isOver) {
      return const [];
    }
    return [
      for (final move in position.legalMoves())
        if (!_isRepetitionForbidden(move)) move,
    ];
  }

  bool isLegal(Move move) => !isOver && position.isLegal(move) && !_isRepetitionForbidden(move);

  /// [move]를 둘 수 없는 이유. 둘 수 있는 수, 기물 규칙으로도 못 가는 수, 끝난 대국이면 null이다.
  MoveRejection? getMoveRejection(Move move) {
    if (isOver || isLegal(move)) {
      return null;
    }
    if (position.isLegal(move)) {
      return MoveRejection.repetition;
    }
    if (!generatePseudoMoves(position.board, position.turn).contains(move)) {
      return null;
    }
    return position.isInCheck(position.turn) ? MoveRejection.mustStopCheck : MoveRejection.exposesGeneral;
  }

  /// [square]의 기물을 골라도 소용없는 이유. 장군을 받은 상태에서 차례인 쪽 기물이 갈 곳이 하나도 없을 때만 있고, 아니면 null이다.
  MoveRejection? getSelectionRejection(Square square) {
    if (isOver || position.pieceAt(square)?.side != position.turn || !position.isInCheck(position.turn)) {
      return null;
    }
    final movable = legalMoves().any((move) => move.from == square);
    return movable ? null : MoveRejection.mustStopCheck;
  }

  /// [move]를 둔 대국을 반환한다. 끝난 대국이거나 둘 수 없는 수면 [ArgumentError]를 던진다.
  Game play(Move move) {
    if (isOver) {
      throw ArgumentError.value(move.toString(), 'move', '이미 끝난 대국이다');
    }
    if (!position.isLegal(move)) {
      throw ArgumentError.value(move.toString(), 'move', '둘 수 없는 수다 (${position.fen})');
    }
    if (_isRepetitionForbidden(move)) {
      throw ArgumentError.value(move.toString(), 'move', '반복수 제한에 걸리는 수다 (${position.fen})');
    }
    final next = Game._(initialPosition, [...moves, move], [...positions, position._playUnchecked(move)], null);
    return next._withResult(next._resolveEndAfterMove());
  }

  /// [side]가 기권한 대국을 반환한다.
  Game resign(Side side) => _endBy(side.opponent, GameEndReason.resignation);

  /// [side]가 시간을 모두 쓴 대국을 반환한다.
  Game timeout(Side side) => _endBy(side.opponent, GameEndReason.timeout);

  /// [side]가 접속 끊김 허용 시간을 넘긴 대국을 반환한다.
  Game disconnect(Side side) => _endBy(side.opponent, GameEndReason.disconnect);

  Game _endBy(Side winner, GameEndReason reason) {
    if (isOver) {
      throw StateError('이미 끝난 대국이다');
    }
    return _withResult(GameResult._fromPosition(position, winner, reason));
  }

  Game _withResult(GameResult? result) {
    if (result == null) {
      return this;
    }
    return Game._(initialPosition, moves, positions, result);
  }

  /// 마지막 수를 둔 뒤 대국이 끝났는지 판정한다.
  ///
  /// 외통을 먼저 보고, 그다음 양쪽 연속 한수쉼, 둘 수 있는 수 없음, 총 수 제한 순서로 본다.
  GameResult? _resolveEndAfterMove() {
    final current = position;
    final noMoves = legalMoves().isEmpty;
    final inCheck = current.isInCheck(current.turn);
    if (noMoves && inCheck) {
      return GameResult._fromPosition(current, current.turn.opponent, GameEndReason.checkmate);
    }
    if (moves.length >= 2 && moves[moves.length - 1].isPass && moves[moves.length - 2].isPass) {
      return GameResult._byScore(current, GameEndReason.consecutivePasses);
    }
    if (noMoves) {
      return GameResult._byScore(current, GameEndReason.noLegalMoves);
    }
    if (moves.length >= maxMoves) {
      return GameResult._byScore(current, GameEndReason.moveLimit);
    }
    return null;
  }

  /// [move]가 반복수 제한에 걸리는지 판단한다. [move]는 [position]에서 둘 수 있는 수여야 한다.
  ///
  /// 같은 국면이 [repetitionLimit]번째로 나오게 하는 수는 금지수다. 다만 그 국면이 직전에 나온 뒤로
  /// 상대가 새 공격수만 두고 이 수를 포함한 내 수가 모두 공격 없는 피하는 수면, 나는 피하는 쪽이므로
  /// 제한을 받지 않는다.
  bool _isRepetitionForbidden(Move move) {
    final current = position;
    final next = current._playUnchecked(move);
    final occurrences = positions.where((position) => position == next).length;
    if (occurrences + 1 < repetitionLimit) {
      return false;
    }
    final mover = current.turn;
    final cycleStart = positions.lastIndexOf(next);
    for (var i = cycleStart; i <= moves.length; i++) {
      final before = positions[i];
      final cycleMove = i < moves.length ? moves[i] : move;
      final after = i < moves.length ? positions[i + 1] : next;
      if (before.turn == mover) {
        if (!_isEvasion(before, cycleMove, after) || _isNewAttack(before, cycleMove, after)) {
          return true;
        }
      } else if (!_isNewAttack(before, cycleMove, after)) {
        return true;
      }
    }
    return false;
  }
}

/// 새 공격수: 상대 궁에 장군을 걸거나, 두기 전에는 잡을 수 없던 상대 기물을 잡을 수 있게 되는 수.
bool _isNewAttack(Position before, Move move, Position after) {
  if (move.isPass) {
    return false;
  }
  final mover = before.turn;
  if (after.isInCheck(mover.opponent)) {
    return true;
  }
  // 두는 쪽의 수로 상대 기물은 움직이지 않으므로 같은 칸이면 같은 기물이다.
  final capturableBefore = capturableSquares(before.board, mover);
  return capturableSquares(after.board, mover).any((square) => !capturableBefore.contains(square));
}

/// 피하는 수: 장군을 벗어나거나, 공격받던 기물이 더 이상 잡히지 않게 되는 수.
bool _isEvasion(Position before, Move move, Position after) {
  if (move.isPass) {
    return false;
  }
  final mover = before.turn;
  if (before.isInCheck(mover)) {
    return true;
  }
  final capturableAfter = capturableSquares(after.board, mover.opponent);
  for (final square in capturableSquares(before.board, mover.opponent)) {
    // 공격받던 기물이 이 수로 움직였으면 옮겨 간 칸에서 다시 본다.
    final squareAfter = square == move.from ? move.to! : square;
    if (!capturableAfter.contains(squareAfter)) {
      return true;
    }
  }
  return false;
}
