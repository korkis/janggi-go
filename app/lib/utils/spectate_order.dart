import 'dart:math';

import '../models/spectate_list_entry.dart';

/// 이 수보다 적게 둔 대국은 관전 목록 뒤로 보낸다(`docs/screens.md`의 관전 목록).
const spectateMinMoves = 10;

/// 관전 목록을 인기 있을 만한 대국 순서로 놓는다(`docs/screens.md`의 관전 목록).
///
/// 10수가 안 된 대국은 뒤로 보내고, 그 안에서 관전자 많은 순, 같으면 급수 높은 순이다. 급수는 두 대국자 중 높은 급수를 먼저
/// 비교하고, 같으면 낮은 쪽의 급수를 비교한다. 나머지가 모두 같으면 늦게 시작한 대국을 먼저 놓는다.
List<({String gameId, SpectateListEntry entry})> sortSpectateEntries(
  Iterable<({String gameId, SpectateListEntry entry})> entries,
) {
  return [...entries]..sort(_compare);
}

int _compare(({String gameId, SpectateListEntry entry}) a, ({String gameId, SpectateListEntry entry}) b) {
  final left = a.entry;
  final right = b.entry;
  final early = (left.moveCount < spectateMinMoves ? 1 : 0) - (right.moveCount < spectateMinMoves ? 1 : 0);
  if (early != 0) {
    return early;
  }
  final spectators = right.spectatorCount - left.spectatorCount;
  if (spectators != 0) {
    return spectators;
  }
  final higher = _getHigherRank(right) - _getHigherRank(left);
  if (higher != 0) {
    return higher;
  }
  final lower = _getLowerRank(right) - _getLowerRank(left);
  if (lower != 0) {
    return lower;
  }
  final started = right.startedAt - left.startedAt;
  if (started != 0) {
    return started;
  }
  return a.gameId.compareTo(b.gameId);
}

int _getHigherRank(SpectateListEntry entry) => max(entry.players.cho.rankLevel, entry.players.han.rankLevel);

int _getLowerRank(SpectateListEntry entry) => min(entry.players.cho.rankLevel, entry.players.han.rankLevel);
