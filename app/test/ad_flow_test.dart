import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/app.dart';
import 'package:janggigo/l10n/app_localizations.dart';
import 'package:janggigo/managers/app_managers.dart';
import 'package:janggigo/models/user_profile.dart';
import 'package:janggigo/screens/records_screen.dart';
import 'package:janggigo/screens/settings_screen.dart';
import 'package:janggigo/screens/spectate_screen.dart';
import 'package:janggigo/screens/store_screen.dart';
import 'package:janggigo/utils/app_exception.dart';
import 'package:janggigo/widgets/ad_banner.dart';

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

String _today() => DateTime.now().toUtc().add(const Duration(hours: 9)).toIso8601String().substring(0, 10);

/// 로그인하고 지갑과 보관함이 있는 상태. [start]면 동의를 거쳐 광고를 켠 상태다.
Future<FakeApp> _signIn({bool adsAllowed = true, bool start = true}) async {
  final fakes = setUpFakeApp();
  fakes.ads.adsAllowed = adsAllowed;
  fakes.users.profiles['me'] = UserProfile(
    nickname: '나',
    rankLevel: 1,
    stats: const UserStats(games: 0, wins: 0, losses: 0),
    createdAt: DateTime.utc(2026, 11, 6),
  );
  fakes.coinWallets.emit('me', 5);
  fakes.inventories.emit('me');
  await fakes.auth.signInWithEmail(email: 'me', password: 'password');
  await managers.authManager.ensureProfileLoaded();
  if (start) {
    await managers.adManager.start();
  }
  return fakes;
}

Widget localizedApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const JanggigoApp());
  await _pumpFor(tester);
}

Future<void> _showCoinsInsufficient(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  showActionError(context, error: const AppException(AppErrorCode.coinsInsufficient), fallback: '기본 메시지');
  await _pumpFor(tester);
}

Future<void> _openStore(WidgetTester tester) async {
  await _pumpApp(tester);
  await tester.tap(find.byIcon(Icons.storefront_outlined));
  await _pumpFor(tester);
}

void main() {
  group('배너', () {
    testWidgets('홈 아래에 배너를 둔다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await _pumpApp(tester);

      expect(find.byKey(fakeBannerKey), findsOneWidget);
      expect(fakes.ads.bannerLoads, 1);
    });

    testWidgets('내 기보 목록 아래에 배너를 둔다', (tester) async {
      _usePhoneView(tester);
      await _signIn();
      await _pumpApp(tester);

      await tester.tap(find.text('기보'));
      await _pumpFor(tester);

      expect(find.byType(RecordsScreen), findsOneWidget);
      expect(find.descendant(of: find.byType(RecordsScreen), matching: find.byKey(fakeBannerKey)), findsOneWidget);
    });

    testWidgets('로그인하지 않은 관전자에게도 관전 화면에 배너를 둔다', (tester) async {
      _usePhoneView(tester);
      final fakes = setUpFakeApp();
      fakes.ads.adsAllowed = true;
      await managers.adManager.start();
      await tester.pumpWidget(localizedApp(const SpectateScreen(gameId: 'g1')));
      fakes.games.emit('g1', buildGameJson(phase: 'playing', turn: 'cho', turnStartedAt: 1000000));
      await _pumpFor(tester);

      expect(find.descendant(of: find.byType(SpectateScreen), matching: find.byKey(fakeBannerKey)), findsOneWidget);
    });

    testWidgets('광고 제거를 사면 배너가 바로 사라지고 보상형은 남는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await _pumpApp(tester);
      expect(find.byKey(fakeBannerKey), findsOneWidget);

      fakes.inventories.emit('me', adsRemoved: true);
      await _pumpFor(tester);

      expect(find.byKey(fakeBannerKey), findsNothing);
      expect(fakes.ads.bannerDisposes, 1);
      expect(managers.adManager.rewardedAdReward, 30);

      await tester.tap(find.byIcon(Icons.storefront_outlined));
      await _pumpFor(tester);
      expect(find.text('광고 보고 30엽전 받기'), findsOneWidget);
    });

    testWidgets('광고 제거가 환불되면 배너가 다시 나온다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.inventories.emit('me', adsRemoved: true);
      await _pumpApp(tester);
      expect(find.byKey(fakeBannerKey), findsNothing);
      expect(fakes.ads.bannerLoads, 0);

      fakes.inventories.emit('me');
      await _pumpFor(tester);

      expect(find.byKey(fakeBannerKey), findsOneWidget);
    });

    testWidgets('보관함을 읽기 전에는 광고 제거를 샀는지 모르므로 불러오지 않는다', (tester) async {
      _usePhoneView(tester);
      final fakes = setUpFakeApp();
      fakes.ads.adsAllowed = true;
      await fakes.auth.signInWithEmail(email: 'me', password: 'password');
      await managers.adManager.start();
      await _pumpApp(tester);

      expect(fakes.ads.bannerLoads, 0);
      fakes.inventories.emit('me');
      await _pumpFor(tester);
      expect(fakes.ads.bannerLoads, 1);
    });

    testWidgets('bannerAdEnabled를 끄면 다음에 켤 때부터 없고 보상형은 남는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await _pumpApp(tester);
      expect(find.byKey(fakeBannerKey), findsOneWidget);

      fakes.configs.bannerAdEnabled = false;
      await _pumpFor(tester);
      expect(find.byKey(fakeBannerKey), findsOneWidget);

      managers.appConfigManager.reloadForStart();
      await _pumpFor(tester);
      expect(find.byKey(fakeBannerKey), findsNothing);
      expect(managers.adManager.rewardedAdReward, 30);
    });

    testWidgets('동의를 받지 못했으면 광고가 없다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn(adsAllowed: false);
      await _pumpApp(tester);

      expect(find.byKey(fakeBannerKey), findsNothing);
      expect(fakes.ads.bannerLoads, 0);
      expect(managers.adManager.rewardedAdReward, isNull);
    });

    testWidgets('웹은 광고가 없다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      managers.appConfigManager.web = true;
      await _openStore(tester);

      expect(fakes.ads.bannerLoads, 0);
      expect(find.text('광고 보고 30엽전 받기'), findsNothing);
    });

    testWidgets('화면을 나가면 배너를 치운다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await tester.pumpWidget(localizedApp(const AdBanner()));
      await _pumpFor(tester);
      expect(fakes.ads.bannerLoads, 1);

      await tester.pumpWidget(localizedApp(const SizedBox.shrink()));
      await _pumpFor(tester);
      expect(fakes.ads.bannerDisposes, 1);
    });
  });

  group('상점의 엽전 받기', () {
    testWidgets('값과 남은 횟수를 보여주고, 누르면 내 uid로 광고를 띄운다. 지급은 서버가 한다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.coinWallets.emit('me', 330, rewardedAdDay: _today(), rewardedAdCount: 2);
      await _openStore(tester);

      expect(find.text('엽전 받기'), findsOneWidget);
      expect(find.text('광고 보고 30엽전 받기'), findsOneWidget);
      expect(find.text('오늘 3번 남았어요'), findsOneWidget);

      await tester.tap(find.text('보기'));
      await _pumpFor(tester);

      expect(fakes.ads.rewardedAdUids, ['me']);
      expect(find.text('곧 30엽전이 들어와요'), findsOneWidget);
      expect(managers.coinManager.balance, 330);

      fakes.coinWallets.emit('me', 360, rewardedAdDay: _today(), rewardedAdCount: 3);
      await _pumpFor(tester);
      expect(find.text('360'), findsWidgets);
      expect(find.text('오늘 2번 남았어요'), findsOneWidget);
    });

    testWidgets('어제 받은 횟수는 세지 않는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.coinWallets.emit('me', 330, rewardedAdDay: '2020-01-01', rewardedAdCount: 5);
      await _openStore(tester);

      expect(find.text('오늘 5번 남았어요'), findsOneWidget);
    });

    testWidgets('오늘 횟수를 다 쓰면 버튼을 끈다. 횟수는 configs/app의 값이다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.configs.coinRewardedAdDailyLimit = 2;
      managers.appConfigManager.reloadForStart();
      fakes.coinWallets.emit('me', 330, rewardedAdDay: _today(), rewardedAdCount: 2);
      await _openStore(tester);

      expect(find.text('오늘은 다 받았어요'), findsOneWidget);
      await tester.tap(find.text('보기'));
      await _pumpFor(tester);
      expect(fakes.ads.rewardedAdUids, isEmpty);
    });

    testWidgets('끝까지 보지 않으면 아무것도 알리지 않는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.ads.nextRewardedAdError = const AppException(AppErrorCode.adNotCompleted);
      await _openStore(tester);

      await tester.tap(find.text('보기'));
      await _pumpFor(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('곧 30엽전이 들어와요'), findsNothing);
    });

    testWidgets('광고를 볼 수 없으면 알리고, 불러오는 동안에는 다시 누를 수 없다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.ads.nextRewardedAdError = const AppException(AppErrorCode.adUnavailable);
      fakes.ads.rewardedAdGate = Completer<void>();
      await _openStore(tester);

      await tester.tap(find.text('보기'));
      await _pumpFor(tester);
      await tester.tap(find.text('보기'));
      await _pumpFor(tester);
      expect(fakes.ads.rewardedAdUids, ['me']);

      fakes.ads.rewardedAdGate!.complete();
      await _pumpFor(tester);
      expect(find.text('지금은 광고를 볼 수 없어요. 잠시 후 다시 해 주세요'), findsOneWidget);
    });

    testWidgets('rewardedAdEnabled를 끄면 다음에 켤 때부터 버튼이 없다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.configs.rewardedAdEnabled = false;
      managers.appConfigManager.reloadForStart();
      await _openStore(tester);

      expect(find.text('엽전 받기'), findsNothing);
      expect(find.text('광고 보고 30엽전 받기'), findsNothing);
    });
  });

  group('엽전이 모자라요 창', () {
    testWidgets('광고 버튼을 누르면 광고를 보고 창을 닫는다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      await _pumpApp(tester);

      await _showCoinsInsufficient(tester);
      expect(find.text('상점으로 가기'), findsOneWidget);

      await tester.tap(find.text('광고 보고 30엽전 받기'));
      await _pumpFor(tester);

      expect(fakes.ads.rewardedAdUids, ['me']);
      expect(find.text('엽전이 모자라요'), findsNothing);
      expect(find.text('곧 30엽전이 들어와요'), findsOneWidget);
      expect(find.byType(StoreScreen), findsNothing);
    });

    testWidgets('광고를 불러오는 동안 창을 두고 버튼을 끈다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.ads.rewardedAdGate = Completer<void>();
      await _pumpApp(tester);
      await _showCoinsInsufficient(tester);

      await tester.tap(find.text('광고 보고 30엽전 받기'));
      await _pumpFor(tester);
      expect(find.text('엽전이 모자라요'), findsOneWidget);
      await tester.tap(find.text('광고 보고 30엽전 받기'));
      await tester.tap(find.text('상점으로 가기'));
      await _pumpFor(tester);
      expect(fakes.ads.rewardedAdUids, ['me']);
      expect(find.byType(StoreScreen), findsNothing);

      fakes.ads.rewardedAdGate!.complete();
      await _pumpFor(tester);
      expect(find.text('엽전이 모자라요'), findsNothing);
    });

    testWidgets('오늘 횟수를 다 썼으면 상점 버튼만 있다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.coinWallets.emit('me', 5, rewardedAdDay: _today(), rewardedAdCount: 5);
      await _pumpApp(tester);

      await _showCoinsInsufficient(tester);

      expect(find.text('광고 보고 30엽전 받기'), findsNothing);
      expect(find.text('상점으로 가기'), findsOneWidget);
    });

    testWidgets('충전을 멈췄어도 광고 버튼은 있다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.configs.coinSaleEnabled = false;
      managers.appConfigManager.reloadForStart();
      await _pumpApp(tester);

      await _showCoinsInsufficient(tester);

      expect(find.text('광고 보고 30엽전 받기'), findsOneWidget);
      expect(find.text('상점으로 가기'), findsNothing);
    });

    testWidgets('충전도 광고도 안 되면 알리기만 한다', (tester) async {
      _usePhoneView(tester);
      final fakes = await _signIn();
      fakes.configs.coinSaleEnabled = false;
      fakes.configs.rewardedAdEnabled = false;
      managers.appConfigManager.reloadForStart();
      await _pumpApp(tester);

      await _showCoinsInsufficient(tester);

      expect(find.text('엽전이 모자라요'), findsOneWidget);
      expect(find.text('광고 보고 30엽전 받기'), findsNothing);
      expect(find.text('상점으로 가기'), findsNothing);
      expect(find.text('확인'), findsOneWidget);
    });

    testWidgets('웹은 상점 버튼만 있다', (tester) async {
      _usePhoneView(tester);
      await _signIn();
      managers.appConfigManager.web = true;
      await _pumpApp(tester);

      await _showCoinsInsufficient(tester);

      expect(find.text('광고 보고 30엽전 받기'), findsNothing);
      expect(find.text('상점으로 가기'), findsOneWidget);
    });
  });

  group('광고 동의', () {
    testWidgets('UMP 대상이면 설정에 다시 고르는 항목을 둔다', (tester) async {
      _usePhoneView(tester);
      final fakes = setUpFakeApp();
      fakes.ads.privacyOptionsRequired = true;
      await managers.adManager.start();
      await tester.pumpWidget(localizedApp(const SettingsScreen()));
      await _pumpFor(tester);

      await tester.ensureVisible(find.text('광고 개인정보 설정'));
      await tester.tap(find.text('광고 개인정보 설정'));
      await _pumpFor(tester);

      expect(fakes.ads.privacyOptionsShows, 1);
    });

    testWidgets('대상이 아니면 항목이 없다', (tester) async {
      _usePhoneView(tester);
      setUpFakeApp();
      await managers.adManager.start();
      await tester.pumpWidget(localizedApp(const SettingsScreen()));
      await _pumpFor(tester);

      expect(find.text('광고 개인정보 설정'), findsNothing);
    });
  });
}
