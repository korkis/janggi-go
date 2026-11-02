import {
  BANNED_WORDS,
  NICKNAME_IMPERSONATION_WORDS,
  NICKNAME_MAX_LENGTH,
  NICKNAME_MIN_LENGTH,
  NICKNAME_PATTERN,
} from "../config";
import {NicknameRejectReason} from "../models/nickname";

/** `nicknames` 문서 ID. 영문 대소문자만 다른 닉네임은 같은 것으로 본다(docs/database.md). */
export function getNicknameKey(nickname: string): string {
  return nickname.toLowerCase();
}

/** 다른 사람과 겹치는지 보기 전에 닉네임 자체의 문제를 찾는다. 문제가 없으면 null. */
export function findNicknameProblem(nickname: string): NicknameRejectReason | null {
  if (
    nickname.length < NICKNAME_MIN_LENGTH ||
    nickname.length > NICKNAME_MAX_LENGTH ||
    !NICKNAME_PATTERN.test(nickname)
  ) {
    return NicknameRejectReason.invalidFormat;
  }
  const lowerNickname = nickname.toLowerCase();
  if (NICKNAME_IMPERSONATION_WORDS.some((word) => lowerNickname.includes(word))) {
    return NicknameRejectReason.impersonation;
  }
  if (BANNED_WORDS.some((word) => lowerNickname.includes(word))) {
    return NicknameRejectReason.bannedWord;
  }
  return null;
}
