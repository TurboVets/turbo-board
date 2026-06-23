export interface RepoEventRecord {
  repo: string;
  event: string;
  action: string | null;
  prNumber: number | null;
}

export function mapEvent(eventName: string, payload: any): RepoEventRecord | null {
  const repo = payload?.repository?.full_name;
  if (typeof repo !== "string") return null;
  const prNumber =
    typeof payload?.pull_request?.number === "number"
      ? payload.pull_request.number
      : typeof payload?.issue?.number === "number"
        ? payload.issue.number
        : null;
  return {
    repo,
    event: eventName,
    action: typeof payload?.action === "string" ? payload.action : null,
    prNumber,
  };
}
