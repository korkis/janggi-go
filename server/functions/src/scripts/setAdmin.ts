import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";

/**
 * 이메일로 찾은 계정에 Admin 웹 권한(`admin: true` custom claim)을 주거나 뺀다(docs/server.md의 관리자 지정).
 * 쓰는 법: `npm run set-admin -- <이메일>`, 빼려면 `npm run set-admin -- <이메일> --remove`.
 * 에뮬레이터: FIREBASE_AUTH_EMULATOR_HOST와 GCLOUD_PROJECT를 정하고 실행한다. 운영: 사용자가 직접 실행한다.
 * 다른 claim은 그대로 둔다. 바꾼 claim은 그 사람이 다시 로그인하거나 ID token이 새로 발급된 뒤(1시간 안) 적용된다.
 */
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const email = args.find((arg) => !arg.startsWith("--"));
  const remove = args.includes("--remove");
  if (email === undefined) {
    throw new Error("이메일을 주어야 합니다: npm run set-admin -- <이메일> [--remove]");
  }
  initializeApp();
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  const claims: Record<string, unknown> = {...(user.customClaims ?? {})};
  if (remove) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }
  await auth.setCustomUserClaims(user.uid, claims);
  console.log(remove ? "admin claim 제거 완료" : "admin claim 설정 완료", {uid: user.uid});
}

main().catch((error: unknown) => {
  console.error("setAdmin 실패", error);
  process.exitCode = 1;
});
