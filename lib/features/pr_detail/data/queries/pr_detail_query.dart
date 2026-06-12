// lib/features/pr_detail/data/queries/pr_detail_query.dart

/// Fetches one pull request's detail by owner/name/number.
const String prDetailQuery = r'''
query PrDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      number title body isDraft state url
      baseRefName headRefName
      author { login }
      reviewDecision
      reviewRequests(first: 50) {
        nodes { requestedReviewer { __typename ... on User { login } ... on Team { name } } }
      }
      latestReviews(first: 50) {
        nodes { author { login } state body submittedAt }
      }
      comments(first: 100) {
        nodes { author { login } body createdAt }
      }
      commits(last: 1) {
        nodes {
          commit {
            abbreviatedOid messageHeadline committedDate
            statusCheckRollup {
              state
              contexts(first: 100) {
                nodes {
                  __typename
                  ... on CheckRun { name conclusion status }
                  ... on StatusContext { context state }
                }
              }
            }
          }
        }
      }
    }
  }
}
''';
