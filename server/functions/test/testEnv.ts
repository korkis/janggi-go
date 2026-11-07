// `npm test`가 `firebase emulators:exec --project demo-janggi-go`로 띄운 에뮬레이터의 프로젝트.
// demo- 프로젝트는 운영 자원에 닿지 않는다.
export const TEST_PROJECT_ID = process.env.GCLOUD_PROJECT ?? "demo-janggi-go";

if (!TEST_PROJECT_ID.startsWith("demo-") || process.env.FIRESTORE_EMULATOR_HOST === undefined) {
  throw new Error("테스트는 demo- 프로젝트의 에뮬레이터에서만 실행한다. `npm test`로 실행한다");
}

// 에뮬레이터는 같은 문서를 여러 트랜잭션이 잡으면 잠금을 2초씩 기다린 뒤 실패시키므로 동시 호출 하나가 10초 넘게 걸릴 수 있다.
// jest 기본값 5초로는 시간이 지나 실패하고, 끝나지 않은 호출이 다음 테스트의 문서를 바꿔 그 테스트까지 실패시킨다.
jest.setTimeout(60000);

// 앱이 실패를 보고 다시 누르는 횟수를 흉내 낸 상한.
const MAX_CALLS_ON_CLOSED_TRANSACTION = 5;

/**
 * [call]이 에뮬레이터의 닫힌 트랜잭션 오류로 실패하면 다시 부른다.
 *
 * 트랜잭션의 읽기가 잠금을 기다리다 시간이 지나면 에뮬레이터는 트랜잭션을 닫고 ABORTED로 답한다. 그런데 gax(retry-request)가 같은
 * 트랜잭션으로 읽기를 두 번 더 보내(2~3초, 4~5초 뒤) 마지막 오류가 INVALID_ARGUMENT `Transaction is invalid or closed`가 된다.
 * SDK는 INVALID_ARGUMENT 중 운영의 `transaction has expired`만 다시 실행하므로 호출이 실패한다. 아무것도 쓰이지 않았으니 앱처럼 다시 부른다.
 */
async function retryOnClosedTransaction<T>(call: () => T): Promise<Awaited<T>> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await call();
    } catch (error) {
      const closed = error instanceof Error && error.message.includes("Transaction is invalid or closed");
      if (!closed || attempt === MAX_CALLS_ON_CLOSED_TRANSACTION) {
        throw error;
      }
    }
  }
}

/**
 * [calls]를 한꺼번에 부르고 결과를 돌려준다. 실패가 있어도 모두 끝난 뒤에 던져, 남은 호출이 다음 테스트의 문서를 바꾸지 않게 한다.
 * 에뮬레이터의 닫힌 트랜잭션 오류는 다시 부른다(retryOnClosedTransaction). 다른 오류는 그대로 던진다.
 */
export async function callConcurrently<T>(calls: (() => T)[]): Promise<Awaited<T>[]> {
  const results = await Promise.allSettled(calls.map((call) => retryOnClosedTransaction(call)));
  return results.map((result) => {
    if (result.status === "rejected") {
      throw result.reason;
    }
    return result.value;
  });
}
