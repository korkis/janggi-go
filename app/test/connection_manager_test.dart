import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/player_state.dart';

import 'fakes.dart';

PlayerState _playerState(String? gameId) {
  return PlayerState(
    roomId: null,
    gameId: gameId,
    lastGameId: null,
    outgoingChallengeId: null,
    incomingChallengeId: null,
    setupDraft: null,
    lastRankChange: null,
    quickQueueJoinedAt: null,
    updatedAt: DateTime.utc(2026, 11, 2),
  );
}

void main() {
  // 시간과 앱 생명주기를 테스트가 정하도록 testWidgets로 돌린다.
  testWidgets('대국이 있는 동안 바로 그리고 heartbeatSeconds마다 lastSeenAt을 쓰고, 대국이 풀리면 멈춘다', (tester) async {
    final fakes = setUpFakeApp();
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    await tester.pump();
    expect(fakes.connections.writes, ['create me true']);
    expect(managers.connectionManager.active, isTrue);

    fakes.playerStates.emit('me', _playerState('g1'));
    await tester.pump();
    expect(fakes.connections.writes, ['create me true', 'lastSeenAt me c1']);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(fakes.connections.writes.where((write) => write == 'lastSeenAt me c1'), hasLength(3));

    fakes.playerStates.emit('me', _playerState(null));
    await tester.pump(const Duration(seconds: 10));
    expect(fakes.connections.writes.where((write) => write == 'lastSeenAt me c1'), hasLength(3));
  });

  testWidgets('다른 앱으로 넘어가면 foreground false를 쓰고, 돌아오면 activeSince를 쓰고 checkGame을 부른다', (tester) async {
    final fakes = setUpFakeApp();
    managers.connectionManager.observeAppLifecycle();
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    fakes.playerStates.emit('me', _playerState('g1'));
    await tester.pump();
    fakes.connections.writes.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 10));
    expect(fakes.connections.writes, ['background me c1']);
    expect(managers.connectionManager.active, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(fakes.connections.writes, ['background me c1', 'foreground me c1', 'lastSeenAt me c1']);
    expect(fakes.games.calls, ['checkGame g1']);

    fakes.playerStates.emit('me', _playerState(null));
    managers.connectionManager.dispose();
  });

  testWidgets('RTDB 연결이 끊겼다 이어지면 새 연결을 만들고 진행 중 대국의 checkGame을 부른다', (tester) async {
    final fakes = setUpFakeApp();
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    fakes.playerStates.emit('me', _playerState('g1'));
    await tester.pump();
    expect(managers.connectionManager.connected, isTrue);

    fakes.connections.setConnected(false);
    await tester.pump();
    expect(managers.connectionManager.connected, isFalse);
    expect(managers.connectionManager.active, isFalse);
    fakes.connections.writes.clear();
    await tester.pump(const Duration(seconds: 10));
    expect(fakes.connections.writes, isEmpty);

    fakes.connections.setConnected(true);
    await tester.pump();
    expect(fakes.connections.writes, ['create me true', 'lastSeenAt me c2']);
    expect(fakes.games.calls, ['checkGame g1']);

    fakes.playerStates.emit('me', _playerState(null));
  });
}
