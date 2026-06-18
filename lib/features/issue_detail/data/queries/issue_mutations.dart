// lib/features/issue_detail/data/queries/issue_mutations.dart

/// Posts a comment to the issue conversation. [subjectId] is the issue node id.
const String addIssueCommentMutation = r'''
mutation AddIssueComment($subjectId: ID!, $body: String!) {
  addComment(input: {subjectId: $subjectId, body: $body}) { clientMutationId }
}
''';

/// Closes an issue as completed. [issueId] is the issue node id.
const String closeIssueMutation = r'''
mutation CloseIssue($issueId: ID!) {
  closeIssue(input: {issueId: $issueId, stateReason: COMPLETED}) { issue { state } }
}
''';

/// Reopens a closed issue.
const String reopenIssueMutation = r'''
mutation ReopenIssue($issueId: ID!) {
  reopenIssue(input: {issueId: $issueId}) { issue { state } }
}
''';

/// Creates a branch linked to the issue. [oid] is the base commit (repo default
/// branch head); [name] the new branch name.
const String createLinkedBranchMutation = r'''
mutation CreateLinkedBranch($issueId: ID!, $oid: GitObjectID!, $name: String!) {
  createLinkedBranch(input: {issueId: $issueId, oid: $oid, name: $name}) {
    linkedBranch { ref { name } }
  }
}
''';
