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

  /// 상대가 상차림을 확정했을 때 상차림 창에 보이는 글자. 옆에 상대의 마·상 기물 네 개를 놓는다
  ///
  /// In ko, this message translates to:
  /// **'상대가 정했어요'**
  String get setupDecided;

  /// 상차림 창 위쪽의 내 진영과 두는 순서
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{나는 초 · 먼저 둬요} han{나는 한 · 나중에 둬요} other{}}'**
  String setupMySide(String side);

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
  /// **'메뉴'**
  String get more;

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

  /// 대국 결과 종류. 내가 이겼거나 관전자일 때 쓴다
  ///
  /// In ko, this message translates to:
  /// **'{reason, select, checkmate{외통승} resignation{기권승} timeout{시간승} consecutivePasses{점수승} moveLimit{점수승} noLegalMoves{점수승} disconnect{접속 끊김승} other{}}'**
  String resultReason(String reason);

  /// 내가 졌을 때의 대국 결과 종류
  ///
  /// In ko, this message translates to:
  /// **'{reason, select, checkmate{외통패} resignation{기권패} timeout{시간패} consecutivePasses{점수패} moveLimit{점수패} noLegalMoves{점수패} disconnect{접속 끊김패} other{}}'**
  String resultReasonLoss(String reason);

  /// 대국 결과 창 가운데 궁 아래의 큰 글자
  ///
  /// In ko, this message translates to:
  /// **'승리'**
  String get resultOutcomeWin;

  /// 대국 결과 창 가운데 궁 아래의 큰 글자
  ///
  /// In ko, this message translates to:
  /// **'패배'**
  String get resultOutcomeLoss;

  /// 대국 결과 창의 제목. 관전자가 볼 때 이긴 쪽 기준
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{초 승리} han{한 승리} other{}}'**
  String resultWinner(String side);

  /// 대국이 끝난 화면의 재대국 신청 버튼
  ///
  /// In ko, this message translates to:
  /// **'재대국 신청'**
  String get resultRematch;

  /// 복기 화면 위쪽 제목
  ///
  /// In ko, this message translates to:
  /// **'복기'**
  String get reviewTitle;

  /// 복기에서 지금 보는 수와 전체 수
  ///
  /// In ko, this message translates to:
  /// **'{current} / {total}수'**
  String reviewMoveCounter(int current, int total);

  /// 복기 중 판에 직접 수를 두어 보는 기능을 켜고 끄는 버튼
  ///
  /// In ko, this message translates to:
  /// **'놓아보기'**
  String get reviewTrial;

  /// 복기 처음 국면으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'처음'**
  String get reviewFirst;

  /// 복기 한 수 앞으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get reviewPrevious;

  /// 복기 한 수 뒤로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get reviewNext;

  /// 복기 마지막 국면으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'끝'**
  String get reviewLast;

  /// 확인 창의 확인 버튼
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get ok;

  /// 닫기 버튼의 화면 읽기 이름
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// 로그인 버튼
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get login;

  /// 이메일 가입 화면의 가입 버튼
  ///
  /// In ko, this message translates to:
  /// **'가입하기'**
  String get signUp;

  /// 홈 내 카드의 로그인 안내
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 급수와 전적이 저장돼요'**
  String get homeLoginGuide;

  /// 홈의 로그인 버튼으로 띄운 로그인 창 제목
  ///
  /// In ko, this message translates to:
  /// **'로그인하고\n온라인 대국을 둬 보세요'**
  String get loginSheetTitleHome;

  /// 빠른 대국을 눌러 띄운 로그인 창 제목
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 바로\n상대를 찾아 드릴게요'**
  String get loginSheetTitleQuickMatch;

  /// 로그인 창 제목 아래의 로그인이 필요한 이유
  ///
  /// In ko, this message translates to:
  /// **'온라인 대국은 로그인 후 둘 수 있어요.\n급수와 전적이 저장돼요.'**
  String get loginSheetDescription;

  /// Google 로그인 버튼
  ///
  /// In ko, this message translates to:
  /// **'Google로 계속하기'**
  String get loginWithGoogle;

  /// Apple 로그인 버튼
  ///
  /// In ko, this message translates to:
  /// **'Apple로 계속하기'**
  String get loginWithApple;

  /// 이메일 로그인 버튼
  ///
  /// In ko, this message translates to:
  /// **'이메일로 계속하기'**
  String get loginWithEmail;

  /// 이용약관 문서 이름
  ///
  /// In ko, this message translates to:
  /// **'이용약관'**
  String get termsOfService;

  /// 개인정보처리방침 문서 이름
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침'**
  String get privacyPolicy;

  /// 로그인 창 맨 아래의 약관 동의 안내
  ///
  /// In ko, this message translates to:
  /// **'계속하면 만 14세 이상이며 {terms}과 {privacy}에\n동의하는 것으로 봅니다.'**
  String loginTermsNotice(String terms, String privacy);

  /// 이메일 로그인 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'이메일로 로그인'**
  String get emailLoginTitle;

  /// 이메일 로그인 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'가입할 때 쓴 이메일과 비밀번호를 넣어 주세요.'**
  String get emailLoginDescription;

  /// 이메일 가입 화면 제목과 이메일 로그인 화면의 가입 링크
  ///
  /// In ko, this message translates to:
  /// **'이메일로 가입하기'**
  String get emailSignUpTitle;

  /// 이메일 가입 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'로그인에 쓸 이메일과 비밀번호를 정해 주세요.'**
  String get emailSignUpDescription;

  /// 이메일 로그인 화면의 가입 링크 앞 글
  ///
  /// In ko, this message translates to:
  /// **'처음이신가요?'**
  String get emailSignUpPrompt;

  /// 이메일 입력칸 이름
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get email;

  /// 비밀번호 입력칸 이름
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get password;

  /// 이메일 가입의 비밀번호 확인 입력칸 이름
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 확인'**
  String get passwordConfirm;

  /// 비밀번호 보기 버튼의 화면 읽기 이름
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 보기'**
  String get showPassword;

  /// 비밀번호 숨기기 버튼의 화면 읽기 이름
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 숨기기'**
  String get hidePassword;

  /// 이메일 가입 화면 비밀번호 확인 칸의 보기 버튼 화면 읽기 이름
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 확인 보기'**
  String get showPasswordConfirm;

  /// 이메일 가입 화면 비밀번호 확인 칸의 숨기기 버튼 화면 읽기 이름
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 확인 숨기기'**
  String get hidePasswordConfirm;

  /// 비밀번호 재설정 메일 보내기 링크
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 잊으셨나요?'**
  String get forgotPassword;

  /// 비밀번호 재설정 메일을 보낸 뒤의 안내
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 다시 정하는 메일을 보냈어요. 메일함을 확인해 주세요.'**
  String get passwordResetSent;

  /// 닉네임 정하기 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'장기판에서 쓸\n이름을 정해 주세요'**
  String get nicknameTitle;

  /// 닉네임 정하기 화면 설명
  ///
  /// In ko, this message translates to:
  /// **'대국 상대와 관전하는 사람에게 보여요.'**
  String get nicknameDescription;

  /// 닉네임 입력칸 이름
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get nickname;

  /// 닉네임 입력칸의 글자 수
  ///
  /// In ko, this message translates to:
  /// **'{count}/{max}'**
  String nicknameLength(int count, int max);

  /// 닉네임 입력칸 아래의 규칙 안내
  ///
  /// In ko, this message translates to:
  /// **'한글, 영문, 숫자로 {min}~{max}자'**
  String nicknameRule(int min, int max);

  /// 닉네임을 쓸 수 있는지 확인하는 중
  ///
  /// In ko, this message translates to:
  /// **'확인하고 있어요'**
  String get nicknameChecking;

  /// 닉네임을 쓸 수 있을 때
  ///
  /// In ko, this message translates to:
  /// **'쓸 수 있는 닉네임이에요'**
  String get nicknameAvailable;

  /// 닉네임을 쓸 수 없고 앱이 모르는 이유일 때
  ///
  /// In ko, this message translates to:
  /// **'쓸 수 없는 닉네임이에요'**
  String get nicknameUnavailable;

  /// 닉네임 확인 요청이 실패했을 때
  ///
  /// In ko, this message translates to:
  /// **'확인하지 못했어요. 잠시 후 다시 해 주세요'**
  String get nicknameCheckFailed;

  /// 닉네임 형식이 틀렸을 때
  ///
  /// In ko, this message translates to:
  /// **'한글, 영문, 숫자로 2~10자로 정해 주세요'**
  String get nicknameInvalidFormat;

  /// 닉네임이 이미 있을 때
  ///
  /// In ko, this message translates to:
  /// **'이미 다른 사람이 쓰고 있어요'**
  String get nicknameTaken;

  /// 닉네임에 금칙어가 있을 때
  ///
  /// In ko, this message translates to:
  /// **'쓸 수 없는 말이 들어 있어요'**
  String get nicknameBannedWord;

  /// 닉네임이 운영진 사칭일 때
  ///
  /// In ko, this message translates to:
  /// **'운영진으로 오해할 수 있는 이름은 쓸 수 없어요'**
  String get nicknameImpersonation;

  /// 닉네임 미리보기 제목
  ///
  /// In ko, this message translates to:
  /// **'대국 화면에서는 이렇게 보여요'**
  String get nicknamePreviewLabel;

  /// 닉네임 미리보기의 급수와 전적 줄
  ///
  /// In ko, this message translates to:
  /// **'{rank} · 첫 대국'**
  String nicknamePreviewDetail(String rank);

  /// 닉네임을 정하는 버튼
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get nicknameStart;

  /// 빠른 대국으로 온 닉네임 정하기의 이어서 할 일 안내
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 바로 상대를 찾아요'**
  String get nicknameStartHintQuickMatch;

  /// 급수(급)
  ///
  /// In ko, this message translates to:
  /// **'{kyu}급'**
  String rankKyu(int kyu);

  /// 급수(단)
  ///
  /// In ko, this message translates to:
  /// **'{dan}단'**
  String rankDan(int dan);

  /// 로그인 창을 닫았을 때. 보통 보여주지 않는다
  ///
  /// In ko, this message translates to:
  /// **'로그인을 그만뒀어요'**
  String get errorSignInCanceled;

  /// 로그인 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'로그인하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorSignIn;

  /// 이메일 형식 오류
  ///
  /// In ko, this message translates to:
  /// **'이메일 주소를 다시 확인해 주세요'**
  String get errorInvalidEmail;

  /// 이메일 로그인 실패
  ///
  /// In ko, this message translates to:
  /// **'이메일 또는 비밀번호가 맞지 않아요'**
  String get errorWrongEmailOrPassword;

  /// 이메일 가입 시 이미 있는 이메일
  ///
  /// In ko, this message translates to:
  /// **'이미 가입한 이메일이에요. 로그인해 주세요'**
  String get errorEmailAlreadyInUse;

  /// 짧은 비밀번호
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 6자 이상으로 정해 주세요'**
  String get errorWeakPassword;

  /// 비밀번호를 넣지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 넣어 주세요'**
  String get errorPasswordEmpty;

  /// 비밀번호 확인이 다를 때
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 서로 달라요'**
  String get errorPasswordMismatch;

  /// 비밀번호 재설정 메일을 보낼 이메일이 없을 때
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 다시 정할 이메일을 넣어 주세요'**
  String get errorPasswordResetEmail;

  /// 비밀번호 재설정 메일 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'메일을 보내지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorPasswordReset;

  /// 요청이 너무 많을 때
  ///
  /// In ko, this message translates to:
  /// **'시도가 너무 많아요. 잠시 후 다시 해 주세요'**
  String get errorTooManyRequests;

  /// 네트워크 오류
  ///
  /// In ko, this message translates to:
  /// **'인터넷 연결을 확인해 주세요'**
  String get errorNetwork;

  /// 로그인 뒤 프로필 읽기 실패
  ///
  /// In ko, this message translates to:
  /// **'내 정보를 불러오지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorProfileLoad;

  /// 프로필 만들기 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 정하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorCreateProfile;

  /// 로그아웃 실패
  ///
  /// In ko, this message translates to:
  /// **'로그아웃하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorSignOut;

  /// 홈의 개발용 온라인 대국 카드 제목. 개발 빌드에만 보인다
  ///
  /// In ko, this message translates to:
  /// **'개발용 온라인 대국'**
  String get homeDevOnlineTitle;

  /// 홈의 개발용 온라인 대국 카드 설명
  ///
  /// In ko, this message translates to:
  /// **'상대 닉네임을 넣으면 두 계정의 대국을 바로 만들어요'**
  String get homeDevOnlineDescription;

  /// 개발용 온라인 대국의 상대 닉네임 입력 칸
  ///
  /// In ko, this message translates to:
  /// **'상대 닉네임'**
  String get homeDevOnlineOpponent;

  /// 개발용 온라인 대국을 만드는 버튼
  ///
  /// In ko, this message translates to:
  /// **'대국 만들기'**
  String get homeDevOnlineCreate;

  /// 진영 고르기. 무작위는 서버가 정한다
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{초} han{한} random{무작위} other{}}'**
  String sideChoiceName(String side);

  /// 온라인 대국 화면 위쪽 제목. count는 지금까지 둔 수
  ///
  /// In ko, this message translates to:
  /// **'온라인 대국 · {count}수'**
  String gameOnlineTitle(int count);

  /// 넓은 화면 대국 화면 오른쪽 패널의 대국 종류
  ///
  /// In ko, this message translates to:
  /// **'{mode, select, quick{빠른 대국} room{방 대국} challenge{신청 대국} other{}}'**
  String gameModeName(String mode);

  /// 넓은 화면 대국 화면 오른쪽 패널에서 급수에 반영되는 대국 표시
  ///
  /// In ko, this message translates to:
  /// **'급수 대국'**
  String get gameRated;

  /// 넓은 화면 대국 화면 오른쪽 패널의 시간 규칙
  ///
  /// In ko, this message translates to:
  /// **'기본 {minutes}분 · 초읽기 {seconds}초 {periods}회'**
  String gameTimeRule(int minutes, int seconds, int periods);

  /// 대국 정보 줄의 닉네임과 급수
  ///
  /// In ko, this message translates to:
  /// **'{nickname} · {rank}'**
  String playerNameWithRank(String nickname, String rank);

  /// 대국 시계 아래의 남은 초읽기 횟수
  ///
  /// In ko, this message translates to:
  /// **'초읽기 {count}회'**
  String clockPeriods(int count);

  /// 상차림 창의 남은 상차림 시간
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초'**
  String setupSeconds(int seconds);

  /// 상대가 상차림을 고르는 동안 상차림 창과 판 위에 보이는 안내
  ///
  /// In ko, this message translates to:
  /// **'상대가 상차림을 고르고 있어요'**
  String get setupOpponentChoosing;

  /// 온라인 대국 기권 확인
  ///
  /// In ko, this message translates to:
  /// **'기권할까요? 이 대국은 지게 돼요'**
  String get resignConfirmOnline;

  /// 개발용 온라인 대국 만들기 실패
  ///
  /// In ko, this message translates to:
  /// **'대국을 만들지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorCreateGame;

  /// 온라인 대국 듣기 실패
  ///
  /// In ko, this message translates to:
  /// **'대국을 불러오지 못했어요'**
  String get errorGameLoad;

  /// 수 보내기 실패
  ///
  /// In ko, this message translates to:
  /// **'수를 보내지 못했어요. 판을 서버와 다시 맞췄어요'**
  String get errorPlayMove;

  /// 상차림 보내기 실패
  ///
  /// In ko, this message translates to:
  /// **'상차림을 보내지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorSetFormation;

  /// 기권 실패
  ///
  /// In ko, this message translates to:
  /// **'기권하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorResign;

  /// 대국 서버 notFound
  ///
  /// In ko, this message translates to:
  /// **'상대나 대국을 찾지 못했어요'**
  String get errorGameNotFound;

  /// 대국 서버 busy
  ///
  /// In ko, this message translates to:
  /// **'이미 대국이나 대기 중인 사람이 있어요'**
  String get errorGameBusy;

  /// 대국 서버 notPlayer
  ///
  /// In ko, this message translates to:
  /// **'이 대국의 대국자가 아니에요'**
  String get errorGameNotPlayer;

  /// 대국 서버 notYourTurn
  ///
  /// In ko, this message translates to:
  /// **'지금은 내 차례가 아니에요'**
  String get errorGameNotYourTurn;

  /// 대국 서버 illegalMove
  ///
  /// In ko, this message translates to:
  /// **'둘 수 없는 수예요'**
  String get errorGameIllegalMove;

  /// 대국 서버 moveConflict
  ///
  /// In ko, this message translates to:
  /// **'판을 서버와 다시 맞췄어요'**
  String get errorGameMoveConflict;

  /// 대국 서버 gameOver
  ///
  /// In ko, this message translates to:
  /// **'이미 끝난 대국이에요'**
  String get errorGameOver;

  /// 대국 화면 판 위. 내 기기의 연결이 끊긴 동안
  ///
  /// In ko, this message translates to:
  /// **'다시 연결하는 중'**
  String get reconnecting;

  /// 홈 맨 위. 진행 중인 온라인 대국이 있을 때
  ///
  /// In ko, this message translates to:
  /// **'대국으로 돌아가기'**
  String get homeResumeGame;

  /// 홈 큰 버튼. 급수가 비슷한 상대와 바로 둔다
  ///
  /// In ko, this message translates to:
  /// **'빠른 대국'**
  String get homeQuickMatch;

  /// 내 카드와 대국 결과의 급수 진행 막대 옆. 비슷한 상대를 이길 때 다음 급수까지 필요한 어림 승수
  ///
  /// In ko, this message translates to:
  /// **'{rank}까지 약 {wins}승'**
  String rankWinsToNext(String rank, int wins);

  /// 빠른 대국 대기 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'상대를 찾고 있어요'**
  String get quickMatchSearching;

  /// 빠른 대국 대기 화면 제목 아래
  ///
  /// In ko, this message translates to:
  /// **'급수가 비슷한 상대와 바로 시작해요'**
  String get quickMatchSearchingDescription;

  /// 빠른 대국 대기 화면의 규칙 팁 제목
  ///
  /// In ko, this message translates to:
  /// **'장기 규칙'**
  String get quickMatchTipTitle;

  /// 빠른 대국 대기 화면의 규칙 팁. docs/game/rules.md의 내용만 쓴다
  ///
  /// In ko, this message translates to:
  /// **'{index, select, 0{초가 먼저 두고, 한은 덤 1.5점을 받아요} 1{한이 먼저 상차림을 정하고, 초는 한의 상차림을 본 뒤 정해요} 2{장군을 받은 상태에서는 한수쉼을 할 수 없어요} 3{같은 국면을 3번째로 만드는 수는 둘 수 없어요} other{양쪽이 연속으로 한수쉼을 하면 점수로 승부를 정해요}}'**
  String quickMatchTip(String index);

  /// 빠른 대국 대기 화면 맨 아래 버튼
  ///
  /// In ko, this message translates to:
  /// **'그만 찾기'**
  String get quickMatchStop;

  /// 빠른 대국 대기열 들어가기 실패
  ///
  /// In ko, this message translates to:
  /// **'상대를 찾지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorQuickMatch;

  /// 빠른 대국 그만 찾기 실패
  ///
  /// In ko, this message translates to:
  /// **'그만 찾지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorLeaveQuickMatch;

  /// 대국 서버 sanctioned
  ///
  /// In ko, this message translates to:
  /// **'이용이 제한되어 지금은 대국을 할 수 없어요'**
  String get errorSanctioned;

  /// 대국 서버 rematchUnavailable
  ///
  /// In ko, this message translates to:
  /// **'지금은 재대국을 할 수 없어요'**
  String get errorRematchUnavailable;

  /// 재대국 신청 실패
  ///
  /// In ko, this message translates to:
  /// **'재대국을 신청하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorRematch;

  /// 대국 결과. 내가 다시 두기를 누르고 상대를 기다릴 때 버튼
  ///
  /// In ko, this message translates to:
  /// **'상대를 기다리는 중'**
  String get resultRematchWaiting;

  /// 대국이 끝난 화면. 상대가 먼저 재대국을 신청했다
  ///
  /// In ko, this message translates to:
  /// **'상대가 재대국을 원해요'**
  String get resultRematchRequested;

  /// 대국이 끝난 화면. 상대가 화면을 나갔다
  ///
  /// In ko, this message translates to:
  /// **'상대가 나가서 재대국을 할 수 없어요'**
  String get resultRematchCancelled;

  /// 대국이 끝난 화면. 빠른 대국의 재대국 횟수에 닿았다
  ///
  /// In ko, this message translates to:
  /// **'같은 상대와는 더 둘 수 없어요'**
  String get resultRematchBlocked;

  /// 대국 결과. 급수가 올랐을 때
  ///
  /// In ko, this message translates to:
  /// **'{rank}으로 올랐어요'**
  String resultRankUp(String rank);

  /// 대국 결과. 급수가 내려갔을 때
  ///
  /// In ko, this message translates to:
  /// **'{rank}으로 내려갔어요'**
  String resultRankDown(String rank);

  /// 홈과 대국실의 방 만들기 버튼
  ///
  /// In ko, this message translates to:
  /// **'방 만들기'**
  String get homeCreateRoom;

  /// 홈 맨 위. 대국은 없고 방에 남아 있을 때
  ///
  /// In ko, this message translates to:
  /// **'방으로 돌아가기'**
  String get homeResumeRoom;

  /// 대국실 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'대국실'**
  String get lobbyTitle;

  /// 넓은 화면 왼쪽 메뉴의 홈
  ///
  /// In ko, this message translates to:
  /// **'홈'**
  String get menuHome;

  /// 대국실의 방 목록 제목
  ///
  /// In ko, this message translates to:
  /// **'방 목록'**
  String get lobbyRoomList;

  /// 대국실. 공개된 방이 없을 때
  ///
  /// In ko, this message translates to:
  /// **'지금 열린 방이 없어요'**
  String get lobbyEmpty;

  /// 대국실. 공개된 방이 없을 때의 안내
  ///
  /// In ko, this message translates to:
  /// **'방을 만들어 상대를 기다려 보세요'**
  String get lobbyEmptyDescription;

  /// 대국실 방 목록의 입장 버튼
  ///
  /// In ko, this message translates to:
  /// **'입장'**
  String get lobbyEnter;

  /// 불러오지 못한 목록을 다시 불러오는 버튼
  ///
  /// In ko, this message translates to:
  /// **'다시 불러오기'**
  String get retry;

  /// 로그인 창 제목. 방 만들기를 눌렀을 때
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 바로\n방을 만들 수 있어요'**
  String get loginSheetTitleCreateRoom;

  /// 로그인 창 제목. 대국실을 눌렀을 때
  ///
  /// In ko, this message translates to:
  /// **'로그인하고\n대국실에 들어가 보세요'**
  String get loginSheetTitleLobby;

  /// 로그인 창 제목. 초대 링크로 들어왔을 때
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 바로\n초대받은 방에 들어가요'**
  String get loginSheetTitleJoinRoom;

  /// 닉네임 정하기. 방 만들기를 눌러 가입했을 때
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 바로 방을 만들어요'**
  String get nicknameStartHintCreateRoom;

  /// 닉네임 정하기. 대국실을 눌러 가입했을 때
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 대국실로 가요'**
  String get nicknameStartHintLobby;

  /// 닉네임 정하기. 초대 링크로 들어와 가입했을 때
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 바로 방에 들어가요'**
  String get nicknameStartHintJoinRoom;

  /// 방 들어가기 실패. 자리가 찼을 때
  ///
  /// In ko, this message translates to:
  /// **'방에 빈자리가 없어요'**
  String get errorRoomFull;

  /// 방 들어가기 실패. 방장이 나가 방이 닫혔을 때
  ///
  /// In ko, this message translates to:
  /// **'닫힌 방이에요'**
  String get errorRoomClosed;

  /// 방 들어가기 실패. 방장이 내보낸 사람일 때
  ///
  /// In ko, this message translates to:
  /// **'이 방에는 다시 들어갈 수 없어요'**
  String get errorKicked;

  /// 방 들어가기 실패. 방의 급수 범위 밖일 때
  ///
  /// In ko, this message translates to:
  /// **'이 방에 들어갈 수 있는 급수가 아니에요'**
  String get errorRankOutOfRange;

  /// 방장만 할 수 있는 일을 했을 때
  ///
  /// In ko, this message translates to:
  /// **'방장만 할 수 있어요'**
  String get errorNotHost;

  /// 방 들어가기의 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'방에 들어가지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorJoinRoom;

  /// 방 만들기의 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'방을 만들지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorCreateRoom;

  /// 방 나가기의 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'방을 나가지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorLeaveRoom;

  /// 방장 내보내기의 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'내보내지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorKickGuest;

  /// 방 대국 시작의 기본 오류
  ///
  /// In ko, this message translates to:
  /// **'대국을 시작하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorStartRoomGame;

  /// 대국실 방 목록을 읽지 못했을 때
  ///
  /// In ko, this message translates to:
  /// **'방 목록을 불러오지 못했어요'**
  String get errorLoadRooms;

  /// 방 대기실에서 방을 읽지 못했을 때
  ///
  /// In ko, this message translates to:
  /// **'방을 불러오지 못했어요'**
  String get errorLoadRoom;

  /// 방 대기실의 공유하기가 실패했을 때
  ///
  /// In ko, this message translates to:
  /// **'공유하지 못했어요. 링크 복사를 써 주세요'**
  String get errorShareLink;

  /// 방 대기실 제목. nickname은 방장 닉네임
  ///
  /// In ko, this message translates to:
  /// **'{nickname}의 방'**
  String roomTitle(String nickname);

  /// 들어올 수 있는 급수를 제한하지 않을 때
  ///
  /// In ko, this message translates to:
  /// **'모든 급수'**
  String get rankRangeAll;

  /// 들어올 수 있는 급수 범위. min과 max는 18급, 1단 같은 급수
  ///
  /// In ko, this message translates to:
  /// **'{min} ~ {max}'**
  String rankRange(String min, String max);

  /// 기물 이름
  ///
  /// In ko, this message translates to:
  /// **'{type, select, chariot{차} cannon{포} horse{마} elephant{상} advisor{사} soldier{졸} king{궁} other{}}'**
  String pieceName(String type);

  /// 접장기 요약. pieces는 뗄 기물 이름 목록, points는 뗀 기물 점수 합
  ///
  /// In ko, this message translates to:
  /// **'{pieces} 떼기 · {points}점 적게 시작'**
  String handicapSummary(String pieces, int points);

  /// 방 조건 칩. 접장기 방
  ///
  /// In ko, this message translates to:
  /// **'접장기'**
  String get roomChipHandicap;

  /// 방 조건 칩. 접장기에서 기물을 떼는 쪽
  ///
  /// In ko, this message translates to:
  /// **'{remover, select, creator{방장이 떼요} opponent{상대가 떼요} other{}}'**
  String roomChipRemover(String remover);

  /// 방 조건 칩. 방장의 진영
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{방장 초} han{방장 한} random{진영 무작위} other{}}'**
  String roomChipSide(String side);

  /// 방 조건 칩. 방 목록에 공개한 방
  ///
  /// In ko, this message translates to:
  /// **'공개'**
  String get roomChipListed;

  /// 방 조건 칩. 링크로만 들어오는 방
  ///
  /// In ko, this message translates to:
  /// **'비공개'**
  String get roomChipUnlisted;

  /// 방 대기실의 방장 자리
  ///
  /// In ko, this message translates to:
  /// **'방장'**
  String get roomHost;

  /// 방 대기실의 상대 자리
  ///
  /// In ko, this message translates to:
  /// **'상대'**
  String get roomGuest;

  /// 방 대기실. 상대 자리가 비었을 때
  ///
  /// In ko, this message translates to:
  /// **'상대를 기다리고 있어요'**
  String get roomWaitingGuest;

  /// 방 대기실. 방장이 상대를 내보내는 버튼과 확인
  ///
  /// In ko, this message translates to:
  /// **'내보내기'**
  String get roomKick;

  /// 방 대기실. 내보내기 확인
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님을 내보낼까요? 이 방에 다시 들어올 수 없어요'**
  String roomKickConfirm(String nickname);

  /// 방 대기실. 초대 링크 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'초대 링크로 부르기'**
  String get roomInviteTitle;

  /// 방 대기실. 초대 링크 복사 버튼
  ///
  /// In ko, this message translates to:
  /// **'링크 복사'**
  String get roomCopyLink;

  /// 방 대기실. 휴대폰 공유 창(카카오톡 포함)으로 초대 링크를 보내는 버튼
  ///
  /// In ko, this message translates to:
  /// **'공유하기'**
  String get roomShareLink;

  /// 방 대기실. 링크를 복사한 뒤 알림
  ///
  /// In ko, this message translates to:
  /// **'링크를 복사했어요'**
  String get roomLinkCopied;

  /// 공유하기로 보내는 초대 글. link는 초대 링크
  ///
  /// In ko, this message translates to:
  /// **'장기고에서 장기 한 판 두실래요? {link}'**
  String roomInviteMessage(String link);

  /// 방 대기실. 방장의 대국 시작 버튼
  ///
  /// In ko, this message translates to:
  /// **'대국 시작'**
  String get roomStart;

  /// 방 대기실. 상대가 없어 대국 시작을 꺼 둘 때
  ///
  /// In ko, this message translates to:
  /// **'상대가 들어오면 시작할 수 있어요'**
  String get roomStartWaiting;

  /// 방 대기실. 상대에게 보이는 안내
  ///
  /// In ko, this message translates to:
  /// **'방장이 대국을 시작하면 바로 상차림으로 가요'**
  String get roomWaitingHost;

  /// 방 나가기 확인 버튼
  ///
  /// In ko, this message translates to:
  /// **'나가기'**
  String get roomLeave;

  /// 방 대기실. 방장이 나가기 전 확인
  ///
  /// In ko, this message translates to:
  /// **'방을 나가면 방이 닫혀요. 나갈까요?'**
  String get roomLeaveHostConfirm;

  /// 방 대기실. 방장이 나가 방이 닫혔을 때
  ///
  /// In ko, this message translates to:
  /// **'방이 닫혔어요'**
  String get roomClosedNotice;

  /// 방 대기실. 방장이 나를 내보냈을 때
  ///
  /// In ko, this message translates to:
  /// **'방장이 내보냈어요'**
  String get roomKickedNotice;

  /// 방 대기실. 연결이 오래 끊겨 서버가 자리를 비웠을 때
  ///
  /// In ko, this message translates to:
  /// **'연결이 오래 끊겨 방에서 나왔어요'**
  String get roomRemovedNotice;

  /// 방 만들기 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'방 만들기'**
  String get createRoomTitle;

  /// 방 만들기 화면 아래쪽 버튼
  ///
  /// In ko, this message translates to:
  /// **'방 만들기'**
  String get createRoomSubmit;

  /// 방 만들기. 내 진영 고르기 제목
  ///
  /// In ko, this message translates to:
  /// **'내 진영'**
  String get createRoomSide;

  /// 방 만들기. 접장기를 켜 진영 고르기를 끌 때
  ///
  /// In ko, this message translates to:
  /// **'떼는 쪽이 한을 잡아요'**
  String get createRoomHandicapSide;

  /// 방 만들기. 접장기 스위치
  ///
  /// In ko, this message translates to:
  /// **'접장기'**
  String get createRoomHandicap;

  /// 방 만들기. 접장기 스위치 설명
  ///
  /// In ko, this message translates to:
  /// **'한쪽이 기물을 떼고 둬요'**
  String get createRoomHandicapDescription;

  /// 방 만들기. 접장기에서 떼는 쪽 고르기 제목
  ///
  /// In ko, this message translates to:
  /// **'떼는 쪽'**
  String get createRoomRemover;

  /// 방 만들기. 접장기에서 떼는 쪽
  ///
  /// In ko, this message translates to:
  /// **'{remover, select, creator{나} opponent{상대} other{}}'**
  String handicapRemover(String remover);

  /// 방 만들기. 뗄 기물 고르기 제목
  ///
  /// In ko, this message translates to:
  /// **'뗄 기물'**
  String get createRoomPieces;

  /// 방 만들기. 접장기를 켰는데 뗄 기물을 고르지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'뗄 기물을 골라 주세요'**
  String get createRoomPiecesHint;

  /// 방 만들기. 화면 읽기 기능용 뗄 기물 이름. side는 왼쪽·오른쪽, piece는 기물 이름
  ///
  /// In ko, this message translates to:
  /// **'{side} {piece}'**
  String handicapPieceLabel(String side, String piece);

  /// 떼는 쪽이 자기 쪽에서 판을 볼 때의 왼쪽과 오른쪽
  ///
  /// In ko, this message translates to:
  /// **'{side, select, left{왼쪽} right{오른쪽} other{}}'**
  String boardSideName(String side);

  /// 방 만들기. 공개 여부 스위치
  ///
  /// In ko, this message translates to:
  /// **'방 목록에 공개'**
  String get createRoomListed;

  /// 방 만들기. 공개 방 설명
  ///
  /// In ko, this message translates to:
  /// **'방 목록에 보이고 누구나 들어올 수 있어요'**
  String get createRoomListedOn;

  /// 방 만들기. 비공개 방 설명
  ///
  /// In ko, this message translates to:
  /// **'초대 링크로만 들어올 수 있어요'**
  String get createRoomListedOff;

  /// 방 만들기. 공개 방의 급수 범위 제목
  ///
  /// In ko, this message translates to:
  /// **'들어올 수 있는 급수'**
  String get createRoomRankRange;

  /// 대국 결과. 방 대국에서 홈으로 대신 보여주는 버튼
  ///
  /// In ko, this message translates to:
  /// **'방 대기실로'**
  String get resultBackToRoom;

  /// 대국실 탭. 접속자 목록
  ///
  /// In ko, this message translates to:
  /// **'접속자'**
  String get lobbyTabUsers;

  /// 대국실 접속자 탭. 닉네임 검색 칸
  ///
  /// In ko, this message translates to:
  /// **'닉네임 검색'**
  String get onlineUsersSearch;

  /// 대국실 접속자 탭. 나를 뺀 접속자 수
  ///
  /// In ko, this message translates to:
  /// **'접속자 {count}명'**
  String onlineUsersCount(int count);

  /// 대국실 접속자 탭. 내 대국 신청 받기 스위치
  ///
  /// In ko, this message translates to:
  /// **'신청 받기'**
  String get onlineUsersChallengesEnabled;

  /// 접속자의 상태
  ///
  /// In ko, this message translates to:
  /// **'{status, select, waiting{기다리는 중} playing{대국 중} notAccepting{신청 받지 않음} other{}}'**
  String onlineStatus(String status);

  /// 대국실 접속자 탭. 기다리는 사람의 신청 버튼
  ///
  /// In ko, this message translates to:
  /// **'신청'**
  String get onlineUsersChallenge;

  /// 대국실 접속자 탭. 나 말고 접속자가 없을 때
  ///
  /// In ko, this message translates to:
  /// **'지금 접속한 사람이 없어요'**
  String get onlineUsersEmpty;

  /// 대국실 접속자 탭. 검색 결과가 없을 때
  ///
  /// In ko, this message translates to:
  /// **'찾는 닉네임이 없어요'**
  String get onlineUsersNoMatch;

  /// 대국실 접속자 탭. 목록 읽기 실패
  ///
  /// In ko, this message translates to:
  /// **'접속자를 불러오지 못했어요'**
  String get errorLoadOnlineUsers;

  /// 신청 받기 스위치 쓰기 실패
  ///
  /// In ko, this message translates to:
  /// **'신청 받기를 바꾸지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorChallengesEnabled;

  /// 다른 사용자 정보. 대국 신청 버튼
  ///
  /// In ko, this message translates to:
  /// **'대국 신청'**
  String get userInfoChallenge;

  /// 다른 사용자 정보. 차단 버튼
  ///
  /// In ko, this message translates to:
  /// **'차단'**
  String get userInfoBlock;

  /// 차단 확인
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님을 차단할까요? 이 사람의 메시지와 대국 신청이 보이지 않아요'**
  String blockConfirm(String nickname);

  /// 차단 확인 창의 차단 버튼
  ///
  /// In ko, this message translates to:
  /// **'차단하기'**
  String get blockAction;

  /// 차단한 뒤 알림
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님을 차단했어요'**
  String blockDone(String nickname);

  /// 차단 실패
  ///
  /// In ko, this message translates to:
  /// **'차단하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorBlock;

  /// 신청 보내기 창 제목
  ///
  /// In ko, this message translates to:
  /// **'대국 신청'**
  String get challengeTitle;

  /// 신청 보내기. 내 진영 제목
  ///
  /// In ko, this message translates to:
  /// **'내 진영'**
  String get challengeSide;

  /// 신청 보내기 버튼
  ///
  /// In ko, this message translates to:
  /// **'신청 보내기'**
  String get challengeSubmit;

  /// 신청 보내기. 응답을 기다리는 중
  ///
  /// In ko, this message translates to:
  /// **'상대의 응답을 기다리고 있어요'**
  String get challengeWaiting;

  /// 신청 보내기. 기다리는 동안의 취소 버튼
  ///
  /// In ko, this message translates to:
  /// **'신청 취소'**
  String get challengeCancel;

  /// 신청 보내기. 거절됐을 때
  ///
  /// In ko, this message translates to:
  /// **'상대가 신청을 거절했어요'**
  String get challengeDeclined;

  /// 신청 보내기. 응답 시간이 지났을 때
  ///
  /// In ko, this message translates to:
  /// **'상대가 응답하지 않았어요'**
  String get challengeExpired;

  /// 신청 보내기. 취소됐을 때(방 초대에서 방이 찼을 때 등)
  ///
  /// In ko, this message translates to:
  /// **'신청이 취소됐어요'**
  String get challengeCancelled;

  /// 신청 보내기 실패
  ///
  /// In ko, this message translates to:
  /// **'신청을 보내지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorSendChallenge;

  /// 신청 취소 실패
  ///
  /// In ko, this message translates to:
  /// **'신청을 취소하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorCancelChallenge;

  /// 연속 거절 제한
  ///
  /// In ko, this message translates to:
  /// **'이 상대에게 여러 번 거절되어 잠시 신청할 수 없어요'**
  String get errorChallengeLimited;

  /// 상대가 대국실에 없거나, 대국 중이거나, 신청을 받지 않거나, 다른 신청을 받고 있을 때
  ///
  /// In ko, this message translates to:
  /// **'상대가 지금은 신청을 받을 수 없어요'**
  String get errorTargetUnavailable;

  /// 방 대기실. 접속자 초대 카드 제목과 버튼
  ///
  /// In ko, this message translates to:
  /// **'접속자 초대하기'**
  String get roomInviteUsers;

  /// 방 대기실. 접속자 초대 설명
  ///
  /// In ko, this message translates to:
  /// **'대국실에 있는 사람을 골라 이 방으로 불러요'**
  String get roomInviteUsersDescription;

  /// 방 초대 보내기 창 설명
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님을 이 방에 초대해요'**
  String roomInviteConfirm(String nickname);

  /// 방 초대 보내기 버튼
  ///
  /// In ko, this message translates to:
  /// **'초대 보내기'**
  String get roomInviteSubmit;

  /// 신청 받음 팝업 제목
  ///
  /// In ko, this message translates to:
  /// **'대국 신청이 왔어요'**
  String get incomingChallenge;

  /// 신청 받음 팝업 제목. 방 초대
  ///
  /// In ko, this message translates to:
  /// **'방 초대가 왔어요'**
  String get incomingRoomInvite;

  /// 신청 조건 칩. 받는 사람 기준 내 진영
  ///
  /// In ko, this message translates to:
  /// **'{side, select, cho{나는 초} han{나는 한} random{진영 무작위} other{}}'**
  String challengeChipMySide(String side);

  /// 신청 조건 칩. 받는 사람 기준 떼는 쪽
  ///
  /// In ko, this message translates to:
  /// **'{remover, select, me{내가 떼요} opponent{상대가 떼요} other{}}'**
  String challengeChipRemover(String remover);

  /// 신청 받음 팝업. 수락 버튼
  ///
  /// In ko, this message translates to:
  /// **'수락'**
  String get challengeAccept;

  /// 신청 받음 팝업. 거절 버튼
  ///
  /// In ko, this message translates to:
  /// **'거절'**
  String get challengeDecline;

  /// 응답하려던 신청이 마감됐거나 취소됐을 때
  ///
  /// In ko, this message translates to:
  /// **'이미 끝난 신청이에요'**
  String get challengeEnded;

  /// 신청 응답 실패
  ///
  /// In ko, this message translates to:
  /// **'신청에 응답하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorRespondChallenge;

  /// 방 대기실의 접속자 초대하기. 기다리는 사람의 초대 버튼
  ///
  /// In ko, this message translates to:
  /// **'초대'**
  String get onlineUsersInvite;

  /// 왼쪽 메뉴와 관전 목록 제목
  ///
  /// In ko, this message translates to:
  /// **'관전'**
  String get menuSpectate;

  /// 관전 목록 위. 목록에 보이는 대국 수
  ///
  /// In ko, this message translates to:
  /// **'진행 중인 대국 {count}개'**
  String spectateGameCount(int count);

  /// 관전 목록이 비었을 때
  ///
  /// In ko, this message translates to:
  /// **'지금 볼 수 있는 대국이 없어요'**
  String get spectateEmpty;

  /// 관전 목록이 비었을 때 안내
  ///
  /// In ko, this message translates to:
  /// **'대국이 시작되면 여기에 보여요'**
  String get spectateEmptyDescription;

  /// 관전 목록 읽기 실패
  ///
  /// In ko, this message translates to:
  /// **'관전 목록을 불러오지 못했어요'**
  String get errorLoadSpectateList;

  /// 관전 카드의 관전자 수
  ///
  /// In ko, this message translates to:
  /// **'{count}명'**
  String spectatorCount(int count);

  /// 관전 카드의 몇 수째
  ///
  /// In ko, this message translates to:
  /// **'{count}수째'**
  String spectateMoveCount(int count);

  /// 관전 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'관전 · {count}명 보는 중'**
  String spectateTitle(int count);

  /// 관전 화면의 관전 채팅 버튼
  ///
  /// In ko, this message translates to:
  /// **'관전 채팅'**
  String get spectateChat;

  /// 관전 화면. 상차림 중
  ///
  /// In ko, this message translates to:
  /// **'대국자가 상차림을 고르고 있어요'**
  String get spectateSetup;

  /// 관전하려던 대국이 지워졌을 때
  ///
  /// In ko, this message translates to:
  /// **'이미 끝난 대국이에요'**
  String get spectateGameGone;

  /// 관전 권하기 확인 버튼
  ///
  /// In ko, this message translates to:
  /// **'관전하기'**
  String get spectateAction;

  /// 링크로 들어가려던 방이 대국 중일 때 관전 권하기
  ///
  /// In ko, this message translates to:
  /// **'지금 대국 중인 방이에요. 관전할까요?'**
  String get spectateRoomPlaying;

  /// 홈의 관전 카드 제목
  ///
  /// In ko, this message translates to:
  /// **'지금 볼 만한 대국'**
  String get homeSpectateTitle;

  /// 홈의 최근 내 대국 제목
  ///
  /// In ko, this message translates to:
  /// **'최근 내 대국'**
  String get homeRecentGamesTitle;

  /// 홈의 최근 내 대국에서 내 기보 목록으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'전체 보기'**
  String get homeRecentGamesAll;

  /// 대국실에 열린 방이 없을 때 관전 목록 제목
  ///
  /// In ko, this message translates to:
  /// **'진행 중인 대국을 구경해 보세요'**
  String get lobbySpectateTitle;

  /// 채팅 버튼과 대국실 채팅 탭
  ///
  /// In ko, this message translates to:
  /// **'채팅'**
  String get chat;

  /// 채팅 고르기 칩. 대국실 채팅
  ///
  /// In ko, this message translates to:
  /// **'로비 채팅'**
  String get chatLobby;

  /// 채팅 고르기 칩. 두 대국자의 채팅
  ///
  /// In ko, this message translates to:
  /// **'대국 채팅'**
  String get chatGame;

  /// 채팅 창을 처음 열 때 한 번 보여주는 안내
  ///
  /// In ko, this message translates to:
  /// **'메시지를 길게 누르면 신고·차단할 수 있어요'**
  String get chatLongPressHint;

  /// 채팅에 메시지가 없을 때
  ///
  /// In ko, this message translates to:
  /// **'아직 메시지가 없어요'**
  String get chatEmpty;

  /// 채팅 입력칸 안내
  ///
  /// In ko, this message translates to:
  /// **'메시지를 입력하세요'**
  String get chatInputHint;

  /// 채팅 보내기 버튼의 화면 읽기 이름
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get chatSend;

  /// 로그인하지 않은 관전자에게 채팅 대신 보여주는 안내
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 채팅할 수 있어요'**
  String get chatLoginGuide;

  /// 대국 채팅에서 상대 메시지를 숨기는 버튼
  ///
  /// In ko, this message translates to:
  /// **'상대 채팅 끄기'**
  String get chatOpponentMute;

  /// 숨긴 상대 메시지를 다시 보여주는 버튼
  ///
  /// In ko, this message translates to:
  /// **'상대 채팅 켜기'**
  String get chatOpponentUnmute;

  /// 메시지를 길게 누른 메뉴의 신고
  ///
  /// In ko, this message translates to:
  /// **'신고하기'**
  String get chatReport;

  /// 신고한 뒤 채팅에 보여주는 안내
  ///
  /// In ko, this message translates to:
  /// **'신고했어요. 운영진이 확인할게요'**
  String get chatReportDone;

  /// 신고 실패
  ///
  /// In ko, this message translates to:
  /// **'신고하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorChatReport;

  /// 채팅 메시지 보내기 실패
  ///
  /// In ko, this message translates to:
  /// **'메시지를 보내지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorChatSend;

  /// 검사에 걸려 보내지 않은 메시지 안내
  ///
  /// In ko, this message translates to:
  /// **'부적절한 표현이 있습니다'**
  String get errorChatMessageBlocked;

  /// 채팅 제한이나 이용 정지 중일 때
  ///
  /// In ko, this message translates to:
  /// **'이용이 제한되어 지금은 채팅할 수 없어요'**
  String get errorChatRestricted;

  /// 로그인 창 제목. 관전 채팅을 열 때
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 관전하면서\n채팅할 수 있어요'**
  String get loginSheetTitleSpectateChat;

  /// 닉네임 정하기. 관전 채팅에서 가입했을 때
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 관전 채팅으로 돌아가요'**
  String get nicknameStartHintSpectateChat;

  /// 차단 목록 화면 제목과 홈 내 카드의 버튼
  ///
  /// In ko, this message translates to:
  /// **'차단 목록'**
  String get blockListTitle;

  /// 차단 목록 위 안내
  ///
  /// In ko, this message translates to:
  /// **'차단한 사람의 채팅 메시지와 대국 신청은 보이지 않아요'**
  String get blockListGuide;

  /// 차단 목록이 비었을 때
  ///
  /// In ko, this message translates to:
  /// **'차단한 사람이 없어요'**
  String get blockListEmpty;

  /// 차단 목록의 차단 풀기 버튼
  ///
  /// In ko, this message translates to:
  /// **'차단 풀기'**
  String get blockListUnblock;

  /// 차단 목록 읽기 실패
  ///
  /// In ko, this message translates to:
  /// **'차단 목록을 불러오지 못했어요'**
  String get errorLoadBlocks;

  /// 차단 풀기 실패
  ///
  /// In ko, this message translates to:
  /// **'차단을 풀지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorUnblock;

  /// 프로필을 찾지 못한 사용자
  ///
  /// In ko, this message translates to:
  /// **'탈퇴한 사용자'**
  String get deletedUser;

  /// 차단 목록의 차단한 날짜
  ///
  /// In ko, this message translates to:
  /// **'{date} 차단'**
  String blockListDate(DateTime date);

  /// 왼쪽 메뉴와 홈 버튼의 기보(내 기보 목록)
  ///
  /// In ko, this message translates to:
  /// **'기보'**
  String get menuRecords;

  /// 왼쪽 메뉴와 홈 버튼의 내 정보
  ///
  /// In ko, this message translates to:
  /// **'내 정보'**
  String get menuProfile;

  /// 로그인 창 제목. 기보를 눌렀을 때
  ///
  /// In ko, this message translates to:
  /// **'로그인하면\n내 기보를 볼 수 있어요'**
  String get loginSheetTitleRecords;

  /// 로그인 창 제목. 내 정보를 눌렀을 때
  ///
  /// In ko, this message translates to:
  /// **'로그인하면\n급수와 전적을 볼 수 있어요'**
  String get loginSheetTitleProfile;

  /// 닉네임 정하기. 기보를 눌러 가입했을 때
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 내 기보로 가요'**
  String get nicknameStartHintRecords;

  /// 닉네임 정하기. 내 정보를 눌러 가입했을 때
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 내 정보로 가요'**
  String get nicknameStartHintProfile;

  /// 내 기보 목록 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'내 기보'**
  String get recordsTitle;

  /// 내 기보 목록 위쪽의 연구용 판 버튼
  ///
  /// In ko, this message translates to:
  /// **'새 판에서 놓아보기'**
  String get recordsFreePlay;

  /// 내 기보 목록이 비었을 때
  ///
  /// In ko, this message translates to:
  /// **'아직 끝난 대국이 없어요'**
  String get recordsEmpty;

  /// 내 기보 목록의 날짜 묶음
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get recordsToday;

  /// 내 기보 목록의 날짜 묶음
  ///
  /// In ko, this message translates to:
  /// **'어제'**
  String get recordsYesterday;

  /// 내 기보 목록의 날짜 묶음. 어제보다 앞
  ///
  /// In ko, this message translates to:
  /// **'{date}'**
  String recordsDate(DateTime date);

  /// 기보의 수
  ///
  /// In ko, this message translates to:
  /// **'{count}수'**
  String recordsMoveCount(int count);

  /// 기보의 승패 표시. 이긴 판
  ///
  /// In ko, this message translates to:
  /// **'승'**
  String get recordsWin;

  /// 기보의 승패 표시. 진 판
  ///
  /// In ko, this message translates to:
  /// **'패'**
  String get recordsLoss;

  /// 내 기보 목록 맨 아래의 다음 쪽 불러오기
  ///
  /// In ko, this message translates to:
  /// **'더 보기'**
  String get recordsLoadMore;

  /// 내 기보 목록 읽기 실패
  ///
  /// In ko, this message translates to:
  /// **'기보를 불러오지 못했어요'**
  String get errorLoadRecords;

  /// 새 판에서 놓아보기 창의 안내
  ///
  /// In ko, this message translates to:
  /// **'접장기로 두려면 한에서 뗄 기물을 골라 주세요'**
  String get freePlayHandicapGuide;

  /// 새 판에서 놓아보기 창의 시작 버튼
  ///
  /// In ko, this message translates to:
  /// **'상차림 고르기'**
  String get freePlayStart;

  /// 내 정보의 닉네임 옆 연필 버튼
  ///
  /// In ko, this message translates to:
  /// **'닉네임 바꾸기'**
  String get profileEditNickname;

  /// 내 정보 프로필 카드의 오늘 전적
  ///
  /// In ko, this message translates to:
  /// **'오늘 {wins}승 {losses}패'**
  String profileToday(int wins, int losses);

  /// 내 정보의 전적 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'전적'**
  String get profileStatsTitle;

  /// 내 정보 전적의 대국 수
  ///
  /// In ko, this message translates to:
  /// **'대국 수'**
  String get profileGames;

  /// 내 정보 전적의 승
  ///
  /// In ko, this message translates to:
  /// **'승'**
  String get profileWins;

  /// 내 정보 전적의 패
  ///
  /// In ko, this message translates to:
  /// **'패'**
  String get profileLosses;

  /// 내 정보 전적의 승률
  ///
  /// In ko, this message translates to:
  /// **'승률'**
  String get profileWinRate;

  /// 승률 값
  ///
  /// In ko, this message translates to:
  /// **'{rate}%'**
  String winRateValue(int rate);

  /// 내 정보 전적의 최근 승패
  ///
  /// In ko, this message translates to:
  /// **'최근 10판'**
  String get profileRecent;

  /// 내 정보에 최근 대국이 없을 때
  ///
  /// In ko, this message translates to:
  /// **'아직 둔 대국이 없어요'**
  String get profileRecentEmpty;

  /// 내 정보에서 내 기보 목록으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'기보 전체 보기'**
  String get profileAllRecords;

  /// 전적 읽기 실패
  ///
  /// In ko, this message translates to:
  /// **'전적을 불러오지 못했어요'**
  String get errorLoadStats;

  /// 닉네임 바꾸기 화면의 버튼
  ///
  /// In ko, this message translates to:
  /// **'바꾸기'**
  String get nicknameChangeSubmit;

  /// 닉네임 바꾸기 버튼 위 안내
  ///
  /// In ko, this message translates to:
  /// **'바꾸면 {days}일 동안 다시 바꿀 수 없어요'**
  String nicknameChangeHint(int days);

  /// 닉네임 바꾸기에서 지금 닉네임을 그대로 넣었을 때
  ///
  /// In ko, this message translates to:
  /// **'지금 쓰는 닉네임이에요'**
  String get nicknameSame;

  /// 닉네임을 바꾼 지 7일이 지나지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'{date}부터 다시 바꿀 수 있어요'**
  String nicknameChangeAvailableAt(DateTime date);

  /// 서버가 7일 제한으로 거절했을 때
  ///
  /// In ko, this message translates to:
  /// **'닉네임은 바꾼 뒤 7일 동안 다시 바꿀 수 없어요'**
  String get errorNicknameChangeCooldown;

  /// 화면을 연 뒤 다른 기기에서 무료 변경을 써서 서버가 값 없는 변경을 거절했을 때
  ///
  /// In ko, this message translates to:
  /// **'무료 닉네임 변경을 이미 썼어요. 다시 열어 주세요'**
  String get errorNicknameChangeNotFree;

  /// 화면에 보여준 엽전 값과 서버 값이 다를 때
  ///
  /// In ko, this message translates to:
  /// **'값이 바뀌었어요. 다시 열어 주세요'**
  String get errorCoinPriceChanged;

  /// 서버가 엽전이 모자라 거절했을 때
  ///
  /// In ko, this message translates to:
  /// **'엽전이 모자라요'**
  String get errorCoinsInsufficient;

  /// 상대의 엽전이 참가비보다 적어 대국을 시작하지 못할 때
  ///
  /// In ko, this message translates to:
  /// **'상대의 엽전이 모자라요'**
  String get errorOpponentCoinsInsufficient;

  /// 두 번째 닉네임 변경에 엽전이 모자랄 때
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 바꾸려면 {cost}엽전이 필요해요. 지금 {balance}엽전이 있어요'**
  String nicknameChangeNeedCoins(int cost, int balance);

  /// 유료 닉네임 바꾸기 버튼 위 안내
  ///
  /// In ko, this message translates to:
  /// **'{cost}엽전을 내고 바꿔요. 바꾸면 {days}일 동안 다시 바꿀 수 없어요'**
  String nicknameChangePaidHint(int cost, int days);

  /// 유료 닉네임 바꾸기 확인
  ///
  /// In ko, this message translates to:
  /// **'{cost}엽전을 내고 {nickname}(으)로 바꿀까요?'**
  String nicknameChangeConfirm(int cost, String nickname);

  /// 홈 내 카드의 엽전 잔액 숫자
  ///
  /// In ko, this message translates to:
  /// **'{amount}'**
  String coinBalanceAmount(int amount);

  /// 엽전 잔액의 화면 낭독 문구
  ///
  /// In ko, this message translates to:
  /// **'엽전 {amount}개'**
  String coinBalanceLabel(int amount);

  /// 출석 엽전을 받은 뒤 알림
  ///
  /// In ko, this message translates to:
  /// **'출석 +{amount}엽전'**
  String coinAttendanceGranted(int amount);

  /// 닉네임 바꾸기 실패
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 바꾸지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorChangeNickname;

  /// 닉네임을 바꾼 뒤 알림
  ///
  /// In ko, this message translates to:
  /// **'닉네임을 바꿨어요'**
  String get nicknameChanged;

  /// 다른 사용자 정보의 대국 수와 승률
  ///
  /// In ko, this message translates to:
  /// **'{games}판 · 승률 {rate}%'**
  String userInfoStats(int games, int rate);

  /// 다른 사용자 정보의 나와의 전적
  ///
  /// In ko, this message translates to:
  /// **'나와의 전적 {wins}승 {losses}패'**
  String userInfoHeadToHead(int wins, int losses);

  /// 다른 사용자 정보. 나와 둔 대국이 없을 때
  ///
  /// In ko, this message translates to:
  /// **'나와 둔 대국이 없어요'**
  String get userInfoHeadToHeadEmpty;

  /// 기보의 결과 종류와 수
  ///
  /// In ko, this message translates to:
  /// **'{reason} · {count}수'**
  String recordsDetail(String reason, int count);

  /// 제재 팝업 제목. 경고
  ///
  /// In ko, this message translates to:
  /// **'경고를 받았어요'**
  String get sanctionTitleWarning;

  /// 제재 팝업 제목. 채팅 제한
  ///
  /// In ko, this message translates to:
  /// **'채팅이 제한되었어요'**
  String get sanctionTitleChatRestriction;

  /// 제재 팝업 제목. 이용 정지
  ///
  /// In ko, this message translates to:
  /// **'이용이 정지되었어요'**
  String get sanctionTitleSuspension;

  /// 제재 팝업 제목. 영구 정지
  ///
  /// In ko, this message translates to:
  /// **'계정 이용이 영구 정지되었어요'**
  String get sanctionTitlePermanentBan;

  /// 제재 팝업 제목. 앱이 모르는 제재 종류
  ///
  /// In ko, this message translates to:
  /// **'이용이 제한되었어요'**
  String get sanctionTitleUnknown;

  /// 제재 팝업 설명. 경고
  ///
  /// In ko, this message translates to:
  /// **'같은 일이 반복되면 채팅이나 이용이 제한될 수 있어요'**
  String get sanctionDescriptionWarning;

  /// 제재 팝업 설명. 채팅 제한
  ///
  /// In ko, this message translates to:
  /// **'제한이 끝날 때까지 채팅을 할 수 없어요'**
  String get sanctionDescriptionChatRestriction;

  /// 제재 팝업 설명. 이용 정지
  ///
  /// In ko, this message translates to:
  /// **'정지가 끝날 때까지 대국과 채팅을 할 수 없어요'**
  String get sanctionDescriptionSuspension;

  /// 제재 팝업 설명. 영구 정지와 모르는 제재
  ///
  /// In ko, this message translates to:
  /// **'대국과 채팅을 할 수 없어요'**
  String get sanctionDescriptionPermanentBan;

  /// 제재 팝업의 사유. 관리자가 적은 글
  ///
  /// In ko, this message translates to:
  /// **'사유: {reason}'**
  String sanctionReason(String reason);

  /// 제재 팝업의 끝나는 날과 시각
  ///
  /// In ko, this message translates to:
  /// **'끝나는 때: {date} {time}'**
  String sanctionEndsAt(DateTime date, DateTime time);

  /// 제재 팝업의 이의 제기 안내
  ///
  /// In ko, this message translates to:
  /// **'이의가 있으면 {email}로 메일을 보내 주세요'**
  String sanctionAppeal(String email);

  /// 대국이 끝난 화면. 상대가 먼저 재대국을 신청했을 때의 버튼
  ///
  /// In ko, this message translates to:
  /// **'재대국 수락'**
  String get resultRematchAccept;

  /// 대국 결과 도장의 글자(이겼을 때). 붓글씨 글꼴로 크게 찍는다
  ///
  /// In ko, this message translates to:
  /// **'승'**
  String get resultStampWin;

  /// 대국 결과 도장의 글자(졌을 때)
  ///
  /// In ko, this message translates to:
  /// **'패'**
  String get resultStampLoss;

  /// 대국이 끝난 화면 머리줄의 결과 칩. 예: 승리 · 외통승
  ///
  /// In ko, this message translates to:
  /// **'{outcome} · {reason}'**
  String resultHeadline(String outcome, String reason);

  /// 결과 도장 아래 칩. 결과 종류, 수, 걸린 시간
  ///
  /// In ko, this message translates to:
  /// **'{reason} · {moves}수 · {minutes}분 {seconds}초'**
  String resultStampDetail(String reason, int moves, int minutes, int seconds);

  /// 대국이 끝난 화면 내 정보 줄. 급수 진행이 늘었다
  ///
  /// In ko, this message translates to:
  /// **'+1칸'**
  String get resultRankGain;

  /// 대국이 끝난 화면 내 정보 줄. 급수 진행이 줄었다
  ///
  /// In ko, this message translates to:
  /// **'−1칸'**
  String get resultRankLoss;

  /// 대국이 끝난 화면 내 정보 줄. 져서 진행이 줄었지만 급수는 그대로다
  ///
  /// In ko, this message translates to:
  /// **'{rank} 유지'**
  String resultRankKept(String rank);

  /// 대국이 끝난 화면의 복기 막대 가운데. 지금 보는 수와 전체 수
  ///
  /// In ko, this message translates to:
  /// **'복기 {current} / {total}수'**
  String reviewBarCounter(int current, int total);

  /// 대국이 끝난 뒤 상대가 대국 화면을 나가 대국 채팅을 더 할 수 없다
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님이 나갔어요'**
  String chatOpponentLeft(String nickname);

  /// 채팅. 전송에 실패한 내 메시지 옆 표시
  ///
  /// In ko, this message translates to:
  /// **'전송실패'**
  String get chatNotSent;

  /// 대국 화면 채팅 미리보기 줄. 메시지가 아직 없을 때
  ///
  /// In ko, this message translates to:
  /// **'채팅'**
  String get chatPreviewHint;

  /// 대국 화면 판 가운데 카드. 대국자의 연결이 끊겼다
  ///
  /// In ko, this message translates to:
  /// **'{nickname}님 연결이 끊겼어요'**
  String disconnectCardTitle(String nickname);

  /// 대국 화면 판 가운데 카드. 끊긴 쪽이 남은 끊김 허용 시간 안에 돌아오지 않으면 진다
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초 안에 돌아오지 않으면 {winner}님의 승리로 끝나요'**
  String disconnectCardBody(int seconds, String winner);

  /// 내 정보 메뉴와 설정 화면 제목
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get menuSettings;

  /// 설정 화면의 언어 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settingsLanguage;

  /// 설정의 언어 선택지. 기기 언어를 따른다
  ///
  /// In ko, this message translates to:
  /// **'기기 설정 따름'**
  String get languageSystem;

  /// 설정의 언어 선택지. 언어 이름은 그 언어로 쓴다
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// 설정의 언어 선택지. 언어 이름은 그 언어로 쓴다
  ///
  /// In ko, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// 설정 저장 실패
  ///
  /// In ko, this message translates to:
  /// **'설정을 저장하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorSaveSettings;

  /// 놓아보기 막대 맨 오른쪽 버튼. 원래 기보 위치로 돌아간다
  ///
  /// In ko, this message translates to:
  /// **'끝내기'**
  String get reviewTrialEnd;

  /// 놓아보기 막대 가운데. 놓아보기를 시작한 자리에서 둔 수
  ///
  /// In ko, this message translates to:
  /// **'놓아보기 {count}수'**
  String reviewTrialMoves(int count);

  /// 폭이 좁아 놓아보기 막대 가운데에 전체 문구가 들어가지 않을 때 쓰는 짧은 표시
  ///
  /// In ko, this message translates to:
  /// **'{count}수'**
  String reviewTrialMovesShort(int count);

  /// 둘 수 없는 수를 누른 이유. 장군을 받은 상태에서 막지 못하는 수
  ///
  /// In ko, this message translates to:
  /// **'장군을 막아야 합니다'**
  String get moveRejectedMustStopCheck;

  /// 둘 수 없는 수를 누른 이유. 두면 내 궁이 장군을 받게 되는 수
  ///
  /// In ko, this message translates to:
  /// **'궁이 장군을 받습니다'**
  String get moveRejectedExposesGeneral;

  /// 둘 수 없는 수를 누른 이유. 반복수 금지
  ///
  /// In ko, this message translates to:
  /// **'반복수입니다'**
  String get moveRejectedRepetition;

  /// 대국 버튼 줄의 시간 연장 버튼
  ///
  /// In ko, this message translates to:
  /// **'시간 연장'**
  String get gameTimeExtension;

  /// 대국 버튼 줄의 대국 중 놓아보기 버튼
  ///
  /// In ko, this message translates to:
  /// **'놓아보기'**
  String get gamePractice;

  /// 시간 연장 확인 창
  ///
  /// In ko, this message translates to:
  /// **'{cost}엽전을 내고 초읽기를 {periods}회 늘릴까요?'**
  String timeExtensionConfirm(int cost, int periods);

  /// 시간 연장 확인 창의 버튼
  ///
  /// In ko, this message translates to:
  /// **'연장하기'**
  String get timeExtensionAction;

  /// 대국 중 놓아보기 확인 창
  ///
  /// In ko, this message translates to:
  /// **'{cost}엽전을 내면 이 판 내내 놓아보기를 쓸 수 있어요'**
  String gamePracticeConfirm(int cost);

  /// 상대가 시간을 연장했을 때 판 위에 잠깐 보여주는 알림
  ///
  /// In ko, this message translates to:
  /// **'상대가 시간을 연장했어요'**
  String get opponentExtendedTime;

  /// 시간 연장에 실패했을 때
  ///
  /// In ko, this message translates to:
  /// **'시간을 연장하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorTimeExtension;

  /// 대국 중 놓아보기 결제에 실패했을 때
  ///
  /// In ko, this message translates to:
  /// **'놓아보기를 열지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorGamePractice;

  /// 서버가 시간 연장 횟수에 닿아 거절했을 때
  ///
  /// In ko, this message translates to:
  /// **'시간 연장을 더 쓸 수 없어요'**
  String get errorExtensionLimit;

  /// 운영 스위치로 멈춘 기능을 눌렀을 때
  ///
  /// In ko, this message translates to:
  /// **'지금은 쓸 수 없어요'**
  String get errorFeatureDisabled;

  /// 아래쪽 탭과 왼쪽 메뉴의 대국실
  ///
  /// In ko, this message translates to:
  /// **'대국실'**
  String get menuLobby;

  /// 상점 아이콘과 왼쪽 메뉴
  ///
  /// In ko, this message translates to:
  /// **'상점'**
  String get menuStore;

  /// 설정의 대국 묶음
  ///
  /// In ko, this message translates to:
  /// **'대국'**
  String get settingsGameGroup;

  /// 설정의 효과음 켜기·끄기
  ///
  /// In ko, this message translates to:
  /// **'소리'**
  String get settingsSound;

  /// 설정의 진동 켜기·끄기
  ///
  /// In ko, this message translates to:
  /// **'진동'**
  String get settingsVibration;

  /// 설정의 대국 신청 받기. 대국실 접속자 탭의 스위치와 같은 설정
  ///
  /// In ko, this message translates to:
  /// **'대국 신청 받기'**
  String get settingsChallengesEnabled;

  /// 설정의 계정 묶음
  ///
  /// In ko, this message translates to:
  /// **'계정'**
  String get settingsAccountGroup;

  /// 설정의 계정 묶음에 보여주는 로그인 방식
  ///
  /// In ko, this message translates to:
  /// **'로그인 방식'**
  String get settingsSignInMethod;

  /// 로그인 방식 이름
  ///
  /// In ko, this message translates to:
  /// **'Google'**
  String get signInMethodGoogle;

  /// 로그인 방식 이름
  ///
  /// In ko, this message translates to:
  /// **'Apple'**
  String get signInMethodApple;

  /// 로그인 방식 이름
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get signInMethodEmail;

  /// 설정의 로그아웃 줄과 확인 창 버튼
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get settingsSignOut;

  /// 로그아웃 확인 창
  ///
  /// In ko, this message translates to:
  /// **'로그아웃할까요?'**
  String get settingsSignOutConfirm;

  /// 진행 중인 대국이 있을 때 로그아웃을 누르면 보여주는 안내
  ///
  /// In ko, this message translates to:
  /// **'대국 중에는 로그아웃할 수 없어요'**
  String get settingsSignOutInGame;

  /// 설정의 정보 묶음
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get settingsInfoGroup;

  /// 설정의 앱 버전
  ///
  /// In ko, this message translates to:
  /// **'버전'**
  String get settingsVersion;

  /// 설정의 오픈소스 라이선스 화면으로 가는 줄
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get settingsLicenses;

  /// 설정의 계정 묶음
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴'**
  String get settingsDeleteAccount;

  /// 진행 중인 대국이 있을 때 회원 탈퇴를 누르면
  ///
  /// In ko, this message translates to:
  /// **'대국 중에는 탈퇴할 수 없어요'**
  String get settingsDeleteAccountInGame;

  /// 회원 탈퇴 확인 창
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하면 급수, 전적, 엽전, 산 상품이 없어져요. 남은 엽전은 돌려받을 수 없어요.\n\n30일 뒤 모두 지우고, 그때까지 같은 계정으로 다시 가입할 수 없어요. 되돌리려면 그 안에 {email}로 알려 주세요.\n\n기보는 닉네임 없이 남고, 엽전 내역은 5년 보관해요.'**
  String settingsDeleteAccountConfirm(String email);

  /// 회원 탈퇴 확인 창의 버튼
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하기'**
  String get settingsDeleteAccountButton;

  /// 회원 탈퇴를 마쳤을 때
  ///
  /// In ko, this message translates to:
  /// **'탈퇴했어요'**
  String get settingsDeleteAccountDone;

  /// 회원 탈퇴 실패
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorDeleteAccount;

  /// 탈퇴해 비활성화된 계정으로 로그인했을 때
  ///
  /// In ko, this message translates to:
  /// **'탈퇴한 계정이에요. 되돌리려면 {email}로 알려 주세요'**
  String errorAccountDisabled(String email);

  /// signupEnabled가 꺼져 있을 때
  ///
  /// In ko, this message translates to:
  /// **'지금은 새로 가입할 수 없어요'**
  String get errorSignupDisabled;

  /// 제재가 남은 채 지워진 계정으로 다시 가입할 때
  ///
  /// In ko, this message translates to:
  /// **'이 계정은 지금 다시 가입할 수 없어요'**
  String get errorSignupBlocked;

  /// 공지가 새 대국을 막고 있을 때
  ///
  /// In ko, this message translates to:
  /// **'지금은 대국을 시작할 수 없어요'**
  String get errorGamesBlocked;

  /// 앱이 minAppVersion보다 낮을 때의 안내 화면
  ///
  /// In ko, this message translates to:
  /// **'새 버전으로 업데이트해 주세요'**
  String get updateRequiredMessage;

  /// 업데이트 안내 화면의 버튼. 스토어를 연다
  ///
  /// In ko, this message translates to:
  /// **'업데이트'**
  String get updateRequiredButton;

  /// webEnabled가 꺼져 있을 때 웹의 안내 화면
  ///
  /// In ko, this message translates to:
  /// **'지금은 웹에서 이용할 수 없어요. 앱을 이용해 주세요'**
  String get webClosedMessage;

  /// 상점 절 제목
  ///
  /// In ko, this message translates to:
  /// **'엽전 충전'**
  String get storeCoinsTitle;

  /// 상점 절 제목
  ///
  /// In ko, this message translates to:
  /// **'장기알'**
  String get storePiecesTitle;

  /// 상점 절 제목
  ///
  /// In ko, this message translates to:
  /// **'광고 제거'**
  String get storeRemoveAdsTitle;

  /// 광고 제거 상품 설명. 배너만 없앤다
  ///
  /// In ko, this message translates to:
  /// **'배너 광고가 나오지 않아요'**
  String get storeRemoveAdsDescription;

  /// 충전 상품 이름
  ///
  /// In ko, this message translates to:
  /// **'{coins}엽전'**
  String storeCoinsAmount(int coins);

  /// 스토어 가격을 모를 때의 값
  ///
  /// In ko, this message translates to:
  /// **'{price}원'**
  String storePriceWon(int price);

  /// 웹 상점의 구매 자리
  ///
  /// In ko, this message translates to:
  /// **'앱에서 살 수 있어요'**
  String get storeBuyInApp;

  /// 기물 이름
  ///
  /// In ko, this message translates to:
  /// **'기본 장기알'**
  String get storeMaterialPlastic;

  /// 기물 이름
  ///
  /// In ko, this message translates to:
  /// **'나무 장기알'**
  String get storeMaterialWood;

  /// 기물 이름
  ///
  /// In ko, this message translates to:
  /// **'알루미늄 장기알'**
  String get storeMaterialAluminum;

  /// 지금 고른 기물
  ///
  /// In ko, this message translates to:
  /// **'쓰는 중'**
  String get storeMaterialSelected;

  /// 산 기물을 고르는 버튼
  ///
  /// In ko, this message translates to:
  /// **'쓰기'**
  String get storeMaterialSelect;

  /// 이미 산 영구 상품
  ///
  /// In ko, this message translates to:
  /// **'샀어요'**
  String get storeOwned;

  /// 결제가 끝났을 때. 지급은 서버가 웹훅을 받아 한다
  ///
  /// In ko, this message translates to:
  /// **'결제했어요. 곧 들어와요'**
  String get storePurchased;

  /// 구매 복원 버튼
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get storeRestore;

  /// 구매 복원이 끝났을 때
  ///
  /// In ko, this message translates to:
  /// **'구매를 다시 확인했어요'**
  String get storeRestored;

  /// 청약철회 안내(docs/release.md의 약관에 넣을 것)
  ///
  /// In ko, this message translates to:
  /// **'쓰지 않은 엽전과 상품은 결제하고 7일 안에 구글 플레이나 앱스토어에서 환불을 신청할 수 있어요'**
  String get storeWithdrawalNotice;

  /// 엽전이 모자라요 창의 버튼
  ///
  /// In ko, this message translates to:
  /// **'상점으로 가기'**
  String get storeGo;

  /// 결제 실패 기본 메시지
  ///
  /// In ko, this message translates to:
  /// **'결제하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorPurchase;

  /// 구매 복원 실패
  ///
  /// In ko, this message translates to:
  /// **'구매를 복원하지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorRestorePurchases;

  /// 기물 고르기 실패
  ///
  /// In ko, this message translates to:
  /// **'장기알을 바꾸지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorSelectMaterial;

  /// 스토어를 쓸 수 없을 때
  ///
  /// In ko, this message translates to:
  /// **'지금은 살 수 없어요. 잠시 후 다시 해 주세요'**
  String get errorStoreUnavailable;

  /// 사용자가 결제를 취소했을 때
  ///
  /// In ko, this message translates to:
  /// **'결제를 그만뒀어요'**
  String get errorPurchaseCanceled;

  /// 결제가 승인 대기 중일 때
  ///
  /// In ko, this message translates to:
  /// **'결제가 끝나면 들어와요'**
  String get errorPurchasePending;

  /// 스토어가 이미 산 상품이라고 할 때
  ///
  /// In ko, this message translates to:
  /// **'이 스토어 계정으로 이미 산 상품이에요'**
  String get errorPurchaseAlreadyOwned;

  /// 로그인 창 제목
  ///
  /// In ko, this message translates to:
  /// **'로그인하면\n상점을 쓸 수 있어요'**
  String get loginSheetTitleStore;

  /// 닉네임 정하기 안내
  ///
  /// In ko, this message translates to:
  /// **'정하고 나면 상점으로 가요'**
  String get nicknameStartHintStore;

  /// 상점의 보상형 광고 묶음 제목
  ///
  /// In ko, this message translates to:
  /// **'엽전 받기'**
  String get storeEarnCoinsTitle;

  /// 보상형 광고 버튼과 줄의 이름
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 {coins}엽전 받기'**
  String adRewardAction(int coins);

  /// 상점의 보상형 광고 버튼
  ///
  /// In ko, this message translates to:
  /// **'보기'**
  String get storeAdWatch;

  /// 상점의 보상형 광고 남은 횟수
  ///
  /// In ko, this message translates to:
  /// **'오늘 {count}번 남았어요'**
  String storeAdsLeft(int count);

  /// 오늘의 보상형 광고 횟수를 다 썼을 때
  ///
  /// In ko, this message translates to:
  /// **'오늘은 다 받았어요'**
  String get storeAdsDone;

  /// 보상형 광고를 끝까지 봤을 때. 지급은 서버가 한다
  ///
  /// In ko, this message translates to:
  /// **'곧 {coins}엽전이 들어와요'**
  String adRewardComing(int coins);

  /// 보상형 광고를 불러오거나 보여주지 못했을 때
  ///
  /// In ko, this message translates to:
  /// **'지금은 광고를 볼 수 없어요. 잠시 후 다시 해 주세요'**
  String get errorAdUnavailable;

  /// 보상형 광고를 끝까지 보지 않았을 때
  ///
  /// In ko, this message translates to:
  /// **'광고를 끝까지 봐야 받을 수 있어요'**
  String get errorAdNotCompleted;

  /// 설정의 광고 동의 다시 고르기(유럽 등)
  ///
  /// In ko, this message translates to:
  /// **'광고 개인정보 설정'**
  String get settingsAdPrivacy;

  /// 광고 동의 창을 띄우지 못했을 때
  ///
  /// In ko, this message translates to:
  /// **'광고 설정을 열지 못했어요. 잠시 후 다시 해 주세요'**
  String get errorAdPrivacy;
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
