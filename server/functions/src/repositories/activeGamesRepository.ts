import {ActiveGameAccess, ActiveGamePlayers, GamePhase} from "../models/activeGame";
import {getRtdb} from "./rtdb";

const PATH = "games_active";

/** 채팅 권한 확인에 쓰는 대국자와 단계. 대국이 없으면(끝나고 지워졌으면) null. Functions는 대국 상태를 읽기만 한다. */
export async function getActiveGameAccess(gameId: string): Promise<ActiveGameAccess | null> {
  const gameRef = getRtdb().ref(`${PATH}/${gameId}`);
  const [players, phase] = await Promise.all([gameRef.child("meta/players").get(), gameRef.child("state/phase").get()]);
  if (!players.exists() || !phase.exists()) {
    return null;
  }
  return {players: players.val() as ActiveGamePlayers, phase: phase.val() as GamePhase};
}
