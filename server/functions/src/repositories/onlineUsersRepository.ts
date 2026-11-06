import {getRtdb} from "./rtdb";

/** RTDB `online_users/{uid}`를 지운다. 접속자 목록은 대국 서버가 쓴다. Functions는 회원 탈퇴 때만 닿는다. */
export async function deleteOnlineUser(uid: string): Promise<void> {
  await getRtdb().ref(`online_users/${uid}`).remove();
}
