import 'package:json_annotation/json_annotation.dart';

part 'connection.g.dart';

/// RTDB `connections/{uid}/{connectionId}`. 앱의 접속 상태다(`docs/database.md`).
///
/// 앱이 쓰고 대국 서버는 접속 끊김 판정에 읽기만 한다. 필드는 앱의 `Connection`(`app/lib/models/connection.dart`)과
/// 일치시킨다. 시각은 Unix epoch 밀리초(UTC)이며 앱이 서버 시각으로만 쓴다(보안 규칙).
@JsonSerializable()
class Connection {
  /// 연결되어 있다. 앱이 `onDisconnect`로 false를 걸어 둔다.
  final bool online;

  /// 앱이 화면에 떠 있다.
  final bool foreground;

  /// `online`이고 `foreground`가 된 시각.
  final int activeSince;

  /// 마지막으로 살아 있음을 알린 시각.
  final int lastSeenAt;

  const Connection({
    required this.online,
    required this.foreground,
    required this.activeSince,
    required this.lastSeenAt,
  });

  factory Connection.fromJson(Map<String, dynamic> json) => _$ConnectionFromJson(json);
}
