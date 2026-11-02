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

  /// 대국 결과 창에서 방금 둔 대국을 복기하는 버튼
  ///
  /// In ko, this message translates to:
  /// **'복기하기'**
  String get resultReview;

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

  /// 홈 내 카드의 로그아웃 버튼. 개발 빌드에만 보인다
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 (개발용)'**
  String get homeDevSignOut;

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
  /// **'계속하면 {terms}과 {privacy}에\n동의하는 것으로 봅니다.'**
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

  /// 진행 중인 개발용 온라인 대국으로 가는 버튼
  ///
  /// In ko, this message translates to:
  /// **'대국으로 가기'**
  String get homeDevOnlineResume;

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

  /// 상차림 남은 시간
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초'**
  String setupSeconds(int seconds);

  /// 상대가 상차림을 고르는 동안 정하기 버튼 자리에 보이는 글자
  ///
  /// In ko, this message translates to:
  /// **'상대가 고르고 있어요'**
  String get setupOpponentChoosing;

  /// 온라인 대국 기권 확인
  ///
  /// In ko, this message translates to:
  /// **'기권할까요? 이 대국은 지게 돼요'**
  String get resignConfirmOnline;

  /// 온라인 대국 중 뒤로 가기 확인
  ///
  /// In ko, this message translates to:
  /// **'화면을 나가도 대국은 계속돼요. 나갈까요?'**
  String get leaveOnlineGameConfirm;

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
