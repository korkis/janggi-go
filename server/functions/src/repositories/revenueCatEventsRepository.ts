import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {RevenueCatEventRecord, RevenueCatEventResult} from "../models/store";

const COLLECTION = "revenuecat_events";

function eventRef(eventId: string) {
  return getFirestore().collection(COLLECTION).doc(encodeURIComponent(eventId));
}

/** 받은 웹훅을 기록한다. RevenueCat이 다시 보내면 같은 문서에 받은 횟수를 늘리고 결과를 비운다. */
export async function recordRevenueCatEvent(eventId: string, record: RevenueCatEventRecord): Promise<void> {
  await eventRef(eventId).set({...record, deliveryCount: FieldValue.increment(1), result: null}, {merge: true});
}

export async function setRevenueCatEventResult(
  eventId: string,
  result: RevenueCatEventResult,
  processedAt: Timestamp,
): Promise<void> {
  await eventRef(eventId).update({result, processedAt});
}
