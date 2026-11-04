import 'package:json_annotation/json_annotation.dart';

part 'connection.g.dart';

/// RTDB `connections/{uid}/{connectionId}`. 앱의 접속 상태다(`docs/database.md`).
///
/// 앱이 쓰고 대국 서버가 접속 끊김 판정에 읽는다. 필드는 대국 서버의 `Connection`(`server/game/lib/models/connection.dart`)과
/// 일치시킨다. 쓸 때는 시각에 서버 시각을 넣어야 하므로 이 모델은 읽기에만 쓴다.
@JsonSerializable(createToJson: false)
class Connection {
  /// 연결되어 있다. 앱이 `onDisconnect`로 false를 걸어 둔다.
  final bool online;

  /// 앱이 화면에 떠 있다.
  final bool foreground;

  /// `online`이고 `foreground`가 된 시각(ms).
  final int activeSince;

  /// 마지막으로 살아 있음을 알린 시각(ms).
  final int lastSeenAt;

  /// 웹 탭이 숨겨져 있다. 웹만 쓰고 앱은 쓰지 않는다(없으면 숨겨지지 않은 것). 웹은 탭이 숨겨져도 `foreground`를 바꾸지 않는다.
  final bool? tabHidden;

  const Connection({
    required this.online,
    required this.foreground,
    required this.activeSince,
    required this.lastSeenAt,
    this.tabHidden,
  });

  factory Connection.fromJson(Map<String, dynamic> json) => _$ConnectionFromJson(json);
}
