import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc, updateDoc, deleteDoc} from "firebase/firestore";
import {ref, get, set} from "firebase/database";
import {readFileSync} from "fs";
import {resolve} from "path";
import {TEST_PROJECT_ID} from "./testEnv";

const ALICE = "alice";
const BOB = "bob";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: TEST_PROJECT_ID,
    firestore: {rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8")},
    database: {rules: readFileSync(resolve(__dirname, "../../database.rules.json"), "utf8")},
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "configs/app"), {onlineUsersVisible: false});
    await setDoc(doc(db, `users/${ALICE}`), {nickname: "앨리스", rankLevel: 1});
    await setDoc(doc(db, `users_private/${ALICE}`), {challengesEnabled: true, rankProgress: 0});
    await setDoc(doc(db, "nicknames/앨리스"), {uid: ALICE});
    await setDoc(doc(db, `ratings/${ALICE}`), {rating: 1000});
  });
});

function guestDb() {
  return testEnv.unauthenticatedContext().firestore();
}

function userDb(uid: string) {
  return testEnv.authenticatedContext(uid).firestore();
}

describe("configs/app", () => {
  test("로그인하지 않아도 읽는다", async () => {
    await assertSucceeds(getDoc(doc(guestDb(), "configs/app")));
  });

  test("누구도 쓰지 못한다", async () => {
    await assertFails(setDoc(doc(guestDb(), "configs/app"), {onlineUsersVisible: true}));
    await assertFails(updateDoc(doc(userDb(ALICE), "configs/app"), {onlineUsersVisible: true}));
  });

  test("configs의 다른 문서는 읽지 못한다", async () => {
    await assertFails(getDoc(doc(guestDb(), "configs/other")));
  });
});

describe("users", () => {
  test("로그인한 사용자는 다른 사람의 프로필을 읽는다", async () => {
    await assertSucceeds(getDoc(doc(userDb(BOB), `users/${ALICE}`)));
  });

  test("로그인하지 않으면 읽지 못한다", async () => {
    await assertFails(getDoc(doc(guestDb(), `users/${ALICE}`)));
  });

  test("본인도 만들거나 고치거나 지우지 못한다", async () => {
    await assertFails(setDoc(doc(userDb(BOB), `users/${BOB}`), {nickname: "밥", rankLevel: 27}));
    await assertFails(updateDoc(doc(userDb(ALICE), `users/${ALICE}`), {rankLevel: 27}));
    await assertFails(deleteDoc(doc(userDb(ALICE), `users/${ALICE}`)));
  });
});

describe("users_private", () => {
  test("본인은 읽는다", async () => {
    await assertSucceeds(getDoc(doc(userDb(ALICE), `users_private/${ALICE}`)));
  });

  test("다른 사람과 비로그인은 읽지 못한다", async () => {
    await assertFails(getDoc(doc(userDb(BOB), `users_private/${ALICE}`)));
    await assertFails(getDoc(doc(guestDb(), `users_private/${ALICE}`)));
  });

  test("본인은 challengesEnabled를 바꾼다", async () => {
    await assertSucceeds(updateDoc(doc(userDb(ALICE), `users_private/${ALICE}`), {challengesEnabled: false}));
  });

  test("challengesEnabled에 boolean이 아닌 값은 쓰지 못한다", async () => {
    await assertFails(updateDoc(doc(userDb(ALICE), `users_private/${ALICE}`), {challengesEnabled: "no"}));
  });

  test("본인도 다른 필드는 바꾸지 못한다", async () => {
    await assertFails(updateDoc(doc(userDb(ALICE), `users_private/${ALICE}`), {rankProgress: 0.9}));
    await assertFails(
      updateDoc(doc(userDb(ALICE), `users_private/${ALICE}`), {challengesEnabled: false, sanction: null}),
    );
  });

  test("다른 사람은 바꾸지 못하고, 본인도 만들거나 지우지 못한다", async () => {
    await assertFails(updateDoc(doc(userDb(BOB), `users_private/${ALICE}`), {challengesEnabled: false}));
    await assertFails(setDoc(doc(userDb(BOB), `users_private/${BOB}`), {challengesEnabled: true}));
    await assertFails(deleteDoc(doc(userDb(ALICE), `users_private/${ALICE}`)));
  });
});

describe("서버 전용 컬렉션", () => {
  test("nicknames는 읽지도 쓰지도 못한다", async () => {
    await assertFails(getDoc(doc(userDb(ALICE), "nicknames/앨리스")));
    await assertFails(setDoc(doc(userDb(BOB), "nicknames/밥"), {uid: BOB}));
  });

  test("규칙에 없는 컬렉션은 막는다", async () => {
    await assertFails(getDoc(doc(userDb(ALICE), `ratings/${ALICE}`)));
    await assertFails(setDoc(doc(userDb(ALICE), "games_archived/g1"), {mode: "quick"}));
  });
});

describe("Realtime Database", () => {
  test("규칙을 연 경로가 아직 없어 모두 막는다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertFails(get(ref(db, "games_active")));
    await assertFails(set(ref(db, `connections/${ALICE}/c1`), {online: true}));
  });
});
