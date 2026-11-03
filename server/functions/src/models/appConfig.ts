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
}

/** configs/app의 처음 값(docs/server.md의 "configs/app"). */
export const INITIAL_APP_CONFIG: AppConfig = {
  disconnectLimitSeconds: 30,
  quickRematchLimit: 5,
  onlineUsersVisible: false,
  autoSanctionEnabled: false,
  heartbeatSeconds: 5,
};
