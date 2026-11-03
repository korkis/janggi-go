import {BANNED_WORDS, BANNED_WORD_EXCEPTIONS} from "../config";

// 금칙어를 찾기 전에 지우는 글자. 한글(완성형, 자모), 영문, 공백이 아닌 것이다. "시1발", "씨.발"처럼 끼워 넣은 숫자와 기호를 지운다.
const IGNORED_CHARACTERS = /[^가-힣ㄱ-ㅎㅏ-ㅣa-z\s]/g;

/**
 * 금칙어를 찾을 글로 바꾼다. 영문은 소문자로 바꾸고, 숫자와 기호를 지우고, 평범한 낱말의 예외를 지운 뒤, 한 글자씩 띄어 쓴
 * 낱말("씨 발", "ㅅ ㅂ")은 붙인다. 두 글자 이상인 낱말끼리는 붙이지 않는다. "아저씨 발"처럼 낱말 경계에서 금칙어가 생기지 않게
 * 하기 위해서다.
 */
function normalize(text: string): string {
  let cleaned = text.toLowerCase().replace(IGNORED_CHARACTERS, "");
  for (const exception of BANNED_WORD_EXCEPTIONS) {
    cleaned = cleaned.split(exception).join(" ");
  }
  const words = cleaned.split(/\s+/).filter((word) => word.length > 0);
  const merged: string[] = [];
  // 바로 앞 낱말이 한 글자였는지. 한 글자 낱말이 이어지면 앞 낱말에 붙인다.
  let previousSingle = false;
  for (const word of words) {
    const single = [...word].length === 1;
    if (single && previousSingle) {
      merged[merged.length - 1] += word;
    } else {
      merged.push(word);
    }
    previousSingle = single;
  }
  return merged.join(" ");
}

/** [text]에 자체 금칙어가 들어 있는지. 닉네임과 채팅이 같이 쓴다. */
export function hasBannedWord(text: string): boolean {
  const normalized = normalize(text);
  return BANNED_WORDS.some((word) => normalized.includes(word));
}
