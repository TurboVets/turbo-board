import { describe, it, expect } from "vitest";
import { mapEvent } from "../src/map_event";

describe("mapEvent", () => {
  it("maps a pull_request event with the PR number", () => {
    const r = mapEvent("pull_request", {
      action: "opened",
      repository: { full_name: "acme/web" },
      pull_request: { number: 42 },
    });
    expect(r).toEqual({ repo: "acme/web", event: "pull_request", action: "opened", prNumber: 42 });
  });

  it("maps issue_comment on a PR using issue.number", () => {
    const r = mapEvent("issue_comment", {
      action: "created",
      repository: { full_name: "acme/web" },
      issue: { number: 7 },
    });
    expect(r).toEqual({ repo: "acme/web", event: "issue_comment", action: "created", prNumber: 7 });
  });

  it("maps check_suite with an associated PR using check_suite.pull_requests[0].number", () => {
    const r = mapEvent("check_suite", {
      action: "completed",
      repository: { full_name: "acme/web" },
      check_suite: { pull_requests: [{ number: 99 }] },
    });
    expect(r).toEqual({ repo: "acme/web", event: "check_suite", action: "completed", prNumber: 99 });
  });

  it("maps check_suite with empty pull_requests to prNumber null", () => {
    const r = mapEvent("check_suite", {
      action: "completed",
      repository: { full_name: "acme/web" },
      check_suite: { pull_requests: [] },
    });
    expect(r).toEqual({ repo: "acme/web", event: "check_suite", action: "completed", prNumber: null });
  });

  it("maps check_suite with no pull_requests field to prNumber null", () => {
    const r = mapEvent("check_suite", {
      action: "completed",
      repository: { full_name: "acme/web" },
    });
    expect(r).toEqual({ repo: "acme/web", event: "check_suite", action: "completed", prNumber: null });
  });

  it("returns null when repository is missing", () => {
    expect(mapEvent("pull_request", { action: "opened" })).toBeNull();
  });
});
