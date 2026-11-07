import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/active_game.dart';
import 'package:janggigo/models/game_enums.dart';
import 'package:janggigo/models/inventory.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/game_screen.dart';
import 'package:janggigo/screens/store_screen.dart';
import 'package:janggigo/theme/app_theme.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:janggigo/widgets/board/board_view.dart';
import 'package:janggigo/widgets/piece_icon.dart';

import 'fakes.dart';
import 'online_game_fixtures.dart';

void _usePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3600);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.localesTestValue = const [Locale('ko')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

Future<void> _pumpFor(WidgetTester tester) async {
  for (var elapsed = 0; elapsed < 10; elapsed++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<FakeApp> _signIn() async {
  final fakes = setUpFakeApp();
  fakes.users.profiles['me'] = UserProfile(
    nickname: '나',
    rankLevel: 1,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: DateTime.utc(2026, 11, 6),
  );
  fakes.coinWallets.emit('me', 330);
  await fakes.auth.signInWithEmail(email: 'me', password: 'password');
  await managers.authManager.ensureProfileLoaded();
  return fakes;
}

/// 홈에서 상점 아이콘을 눌러 상점을 연다.
Future<void> _openStore(WidgetTester tester) async {
  await tester.pumpWidget(const JanggigoApp());
  await _pumpFor(tester);
  await tester.tap(find.byIcon(Icons.storefront_outlined));
  await _pumpFor(tester);
}

void main() {
  group('상점 화면', () {
    testWidgets('홈의 아이콘으로 열고 잔액과 상품을 보여준다', (tester) async {
      _usePhoneView(tester);
      await _signIn();
      await _openStore(tester);

      expect(find.byType(StoreScreen), findsOneWidget);
      expect(find.text('330'), findsWidgets);
      for (final text in ['엽전 충전', '300엽전', '1,100엽전', '3,000엽전', '장기알', '기본 장기알', '나무 장기알', '알루미늄 장기알', '광고 제거']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('쓰는 중'), findsOneWidget);
      expect(find.text('구매 복원'), findsOneWidget);
      expect(find.textContaining('7일 안에'), findsOneWidget);
    });

    testWidgets('스토어 가격을 읽으면 그 값을, 못 읽으면 원화 값을 보여준다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.storePurchases.prices = {'coins_300': r'$0.99'};
      await _openStore(tester);

      expect(find.text(r'$0.99'), findsOneWidget);
      expect(find.text('1,200원'), findsNothing);
      expect(find.text('3,900원'), findsOneWidget);
      expect(find.text('4,900원'), findsNWidgets(3));
    });

    testWidgets('로그인하지 않았으면 로그인을 먼저 묻는다', (tester) async {
      _usePhoneView(tester);
      setUpFakeApp();
      await _openStore(tester);

      expect(find.byType(StoreScreen), findsNothing);
      expect(find.text('로그인하면\n상점을 쓸 수 있어요'), findsOneWidget);
    });

    testWidgets('각 기물의 미리보기를 그 재질로 보여준다', (tester) async {
      _usePhoneView(tester);
      await _signIn();
      await _openStore(tester);

      final icons = tester.widgetList<PieceIcon>(find.byType(PieceIcon)).map((icon) => icon.material).toList();
      for (final material in PieceMaterial.values) {
        expect(icons.where((item) => item == material).length, 4);
      }
    });

    testWidgets('coinSaleEnabled를 끄면 다음에 켤 때부터 충전만 숨기고 나머지는 판다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await _openStore(tester);
      expect(find.text('300엽전'), findsOneWidget);

      fakes.configs.coinSaleEnabled = false;
      await _pumpFor(tester);
      expect(find.text('300엽전'), findsOneWidget);

      managers.appConfigManager.reloadForStart();
      await _pumpFor(tester);

      expect(find.text('엽전 충전'), findsNothing);
      expect(find.text('300엽전'), findsNothing);
      expect(find.text('나무 장기알'), findsOneWidget);
      expect(find.text('4,900원'), findsNWidgets(3));
    });

    testWidgets('웹은 구매 자리에 "앱에서 살 수 있어요"를 두고 복원 버튼이 없다', (tester) async {
      _usePhoneView(tester);
      await _signIn();
      managers.appConfigManager.web = true;
      await _openStore(tester);

      expect(find.text('앱에서 살 수 있어요'), findsNWidgets(6));
      expect(find.text('1,200원'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('구매 복원'), findsNothing);
    });

    testWidgets('웹도 산 기물은 고를 수 있다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', materials: [PieceMaterial.wood]);
      managers.appConfigManager.web = true;
      await _openStore(tester);

      await tester.tap(find.text('쓰기'));
      await _pumpFor(tester);

      expect(managers.storeManager.selectedMaterial, PieceMaterial.wood);
    });
  });

  group('결제', () {
    testWidgets('구매 버튼을 누르면 내 uid로 결제한다. 지급은 서버가 하므로 앱은 바꾸지 않는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await _openStore(tester);

      await tester.tap(find.text('1,200원'));
      await _pumpFor(tester);

      expect(fakes.storePurchases.purchases, [(uid: 'me', productId: 'coins_300')]);
      expect(find.text('결제했어요. 곧 들어와요'), findsOneWidget);
      expect(managers.coinManager.balance, 330);

      fakes.coinWallets.emit('me', 630);
      await _pumpFor(tester);
      expect(find.text('630'), findsWidgets);
    });

    testWidgets('사용자가 결제를 취소하면 아무것도 알리지 않는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.storePurchases.nextPurchaseError = const AppException(AppErrorCode.purchaseCanceled);
      await _openStore(tester);

      await tester.tap(find.text('1,200원'));
      await _pumpFor(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('결제했어요. 곧 들어와요'), findsNothing);
    });

    testWidgets('스토어의 거절은 사유를, 모르는 오류는 기본 메시지를 보여주고 다시 살 수 있다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.storePurchases.nextPurchaseError = const AppException(AppErrorCode.purchaseAlreadyOwned);
      await _openStore(tester);

      await tester.tap(find.text('1,200원'));
      await _pumpFor(tester);
      expect(find.text('이 스토어 계정으로 이미 산 상품이에요'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await _pumpFor(tester);

      fakes.storePurchases.nextPurchaseError = StateError('스토어 오류');
      await tester.tap(find.text('1,200원'));
      await _pumpFor(tester);
      expect(find.text('결제하지 못했어요. 잠시 후 다시 해 주세요'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await _pumpFor(tester);

      await tester.tap(find.text('1,200원'));
      await _pumpFor(tester);
      expect(fakes.storePurchases.purchases, hasLength(1));
    });

    testWidgets('구매 복원을 내 uid로 부른다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await _openStore(tester);

      await tester.ensureVisible(find.text('구매 복원'));
      await tester.tap(find.text('구매 복원'));
      await _pumpFor(tester);

      expect(fakes.storePurchases.restores, ['me']);
      expect(find.text('구매를 다시 확인했어요'), findsOneWidget);
    });

    testWidgets('로그아웃하면 스토어에서도 로그아웃한다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      await managers.authManager.signOut();
      await _pumpFor(tester);
      expect(fakes.storePurchases.logOutCalls, 1);
    });
  });

  group('보관함', () {
    testWidgets('산 기물은 쓰기로, 쓰는 기물은 쓰는 중으로 보여주고 고르면 바뀐다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', materials: [PieceMaterial.wood], selected: PieceMaterial.wood);
      await _openStore(tester);

      expect(managers.storeManager.selectedMaterial, PieceMaterial.wood);
      expect(find.text('쓰는 중'), findsOneWidget);
      expect(find.text('쓰기'), findsOneWidget);
      expect(find.text('4,900원'), findsNWidgets(2));

      await tester.tap(find.text('쓰기'));
      await _pumpFor(tester);
      expect(managers.storeManager.selectedMaterial, PieceMaterial.plastic);
    });

    testWidgets('기물을 고르지 못하면 알린다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', materials: [PieceMaterial.wood]);
      fakes.inventories.nextSelectError = StateError('규칙 거절');
      await _openStore(tester);

      await tester.tap(find.text('쓰기'));
      await _pumpFor(tester);
      expect(find.text('장기알을 바꾸지 못했어요. 잠시 후 다시 해 주세요'), findsOneWidget);
    });

    testWidgets('환불되어 빠진 기물은 고른 값이 남아 있어도 쓰지 않는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', selected: PieceMaterial.wood);
      await _pumpFor(tester);
      expect(managers.storeManager.selectedMaterial, PieceMaterial.plastic);
      expect(managers.storeManager.isOwned(PieceMaterial.wood), isFalse);
      expect(managers.storeManager.isOwned(PieceMaterial.plastic), isTrue);
    });

    testWidgets('광고 제거를 샀으면 샀어요로 보여준다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', adsRemoved: true);
      await _openStore(tester);

      expect(managers.storeManager.adsRemoved, isTrue);
      expect(find.text('샀어요'), findsOneWidget);
    });

    test('모르는 재질은 기본 기물로 읽는다', () {
      final inventory = Inventory.fromJson({
        'materials': ['gold', 'wood'],
        'selectedMaterial': 'gold',
        'adsRemoved': false,
      });
      expect(inventory.materials, [PieceMaterial.plastic, PieceMaterial.wood]);
      expect(inventory.selectedMaterial, PieceMaterial.plastic);
      final player = GamePlayer.fromJson({'uid': 'a', 'nickname': '나', 'rankLevel': 1, 'pieceMaterial': 'gold'});
      expect(player.pieceMaterial, isNull);
    });

    test('대국자의 재질을 진영별로 읽고 없으면 기본 기물이다', () {
      final players = GamePlayers.fromJson({
        'cho': {'uid': 'a', 'nickname': '나', 'rankLevel': 1, 'pieceMaterial': 'aluminum'},
        'han': {'uid': 'b', 'nickname': '너', 'rankLevel': 1},
      });
      expect(players.materials, (cho: PieceMaterial.aluminum, han: PieceMaterial.plastic));
    });
  });

  group('판의 기물', () {
    testWidgets('온라인 대국은 내가 고른 것과 상관없이 대국에 실린 두 사람의 기물로 그린다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', materials: [PieceMaterial.aluminum], selected: PieceMaterial.aluminum);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Theme(
            data: gameTheme,
            child: const GameScreen.online(gameId: 'g1'),
          ),
        ),
      );
      final game = buildGameJson(phase: 'playing', turn: 'cho', turnStartedAt: 1000000);
      final players = (game['meta'] as Map<String, dynamic>)['players'] as Map<String, dynamic>;
      (players['han'] as Map<String, dynamic>)['pieceMaterial'] = 'wood';
      fakes.games.emit('g1', game);
      await _pumpFor(tester);

      final board = tester.widget<BoardView>(find.byType(BoardView));
      expect(board.materials, (cho: PieceMaterial.plastic, han: PieceMaterial.wood));
    });

    testWidgets('대국자의 기물을 모르는 판은 양쪽 모두 내가 고른 기물로 그린다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', materials: [PieceMaterial.wood], selected: PieceMaterial.wood);
      await _pumpFor(tester);
      expect(managers.storeManager.materials, (cho: PieceMaterial.wood, han: PieceMaterial.wood));
    });
  });

  group('엽전이 모자라요 창', () {
    Future<void> showError(WidgetTester tester, Object error) async {
      final context = tester.element(find.byType(Scaffold).first);
      showActionError(context, error: error, fallback: '기본 메시지');
      await _pumpFor(tester);
    }

    testWidgets('상점으로 가는 버튼이 있고 누르면 상점을 연다', (tester) async {
      _usePhoneView(tester);
      await _signIn();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);

      await showError(tester, const AppException(AppErrorCode.coinsInsufficient));
      expect(find.text('엽전이 모자라요'), findsOneWidget);

      await tester.tap(find.text('상점으로 가기'));
      await _pumpFor(tester);
      expect(find.byType(StoreScreen), findsOneWidget);
    });

    testWidgets('coinSaleEnabled를 끄면 상점 버튼 없이 알리기만 한다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);
      fakes.configs.coinSaleEnabled = false;
      managers.appConfigManager.reloadForStart();
      await _pumpFor(tester);

      await showError(tester, const AppException(AppErrorCode.coinsInsufficient));
      expect(find.text('엽전이 모자라요'), findsOneWidget);
      expect(find.text('상점으로 가기'), findsNothing);
    });

    testWidgets('다른 오류는 그 사유를, 모르는 오류는 기본 메시지를 보여준다', (tester) async {
      _usePhoneView(tester);
      await _signIn();
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);

      await showError(tester, const AppException(AppErrorCode.purchasePending));
      expect(find.text('결제가 끝나면 들어와요'), findsOneWidget);
      expect(find.text('상점으로 가기'), findsNothing);
      await tester.tap(find.text('확인'));
      await _pumpFor(tester);

      await showError(tester, StateError('모름'));
      expect(find.text('기본 메시지'), findsOneWidget);
    });

    testWidgets('빠른 대국에서 엽전이 모자라면 이 창을 띄운다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.games.nextError = const AppException(AppErrorCode.coinsInsufficient);
      await tester.pumpWidget(const JanggigoApp());
      await _pumpFor(tester);

      await tester.tap(find.text('빠른 대국'));
      await _pumpFor(tester);

      expect(find.text('엽전이 모자라요'), findsOneWidget);
      expect(find.text('상점으로 가기'), findsOneWidget);
    });
  });
}
