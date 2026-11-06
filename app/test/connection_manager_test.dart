import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/managers/connection_manager.dart';
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
    gamePracticeGameId: null,
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

  testWidgets('로그인한 동안 내 connections를 들어 RTDB 연결을 유지하고, 로그아웃하면 그만 듣는다', (tester) async {
    final fakes = setUpFakeApp();
    expect(fakes.connections.isWatchingConnections('me'), isFalse);
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    await tester.pump();
    expect(fakes.connections.isWatchingConnections('me'), isTrue);

    await fakes.auth.signOut();
    await tester.pump();
    expect(fakes.connections.isWatchingConnections('me'), isFalse);
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

  testWidgets('웹은 탭이 숨겨져도 foreground를 바꾸지 않고 tabHidden만 쓰며 heartbeat를 이어 간다', (tester) async {
    final fakes = setUpFakeApp();
    // 기본 ConnectionManager는 웹이 아니므로 멈추고 웹으로 하나 만든다.
    managers.connectionManager.dispose();
    final connectionManager = ConnectionManager(
      authManager: managers.authManager,
      playerStateManager: managers.playerStateManager,
      web: true,
    );
    connectionManager.observeAppLifecycle();
    await fakes.auth.signInWithEmail(email: 'me', password: 'password');
    fakes.playerStates.emit('me', _playerState('g1'));
    await tester.pump();
    expect(fakes.connections.writes, ['create me true tabHidden false', 'lastSeenAt me c1']);
    fakes.connections.writes.clear();
    fakes.games.calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(fakes.connections.writes, ['tabHidden me c1']);
    expect(connectionManager.foreground, isFalse);
    expect(connectionManager.active, isTrue);
    await tester.pump(const Duration(seconds: 10));
    expect(fakes.connections.writes.where((write) => write == 'lastSeenAt me c1'), hasLength(2));

    // 숨겨진 동안 RTDB에 다시 연결되면 숨겨진 채로 연결을 만든다.
    fakes.connections.setConnected(false);
    await tester.pump();
    fakes.connections.setConnected(true);
    await tester.pump();
    expect(fakes.connections.writes, contains('create me true tabHidden true'));
    fakes.connections.writes.clear();
    fakes.games.calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(fakes.connections.writes, ['tabVisible me c2']);
    expect(fakes.games.calls, ['checkGame g1']);

    fakes.playerStates.emit('me', _playerState(null));
    connectionManager.dispose();
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
