import {createHash} from "node:crypto";
import dayjs from "dayjs";
import {UserRecord, getAuth} from "firebase-admin/auth";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {
  ACCOUNT_DELETION_GRACE_DAYS,
  ACCOUNT_PURGE_BATCH_SIZE,
  COIN_TRANSACTION_RETENTION_YEARS,
  MODERATION_LOG_RETENTION_DAYS,
} from "../config";
import {AccountErrorCode} from "../models/account";
import {AdminErrorCode, UserHistoryView} from "../models/admin";
import {deleteChallengesByUid} from "../repositories/challengesRepository";
import {deleteWalletInTransaction} from "../repositories/coinWalletsRepository";
import {setCoinTransactionsExpiry} from "../repositories/coinTransactionsRepository";
import {deleteConnections} from "../repositories/connectionsRepository";
import {setDeletedAccount} from "../repositories/deletedAccountsRepository";
import {runTransaction} from "../repositories/firestore";
import {deleteInventoryInTransaction} from "../repositories/inventoriesRepository";
import {deleteNicknameChangesByUid} from "../repositories/nicknameChangesRepository";
import {deleteNicknameInTransaction, getNicknameInTransaction} from "../repositories/nicknamesRepository";
import {deleteOnlineUser} from "../repositories/onlineUsersRepository";
import {deletePlayerStateInTransaction, getPlayerStateInTransaction} from "../repositories/playerStatesRepository";
import {setPurchasesExpiry} from "../repositories/purchasesRepository";
import {deleteRatingInTransaction} from "../repositories/ratingsRepository";
import {deleteRoomsByHost} from "../repositories/roomsRepository";
import {setSanctionsExpiry} from "../repositories/sanctionsRepository";
import {deleteUserBlocks} from "../repositories/userBlocksRepository";
import {
  deleteUserInTransaction,
  getUidsDeletedBefore,
  getUser,
  getUserInTransaction,
  updateDeletedAtInTransaction,
} from "../repositories/usersRepository";
import {deleteUserPrivateInTransaction, getUserPrivate} from "../repositories/usersPrivateRepository";
import {getUserHistory} from "./adminUserService";
import {getNicknameKey} from "./nicknameService";
import {deleteRevenueCatCustomer} from "./revenueCatApi";
import {isBlocking} from "./sanctionService";

// `firebase-admin/auth`가 없는 사용자에게 던지는 오류 코드.
const AUTH_USER_NOT_FOUND = "auth/user-not-found";

function isAuthUserNotFound(error: unknown): boolean {
  return (error as {code?: string}).code === AUTH_USER_NOT_FOUND;
}

/** Auth 계정을 읽는다. 없으면 null. */
async function getAuthUser(uid: string): Promise<UserRecord | null> {
  try {
    return await getAuth().getUser(uid);
  } catch (error) {
    if (isAuthUserNotFound(error)) {
      return null;
    }
    throw error;
  }
}

/** Auth 계정을 지운다. 이미 없어도 성공으로 본다. */
async function deleteAuthUser(uid: string): Promise<void> {
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if (!isAuthUserNotFound(error)) {
      throw error;
    }
  }
}

/**
 * Auth 계정의 로그인 수단마다 `deleted_accounts` 문서 ID를 만든다. 이메일과 계정 ID를 그대로 남기지 않도록 해시한다.
 * 같은 구글·애플 계정이나 같은 이메일로 다시 가입하면 uid가 달라져도 같은 값이 된다.
 */
export function getIdentityHashes(authUser: UserRecord): string[] {
  return authUser.providerData.map((provider) =>
    createHash("sha256").update(`${provider.providerId}:${provider.uid}`.toLowerCase()).digest("hex"),
  );
}

/** 호출자의 로그인 수단으로 만든 `deleted_accounts` 문서 ID. Auth 계정이 없으면 비어 있다. */
export async function getIdentityHashesByUid(uid: string): Promise<string[]> {
  const authUser = await getAuthUser(uid);
  return authUser === null ? [] : getIdentityHashes(authUser);
}

/**
 * 회원 탈퇴를 처리한다(docs/server.md의 회원 탈퇴). 진행 중인 대국이 있으면 `inGame`, 대기열·방·신청이 남아 있으면 `busy`로 거절한다.
 * `users.deletedAt`을 쓰고 Auth 계정을 비활성화한다. 실제로 지우는 것은 30일 뒤의 [purgeDeletedAccounts]다. 닉네임을 정하기 전이면
 * 지킬 것이 없으므로 Auth 계정을 바로 지운다. 응답을 못 받고 다시 불러도 결과가 같다.
 */
export async function requestAccountDeletion(uid: string): Promise<void> {
  const hasProfile = await runTransaction(async (transaction) => {
    const user = await getUserInTransaction(transaction, uid);
    if (user === null) {
      return false;
    }
    if (user.deletedAt != null) {
      return true;
    }
    const state = await getPlayerStateInTransaction(transaction, uid);
    if (state?.gameId != null) {
      throw new HttpsError("failed-precondition", "진행 중인 대국이 있습니다", {code: AccountErrorCode.inGame});
    }
    if (
      state?.roomId != null ||
      state?.quickQueueJoinedAt != null ||
      state?.outgoingChallengeId != null ||
      state?.incomingChallengeId != null
    ) {
      throw new HttpsError("failed-precondition", "대기열, 방, 신청에 남아 있습니다", {code: AccountErrorCode.busy});
    }
    updateDeletedAtInTransaction(transaction, uid, Timestamp.now());
    return true;
  });
  await Promise.all([deleteConnections(uid), deleteOnlineUser(uid)]);
  if (hasProfile) {
    await getAuth().updateUser(uid, {disabled: true});
    await getAuth().revokeRefreshTokens(uid);
  } else {
    await deleteAuthUser(uid);
  }
  logger.info("deleteAccount 완료", {uid, hasProfile});
}

/**
 * 탈퇴를 되돌린다. `deletedAt`을 지우고 Auth 계정을 다시 켠다. 결과는 바뀐 사용자 기록이다.
 * 이미 지웠으면 `notFound`, 탈퇴한 사용자가 아니면 `notDeleted`로 거절한다.
 */
export async function restoreAccount(adminUid: string, uid: string, reason: string): Promise<UserHistoryView> {
  await runTransaction(async (transaction) => {
    const user = await getUserInTransaction(transaction, uid);
    if (user === null) {
      throw new HttpsError("not-found", "사용자가 없습니다", {code: AdminErrorCode.notFound});
    }
    if (user.deletedAt == null) {
      throw new HttpsError("failed-precondition", "탈퇴한 사용자가 아닙니다", {code: AdminErrorCode.notDeleted});
    }
    updateDeletedAtInTransaction(transaction, uid, null);
  });
  await getAuth().updateUser(uid, {disabled: false});
  logger.info("adminRestoreAccount 완료", {adminUid, uid, reason});
  return getUserHistory(uid);
}

/** 제재가 남아 있으면 같은 계정의 재가입을 막는 기록을 남긴다(docs/database.md의 회원 탈퇴). */
async function keepSanctionBlock(uid: string, now: dayjs.Dayjs): Promise<void> {
  const sanction = (await getUserPrivate(uid))?.sanction ?? null;
  if (sanction === null || !isBlocking(sanction, now)) {
    return;
  }
  const hashes = await getIdentityHashesByUid(uid);
  await Promise.all(
    hashes.map((hash) =>
      setDeletedAccount(hash, {expiresAt: sanction.endsAt, createdAt: Timestamp.fromDate(now.toDate())}),
    ),
  );
}

/**
 * 탈퇴한 [uid]의 데이터를 지운다(docs/database.md의 회원 탈퇴). 앞 단계가 모두 끝나야 마지막 트랜잭션이 `users`를 지우므로, 중간에
 * 실패하면 다음 예약 작업이 처음부터 다시 한다. 그새 되돌렸으면 지우지 않는다.
 */
export async function purgeAccount(uid: string, now: dayjs.Dayjs, revenueCatApiKey: string): Promise<void> {
  const user = await getUser(uid);
  if (user?.deletedAt == null) {
    return;
  }
  await keepSanctionBlock(uid, now);
  const purchaseExpiresAt = Timestamp.fromDate(now.add(COIN_TRANSACTION_RETENTION_YEARS, "year").toDate());
  await Promise.all([
    deleteUserBlocks(uid),
    deleteNicknameChangesByUid(uid),
    deleteChallengesByUid(uid),
    deleteRoomsByHost(uid),
    setCoinTransactionsExpiry(uid, purchaseExpiresAt),
    setPurchasesExpiry(uid, purchaseExpiresAt),
    deleteRevenueCatCustomer(uid, revenueCatApiKey),
    setSanctionsExpiry(uid, Timestamp.fromDate(now.add(MODERATION_LOG_RETENTION_DAYS, "day").toDate())),
  ]);
  await deleteAuthUser(uid);
  await runTransaction(async (transaction) => {
    const current = await getUserInTransaction(transaction, uid);
    if (current?.deletedAt == null) {
      return;
    }
    const nicknameKey = getNicknameKey(current.nickname);
    const reservation = await getNicknameInTransaction(transaction, nicknameKey);
    if (reservation?.uid === uid) {
      deleteNicknameInTransaction(transaction, nicknameKey);
    }
    deleteUserInTransaction(transaction, uid);
    deleteUserPrivateInTransaction(transaction, uid);
    deleteWalletInTransaction(transaction, uid);
    deleteInventoryInTransaction(transaction, uid);
    deleteRatingInTransaction(transaction, uid);
    deletePlayerStateInTransaction(transaction, uid);
  });
}

/** 탈퇴하고 30일 지난 사람들을 지운다. 한 사람이 실패해도 나머지는 지우고, 실패한 사람은 다음 예약 작업이 다시 한다. */
export async function purgeDeletedAccounts(revenueCatApiKey: string): Promise<void> {
  const now = dayjs();
  const cutoff = Timestamp.fromDate(now.subtract(ACCOUNT_DELETION_GRACE_DAYS, "day").toDate());
  const uids = await getUidsDeletedBefore(cutoff, ACCOUNT_PURGE_BATCH_SIZE);
  let purged = 0;
  for (const uid of uids) {
    try {
      await purgeAccount(uid, now, revenueCatApiKey);
      purged += 1;
    } catch (error) {
      logger.error("purgeDeletedAccounts 실패", {uid, error});
    }
  }
  logger.info("purgeDeletedAccounts 완료", {found: uids.length, purged});
}
