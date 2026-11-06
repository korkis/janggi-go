import dayjs from "dayjs";
import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {NICKNAME_CHANGE_COOLDOWN_DAYS, NICKNAME_FREE_CHANGE_COUNT} from "../config";
import {NicknameChangeErrorCode, NicknameRejectReason} from "../models/nickname";
import {getWalletInTransaction} from "../repositories/coinWalletsRepository";
import {getAppConfig} from "../repositories/configsRepository";
import {runTransaction} from "../repositories/firestore";
import {createNicknameChangeInTransaction} from "../repositories/nicknameChangesRepository";
import {
  createNicknameInTransaction,
  deleteNicknameInTransaction,
  getNicknameInTransaction,
} from "../repositories/nicknamesRepository";
import {
  createUserInTransaction,
  getUserInTransaction,
  updateNicknameInTransaction,
} from "../repositories/usersRepository";
import {
  createUserPrivateInTransaction,
  getUserPrivateInTransaction,
  updateNicknameChangeInTransaction,
} from "../repositories/usersPrivateRepository";
import {grantSignupInTransaction, spendNicknameChangeInTransaction} from "./coinService";
import {getNicknameKey} from "./nicknameService";

// 처음 가입한 사용자의 급수. 18급이다(docs/screens.md의 닉네임 정하기).
const INITIAL_RANK_LEVEL = 1;

/**
 * 첫 가입의 프로필을 만든다. `nicknames`, `users`, `users_private`와 가입 엽전을 한 트랜잭션으로 만든다.
 * 같은 닉네임으로 다시 부르면(응답을 못 받고 다시 누른 경우) 성공으로 보고 엽전도 다시 주지 않는다.
 */
export async function createProfile(uid: string, nickname: string): Promise<void> {
  const nicknameKey = getNicknameKey(nickname);
  const {coinSignupBonus} = await getAppConfig();
  const created = await runTransaction(async (transaction) => {
    const existingUser = await getUserInTransaction(transaction, uid);
    const reservation = await getNicknameInTransaction(transaction, nicknameKey);
    if (existingUser !== null) {
      if (existingUser.nickname === nickname) {
        return false;
      }
      throw new HttpsError("failed-precondition", "이미 프로필이 있습니다", {code: "profileExists"});
    }
    if (reservation !== null) {
      throw new HttpsError("already-exists", "이미 쓰는 닉네임입니다", {code: NicknameRejectReason.taken});
    }

    const now = Timestamp.now();
    createNicknameInTransaction(transaction, nicknameKey, {uid, createdAt: now});
    createUserInTransaction(transaction, uid, {
      nickname,
      rankLevel: INITIAL_RANK_LEVEL,
      stats: {games: 0, wins: 0, losses: 0},
      createdAt: now,
    });
    createUserPrivateInTransaction(transaction, uid, {
      challengesEnabled: true,
      rankProgress: 0,
      winsToNextRank: null,
      nicknameChangeCount: 0,
      nicknameChangedAt: null,
      sanction: null,
    });
    grantSignupInTransaction(transaction, uid, coinSignupBonus, now);
    return true;
  });
  logger.info("createProfile 완료", {uid, created});
}

/**
 * 닉네임을 바꾼다. `nicknames` 예약을 옮기고 `users.nickname`, `users_private`의 변경 횟수·시각, `nickname_changes` 기록을
 * 한 트랜잭션으로 쓴다. 이전 닉네임은 다른 사용자에게 보이는 곳에 남기지 않는다(docs/screens.md의 내 정보).
 *
 * 지금 닉네임과 같으면(응답을 못 받고 다시 누른 경우) 바꾸지 않고 성공으로 보며 엽전도 다시 받지 않는다. 바꾼 지 7일이 지나지
 * 않았으면 거절한다. 영문 대소문자만 바꾸는 것은 같은 예약을 그대로 쓴다.
 *
 * 무료 변경을 이미 썼으면 [coinCost]가 지금 값(`configs/app.coinNicknameChangeCost`)과 같을 때만 엽전을 받고 바꾼다. 없으면
 * `nicknameChangeNotFree`로 거절해 값을 보여주지 못하는 옛 앱이 엽전을 내지 않게 한다.
 */
export async function changeNickname(uid: string, nickname: string, coinCost: number | null): Promise<void> {
  const nicknameKey = getNicknameKey(nickname);
  const {coinNicknameChangeCost} = await getAppConfig();
  const changed = await runTransaction(async (transaction) => {
    const user = await getUserInTransaction(transaction, uid);
    const userPrivate = await getUserPrivateInTransaction(transaction, uid);
    const reservation = await getNicknameInTransaction(transaction, nicknameKey);
    const wallet = await getWalletInTransaction(transaction, uid);
    if (user === null || userPrivate === null) {
      throw new HttpsError("failed-precondition", "닉네임을 먼저 정해야 합니다", {
        code: NicknameChangeErrorCode.profileRequired,
      });
    }
    if (user.nickname === nickname) {
      return false;
    }
    const now = dayjs();
    const changedAt = userPrivate.nicknameChangedAt;
    if (changedAt !== null && now.isBefore(dayjs(changedAt.toDate()).add(NICKNAME_CHANGE_COOLDOWN_DAYS, "day"))) {
      throw new HttpsError("failed-precondition", "닉네임을 바꾼 지 얼마 되지 않았습니다", {
        code: NicknameChangeErrorCode.nicknameChangeCooldown,
      });
    }
    const paid = userPrivate.nicknameChangeCount >= NICKNAME_FREE_CHANGE_COUNT;
    if (paid && coinCost === null) {
      throw new HttpsError("failed-precondition", "무료 변경을 이미 썼습니다", {
        code: NicknameChangeErrorCode.nicknameChangeNotFree,
      });
    }
    if (paid && coinCost !== coinNicknameChangeCost) {
      throw new HttpsError("failed-precondition", "닉네임 변경 값이 바뀌었습니다", {
        code: NicknameChangeErrorCode.coinPriceChanged,
      });
    }
    if (reservation !== null && reservation.uid !== uid) {
      throw new HttpsError("already-exists", "이미 쓰는 닉네임입니다", {code: NicknameRejectReason.taken});
    }

    const timestamp = Timestamp.fromMillis(now.valueOf());
    if (paid) {
      const changeCount = userPrivate.nicknameChangeCount + 1;
      spendNicknameChangeInTransaction(transaction, uid, wallet, coinNicknameChangeCost, changeCount, timestamp);
    }
    const beforeKey = getNicknameKey(user.nickname);
    if (beforeKey !== nicknameKey) {
      deleteNicknameInTransaction(transaction, beforeKey);
      createNicknameInTransaction(transaction, nicknameKey, {uid, createdAt: timestamp});
    }
    updateNicknameInTransaction(transaction, uid, nickname);
    updateNicknameChangeInTransaction(transaction, uid, userPrivate.nicknameChangeCount + 1, timestamp);
    createNicknameChangeInTransaction(transaction, {uid, before: user.nickname, after: nickname, changedAt: timestamp});
    return true;
  });
  logger.info("changeNickname 완료", {uid, changed});
}
