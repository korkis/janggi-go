import 'package:janggi_core/janggi_core.dart';

import '../config.dart';
import '../http/callable.dart';
import '../models/game_enums.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import 'param_checks.dart';

/// 파라미터: `hostSide`(SideChoice), `handicap?`(`remover`: HandicapRemover, `pieces`: 서로 다른 HandicapPiece 1개 이상),
/// `listed`(boolean), `rankRange?`(`min`, `max`: 1~27의 급수, `min` ≤ `max`, 공개 방에서만).
RoomOptions validateParams(Object? requestParams) {
  final params = requireParamsMap(requestParams);
  final hostSide = requireEnum(params, 'hostSide', SideChoice.values);
  final listed = params['listed'];
  if (listed is! bool) {
    throw const CallableException.invalidArgument('listed는 boolean이어야 합니다');
  }
  final handicap = switch (params['handicap']) {
    null => null,
    final Map<String, Object?> value => _validateHandicap(value),
    _ => throw const CallableException.invalidArgument('handicap은 객체여야 합니다'),
  };
  final rankRange = switch (params['rankRange']) {
    null => null,
    final Map<String, Object?> value => _validateRankRange(value),
    _ => throw const CallableException.invalidArgument('rankRange는 객체여야 합니다'),
  };
  if (rankRange != null && !listed) {
    throw const CallableException.invalidArgument('rankRange는 공개 방에서만 정합니다');
  }
  return RoomOptions(hostSide: hostSide, handicap: handicap, listed: listed, rankRange: rankRange);
}

RoomHandicap _validateHandicap(Map<String, Object?> params) {
  final remover = requireEnum(params, 'remover', HandicapRemover.values);
  final names = params['pieces'];
  if (names is! List<Object?> || names.isEmpty) {
    throw const CallableException.invalidArgument('handicap.pieces는 기물 이름 목록이어야 합니다');
  }
  final pieces = <HandicapPiece>[];
  for (final name in names) {
    final piece = name is String ? HandicapPiece.values.asNameMap()[name] : null;
    if (piece == null || pieces.contains(piece)) {
      throw const CallableException.invalidArgument('handicap.pieces는 서로 다른 HandicapPiece여야 합니다');
    }
    pieces.add(piece);
  }
  return RoomHandicap(remover: remover, pieces: pieces);
}

RankRange _validateRankRange(Map<String, Object?> params) {
  final min = params['min'];
  final max = params['max'];
  if (min is! int || max is! int || min < 1 || max > maxRankLevel || min > max) {
    throw const CallableException.invalidArgument('rankRange는 1~$maxRankLevel 사이의 min ≤ max여야 합니다');
  }
  return RankRange(min: min, max: max);
}

/// 방을 만든다(`docs/server.md`의 방). 결과: `roomId`.
class CreateRoomEndpoint extends CallableEndpoint {
  final RoomService roomService;

  CreateRoomEndpoint({required this.roomService});

  @override
  String get name => 'createRoom';

  @override
  Future<Object?> handle(CallableRequest request, Object? data) async {
    final requestParams = data;
    final options = validateParams(requestParams);
    final roomId = await roomService.createRoom(request.uid, request.user, options, now: request.receivedAt);
    return {'roomId': roomId};
  }
}
