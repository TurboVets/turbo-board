// lib/features/issue_detail/data/queries/issue_detail_query.dart

/// Fetches one issue's detail by owner/name/number, enriched with ProjectV2 fields.
const String issueDetailQuery = r'''
query IssueDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    defaultBranchRef { target { oid } }
    issue(number: $number) {
      id number title url state body createdAt viewerCanUpdate
      author { login }
      labels(first: 20) { nodes { name color } }
      assignees(first: 10) { nodes { login } }
      participants(first: 10) { nodes { login } }
      milestone { title }
      comments(first: 50) { totalCount nodes { author { login } body createdAt } }
      parent { number title state repository { nameWithOwner } }
      subIssuesSummary { total completed }
      subIssues(first: 50) {
        nodes { number title state assignees(first: 1) { nodes { login } } }
      }
      closedByPullRequestsReferences(first: 10, includeClosedPrs: true) {
        nodes {
          number title isDraft state url reviewDecision
          repository { name owner { login } }
          commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
        }
      }
      projectItems(first: 5) {
        nodes {
          fieldValues(first: 20) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldSingleSelectValue { name field { ... on ProjectV2FieldCommon { name } } }
              ... on ProjectV2ItemFieldNumberValue { number field { ... on ProjectV2FieldCommon { name } } }
              ... on ProjectV2ItemFieldIterationValue { title field { ... on ProjectV2FieldCommon { name } } }
            }
          }
        }
      }
      timelineItems(
        first: 60
        itemTypes: [ISSUE_COMMENT, CLOSED_EVENT, REOPENED_EVENT, LABELED_EVENT, ASSIGNED_EVENT, UNASSIGNED_EVENT, CROSS_REFERENCED_EVENT, RENAMED_TITLE_EVENT]
      ) {
        nodes {
          __typename
          ... on IssueComment { createdAt author { login } body }
          ... on ClosedEvent { createdAt actor { login } }
          ... on ReopenedEvent { createdAt actor { login } }
          ... on LabeledEvent { createdAt actor { login } label { name } }
          ... on AssignedEvent { createdAt actor { login } assignee { ... on User { login } } }
          ... on UnassignedEvent { createdAt actor { login } assignee { ... on User { login } } }
          ... on CrossReferencedEvent { createdAt actor { login } source { ... on PullRequest { number } ... on Issue { number } } }
          ... on RenamedTitleEvent { createdAt actor { login } currentTitle }
        }
      }
    }
  }
}
''';
