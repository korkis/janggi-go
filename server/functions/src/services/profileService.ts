import {Timestamp} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {NicknameRejectReason} from "../models/nickname";
import {runTransaction} from "../repositories/firestore";
import {createNicknameInTransaction, getNicknameInTransaction} from "../repositories/nicknamesRepository";
import {createUserInTransaction, getUserInTransaction} from "../repositories/usersRepository";
import {createUserPrivateInTransaction} from "../repositories/usersPrivateRepository";
import {getNicknameKey} from "./nicknameService";

// 처음 가입한 사용자의 급수. 18급이다(docs/screens.md의 닉네임 정하기).
const INITIAL_RANK_LEVEL = 1;

/**
 * 첫 가입의 프로필을 만든다. `nicknames`, `users`, `users_private`를 한 트랜잭션으로 만든다.
 * 같은 닉네임으로 다시 부르면(응답을 못 받고 다시 누른 경우) 성공으로 본다.
 */
export async function createProfile(uid: string, nickname: string): Promise<void> {
  const nicknameKey = getNicknameKey(nickname);
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
    return true;
  });
  logger.info("createProfile 완료", {uid, created});
}
