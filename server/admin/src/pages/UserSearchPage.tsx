import {type FormEvent, useState} from "react";
import {useNavigate} from "react-router";
import {getErrorText} from "../components/States";
import {AdminApiError, findUserByNickname} from "../services/adminApi";

/** 사용자 찾기. 닉네임(영문 대소문자 무시)이나 uid로 찾아 사용자 화면으로 옮긴다. */
export function UserSearchPage() {
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [mode, setMode] = useState<"nickname" | "uid">("nickname");
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function search(event: FormEvent): Promise<void> {
    event.preventDefault();
    const value = query.trim();
    if (value.length === 0 || searching) {
      return;
    }
    if (mode === "uid") {
      await navigate(`/users/${encodeURIComponent(value)}`);
      return;
    }
    try {
      setSearching(true);
      setError(null);
      const user = await findUserByNickname(value);
      await navigate(`/users/${encodeURIComponent(user.uid)}`);
    } catch (searchError) {
      setError(searchError instanceof AdminApiError ? getErrorText(searchError) : "찾지 못했어요.");
    } finally {
      setSearching(false);
    }
  }

  return (
    <div className="max-w-lg">
      <h1 className="text-xl font-bold">사용자</h1>
      <form onSubmit={(event) => void search(event)} className="mt-4 flex gap-2">
        <select
          value={mode}
          onChange={(event) => setMode(event.target.value === "uid" ? "uid" : "nickname")}
          className="rounded-md border border-slate-300 px-2 text-sm"
          aria-label="찾는 방법"
        >
          <option value="nickname">닉네임</option>
          <option value="uid">uid</option>
        </select>
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={mode === "nickname" ? "지금 닉네임" : "Firebase Auth uid"}
          className="flex-1 rounded-md border border-slate-300 px-3 py-2 text-sm"
        />
        <button
          type="submit"
          disabled={searching || query.trim().length === 0}
          className="rounded-md bg-slate-900 px-4 py-2 text-sm font-semibold text-white disabled:opacity-40"
        >
          {searching ? "찾는 중…" : "찾기"}
        </button>
      </form>
      {error !== null && (
        <p role="alert" className="mt-2 text-sm text-red-700">
          ⚠ {error}
        </p>
      )}
      <p className="mt-2 text-xs text-slate-500">
        닉네임은 지금 닉네임으로만 찾아요. 예전 닉네임은 사용자 화면의 변경 기록에 있어요.
      </p>
    </div>
  );
}
