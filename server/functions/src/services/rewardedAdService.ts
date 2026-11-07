import {verify} from "node:crypto";
import * as logger from "firebase-functions/logger";
import {ADMOB_REWARDED_AD_UNITS} from "../config";
import {RewardedAdResult} from "../models/coin";
import {getAdmobVerifierKey} from "./admobVerifierKeys";
import {grantRewardedAd} from "./coinService";

// 서명 앞까지가 서명된 내용이다. 구글 문서에 따르면 signature와 key_id는 언제나 이 순서로 맨 뒤에 온다.
const SIGNATURE_PARAM = "&signature=";
const KEY_ID_PARAM = "&key_id=";

/** 콜백의 쿼리 문자열을 나눈 것. */
interface SignedCallback {
  // 서명된 내용. 구글이 서명한 그대로이므로 디코딩하거나 순서를 바꾸지 않는다.
  content: string;
  signature: Buffer;
  keyId: string;
}

/** 서명 필드가 없거나 모양이 틀린 콜백. 구글이 보낸 것이 아니다. */
export class InvalidAdmobCallbackError extends Error {}

/** [rawQuery]를 서명된 내용과 서명으로 나눈다. 모양이 틀리면 [InvalidAdmobCallbackError]다. */
function parseSignedCallback(rawQuery: string): SignedCallback {
  const signatureAt = rawQuery.indexOf(SIGNATURE_PARAM);
  const keyIdAt = rawQuery.indexOf(KEY_ID_PARAM, signatureAt);
  if (signatureAt <= 0 || keyIdAt < 0) {
    throw new InvalidAdmobCallbackError("signature나 key_id가 없습니다");
  }
  return {
    content: rawQuery.slice(0, signatureAt),
    signature: Buffer.from(rawQuery.slice(signatureAt + SIGNATURE_PARAM.length, keyIdAt), "base64url"),
    keyId: rawQuery.slice(keyIdAt + KEY_ID_PARAM.length),
  };
}

/** 구글의 서명이 맞는지. 키는 ECDSA, 해시는 SHA-256, 서명은 DER이다. */
async function isSignatureValid({content, signature, keyId}: SignedCallback): Promise<boolean> {
  const pem = await getAdmobVerifierKey(keyId);
  if (pem === null) {
    return false;
  }
  return verify("sha256", Buffer.from(content, "utf8"), pem, signature);
}

/** 서명을 통과한 콜백의 값을 보고 엽전을 준다. 값은 서명된 내용에서만 읽으므로 서명 뒤에 덧붙인 파라미터는 쓰이지 않는다. */
async function handleVerifiedCallback(params: URLSearchParams): Promise<RewardedAdResult> {
  if (!ADMOB_REWARDED_AD_UNITS.includes(params.get("ad_unit") ?? "")) {
    return RewardedAdResult.unknownAdUnit;
  }
  const uid = params.get("user_id");
  const adTransactionId = params.get("transaction_id");
  if (uid === null || uid === "" || adTransactionId === null || adTransactionId === "") {
    return RewardedAdResult.missingField;
  }
  return grantRewardedAd(uid, adTransactionId);
}

/**
 * AdMob의 보상 콜백 하나를 처리한다(docs/server.md의 앱 광고). 서명이 틀리면 [InvalidAdmobCallbackError]다.
 * 서명이 맞으면 주지 않아도 정상 처리로 끝낸다. 다시 보내도 결과가 같기 때문이다.
 */
export async function receiveAdmobCallback(rawQuery: string): Promise<void> {
  const callback = parseSignedCallback(rawQuery);
  if (!(await isSignatureValid(callback))) {
    throw new InvalidAdmobCallbackError("서명이 맞지 않습니다");
  }
  const params = new URLSearchParams(callback.content);
  const result = await handleVerifiedCallback(params);
  const fields = {
    uid: params.get("user_id"),
    adUnit: params.get("ad_unit"),
    transactionId: params.get("transaction_id"),
    result,
  };
  if (result === RewardedAdResult.granted || result === RewardedAdResult.duplicate) {
    logger.info("admobRewardCallback 완료", fields);
    return;
  }
  if (result === RewardedAdResult.limitReached) {
    logger.info("admobRewardCallback 하루 횟수를 넘어 주지 않음", fields);
    return;
  }
  logger.warn("admobRewardCallback 주지 않음", fields);
}
