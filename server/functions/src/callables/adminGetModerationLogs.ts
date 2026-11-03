import {HttpsError, onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {ModerationLogView, Page, PageCursor} from "../models/admin";
import {getModerationLogs} from "../services/adminModerationLogService";
import {isValidDocumentId, validateCursor} from "./adminParams";
import {requireAdmin} from "./auth";

interface AdminGetModerationLogsParams {
  // 이 사람의 기록만 본다. 없으면 모든 사람이다.
  uid?: string | null;
  cursor?: PageCursor | null;
}

function validateParams(requestParams: AdminGetModerationLogsParams): void {
  const uid: unknown = requestParams?.uid ?? null;
  if (uid !== null && !isValidDocumentId(uid)) {
    throw new HttpsError("invalid-argument", "uid가 올바르지 않습니다");
  }
  validateCursor(requestParams?.cursor);
}

/** Admin 웹의 검사 기록. 금칙어와 OpenAI Moderation에 걸린 메시지를 최근 것부터 한 쪽씩 읽는다. */
export const adminGetModerationLogs = onCall<AdminGetModerationLogsParams>(
  async (request): Promise<Page<ModerationLogView>> => {
    const requestParams = request.data;
    const adminUid = requireAdmin(request);
    validateParams(requestParams);
    const uid = requestParams?.uid ?? null;
    const page = await getModerationLogs(uid, requestParams?.cursor ?? null);
    logger.info("adminGetModerationLogs 완료", {adminUid, uid, count: page.items.length});
    return page;
  },
);
