import dayjs from "dayjs";
import {HttpsError} from "firebase-functions/https";
import {ChatChannel, ChatErrorCode} from "../models/chat";
import {SanctionType, UserPrivate} from "../models/userPrivate";
import {getActiveGameAccess} from "../repositories/activeGamesRepository";

/**
 * [uid]가 이 채팅을 읽고 쓸 수 있는지 확인한다. 보안 규칙의 `chats_*` 읽기 조건과 같다(server/database.rules.json).
 * - 로비 채팅: 로그인한 사용자.
 * - 대국 채팅: 그 대국의 두 대국자.
 * - 관전 채팅: 로그인한 사용자. 대국자는 대국이 끝난 뒤에만.
 * 대국·관전 채팅은 `games_active`에 대국이 있어야 한다. 없으면 notFound, 권한이 없으면 notAllowed를 던진다.
 */
export async function requireChatAccess(uid: string, channel: ChatChannel, gameId: string | null): Promise<void> {
  if (channel === ChatChannel.lobby) {
    return;
  }
  const game = await getActiveGameAccess(gameId!);
  if (game === null) {
    throw new HttpsError("not-found", "대국이 없습니다", {code: ChatErrorCode.notFound});
  }
  const player = game.players.cho.uid === uid || game.players.han.uid === uid;
  if (channel === ChatChannel.game && !player) {
    throw new HttpsError("permission-denied", "대국자가 아닙니다", {code: ChatErrorCode.notAllowed});
  }
  if (channel === ChatChannel.spectator && player && game.phase !== "finished") {
    // 관전자가 다음 수를 알려주는 훈수를 막기 위해서다(docs/moderation.md의 채팅 종류).
    throw new HttpsError("permission-denied", "대국 중인 대국자는 관전 채팅을 쓸 수 없습니다", {
      code: ChatErrorCode.notAllowed,
    });
  }
}

/**
 * 채팅을 막는 제재가 걸려 있으면 던진다. 채팅 제한은 chatRestricted, 이용 정지와 영구 정지는 sanctioned다. 경고와 끝난 제재는 막지
 * 않는다. 끝난 제재는 예약 작업이 지우기 전이어도 끝난 것으로 본다.
 */
export function requireNotChatSanctioned(userPrivate: UserPrivate | null): void {
  const sanction = userPrivate?.sanction ?? null;
  if (sanction === null || sanction.type === SanctionType.warning) {
    return;
  }
  if (sanction.endsAt !== null && !dayjs(sanction.endsAt.toDate()).isAfter(dayjs())) {
    return;
  }
  if (sanction.type === SanctionType.chatRestriction) {
    throw new HttpsError("permission-denied", "채팅 제한 중입니다", {code: ChatErrorCode.chatRestricted});
  }
  throw new HttpsError("permission-denied", "이용 정지 중입니다", {code: ChatErrorCode.sanctioned});
}
