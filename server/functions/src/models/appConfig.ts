/**
 * Firestore `configs/app`. 앱, Functions, 대국 서버가 같이 읽는 운영 설정이다.
 * 필드는 앱의 `AppConfig`(app/lib/models/app_config.dart)와 일치시킨다. 필드 설명은 docs/server.md의 "configs/app".
 */
export interface AppConfig {
  disconnectLimitSeconds: number;
  quickRematchLimit: number;
  onlineUsersVisible: boolean;
  autoSanctionEnabled: boolean;
  heartbeatSeconds: number;
  entryFeeEnabled: boolean;
  coinSignupBonus: number;
  coinEntryFee: number;
  coinWinReward: number;
  coinLossReward: number;
  coinAttendanceReward: number;
  coinAttendanceStreakReward: number;
  coinNicknameChangeCost: number;
  timeExtensionEnabled: boolean;
  gamePracticeEnabled: boolean;
  coinTimeExtensionCost: number;
  coinGamePracticeCost: number;
}

/** configs/app의 처음 값(docs/server.md의 "configs/app"). */
export const INITIAL_APP_CONFIG: AppConfig = {
  disconnectLimitSeconds: 30,
  quickRematchLimit: 5,
  onlineUsersVisible: false,
  autoSanctionEnabled: false,
  heartbeatSeconds: 5,
  entryFeeEnabled: true,
  coinSignupBonus: 300,
  coinEntryFee: 10,
  coinWinReward: 12,
  coinLossReward: 0,
  coinAttendanceReward: 30,
  coinAttendanceStreakReward: 100,
  coinNicknameChangeCost: 300,
  timeExtensionEnabled: true,
  gamePracticeEnabled: true,
  coinTimeExtensionCost: 30,
  coinGamePracticeCost: 30,
};
