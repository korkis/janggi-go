import {applicationDefault} from "firebase-admin/app";
import {Database, getDatabaseWithUrl} from "firebase-admin/database";
import {DATABASE_URL} from "../config";

/** Realtime Database. 에뮬레이터에서는 Admin SDK가 FIREBASE_DATABASE_EMULATOR_HOST로 보낸다. */
export function getRtdb(): Database {
  return getDatabaseWithUrl(DATABASE_URL);
}

/**
 * [path] 바로 아래 자식의 키만 읽는다(REST `shallow`). Admin SDK에는 shallow 읽기가 없어 자식 전체를 받지 않으려고 REST로 부른다.
 * 에뮬레이터에서는 관리자 토큰(`owner`)을 쓴다.
 */
export async function getShallowKeys(path: string): Promise<string[]> {
  const emulatorHost = process.env.FIREBASE_DATABASE_EMULATOR_HOST;
  let url: URL;
  let token: string;
  if (emulatorHost !== undefined) {
    url = new URL(`http://${emulatorHost}/${path}.json`);
    url.searchParams.set("ns", new URL(DATABASE_URL).hostname.split(".")[0]);
    token = "owner";
  } else {
    url = new URL(`${DATABASE_URL}/${path}.json`);
    token = (await applicationDefault().getAccessToken()).access_token;
  }
  url.searchParams.set("shallow", "true");
  const response = await fetch(url, {headers: {Authorization: `Bearer ${token}`}});
  if (!response.ok) {
    throw new Error(`RTDB shallow 읽기 실패: ${path} ${response.status}`);
  }
  const value = (await response.json()) as Record<string, unknown> | null;
  return value === null ? [] : Object.keys(value);
}
