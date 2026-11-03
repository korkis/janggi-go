import {create} from "zustand";

// 서버 원본이 아닌 화면 상태. 조치를 마친 뒤 다른 화면으로 옮겨도 보이는 알림이다.

export interface Notice {
  kind: "success" | "error";
  text: string;
}

interface UiState {
  notice: Notice | null;
  showNotice: (notice: Notice) => void;
  clearNotice: () => void;
}

export const useUiStore = create<UiState>()((set) => ({
  notice: null,
  showNotice: (notice) => set({notice}),
  clearNotice: () => set({notice: null}),
}));
