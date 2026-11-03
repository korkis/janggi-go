import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../models/challenge.dart';
import '../models/game_enums.dart';
import '../models/online_user.dart';

// 접속자 상태와 대국 신청 조건을 글자로 바꾼다. 대국실 접속자 탭, 다른 사용자 정보, 신청 받음 팝업이 같이 쓴다.

/// 접속자 상태 표시. 대국 중이면 대국 중, 아니면 신청 받기를 껐으면 신청 받지 않음이다. 값의 순서가 접속자 목록의 순서다.
enum OnlineUserState {
  waiting,
  notAccepting,
  playing;

  static OnlineUserState of(OnlineUser user) {
    if (user.status != OnlineStatus.waiting) {
      return OnlineUserState.playing;
    }
    if (!user.challengesEnabled) {
      return OnlineUserState.notAccepting;
    }
    return OnlineUserState.waiting;
  }

  /// 신청을 보낼 수 있는 상태.
  bool get isChallengeable => this == OnlineUserState.waiting;

  String getLabel(AppLocalizations l10n) {
    // 기다리는 중 / 대국 중 / 신청 받지 않음
    return l10n.onlineStatus(name);
  }
}

/// 받는 사람 기준의 신청 조건 칩 글자. 접장기면 "접장기"와 떼는 쪽, 그다음 내 진영, 시간 규칙이다(`docs/screens.md`의 대국 신청).
List<({String label, bool handicap})> getIncomingChallengeChips(AppLocalizations l10n, Challenge challenge) {
  final handicap = challenge.handicap;
  final timeControl = challenge.timeControl;
  final String mySide;
  if (handicap != null) {
    // 떼는 쪽이 한이다. remover는 신청한 사람 기준이다.
    mySide = handicap.remover == HandicapRemover.creator ? Side.cho.name : Side.han.name;
  } else {
    mySide = switch (challenge.senderSide) {
      SideChoice.cho => Side.han.name,
      SideChoice.han => Side.cho.name,
      SideChoice.random || null => SideChoice.random.name,
    };
  }
  return [
    if (handicap != null) ...[
      // 접장기
      (label: l10n.roomChipHandicap, handicap: true),
      // 내가 떼요 / 상대가 떼요
      (
        label: l10n.challengeChipRemover(handicap.remover == HandicapRemover.creator ? 'opponent' : 'me'),
        handicap: true,
      ),
    ],
    // 나는 초 / 나는 한 / 진영 무작위
    (label: l10n.challengeChipMySide(mySide), handicap: false),
    // 기본 10분 · 초읽기 30초 3회
    (
      label: l10n.gameTimeRule(
        timeControl.baseMs ~/ Duration.millisecondsPerMinute,
        timeControl.periodMs ~/ Duration.millisecondsPerSecond,
        timeControl.periods,
      ),
      handicap: false,
    ),
  ];
}
