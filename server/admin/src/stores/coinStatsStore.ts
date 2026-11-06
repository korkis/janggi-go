import {create} from "zustand";
import type {CoinStatsView} from "../models/admin";
import * as adminApi from "../services/adminApi";
import type {AdminApiError} from "../services/adminApi";
import type {Resource} from "./moderationStore";

// 엽전 지표의 서버 값.

interface CoinStatsState {
  stats: Resource<CoinStatsView> | null;
  load: () => Promise<void>;
  reset: () => void;
}

export const useCoinStatsStore = create<CoinStatsState>()((set) => ({
  stats: null,
  load: async () => {
    set({stats: {status: "loading"}});
    try {
      set({stats: {status: "loaded", data: await adminApi.getCoinStats()}});
    } catch (error) {
      set({stats: {status: "error", error: error as AdminApiError}});
    }
  },
  reset: () => set({stats: null}),
}));
