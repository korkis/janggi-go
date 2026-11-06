import {onCall} from "firebase-functions/https";
import {requestAccountDeletion} from "../services/accountService";
import {requireUid} from "./auth";

/** 회원 탈퇴. 30일 뒤 지운다(docs/server.md의 회원 탈퇴). 웹을 멈춰도 탈퇴는 받으므로 `webEnabled`를 보지 않는다. */
export const deleteAccount = onCall(async (request): Promise<Record<string, never>> => {
  const uid = requireUid(request);
  await requestAccountDeletion(uid);
  return {};
});
