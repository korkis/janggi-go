import {create} from "zustand";
import type {AppConfig} from "../models/admin";
import * as adminApi from "../services/adminApi";
import type {AdminApiError} from "../services/adminApi";
import type {Resource} from "./moderationStore";

// Firestore `configs/app`의 서버 값과 저장 상태.

interface ConfigState {
  config: Resource<AppConfig> | null;
  // 저장 요청 중이다. 응답을 받기 전에 다시 보내지 못하게 한다.
  saving: boolean;
  load: () => Promise<void>;
  /** 저장한다. 성공하면 서버가 돌려준 값으로 바꾼다. 실패하면 던진다. */
  save: (config: AppConfig) => Promise<void>;
  reset: () => void;
}

export const useConfigStore = create<ConfigState>()((set, get) => ({
  config: null,
  saving: false,
  load: async () => {
    set({config: {status: "loading"}});
    try {
      set({config: {status: "loaded", data: await adminApi.getAppConfig()}});
    } catch (error) {
      set({config: {status: "error", error: error as AdminApiError}});
    }
  },
  save: async (config) => {
    if (get().saving) {
      return;
    }
    try {
      set({saving: true});
      set({config: {status: "loaded", data: await adminApi.updateAppConfig(config)}});
    } finally {
      set({saving: false});
    }
  },
  reset: () => set({config: null, saving: false}),
}));
