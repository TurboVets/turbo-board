// lib/features/pr_detail/data/queries/pr_mutations.dart

/// Posts a comment to the PR conversation (an issue comment on the PR).
const String addCommentMutation = r'''
mutation AddPrComment($subjectId: ID!, $body: String!) {
  addComment(input: {subjectId: $subjectId, body: $body}) {
    clientMutationId
  }
}
''';

/// Submits a pull-request review — `event` is APPROVE / REQUEST_CHANGES / COMMENT.
const String addReviewMutation = r'''
mutation AddPrReview($pullRequestId: ID!, $event: PullRequestReviewEvent!, $body: String) {
  addPullRequestReview(input: {pullRequestId: $pullRequestId, event: $event, body: $body}) {
    clientMutationId
  }
}
''';

/// Merges a pull request. `method` is MERGE / SQUASH / REBASE. Commit
/// headline/body are left to GitHub's defaults.
const String mergePrMutation = r'''
mutation MergePr($pullRequestId: ID!, $method: PullRequestMergeMethod!) {
  mergePullRequest(input: {pullRequestId: $pullRequestId, mergeMethod: $method}) {
    pullRequest { state merged }
  }
}
''';

/// Deletes a git ref (the PR's head branch). `refId` is the head ref node id.
const String deleteRefMutation = r'''
mutation DeleteRef($refId: ID!) {
  deleteRef(input: {refId: $refId}) {
    clientMutationId
  }
}
''';
