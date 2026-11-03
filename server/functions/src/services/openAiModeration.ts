import {MODERATION_API_URL, MODERATION_MODEL, MODERATION_TIMEOUT_MS} from "../config";
import {ModerationScores} from "../models/chat";

/** OpenAI Moderation 한 번의 결과. */
export interface OpenAiModerationResult {
  flagged: boolean;
  // 걸린 분류.
  categories: string[];
  scores: ModerationScores;
}

/** OpenAI Moderation 호출 실패. [status]는 HTTP 상태이고, 응답을 받지 못했으면(시간 초과, 네트워크) null이다. */
export class ModerationApiError extends Error {
  constructor(
    message: string,
    readonly status: number | null,
  ) {
    super(message);
    this.name = "ModerationApiError";
  }

  /** 키가 없거나 권한이 없다(401, 403). 키의 Moderations 권한을 확인해야 한다. */
  isPermissionError(): boolean {
    return this.status === 401 || this.status === 403;
  }
}

interface ModerationResponse {
  results?: {
    flagged?: unknown;
    categories?: Record<string, unknown>;
    category_scores?: Record<string, unknown>;
  }[];
}

/** [text]를 OpenAI Moderation으로 검사한다. 자동 테스트는 이 모듈을 가짜로 바꿔 네트워크를 쓰지 않는다. */
export async function moderateWithOpenAi(text: string, apiKey: string): Promise<OpenAiModerationResult> {
  let response: Response;
  try {
    response = await fetch(MODERATION_API_URL, {
      method: "POST",
      headers: {Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json"},
      body: JSON.stringify({model: MODERATION_MODEL, input: text}),
      signal: AbortSignal.timeout(MODERATION_TIMEOUT_MS),
    });
  } catch (error) {
    throw new ModerationApiError(`OpenAI Moderation 요청 실패: ${(error as Error).message}`, null);
  }
  if (!response.ok) {
    throw new ModerationApiError(`OpenAI Moderation 응답 오류: ${response.status}`, response.status);
  }
  const body = (await response.json()) as ModerationResponse;
  const result = body.results?.[0];
  if (result === undefined || typeof result.flagged !== "boolean") {
    throw new ModerationApiError("OpenAI Moderation 응답에 결과가 없습니다", response.status);
  }
  const categories: string[] = [];
  for (const [category, flagged] of Object.entries(result.categories ?? {})) {
    if (flagged === true) {
      categories.push(category);
    }
  }
  const scores: ModerationScores = {};
  for (const [category, score] of Object.entries(result.category_scores ?? {})) {
    if (typeof score === "number") {
      scores[category] = score;
    }
  }
  return {flagged: result.flagged, categories, scores};
}
