import 'package:flutter/foundation.dart';

import '../config.dart';

// 초대 링크(`docs/game/matching.md`의 링크) 주소를 만들고 읽는다.

/// 대국 서버가 만드는 방 ID 모양. 영문과 숫자다.
final _roomIdPattern = RegExp(r'^[A-Za-z0-9]{1,64}$');

/// [roomId]의 초대 링크. `https://janggi-go.web.app/r/<방 ID>`.
Uri buildInviteLink(String roomId) => Uri.https(inviteLinkHost, '/$inviteLinkPathPrefix/$roomId');

/// 앱으로 들어온 주소에서 방 ID를 읽는다. 초대 링크가 아니면 null.
///
/// - 안드로이드 App Links·iOS Universal Links: `https://janggi-go.web.app/r/<방 ID>`.
/// - 아이폰 앱 안 브라우저의 "앱에서 열기": `janggigo://r/<방 ID>`.
/// - 웹: 입장 페이지가 PC와 "웹에서 바로 두기"를 `/?room=<방 ID>`로 보낸다. 웹은 자기 주소만 받으므로 호스트를 보지 않는다.
String? getInviteRoomId(Uri uri, {bool web = kIsWeb}) {
  final String? roomId;
  if (web) {
    roomId = uri.queryParameters['room'];
  } else if (uri.scheme == appUrlScheme && uri.host == inviteLinkPathPrefix) {
    roomId = uri.pathSegments.length == 1 ? uri.pathSegments.single : null;
  } else if (uri.scheme == 'https' && uri.host == inviteLinkHost) {
    final segments = uri.pathSegments;
    roomId = segments.length == 2 && segments.first == inviteLinkPathPrefix ? segments.last : null;
  } else {
    roomId = null;
  }
  return roomId != null && _roomIdPattern.hasMatch(roomId) ? roomId : null;
}

/// 플레이 스토어 설치 정보(Play Install Referrer)에서 방 ID를 읽는다. 입장 페이지의 "앱 설치"는 `referrer=room%3D<방 ID>`를
/// 붙여 스토어를 연다. 링크로 설치하지 않았으면 null.
String? getInstallReferrerRoomId(String referrer) {
  final String? roomId;
  try {
    roomId = Uri.splitQueryString(referrer)['room'];
  } on FormatException {
    return null;
  }
  return roomId != null && _roomIdPattern.hasMatch(roomId) ? roomId : null;
}
