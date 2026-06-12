// lib/features/pr_detail/data/queries/pr_detail_query.dart

/// Fetches one pull request's detail by owner/name/number.
const String prDetailQuery = r'''
query PrDetail($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    viewerPermission
    mergeCommitAllowed
    squashMergeAllowed
    rebaseMergeAllowed
    pullRequest(number: $number) {
      id number title body isDraft state url mergeable mergeStateStatus createdAt
      baseRefName headRefName isCrossRepository
      headRef { id }
      author { login }
      reviewDecision
      reviewRequests(first: 50) {
        nodes { requestedReviewer { __typename ... on User { login } ... on Team { name } } }
      }
      latestReviews(first: 50) {
        nodes { author { login } state body submittedAt }
      }
      reviews(first: 100) {
        nodes { author { login } state body submittedAt }
      }
      comments(first: 100) {
        nodes { author { login } body createdAt }
      }
      timelineItems(
        first: 100
        itemTypes: [
          PULL_REQUEST_COMMIT, REVIEW_REQUESTED_EVENT, REVIEW_REQUEST_REMOVED_EVENT,
          LABELED_EVENT, HEAD_REF_FORCE_PUSHED_EVENT, MERGED_EVENT, CLOSED_EVENT,
          REOPENED_EVENT, READY_FOR_REVIEW_EVENT, RENAMED_TITLE_EVENT
        ]
      ) {
        nodes {
          __typename
          ... on PullRequestCommit { commit { committedDate author { user { login } name } } }
          ... on ReviewRequestedEvent {
            createdAt actor { login }
            requestedReviewer { __typename ... on User { login } ... on Team { name } }
          }
          ... on ReviewRequestRemovedEvent {
            createdAt actor { login }
            requestedReviewer { __typename ... on User { login } ... on Team { name } }
          }
          ... on LabeledEvent { createdAt actor { login } label { name } }
          ... on HeadRefForcePushedEvent { createdAt actor { login } }
          ... on MergedEvent { createdAt actor { login } }
          ... on ClosedEvent { createdAt actor { login } }
          ... on ReopenedEvent { createdAt actor { login } }
          ... on ReadyForReviewEvent { createdAt actor { login } }
          ... on RenamedTitleEvent { createdAt actor { login } currentTitle }
        }
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
