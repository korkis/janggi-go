import {getRtdb} from "./rtdb";

/** RTDB `connections/{uid}`를 지운다. 접속 상태는 앱이 쓴다. Functions는 회원 탈퇴 때만 닿는다. */
export async function deleteConnections(uid: string): Promise<void> {
  await getRtdb().ref(`connections/${uid}`).remove();
}
