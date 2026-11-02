import 'package:json_annotation/json_annotation.dart';

import 'timestamp_converter.dart';

part 'user_private.g.dart';

/// Firestore `users_private/{uid}`. 본인만 보는 정보다(`docs/database.md`).
///
/// 필드는 앱의 `UserPrivate`(`app/lib/models/user_private.dart`), Functions의 `UserPrivate`
/// (`server/functions/src/models/userPrivate.ts`)와 일치시킨다. Functions가 만들고, 대국 서버는 급수 진행(`rankProgress`,
/// `winsToNextRank`)만 쓰고 제재를 읽는다.
@JsonSerializable()
class UserPrivate {
  final bool challengesEnabled;

  /// 현재 급수 구간 안에서의 위치 0~1.
  final double rankProgress;

  /// 다음 급수까지의 어림 승수. 9단이거나 아직 급수 대국을 두지 않았으면 null.
  final int? winsToNextRank;
  final int nicknameChangeCount;

  @TimestampConverter()
  final DateTime? nicknameChangedAt;

  /// 지금 걸린 제재. 없으면 null.
  final ActiveSanction? sanction;

  const UserPrivate({
    required this.challengesEnabled,
    required this.rankProgress,
    required this.winsToNextRank,
    required this.nicknameChangeCount,
    required this.nicknameChangedAt,
    required this.sanction,
  });

  factory UserPrivate.fromJson(Map<String, dynamic> json) => _$UserPrivateFromJson(json);
}

/// 제재 종류. 앱, Functions, Admin 웹과 값을 일치시킨다(`docs/database.md`의 공통 enum).
enum SanctionType { warning, chatRestriction, suspension, permanentBan }

@JsonSerializable()
class ActiveSanction {
  final SanctionType type;

  /// 끝나는 시각. 영구 정지면 null.
  @TimestampConverter()
  final DateTime? endsAt;
  final String reason;

  const ActiveSanction({required this.type, required this.endsAt, required this.reason});

  factory ActiveSanction.fromJson(Map<String, dynamic> json) => _$ActiveSanctionFromJson(json);
}
