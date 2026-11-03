import {getFirestore} from "firebase-admin/firestore";
import {Report} from "../models/report";
import {modelConverter} from "./firestore";

const COLLECTION = "reports";

/** 같은 사람이 같은 메시지를 여러 번 신고해도 신고 하나로 남기도록 메시지와 신고한 사람으로 ID를 정한다. */
export function getReportId(messageId: string, reporterUid: string): string {
  return `${messageId}_${reporterUid}`;
}

/** 신고를 만든다. 이미 있으면 그대로 두고 false를 돌려준다. */
export async function createReportIfAbsent(reportId: string, report: Report): Promise<boolean> {
  try {
    await getFirestore().collection(COLLECTION).doc(reportId).withConverter(modelConverter<Report>()).create(report);
    return true;
  } catch (error) {
    // 이미 있으면 ALREADY_EXISTS(6)로 실패한다.
    if ((error as {code?: unknown}).code === 6) {
      return false;
    }
    throw error;
  }
}
