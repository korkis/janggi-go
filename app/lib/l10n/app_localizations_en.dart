// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Janggigo';

  @override
  String get homeDevGameTitle => 'Development game';

  @override
  String get homeDevGameDescription => 'Play both Cho and Han on one device';

  @override
  String get homeDevGameStart => 'Start';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String sideName(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'Cho',
      'han': 'Han',
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
  String get setupTitle => 'Choose your setup';

  @override
  String get setupDecided => 'Ready';

  @override
  String get setupConfirm => 'Use this setup';

  @override
  String formationName(String formation) {
    String _temp0 = intl.Intl.selectLogic(formation, {
      'horseElephantHorseElephant': 'Horse, Elephant, Horse, Elephant',
      'elephantHorseElephantHorse': 'Elephant, Horse, Elephant, Horse',
      'horseElephantElephantHorse': 'Horse, Elephant, Elephant, Horse',
      'elephantHorseHorseElephant': 'Elephant, Horse, Horse, Elephant',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String gameDevTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moves',
      one: '1 move',
    );
    return 'Development game · $_temp0';
  }

  @override
  String score(String score) {
    return '$score pts';
  }

  @override
  String get check => 'Check';

  @override
  String get passedLast => 'Passed';

  @override
  String get pass => 'Pass';

  @override
  String get passFailed => 'You can\'t pass right now';

  @override
  String get more => 'More';

  @override
  String get flipBoard => 'Flip board';

  @override
  String get resign => 'Resign';

  @override
  String resignConfirm(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'Cho',
      'han': 'Han',
      'other': '',
    });
    return 'Resign as $_temp0?';
  }

  @override
  String get resignAction => 'Resign';

  @override
  String get leaveGameConfirm => 'Leave this game?';

  @override
  String get leaveGameAction => 'Leave';

  @override
  String resultReason(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'checkmate': 'Checkmate',
      'resignation': 'Resignation',
      'timeout': 'Timeout',
      'consecutivePasses': 'On points',
      'moveLimit': 'On points',
      'noLegalMoves': 'On points',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String resultWinner(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'Cho wins',
      'han': 'Han wins',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String resultSummary(int moves, int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      moves,
      locale: localeName,
      other: '$moves moves',
      one: '1 move',
    );
    return '$_temp0 · ${minutes}m ${seconds}s';
  }

  @override
  String get resultConsecutivePasses =>
      'Both sides passed in a row, so points decided the game';

  @override
  String resultMoveLimit(int limit) {
    return 'The game reached $limit moves, so points decided it';
  }

  @override
  String get resultNoLegalMoves =>
      'No moves were left, so points decided the game';

  @override
  String get resultRematch => 'Play again';

  @override
  String get resultHome => 'Home';

  @override
  String get resultReview => 'Review';

  @override
  String get reviewTitle => 'Review';

  @override
  String reviewMoveCounter(int current, int total) {
    return '$current / $total';
  }

  @override
  String get reviewTrial => 'Try moves';

  @override
  String get reviewFirst => 'First';

  @override
  String get reviewPrevious => 'Back';

  @override
  String get reviewNext => 'Next';

  @override
  String get reviewLast => 'Last';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Close';

  @override
  String get login => 'Sign in';

  @override
  String get signUp => 'Sign up';

  @override
  String get homeLoginGuide => 'Sign in to save your rank and record';

  @override
  String get homeDevSignOut => 'Sign out (dev)';

  @override
  String get loginSheetTitleHome => 'Sign in and\nplay online';

  @override
  String get loginSheetTitleQuickMatch =>
      'Sign in and we\'ll\nfind you an opponent';

  @override
  String get loginSheetDescription =>
      'Sign in to play online.\nYour rank and record will be saved.';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get loginWithApple => 'Continue with Apple';

  @override
  String get loginWithEmail => 'Continue with email';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String loginTermsNotice(String terms, String privacy) {
    return 'By continuing, you agree to the\n$terms and $privacy.';
  }

  @override
  String get emailLoginTitle => 'Sign in with email';

  @override
  String get emailLoginDescription =>
      'Enter the email and password you signed up with.';

  @override
  String get emailSignUpTitle => 'Sign up with email';

  @override
  String get emailSignUpDescription =>
      'Choose the email and password you\'ll sign in with.';

  @override
  String get emailSignUpPrompt => 'New here?';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get passwordConfirm => 'Confirm password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get forgotPassword => 'Forgot your password?';

  @override
  String get passwordResetSent =>
      'We sent you an email to reset your password. Please check your inbox.';

  @override
  String get nicknameTitle => 'Choose the name\nyou\'ll play under';

  @override
  String get nicknameDescription =>
      'Your opponents and spectators will see it.';

  @override
  String get nickname => 'Nickname';

  @override
  String nicknameLength(int count, int max) {
    return '$count/$max';
  }

  @override
  String nicknameRule(int min, int max) {
    return '$min to $max Korean letters, English letters, or digits';
  }

  @override
  String get nicknameChecking => 'Checking…';

  @override
  String get nicknameAvailable => 'This nickname is available';

  @override
  String get nicknameUnavailable => 'This nickname can\'t be used';

  @override
  String get nicknameCheckFailed => 'Couldn\'t check. Please try again shortly';

  @override
  String get nicknameInvalidFormat =>
      'Use 2 to 10 Korean letters, English letters, or digits';

  @override
  String get nicknameTaken => 'Someone is already using this nickname';

  @override
  String get nicknameBannedWord =>
      'This nickname contains words that aren\'t allowed';

  @override
  String get nicknameImpersonation =>
      'Names that look like staff can\'t be used';

  @override
  String get nicknamePreviewLabel => 'This is how you\'ll appear in games';

  @override
  String nicknamePreviewDetail(String rank) {
    return '$rank · First game';
  }

  @override
  String get nicknameStart => 'Start';

  @override
  String get nicknameStartHintQuickMatch =>
      'We\'ll find you an opponent right after';

  @override
  String rankKyu(int kyu) {
    return '$kyu kyu';
  }

  @override
  String rankDan(int dan) {
    return '$dan dan';
  }

  @override
  String get errorSignInCanceled => 'Sign-in was canceled';

  @override
  String get errorSignIn => 'Couldn\'t sign in. Please try again shortly';

  @override
  String get errorInvalidEmail => 'Please check your email address';

  @override
  String get errorWrongEmailOrPassword => 'The email or password is incorrect';

  @override
  String get errorEmailAlreadyInUse =>
      'This email is already registered. Please sign in';

  @override
  String get errorWeakPassword => 'Use at least 6 characters for your password';

  @override
  String get errorPasswordEmpty => 'Please enter your password';

  @override
  String get errorPasswordMismatch => 'The passwords don\'t match';

  @override
  String get errorPasswordResetEmail =>
      'Enter the email to reset your password';

  @override
  String get errorPasswordReset =>
      'Couldn\'t send the email. Please try again shortly';

  @override
  String get errorTooManyRequests =>
      'Too many attempts. Please try again shortly';

  @override
  String get errorNetwork => 'Please check your internet connection';

  @override
  String get errorProfileLoad =>
      'Couldn\'t load your profile. Please try again shortly';

  @override
  String get errorCreateProfile =>
      'Couldn\'t set your nickname. Please try again shortly';

  @override
  String get errorSignOut => 'Couldn\'t sign out. Please try again shortly';
}
