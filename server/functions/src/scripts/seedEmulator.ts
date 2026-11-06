import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {INITIAL_APP_CONFIG} from "../models/appConfig";
import {fillMissingAppConfig} from "../repositories/configsRepository";
import {createProfile} from "../services/profileService";

// 에뮬레이터 전용 프로젝트. demo-로 시작해야 운영에 닿지 않는다.
const EMULATOR_PROJECT_ID = "demo-janggi-go";
// 테스트 계정은 모두 같은 비밀번호를 쓴다. 에뮬레이터에만 만든다.
const TEST_PASSWORD = "janggigo1";

interface TestAccount {
  uid: string;
  email: string;
  nickname: string;
  admin: boolean;
}

// 두 계정으로 대국·신청·채팅을, 나머지로 관전·방 초대를 해 본다. 첫 계정은 Admin 웹에도 들어간다.
const TEST_ACCOUNTS: TestAccount[] = [
  {uid: "test-1", email: "test1@janggigo.test", nickname: "장기왕", admin: true},
  {uid: "test-2", email: "test2@janggigo.test", nickname: "고수할배", admin: false},
  {uid: "test-3", email: "test3@janggigo.test", nickname: "묵향", admin: false},
  {uid: "test-4", email: "test4@janggigo.test", nickname: "한량", admin: false},
];

/** 에뮬레이터 주소를 정하지 않았으면 firebase.json의 기본 포트를 쓴다. 운영 프로젝트로는 돌지 않게 막는다. */
function useEmulator(): void {
  process.env.GCLOUD_PROJECT ??= EMULATOR_PROJECT_ID;
  process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
  if (!process.env.GCLOUD_PROJECT.startsWith("demo-")) {
    throw new Error(`에뮬레이터 전용 스크립트입니다. GCLOUD_PROJECT가 demo-로 시작해야 합니다: ${process.env.GCLOUD_PROJECT}`);
  }
}

/** 계정이 없으면 만들고 프로필(닉네임)까지 정한다. 이미 있으면 그대로 둔다. */
async function seedAccount(account: TestAccount): Promise<void> {
  const auth = getAuth();
  try {
    await auth.createUser({uid: account.uid, email: account.email, password: TEST_PASSWORD, emailVerified: true});
  } catch (error) {
    if ((error as {code?: unknown}).code !== "auth/uid-already-exists") {
      throw error;
    }
  }
  if (account.admin) {
    await auth.setCustomUserClaims(account.uid, {admin: true});
  }
  await createProfile(account.uid, account.nickname);
}

/**
 * 에뮬레이터를 처음 띄운 뒤 한 번 실행한다. `configs/app`과 테스트 계정 네 개(닉네임까지 정한 상태)를 만든다.
 * 여러 번 실행해도 이미 있는 것은 바꾸지 않는다. 쓰는 법: 에뮬레이터를 띄운 채 `npm run seed`.
 */
async function main(): Promise<void> {
  useEmulator();
  initializeApp({projectId: process.env.GCLOUD_PROJECT});
  const filled = await fillMissingAppConfig(INITIAL_APP_CONFIG);
  console.log(filled.length > 0 ? "configs/app 채움" : "configs/app 이미 있음");
  for (const account of TEST_ACCOUNTS) {
    await seedAccount(account);
    console.log(`${account.email} / ${account.nickname}${account.admin ? " (관리자)" : ""}`);
  }
  console.log(`비밀번호는 모두 ${TEST_PASSWORD}`);
}

main().catch((error: unknown) => {
  console.error("seedEmulator 실패", error);
  process.exitCode = 1;
});
