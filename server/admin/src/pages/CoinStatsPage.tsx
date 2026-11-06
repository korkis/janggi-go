import {useEffect} from "react";
import {ErrorState, Loading} from "../components/States";
import type {CoinBalanceBucketView, CoinDayStatsView} from "../models/admin";
import {useCoinStatsStore} from "../stores/coinStatsStore";

function formatBucket(bucket: CoinBalanceBucketView): string {
  return bucket.max === null ? `${bucket.min} 이상` : `${bucket.min}~${bucket.max - 1}`;
}

/** 대국 수에 대한 사용 수의 비율. 대국이 없으면 "—". */
function formatRatio(count: number, games: number): string {
  if (games === 0) {
    return "—";
  }
  return `${count} (${Math.round((count / games) * 100)}%)`;
}

const CELL = "border-b border-slate-100 px-3 py-2 text-right tabular-nums";
const HEAD = "border-b border-slate-200 px-3 py-2 text-right font-medium text-slate-600";

function DayRow({day}: {day: CoinDayStatsView}) {
  return (
    <tr>
      <td className="border-b border-slate-100 px-3 py-2">{day.day}</td>
      <td className={CELL}>{day.games}</td>
      <td className={CELL}>{formatRatio(day.timeExtensions, day.games)}</td>
      <td className={CELL}>{formatRatio(day.gamePractices, day.games)}</td>
      <td className={CELL}>{day.rewardedAds}</td>
    </tr>
  );
}

/** 잔액 분포와 최근 7일의 시간 연장·놓아보기 비율, 광고 시청 수(docs/monetization.md의 엽전). 하루는 서울 기준이다. */
export function CoinStatsPage() {
  const resource = useCoinStatsStore((state) => state.stats);
  const load = useCoinStatsStore((state) => state.load);

  useEffect(() => {
    void load();
  }, [load]);

  if (resource === null || resource.status === "loading") {
    return <Loading />;
  }
  if (resource.status === "error") {
    return <ErrorState error={resource.error} onRetry={() => void load()} />;
  }
  const {balanceBuckets, days} = resource.data;

  return (
    <div className="max-w-3xl space-y-6">
      <h1 className="text-xl font-bold">엽전</h1>
      <section>
        <h2 className="mb-2 font-semibold">잔액 분포</h2>
        <table className="w-full rounded-xl border border-slate-200 bg-white text-sm">
          <thead>
            <tr>
              <th className="border-b border-slate-200 px-3 py-2 text-left font-medium text-slate-600">잔액</th>
              <th className={HEAD}>사용자</th>
            </tr>
          </thead>
          <tbody>
            {balanceBuckets.map((bucket) => (
              <tr key={bucket.min}>
                <td className="border-b border-slate-100 px-3 py-2">{formatBucket(bucket)}</td>
                <td className={CELL}>{bucket.count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
      <section>
        <h2 className="mb-2 font-semibold">최근 7일</h2>
        <table className="w-full rounded-xl border border-slate-200 bg-white text-sm">
          <thead>
            <tr>
              <th className="border-b border-slate-200 px-3 py-2 text-left font-medium text-slate-600">날짜</th>
              <th className={HEAD}>끝난 대국</th>
              <th className={HEAD}>시간 연장</th>
              <th className={HEAD}>놓아보기</th>
              <th className={HEAD}>광고 시청</th>
            </tr>
          </thead>
          <tbody>
            {days.map((day) => (
              <DayRow key={day.day} day={day} />
            ))}
          </tbody>
        </table>
        <p className="mt-2 text-xs text-slate-500">
          시간 연장, 놓아보기, 광고 시청은 그 기능이 생기면 쌓여요. 괄호는 끝난 대국 수에 대한 비율이에요.
        </p>
      </section>
    </div>
  );
}
