import {getSortedScores} from "../utils/format";

/** 분류별 OpenAI Moderation 점수. 높은 것부터 막대와 숫자로 보여준다. [flagged]는 걸린 분류다. */
export function ScoreList({scores, flagged = []}: {scores: Record<string, number>; flagged?: string[]}) {
  const sorted = getSortedScores(scores);
  if (sorted.length === 0) {
    return <p className="text-sm text-slate-500">— 점수 없음 (금칙어에 걸려 OpenAI에 보내지 않았어요)</p>;
  }
  return (
    <ul className="space-y-1">
      {sorted.map(([category, score]) => (
        <li key={category} className="flex items-center gap-2 text-sm">
          <span className="w-56 shrink-0 truncate font-mono text-xs" title={category}>
            {flagged.includes(category) ? "● " : ""}
            {category}
          </span>
          <span className="h-2 flex-1 overflow-hidden rounded bg-slate-200">
            <span
              className={`block h-full ${flagged.includes(category) ? "bg-red-500" : "bg-slate-500"}`}
              style={{width: `${Math.round(score * 100)}%`}}
            />
          </span>
          <span className="w-14 text-right font-mono text-xs">{score.toFixed(3)}</span>
        </li>
      ))}
    </ul>
  );
}
