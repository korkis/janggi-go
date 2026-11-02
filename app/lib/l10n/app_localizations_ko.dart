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
}
