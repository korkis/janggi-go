import dayjs from "dayjs";
import {Timestamp, Transaction} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {SANCTION_EXPIRE_BATCH_SIZE} from "../config";
import {ActiveSanction, SanctionType, UserPrivate} from "../models/userPrivate";
import {runTransaction} from "../repositories/firestore";
import {createSanctionInTransaction} from "../repositories/sanctionsRepository";
import {
  getUidsWithEndedSanction,
  getUserPrivateInTransaction,
  updateSanctionInTransaction,
} from "../repositories/usersPrivateRepository";

/** 걸 제재. */
export interface SanctionRequest {
  uid: string;
  type: SanctionType;
  // 채팅 제한과 이용 정지의 기간(일). 경고와 영구 정지는 null.
  durationDays: number | null;
  // 사용자에게 보이는 사유.
  reason: string;
  reportId: string | null;
  // 자동 제재면 null.
  adminUid: string | null;
}

/** [sanction]이 [now]에 아직 대국이나 채팅을 막고 있는지. 경고와 끝난 제재는 막지 않는다. */
function isBlocking(sanction: ActiveSanction | null, now: dayjs.Dayjs): boolean {
  if (sanction === null || sanction.type === SanctionType.warning) {
    return false;
  }
  return sanction.endsAt === null || dayjs(sanction.endsAt.toDate()).isAfter(now);
}

/**
 * 트랜잭션 안에서 제재를 걸고 제재 ID를 돌려준다. `sanctions`에 이력을 만들고 `users_private.sanction`을 바꾼다.
 * [userPrivate]는 같은 트랜잭션에서 미리 읽은 값이다(트랜잭션은 읽기를 쓰기보다 먼저 한다).
 *
 * 새 제재가 지금 걸린 제재를 바꾼다. 다만 경고는 아직 막고 있는 제재(채팅 제한, 이용 정지, 영구 정지)를 풀지 않도록 이력에만 남긴다.
 */
export function applySanctionInTransaction(
  transaction: Transaction,
  request: SanctionRequest,
  userPrivate: UserPrivate,
  now: dayjs.Dayjs,
): string {
  const endsAt =
    request.durationDays === null ? null : Timestamp.fromDate(now.add(request.durationDays, "day").toDate());
  const startsAt = Timestamp.fromDate(now.toDate());
  const sanctionId = createSanctionInTransaction(transaction, {
    uid: request.uid,
    type: request.type,
    startsAt,
    endsAt,
    reason: request.reason,
    reportId: request.reportId,
    adminUid: request.adminUid,
    createdAt: startsAt,
  });
  const keepCurrent = request.type === SanctionType.warning && isBlocking(userPrivate.sanction ?? null, now);
  if (!keepCurrent) {
    updateSanctionInTransaction(transaction, request.uid, {type: request.type, endsAt, reason: request.reason});
  }
  logger.debug("applySanctionInTransaction", {uid: request.uid, type: request.type, sanctionId, keepCurrent});
  return sanctionId;
}

/** 끝난 제재를 `users_private.sanction`에서 지운다(docs/server.md의 expireSanctions). 이력(`sanctions`)은 그대로 둔다. */
export async function expireSanctions(): Promise<void> {
  const now = Timestamp.now();
  const uids = await getUidsWithEndedSanction(now, SANCTION_EXPIRE_BATCH_SIZE);
  let cleared = 0;
  for (const uid of uids) {
    // 읽은 뒤 새 제재가 걸렸을 수 있으므로 트랜잭션에서 다시 확인한다.
    const expired = await runTransaction(async (transaction) => {
      const endsAt = (await getUserPrivateInTransaction(transaction, uid))?.sanction?.endsAt ?? null;
      if (endsAt === null || endsAt.toMillis() > now.toMillis()) {
        return false;
      }
      updateSanctionInTransaction(transaction, uid, null);
      return true;
    });
    if (expired) {
      cleared += 1;
    }
  }
  logger.info("expireSanctions 완료", {found: uids.length, cleared});
}
