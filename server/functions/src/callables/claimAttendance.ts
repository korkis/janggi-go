import {onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {ClaimAttendanceResult} from "../models/coin";
import {claimAttendance as claimAttendanceInDb} from "../services/coinService";
import {requireUid, requireWebAllowed} from "./auth";

/** 오늘의 출석 엽전을 받는다(docs/monetization.md의 엽전). 오늘 이미 받았으면 granted false다. */
export const claimAttendance = onCall(async (request): Promise<ClaimAttendanceResult> => {
  const uid = requireUid(request);
  await requireWebAllowed(request);
  logger.debug("claimAttendance 시작", {uid});
  return claimAttendanceInDb(uid);
});
