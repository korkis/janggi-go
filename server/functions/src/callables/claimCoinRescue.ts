import {onCall} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {ClaimCoinRescueResult} from "../models/coin";
import {claimCoinRescue as claimCoinRescueInDb} from "../services/coinService";
import {requireUid} from "./auth";

/** 잔액이 기준 미만이면 바닥 구제를 받는다(docs/monetization.md의 엽전). 대상이 아니거나 오늘 이미 받았으면 granted false다. */
export const claimCoinRescue = onCall(async (request): Promise<ClaimCoinRescueResult> => {
  const uid = requireUid(request);
  logger.debug("claimCoinRescue 시작", {uid});
  return claimCoinRescueInDb(uid);
});
