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
}
