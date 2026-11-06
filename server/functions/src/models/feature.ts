/** 운영 스위치로 멈춘 기능을 부른 이유. 오류의 `details.code`로 앱에 보낸다. 대국 서버와 채팅의 같은 이름 코드와 값이 같다. */
export const FeatureErrorCode = {
  featureDisabled: "featureDisabled",
} as const;
export type FeatureErrorCode = (typeof FeatureErrorCode)[keyof typeof FeatureErrorCode];
