import 'package:janggi_core/janggi_core.dart';

/// 대국 서버가 RTDB `games_active/{gameId}`에 쓰는 모양의 대국. [cho]와 [han]은 대국자 uid다.
///
/// 시각은 [startsAt] 기준이고, 처음 국면은 양쪽 모두 마상마상이다. 기본은 급수에 반영하지 않는 신청 대국이다.
Map<String, dynamic> buildGameJson({
  String cho = 'me',
  String han = 'opp',
  String phase = 'setup',
  String setupTurn = 'han',
  String? hanFormation,
  String? choFormation,
  int startsAt = 1000000,
  String? turn,
  int? turnStartedAt,
  Map<String, dynamic>? clock,
  List<String> moves = const [],
  Map<String, dynamic>? disconnect,
  Map<String, dynamic>? result,
  int? endedAt,
  String mode = 'challenge',
  bool rated = false,
  Map<String, dynamic>? rematch,
  String? roomId,
}) {
  final playing = phase != 'setup';
  final sideClock = {'baseMs': 300000, 'periods': 3, 'extensionsUsed': 0};
  return {
    'meta': {
      'mode': mode,
      'rated': rated,
      'roomId': ?roomId,
      'listed': true,
      'players': {
        'cho': {'uid': cho, 'nickname': '초$cho', 'rankLevel': 1},
        'han': {'uid': han, 'nickname': '한$han', 'rankLevel': 19},
      },
      'timeControl': {
        'baseMs': 300000,
        'periodMs': 30000,
        'periods': 3,
        'setupMs': 20000,
        'extensionPeriods': 2,
        'extensionLimit': 2,
      },
      'disconnectLimitMs': 30000,
      'rematchCount': 0,
      'createdAt': startsAt - 3000,
    },
    'state': {
      'version': 1,
      'phase': phase,
      'setup': {
        'turn': setupTurn,
        'startsAt': startsAt,
        'deadlineAt': startsAt + 20000,
        'han': ?hanFormation,
        'cho': ?choFormation,
      },
      if (playing)
        'initialFen': createInitialPosition(
          cho: Formation.horseElephantHorseElephant,
          han: Formation.horseElephantHorseElephant,
        ).fen,
      'turn': ?turn,
      'turnStartedAt': ?turnStartedAt,
      'clock': clock ?? {'cho': sideClock, 'han': sideClock},
      'disconnect':
          disconnect ??
          {
            'cho': {'usedMs': 0},
            'han': {'usedMs': 0},
          },
      'result': ?result,
      'endedAt': ?endedAt,
    },
    'rematch': ?rematch,
    if (moves.isNotEmpty)
      'moves': [
        for (final move in moves) {'m': move, 'spentMs': 1000},
      ],
  };
}
