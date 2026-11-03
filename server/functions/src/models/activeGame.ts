/**
 * RTDB `games_active/{gameId}` 중 Functions가 채팅 권한을 확인하려고 읽는 필드만 담는다. 대국 서버만 쓴다.
 * 필드 이름은 대국 서버의 `ActiveGame`(server/game/lib/models/active_game.dart)과 같다.
 */
export interface ActiveGamePlayers {
  cho: {uid: string};
  han: {uid: string};
}

/** 대국 단계. 대국 서버의 `GamePhase`와 값이 같다. */
export type GamePhase = "setup" | "playing" | "finished";

export interface ActiveGameAccess {
  players: ActiveGamePlayers;
  phase: GamePhase;
}
