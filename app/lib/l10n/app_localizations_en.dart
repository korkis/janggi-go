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
  String get setupDecided => 'Opponent is ready';

  @override
  String setupMySide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'You are Cho · You move first',
      'han': 'You are Han · You move second',
      'other': '',
    });
    return '$_temp0';
  }

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
      'checkmate': 'Win by checkmate',
      'resignation': 'Win by resignation',
      'timeout': 'Win on time',
      'consecutivePasses': 'Win on points',
      'moveLimit': 'Win on points',
      'noLegalMoves': 'Win on points',
      'disconnect': 'Win by disconnection',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String resultReasonLoss(String reason) {
    String _temp0 = intl.Intl.selectLogic(reason, {
      'checkmate': 'Loss by checkmate',
      'resignation': 'Loss by resignation',
      'timeout': 'Loss on time',
      'consecutivePasses': 'Loss on points',
      'moveLimit': 'Loss on points',
      'noLegalMoves': 'Loss on points',
      'disconnect': 'Loss by disconnection',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String resultMyWin(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'Cho wins!',
      'han': 'Han wins!',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String resultMyLoss(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'Cho loses!',
      'han': 'Han loses!',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get resultOutcomeWin => 'Victory';

  @override
  String get resultOutcomeLoss => 'Defeat';

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
  String get resultRematch => 'Rematch';

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
  String get showPasswordConfirm => 'Show password confirmation';

  @override
  String get hidePasswordConfirm => 'Hide password confirmation';

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

  @override
  String get homeDevOnlineTitle => 'Dev online game';

  @override
  String get homeDevOnlineDescription =>
      'Enter an opponent nickname to start a game between two accounts';

  @override
  String get homeDevOnlineOpponent => 'Opponent nickname';

  @override
  String get homeDevOnlineCreate => 'Create game';

  @override
  String sideChoiceName(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'Cho',
      'han': 'Han',
      'random': 'Random',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String gameOnlineTitle(int count) {
    return 'Online game · $count moves';
  }

  @override
  String gameModeName(String mode) {
    String _temp0 = intl.Intl.selectLogic(mode, {
      'quick': 'Quick match',
      'room': 'Room game',
      'challenge': 'Challenge',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get gameRated => 'Ranked game';

  @override
  String gameTimeRule(int minutes, int seconds, int periods) {
    return '$minutes min · $periods×${seconds}s byoyomi';
  }

  @override
  String playerNameWithRank(String nickname, String rank) {
    return '$nickname · $rank';
  }

  @override
  String clockPeriods(int count) {
    return '$count × byoyomi';
  }

  @override
  String setupSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get setupOpponentChoosing => 'Your opponent is choosing a setup';

  @override
  String get resignConfirmOnline => 'Resign? You will lose this game.';

  @override
  String get leaveOnlineGameConfirm =>
      'The game continues if you leave. Leave anyway?';

  @override
  String get errorCreateGame =>
      'Could not create the game. Please try again later.';

  @override
  String get errorGameLoad => 'Could not load the game.';

  @override
  String get errorPlayMove =>
      'Could not send the move. The board was synced with the server.';

  @override
  String get errorSetFormation => 'Could not send the setup. Please try again.';

  @override
  String get errorResign => 'Could not resign. Please try again.';

  @override
  String get errorGameNotFound => 'Could not find the opponent or the game.';

  @override
  String get errorGameBusy => 'Someone is already in a game or waiting.';

  @override
  String get errorGameNotPlayer => 'You are not a player in this game.';

  @override
  String get errorGameNotYourTurn => 'It is not your turn.';

  @override
  String get errorGameIllegalMove => 'That move is not allowed.';

  @override
  String get errorGameMoveConflict => 'The board was synced with the server.';

  @override
  String get errorGameOver => 'The game is already over.';

  @override
  String opponentDisconnected(int seconds) {
    return 'Disconnected ${seconds}s';
  }

  @override
  String get reconnecting => 'Reconnecting';

  @override
  String get homeResumeGame => 'Back to game';

  @override
  String get homeQuickMatch => 'Quick match';

  @override
  String rankWinsToNext(String rank, int wins) {
    String _temp0 = intl.Intl.pluralLogic(
      wins,
      locale: localeName,
      other: '$wins wins',
      one: '1 win',
    );
    return 'About $_temp0 to $rank';
  }

  @override
  String get quickMatchSearching => 'Finding an opponent';

  @override
  String get quickMatchSearchingDescription =>
      'You\'ll start right away with a player of a similar rank';

  @override
  String get quickMatchTipTitle => 'Janggi rules';

  @override
  String quickMatchTip(String index) {
    String _temp0 = intl.Intl.selectLogic(index, {
      '0': 'Cho moves first, and Han gets a 1.5-point bonus',
      '1': 'Han sets up first, then Cho sets up after seeing Han\'s setup',
      '2': 'You can\'t pass while in check',
      '3': 'You can\'t make a move that repeats the same position a third time',
      'other': 'If both sides pass in a row, points decide the game',
    });
    return '$_temp0';
  }

  @override
  String get quickMatchStop => 'Stop searching';

  @override
  String get errorQuickMatch =>
      'Couldn\'t find an opponent. Please try again shortly';

  @override
  String get errorLeaveQuickMatch =>
      'Couldn\'t stop searching. Please try again shortly';

  @override
  String get errorSanctioned =>
      'Your account is restricted, so you can\'t play right now';

  @override
  String get errorRematchUnavailable => 'A rematch isn\'t available right now';

  @override
  String get errorRematch =>
      'Couldn\'t request a rematch. Please try again shortly';

  @override
  String get resultPlayAgain => 'Play again';

  @override
  String get resultRematchWaiting => 'Waiting for opponent';

  @override
  String get resultRematchRequested => 'Your opponent wants a rematch';

  @override
  String get resultRematchCancelled =>
      'Your opponent left, so you can\'t rematch';

  @override
  String get resultRematchBlocked => 'You can\'t rematch this opponent again';

  @override
  String resultRankUp(String rank) {
    return 'Promoted to $rank';
  }

  @override
  String resultRankDown(String rank) {
    return 'Dropped to $rank';
  }

  @override
  String get homeCreateRoom => 'Create room';

  @override
  String get homeResumeRoom => 'Back to my room';

  @override
  String get lobbyTitle => 'Game rooms';

  @override
  String get menuHome => 'Home';

  @override
  String get lobbyRoomList => 'Rooms';

  @override
  String get lobbyEmpty => 'No open rooms right now';

  @override
  String get lobbyEmptyDescription => 'Create a room and wait for an opponent';

  @override
  String get lobbyEnter => 'Join';

  @override
  String get retry => 'Try again';

  @override
  String get loginSheetTitleCreateRoom => 'Sign in to\ncreate a room';

  @override
  String get loginSheetTitleLobby => 'Sign in to\nenter the game rooms';

  @override
  String get loginSheetTitleJoinRoom =>
      'Sign in to join\nthe room you were invited to';

  @override
  String get nicknameStartHintCreateRoom =>
      'We\'ll create your room right after';

  @override
  String get nicknameStartHintLobby =>
      'We\'ll take you to the game rooms right after';

  @override
  String get nicknameStartHintJoinRoom =>
      'We\'ll take you to the room right after';

  @override
  String get errorRoomFull => 'This room is full';

  @override
  String get errorRoomPlaying => 'A game is in progress in this room';

  @override
  String get errorRoomClosed => 'This room has closed';

  @override
  String get errorKicked => 'You can\'t rejoin this room';

  @override
  String get errorRankOutOfRange => 'Your rank isn\'t allowed in this room';

  @override
  String get errorNotHost => 'Only the host can do this';

  @override
  String get errorJoinRoom =>
      'Couldn\'t join the room. Please try again shortly';

  @override
  String get errorCreateRoom =>
      'Couldn\'t create the room. Please try again shortly';

  @override
  String get errorLeaveRoom =>
      'Couldn\'t leave the room. Please try again shortly';

  @override
  String get errorKickGuest =>
      'Couldn\'t remove the opponent. Please try again shortly';

  @override
  String get errorStartRoomGame =>
      'Couldn\'t start the game. Please try again shortly';

  @override
  String get errorLoadRooms => 'Couldn\'t load the rooms';

  @override
  String get errorLoadRoom => 'Couldn\'t load the room';

  @override
  String get errorShareLink => 'Couldn\'t share. Please copy the link instead';

  @override
  String roomTitle(String nickname) {
    return '$nickname\'s room';
  }

  @override
  String get rankRangeAll => 'All ranks';

  @override
  String rankRange(String min, String max) {
    return '$min – $max';
  }

  @override
  String pieceName(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'chariot': 'Chariot',
      'cannon': 'Cannon',
      'horse': 'Horse',
      'elephant': 'Elephant',
      'advisor': 'Advisor',
      'soldier': 'Soldier',
      'king': 'General',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String handicapSummary(String pieces, int points) {
    return 'Remove $pieces · start $points points behind';
  }

  @override
  String get roomChipHandicap => 'Handicap';

  @override
  String roomChipRemover(String remover) {
    String _temp0 = intl.Intl.selectLogic(remover, {
      'creator': 'Host removes',
      'opponent': 'Opponent removes',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String roomChipSide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'Host plays Cho',
      'han': 'Host plays Han',
      'random': 'Random sides',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get roomChipListed => 'Public';

  @override
  String get roomChipUnlisted => 'Private';

  @override
  String get roomHost => 'Host';

  @override
  String get roomGuest => 'Opponent';

  @override
  String get roomWaitingGuest => 'Waiting for an opponent';

  @override
  String get roomKick => 'Remove';

  @override
  String roomKickConfirm(String nickname) {
    return 'Remove $nickname? They won\'t be able to rejoin this room';
  }

  @override
  String get roomInviteTitle => 'Invite with a link';

  @override
  String get roomCopyLink => 'Copy link';

  @override
  String get roomShareLink => 'Share';

  @override
  String get roomLinkCopied => 'Link copied';

  @override
  String roomInviteMessage(String link) {
    return 'Want to play Janggi with me on Janggigo? $link';
  }

  @override
  String get roomStart => 'Start game';

  @override
  String get roomStartWaiting => 'You can start once an opponent joins';

  @override
  String get roomWaitingHost => 'The game begins when the host starts it';

  @override
  String get roomLeave => 'Leave';

  @override
  String get roomLeaveHostConfirm => 'Leaving will close the room. Leave?';

  @override
  String get roomClosedNotice => 'The room has closed';

  @override
  String get roomKickedNotice => 'The host removed you from the room';

  @override
  String get roomRemovedNotice =>
      'You were disconnected too long and left the room';

  @override
  String get createRoomTitle => 'Create room';

  @override
  String get createRoomSubmit => 'Create room';

  @override
  String get createRoomSide => 'My side';

  @override
  String get createRoomHandicapSide => 'The side removing pieces plays Han';

  @override
  String get createRoomHandicap => 'Handicap game';

  @override
  String get createRoomHandicapDescription =>
      'One side plays without some pieces';

  @override
  String get createRoomRemover => 'Who removes pieces';

  @override
  String handicapRemover(String remover) {
    String _temp0 = intl.Intl.selectLogic(remover, {
      'creator': 'Me',
      'opponent': 'Opponent',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get createRoomPieces => 'Pieces to remove';

  @override
  String get createRoomPiecesHint => 'Choose the pieces to remove';

  @override
  String handicapPieceLabel(String side, String piece) {
    return '$side $piece';
  }

  @override
  String boardSideName(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'left': 'Left',
      'right': 'Right',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get createRoomListed => 'Show in room list';

  @override
  String get createRoomListedOn =>
      'Anyone can find and join it in the room list';

  @override
  String get createRoomListedOff => 'Only people with the invite link can join';

  @override
  String get createRoomRankRange => 'Allowed ranks';

  @override
  String get resultBackToRoom => 'Back to room';

  @override
  String get lobbyTabUsers => 'Players online';

  @override
  String get onlineUsersSearch => 'Search nicknames';

  @override
  String onlineUsersCount(int count) {
    return '$count online';
  }

  @override
  String get onlineUsersChallengesEnabled => 'Accept challenges';

  @override
  String onlineStatus(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'waiting': 'Waiting',
      'playing': 'In a game',
      'notAccepting': 'Not accepting',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get onlineUsersChallenge => 'Challenge';

  @override
  String get onlineUsersEmpty => 'No one else is online right now';

  @override
  String get onlineUsersNoMatch => 'No matching nickname';

  @override
  String get errorLoadOnlineUsers => 'Couldn\'t load players online';

  @override
  String get errorChallengesEnabled =>
      'Couldn\'t change this setting. Please try again later';

  @override
  String get userInfoChallenge => 'Challenge';

  @override
  String get userInfoBlock => 'Block';

  @override
  String blockConfirm(String nickname) {
    return 'Block $nickname? You won\'t see their messages or challenges';
  }

  @override
  String get blockAction => 'Block';

  @override
  String blockDone(String nickname) {
    return 'You blocked $nickname';
  }

  @override
  String get errorBlock => 'Couldn\'t block. Please try again later';

  @override
  String get challengeTitle => 'Challenge';

  @override
  String get challengeSide => 'My side';

  @override
  String get challengeSubmit => 'Send challenge';

  @override
  String get challengeWaiting => 'Waiting for a response';

  @override
  String get challengeCancel => 'Cancel challenge';

  @override
  String get challengeDeclined => 'Your challenge was declined';

  @override
  String get challengeExpired => 'No response';

  @override
  String get challengeCancelled => 'The challenge was cancelled';

  @override
  String get errorSendChallenge =>
      'Couldn\'t send the challenge. Please try again later';

  @override
  String get errorCancelChallenge =>
      'Couldn\'t cancel the challenge. Please try again later';

  @override
  String get errorChallengeLimited =>
      'You can\'t challenge this player for a while after several declines';

  @override
  String get errorTargetUnavailable =>
      'This player can\'t take a challenge right now';

  @override
  String get roomInviteUsers => 'Invite a player online';

  @override
  String get roomInviteUsersDescription =>
      'Pick someone online and invite them to this room';

  @override
  String roomInviteConfirm(String nickname) {
    return 'Invite $nickname to this room';
  }

  @override
  String get roomInviteSubmit => 'Send invite';

  @override
  String get incomingChallenge => 'You\'ve been challenged';

  @override
  String get incomingRoomInvite => 'You\'ve been invited to a room';

  @override
  String challengeChipMySide(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'cho': 'I play Cho',
      'han': 'I play Han',
      'random': 'Random sides',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String challengeChipRemover(String remover) {
    String _temp0 = intl.Intl.selectLogic(remover, {
      'me': 'I remove',
      'opponent': 'Opponent removes',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get challengeAccept => 'Accept';

  @override
  String get challengeDecline => 'Decline';

  @override
  String get challengeEnded => 'This challenge has already ended';

  @override
  String get errorRespondChallenge =>
      'Couldn\'t respond to the challenge. Please try again later';

  @override
  String get onlineUsersInvite => 'Invite';
}
