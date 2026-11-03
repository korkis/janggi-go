import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp as firestoreServerTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import {ref, get, set, update, serverTimestamp} from "firebase/database";
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

describe("player_states", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `player_states/${ALICE}`), {gameId: "g1"});
    });
  });

  test("본인은 읽는다", async () => {
    await assertSucceeds(getDoc(doc(userDb(ALICE), `player_states/${ALICE}`)));
  });

  test("다른 사람과 비로그인은 읽지 못한다", async () => {
    await assertFails(getDoc(doc(userDb(BOB), `player_states/${ALICE}`)));
    await assertFails(getDoc(doc(guestDb(), `player_states/${ALICE}`)));
  });

  test("본인도 만들거나 고치거나 지우지 못한다", async () => {
    await assertFails(setDoc(doc(userDb(BOB), `player_states/${BOB}`), {gameId: "g2"}));
    await assertFails(updateDoc(doc(userDb(ALICE), `player_states/${ALICE}`), {gameId: null}));
    await assertFails(deleteDoc(doc(userDb(ALICE), `player_states/${ALICE}`)));
  });
});

describe("rooms", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "rooms/listedRoom"), {hostUid: ALICE, listed: true, status: "waiting", createdAt: 1});
      await setDoc(doc(db, "rooms/privateRoom"), {hostUid: ALICE, listed: false, status: "waiting", createdAt: 2});
    });
  });

  test("로그인한 사용자는 ID로 공개 방과 비공개 방을 읽는다", async () => {
    await assertSucceeds(getDoc(doc(userDb(BOB), "rooms/listedRoom")));
    await assertSucceeds(getDoc(doc(userDb(BOB), "rooms/privateRoom")));
  });

  test("로그인하지 않으면 읽지 못한다", async () => {
    await assertFails(getDoc(doc(guestDb(), "rooms/listedRoom")));
    await assertFails(getDocs(query(collection(guestDb(), "rooms"), where("listed", "==", true))));
  });

  test("목록은 공개된 기다리는 방 조건으로만 조회한다", async () => {
    const rooms = collection(userDb(BOB), "rooms");
    await assertSucceeds(
      getDocs(
        query(
          rooms,
          where("listed", "==", true),
          where("status", "==", "waiting"),
          orderBy("createdAt", "desc"),
          limit(50),
        ),
      ),
    );
    await assertFails(getDocs(rooms));
    await assertFails(getDocs(query(rooms, where("listed", "==", true))));
    await assertFails(getDocs(query(rooms, where("status", "==", "waiting"))));
  });

  test("누구도 쓰지 못한다", async () => {
    await assertFails(setDoc(doc(userDb(BOB), "rooms/newRoom"), {hostUid: BOB, listed: true, status: "waiting"}));
    await assertFails(updateDoc(doc(userDb(ALICE), "rooms/listedRoom"), {status: "closed"}));
    await assertFails(deleteDoc(doc(userDb(ALICE), "rooms/listedRoom")));
  });
});

describe("users/{uid}/blocks", () => {
  test("본인은 서버 시각으로 차단을 만들고 읽고 지운다", async () => {
    const db = userDb(ALICE);
    await assertSucceeds(setDoc(doc(db, `users/${ALICE}/blocks/${BOB}`), {createdAt: firestoreServerTimestamp()}));
    await assertSucceeds(getDoc(doc(db, `users/${ALICE}/blocks/${BOB}`)));
    await assertSucceeds(getDocs(collection(db, `users/${ALICE}/blocks`)));
    await assertSucceeds(deleteDoc(doc(db, `users/${ALICE}/blocks/${BOB}`)));
  });

  test("서버 시각이 아니거나 다른 필드가 있거나 나를 차단하면 막는다", async () => {
    const db = userDb(ALICE);
    await assertFails(setDoc(doc(db, `users/${ALICE}/blocks/${BOB}`), {createdAt: new Date(2026, 0, 1)}));
    await assertFails(
      setDoc(doc(db, `users/${ALICE}/blocks/${BOB}`), {createdAt: firestoreServerTimestamp(), reason: "x"}),
    );
    await assertFails(setDoc(doc(db, `users/${ALICE}/blocks/${ALICE}`), {createdAt: firestoreServerTimestamp()}));
  });

  test("고치기는 막는다", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${ALICE}/blocks/${BOB}`), {createdAt: new Date(2026, 0, 1)});
    });
    await assertFails(
      setDoc(doc(userDb(ALICE), `users/${ALICE}/blocks/${BOB}`), {createdAt: firestoreServerTimestamp()}),
    );
  });

  test("다른 사람의 차단 목록은 읽거나 쓰지 못한다", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${ALICE}/blocks/${BOB}`), {createdAt: new Date(2026, 0, 1)});
    });
    await assertFails(getDoc(doc(userDb(BOB), `users/${ALICE}/blocks/${BOB}`)));
    await assertFails(getDocs(collection(userDb(BOB), `users/${ALICE}/blocks`)));
    await assertFails(deleteDoc(doc(userDb(BOB), `users/${ALICE}/blocks/${BOB}`)));
    await assertFails(setDoc(doc(userDb(BOB), `users/${ALICE}/blocks/carol`), {createdAt: firestoreServerTimestamp()}));
  });
});

describe("challenges", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "challenges/c1"), {fromUid: ALICE, toUid: BOB, status: "pending"});
    });
  });

  test("보낸 사람과 받는 사람은 ID로 읽는다", async () => {
    await assertSucceeds(getDoc(doc(userDb(ALICE), "challenges/c1")));
    await assertSucceeds(getDoc(doc(userDb(BOB), "challenges/c1")));
  });

  test("다른 사람과 비로그인은 읽지 못하고 목록도 읽지 못한다", async () => {
    await assertFails(getDoc(doc(userDb("carol"), "challenges/c1")));
    await assertFails(getDoc(doc(guestDb(), "challenges/c1")));
    await assertFails(getDocs(query(collection(userDb(ALICE), "challenges"), where("fromUid", "==", ALICE))));
  });

  test("누구도 쓰지 못한다", async () => {
    await assertFails(updateDoc(doc(userDb(BOB), "challenges/c1"), {status: "accepted"}));
    await assertFails(setDoc(doc(userDb(ALICE), "challenges/c2"), {fromUid: ALICE, toUid: BOB}));
    await assertFails(deleteDoc(doc(userDb(ALICE), "challenges/c1")));
  });

  test("challenge_limits는 서버 전용이다", async () => {
    await assertFails(getDoc(doc(userDb(ALICE), `challenge_limits/${ALICE}_${BOB}`)));
    await assertFails(setDoc(doc(userDb(ALICE), `challenge_limits/${ALICE}_${BOB}`), {failCount: 0}));
  });
});

describe("Realtime Database online_users", () => {
  const entry = {nickname: "앨리스", rankLevel: 1, status: "waiting", challengesEnabled: true, since: 1000};

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await set(ref(context.database(), `online_users/${ALICE}`), entry);
    });
  });

  test("로그인한 사용자는 접속자 목록을 읽는다", async () => {
    await assertSucceeds(get(ref(testEnv.authenticatedContext(BOB).database(), "online_users")));
    await assertFails(get(ref(testEnv.unauthenticatedContext().database(), "online_users")));
  });

  test("본인은 신청 받기만 바꾸고 자기 항목을 지운다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertSucceeds(set(ref(db, `online_users/${ALICE}/challengesEnabled`), false));
    await assertSucceeds(set(ref(db, `online_users/${ALICE}`), null));
  });

  test("본인도 닉네임, 급수, 상태는 쓰지 못한다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertFails(set(ref(db, `online_users/${ALICE}`), {...entry, rankLevel: 27}));
    await assertFails(set(ref(db, `online_users/${ALICE}/status`), "playing"));
    await assertFails(set(ref(db, `online_users/${ALICE}/challengesEnabled`), "no"));
    await assertFails(set(ref(db, `online_users/${ALICE}/challengesEnabled`), null));
  });

  test("항목이 없으면 신청 받기도 쓰지 못한다", async () => {
    const db = testEnv.authenticatedContext(BOB).database();
    await assertFails(set(ref(db, `online_users/${BOB}/challengesEnabled`), true));
    await assertSucceeds(set(ref(db, `online_users/${BOB}`), null));
  });

  test("다른 사람의 항목은 바꾸거나 지우지 못한다", async () => {
    const db = testEnv.authenticatedContext(BOB).database();
    await assertFails(set(ref(db, `online_users/${ALICE}/challengesEnabled`), false));
    await assertFails(set(ref(db, `online_users/${ALICE}`), null));
  });
});

describe("Realtime Database", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await set(ref(context.database(), "games_active/g1"), {state: {phase: "playing"}});
    });
  });

  test("games_active의 대국은 로그인하지 않아도 ID로 읽는다", async () => {
    await assertSucceeds(get(ref(testEnv.unauthenticatedContext().database(), "games_active/g1")));
    await assertSucceeds(get(ref(testEnv.authenticatedContext(ALICE).database(), "games_active/g1/state")));
  });

  test("games_active 전체 목록은 읽지 못한다", async () => {
    await assertFails(get(ref(testEnv.authenticatedContext(ALICE).database(), "games_active")));
  });

  test("games_active는 아무도 쓰지 못한다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertFails(set(ref(db, "games_active/g1/state/phase"), "finished"));
    await assertFails(set(ref(db, "games_active/g2"), {state: {phase: "setup"}}));
  });

  test("규칙을 연 경로가 아니면 막는다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertFails(set(ref(db, "unknown_path/g1"), {fen: "x"}));
    await assertFails(get(ref(db, "unknown_path")));
  });
});

describe("Realtime Database 관전", () => {
  const VIEWER = "v".repeat(20);

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.database();
      await set(ref(db, "games_active/g1"), {state: {phase: "playing"}});
      await set(ref(db, "spectate_list/g1"), {fen: "x", moveCount: 3, spectatorCount: 1});
      await set(ref(db, `spectators/g1/${"o".repeat(20)}`), 1000);
    });
  });

  test("spectate_list는 로그인하지 않아도 목록을 읽는다", async () => {
    await assertSucceeds(get(ref(testEnv.unauthenticatedContext().database(), "spectate_list")));
    await assertSucceeds(get(ref(testEnv.authenticatedContext(ALICE).database(), "spectate_list/g1")));
  });

  test("spectate_list는 아무도 쓰지 못한다", async () => {
    await assertFails(set(ref(testEnv.unauthenticatedContext().database(), "spectate_list/g1/spectatorCount"), 99));
    await assertFails(set(ref(testEnv.authenticatedContext(ALICE).database(), "spectate_list/g2"), {fen: "x"}));
  });

  test("로그인하지 않아도 진행 중 대국에 관전자 표시를 서버 시각으로 만들고 지운다", async () => {
    for (const db of [testEnv.unauthenticatedContext().database(), testEnv.authenticatedContext(ALICE).database()]) {
      await assertSucceeds(set(ref(db, `spectators/g1/${VIEWER}`), serverTimestamp()));
      await assertSucceeds(set(ref(db, `spectators/g1/${VIEWER}`), null));
    }
  });

  test("서버 시각이 아니거나 고치거나 없는 대국이거나 ID가 20자가 아니면 막는다", async () => {
    const db = testEnv.unauthenticatedContext().database();
    await assertFails(set(ref(db, `spectators/g1/${VIEWER}`), 1234));
    await assertFails(set(ref(db, `spectators/g1/${VIEWER}`), {at: serverTimestamp()}));
    await assertFails(set(ref(db, `spectators/g1/${"o".repeat(20)}`), serverTimestamp()));
    await assertFails(set(ref(db, `spectators/g2/${VIEWER}`), serverTimestamp()));
    await assertFails(set(ref(db, "spectators/g1/short"), serverTimestamp()));
    await assertFails(set(ref(db, "spectators/g1"), {[VIEWER]: serverTimestamp()}));
  });

  test("관전자 표시는 읽지 못한다", async () => {
    await assertFails(get(ref(testEnv.unauthenticatedContext().database(), "spectators/g1")));
    await assertFails(get(ref(testEnv.authenticatedContext(ALICE).database(), `spectators/g1/${"o".repeat(20)}`)));
  });
});

describe("Realtime Database connections", () => {
  function connection(online: boolean) {
    return {online, foreground: true, activeSince: serverTimestamp(), lastSeenAt: serverTimestamp()};
  }

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await set(ref(context.database(), `connections/${ALICE}/old`), {
        online: false,
        foreground: true,
        activeSince: 1000,
        lastSeenAt: 2000,
      });
    });
  });

  test("로그인한 사용자는 다른 사람의 연결을 읽는다", async () => {
    await assertSucceeds(get(ref(testEnv.authenticatedContext(BOB).database(), `connections/${ALICE}`)));
    await assertFails(get(ref(testEnv.unauthenticatedContext().database(), `connections/${ALICE}`)));
  });

  test("connections 전체 목록은 읽지 못한다", async () => {
    await assertFails(get(ref(testEnv.authenticatedContext(ALICE).database(), "connections")));
  });

  test("본인은 지난 연결을 지우고 새 연결을 서버 시각으로 쓴다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertSucceeds(update(ref(db, `connections/${ALICE}`), {old: null, c1: connection(true)}));
    await assertSucceeds(update(ref(db, `connections/${ALICE}/c1`), {lastSeenAt: serverTimestamp()}));
    await assertSucceeds(
      update(ref(db, `connections/${ALICE}/c1`), {foreground: false, lastSeenAt: serverTimestamp()}),
    );
    // onDisconnect로 걸어 두는 쓰기
    await assertSucceeds(update(ref(db, `connections/${ALICE}/c1`), {online: false}));
  });

  test("시각은 서버 시각만 받는다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertFails(set(ref(db, `connections/${ALICE}/c1`), {...connection(true), activeSince: 1234}));
    await assertFails(update(ref(db, `connections/${ALICE}/old`), {lastSeenAt: Date.now()}));
  });

  test("필드가 빠지거나 다른 필드가 있으면 막는다", async () => {
    const db = testEnv.authenticatedContext(ALICE).database();
    await assertFails(set(ref(db, `connections/${ALICE}/c1`), {online: true, foreground: true}));
    await assertFails(set(ref(db, `connections/${ALICE}/c1`), {...connection(true), extra: 1}));
    await assertFails(set(ref(db, `connections/${ALICE}/c1`), {...connection(true), online: "yes"}));
    await assertFails(set(ref(db, `connections/${ALICE}`), "online"));
  });

  test("다른 사람의 연결은 쓰거나 지우지 못한다", async () => {
    const db = testEnv.authenticatedContext(BOB).database();
    await assertFails(set(ref(db, `connections/${ALICE}/c1`), connection(true)));
    await assertFails(set(ref(db, `connections/${ALICE}/old`), null));
    await assertFails(
      set(ref(testEnv.unauthenticatedContext().database(), `connections/${ALICE}/c1`), connection(true)),
    );
  });
});
