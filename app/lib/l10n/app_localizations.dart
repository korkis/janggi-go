import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// 앱 이름
  ///
  /// In ko, this message translates to:
  /// **'장기고'**
  String get appTitle;

  /// 홈의 개발용 대국 카드 제목. 개발 빌드에만 보인다
  ///
  /// In ko, this message translates to:
  /// **'개발용 대국'**
  String get homeDevGameTitle;

  /// 홈의 개발용 대국 카드 설명
  ///
  /// In ko, this message translates to:
  /// **'한 기기에서 초와 한을 번갈아 둬요'**
  String get homeDevGameDescription;

  /// 개발용 대국을 시작하는 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get homeDevGameStart;

  /// 뒤로 가기 버튼의 화면 읽기 이름
  ///
  /// In ko, this message translates to:
  /// **'뒤로'**
  String get back;

  /// 확인 창의 취소 버튼
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// 진영 이름
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{초} han{한} other{}}'**
  String sideName(String side);

  /// 정보 줄 동그라미 안에 쓰는 진영 한자
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{楚} han{漢} other{}}'**
  String sideHanja(String side);

  /// 상차림 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'상차림을 골라 주세요'**
  String get setupTitle;

  /// 상대가 상차림을 확정했을 때 상대 정보 줄에 보이는 글자
  ///
  /// In ko, this message translates to:
  /// **'정했어요'**
  String get setupDecided;

  /// 상차림을 확정하는 버튼
  ///
  /// In ko, this message translates to:
  /// **'이 상차림으로 정하기'**
  String get setupConfirm;

  /// 상차림 이름. 상차림 버튼의 화면 읽기 이름으로 쓴다
  ///
  /// In ko, this message translates to:
  /// **'{formation, select, horseElephantHorseElephant{마상마상} elephantHorseElephantHorse{상마상마} horseElephantElephantHorse{마상상마} elephantHorseHorseElephant{상마마상} other{}}'**
  String formationName(String formation);

  /// 개발용 대국 화면 위쪽 제목. count는 지금까지 둔 수
  ///
  /// In ko, this message translates to:
  /// **'개발용 대국 · {count}수'**
  String gameDevTitle(int count);

  /// 남은 기물 점수
  ///
  /// In ko, this message translates to:
  /// **'{score}점'**
  String score(String score);

  /// 장군을 받은 쪽의 정보 줄에 보이는 표시
  ///
  /// In ko, this message translates to:
  /// **'장군'**
  String get check;

  /// 마지막 수로 한수쉼을 한 쪽의 정보 줄에 보이는 표시
  ///
  /// In ko, this message translates to:
  /// **'한수쉼'**
  String get passedLast;

  /// 한수쉼 버튼
  ///
  /// In ko, this message translates to:
  /// **'한수쉼'**
  String get pass;

  /// 한수쉼을 할 수 없을 때 알림
  ///
  /// In ko, this message translates to:
  /// **'지금은 한수쉼을 할 수 없어요'**
  String get passFailed;

  /// 대국 메뉴를 여는 버튼
  ///
  /// In ko, this message translates to:
  /// **'더보기'**
  String get more;

  /// 판의 위아래를 바꾸는 메뉴
  ///
  /// In ko, this message translates to:
  /// **'판 돌리기'**
  String get flipBoard;

  /// 기권 메뉴
  ///
  /// In ko, this message translates to:
  /// **'기권'**
  String get resign;

  /// 기권 확인 창
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{초가} han{한이} other{}} 기권할까요?'**
  String resignConfirm(String side);

  /// 기권 확인 창의 기권 버튼
  ///
  /// In ko, this message translates to:
  /// **'기권하기'**
  String get resignAction;

  /// 대국 중 뒤로 가기를 눌렀을 때 확인 창
  ///
  /// In ko, this message translates to:
  /// **'대국을 그만두고 나갈까요?'**
  String get leaveGameConfirm;

  /// 대국 나가기 확인 창의 나가기 버튼
  ///
  /// In ko, this message translates to:
  /// **'나가기'**
  String get leaveGameAction;

  /// 대국 결과 종류
  ///
  /// In ko, this message translates to:
  /// **'{reason, select, checkmate{외통승} resignation{기권승} timeout{시간승} consecutivePasses{점수승} moveLimit{점수승} noLegalMoves{점수승} other{}}'**
  String resultReason(String reason);

  /// 대국 결과 창의 큰 제목
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{초 승리} han{한 승리} other{}}'**
  String resultWinner(String side);

  /// 대국 결과 창의 수와 걸린 시간
  ///
  /// In ko, this message translates to:
  /// **'{moves}수 · {minutes}분 {seconds}초'**
  String resultSummary(int moves, int minutes, int seconds);

  /// 양쪽 연속 한수쉼으로 점수 판정했을 때 설명
  ///
  /// In ko, this message translates to:
  /// **'양쪽이 연속으로 한수쉼을 해서 점수로 정했어요'**
  String get resultConsecutivePasses;

  /// 총 수 제한으로 점수 판정했을 때 설명
  ///
  /// In ko, this message translates to:
  /// **'{limit}수에 닿아서 점수로 정했어요'**
  String resultMoveLimit(int limit);

  /// 둘 수 있는 수가 없어 점수 판정했을 때 설명
  ///
  /// In ko, this message translates to:
  /// **'둘 수 있는 수가 없어서 점수로 정했어요'**
  String get resultNoLegalMoves;

  /// 대국 결과 창에서 상차림부터 다시 시작하는 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 두기'**
  String get resultRematch;

  /// 대국 결과 창에서 홈으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'홈으로'**
  String get resultHome;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
