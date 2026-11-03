import {Timestamp} from "firebase-admin/firestore";
import {ChatChannel} from "./chat";
import {SanctionType} from "./userPrivate";

export const ReportStatus = {
  pending: "pending",
  resolved: "resolved",
} as const;
export type ReportStatus = (typeof ReportStatus)[keyof typeof ReportStatus];

/** 신고에 저장하는 메시지 사본. */
export interface ReportedMessage {
  messageId: string;
  uid: string;
  nickname: string;
  text: string;
  sentAt: number;
}

/** 신고 처리 결과. Admin 웹(구현 순서 13번)이 쓴다. */
export interface ReportResolution {
  action: "dismissed" | SanctionType;
  reason: string;
  adminUid: string;
  sanctionId: string | null;
}

/** Firestore `reports/{reportId}`. 채팅 메시지 신고다(서버 전용). Admin 웹은 Callable로만 읽고 바꾼다. */
export interface Report {
  reporterUid: string;
  // 신고된 메시지를 보낸 사람.
  targetUid: string;
  channel: ChatChannel;
  gameId: string | null;
  message: ReportedMessage;
  // 앞뒤 메시지 사본. 보낸 순서대로다.
  context: ReportedMessage[];
  // 신고된 메시지의 검사 결과 사본. 검사 결과가 지워졌으면 null.
  check: {scores: Record<string, number>; bannedWordMatched: boolean} | null;
  status: ReportStatus;
  resolution: ReportResolution | null;
  createdAt: Timestamp;
  resolvedAt: Timestamp | null;
  // 처리가 끝나면 1년 뒤로 정한다. TTL 정책으로 지운다.
  expiresAt: Timestamp | null;
}
