import {REVENUECAT_API_TIMEOUT_MS, REVENUECAT_API_URL} from "../config";

/**
 * RevenueCat 고객을 지운다. 이미 없으면(404) 성공으로 본다. 실패하면 오류를 던져 다음 예약 작업이 다시 하게 한다.
 * 자동 테스트는 이 모듈을 가짜로 바꿔 네트워크를 쓰지 않는다.
 */
export async function deleteRevenueCatCustomer(uid: string, apiKey: string): Promise<void> {
  const response = await fetch(`${REVENUECAT_API_URL}/subscribers/${encodeURIComponent(uid)}`, {
    method: "DELETE",
    headers: {Authorization: `Bearer ${apiKey}`},
    signal: AbortSignal.timeout(REVENUECAT_API_TIMEOUT_MS),
  });
  if (!response.ok && response.status !== 404) {
    throw new Error(`RevenueCat 고객 지우기 응답 오류: ${response.status}`);
  }
}
