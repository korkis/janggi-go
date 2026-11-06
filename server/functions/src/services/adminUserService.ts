import dayjs from "dayjs";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {ADMIN_HISTORY_LIMIT} from "../config";
import {AdminErrorCode, UserHistoryView} from "../models/admin";
import {runTransaction} from "../repositories/firestore";
import {getModerationLogsPage} from "../repositories/moderationLogsRepository";
import {getNicknameChangesByUid} from "../repositories/nicknameChangesRepository";
import {getNickname} from "../repositories/nicknamesRepository";
import {getReportsByTarget} from "../repositories/reportsRepository";
import {getSanctionsByUid} from "../repositories/sanctionsRepository";
import {getUsers} from "../repositories/usersRepository";
import {getUserPrivate, getUserPrivateInTransaction} from "../repositories/usersPrivateRepository";
import {toModerationLogView, toReportSummaryView, toSanctionView} from "./adminViewService";
import {getNicknameKey} from "./nicknameService";
import {SanctionRequest, applySanctionInTransaction} from "./sanctionService";

/** 닉네임으로 uid를 찾는다. 영문 대소문자는 가리지 않는다. 없으면 notFound. */
export async function findUidByNickname(nickname: string): Promise<string> {
  const reservation = await getNickname(getNicknameKey(nickname));
  if (reservation === null) {
    throw new HttpsError("not-found", "사용자가 없습니다", {code: AdminErrorCode.notFound});
  }
  return reservation.uid;
}

/**
 * 사용자의 프로필, 지금 걸린 제재, 최근 제재·신고·검사 기록·닉네임 변경을 읽는다(docs/moderation.md의 Admin 웹 처리).
 * 프로필과 비공개 정보, 남은 기록이 모두 없으면 notFound. 탈퇴해 지운 사용자도 처리 전 신고를 열 수 있도록 기록이 있으면 돌려준다.
 */
export async function getUserHistory(uid: string): Promise<UserHistoryView> {
  const [userPrivate, sanctions, reports, logs, nicknameChanges] = await Promise.all([
    getUserPrivate(uid),
    getSanctionsByUid(uid, ADMIN_HISTORY_LIMIT),
    getReportsByTarget(uid, ADMIN_HISTORY_LIMIT),
    getModerationLogsPage(uid, null, ADMIN_HISTORY_LIMIT),
    getNicknameChangesByUid(uid, ADMIN_HISTORY_LIMIT),
  ]);
  const users = await getUsers([uid, ...reports.map((entry) => entry.report.reporterUid)]);
  const user = users.get(uid) ?? null;
  const hasRecords = sanctions.length > 0 || reports.length > 0 || logs.length > 0;
  if (user === null && userPrivate === null && !hasRecords) {
    throw new HttpsError("not-found", "사용자가 없습니다", {code: AdminErrorCode.notFound});
  }
  const sanction = userPrivate?.sanction ?? null;
  return {
    uid,
    profile:
      user === null
        ? null
        : {
            nickname: user.nickname,
            rankLevel: user.rankLevel,
            stats: user.stats,
            createdAt: user.createdAt.toMillis(),
            deletedAt: user.deletedAt?.toMillis() ?? null,
          },
    sanction:
      sanction === null
        ? null
        : {type: sanction.type, endsAt: sanction.endsAt?.toMillis() ?? null, reason: sanction.reason},
    sanctions: sanctions.map(toSanctionView),
    reports: reports.map((entry) => toReportSummaryView(entry, users)),
    moderationLogs: logs.map((entry) => toModerationLogView(entry, users)),
    nicknameChanges: nicknameChanges.map((change) => ({
      before: change.before,
      after: change.after,
      changedAt: change.changedAt.toMillis(),
    })),
  };
}

/** 신고 없이 사용자에게 제재를 건다(Admin 웹의 사용자 조회 화면). 결과는 바뀐 사용자 정보다. */
export async function sanctionUser(request: SanctionRequest): Promise<UserHistoryView> {
  const now = dayjs();
  const sanctionId = await runTransaction(async (transaction) => {
    const userPrivate = await getUserPrivateInTransaction(transaction, request.uid);
    if (userPrivate === null) {
      throw new HttpsError("not-found", "사용자가 없습니다", {code: AdminErrorCode.notFound});
    }
    return applySanctionInTransaction(transaction, request, userPrivate, now);
  });
  logger.info("sanctionUser 완료", {
    adminUid: request.adminUid,
    uid: request.uid,
    type: request.type,
    durationDays: request.durationDays,
    sanctionId,
  });
  return getUserHistory(request.uid);
}
