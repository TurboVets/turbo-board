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
