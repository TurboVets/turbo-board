// lib/features/lead_cockpit/data/queries/project_board.dart

/// GraphQL document reading one organization Projects v2 board, page by page.
///
/// Selects both Issues and Pull Requests. `$org` + `$number` address the board;
/// `$first`/`$after` paginate `items`. Custom fields (Status / Priority / Complexity / Sprint)
/// are read from each item's `fieldValues` — the plain Issues REST/Search API cannot see them.
///
/// `fields` carries the Sprint iteration field's full configuration so the sprint
/// catalog includes iterations with no items yet (e.g. the upcoming "next" sprint),
/// which the per-item `fieldValues` alone cannot reveal.
const String projectBoardQuery = r'''
query ProjectBoard($org: String!, $number: Int!, $first: Int!, $after: String) {
  organization(login: $org) {
    projectV2(number: $number) {
      title
      fields(first: 50) {
        nodes {
          ... on ProjectV2IterationField {
            name
            configuration {
              iterations { title startDate duration }
              completedIterations { title startDate duration }
            }
          }
        }
      }
      items(first: $first, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          updatedAt
          content {
            __typename
            ... on Issue {
              number
              title
              url
              closed
              createdAt
              closedAt
              repository { name owner { login } }
              assignees(first: 5) { nodes { login } }
              subIssuesSummary { total completed percentCompleted }
            }
            ... on PullRequest {
              number
              title
              url
              isDraft
              state
              reviewDecision
              repository { name owner { login } }
              assignees(first: 5) { nodes { login } }
              commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
            }
          }
          fieldValues(first: 20) {
            nodes {
              __typename
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldNumberValue {
                number
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldIterationValue {
                title
                startDate
                duration
                field { ... on ProjectV2FieldCommon { name } }
              }
            }
          }
        }
      }
    }
  }
}
''';
