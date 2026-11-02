import 'dart:math';

import 'package:janggi_core/janggi_core.dart';

import '../models/active_game.dart';
import '../models/game_enums.dart';

// 대국 시계 표시. 서버가 기준이고 앱은 같은 식(`docs/server.md`의 시계)으로 지금 남은 시간을 어림해 보여주기만 한다.

/// 한 진영 시계의 지금 값.
class ClockDisplay {
  /// 남은 기본 시간.
  final Duration base;

  /// 남은 초읽기 횟수.
  final int periods;

  /// 초읽기 중이면 이번 초읽기의 남은 시간. 기본 시간이 남았으면 null.
  final Duration? period;

  const ClockDisplay({required this.base, required this.periods, required this.period});

  /// 초읽기 중인지 여부.
  bool get inByoyomi => period != null;
}

/// [side]의 시계를 서버 시각 [nowMs]에 맞춰 어림한다. 차례인 쪽만 흐르고, 끝난 대국은 끝난 시각에 멈춘다.
ClockDisplay getClockDisplay(ActiveGame game, Side side, int nowMs) {
  final state = game.state;
  final clock = side == Side.cho ? state.clock.cho : state.clock.han;
  final periodMs = game.meta.timeControl.periodMs;
  var spentMs = 0;
  final turnStartedAt = state.turnStartedAt;
  if (state.phase != GamePhase.setup && state.turn == side && turnStartedAt != null) {
    spentMs = max(0, min(nowMs, state.endedAt ?? nowMs) - turnStartedAt);
  }
  if (spentMs < clock.baseMs) {
    return ClockDisplay(
      base: Duration(milliseconds: clock.baseMs - spentMs),
      periods: clock.periods,
      period: null,
    );
  }
  final overMs = spentMs - clock.baseMs;
  final periods = clock.periods - overMs ~/ periodMs;
  if (periods < 0) {
    return const ClockDisplay(base: Duration.zero, periods: 0, period: Duration.zero);
  }
  return ClockDisplay(
    base: Duration.zero,
    periods: periods,
    period: Duration(milliseconds: periodMs - overMs % periodMs),
  );
}

/// 지금 상차림을 고르는 쪽의 남은 시간. 상대 찾음 화면 동안은 상차림 시간 전체다. 상차림 중이 아니면 null.
Duration? getSetupRemaining(ActiveGame game, int nowMs) {
  final state = game.state;
  if (state.phase != GamePhase.setup) {
    return null;
  }
  final setupMs = game.meta.timeControl.setupMs;
  final remainingMs = state.setup.deadlineAt - max(nowMs, state.setup.startsAt);
  return Duration(milliseconds: remainingMs.clamp(0, setupMs).toInt());
}

/// 시계 글자 "4:05". 초는 올림해 0초가 되는 순간에만 0을 보여준다.
String formatClock(Duration duration) {
  final totalSeconds = (duration.inMilliseconds / 1000).ceil();
  final seconds = totalSeconds % 60;
  return '${totalSeconds ~/ 60}:${seconds.toString().padLeft(2, '0')}';
}

/// 지금 차례인 쪽의 시간패 시각(ms). 서버와 같은 식이다. 대국 중이 아니면 null.
int? getTimeoutAt(ActiveGame game) {
  final state = game.state;
  final turn = state.turn;
  final turnStartedAt = state.turnStartedAt;
  if (state.phase != GamePhase.playing || turn == null || turnStartedAt == null) {
    return null;
  }
  final clock = state.clock.get(turn);
  return turnStartedAt + clock.baseMs + (clock.periods + 1) * game.meta.timeControl.periodMs;
}

/// [side]가 지금 끊겨 있으면 이번 대국에서 남은 끊김 허용 시간. 대국을 만들 때 정한 `meta.disconnectLimitMs`
/// (`configs/app.disconnectLimitSeconds`)에서 지금까지 끊긴 시간을 뺀다. 끊겨 있지 않거나 끝난 대국이면 null.
Duration? getDisconnectRemaining(ActiveGame game, Side side, int nowMs) {
  final disconnect = game.state.disconnect.get(side);
  final since = disconnect.since;
  if (since == null || game.state.phase == GamePhase.finished) {
    return null;
  }
  final limitMs = game.meta.disconnectLimitMs;
  final remainingMs = limitMs - disconnect.usedMs - max(0, nowMs - since);
  return Duration(milliseconds: remainingMs.clamp(0, limitMs).toInt());
}
