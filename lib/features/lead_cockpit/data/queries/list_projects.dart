// lib/features/lead_cockpit/data/queries/list_projects.dart

/// Lists the Projects v2 boards the current token can pick from: the viewer's
/// own boards plus those of every organization they belong to.
const String listProjectsQuery = r'''
query MyProjects {
  viewer {
    login
    projectsV2(first: 50) {
      nodes { number title closed }
    }
    organizations(first: 50) {
      nodes {
        login
        projectsV2(first: 50) {
          nodes { number title closed }
        }
      }
    }
  }
}
''';
