import dayjs from "dayjs";
import {
  ADMOB_VERIFIER_KEYS_CACHE_HOURS,
  ADMOB_VERIFIER_KEYS_REFRESH_SECONDS,
  ADMOB_VERIFIER_KEYS_TIMEOUT_MS,
  ADMOB_VERIFIER_KEYS_URL,
} from "../config";

// 읽어 둔 공개 키(key_id별 PEM)와 읽은 시각(epoch ms).
let cachedKeys: {pemByKeyId: Map<string, string>; loadedAt: number} | null = null;

async function fetchKeys(): Promise<Map<string, string>> {
  const response = await fetch(ADMOB_VERIFIER_KEYS_URL, {signal: AbortSignal.timeout(ADMOB_VERIFIER_KEYS_TIMEOUT_MS)});
  if (!response.ok) {
    throw new Error(`AdMob 공개 키 응답 오류: ${response.status}`);
  }
  const body = (await response.json()) as {keys?: {keyId?: unknown; pem?: unknown}[]};
  const keys = new Map<string, string>();
  for (const key of body.keys ?? []) {
    if (typeof key.pem === "string" && (typeof key.keyId === "number" || typeof key.keyId === "string")) {
      keys.set(String(key.keyId), key.pem);
    }
  }
  if (keys.size === 0) {
    throw new Error("AdMob 공개 키 응답에 키가 없습니다");
  }
  return keys;
}

/**
 * [keyId]의 공개 키(PEM). 없는 키이면 null이다. 읽지 못하면 오류를 던져 구글이 콜백을 다시 보내게 한다.
 * 구글이 키를 바꾸므로 모르는 키가 오면 다시 읽어 본다. 가짜 key_id로 구글 주소를 계속 부르지 않게 간격을 둔다.
 */
export async function getAdmobVerifierKey(keyId: string): Promise<string | null> {
  const now = dayjs().valueOf();
  const expired = cachedKeys === null || now - cachedKeys.loadedAt >= ADMOB_VERIFIER_KEYS_CACHE_HOURS * 3600 * 1000;
  const refreshable = cachedKeys === null || now - cachedKeys.loadedAt >= ADMOB_VERIFIER_KEYS_REFRESH_SECONDS * 1000;
  if (expired || (!cachedKeys?.pemByKeyId.has(keyId) && refreshable)) {
    cachedKeys = {pemByKeyId: await fetchKeys(), loadedAt: now};
  }
  return cachedKeys?.pemByKeyId.get(keyId) ?? null;
}
