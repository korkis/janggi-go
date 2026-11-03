import type {ReportAction, ReportStatus, SanctionType} from "../models/admin";
import {ACTION_LABELS, REPORT_STATUS_LABELS, SANCTION_LABELS} from "../utils/format";

// 상태 표시. 색과 함께 기호·글자를 보여준다.

const BADGE = "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap";

const SANCTION_COLORS: Record<SanctionType, string> = {
  warning: "bg-amber-100 text-amber-900",
  chatRestriction: "bg-orange-100 text-orange-900",
  suspension: "bg-red-100 text-red-900",
  permanentBan: "bg-slate-800 text-white",
};

export function ReportStatusBadge({status}: {status: ReportStatus}) {
  const color = status === "pending" ? "bg-blue-100 text-blue-900" : "bg-slate-100 text-slate-700";
  return <span className={`${BADGE} ${color}`}>{REPORT_STATUS_LABELS[status]}</span>;
}

export function SanctionBadge({type}: {type: SanctionType}) {
  return <span className={`${BADGE} ${SANCTION_COLORS[type]}`}>{SANCTION_LABELS[type]}</span>;
}

export function ActionBadge({action}: {action: ReportAction}) {
  if (action === "dismissed") {
    return <span className={`${BADGE} bg-emerald-100 text-emerald-900`}>{ACTION_LABELS.dismissed}</span>;
  }
  return <SanctionBadge type={action} />;
}
