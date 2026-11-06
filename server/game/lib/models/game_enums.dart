// 앱과 대국 서버가 함께 쓰는 대국 enum이다(`docs/database.md`의 공통 enum).
// 앱의 같은 이름 enum(`app/lib/models/game_enums.dart`)과 값을 일치시키고, DB에는 `name`을 쓴다.

/// 대국을 만든 방법.
enum GameMode { quick, room, challenge }

/// 대국 진행 단계.
enum GamePhase { setup, playing, finished }

/// 진영 고르기. `random`이면 서버가 정한다.
enum SideChoice { cho, han, random }

/// 방 상태. 방장이 나가면 `closed`가 되고 문서는 남긴다.
enum RoomStatus { waiting, playing, closed }

/// 접장기에서 기물을 떼는 쪽. 방장(신청이면 신청한 사람) 기준이다. 떼는 쪽이 한을 잡는다(`docs/game/handicap.md`).
enum HandicapRemover { creator, opponent }

/// 대국 신청 상태. 응답을 기다리면 `pending`이고, 나머지는 끝난 신청이다.
enum ChallengeStatus { pending, accepted, declined, expired, cancelled }

/// 대국실 접속자의 상태(`online_users.status`). 대국(상차림 포함) 중이면 `playing`이다.
enum OnlineStatus { waiting, playing }

/// 기물 재질(`docs/ui.md`의 기물). 앱의 `PieceMaterial`, Functions의 `PieceMaterial`과 값을 일치시킨다.
enum PieceMaterial { plastic, wood, aluminum }
