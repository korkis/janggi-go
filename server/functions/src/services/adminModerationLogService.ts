import {ADMIN_PAGE_SIZE} from "../config";
import {ModerationLogView, Page, PageCursor} from "../models/admin";
import {getModerationLogsPage} from "../repositories/moderationLogsRepository";
import {getUsers} from "../repositories/usersRepository";
import {toModerationLogView} from "./adminViewService";

/** 최근 검사 기록 한 쪽. [uid]가 있으면 그 사람의 기록만이다. */
export async function getModerationLogs(
  uid: string | null,
  cursor: PageCursor | null,
): Promise<Page<ModerationLogView>> {
  const entries = await getModerationLogsPage(uid, cursor, ADMIN_PAGE_SIZE);
  const users = await getUsers(entries.map((entry) => entry.log.uid));
  const last = entries[entries.length - 1];
  const nextCursor =
    entries.length === ADMIN_PAGE_SIZE && last !== undefined
      ? {afterMs: last.log.createdAt.toMillis(), afterId: last.logId}
      : null;
  return {items: entries.map((entry) => toModerationLogView(entry, users)), nextCursor};
}
