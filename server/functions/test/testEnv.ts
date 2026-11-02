// `npm test`가 `firebase emulators:exec --project demo-janggi-go`로 띄운 에뮬레이터의 프로젝트.
// demo- 프로젝트는 운영 자원에 닿지 않는다.
export const TEST_PROJECT_ID = process.env.GCLOUD_PROJECT ?? "demo-janggi-go";

if (!TEST_PROJECT_ID.startsWith("demo-") || process.env.FIRESTORE_EMULATOR_HOST === undefined) {
  throw new Error("테스트는 demo- 프로젝트의 에뮬레이터에서만 실행한다. `npm test`로 실행한다");
}
