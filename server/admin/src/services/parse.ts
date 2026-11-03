// Callable 응답처럼 밖에서 들어온 `unknown` 값을 타입으로 바꾸며 필수 필드와 enum 값을 확인한다.
// 맞지 않으면 어느 경로가 틀렸는지 담아 ParseError를 던진다. 값 자체는 메시지에 넣지 않는다(원문이 로그에 남지 않게).

export class ParseError extends Error {
  constructor(path: string, expected: string) {
    super(`${path}: ${expected}이어야 합니다`);
    this.name = "ParseError";
  }
}

export function asRecord(value: unknown, path: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new ParseError(path, "객체");
  }
  return value as Record<string, unknown>;
}

export function asString(value: unknown, path: string): string {
  if (typeof value !== "string") {
    throw new ParseError(path, "문자열");
  }
  return value;
}

export function asNumber(value: unknown, path: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new ParseError(path, "숫자");
  }
  return value;
}

export function asBoolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") {
    throw new ParseError(path, "boolean");
  }
  return value;
}

/** null을 허용한다. 필드가 아예 없으면(undefined) 계약 위반으로 본다. */
export function asNullable<T>(value: unknown, path: string, parse: (value: unknown, path: string) => T): T | null {
  return value === null ? null : parse(value, path);
}

export function asEnum<T extends string>(value: unknown, values: readonly T[], path: string): T {
  if (typeof value !== "string" || !(values as readonly string[]).includes(value)) {
    throw new ParseError(path, values.join(" | "));
  }
  return value as T;
}

export function asArray<T>(value: unknown, path: string, parse: (item: unknown, path: string) => T): T[] {
  if (!Array.isArray(value)) {
    throw new ParseError(path, "배열");
  }
  return value.map((item, index) => parse(item, `${path}[${index}]`));
}

export function asStringArray(value: unknown, path: string): string[] {
  return asArray(value, path, asString);
}

/** 분류별 점수처럼 문자열 키에 숫자 값인 map. */
export function asNumberMap(value: unknown, path: string): Record<string, number> {
  const record = asRecord(value, path);
  const result: Record<string, number> = {};
  for (const [key, item] of Object.entries(record)) {
    result[key] = asNumber(item, `${path}.${key}`);
  }
  return result;
}
