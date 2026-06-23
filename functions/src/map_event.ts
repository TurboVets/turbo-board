export interface RepoEventRecord {
  repo: string;
  event: string;
  action: string | null;
  prNumber: number | null;
}

export function mapEvent(eventName: string, payload: any): RepoEventRecord | null {
  const repo = payload?.repository?.full_name;
  if (typeof repo !== "string") return null;
  const checkSuitePrs = payload?.check_suite?.pull_requests;
  const prNumber =
    typeof payload?.pull_request?.number === "number"
      ? payload.pull_request.number
      : typeof payload?.issue?.number === "number"
        ? payload.issue.number
        : Array.isArray(checkSuitePrs) && checkSuitePrs.length > 0 && typeof checkSuitePrs[0]?.number === "number"
          ? checkSuitePrs[0].number
          : null;
  return {
    repo,
    event: eventName,
    action: typeof payload?.action === "string" ? payload.action : null,
    prNumber,
  };
}
