// lib/features/pr_inbox/data/queries/search_open_prs.dart

/// GraphQL document fetching open PRs across the watched repos.
/// `$q` is the search expression (see [buildSearchQueryString]); `$first` caps results.
const String searchOpenPrsQuery = r'''
query SearchOpenPrs($q: String!, $first: Int!) {
  search(query: $q, type: ISSUE, first: $first) {
    nodes {
      ... on PullRequest {
        number
        title
        isDraft
        updatedAt
        url
        author { login }
        repository { nameWithOwner }
        reviewDecision
        mergeable
        comments { totalCount }
        commits(last: 1) {
          nodes { commit { statusCheckRollup { state } } }
        }
      }
    }
  }
}
''';

/// Builds the GitHub search expression: `is:pr is:open repo:<slug> …`.
/// Slugs are deduped and sorted so the query (and any caching) is stable.
String buildSearchQueryString(List<String> repoSlugs) {
  final slugs = repoSlugs.toSet().toList()..sort();
  final terms = slugs.map((s) => 'repo:$s').join(' ');
  return terms.isEmpty ? 'is:pr is:open' : 'is:pr is:open $terms';
}
