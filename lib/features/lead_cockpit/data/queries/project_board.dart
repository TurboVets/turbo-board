// lib/features/lead_cockpit/data/queries/project_board.dart

/// GraphQL document reading one organization Projects v2 board, page by page.
///
/// `$org` + `$number` address the board; `$first`/`$after` paginate `items`.
/// Custom fields (Status / Priority / Complexity / Sprint) are read from each
/// item's `fieldValues` — the plain Issues REST/Search API cannot see them.
const String projectBoardQuery = r'''
query ProjectBoard($org: String!, $number: Int!, $first: Int!, $after: String) {
  organization(login: $org) {
    projectV2(number: $number) {
      title
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
              repository { name }
              assignees(first: 5) { nodes { login } }
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
