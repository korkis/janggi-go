// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '장기고';

  @override
  String get homeDevGameTitle => '개발용 대국';

  @override
  String get homeDevGameDescription => '한 기기에서 초와 한을 번갈아 둬요';

  @override
  String get homeDevGameStart => '시작하기';

  @override
  String get back => '뒤로';

  @override
  String get cancel => '취소';

  @override
  String sideName(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': '초',
      'han': '한',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String sideHanja(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': '楚',
      'han': '漢',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get setupTitle => '상차림을 골라 주세요';

  @override
  String get setupDecided => '정했어요';

  @override
  String get setupConfirm => '이 상차림으로 정하기';

  @override
  String formationName(String formation) {
    String _temp0 = intl.Intl.selectLogic(formation, {
      'horseElephantHorseElephant': '마상마상',
      'elephantHorseElephantHorse': '상마상마',
      'horseElephantElephantHorse': '마상상마',
      'elephantHorseHorseElephant': '상마마상',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String gameDevTitle(int count) {
    return '개발용 대국 · $count수';
  }

  @override
  String score(String score) {
    return '$score점';
  }

  @override
  String get check => '장군';

  @override
  String get passedLast => '한수쉼';

  @override
  String get pass => '한수쉼';

  @override
  String get passFailed => '지금은 한수쉼을 할 수 없어요';

  @override
  String get more => '더보기';

  @override
  String get flipBoard => '판 돌리기';

  @override
  String get resign => '기권';

  @override
  String resignConfirm(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': '초가',
      'han': '한이',
      'other': '',
    });
    return '$_temp0 기권할까요?';
  }

  @override
  String get resignAction => '기권하기';

  @override
  String get leaveGameConfirm => '대국을 그만두고 나갈까요?';

  @override
  String get leaveGameAction => '나가기';

  @override
  String resultReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'checkmate': '외통승',
      'resignation': '기권승',
      'timeout': '시간승',
      'consecutivePasses': '점수승',
      'moveLimit': '점수승',
      'noLegalMoves': '점수승',
      'disconnect': '접속 끊김승',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String resultWinner(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': '초 승리',
      'han': '한 승리',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String resultSummary(int moves, int minutes, int seconds) {
    return '$moves수 · $minutes분 $seconds초';
  }

  @override
  String get resultConsecutivePasses => '양쪽이 연속으로 한수쉼을 해서 점수로 정했어요';

  @override
  String resultMoveLimit(int limit) {
    return '$limit수에 닿아서 점수로 정했어요';
  }

  @override
  String get resultNoLegalMoves => '둘 수 있는 수가 없어서 점수로 정했어요';

  @override
  String get resultRematch => '다시 두기';

  @override
  String get resultHome => '홈으로';

  @override
  String get resultReview => '복기하기';

  @override
  String get reviewTitle => '복기';

  @override
  String reviewMoveCounter(int current, int total) {
    return '$current / $total수';
  }

  @override
  String get reviewTrial => '놓아보기';

  @override
  String get reviewFirst => '처음';

  @override
  String get reviewPrevious => '이전';

  @override
  String get reviewNext => '다음';

  @override
  String get reviewLast => '끝';

  @override
  String get ok => '확인';

  @override
  String get close => '닫기';

  @override
  String get login => '로그인';

  @override
  String get signUp => '가입하기';

  @override
  String get homeLoginGuide => '로그인하면 급수와 전적이 저장돼요';

  @override
  String get homeDevSignOut => '로그아웃 (개발용)';

  @override
  String get loginSheetTitleHome => '로그인하고\n온라인 대국을 둬 보세요';

  @override
  String get loginSheetTitleQuickMatch => '로그인하면 바로\n상대를 찾아 드릴게요';

  @override
  String get loginSheetDescription => '온라인 대국은 로그인 후 둘 수 있어요.\n급수와 전적이 저장돼요.';

  @override
  String get loginWithGoogle => 'Google로 계속하기';

  @override
  String get loginWithApple => 'Apple로 계속하기';

  @override
  String get loginWithEmail => '이메일로 계속하기';

  @override
  String get termsOfService => '이용약관';

  @override
  String get privacyPolicy => '개인정보처리방침';

  @override
  String loginTermsNotice(String terms, String privacy) {
    return '계속하면 $terms과 $privacy에\n동의하는 것으로 봅니다.';
  }

  @override
  String get emailLoginTitle => '이메일로 로그인';

  @override
  String get emailLoginDescription => '가입할 때 쓴 이메일과 비밀번호를 넣어 주세요.';

  @override
  String get emailSignUpTitle => '이메일로 가입하기';

  @override
  String get emailSignUpDescription => '로그인에 쓸 이메일과 비밀번호를 정해 주세요.';

  @override
  String get emailSignUpPrompt => '처음이신가요?';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get passwordConfirm => '비밀번호 확인';

  @override
  String get showPassword => '비밀번호 보기';

  @override
  String get hidePassword => '비밀번호 숨기기';

  @override
  String get forgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get passwordResetSent => '비밀번호를 다시 정하는 메일을 보냈어요. 메일함을 확인해 주세요.';

  @override
  String get nicknameTitle => '장기판에서 쓸\n이름을 정해 주세요';

  @override
  String get nicknameDescription => '대국 상대와 관전하는 사람에게 보여요.';

  @override
  String get nickname => '닉네임';

  @override
  String nicknameLength(int count, int max) {
    return '$count/$max';
  }

  @override
  String nicknameRule(int min, int max) {
    return '한글, 영문, 숫자로 $min~$max자';
  }

  @override
  String get nicknameChecking => '확인하고 있어요';

  @override
  String get nicknameAvailable => '쓸 수 있는 닉네임이에요';

  @override
  String get nicknameUnavailable => '쓸 수 없는 닉네임이에요';

  @override
  String get nicknameCheckFailed => '확인하지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get nicknameInvalidFormat => '한글, 영문, 숫자로 2~10자로 정해 주세요';

  @override
  String get nicknameTaken => '이미 다른 사람이 쓰고 있어요';

  @override
  String get nicknameBannedWord => '쓸 수 없는 말이 들어 있어요';

  @override
  String get nicknameImpersonation => '운영진으로 오해할 수 있는 이름은 쓸 수 없어요';

  @override
  String get nicknamePreviewLabel => '대국 화면에서는 이렇게 보여요';

  @override
  String nicknamePreviewDetail(String rank) {
    return '$rank · 첫 대국';
  }

  @override
  String get nicknameStart => '시작하기';

  @override
  String get nicknameStartHintQuickMatch => '정하고 나면 바로 상대를 찾아요';

  @override
  String rankKyu(int kyu) {
    return '$kyu급';
  }

  @override
  String rankDan(int dan) {
    return '$dan단';
  }

  @override
  String get errorSignInCanceled => '로그인을 그만뒀어요';

  @override
  String get errorSignIn => '로그인하지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorInvalidEmail => '이메일 주소를 다시 확인해 주세요';

  @override
  String get errorWrongEmailOrPassword => '이메일 또는 비밀번호가 맞지 않아요';

  @override
  String get errorEmailAlreadyInUse => '이미 가입한 이메일이에요. 로그인해 주세요';

  @override
  String get errorWeakPassword => '비밀번호는 6자 이상으로 정해 주세요';

  @override
  String get errorPasswordEmpty => '비밀번호를 넣어 주세요';

  @override
  String get errorPasswordMismatch => '비밀번호가 서로 달라요';

  @override
  String get errorPasswordResetEmail => '비밀번호를 다시 정할 이메일을 넣어 주세요';

  @override
  String get errorPasswordReset => '메일을 보내지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorTooManyRequests => '시도가 너무 많아요. 잠시 후 다시 해 주세요';

  @override
  String get errorNetwork => '인터넷 연결을 확인해 주세요';

  @override
  String get errorProfileLoad => '내 정보를 불러오지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorCreateProfile => '닉네임을 정하지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorSignOut => '로그아웃하지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get homeDevOnlineTitle => '개발용 온라인 대국';

  @override
  String get homeDevOnlineDescription => '상대 닉네임을 넣으면 두 계정의 대국을 바로 만들어요';

  @override
  String get homeDevOnlineOpponent => '상대 닉네임';

  @override
  String get homeDevOnlineCreate => '대국 만들기';

  @override
  String sideChoiceName(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': '초',
      'han': '한',
      'random': '무작위',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String gameOnlineTitle(int count) {
    return '온라인 대국 · $count수';
  }

  @override
  String playerNameWithRank(String nickname, String rank) {
    return '$nickname · $rank';
  }

  @override
  String clockPeriods(int count) {
    return '초읽기 $count회';
  }

  @override
  String setupSeconds(int seconds) {
    return '$seconds초';
  }

  @override
  String get setupOpponentChoosing => '상대가 고르고 있어요';

  @override
  String get resignConfirmOnline => '기권할까요? 이 대국은 지게 돼요';

  @override
  String get leaveOnlineGameConfirm => '화면을 나가도 대국은 계속돼요. 나갈까요?';

  @override
  String get errorCreateGame => '대국을 만들지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorGameLoad => '대국을 불러오지 못했어요';

  @override
  String get errorPlayMove => '수를 보내지 못했어요. 판을 서버와 다시 맞췄어요';

  @override
  String get errorSetFormation => '상차림을 보내지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorResign => '기권하지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorGameNotFound => '상대나 대국을 찾지 못했어요';

  @override
  String get errorGameBusy => '이미 대국이나 대기 중인 사람이 있어요';

  @override
  String get errorGameNotPlayer => '이 대국의 대국자가 아니에요';

  @override
  String get errorGameNotYourTurn => '지금은 내 차례가 아니에요';

  @override
  String get errorGameIllegalMove => '둘 수 없는 수예요';

  @override
  String get errorGameMoveConflict => '판을 서버와 다시 맞췄어요';

  @override
  String get errorGameOver => '이미 끝난 대국이에요';

  @override
  String opponentDisconnected(int seconds) {
    return '연결이 끊겼어요 $seconds초';
  }

  @override
  String get reconnecting => '다시 연결하는 중';

  @override
  String get homeResumeGame => '대국으로 돌아가기';

  @override
  String get homeQuickMatch => '빠른 대국';

  @override
  String rankWinsToNext(String rank, int wins) {
    return '$rank까지 약 $wins승';
  }

  @override
  String get quickMatchSearching => '상대를 찾고 있어요';

  @override
  String get quickMatchSearchingDescription => '급수가 비슷한 상대와 바로 시작해요';

  @override
  String get quickMatchTipTitle => '장기 규칙';

  @override
  String quickMatchTip(String index) {
    String _temp0 = intl.Intl.selectLogic(index, {
      '0': '초가 먼저 두고, 한은 덤 1.5점을 받아요',
      '1': '한이 먼저 상차림을 정하고, 초는 한의 상차림을 본 뒤 정해요',
      '2': '장군을 받은 상태에서는 한수쉼을 할 수 없어요',
      '3': '같은 국면을 3번째로 만드는 수는 둘 수 없어요',
      'other': '양쪽이 연속으로 한수쉼을 하면 점수로 승부를 정해요',
    });
    return '$_temp0';
  }

  @override
  String get quickMatchStop => '그만 찾기';

  @override
  String get quickMatchFound => '상대를 찾았어요';

  @override
  String get quickMatchVersus => 'VS';

  @override
  String quickMatchMoveOrder(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': '초 · 먼저 둬요',
      'han': '한 · 나중에 둬요',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String quickMatchTimeRule(int minutes, int seconds, int periods) {
    return '기본 $minutes분 · 초읽기 $seconds초 $periods회';
  }

  @override
  String get quickMatchRated => '급수 대국';

  @override
  String get errorQuickMatch => '상대를 찾지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorLeaveQuickMatch => '그만 찾지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get errorSanctioned => '이용이 제한되어 지금은 대국을 할 수 없어요';

  @override
  String get errorRematchUnavailable => '지금은 다시 두기를 할 수 없어요';

  @override
  String get errorRematch => '다시 두기를 하지 못했어요. 잠시 후 다시 해 주세요';

  @override
  String get resultPlayAgain => '한 판 더';

  @override
  String get resultRematchWaiting => '상대를 기다리는 중';

  @override
  String get resultRematchRequested => '상대가 다시 두기를 원해요';

  @override
  String get resultRematchCancelled => '상대가 나가서 다시 둘 수 없어요';

  @override
  String get resultRematchBlocked => '같은 상대와는 더 다시 둘 수 없어요';

  @override
  String resultRankUp(String rank) {
    return '$rank으로 올랐어요';
  }

  @override
  String resultRankDown(String rank) {
    return '$rank으로 내려갔어요';
  }
}
