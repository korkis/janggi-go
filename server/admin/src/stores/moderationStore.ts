import {create} from "zustand";
import type {
  ModerationLogView,
  PageCursor,
  ReportStatus,
  ReportSummaryView,
  ReportWithTargetView,
  ResolveReportInput,
  SanctionInput,
  UserHistoryView,
} from "../models/admin";
import * as adminApi from "../services/adminApi";
import type {AdminApiError} from "../services/adminApi";

// 신고, 검사 기록, 사용자 기록과 조치 상태. 모두 서버 응답 그대로이고 메모리에만 둔다(persist 하지 않는다).
// 지금 보고 있는 신고와 사용자는 URL이 정하고, 여기에는 ID별로 읽어 둔 결과만 둔다.

/** 한 번 읽는 자료의 상태. */
export type Resource<T> = {status: "loading"} | {status: "loaded"; data: T} | {status: "error"; error: AdminApiError};

/** 한 쪽씩 읽는 목록의 상태. idle이면 화면이 열릴 때 처음부터 다시 읽는다. */
export interface ListState<T> {
  status: "idle" | "loading" | "loaded" | "error";
  items: T[];
  nextCursor: PageCursor | null;
  // 다음 쪽을 읽는 중이다.
  loadingMore: boolean;
  error: AdminApiError | null;
}

function emptyList<T>(): ListState<T> {
  return {status: "idle", items: [], nextCursor: null, loadingMore: false, error: null};
}

/** 검사 기록 목록의 키. 모든 사람이면 빈 문자열이다. */
function getLogsKey(uid: string | null): string {
  return uid ?? "";
}

interface ModerationState {
  reports: Record<ReportStatus, ListState<ReportSummaryView>>;
  reportDetails: Record<string, Resource<ReportWithTargetView>>;
  users: Record<string, Resource<UserHistoryView>>;
  moderationLogs: Record<string, ListState<ModerationLogView>>;
  // 조치(신고 처리, 제재)를 보내는 중이다. 응답을 받기 전에 다시 보내지 못하게 한다.
  submitting: boolean;

  /** 신고 목록을 읽는다. [more]면 다음 쪽을 이어 읽고, 아니면 처음부터 다시 읽는다. */
  loadReports: (status: ReportStatus, more: boolean) => Promise<void>;
  loadReport: (reportId: string) => Promise<void>;
  loadUser: (uid: string) => Promise<void>;
  loadModerationLogs: (uid: string | null, more: boolean) => Promise<void>;
  /** 신고를 처리한다. 성공하면 서버 응답으로 상세를 바꾸고 신고 목록을 다시 읽게 한다. 실패하면 던진다. */
  resolveReport: (reportId: string, input: ResolveReportInput) => Promise<void>;
  /** 신고 없이 제재를 건다. 성공하면 서버 응답으로 사용자 기록을 바꾼다. 실패하면 던진다. */
  sanctionUser: (uid: string, input: SanctionInput) => Promise<void>;
  /** 로그아웃하면 읽어 둔 신고와 채팅 내용을 메모리에서 지운다. */
  reset: () => void;
}

function getInitialState() {
  return {
    reports: {pending: emptyList<ReportSummaryView>(), resolved: emptyList<ReportSummaryView>()},
    reportDetails: {},
    users: {},
    moderationLogs: {},
    submitting: false,
  };
}

export const useModerationStore = create<ModerationState>()((set, get) => {
  function setReportList(status: ReportStatus, list: Partial<ListState<ReportSummaryView>>): void {
    set((state) => ({reports: {...state.reports, [status]: {...state.reports[status], ...list}}}));
  }

  function setLogList(key: string, list: Partial<ListState<ModerationLogView>>): void {
    set((state) => ({
      moderationLogs: {...state.moderationLogs, [key]: {...(state.moderationLogs[key] ?? emptyList()), ...list}},
    }));
  }

  return {
    ...getInitialState(),

    loadReports: async (status, more) => {
      const current = get().reports[status];
      const cursor = more ? current.nextCursor : null;
      if (more && (cursor === null || current.loadingMore)) {
        return;
      }
      setReportList(status, more ? {loadingMore: true} : {status: "loading", error: null});
      try {
        const page = await adminApi.getReports(status, cursor);
        const items = more ? [...get().reports[status].items, ...page.items] : page.items;
        setReportList(status, {status: "loaded", items, nextCursor: page.nextCursor, error: null});
      } catch (error) {
        setReportList(
          status,
          more ? {error: error as AdminApiError} : {status: "error", error: error as AdminApiError},
        );
      } finally {
        setReportList(status, {loadingMore: false});
      }
    },

    loadReport: async (reportId) => {
      set((state) => ({reportDetails: {...state.reportDetails, [reportId]: {status: "loading"}}}));
      try {
        const data = await adminApi.getReport(reportId);
        set((state) => ({
          reportDetails: {...state.reportDetails, [reportId]: {status: "loaded", data}},
          users: {...state.users, [data.target.uid]: {status: "loaded", data: data.target}},
        }));
      } catch (error) {
        set((state) => ({
          reportDetails: {...state.reportDetails, [reportId]: {status: "error", error: error as AdminApiError}},
        }));
      }
    },

    loadUser: async (uid) => {
      set((state) => ({users: {...state.users, [uid]: {status: "loading"}}}));
      try {
        const data = await adminApi.getUser(uid);
        set((state) => ({users: {...state.users, [uid]: {status: "loaded", data}}}));
      } catch (error) {
        set((state) => ({users: {...state.users, [uid]: {status: "error", error: error as AdminApiError}}}));
      }
    },

    loadModerationLogs: async (uid, more) => {
      const key = getLogsKey(uid);
      const current = get().moderationLogs[key] ?? emptyList<ModerationLogView>();
      const cursor = more ? current.nextCursor : null;
      if (more && (cursor === null || current.loadingMore)) {
        return;
      }
      setLogList(key, more ? {loadingMore: true} : {status: "loading", error: null});
      try {
        const page = await adminApi.getModerationLogs(uid, cursor);
        const items = more ? [...(get().moderationLogs[key]?.items ?? []), ...page.items] : page.items;
        setLogList(key, {status: "loaded", items, nextCursor: page.nextCursor, error: null});
      } catch (error) {
        setLogList(key, more ? {error: error as AdminApiError} : {status: "error", error: error as AdminApiError});
      } finally {
        setLogList(key, {loadingMore: false});
      }
    },

    resolveReport: async (reportId, input) => {
      if (get().submitting) {
        return;
      }
      try {
        set({submitting: true});
        const data = await adminApi.resolveReport(reportId, input);
        // 같은 메시지의 다른 신고도 함께 닫혔을 수 있으므로 두 목록 모두 다시 읽게 한다.
        set((state) => ({
          reportDetails: {...state.reportDetails, [reportId]: {status: "loaded", data}},
          users: {...state.users, [data.target.uid]: {status: "loaded", data: data.target}},
          reports: {pending: emptyList(), resolved: emptyList()},
        }));
      } finally {
        set({submitting: false});
      }
    },

    sanctionUser: async (uid, input) => {
      if (get().submitting) {
        return;
      }
      try {
        set({submitting: true});
        const data = await adminApi.sanctionUser(uid, input);
        set((state) => ({users: {...state.users, [uid]: {status: "loaded", data}}}));
      } finally {
        set({submitting: false});
      }
    },

    reset: () => set(getInitialState()),
  };
});
