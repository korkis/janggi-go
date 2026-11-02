import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_core/janggi_core.dart';
import 'package:janggigo/models/active_game.dart';
import 'package:janggigo/utils/game_clock.dart';

import 'online_game_fixtures.dart';

void main() {
  const startedAt = 2000000;

  ActiveGame playing({int baseMs = 300000, int periods = 3, int? endedAt}) {
    final clock = {'baseMs': baseMs, 'periods': periods, 'extensionsUsed': 0};
    return ActiveGame.fromJson(
      buildGameJson(
        phase: endedAt == null ? 'playing' : 'finished',
        turn: 'cho',
        turnStartedAt: startedAt,
        clock: {
          'cho': clock,
          'han': {'baseMs': 120000, 'periods': 2, 'extensionsUsed': 0},
        },
        endedAt: endedAt,
      ),
    );
  }

  test('차례인 쪽만 시계가 흐른다', () {
    final game = playing();
    expect(getClockDisplay(game, Side.cho, startedAt + 12000).base, const Duration(seconds: 288));
    expect(getClockDisplay(game, Side.han, startedAt + 12000).base, const Duration(seconds: 120));
  });

  test('기본 시간을 다 쓰면 초읽기를 보여준다', () {
    final game = playing(baseMs: 10000);
    final clock = getClockDisplay(game, Side.cho, startedAt + 10000 + 45000);
    expect(clock.inByoyomi, isTrue);
    expect(clock.periods, 2);
    expect(clock.period, const Duration(seconds: 15));
  });

  test('초읽기를 모두 넘기면 0에 멈춘다', () {
    final clock = getClockDisplay(playing(baseMs: 0, periods: 0), Side.cho, startedAt + 99000);
    expect(clock.periods, 0);
    expect(clock.period, Duration.zero);
  });

  test('끝난 대국은 끝난 시각에 멈춘다', () {
    final game = playing(endedAt: startedAt + 5000);
    expect(getClockDisplay(game, Side.cho, startedAt + 60000).base, const Duration(seconds: 295));
  });

  test('상차림 남은 시간은 상대 찾음 화면 동안 20초다', () {
    final game = ActiveGame.fromJson(buildGameJson(startsAt: 5000000));
    expect(getSetupRemaining(game, 4999000), const Duration(seconds: 20));
    expect(getSetupRemaining(game, 5007500), const Duration(milliseconds: 12500));
    expect(getSetupRemaining(game, 5030000), Duration.zero);
  });

  test('시간패 시각은 서버와 같은 식이다', () {
    expect(getTimeoutAt(playing(baseMs: 10000, periods: 2)), startedAt + 10000 + 3 * 30000);
    expect(getTimeoutAt(playing(endedAt: startedAt + 5000)), isNull);
  });

  test('끊겨 있는 동안 남은 끊김 허용 시간은 대국을 만들 때의 한도에서 지금까지 끊긴 시간을 뺀다', () {
    final game = ActiveGame.fromJson(
      buildGameJson(
        phase: 'playing',
        turn: 'cho',
        turnStartedAt: startedAt,
        disconnect: {
          'cho': {'usedMs': 0},
          'han': {'usedMs': 8000, 'since': startedAt},
        },
      ),
    );
    expect(getDisconnectRemaining(game, Side.cho, startedAt + 5000), isNull);
    expect(getDisconnectRemaining(game, Side.han, startedAt + 5000), const Duration(seconds: 17));
    expect(getDisconnectRemaining(game, Side.han, startedAt + 60000), Duration.zero);
  });

  test('시계 글자는 초를 올림한다', () {
    expect(formatClock(const Duration(milliseconds: 299001)), '5:00');
    expect(formatClock(const Duration(seconds: 65)), '1:05');
    expect(formatClock(Duration.zero), '0:00');
  });
}
