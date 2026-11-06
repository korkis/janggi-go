/** 공지(docs/server.md의 운영 스위치). 앱 언어가 한국어면 [messageKo], 그 밖에는 [messageEn]을 보여준다. */
export interface ServiceNotice {
  messageKo: string;
  messageEn: string;
  // 새 대국을 막는다. 진행 중인 대국은 그대로 둔다.
  gamesBlocked: boolean;
}

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
  chatEnabled: boolean;
  signupEnabled: boolean;
  webEnabled: boolean;
  coinSaleEnabled: boolean;
  minAppVersion: string;
  serviceNotice: ServiceNotice | null;
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
  chatEnabled: true,
  signupEnabled: true,
  webEnabled: true,
  coinSaleEnabled: true,
  minAppVersion: "1.0.0",
  serviceNotice: null,
};
